-- Money, XP, levels, reputation, mastery and income multipliers.
-- Pure functions on the save table `d`; `ctx` carries the clock and active
-- effects: { now = unix seconds, event = event config or nil }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local Formulas = require(Shared.Modules.Formulas)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Progression = require(Shared.Config.Progression)
local Monetization = require(Shared.Config.Monetization)

local Economy = {}

function Economy.hasPass(d, key)
	return d.purchases.passes[key] == true
end

function Economy.boostActive(d, kind, now)
	local untilTime = d.boosts[kind]
	return untilTime ~= nil and untilTime > now
end

function Economy.addBoost(d, kind, minutes, now)
	local current = d.boosts[kind]
	local start = (current and current > now) and current or now
	d.boosts[kind] = start + minutes * 60
end

function Economy.canAfford(d, amount)
	return Util.isFiniteNumber(amount) and amount >= 0 and d.cash >= amount
end

function Economy.spend(d, amount)
	if not Economy.canAfford(d, amount) then
		return false
	end
	d.cash = d.cash - amount
	return true
end

function Economy.spendGems(d, amount)
	if not Util.isFiniteNumber(amount) or amount < 0 or d.gems < amount then
		return false
	end
	d.gems = d.gems - amount
	return true
end

-- Adds earned cash (counts towards stats and missions). Returns the amount.
function Economy.earn(d, amount)
	if not Util.isFiniteNumber(amount) or amount <= 0 then
		return 0
	end
	d.cash = d.cash + amount
	d.stats.totalEarned = d.stats.totalEarned + amount
	return amount
end

-- Add XP; returns a list of levels reached (may be empty) and gems granted.
function Economy.addXp(d, amount)
	local reached = {}
	local gems = 0
	if not Util.isFiniteNumber(amount) or amount <= 0 then
		return reached, gems
	end
	d.xp = d.xp + amount
	while d.level < Progression.MAX_LEVEL and d.xp >= Progression.xpForLevel(d.level) do
		d.xp = d.xp - Progression.xpForLevel(d.level)
		d.level = d.level + 1
		local g = d.level * Progression.GEMS_PER_LEVEL
		if d.level % 5 == 0 then
			g = g * 2
		end
		gems = gems + g
		table.insert(reached, d.level)
	end
	if d.level >= Progression.MAX_LEVEL then
		d.xp = math.min(d.xp, Progression.xpForLevel(d.level))
	end
	d.gems = d.gems + gems
	return reached, gems
end

function Economy.addReputation(d, delta)
	d.reputation = math.max(0, d.reputation + delta)
	if d.reputation > d.stats.maxReputation then
		d.stats.maxReputation = d.reputation
	end
end

function Economy.masteryOf(d, disciplineId)
	local m = d.mastery[disciplineId]
	if not m then
		m = { rank = 1, xp = 0 }
		d.mastery[disciplineId] = m
	end
	return m
end

-- Add mastery XP to a discipline; returns list of new rank indexes.
function Economy.addMastery(d, disciplineId, amount)
	local disc = Disciplines.byId[disciplineId]
	local ups = {}
	if not disc or not Util.isFiniteNumber(amount) or amount <= 0 then
		return ups
	end
	local m = Economy.masteryOf(d, disciplineId)
	m.xp = m.xp + amount
	while m.rank < #disc.ranks and m.xp >= Formulas.masteryXpForRank(m.rank) do
		m.xp = m.xp - Formulas.masteryXpForRank(m.rank)
		m.rank = m.rank + 1
		table.insert(ups, m.rank)
	end
	if m.rank >= #disc.ranks then
		m.xp = 0
	end
	return ups
end

-- Number of disciplines at their top rank.
function Economy.masteredCount(d)
	local n = 0
	for id, m in pairs(d.mastery) do
		local disc = Disciplines.byId[id]
		if disc and m.rank >= #disc.ranks then
			n = n + 1
		end
	end
	return n
end

-- Multiplier from passes, boosts, rebirths (applies to all income).
function Economy.globalMult(d, ctx)
	local m = Formulas.rebirthMult(d.rebirths)
	if Economy.hasPass(d, "double_cash") then
		m = m * 2
	end
	if Economy.boostActive(d, "cash", ctx.now) then
		m = m * Monetization.boosts.cash.cashMult
	end
	return m
end

-- Full multiplier for class income of a discipline in a city.
function Economy.classMult(d, ctx, disciplineId, cityId)
	local city = Cities.byId[cityId]
	local m = Economy.globalMult(d, ctx) * city.incomeMult * (city.bonus[disciplineId] or 1)
	local event = ctx.event
	if event and event.bonus then
		m = m * (event.bonus[disciplineId] or event.bonus.all or 1)
		if event.cityBonus then
			m = m * (event.cityBonus[cityId] or 1)
		end
	end
	for _, pass in ipairs(Monetization.gamePasses) do
		local e = pass.effect
		if e and e.discipline == disciplineId and e.revenue and Economy.hasPass(d, pass.key) then
			m = m * (1 + e.revenue)
		end
	end
	return m
end

-- Flat satisfaction from premium equipment passes.
function Economy.premiumSatisfaction(d)
	local s = 0
	for _, pass in ipairs(Monetization.gamePasses) do
		local e = pass.effect
		if e and e.satisfaction and Economy.hasPass(d, pass.key) then
			s = s + e.satisfaction
		end
	end
	return s
end

function Economy.extraSlots(d)
	local p = Monetization.passByKey.extra_slot
	if Economy.hasPass(d, "extra_slot") then
		return p.effect.extraSlots
	end
	return 0
end

return Economy
