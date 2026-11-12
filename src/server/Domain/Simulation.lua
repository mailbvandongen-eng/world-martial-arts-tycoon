-- Visitor simulation for the branch a player is managing. The server plans a
-- complete visit when a visitor arrives (which room, which class, wait time,
-- satisfaction, payment) and settles it when the class ends. Clients only
-- receive the plan and animate it. Pure Lua: time and randomness come in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Util = require(Shared.Modules.Util)
local Formulas = require(Shared.Modules.Formulas)
local Layout = require(Shared.Modules.Layout)
local Visits = require(Shared.Modules.Visits)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Customers = require(Shared.Config.Customers)
local Trainers = require(Shared.Config.Trainers)
local Monetization = require(Shared.Config.Monetization)
local Progression = require(Shared.Config.Progression)
local Events = require(Shared.Config.Events)
local Academy = require(script.Parent.Academy)
local Economy = require(script.Parent.Economy)
local TrainerGen = require(script.Parent.TrainerGen)

local Simulation = {}

local SESSION_BREAK = 4

function Simulation.new(cityId, now)
	return {
		cityId = cityId,
		rooms = {}, -- slotKey -> { cycleStart, seats = { [sessionStart] = count } }
		deskFree = now,
		queue = 0, -- people waiting at the desk (visual queue index)
		active = {}, -- id -> plan
		activeCount = 0,
		pending = {}, -- plans waiting for settlement, sorted by tEnd
		nextId = 1,
		spawnTimer = 0,
		lost = {}, -- discipline -> visitors that found no room (demand info)
		lostTotal = 0,
		served = 0,
		satisfactionSum = 0,
		sessionsCounted = {},
	}
end

local function sessionPeriod(duration)
	return duration + SESSION_BREAK
end

-- Visitor category weights given reputation and city.
function Simulation.categoryWeights(d, cityId)
	local city = Cities.byId[cityId]
	local w = {}
	for _, c in ipairs(Customers.list) do
		if d.reputation >= c.minRep then
			w[c.id] = c.weight * (city.categories[c.id] or 1)
		end
	end
	return w
end

-- Interest weights: city demand, boosted by famous trainers. Disciplines the
-- academy cannot serve still appear (that is the "unserved demand").
function Simulation.interestWeights(d, cityId, now)
	local city = Cities.byId[cityId]
	local served = {}
	local branch = d.cities[cityId]
	local demandBonus = {}
	local hasFitness = false
	for _, room in pairs(branch.rooms) do
		if Academy.roomOperational(d, room, now) then
			local disc = Academy.roomDiscipline(d, room)
			if disc then
				served[disc] = true
				if disc == "fitness" then
					hasFitness = true
				end
				local stats = Academy.trainerStatsInRoom(d, room)
				if stats and stats.demand > 0 then
					demandBonus[disc] = (demandBonus[disc] or 0) + stats.demand
				end
			end
		end
	end
	local w = {}
	for _, disc in ipairs(Disciplines.list) do
		local base = city.demand[disc.id] or 1
		if not served[disc.id] then
			base = base * 0.1
		end
		w[disc.id] = base * (1 + (demandBonus[disc.id] or 0))
	end
	w.fitness = hasFitness and 2 or 0.15
	return w
end

-- Choose a room for an interest/category. Returns slotKey, room, def.
local function chooseRoom(d, sim, category, interest, now)
	local branch = d.cities[sim.cityId]
	local best, bestScore
	for slotKey, room in pairs(branch.rooms) do
		if slotKey ~= "0" and Academy.roomOperational(d, room, now) then
			local def = Rooms.byId[room.id]
			local disc = Academy.roomDiscipline(d, room)
			local fits = disc == interest
			if fits and (def.kind == "vip") and not category.vip then
				fits = false
			end
			if fits and def.kind == "coaching" and category.order < 4 then
				fits = false
			end
			if fits then
				local score = room.level - tonumber(slotKey) * 0.001
				if category.prefers and def.kind == category.prefers then
					score = score + 100
				elseif def.kind == "coaching" or def.kind == "vip" then
					score = score + 50
				end
				if not best or score > bestScore then
					best, bestScore = slotKey, score
				end
			end
		end
	end
	if best then
		return best, branch.rooms[best], Rooms.byId[branch.rooms[best].id]
	end
	return nil
end

local function pickAmenity(d, sim, rng, now)
	local branch = d.cities[sim.cityId]
	local options = {}
	for slotKey, room in pairs(branch.rooms) do
		local def = Rooms.byId[room.id]
		if (def.kind == "amenity" or def.kind == "shop") and not Academy.isBuilding(room, now) then
			table.insert(options, { slot = tonumber(slotKey), room = room, def = def })
		end
	end
	table.sort(options, function(a, b)
		return a.slot < b.slot
	end)
	if #options == 0 or not rng:chance(0.55) then
		return nil
	end
	return rng:pick(options)
end

-- Find the first session in a room at or after `readyAt` with a free seat.
local function findSession(sim, slotKey, readyAt, duration, capacity, maxWait)
	local r = sim.rooms[slotKey]
	if not r then
		r = { cycleStart = readyAt, seats = {} }
		sim.rooms[slotKey] = r
	end
	local period = sessionPeriod(duration)
	-- if the room was idle, restart its schedule so classes begin promptly
	local k = math.ceil((readyAt - r.cycleStart) / period)
	if k < 0 then
		k = 0
	end
	local lastKey = r.cycleStart + (k - 1) * period
	if (r.seats[lastKey] or 0) == 0 and (r.seats[r.cycleStart + k * period] or 0) == 0 then
		local idleSince = r.cycleStart + k * period
		if idleSince - readyAt > 1 then
			r.cycleStart = readyAt
			r.seats = {}
			k = 0
		end
	end
	for _ = 1, 6 do
		local start = r.cycleStart + k * period
		local taken = r.seats[start] or 0
		if start - readyAt > maxWait then
			return nil
		end
		if taken < capacity then
			r.seats[start] = taken + 1
			return start, taken + 1
		end
		k = k + 1
	end
	return nil
end

-- Garbage-collect old session seat counts.
local function pruneSessions(sim, now)
	for _, r in pairs(sim.rooms) do
		for start in pairs(r.seats) do
			if start < now - 120 then
				r.seats[start] = nil
			end
		end
	end
end

-- Plans a visit. ctx = { now, event }. Returns plan (always; outcome may be "leave").
function Simulation.planVisit(d, sim, ctx, rng)
	local now = ctx.now
	local cityId = sim.cityId
	local city = Cities.byId[cityId]
	local catId = Util.weightedKey(Simulation.categoryWeights(d, cityId), rng:next()) or "beginner"
	local category = Customers.byId[catId]
	local interest
	if category.fitnessBias and rng:chance(category.fitnessBias) then
		interest = "fitness"
	else
		interest = Util.weightedKey(Simulation.interestWeights(d, cityId, now), rng:next())
	end

	local id = sim.nextId
	sim.nextId = sim.nextId + 1
	sim.queue = sim.queue + 1
	local queueIndex = ((sim.queue - 1) % 12) + 1
	local plan = {
		id = id,
		seed = rng:int(1, 2147483646),
		category = catId,
		interest = interest,
		t0 = now,
		queue = queueIndex,
	}
	if category.celebrity then
		plan.name = rng:pick(Customers.celebrityNames)
	end

	-- reception desk service
	local recRoom = d.cities[cityId].rooms["0"]
	local recLevel = recRoom and recRoom.level or 1
	local tDesk = now + Layout.walkTime(Visits.toDesk(queueIndex))
	local service = Visits.DESK_SERVICE / (1 + 0.3 * (recLevel - 1))
	local tStart = math.max(tDesk, sim.deskFree)
	sim.deskFree = tStart + service
	plan.tDeskDone = tStart + service
	local deskWait = tStart - tDesk

	local slotKey, room, def = chooseRoom(d, sim, category, interest, now)
	if not slotKey or deskWait > category.patience then
		plan.outcome = "leave"
		plan.reason = slotKey and "queue" or "no_room"
		if not slotKey then
			sim.lost[interest] = (sim.lost[interest] or 0) + 1
			sim.lostTotal = sim.lostTotal + 1
		end
		local _, tEnd = Visits.timeline(plan)
		plan.tExit = tEnd
		return plan
	end

	local slot = tonumber(slotKey)
	local stats, trainer = Academy.trainerStatsInRoom(d, room)
	local capacity = Formulas.roomCapacity(room.id, room.level, stats)
	local tierId = room.tier or 1
	if def.kind ~= "training" then
		-- coaching / vip rooms teach the best tier their trainer's discipline allows
		tierId = math.max(category.minTier, 3)
	end
	tierId = Util.clamp(tierId, 1, 5)
	local info = Formulas.classInfo(def.kind == "training" and room.id or ((plan.interest or "karate") .. "_room"), tierId)
	local speed = stats and stats.speed or 1
	if Economy.boostActive(d, "training", now) then
		speed = speed * Monetization.boosts.training.speedMult
	end
	local duration = info.duration / speed

	local tDoor = plan.tDeskDone + Layout.walkTime(Visits.deskToDoor(queueIndex, slot))
	local spotWalk = 1.5
	local sessionStart, seat = findSession(sim, slotKey, tDoor + spotWalk + 1, duration, capacity, category.patience)
	if not sessionStart then
		plan.outcome = "leave"
		plan.reason = "full"
		sim.lost[interest] = (sim.lost[interest] or 0) + 1
		sim.lostTotal = sim.lostTotal + 1
		local _, tEnd = Visits.timeline(plan)
		plan.tExit = tEnd
		return plan
	end

	plan.outcome = "train"
	plan.slot = slot
	plan.spot = seat
	plan.tSession = sessionStart
	plan.tEnd = sessionStart + duration
	plan.classTier = tierId
	plan.className = info.name
	plan.roomKind = def.kind
	plan.trainer = room.trainer

	local amenity = pickAmenity(d, sim, rng, now)
	if amenity then
		plan.amenitySlot = amenity.slot
		if amenity.def.kind == "shop" and rng:chance(amenity.def.shopChance) then
			plan.shopSpend = amenity.def.shopSpend * (1 + 0.3 * (amenity.room.level - 1))
		end
	end

	-- satisfaction
	local waitSeconds = deskWait + math.max(0, sessionStart - tDoor - spotWalk - 3)
	local tierMatch = tierId >= category.minTier and tierId <= category.maxTier
	local sat = Formulas.visitSatisfaction({
		trainerSatisfaction = stats and stats.satisfaction or 0,
		roomLevel = room.level,
		amenityBonus = Academy.amenityBonus(d, cityId, now),
		premiumBonus = Economy.premiumSatisfaction(d) + (def.kind == "vip" and 8 or def.kind == "coaching" and 5 or 0),
		waitSeconds = waitSeconds,
		patience = category.patience,
		expectation = category.expectation,
		tierMatch = tierMatch,
	})
	plan.satisfaction = math.floor(sat + 0.5)

	-- rank shown on the visitor (belt colour): up to the academy's mastery
	local discId = plan.interest
	local disc = Disciplines.byId[discId]
	if disc then
		local m = d.mastery[discId]
		local maxRank = m and m.rank or 1
		local bias = (category.order - 1) / (#Customers.list - 1)
		-- skewed: most visitors are beginners (white/yellow), high grades are rare
		-- and mostly worn by advanced, professional and VIP visitors
		local u = rng:next() ^ 2.5
		plan.rank = Util.clamp(1 + math.floor(u * maxRank * (0.6 + 0.6 * bias)), 1, maxRank)
	end

	-- payment (credited at tEnd)
	local mult = Economy.classMult(d, ctx, discId, cityId) * (def.payMult or 1)
	local revenue = stats and stats.revenue or 1
	if stats and stats.spec then
		local s = stats.spec
		if tierId >= s.tiers[1] and tierId <= s.tiers[2] then
			revenue = revenue + s.bonus
		end
	end
	plan.pay = Formulas.classPayment(info.pay, category.spend, sat, mult * revenue)
	if plan.shopSpend then
		plan.shopPay = plan.shopSpend * category.spend * city.incomeMult * Economy.globalMult(d, ctx)
	end
	plan.mastery = info.xp * (stats and stats.mastery or 1)
	if Economy.boostActive(d, "training", now) then
		plan.mastery = plan.mastery * Monetization.boosts.training.masteryMult
	end
	if ctx.event and ctx.event.masteryBonus and ctx.event.masteryBonus[discId] then
		plan.mastery = plan.mastery * ctx.event.masteryBonus[discId]
	end
	plan.sessionKey = slotKey .. "@" .. tostring(math.floor(sessionStart * 10))

	local _, tExit = Visits.timeline(plan)
	plan.tExit = tExit
	return plan
end

-- Called on the server tick. Spawns visitors when due. Returns new plans.
function Simulation.step(d, sim, ctx, rng, dt)
	local now = ctx.now
	local plans = {}
	-- people leave the desk queue over time
	if sim.deskFree < now then
		sim.queue = 0
	end
	local branch = d.cities[sim.cityId]
	local rec = branch.rooms["0"]
	local spawnMult = 1 + math.min(1, branch.members / 200) * 0.5
	if Economy.boostActive(d, "customers", now) then
		spawnMult = spawnMult * Monetization.boosts.customers.spawnMult
	end
	local interval = Formulas.spawnInterval(rec and rec.level or 1, d.reputation, spawnMult)
	local maxVisitors = Formulas.maxVisitors(Academy.totalCapacity(d, sim.cityId, now))
	sim.spawnTimer = sim.spawnTimer + dt
	local spawned = 0
	while sim.spawnTimer >= interval and spawned < 3 do
		sim.spawnTimer = sim.spawnTimer - interval
		if sim.activeCount < maxVisitors then
			local plan = Simulation.planVisit(d, sim, ctx, rng)
			sim.active[plan.id] = plan
			sim.activeCount = sim.activeCount + 1
			if plan.outcome == "train" then
				table.insert(sim.pending, plan)
			end
			table.insert(plans, plan)
			spawned = spawned + 1
		end
	end
	if sim.spawnTimer > interval then
		sim.spawnTimer = interval
	end
	-- remove visitors that have left
	for id, plan in pairs(sim.active) do
		if plan.tExit <= now then
			sim.active[id] = nil
			sim.activeCount = sim.activeCount - 1
		end
	end
	pruneSessions(sim, now)
	return plans
end

-- Settles every class that ended. Returns a list of results for the service
-- layer (notifications, quests). Mutates the save data.
function Simulation.settle(d, sim, ctx, rng)
	local now = ctx.now
	local results = {}
	local i = 1
	while i <= #sim.pending do
		local plan = sim.pending[i]
		if plan.tEnd <= now then
			table.remove(sim.pending, i)
			table.insert(results, Simulation.settleOne(d, sim, ctx, rng, plan))
		else
			i = i + 1
		end
	end
	return results
end

function Simulation.settleOne(d, sim, ctx, rng, plan)
	local now = ctx.now
	local res = { plan = plan, cash = 0, rankUps = {}, levels = {}, newClass = false }
	local branch = d.cities[sim.cityId]
	-- income goes to the register at reception
	local kept = Academy.addToRegister(d, plan.pay + (plan.shopPay or 0))
	res.cash = kept
	res.overflow = (plan.pay + (plan.shopPay or 0)) - kept
	d.stats.studentsServed = d.stats.studentsServed + 1
	if plan.satisfaction >= 90 then
		d.stats.happyStudents = d.stats.happyStudents + 1
		res.happy = true
	end
	sim.served = sim.served + 1
	sim.satisfactionSum = sim.satisfactionSum + plan.satisfaction
	-- class completion (once per session)
	if not sim.sessionsCounted[plan.sessionKey] then
		sim.sessionsCounted[plan.sessionKey] = now
		d.stats.classesCompleted = d.stats.classesCompleted + 1
		res.newClass = true
		if plan.trainer and d.trainers[plan.trainer] then
			res.trainerLevel = TrainerGen.addXp(d.trainers[plan.trainer], Trainers.XP_PER_CLASS)
		end
	end
	for key, t in pairs(sim.sessionsCounted) do
		if t < now - 300 then
			sim.sessionsCounted[key] = nil
		end
	end
	-- reputation, xp, mastery
	local category = Customers.byId[plan.category]
	local repDelta = Formulas.reputationDelta(plan.satisfaction, category.spend)
	Economy.addReputation(d, repDelta)
	res.reputation = repDelta
	local xp = Progression.xp.studentServed + (res.newClass and Progression.xp.classCompleted or 0)
	res.levels, res.gems = Economy.addXp(d, xp)
	if Disciplines.byId[plan.interest] then
		res.rankUps = Economy.addMastery(d, plan.interest, plan.mastery)
		res.masteryXp = plan.mastery
	end
	-- membership
	if plan.satisfaction >= Customers.MEMBER_THRESHOLD and rng:chance(Customers.MEMBER_CHANCE) then
		local cap = Academy.totalCapacity(d, sim.cityId, now) * Customers.MEMBERS_PER_CAPACITY
		if branch.members < cap then
			branch.members = branch.members + 1
			res.newMember = true
		end
	end
	-- event points
	if ctx.event then
		res.eventPoints = Events.POINTS_PER_CLASS
	end
	return res
end

-- Business day: membership dues, churn, expenses, passive income of other branches.
function Simulation.businessDay(d, ctx, avgSatisfaction)
	local report = { dues = 0, expenses = 0, passive = 0, unpaid = 0, churn = 0 }
	for cityId, branch in pairs(d.cities) do
		local city = Cities.byId[cityId]
		if cityId == d.activeCity then
			local dues = branch.members * Customers.MEMBER_DUES * city.incomeMult * Economy.globalMult(d, ctx)
			report.dues = report.dues + dues
			local churnRate = 0.02 + math.max(0, 70 - (avgSatisfaction or 70)) * 0.002
			local churn = math.floor(branch.members * churnRate + 0.5)
			branch.members = math.max(0, branch.members - churn)
			report.churn = report.churn + churn
			report.expenses = report.expenses + Academy.expensesPerDay(d, cityId).total
		else
			local hourly = Academy.estimateHourly(d, ctx, cityId) * Progression.PASSIVE_BRANCH_RATE
			report.passive = report.passive + hourly * Progression.DAY_SECONDS / 3600
		end
	end
	Economy.earn(d, report.dues + report.passive)
	local pay = math.min(d.cash, report.expenses)
	d.cash = d.cash - pay
	report.unpaid = report.expenses - pay
	return report
end

-- Average satisfaction of settled visits since the last call.
function Simulation.takeAverageSatisfaction(sim)
	if sim.served == 0 then
		return nil
	end
	local avg = sim.satisfactionSum / sim.served
	sim.served = 0
	sim.satisfactionSum = 0
	return avg
end

return Simulation
