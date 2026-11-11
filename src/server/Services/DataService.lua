-- Persistent player data: DataStoreService with session locking, retries
-- with backoff, autosave, save on leave and on shutdown (BindToClose),
-- versioned migrations and validation (Domain/Schema).
-- In Studio without "Enable Studio Access to API Services" it falls back to
-- an in-memory store and says so in the output.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Domain = script.Parent.Parent.Domain
local Schema = require(Domain.Schema)

local DataService = {}

local STORE_NAME = "WMAT_Players_v1"
local RECEIPT_STORE_NAME = "WMAT_Receipts_v1"
local AUTOSAVE_SECONDS = 90
local LOCK_EXPIRE_SECONDS = 600 -- a lock older than this is considered abandoned
local LOAD_ATTEMPTS = 6

local profiles = {} -- [player] = { data, loadedAt, lastSave, saving }
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local loadedCallbacks = {}

---------------------------------------------------------------- store access

local memoryStore = {}
local useMemory = false
local playerStore, receiptStore

local function memoryUpdate(storeName, key, fn)
	memoryStore[storeName] = memoryStore[storeName] or {}
	local current = memoryStore[storeName][key]
	local copy = current and HttpService:JSONDecode(HttpService:JSONEncode(current)) or nil
	local result = fn(copy)
	if result ~= nil then
		memoryStore[storeName][key] = result
	end
	return result
end

local function initStores()
	local ok, err = pcall(function()
		playerStore = DataStoreService:GetDataStore(STORE_NAME)
		receiptStore = DataStoreService:GetDataStore(RECEIPT_STORE_NAME)
		-- a cheap call to see if API access works (fails in Studio without access)
		playerStore:GetAsync("__probe")
	end)
	if not ok then
		useMemory = true
		warn("[DataService] DataStores unavailable (" .. tostring(err) .. "). Using in-memory data: progress will NOT be saved. Enable Studio Access to API Services to test saving.")
	end
end

-- UpdateAsync with retries and exponential backoff.
local function update(storeName, key, fn)
	if useMemory then
		return true, memoryUpdate(storeName, key, fn)
	end
	local store = storeName == RECEIPT_STORE_NAME and receiptStore or playerStore
	local delay = 1
	local lastErr
	for attempt = 1, 5 do
		-- wait for request budget instead of throwing
		local budgetWait = 0
		while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 and budgetWait < 10 do
			task.wait(0.5)
			budgetWait = budgetWait + 0.5
		end
		local ok, result = pcall(function()
			return store:UpdateAsync(key, fn)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < 5 then
			task.wait(delay)
			delay = delay * 2
		end
	end
	warn("[DataService] UpdateAsync failed for " .. key .. ": " .. tostring(lastErr))
	return false, lastErr
end

local function keyFor(userId)
	return "player_" .. tostring(userId)
end

---------------------------------------------------------------- profiles

function DataService.get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function DataService.profile(player)
	return profiles[player]
end

function DataService.isMemoryMode()
	return useMemory
end

function DataService.onLoaded(fn)
	table.insert(loadedCallbacks, fn)
end

-- Load with session lock. Returns data or nil (caller kicks the player).
function DataService.load(player)
	local key = keyFor(player.UserId)
	local now = os.time()
	for attempt = 1, LOAD_ATTEMPTS do
		local locked = false
		local ok, stored = update(STORE_NAME, key, function(old)
			old = old or {}
			local lock = old.lock
			if lock and lock.jobId ~= jobId and now - (lock.time or 0) < LOCK_EXPIRE_SECONDS and attempt < LOAD_ATTEMPTS then
				locked = true
				return nil -- do not write; another server still owns the session
			end
			old.lock = { jobId = jobId, time = now }
			return old
		end)
		if not ok then
			return nil, "DataStore error"
		end
		if not locked then
			if not player.Parent then
				-- player left while loading: release the lock again
				update(STORE_NAME, key, function(old)
					if old and old.lock and old.lock.jobId == jobId then
						old.lock = nil
					end
					return old
				end)
				return nil, "left"
			end
			local data = stored and stored.data
			local isNew = data == nil
			if isNew then
				data = Schema.defaults()
				data.createdAt = os.time()
			end
			data = Schema.migrate(data)
			data = Schema.validate(data)
			profiles[player] = { data = data, loadedAt = os.clock(), lastSave = os.clock(), isNew = isNew }
			for _, fn in ipairs(loadedCallbacks) do
				task.spawn(fn, player, data, isNew)
			end
			return data
		end
		-- session still locked by another server (e.g. quick rejoin): wait and retry
		task.wait(attempt * 2)
	end
	return nil, "Session locked"
end

-- Save now. release = true removes the session lock (player leaving).
function DataService.save(player, release)
	local p = profiles[player]
	if not p then
		return false
	end
	while p.saving do
		task.wait(0.1)
	end
	p.saving = true
	p.data.lastOnline = os.time()
	local snapshot = p.data
	local ownLock = true
	local ok = update(STORE_NAME, keyFor(player.UserId), function(old)
		old = old or {}
		if old.lock and old.lock.jobId ~= jobId then
			-- another server took over: never overwrite its data
			ownLock = false
			return nil
		end
		old.data = snapshot
		old.version = Schema.VERSION
		old.lock = (not release) and { jobId = jobId, time = os.time() } or nil
		return old
	end)
	p.saving = false
	if ok and ownLock then
		p.lastSave = os.clock()
		return true
	end
	if not ownLock then
		warn("[DataService] Session for " .. player.Name .. " was taken over by another server; not saving.")
	end
	return false
end

function DataService.release(player)
	DataService.save(player, true)
	profiles[player] = nil
end

---------------------------------------------------------------- receipts

-- Permanent record of granted Developer Product receipts.
function DataService.receiptGranted(purchaseId)
	if useMemory then
		return memoryStore[RECEIPT_STORE_NAME] ~= nil and memoryStore[RECEIPT_STORE_NAME][purchaseId] ~= nil
	end
	local ok, value = pcall(function()
		return receiptStore:GetAsync(purchaseId)
	end)
	if not ok then
		return nil -- unknown (store error): caller must not grant
	end
	return value ~= nil
end

function DataService.recordReceipt(purchaseId, userId, productId)
	return update(RECEIPT_STORE_NAME, purchaseId, function(old)
		if old then
			return nil
		end
		return { userId = userId, productId = productId, time = os.time() }
	end)
end

---------------------------------------------------------------- lifecycle

function DataService.init()
	initStores()
	-- autosave loop, staggered per player
	task.spawn(function()
		while true do
			task.wait(5)
			for player, p in pairs(profiles) do
				if os.clock() - p.lastSave >= AUTOSAVE_SECONDS and not p.saving then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and useMemory then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending = pending + 1
			task.spawn(function()
				DataService.save(player, true)
				pending = pending - 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.2)
		end
	end)
	-- Releasing on leave is done by PlayerService after its own cleanup, so
	-- last-second rewards (e.g. a running championship) are saved too.
end

return DataService
