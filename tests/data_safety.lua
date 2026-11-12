-- Player data safety (QA). Runs the real DataService against a fake DataStore
-- that behaves like Roblox's (UpdateAsync transform, errors on demand, only
-- storable values: string-keyed dictionaries or proper arrays, finite numbers).
--   lua5.4 tests/data_safety.lua
-- What this cannot show: real DataStore latency, budgets, throttling and
-- Roblox's own JSON encoder; those need a test place with API access.
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
_G.warn = function() end
local H = require("harness")
local check, eq = H.check, H.eq

---------------------------------------------------------------- fake Roblox services

-- Deep copy that rejects what a DataStore / JSONEncode rejects.
local function storable(v, path)
	local t = type(v)
	if t == "number" then
		assert(v == v and v ~= math.huge and v ~= -math.huge, "not storable (NaN/inf) at " .. path)
		return v
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "table" then
		local n, strings, ints = 0, 0, 0
		for k in pairs(v) do
			n = n + 1
			if type(k) == "string" then
				strings = strings + 1
			elseif math.type(k) == "integer" and k >= 1 then
				ints = ints + 1
			else
				error("not storable key " .. tostring(k) .. " at " .. path)
			end
		end
		assert(strings == 0 or ints == 0, "mixed table at " .. path)
		if ints > 0 then
			assert(#v == ints, "sparse array at " .. path)
		end
		local out = {}
		for k, x in pairs(v) do
			out[k] = storable(x, path .. "." .. tostring(k))
		end
		return out
	end
	error("not storable type " .. t .. " at " .. path)
end

local store = {} -- key -> value (as stored)
local failNext = 0 -- number of UpdateAsync calls that throw
local writes = 0
local fakeStore = {
	UpdateAsync = function(_, key, fn)
		if failNext > 0 then
			failNext = failNext - 1
			error("502: API Services rejected request")
		end
		local old = store[key] and storable(store[key], key) or nil
		local new = fn(old)
		if new ~= nil then
			store[key] = storable(new, key)
			writes = writes + 1
		end
		return new
	end,
	GetAsync = function(_, key)
		return store[key]
	end,
}
local DSS = H.game:GetService("DataStoreService")
rawset(DSS, "GetDataStore", function()
	return fakeStore
end)
rawset(DSS, "GetRequestBudgetForRequestType", function()
	return 100
end)
local Http = H.game:GetService("HttpService")
rawset(Http, "JSONEncode", function(_, v)
	return storable(v, "json")
end)
rawset(Http, "JSONDecode", function(_, v)
	return storable(v, "json")
end)
rawset(Http, "GenerateGUID", function()
	return "job-A"
end)
local Run = H.game:GetService("RunService")
rawset(Run, "IsStudio", function()
	return false
end)
H.game.BindToClose = function() end
_G.task = { wait = function() end, spawn = function() end, delay = function() end }

local DataService = H.load("ServerScriptService/Server/Services/DataService")
local Schema = H.load("ServerScriptService/Server/Domain/Schema")
DataService.init()

local function player(id)
	return { UserId = id, Name = "P" .. id, Parent = true }
end

H.suite("data: new player, save and reload keep every kind of progress", function()
	local p = player(1)
	local d = DataService.load(p)
	check(d ~= nil, "new player loads")
	check(store.player_1 and store.player_1.lock and store.player_1.lock.jobId:find("job%-A"), "session lock taken")
	d.cash, d.gems, d.level, d.xp, d.reputation = 123456, 77, 12, 40, 999
	d.disciplines.boxing = true
	d.cities.smalltown.rooms["2"] = { id = "boxing_room", level = 3, tier = 1 }
	d.mastery.karate = { rank = 4, xp = 10 }
	d.cosmetics.owned.outfit_karate_white = true
	d.achievements.first_student = true
	d.students.s1 = { id = "s1", name = "Ann B.", discipline = "karate", rank = 3, xp = 4, talent = 2, satisfaction = 80, visits = 9, seed = 5, examReady = true, waited = 2 }
	d.nextStudentId = 2
	d.compete.kumiteWins = 3
	check(DataService.save(p, false), "save succeeds")
	DataService.release(p)
	check(store.player_1.lock == nil, "lock released on leave")
	local d2 = DataService.load(p)
	eq(d2.cash, 123456, "cash")
	eq(d2.gems, 77, "gems")
	eq(d2.level, 12, "level")
	eq(d2.reputation, 999, "reputation")
	check(d2.disciplines.boxing, "discipline")
	eq(d2.cities.smalltown.rooms["2"].level, 3, "room upgrade")
	eq(d2.mastery.karate.rank, 4, "mastery")
	check(d2.cosmetics.owned.outfit_karate_white, "cosmetic")
	check(d2.achievements.first_student, "achievement")
	check(d2.students.s1 and d2.students.s1.examReady and d2.students.s1.rank == 3, "student with exam state")
	eq(d2.compete.kumiteWins, 3, "competition record")
	check(d2.trainers.t1 ~= nil, "starter trainer")
	DataService.release(p)
end)

H.suite("data: a failed DataStore never resets or overwrites progress", function()
	local p = player(2)
	store.player_2 = { data = { version = Schema.VERSION, cash = 5000000, level = 30 }, version = Schema.VERSION }
	local before = writes
	failNext = 999
	local d, err = DataService.load(p)
	failNext = 0
	check(d == nil and err == "DataStore error", "load fails instead of giving a fresh save (" .. tostring(err) .. ")")
	eq(store.player_2.data.cash, 5000000, "stored cash untouched")
	eq(writes, before, "nothing was written")
	check(DataService.get(p) == nil, "no profile, so nothing can be saved over it later")
	-- a transient error is retried
	failNext = 2
	local d2 = DataService.load(p)
	check(d2 and d2.cash == 5000000 and d2.level == 30, "two errors, then loads the real data")
	-- a failed save keeps the data in memory and reports failure
	d2.cash = 6000000
	failNext = 999
	check(not DataService.save(p, false), "save failure is reported")
	failNext = 0
	eq(store.player_2.data.cash, 5000000, "store unchanged after failed save")
	check(DataService.save(p, false), "next save works")
	eq(store.player_2.data.cash, 6000000, "and stores the new value")
	DataService.release(p)
end)

H.suite("data: another server's session is never overwritten", function()
	local p = player(3)
	local d = DataService.load(p)
	d.cash = 42
	DataService.save(p, false)
	-- another server takes over (e.g. the player joined elsewhere)
	store.player_3.lock = { jobId = "job-B", time = os.time() }
	store.player_3.data.cash = 777
	d.cash = 1
	check(not DataService.save(p, true), "save refused when the lock belongs to another server")
	eq(store.player_3.data.cash, 777, "other server's data kept")
	-- a fresh lock held by another server delays loading; an old one is taken over
	store.player_4 = { data = { version = Schema.VERSION, cash = 99 }, lock = { jobId = "job-B", time = os.time() - 5000 } }
	local d4 = DataService.load(player(4))
	check(d4 and d4.cash == 99, "abandoned lock (older than 10 min) is taken over")
end)

H.suite("data: old saves migrate without losing progress", function()
	-- a version 3 save (before students, achievements, competition)
	store.player_5 = { version = 3, data = {
		version = 3, cash = 250000, gems = 40, level = 15, xp = 3, reputation = 4000,
		activeCity = "smalltown",
		cities = { smalltown = { rooms = { ["0"] = { id = "reception", level = 2 }, ["1"] = { id = "karate_room", level = 4, trainer = "t9" }, ["3"] = { id = "judo_room", level = 2 } }, members = 30 } },
		trainers = { t9 = { name = "Old Sensei", discipline = "karate", rarity = "epic", level = 20, upgrade = 1, xp = 0, seed = 3, specialty = "kata" } },
		disciplines = { karate = true, judo = true },
		mastery = { karate = { rank = 5, xp = 1 } },
		cosmetics = { owned = { outfit_karate_white = true }, equipped = { outfit = "outfit_karate_white" } },
	} }
	local d = DataService.load(player(5))
	eq(d.version, Schema.VERSION, "migrated to the current version")
	eq(d.cash, 250000, "cash kept")
	eq(d.level, 15, "level kept")
	eq(d.cities.smalltown.rooms["1"].level, 4, "room level kept")
	eq(d.cities.smalltown.rooms["1"].trainer, "t9", "trainer assignment kept")
	check(d.trainers.t9 and d.trainers.t9.name == "Old Sensei", "trainer kept")
	check(d.trainers.t1 == nil, "no extra starter trainer added to an existing save")
	eq(d.mastery.karate.rank, 5, "mastery kept")
	check(type(d.students) == "table" and type(d.compete) == "table" and d.compete.kumiteWins == 0, "new fields get safe defaults")
	check(d.cosmetics.equipped.outfit == "outfit_karate_white", "equipped outfit kept")
end)

H.suite("data: developer sandbox never loses or writes real progress", function()
	local p = player(6)
	local d = DataService.load(p)
	d.cash = 1000
	DataService.save(p, false)
	check(DataService.enterSandbox(p), "sandbox on")
	local sd = DataService.get(p)
	sd.cash = 999999999
	sd.level = 90
	check(DataService.save(p, false), "autosave in the sandbox")
	eq(store.player_6.data.cash, 1000, "autosave stores the real cash, not the test cash")
	check(store.player_6.lock and store.player_6.lock.jobId:find("job%-A") and store.player_6.lock.time ~= nil, "session lock kept fresh while testing")
	-- a Robux purchase while testing goes to the real save
	local real = DataService.realData(p)
	real.cash = real.cash + 500
	check(DataService.save(p, false), "purchase save in the sandbox")
	eq(store.player_6.data.cash, 1500, "purchase stored")
	check(DataService.exitSandbox(p), "sandbox off")
	eq(DataService.get(p).cash, 1500, "real progress back, including the purchase")
	-- leaving while in the sandbox stores the real progress
	DataService.enterSandbox(p)
	DataService.get(p).cash = 5
	DataService.release(p)
	eq(store.player_6.data.cash, 1500, "leaving in the sandbox keeps the real cash")
	check(store.player_6.lock == nil, "and releases the lock")
end)

H.suite("data: every scenario and a long simulated session stay storable", function()
	local DevTools = H.load("ServerScriptService/Server/Domain/DevTools")
	for _, id in ipairs({ "new", "early", "mid", "late", "karate_full", "tournament" }) do
		local ok, err = pcall(storable, DevTools.scenario(id, 3), id)
		check(ok, id .. " save is storable (" .. tostring(err) .. ")")
	end
	local Simulation = H.load("ServerScriptService/Server/Domain/Simulation")
	local Academy = H.load("ServerScriptService/Server/Domain/Academy")
	local RNG = H.load("ReplicatedStorage/Shared/Modules/RNG")
	local d = DevTools.scenario("mid", 9)
	local sim = Simulation.new(d.activeCity, 1.7e9)
	local rng = RNG.new(4)
	for step = 1, 3600 do
		local ctx = { now = 1.7e9 + step }
		Simulation.step(d, sim, ctx, rng, 1)
		Simulation.settle(d, sim, ctx, rng)
		if step % 60 == 0 then
			Academy.collect(d)
		end
	end
	local ok, err = pcall(storable, d, "session")
	check(ok, "an hour of play is storable (" .. tostring(err) .. ")")
end)

local r = H.results
for _, f in ipairs(r.failures) do
	print("  - " .. f)
end
print(string.format("data safety: %d checks passed, %d failed", r.passed, r.failed))
os.exit(r.failed == 0 and 0 or 1)
