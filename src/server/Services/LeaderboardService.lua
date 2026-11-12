-- Global leaderboards (OrderedDataStores) shown on the boards in the plaza
-- and in the Leaderboards menu, plus live in-server rankings.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Modules.Format)
local Util = require(Shared.Modules.Util)

local Domain = script.Parent.Parent.Domain
local Economy = require(Domain.Economy)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

-- stat id -> { title, value(d), format }
LeaderboardService.STATS = {
	{ id = "richest", title = "Richest Owners", board = "Richest Owners", value = function(d) return d.stats.totalEarned end, format = Format.cash },
	{ id = "level", title = "Highest Level", board = "Highest Level", value = function(d) return d.rebirths * 1000 + d.level end, format = function(v) local rb = math.floor(v / 1000) return "Lv " .. (v % 1000) .. (rb > 0 and (" ★" .. rb) or "") end },
	{ id = "students", title = "Most Students", value = function(d) return d.stats.studentsServed end, format = Format.short },
	{ id = "reputation", title = "Top Reputation", board = "Top Reputation", value = function(d) return d.stats.maxReputation end, format = Format.short },
	{ id = "mastered", title = "Disciplines Mastered", value = function(d) return Economy.masteredCount(d) end, format = tostring },
	{ id = "cities", title = "Most Cities", value = function(d) return Util.count(d.cities) end, format = tostring },
	{ id = "tournaments", title = "Tournament Wins", value = function(d) return d.stats.tournamentWins or 0 end, format = tostring },
	{ id = "prestige", title = "Highest Prestige", board = "Highest Prestige", value = function(d) return d.rebirths end, format = function(v) return v .. " rebirths" end },
}
local byId = {}
for _, s in ipairs(LeaderboardService.STATS) do
	byId[s.id] = s
end

local stores = {}
local cache = {} -- id -> { { name, value } }
local available = true

local function store(id)
	if not stores[id] then
		stores[id] = DataStoreService:GetOrderedDataStore("WMAT_LB_" .. id)
	end
	return stores[id]
end

local function pushScores()
	for _, player in ipairs(Players:GetPlayers()) do
		local d = DataService.get(player)
		if d then
			for _, s in ipairs(LeaderboardService.STATS) do
				local value = math.floor(math.min(s.value(d), 9e15))
				pcall(function()
					store(s.id):SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Player " .. userId)
	return nameCache[userId]
end

local function fetch()
	for _, s in ipairs(LeaderboardService.STATS) do
		local ok, pages = pcall(function()
			return store(s.id):GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local list = {}
			for _, entry in ipairs(pages:GetCurrentPage()) do
				table.insert(list, { name = nameOf(tonumber(entry.key)), value = entry.value, text = s.format(entry.value) })
			end
			cache[s.id] = list
		else
			available = false
		end
	end
end

local function updateBoards()
	local env = workspace:FindFirstChild("Environment")
	local boards = env and env:FindFirstChild("Leaderboards")
	if not boards then
		return
	end
	for _, model in ipairs(boards:GetChildren()) do
		local title = model:GetAttribute("Stat")
		local stat
		for _, s in ipairs(LeaderboardService.STATS) do
			if s.board == title then
				stat = s
			end
		end
		local screen = model:FindFirstChild("Screen")
		local list = screen and screen:FindFirstChild("BoardGui") and screen.BoardGui:FindFirstChild("List")
		if stat and list then
			local entries = LeaderboardService.list(stat.id)
			for i = 1, 10 do
				local row = list:FindFirstChild("Row" .. i)
				local source = #entries.global > 0 and entries.global or entries.server
				local e = source[i]
				if row then
					row.Text = e and string.format("%d.  %s  —  %s", i, e.name, e.text) or (i .. ".  —")
				end
			end
		end
	end
end

-- Returns { global = list (may be empty when DataStores are off), server = list }
function LeaderboardService.list(statId)
	local s = byId[statId]
	if not s then
		return { global = {}, server = {} }
	end
	local server = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local d = DataService.get(player)
		if d then
			local v = s.value(d)
			table.insert(server, { name = player.DisplayName, value = v, text = s.format(v), userId = player.UserId })
		end
	end
	table.sort(server, function(a, b)
		return a.value > b.value
	end)
	return { global = cache[statId] or {}, server = server, available = available }
end

function LeaderboardService.init()
	task.spawn(function()
		task.wait(20)
		while true do
			if not DataService.isMemoryMode() then
				pushScores()
				fetch()
			end
			updateBoards()
			task.wait(120)
		end
	end)
	-- quick refresh of the in-server part of the boards
	task.spawn(function()
		while true do
			task.wait(15)
			updateBoards()
		end
	end)
end

return LeaderboardService
