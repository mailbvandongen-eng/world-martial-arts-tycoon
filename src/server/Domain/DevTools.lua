-- Developer tools: direct changes to a save for testing (cities, rooms,
-- upgrade levels, trainers, students, money, missions) and ready-made
-- scenarios. Pure Lua; the service layer checks who may use it and puts the
-- player in sandbox mode so real progress is never overwritten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local RNG = require(Shared.Modules.RNG)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Trainers = require(Shared.Config.Trainers)
local Progression = require(Shared.Config.Progression)
local Schema = require(script.Parent.Schema)
local Academy = require(script.Parent.Academy)
local TrainerGen = require(script.Parent.TrainerGen)
local Activities = require(script.Parent.Activities)

local DevTools = {}

local function clampInt(v, lo, hi)
	v = tonumber(v)
	if not v or v ~= v then
		return nil
	end
	return math.floor(Util.clamp(v, lo, hi))
end

function DevTools.setValue(d, key, value)
	if key == "cash" then
		d.cash = clampInt(value, 0, 1e15) or d.cash
	elseif key == "gems" then
		d.gems = clampInt(value, 0, 1e9) or d.gems
	elseif key == "level" then
		d.level = clampInt(value, 1, Progression.MAX_LEVEL) or d.level
		d.xp = 0
	elseif key == "reputation" then
		d.reputation = clampInt(value, 0, 1e12) or d.reputation
		d.stats.maxReputation = math.max(d.stats.maxReputation, d.reputation)
	elseif key == "register" then
		d.register = clampInt(value, 0, 1e15) or d.register
	else
		return false, "Unknown value"
	end
	return true
end

function DevTools.unlockCity(d, cityId, switch)
	if not Cities.byId[cityId] then
		return false, "Unknown city"
	end
	-- unlock every earlier city too, so the city order stays valid
	for _, c in ipairs(Cities.list) do
		if not d.cities[c.id] then
			d.cities[c.id] = Schema.newBranch()
		end
		if c.id == cityId then
			break
		end
	end
	if switch then
		d.activeCity = cityId
	end
	return true
end

function DevTools.unlockDiscipline(d, id)
	if id == "all" then
		for _, disc in ipairs(Disciplines.list) do
			d.disciplines[disc.id] = true
		end
		return true
	end
	if not Disciplines.byId[id] then
		return false, "Unknown discipline"
	end
	d.disciplines[id] = true
	return true
end

function DevTools.setMastery(d, id, rank)
	local list = id == "all" and Disciplines.list or { Disciplines.byId[id] }
	if not list[1] then
		return false, "Unknown discipline"
	end
	for _, disc in ipairs(list) do
		d.mastery[disc.id] = { rank = Util.clamp(rank, 1, #disc.ranks), xp = 0 }
	end
	return true
end

-- Build (or replace) a room instantly, at any level, without cost.
function DevTools.placeRoom(d, cityId, slot, roomId, level)
	local def = Rooms.byId[roomId]
	if not def or def.kind == "reception" then
		return false, "Unknown room"
	end
	if not d.cities[cityId] then
		return false, "City not unlocked"
	end
	if slot < 1 or slot > 20 then
		return false, "Invalid slot"
	end
	if def.discipline and def.discipline ~= "fitness" then
		d.disciplines[def.discipline] = true
	end
	local old = d.cities[cityId].rooms[tostring(slot)]
	d.cities[cityId].rooms[tostring(slot)] = { id = roomId, level = Util.clamp(level, 1, Rooms.MAX_LEVEL), tier = 1, trainer = old and old.trainer or nil }
	local room = d.cities[cityId].rooms[tostring(slot)]
	room.tier = Academy.maxTier(d, roomId, room.level)
	return true
end

function DevTools.setAllRoomLevels(d, cityId, level)
	for _, room in pairs(d.cities[cityId].rooms) do
		room.level = Util.clamp(level, 1, Rooms.MAX_LEVEL)
		room.buildEnd = nil
		room.buildStart = nil
		room.tier = Academy.maxTier(d, room.id, room.level)
	end
	return true
end

function DevTools.clearRooms(d, cityId)
	local branch = d.cities[cityId]
	for slot in pairs(branch.rooms) do
		if slot ~= "0" then
			branch.rooms[slot] = nil
		end
	end
	return true
end

-- Add a trainer and, when possible, put them in an empty matching room.
function DevTools.addTrainer(d, rng, disciplineId, rarityId, cityId)
	if not Disciplines.byId[disciplineId] or not Trainers.rarityById[rarityId] then
		return false, "Unknown discipline or rarity"
	end
	local uid = TrainerGen.add(d, TrainerGen.generate(rng, disciplineId, rarityId))
	local branch = d.cities[cityId]
	for slot, room in pairs(branch.rooms) do
		local def = Rooms.byId[room.id]
		if def.needsTrainer and not room.trainer and (def.kind ~= "training" or def.discipline == disciplineId) then
			Academy.assignTrainer(d, cityId, tonumber(slot), uid)
			break
		end
	end
	return true, uid
end

-- Give every trainer-less room a trainer of the right discipline.
function DevTools.staffAll(d, rng, cityId, rarityId)
	local branch = d.cities[cityId]
	for slot, room in pairs(branch.rooms) do
		local def = Rooms.byId[room.id]
		if def.needsTrainer and not room.trainer then
			local disc = def.kind == "training" and def.discipline or "karate"
			local uid = TrainerGen.add(d, TrainerGen.generate(rng, disc, rarityId))
			Academy.assignTrainer(d, cityId, tonumber(slot), uid)
		end
	end
	return true
end

function DevTools.addStudents(d, rng, disciplineId, count, rank)
	if not Disciplines.byId[disciplineId] then
		return false, "Unknown discipline"
	end
	for _ = 1, Util.clamp(count, 1, 40) do
		local s = Activities.newStudent(d, rng, disciplineId, rng:int(1, 2147483000))
		s.rank = Util.clamp(rank or 1, 1, #Disciplines.byId[disciplineId].ranks)
	end
	return true
end

-- Every student (optionally of one discipline) is ready for a belt exam now.
function DevTools.examReadyAll(d, disciplineId)
	local n = 0
	for _, s in pairs(d.students) do
		if not disciplineId or s.discipline == disciplineId then
			local cap = #Disciplines.byId[s.discipline].ranks
			if s.rank < cap then
				s.examReady = true
				s.waited = 0
				s.examAt = nil
				n = n + 1
			end
			d.mastery[s.discipline] = d.mastery[s.discipline] or { rank = 1, xp = 0 }
			d.mastery[s.discipline].rank = math.max(d.mastery[s.discipline].rank, math.min(cap, s.rank + 1))
		end
	end
	return true, n
end

-- Opponent level of your own kumite (1-20) and no cooldowns.
function DevTools.setKumiteLevel(d, level)
	level = clampInt(level, 1, 20) or 1
	d.compete.kumiteWins = level - 1
	d.compete.kumiteLosses = 0
	d.compete.lastKumite = 0
	d.compete.lastSpar = 0
	return true
end

function DevTools.completeMissions(d)
	for _, list in ipairs({ d.quests.daily, d.quests.weekly }) do
		for _, q in ipairs(list) do
			q.progress = q.target
		end
	end
	return true
end

function DevTools.rerollMissions(d)
	d.quests.day = -1
	d.quests.week = -1
	return true
end

function DevTools.resetDaily(d)
	d.daily.lastDay = -1
	d.minigame.lastAt = 0
	d.minigame.plays = 0
	d.flags.arenaReadyAt = 0
	return true
end

-- Fill the active city with every available room type at a level.
function DevTools.fillAcademy(d, rng, level, rarityId)
	local cityId = d.activeCity
	local slots = Academy.slotCount(d, cityId)
	local order = { "karate_room", "boxing_room", "judo_room", "sumo_room", "locker_room", "fitness_room", "juice_bar", "showers",
		"restrooms", "strength_room", "cardio_room", "kickboxing_room", "muaythai_room", "taekwondo_room", "bjj_room", "mma_room",
		"recovery_room", "vip_room", "coaching_room", "arena" }
	DevTools.clearRooms(d, cityId)
	for slot = 1, slots do
		local id = order[slot]
		if id then
			DevTools.placeRoom(d, cityId, slot, id, level)
		end
	end
	DevTools.staffAll(d, rng, cityId, rarityId or "rare")
	return true
end

-- Ready-made scenarios. Returns a fresh save table (the caller swaps it in).
function DevTools.scenario(id, seed)
	local rng = RNG.new(seed or 1)
	local d = Schema.validate(Schema.defaults())
	d.flags.hasPlot = true
	d.flags.collectedOnce = true
	d.flags.defaultOutfitGiven = true
	if id == "new" then
		return d
	elseif id == "early" then
		DevTools.setValue(d, "level", 6)
		d.cash = 15000
		d.reputation = 400
		for _, disc in ipairs({ "karate", "boxing", "judo" }) do
			d.disciplines[disc] = true
		end
		DevTools.setMastery(d, "karate", 2)
		DevTools.placeRoom(d, "smalltown", 1, "karate_room", 2)
		DevTools.placeRoom(d, "smalltown", 2, "boxing_room", 2)
		DevTools.placeRoom(d, "smalltown", 3, "judo_room", 2)
		DevTools.placeRoom(d, "smalltown", 4, "locker_room", 1)
		DevTools.staffAll(d, rng, "smalltown", "uncommon")
		DevTools.addStudents(d, rng, "karate", 8, 2)
	elseif id == "mid" then
		DevTools.setValue(d, "level", 18)
		d.cash = 800000
		d.gems = 2000
		d.reputation = 6000
		DevTools.unlockCity(d, "london", true)
		for _, disc in ipairs({ "karate", "boxing", "judo", "kickboxing", "muaythai", "taekwondo", "bjj" }) do
			d.disciplines[disc] = true
		end
		DevTools.setMastery(d, "all", 4)
		DevTools.fillAcademy(d, rng, 3, "rare")
		DevTools.addStudents(d, rng, "karate", 10, 3)
		DevTools.addStudents(d, rng, "boxing", 6, 3)
	elseif id == "late" then
		DevTools.setValue(d, "level", 45)
		d.cash = 5e9
		d.gems = 20000
		d.reputation = 500000
		DevTools.unlockDiscipline(d, "all")
		DevTools.unlockCity(d, "lasvegas", true)
		DevTools.setMastery(d, "all", 99)
		DevTools.fillAcademy(d, rng, 5, "legendary")
		for _, disc in ipairs({ "karate", "boxing", "judo", "sumo" }) do
			DevTools.addStudents(d, rng, disc, 6, 6)
		end
	elseif id == "karate_full" then
		DevTools.setValue(d, "level", 25)
		d.cash = 1e7
		d.reputation = 20000
		DevTools.setMastery(d, "karate", 9)
		DevTools.placeRoom(d, "smalltown", 1, "karate_room", 5)
		DevTools.placeRoom(d, "smalltown", 2, "karate_room", 5)
		DevTools.placeRoom(d, "smalltown", 3, "locker_room", 5)
		DevTools.placeRoom(d, "smalltown", 4, "juice_bar", 5)
		d.cities.smalltown.rooms["0"].level = 5
		DevTools.staffAll(d, rng, "smalltown", "legendary")
		DevTools.addStudents(d, rng, "karate", 30, 4)
	elseif id == "tournament" then
		DevTools.setValue(d, "level", 30)
		d.cash = 1e8
		d.reputation = 50000
		DevTools.unlockDiscipline(d, "all")
		DevTools.setMastery(d, "all", 6)
		DevTools.fillAcademy(d, rng, 4, "epic")
	else
		return nil
	end
	return d
end

return DevTools
