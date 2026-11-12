-- Trainer generation, scouting (cash, published odds), the daily gem market
-- (fixed offers and prices, no randomness at purchase) and trainer upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RNG = require(Shared.Modules.RNG)
local Util = require(Shared.Modules.Util)
local Formulas = require(Shared.Modules.Formulas)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)
local Economy = require(script.Parent.Economy)

local TrainerGen = {}

local function rarityOrder(id)
	return Trainers.rarityById[id].order
end

function TrainerGen.rollRarity(rng)
	local weights = {}
	for _, r in ipairs(Trainers.rarities) do
		weights[r.id] = r.odds
	end
	return Util.weightedKey(weights, rng:next())
end

local function rollAbility(rng, rarityId)
	local order = rarityOrder(rarityId)
	if order < 2 then
		return nil
	end
	local pool = {}
	for _, a in ipairs(Trainers.abilities) do
		if a.minRarity <= order and a.minRarity >= order - 2 then
			table.insert(pool, a.id)
		end
	end
	return rng:pick(pool)
end

-- Builds a trainer record (without uid).
function TrainerGen.generate(rng, disciplineId, rarityId)
	local disc = Disciplines.byId[disciplineId]
	local culture = Trainers.cultureByOrigin[disc.origin] or "usa"
	-- a third of trainers come from elsewhere: academies are international
	if rng:chance(0.33) then
		culture = rng:pick(Util.keys(Trainers.names))
	end
	local pool = Trainers.names[culture]
	local first = rng:pick(pool.first)
	local last = rng:pick(pool.last)
	local specs = {}
	for _, s in ipairs(Trainers.specializations) do
		table.insert(specs, s.id)
	end
	return {
		name = first .. " " .. last,
		discipline = disciplineId,
		rarity = rarityId,
		level = 1,
		xp = 0,
		upgrade = 0,
		spec = rng:pick(specs),
		ability = rollAbility(rng, rarityId),
		seed = rng:int(1, 2147483646),
	}
end

function TrainerGen.fromMaster(masterId)
	local m = Trainers.masterById[masterId]
	return {
		name = m.name,
		title = m.title,
		master = m.id,
		discipline = m.discipline,
		rarity = m.rarity,
		level = 1,
		xp = 0,
		upgrade = 0,
		spec = m.spec,
		ability = m.ability,
		seed = RNG.hash(m.id),
	}
end

function TrainerGen.add(d, record)
	local uid = "t" .. d.nextTrainerId
	d.nextTrainerId = d.nextTrainerId + 1
	record.uid = uid
	d.trainers[uid] = record
	d.stats.trainersHired = d.stats.trainersHired + 1
	return uid, record
end

function TrainerGen.rosterSize(d)
	return Util.count(d.trainers)
end

function TrainerGen.ownsMaster(d, masterId)
	for _, t in pairs(d.trainers) do
		if t.master == masterId then
			return true
		end
	end
	return false
end

-- Scout a trainer for a discipline with cash. Odds are listed in Trainers.rarities.
function TrainerGen.scout(d, rng, disciplineId)
	if not Disciplines.byId[disciplineId] then
		return false, "Unknown discipline"
	end
	if not d.disciplines[disciplineId] then
		return false, "Discipline locked"
	end
	if TrainerGen.rosterSize(d) >= Trainers.ROSTER_LIMIT then
		return false, "Roster full (" .. Trainers.ROSTER_LIMIT .. "). Release a trainer first"
	end
	local cost = Formulas.scoutCost(d.level)
	if d.tokens and d.tokens.scout > 0 then
		-- recruitment token from missions: a free scouting
		d.tokens.scout = d.tokens.scout - 1
		cost = 0
	elseif not Economy.spend(d, cost) then
		return false, "Not enough cash"
	end
	local rarity = TrainerGen.rollRarity(rng)
	local record
	if rarity == "mythic" then
		-- mythic scouting results are legendary-stat masters with mythic rarity
		record = TrainerGen.generate(rng, disciplineId, "mythic")
	elseif rarity == "legendary" and rng:chance(Trainers.LEGENDARY_MASTER_SHARE) then
		local masterId
		for _, m in ipairs(Trainers.masters) do
			if m.discipline == disciplineId and not m.premium then
				masterId = m.id
			end
		end
		if masterId and not TrainerGen.ownsMaster(d, masterId) then
			record = TrainerGen.fromMaster(masterId)
		end
	end
	if not record then
		record = TrainerGen.generate(rng, disciplineId, rarity)
	end
	local uid = TrainerGen.add(d, record)
	return true, { uid = uid, trainer = record, cost = cost }
end

-- Today's market: same offers for everyone on a given day (seeded by day).
function TrainerGen.marketOffers(dayNumber, unlocked)
	local rng = RNG.new(dayNumber * 7919 + 17)
	local disciplines = {}
	for _, disc in ipairs(Disciplines.list) do
		if unlocked[disc.id] then
			table.insert(disciplines, disc.id)
		end
	end
	local offers = {}
	local rarities = { "uncommon", "rare", "epic", "rare", "legendary" }
	for i = 1, Trainers.MARKET_SIZE do
		local discId = rng:pick(disciplines)
		local rarity = rarities[rng:int(1, #rarities)]
		local record = TrainerGen.generate(rng, discId, rarity)
		table.insert(offers, { index = i, trainer = record, price = Trainers.rarityById[rarity].gemPrice })
	end
	return offers
end

function TrainerGen.buyMarket(d, dayNumber, index)
	local offers = TrainerGen.marketOffers(dayNumber, d.disciplines)
	local offer = offers[index]
	if not offer then
		return false, "Offer not available"
	end
	local key = tostring(dayNumber) .. ":" .. tostring(index)
	d.flags.market = d.flags.market or {}
	if d.flags.market[key] then
		return false, "Already recruited today"
	end
	if TrainerGen.rosterSize(d) >= Trainers.ROSTER_LIMIT then
		return false, "Roster full"
	end
	if not Economy.spendGems(d, offer.price) then
		return false, "Not enough gems"
	end
	-- keep only today's purchase flags
	for k in pairs(d.flags.market) do
		if string.sub(k, 1, #tostring(dayNumber)) ~= tostring(dayNumber) then
			d.flags.market[k] = nil
		end
	end
	d.flags.market[key] = true
	local uid = TrainerGen.add(d, offer.trainer)
	return true, { uid = uid, trainer = offer.trainer, price = offer.price }
end

function TrainerGen.train(d, uid)
	local t = d.trainers[uid]
	if not t then
		return false, "Unknown trainer"
	end
	if t.upgrade >= Formulas.trainerMaxUpgrade(t) then
		return false, "Fully trained"
	end
	local cost = Formulas.trainerTrainCost(t)
	if not Economy.spend(d, cost) then
		return false, "Not enough cash"
	end
	t.upgrade = t.upgrade + 1
	return true, { cost = cost, upgrade = t.upgrade }
end

function TrainerGen.release(d, uid, assignedCheck)
	local t = d.trainers[uid]
	if not t then
		return false, "Unknown trainer"
	end
	if t.master == "m_premium" then
		return false, "Premium trainers cannot be released"
	end
	if assignedCheck(uid) then
		return false, "Unassign the trainer first"
	end
	d.trainers[uid] = nil
	return true
end

-- Class experience for a trainer; returns new level if they levelled up.
function TrainerGen.addXp(t, amount)
	local r = Trainers.rarityById[t.rarity]
	t.xp = t.xp + amount
	local leveled = nil
	while t.level < r.maxLevel and t.xp >= Formulas.trainerXpForLevel(t.level) do
		t.xp = t.xp - Formulas.trainerXpForLevel(t.level)
		t.level = t.level + 1
		leveled = t.level
	end
	return leveled
end

return TrainerGen
