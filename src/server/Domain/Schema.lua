-- Player save data: defaults, versioned migrations and validation.
-- Everything the game persists is in this one table (stored by DataService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Trainers = require(Shared.Config.Trainers)
local Progression = require(Shared.Config.Progression)
local Cosmetics = require(Shared.Config.Cosmetics)

local Schema = {}

Schema.VERSION = 3

local function newBranch()
	return {
		rooms = {
			-- slot keys are strings: DataStores store JSON and sparse number keys break arrays
			["0"] = { id = "reception", level = 1 },
		},
		members = 0,
	}
end
Schema.newBranch = newBranch

function Schema.defaults()
	local starter = newBranch()
	starter.rooms["1"] = { id = "karate_room", level = 1, tier = 1, trainer = "t1" }
	return {
		version = Schema.VERSION,
		cash = Progression.START_CASH,
		gems = Progression.START_GEMS,
		level = 1,
		xp = 0,
		reputation = 0,
		rebirths = 0,
		register = 0,
		automation = 0,
		activeCity = Cities.START,
		cities = { [Cities.START] = starter },
		disciplines = { karate = true },
		mastery = {},
		trainers = {
			t1 = { uid = "t1", name = "Kenji Mori", discipline = "karate", rarity = "common", level = 1, xp = 0, upgrade = 0, spec = "fundamentals", seed = 1234 },
		},
		nextTrainerId = 2,
		boosts = {},
		cosmetics = {
			owned = { outfit_karate_white = true, pose_bow = true, title_owner = true },
			equipped = { title = "title_owner", outfit = "outfit_karate_white" },
		},
		quests = { day = -1, daily = {}, week = -1, weekly = {} },
		daily = { lastDay = -1, streak = 0 },
		event = { key = "", points = 0, claimed = {} },
		purchases = { passes = {}, receipts = {}, products = {}, starter = false },
		ratings = { sum = 0, count = 0, given = {} },
		stats = {
			studentsServed = 0, classesCompleted = 0, totalEarned = 0, roomsBuilt = 0, roomsUpgraded = 0,
			trainersHired = 0, championships = 0, happyStudents = 0, visitsMade = 0, playSeconds = 0,
			bestHourly = 0, maxReputation = 0,
		},
		flags = {},
		settings = { music = true, sfx = true, npcDensity = 1, lowGraphics = false },
		lastOnline = 0,
		createdAt = 0,
	}
end

-- Migrations: index n migrates data from version n to n + 1.
local migrations = {}

-- v1 kept one flat academy (data.rooms) and no cities.
migrations[1] = function(d)
	if d.rooms and not d.cities then
		local branch = newBranch()
		for slot, room in pairs(d.rooms) do
			branch.rooms[tostring(slot)] = room
		end
		d.cities = { [Cities.START] = branch }
		d.activeCity = Cities.START
		d.rooms = nil
	end
	if type(d.members) == "number" then
		d.cities[Cities.START].members = d.members
		d.members = nil
	end
end

-- v2 stored trainer assignment on the trainer; v3 stores it on the room only.
migrations[2] = function(d)
	for uid, t in pairs(d.trainers or {}) do
		if t.room and t.city then
			local branch = d.cities and d.cities[t.city]
			local room = branch and branch.rooms[tostring(t.room)]
			if room and room.trainer == nil then
				room.trainer = uid
			end
		end
		t.room = nil
		t.city = nil
	end
end

function Schema.migrate(d)
	d.version = tonumber(d.version) or 1
	while d.version < Schema.VERSION do
		local m = migrations[d.version]
		if m then
			m(d)
		end
		d.version = d.version + 1
	end
	return d
end

local function num(x, lo, hi, default)
	if not Util.isFiniteNumber(x) then
		return default
	end
	return Util.clamp(x, lo, hi)
end

local BIG = 1e15

local COLLECTIONS = { cities = true, trainers = true, disciplines = true, mastery = true, boosts = true }

-- Repair anything invalid (corrupt saves, removed content, NaN). Never throws.
function Schema.validate(d)
	local defaults = Schema.defaults()
	if type(d) ~= "table" then
		return defaults
	end
	-- top-level scalars
	d.cash = math.floor(num(d.cash, 0, BIG, defaults.cash))
	d.gems = math.floor(num(d.gems, 0, 1e9, defaults.gems))
	d.level = math.floor(num(d.level, 1, Progression.MAX_LEVEL, 1))
	d.xp = num(d.xp, 0, BIG, 0)
	d.reputation = num(d.reputation, 0, BIG, 0)
	d.rebirths = math.floor(num(d.rebirths, 0, 1000, 0))
	d.register = num(d.register, 0, BIG, 0)
	d.automation = math.floor(num(d.automation, 0, #Progression.automation, 0))
	d.nextTrainerId = math.floor(num(d.nextTrainerId, 1, 1e9, 1))
	-- fill missing tables / keys
	if type(d.cities) ~= "table" then
		d.cities = nil
	end
	if type(d.trainers) ~= "table" then
		d.trainers = nil
	end
	-- Collections (maps keyed by id) are only filled when missing entirely;
	-- other tables get their missing keys from the defaults.
	for k, v in pairs(defaults) do
		if d[k] == nil or type(d[k]) ~= type(v) then
			d[k] = Util.deepCopy(v)
		elseif type(v) == "table" and not COLLECTIONS[k] then
			Util.reconcile(d[k], v)
		end
	end
	-- disciplines
	for id in pairs(d.disciplines) do
		if not Disciplines.byId[id] then
			d.disciplines[id] = nil
		end
	end
	d.disciplines.karate = true
	-- mastery
	for id, m in pairs(d.mastery) do
		if not Disciplines.byId[id] or type(m) ~= "table" then
			d.mastery[id] = nil
		else
			local maxRank = #Disciplines.byId[id].ranks
			m.rank = math.floor(num(m.rank, 1, maxRank, 1))
			m.xp = num(m.xp, 0, BIG, 0)
		end
	end
	-- trainers
	local trainerCount = 0
	for uid, t in pairs(d.trainers) do
		local ok = type(t) == "table" and Disciplines.byId[t.discipline] and Trainers.rarityById[t.rarity]
		if not ok then
			d.trainers[uid] = nil
		else
			trainerCount = trainerCount + 1
			t.uid = uid
			t.level = math.floor(num(t.level, 1, Trainers.rarityById[t.rarity].maxLevel, 1))
			t.xp = num(t.xp, 0, BIG, 0)
			t.upgrade = math.floor(num(t.upgrade, 0, 50, 0))
			t.seed = math.floor(num(t.seed, 1, 2147483646, 1))
			if t.ability and not Trainers.abilityById[t.ability] then
				t.ability = nil
			end
			if t.spec and not Trainers.specById[t.spec] then
				t.spec = nil
			end
			t.name = type(t.name) == "string" and string.sub(t.name, 1, 40) or "Trainer"
		end
	end
	-- cities and rooms
	for cityId, branch in pairs(d.cities) do
		if not Cities.byId[cityId] or type(branch) ~= "table" then
			d.cities[cityId] = nil
		else
			if type(branch.rooms) ~= "table" then
				branch.rooms = {}
			end
			branch.members = math.floor(num(branch.members, 0, 1e9, 0))
			for slot, room in pairs(branch.rooms) do
				local slotNum = tonumber(slot)
				local valid = type(room) == "table" and Rooms.byId[room.id] and slotNum and slotNum >= 0 and slotNum <= 20
				if valid and slotNum == 0 and room.id ~= "reception" then
					valid = false
				end
				if not valid then
					branch.rooms[slot] = nil
				else
					room.level = math.floor(num(room.level, 1, Rooms.MAX_LEVEL, 1))
					room.tier = math.floor(num(room.tier, 1, 5, 1))
					if room.trainer and not d.trainers[room.trainer] then
						room.trainer = nil
					end
					if room.buildEnd ~= nil then
						room.buildEnd = num(room.buildEnd, 0, BIG, 0)
					end
				end
			end
			if not branch.rooms["0"] then
				branch.rooms["0"] = { id = "reception", level = 1 }
			end
		end
	end
	if not d.cities[Cities.START] then
		d.cities[Cities.START] = newBranch()
	end
	if not d.cities[d.activeCity] then
		d.activeCity = Cities.START
	end
	-- a trainer can only be in one room
	local seen = {}
	for _, branch in pairs(d.cities) do
		for _, room in pairs(branch.rooms) do
			if room.trainer then
				if seen[room.trainer] then
					room.trainer = nil
				else
					seen[room.trainer] = true
				end
			end
		end
	end
	-- cosmetics
	for id in pairs(d.cosmetics.owned) do
		if not Cosmetics.byId[id] then
			d.cosmetics.owned[id] = nil
		end
	end
	for kind, id in pairs(d.cosmetics.equipped) do
		if kind == "deco" then
			if type(id) ~= "table" then
				d.cosmetics.equipped.deco = nil
			end
		elseif type(id) ~= "string" or not d.cosmetics.owned[id] then
			d.cosmetics.equipped[kind] = nil
		end
	end
	-- receipts list stays bounded (the permanent record lives in the receipt store)
	if type(d.purchases.receipts) ~= "table" then
		d.purchases.receipts = {}
	end
	while #d.purchases.receipts > 50 do
		table.remove(d.purchases.receipts, 1)
	end
	for k, v in pairs(d.stats) do
		d.stats[k] = num(v, 0, BIG, 0)
	end
	d.trainerCount = nil
	return d, trainerCount
end

return Schema
