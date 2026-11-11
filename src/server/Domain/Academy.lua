-- Academy management: rooms, construction, trainers in rooms, disciplines,
-- cities, the cash register. Every function validates its input and returns
-- ok (boolean) plus an error message or a result table. Pure (no Roblox APIs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local Formulas = require(Shared.Modules.Formulas)
local Layout = require(Shared.Modules.Layout)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Progression = require(Shared.Config.Progression)
local Customers = require(Shared.Config.Customers)
local Economy = require(script.Parent.Economy)

local Academy = {}

local UNIQUE_KINDS = { amenity = true, shop = true, arena = true, coaching = true, vip = true }
local MAX_SAME_TRAINING_ROOM = 2

function Academy.branch(d, cityId)
	return d.cities[cityId or d.activeCity]
end

function Academy.slotCount(d, cityId)
	local city = Cities.byId[cityId]
	return math.min(Layout.MAX_SLOTS, city.slots + Economy.extraSlots(d))
end

function Academy.isBuilding(room, now)
	return room.buildEnd ~= nil and room.buildEnd > now
end

function Academy.room(d, cityId, slot)
	local branch = d.cities[cityId]
	if not branch then
		return nil
	end
	return branch.rooms[tostring(slot)]
end

function Academy.findTrainerRoom(d, uid)
	for cityId, branch in pairs(d.cities) do
		for slot, room in pairs(branch.rooms) do
			if room.trainer == uid then
				return cityId, slot, room
			end
		end
	end
	return nil
end

function Academy.countRooms(branch, roomId)
	local n = 0
	for _, room in pairs(branch.rooms) do
		if room.id == roomId then
			n = n + 1
		end
	end
	return n
end

-- Highest class tier a room can run right now.
function Academy.maxTier(d, roomId, level)
	local def = Rooms.byId[roomId]
	local best = 1
	for _, tier in ipairs(Disciplines.tiers) do
		local okLevel = level >= tier.roomLevel
		local okRank = true
		if def.discipline and def.discipline ~= "fitness" then
			local disc = Disciplines.byId[def.discipline]
			local m = d.mastery[def.discipline]
			local rank = m and m.rank or 1
			okRank = rank >= Disciplines.tierRankRequirement(disc, tier.id)
		end
		if okLevel and okRank then
			best = tier.id
		end
	end
	return best
end

local function checkCity(d, cityId)
	if type(cityId) ~= "string" or not Cities.byId[cityId] then
		return false, "Unknown city"
	end
	if not d.cities[cityId] then
		return false, "City not unlocked"
	end
	return true
end

local function checkSlot(d, cityId, slot)
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return false, "Invalid slot"
	end
	if slot < 1 or slot > Academy.slotCount(d, cityId) then
		return false, "Slot not available"
	end
	return true
end

function Academy.canBuild(d, cityId, slot, roomId)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	ok, err = checkSlot(d, cityId, slot)
	if not ok then
		return false, err
	end
	local def = Rooms.byId[roomId]
	if not def or def.kind == "reception" then
		return false, "Unknown room"
	end
	local branch = d.cities[cityId]
	if branch.rooms[tostring(slot)] then
		return false, "Slot is not empty"
	end
	if def.discipline and def.discipline ~= "fitness" and not d.disciplines[def.discipline] then
		return false, "Unlock " .. Disciplines.byId[def.discipline].name .. " first"
	end
	if d.level < def.unlockLevel then
		return false, "Requires level " .. def.unlockLevel
	end
	local count = Academy.countRooms(branch, roomId)
	if UNIQUE_KINDS[def.kind] and count >= 1 then
		return false, "Only one " .. def.name .. " per academy"
	end
	if def.kind == "training" and count >= MAX_SAME_TRAINING_ROOM then
		return false, "Max " .. MAX_SAME_TRAINING_ROOM .. " of this room per academy"
	end
	local cost = Formulas.roomBuildCost(roomId, cityId)
	if not Economy.canAfford(d, cost) then
		return false, "Not enough cash"
	end
	return true, cost
end

function Academy.build(d, ctx, cityId, slot, roomId)
	local ok, costOrErr = Academy.canBuild(d, cityId, slot, roomId)
	if not ok then
		return false, costOrErr
	end
	Economy.spend(d, costOrErr)
	local room = { id = roomId, level = 1, tier = 1, buildStart = ctx.now, buildEnd = ctx.now + Formulas.buildTime(roomId, 1) }
	d.cities[cityId].rooms[tostring(slot)] = room
	d.stats.roomsBuilt = d.stats.roomsBuilt + 1
	return true, { cost = costOrErr, room = room }
end

function Academy.upgrade(d, ctx, cityId, slot)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	if type(slot) ~= "number" then
		return false, "Invalid slot"
	end
	local room = d.cities[cityId].rooms[tostring(slot)]
	if not room then
		return false, "No room there"
	end
	if Academy.isBuilding(room, ctx.now) then
		return false, "Still under construction"
	end
	if room.level >= Rooms.MAX_LEVEL then
		return false, "Already max level"
	end
	local cost = Formulas.roomUpgradeCost(room.id, room.level, cityId)
	if not Economy.spend(d, cost) then
		return false, "Not enough cash"
	end
	room.level = room.level + 1
	room.buildStart = ctx.now
	room.buildEnd = ctx.now + Formulas.buildTime(room.id, room.level)
	d.stats.roomsUpgraded = d.stats.roomsUpgraded + 1
	return true, { cost = cost, level = room.level }
end

-- Removing a room refunds 40% of its build cost. Reception cannot be removed.
function Academy.remove(d, ctx, cityId, slot)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	local key = tostring(slot)
	local room = d.cities[cityId].rooms[key]
	if not room or room.id == "reception" then
		return false, "Nothing to remove"
	end
	local refund = math.floor(Formulas.roomBuildCost(room.id, cityId) * 0.4)
	d.cities[cityId].rooms[key] = nil
	d.cash = d.cash + refund
	return true, { refund = refund }
end

-- Clears finished construction; returns list of {cityId, slot}.
function Academy.finishConstruction(d, now)
	local done = {}
	for cityId, branch in pairs(d.cities) do
		for slot, room in pairs(branch.rooms) do
			if room.buildEnd and room.buildEnd <= now then
				room.buildEnd = nil
				room.buildStart = nil
				table.insert(done, { cityId = cityId, slot = slot, room = room })
			end
		end
	end
	return done
end

function Academy.instantFinish(d)
	local n = 0
	for _, branch in pairs(d.cities) do
		for _, room in pairs(branch.rooms) do
			if room.buildEnd then
				room.buildEnd = 0
				n = n + 1
			end
		end
	end
	return n
end

function Academy.assignTrainer(d, cityId, slot, uid)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	local room = d.cities[cityId].rooms[tostring(slot)]
	if not room then
		return false, "No room there"
	end
	local def = Rooms.byId[room.id]
	if not def.needsTrainer then
		return false, "This room does not use a trainer"
	end
	local t = d.trainers[uid]
	if not t then
		return false, "Unknown trainer"
	end
	if def.kind == "training" and t.discipline ~= def.discipline then
		return false, "Needs a " .. Disciplines.byId[def.discipline].name .. " trainer"
	end
	local _, oldSlot, oldRoom = Academy.findTrainerRoom(d, uid)
	if oldRoom then
		oldRoom.trainer = nil
	end
	local previous = room.trainer
	room.trainer = uid
	return true, { previous = previous, movedFrom = oldSlot }
end

function Academy.unassign(d, cityId, slot)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	local room = d.cities[cityId].rooms[tostring(slot)]
	if not room or not room.trainer then
		return false, "No trainer assigned"
	end
	room.trainer = nil
	return true
end

function Academy.setTier(d, cityId, slot, tier)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	local room = d.cities[cityId].rooms[tostring(slot)]
	if not room then
		return false, "No room there"
	end
	local def = Rooms.byId[room.id]
	if def.kind ~= "training" then
		return false, "This room has no classes"
	end
	if type(tier) ~= "number" or tier < 1 or tier > 5 or tier ~= math.floor(tier) then
		return false, "Invalid class"
	end
	if tier > Academy.maxTier(d, room.id, room.level) then
		return false, "Class locked (needs mastery rank or room level)"
	end
	room.tier = tier
	return true
end

function Academy.unlockDiscipline(d, disciplineId)
	local disc = Disciplines.byId[disciplineId]
	if not disc then
		return false, "Unknown discipline"
	end
	if d.disciplines[disciplineId] then
		return false, "Already unlocked"
	end
	if d.level < disc.unlock.level then
		return false, "Requires level " .. disc.unlock.level
	end
	if not Economy.spend(d, disc.unlock.cost) then
		return false, "Not enough cash"
	end
	d.disciplines[disciplineId] = true
	Economy.masteryOf(d, disciplineId)
	return true, { cost = disc.unlock.cost }
end

function Academy.cityRequirements(d, cityId)
	local city = Cities.byId[cityId]
	local prev = Cities.list[city.order - 1]
	return {
		level = d.level >= city.unlock.level,
		reputation = d.reputation >= city.unlock.reputation,
		cash = d.cash >= city.unlock.cost,
		previous = prev == nil or d.cities[prev.id] ~= nil,
	}
end

function Academy.unlockCity(d, cityId)
	local city = Cities.byId[cityId]
	if not city then
		return false, "Unknown city"
	end
	if d.cities[cityId] then
		return false, "Already unlocked"
	end
	local req = Academy.cityRequirements(d, cityId)
	if not req.previous then
		return false, "Unlock the previous city first"
	end
	if not req.level then
		return false, "Requires level " .. city.unlock.level
	end
	if not req.reputation then
		return false, "Requires " .. city.unlock.reputation .. " reputation"
	end
	if not Economy.spend(d, city.unlock.cost) then
		return false, "Not enough cash"
	end
	d.cities[cityId] = {
		rooms = { ["0"] = { id = "reception", level = 1 } },
		members = 0,
	}
	return true, { cost = city.unlock.cost }
end

function Academy.switchCity(d, cityId)
	local ok, err = checkCity(d, cityId)
	if not ok then
		return false, err
	end
	d.activeCity = cityId
	return true
end

-- Moves the register into the balance. Returns amount collected.
function Academy.collect(d)
	local amount = math.floor(d.register)
	if amount <= 0 then
		return 0
	end
	d.register = d.register - amount
	d.cash = d.cash + amount
	d.flags.collectedOnce = true
	return amount
end

function Academy.registerCap(d)
	local branch = d.cities[d.activeCity]
	local rec = branch.rooms["0"]
	return Formulas.registerCap(rec and rec.level or 1, d.activeCity)
end

-- Adds class income to the register; overflow beyond the cap is lost
-- (unless auto-collect is active, see PlayerService). Returns amount kept.
function Academy.addToRegister(d, amount)
	local cap = Academy.registerCap(d)
	local space = math.max(0, cap - d.register)
	local kept = math.min(space, amount)
	d.register = d.register + kept
	d.stats.totalEarned = d.stats.totalEarned + kept
	return kept
end

function Academy.buyAutomation(d)
	local nextLevel = d.automation + 1
	local def = Progression.automation[nextLevel]
	if not def then
		return false, "Fully automated"
	end
	if d.level < def.unlockLevel then
		return false, "Requires level " .. def.unlockLevel
	end
	if not Economy.spend(d, def.cost) then
		return false, "Not enough cash"
	end
	d.automation = nextLevel
	return true, { name = def.name }
end

-- Satisfaction bonus from amenities in a branch (finished ones only).
function Academy.amenityBonus(d, cityId, now)
	local branch = d.cities[cityId]
	local bonus = 0
	for _, room in pairs(branch.rooms) do
		local def = Rooms.byId[room.id]
		if def.kind == "amenity" and not Academy.isBuilding(room, now) then
			bonus = bonus + def.satisfaction * (1 + 0.25 * (room.level - 1))
		end
	end
	return bonus
end

function Academy.trainerStatsInRoom(d, room)
	if not room.trainer then
		return nil
	end
	local t = d.trainers[room.trainer]
	if not t then
		return nil
	end
	return Formulas.trainerStats(t), t
end

-- Can this room run classes right now?
function Academy.roomOperational(d, room, now)
	local def = Rooms.byId[room.id]
	if Academy.isBuilding(room, now) then
		return false
	end
	if def.kind ~= "training" and def.kind ~= "coaching" and def.kind ~= "vip" then
		return false
	end
	if def.needsTrainer and not room.trainer then
		return false
	end
	return true
end

-- Discipline a room teaches (coaching/vip rooms teach their trainer's discipline).
function Academy.roomDiscipline(d, room)
	local def = Rooms.byId[room.id]
	if def.kind == "training" then
		return def.discipline
	end
	if room.trainer and d.trainers[room.trainer] then
		return d.trainers[room.trainer].discipline
	end
	return nil
end

function Academy.totalCapacity(d, cityId, now)
	local branch = d.cities[cityId]
	local total = 0
	for _, room in pairs(branch.rooms) do
		if Academy.roomOperational(d, room, now) then
			local stats = Academy.trainerStatsInRoom(d, room)
			total = total + Formulas.roomCapacity(room.id, room.level, stats)
		end
	end
	return total
end

function Academy.expensesPerDay(d, cityId)
	local city = Cities.byId[cityId]
	local branch = d.cities[cityId]
	local salaries, maintenance = 0, 0
	for _, room in pairs(branch.rooms) do
		local def = Rooms.byId[room.id]
		maintenance = maintenance + math.floor(def.cost * 0.004 * room.level * Formulas.cityBuildMult(cityId))
		if room.trainer and d.trainers[room.trainer] then
			salaries = salaries + Formulas.trainerStats(d.trainers[room.trainer]).salary * math.sqrt(city.incomeMult)
		end
	end
	salaries = math.floor(salaries)
	-- rent grows with the floor space in use, so a fresh branch is not a money pit
	local used = 0
	for slot in pairs(branch.rooms) do
		if slot ~= "0" then
			used = used + 1
		end
	end
	local rent = math.floor(city.rentPerDay * math.min(1, (used + 1) / (city.slots + 1)))
	return { rent = rent, salaries = salaries, maintenance = maintenance, total = rent + salaries + maintenance }
end

-- Rough theoretical earnings per hour of a branch (used for passive income of
-- branches you are not managing, for offline earnings and for cash pack size).
function Academy.estimateHourly(d, ctx, cityId)
	local branch = d.cities[cityId]
	local rec = branch.rooms["0"]
	local interval = Formulas.spawnInterval(rec and rec.level or 1, d.reputation, 1)
	local visitorsPerHour = 3600 / interval
	local classIncome = 0
	local seats = 0
	for _, room in pairs(branch.rooms) do
		if Academy.roomOperational(d, room, ctx.now) then
			local def = Rooms.byId[room.id]
			local stats = Academy.trainerStatsInRoom(d, room)
			local cap = Formulas.roomCapacity(room.id, room.level, stats)
			local info = Formulas.classInfo(room.id, room.tier or 1)
			local disc = Academy.roomDiscipline(d, room) or "fitness"
			local mult = Economy.classMult(d, ctx, disc, cityId) * (def.payMult or 1)
			local speed = stats and stats.speed or 1
			local revenueMult = stats and stats.revenue or 1
			-- one class cycle ~ duration / speed + 6 s turnover
			local perSeatHour = 3600 / (info.duration / speed + 6)
			classIncome = classIncome + cap * perSeatHour * info.pay * 1.3 * mult * revenueMult
			seats = seats + cap * perSeatHour
		end
	end
	if seats <= 0 then
		return 0
	end
	-- visitor flow limits how full rooms get
	local fill = math.min(1, visitorsPerHour / seats)
	local hourly = classIncome * fill
	local dues = branch.members * Customers.MEMBER_DUES * (3600 / Progression.DAY_SECONDS) * Cities.byId[cityId].incomeMult
	local expenses = Academy.expensesPerDay(d, cityId).total * (3600 / Progression.DAY_SECONDS)
	return math.max(0, hourly + dues - expenses)
end

function Academy.estimateAllHourly(d, ctx)
	local total = 0
	for cityId in pairs(d.cities) do
		local h = Academy.estimateHourly(d, ctx, cityId)
		if cityId ~= d.activeCity then
			h = h * Progression.PASSIVE_BRANCH_RATE
		end
		total = total + h
	end
	return total
end

function Academy.unlockedCityCount(d)
	return Util.count(d.cities)
end

return Academy
