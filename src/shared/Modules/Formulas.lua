-- All balance formulas in one place. Used by the server (authoritative) and by
-- the client (only to display prices and previews).

local Config = script.Parent.Parent.Config
local Disciplines = require(Config.Disciplines)
local Rooms = require(Config.Rooms)
local Cities = require(Config.Cities)
local Trainers = require(Config.Trainers)
local Progression = require(Config.Progression)
local Stations = require(script.Parent.Stations)

local Formulas = {}

local function floor(x)
	return math.floor(x + 1e-9)
end

-- Building costs grow slower than city income, so a new city is a step up.
function Formulas.cityBuildMult(cityId)
	local city = Cities.byId[cityId]
	if not city or city.order == 1 then
		return 1
	end
	return city.incomeMult * 0.7
end

function Formulas.roomBuildCost(roomId, cityId)
	local def = Rooms.byId[roomId]
	return floor(def.cost * Formulas.cityBuildMult(cityId))
end

-- Cost to upgrade from `level` to `level + 1`.
function Formulas.roomUpgradeCost(roomId, level, cityId)
	local def = Rooms.byId[roomId]
	local base = math.max(def.cost, 300)
	return floor(base * 1.6 * 2.1 ^ (level - 1) * Formulas.cityBuildMult(cityId))
end

-- Construction time in seconds.
function Formulas.buildTime(roomId, level)
	local def = Rooms.byId[roomId]
	local t = 6 + math.log(math.max(def.cost, 1) + 1, 10) * 3 + (level - 1) * 4
	return floor(math.min(t, 60))
end

function Formulas.roomCapacity(roomId, level, trainerStats)
	local def = Rooms.byId[roomId]
	local cap = (def.capacity or 0) + (def.capacityPerLevel or 0) * (level - 1)
	if trainerStats then
		cap = cap + trainerStats.capacity
	end
	-- never more students than there are training positions in the room
	return math.min(cap, 24, Stations.count(roomId, level))
end

-- Trainer level from XP
function Formulas.trainerXpForLevel(level)
	return floor(40 * level ^ 1.45)
end

-- Effective trainer stats for a trainer record { rarity, level, upgrade, ability, spec }.
function Formulas.trainerStats(t)
	local r = Trainers.rarityById[t.rarity] or Trainers.rarities[1]
	local level = t.level or 1
	local upgrade = t.upgrade or 0
	local ability = t.ability and Trainers.abilityById[t.ability]
	local spec = t.spec and Trainers.specById[t.spec]
	local stats = {
		speed = r.speed * (1 + 0.006 * (level - 1) + 0.01 * upgrade),
		capacity = r.capacity + math.floor(upgrade / 4),
		satisfaction = r.satisfaction * (1 + 0.03 * (level - 1)) + upgrade * 0.5,
		salary = floor(r.salary * (1 + 0.06 * (level - 1) + 0.05 * upgrade)),
		revenue = 1 + 0.01 * (level - 1) + 0.02 * upgrade,
		mastery = 1,
		demand = 0,
	}
	if ability then
		stats.satisfaction = stats.satisfaction + (ability.satisfaction or 0)
		stats.speed = stats.speed * (1 + (ability.speed or 0))
		stats.capacity = stats.capacity + (ability.capacity or 0)
		stats.revenue = stats.revenue + (ability.revenue or 0)
		stats.mastery = stats.mastery + (ability.mastery or 0)
		stats.demand = stats.demand + (ability.demand or 0)
	end
	if spec and spec.speedBonus then
		stats.speed = stats.speed * (1 + spec.speedBonus)
	end
	stats.spec = spec
	return stats
end

-- Cash cost to train (upgrade) a trainer once.
function Formulas.trainerTrainCost(t)
	local r = Trainers.rarityById[t.rarity] or Trainers.rarities[1]
	return floor(Trainers.TRAIN_COST_BASE * r.order ^ 1.6 * 1.45 ^ (t.upgrade or 0))
end

function Formulas.trainerMaxUpgrade(t)
	local r = Trainers.rarityById[t.rarity] or Trainers.rarities[1]
	return math.floor(r.maxLevel / 2)
end

function Formulas.scoutCost(playerLevel)
	return floor(Trainers.SCOUT_BASE_COST * 1.2 ^ (playerLevel - 1))
end

-- Class definition for a discipline (or general fitness room) at a tier.
function Formulas.classInfo(roomId, tierId)
	local def = Rooms.byId[roomId]
	local tier = Disciplines.tiers[tierId] or Disciplines.tiers[1]
	local basePay
	local name
	if def.discipline == "fitness" then
		basePay = def.basePay or 7
		name = def.name .. " " .. tier.name
	else
		local d = Disciplines.byId[def.discipline]
		basePay = d and d.basePay or 6
		name = d and d.classes[tierId] or tier.name
	end
	return {
		name = name,
		tier = tierId,
		tierName = tier.name,
		pay = basePay * tier.payMult,
		duration = tier.duration,
		xp = tier.xp,
		roomLevel = tier.roomLevel,
	}
end

-- Mastery XP needed to go from rank r to r + 1.
function Formulas.masteryXpForRank(rank)
	return floor(120 * 2.35 ^ (rank - 1))
end

-- Satisfaction (0-100) of one visit.
--   p.trainerSatisfaction, p.roomLevel, p.amenityBonus, p.waitSeconds, p.patience,
--   p.expectation, p.tierMatch (bool), p.premiumBonus
function Formulas.visitSatisfaction(p)
	local s = 60
		+ (p.trainerSatisfaction or 0)
		+ (p.roomLevel or 1) * 4
		+ (p.amenityBonus or 0)
		+ (p.premiumBonus or 0)
	if p.tierMatch == false then
		s = s - 10
	end
	local waitShare = (p.waitSeconds or 0) / math.max(p.patience or 30, 1)
	s = s - waitShare * 25
	-- picky visitors judge harder
	s = s - math.max(0, (p.expectation or 50) - 50) * 0.35
	if s < 0 then
		s = 0
	elseif s > 100 then
		s = 100
	end
	return s
end

-- Payment for one completed class.
function Formulas.classPayment(classPay, spend, satisfaction, mult)
	return 2 * classPay * spend * (0.55 + satisfaction / 110) * (mult or 1)
end

-- Reputation change from one visit.
function Formulas.reputationDelta(satisfaction, categorySpend)
	local base = (satisfaction - 45) / 18
	return base * math.sqrt(categorySpend or 1)
end

function Formulas.rebirthMult(rebirths)
	return 1 + (rebirths or 0) * Progression.rebirth.incomeBonusPerRebirth
end

-- Mission cash unit: grows with level so missions matter all game long.
function Formulas.rewardCashUnit(level)
	return floor(400 * 1.24 ^ (math.max(level, 1) - 1))
end

-- Register capacity (cash waiting at reception before it stops filling).
function Formulas.registerCap(receptionLevel, cityId)
	local city = Cities.byId[cityId] or Cities.list[1]
	return floor(Progression.REGISTER_BASE_CAP * (1 + (receptionLevel - 1) * 0.8) * city.incomeMult)
end

-- Seconds between visitor arrivals on the active branch.
function Formulas.spawnInterval(receptionLevel, reputation, spawnMult)
	local recDef = Rooms.byId.reception
	local rate = 0.3 * (1 + (receptionLevel - 1) * recDef.spawnPerLevel) * (1 + math.log(1 + (reputation or 0) / 200, 10) * 0.6)
	rate = rate * (spawnMult or 1)
	return 1 / rate
end

-- Max visitors inside the academy at once (server-side cap, protects performance).
function Formulas.maxVisitors(totalCapacity)
	return math.min(40, 6 + totalCapacity)
end

function Formulas.cashPackAmount(product, hourlyIncome)
	local amount = (hourlyIncome or 0) * product.cashMinutes / 60
	return floor(math.max(product.cashMin, amount))
end

function Formulas.cityUnlockCost(cityId)
	return Cities.byId[cityId].unlock.cost
end

return Formulas
