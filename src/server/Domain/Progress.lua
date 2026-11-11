-- Missions, daily login rewards, seasonal event progress, cosmetics,
-- rebirth and the "next objective" guide. Pure Lua.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local RNG = require(Shared.Modules.RNG)
local Formulas = require(Shared.Modules.Formulas)
local Quests = require(Shared.Config.Quests)
local Progression = require(Shared.Config.Progression)
local Cosmetics = require(Shared.Config.Cosmetics)
local Cities = require(Shared.Config.Cities)
local Events = require(Shared.Config.Events)
local Schema = require(script.Parent.Schema)
local Economy = require(script.Parent.Economy)
local Academy = require(script.Parent.Academy)

local Progress = {}

---------------------------------------------------------------- missions

local function questTarget(def, level)
	local target = def.target
	if def.scale then
		target = target + math.floor(def.scale * (level - 1))
	end
	if def.scaleMoney then
		target = Formulas.rewardCashUnit(level) * 5
	end
	return target
end

local function rollQuests(pool, count, seed, level)
	local rng = RNG.new(seed)
	local ids = {}
	for _, q in ipairs(pool) do
		table.insert(ids, q.id)
	end
	local chosen = {}
	for _ = 1, math.min(count, #ids) do
		local i = rng:int(1, #ids)
		local id = table.remove(ids, i)
		local def = Quests.byId[id]
		table.insert(chosen, { id = id, target = questTarget(def, level), progress = 0, claimed = false })
	end
	return chosen
end

-- Make sure today's and this week's missions exist. userId makes the pick personal.
function Progress.refreshQuests(d, now, userId)
	local day = Util.dayNumber(now)
	local week = Util.weekNumber(now)
	local changed = false
	if d.quests.day ~= day then
		d.quests.day = day
		d.quests.daily = rollQuests(Quests.daily, Quests.DAILY_COUNT, day * 131 + (userId % 100000), d.level)
		changed = true
	end
	if d.quests.week ~= week then
		d.quests.week = week
		d.quests.weekly = rollQuests(Quests.weekly, Quests.WEEKLY_COUNT, week * 977 + (userId % 100000), d.level)
		changed = true
	end
	return changed
end

-- Increment a tracked stat; returns list of quest entries that just completed.
function Progress.track(d, track, amount)
	local done = {}
	for _, list in ipairs({ d.quests.daily, d.quests.weekly }) do
		for _, q in ipairs(list) do
			local def = Quests.byId[q.id]
			if def and def.track == track and q.progress < q.target then
				q.progress = math.min(q.target, q.progress + amount)
				if q.progress >= q.target then
					table.insert(done, q)
				end
			end
		end
	end
	return done
end

function Progress.claimQuest(d, period, index)
	local list = period == "weekly" and d.quests.weekly or d.quests.daily
	local q = list[index]
	if not q then
		return false, "Unknown mission"
	end
	if q.claimed then
		return false, "Already claimed"
	end
	if q.progress < q.target then
		return false, "Not complete yet"
	end
	local def = Quests.byId[q.id]
	q.claimed = true
	local cash = math.floor(def.reward.cash * Formulas.rewardCashUnit(d.level))
	Economy.earn(d, cash)
	d.gems = d.gems + (def.reward.gems or 0)
	local levels = Economy.addXp(d, Progression.xp.missionCompleted)
	return true, { cash = cash, gems = def.reward.gems or 0, levels = levels }
end

---------------------------------------------------------------- daily login

function Progress.dailyStatus(d, now)
	local today = Util.dayNumber(now)
	local available = d.daily.lastDay ~= today
	local streak = d.daily.streak
	if d.daily.lastDay < today - 1 then
		streak = 0 -- missed a day: cycle restarts
	end
	local nextDay = (streak % #Progression.daily) + 1
	return { available = available, nextDay = nextDay, streak = streak, today = today }
end

function Progress.claimDaily(d, now)
	local st = Progress.dailyStatus(d, now)
	if not st.available then
		return false, "Come back tomorrow"
	end
	local reward = Progression.daily[st.nextDay]
	d.daily.lastDay = st.today
	d.daily.streak = st.streak + 1
	local result = { day = st.nextDay, cash = 0, gems = reward.gems or 0 }
	if reward.cash then
		result.cash = math.floor(reward.cash * math.max(1, Formulas.rewardCashUnit(d.level) / 400))
		Economy.earn(d, result.cash)
	end
	d.gems = d.gems + (reward.gems or 0)
	if reward.boost then
		Economy.addBoost(d, reward.boost, reward.minutes, now)
		result.boost = reward.boost
		result.minutes = reward.minutes
	end
	if reward.cosmetic then
		if d.cosmetics.owned[reward.cosmetic] then
			-- already owned: compensate with gems instead of a duplicate
			d.gems = d.gems + 100
			result.gems = result.gems + 100
		else
			d.cosmetics.owned[reward.cosmetic] = true
			result.cosmetic = reward.cosmetic
		end
	end
	return true, result
end

---------------------------------------------------------------- events

function Progress.eventKey(event, now)
	local year = math.floor(1970 + now / 31556952)
	return event.id .. "-" .. tostring(year)
end

function Progress.addEventPoints(d, event, now, amount)
	local key = Progress.eventKey(event, now)
	if d.event.key ~= key then
		d.event = { key = key, points = 0, claimed = {} }
	end
	d.event.points = d.event.points + amount
end

function Progress.claimEventReward(d, event, now, index)
	local key = Progress.eventKey(event, now)
	if d.event.key ~= key then
		return false, "No progress in this event yet"
	end
	local reward = event.rewards[index]
	if not reward then
		return false, "Unknown reward"
	end
	if d.event.claimed[tostring(index)] then
		return false, "Already claimed"
	end
	if d.event.points < reward.points then
		return false, "Not enough event points"
	end
	d.event.claimed[tostring(index)] = true
	if reward.cosmetic then
		d.cosmetics.owned[reward.cosmetic] = true
	end
	if reward.gems then
		d.gems = d.gems + reward.gems
	end
	return true, reward
end

---------------------------------------------------------------- cosmetics

function Progress.cosmeticAvailable(d, c)
	if c.source == "default" then
		return true
	elseif c.source == "level" then
		return d.level >= c.level
	elseif c.source == "rebirth" then
		return d.rebirths >= c.rebirths
	elseif c.source == "pass" then
		return Economy.hasPass(d, c.pass)
	end
	return false
end

-- Grants all cosmetics unlocked by level / rebirth / pass. Returns new ids.
function Progress.syncCosmetics(d)
	local new = {}
	for _, c in ipairs(Cosmetics.list) do
		if not d.cosmetics.owned[c.id] and Progress.cosmeticAvailable(d, c) then
			d.cosmetics.owned[c.id] = true
			table.insert(new, c.id)
		end
	end
	return new
end

function Progress.buyCosmetic(d, id)
	local c = Cosmetics.byId[id]
	if not c then
		return false, "Unknown item"
	end
	if d.cosmetics.owned[id] then
		return false, "Already owned"
	end
	if c.source == "gems" then
		if not Economy.spendGems(d, c.price) then
			return false, "Not enough gems"
		end
	elseif c.source == "cash" then
		if not Economy.spend(d, c.price) then
			return false, "Not enough cash"
		end
	else
		return false, "Not for sale"
	end
	d.cosmetics.owned[id] = true
	return true
end

Progress.MAX_DECOS = 4

function Progress.equipCosmetic(d, id, on)
	local c = Cosmetics.byId[id]
	if not c or not d.cosmetics.owned[id] then
		return false, "Not owned"
	end
	local eq = d.cosmetics.equipped
	if c.kind == "deco" then
		eq.deco = eq.deco or {}
		local idx = Util.find(eq.deco, id)
		if on and not idx then
			if #eq.deco >= Progress.MAX_DECOS then
				return false, "Max " .. Progress.MAX_DECOS .. " decorations"
			end
			table.insert(eq.deco, id)
		elseif not on and idx then
			table.remove(eq.deco, idx)
		end
	else
		if on then
			eq[c.kind] = id
		elseif eq[c.kind] == id then
			eq[c.kind] = nil
		end
	end
	return true
end

---------------------------------------------------------------- rebirth

function Progress.canRebirth(d)
	local rb = Progression.rebirth
	if d.level < rb.minLevel then
		return false, "Requires level " .. rb.minLevel
	end
	if Academy.unlockedCityCount(d) < rb.minCities then
		return false, "Requires " .. rb.minCities .. " cities"
	end
	return true
end

function Progress.rebirth(d)
	local ok, err = Progress.canRebirth(d)
	if not ok then
		return false, err
	end
	local fresh = Schema.defaults()
	-- reset
	d.cash = fresh.cash
	d.level = 1
	d.xp = 0
	d.reputation = 0
	d.register = 0
	d.automation = 0
	d.disciplines = { karate = true }
	d.activeCity = Cities.START
	-- rooms reset; trainers stay in the roster (unassigned except the starter room)
	d.cities = { [Cities.START] = Schema.newBranch() }
	d.cities[Cities.START].rooms["1"] = { id = "karate_room", level = 1, tier = 1 }
	for uid, t in pairs(d.trainers) do
		if t.discipline == "karate" then
			d.cities[Cities.START].rooms["1"].trainer = uid
			break
		end
	end
	-- keep: gems, trainers, mastery, cosmetics, purchases, stats
	d.rebirths = d.rebirths + 1
	d.gems = d.gems + Progression.rebirth.gemsReward
	local titles = Progression.rebirth.titles
	local title = titles[math.min(d.rebirths, #titles)]
	d.flags.prestigeTitle = title
	local newCosmetics = Progress.syncCosmetics(d)
	return true, { rebirths = d.rebirths, title = title, cosmetics = newCosmetics }
end

---------------------------------------------------------------- objective guide

local function checkObjective(d, check)
	local kind, arg = string.match(check, "^(%w+):?(.*)$")
	if kind == "hasPlot" then
		return d.flags.hasPlot == true
	elseif kind == "collectedOnce" then
		return d.flags.collectedOnce == true
	elseif kind == "discipline" then
		return d.disciplines[arg] == true
	elseif kind == "room" then
		for _, branch in pairs(d.cities) do
			for _, room in pairs(branch.rooms) do
				if room.id == arg then
					return true
				end
			end
		end
		return false
	elseif kind == "assigned" then
		for _, branch in pairs(d.cities) do
			for _, room in pairs(branch.rooms) do
				if room.trainer and d.trainers[room.trainer] and d.trainers[room.trainer].discipline == arg and room.id == arg .. "_room" then
					return true
				end
			end
		end
		return false
	elseif kind == "roomLevel" then
		local need = tonumber(arg)
		for _, branch in pairs(d.cities) do
			for slot, room in pairs(branch.rooms) do
				if slot ~= "0" and room.level >= need then
					return true
				end
			end
		end
		return false
	elseif kind == "city" then
		return d.cities[arg] ~= nil
	elseif kind == "level" then
		return d.level >= tonumber(arg)
	elseif kind == "rebirths" then
		return d.rebirths >= tonumber(arg)
	end
	return false
end

function Progress.currentObjective(d)
	for i, o in ipairs(Quests.objectives) do
		if not checkObjective(d, o.check) then
			return { index = i, id = o.id, text = o.text, total = #Quests.objectives }
		end
	end
	return nil
end

-- Active event for a unix time.
function Progress.activeEvent(now)
	return Events.active({ month = tonumber(os.date("!%m", now)), day = tonumber(os.date("!%d", now)) })
end

return Progress
