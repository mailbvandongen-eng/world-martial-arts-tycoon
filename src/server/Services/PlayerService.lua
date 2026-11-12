-- Runtime of every player in the server: loads data, runs the academy
-- simulation of their active branch, settles classes, the business day,
-- automation, championships, missions/event tracking, and pushes state to
-- the client. The game loop runs here at 4 Hz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RNG = require(Shared.Modules.RNG)
local Util = require(Shared.Modules.Util)
local Remotes = require(Shared.Modules.Remotes)
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Progression = require(Shared.Config.Progression)
local Disciplines = require(Shared.Config.Disciplines)
local Cities = require(Shared.Config.Cities)
local Customers = require(Shared.Config.Customers)
local Rooms = require(Shared.Config.Rooms)
local Monetization = require(Shared.Config.Monetization)
local Events = require(Shared.Config.Events)
local DevConfig = require(Shared.Config.Dev)
local RunService = game:GetService("RunService")

local Domain = script.Parent.Parent.Domain
local Academy = require(Domain.Academy)
local Economy = require(Domain.Economy)
local Simulation = require(Domain.Simulation)
local Progress = require(Domain.Progress)
local TrainerGen = require(Domain.TrainerGen)
local Activities = require(Domain.Activities)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CosmeticService = require(script.Parent.CosmeticService)

local PlayerService = {}

local runtimes = {} -- [player] = rt
local stateRemote, visitorsRemote, notifyRemote
local TICK = 0.25
local AUTO_CLAIM_SECONDS = 45

local function serverNow()
	return workspace:GetServerTimeNow()
end

local eventCache = { at = -1 }
local eventOverride -- developer menu: force an event (config id) for testing
function PlayerService.setEventOverride(id)
	eventOverride = id
	eventCache.at = -1
end
local function activeEvent(now)
	if eventOverride then
		return Events.byId[eventOverride]
	end
	if now - eventCache.at > 60 then
		eventCache.at = now
		eventCache.event = Progress.activeEvent(now)
	end
	return eventCache.event
end

function PlayerService.ctx()
	local now = serverNow()
	return { now = now, event = activeEvent(now) }
end

function PlayerService.runtime(player)
	return runtimes[player]
end

function PlayerService.data(player)
	return DataService.get(player)
end

-- Developer access: listed user ids, the experience owner, or Roblox Studio.
function PlayerService.isDev(player)
	if RunService:IsStudio() or DevConfig.USER_IDS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

function PlayerService.markDirty(player)
	local rt = runtimes[player]
	if rt then
		rt.dirty = true
	end
end

function PlayerService.notify(player, kind, payload)
	notifyRemote:FireClient(player, kind, payload or {})
end

function PlayerService.notifyAll(kind, payload)
	notifyRemote:FireAllClients(kind, payload or {})
end

---------------------------------------------------------------- tracking helpers

-- Mission tracking + completion notification.
function PlayerService.track(player, track, amount)
	local d = DataService.get(player)
	if not d or amount <= 0 then
		return
	end
	local done = Progress.track(d, track, amount)
	for _, q in ipairs(done) do
		PlayerService.notify(player, "mission", { id = q.id })
	end
	if #done > 0 then
		PlayerService.markDirty(player)
	end
end

-- XP with level-up handling.
function PlayerService.giveXp(player, amount)
	local d = DataService.get(player)
	if not d then
		return
	end
	local levels, gems = Economy.addXp(d, amount)
	if #levels > 0 then
		PlayerService.notify(player, "levelup", { level = levels[#levels], gems = gems })
		local new = Progress.syncCosmetics(d)
		for _, id in ipairs(new) do
			PlayerService.notify(player, "cosmetic", { id = id })
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Level") then
			leaderstats.Level.Value = d.level
		end
	end
	PlayerService.markDirty(player)
end

function PlayerService.recordEarning(player, amount)
	local rt = runtimes[player]
	local d = DataService.get(player)
	if not rt or not d or amount <= 0 then
		return
	end
	table.insert(rt.earnLog, { t = serverNow(), a = amount })
	local day = Util.dayNumber(os.time())
	if d.flags.todayDay ~= day then
		d.flags.todayDay = day
		d.flags.todayEarned = 0
		d.flags.todayExpenses = 0
	end
	d.flags.todayEarned = (d.flags.todayEarned or 0) + amount
end

local function hourlyFromLog(rt, now)
	local sum = 0
	local i = 1
	while i <= #rt.earnLog do
		local e = rt.earnLog[i]
		if now - e.t > 300 then
			table.remove(rt.earnLog, i)
		else
			sum = sum + e.a
			i = i + 1
		end
	end
	local window = math.min(300, math.max(30, now - rt.joinedAt))
	return sum * 3600 / window
end

---------------------------------------------------------------- state snapshot

local function stripData(d)
	local copy = Util.shallowCopy(d)
	copy.purchases = { passes = d.purchases.passes, starter = d.purchases.starter }
	return copy
end

function PlayerService.buildState(player)
	local rt = runtimes[player]
	local d = DataService.get(player)
	if not rt or not d then
		return nil
	end
	local ctx = PlayerService.ctx()
	local now = ctx.now
	local day = Util.dayNumber(os.time())
	local event = ctx.event
	local derived = {
		plot = PlotService.plotOf(player),
		registerCap = Academy.registerCap(d),
		slotCounts = {},
		hourly = hourlyFromLog(rt, now),
		hourlyEstimate = Academy.estimateAllHourly(d, ctx),
		today = d.flags.todayDay == day and (d.flags.todayEarned or 0) or 0,
		todayExpenses = d.flags.todayDay == day and (d.flags.todayExpenses or 0) or 0,
		expenses = Academy.expensesPerDay(d, d.activeCity),
		members = 0,
		capacity = Academy.totalCapacity(d, d.activeCity, now),
		objective = Progress.currentObjective(d),
		daily = Progress.dailyStatus(d, os.time()),
		scoutCost = Formulas.scoutCost(d.level),
		market = TrainerGen.marketOffers(day, d.disciplines),
		marketDay = day,
		demand = rt.sim and rt.sim.lost or {},
		lostTotal = rt.sim and rt.sim.lostTotal or 0,
		avgSatisfaction = rt.avgSatisfaction,
		memoryMode = DataService.isMemoryMode(),
		dayEndsAt = rt.lastDay + Progression.DAY_SECONDS,
		champ = rt.champ and { endAt = rt.champ.endAt, discipline = rt.champ.discipline } or nil,
		eventKey = event and Progress.eventKey(event, now) or nil,
		eventId = event and event.id or nil,
		masteredCount = Economy.masteredCount(d),
		passive = {},
		isDev = PlayerService.isDev(player),
		sandbox = DataService.isSandbox(player),
		eventOverride = eventOverride,
	}
	local canRebirth, rebirthErr = Progress.canRebirth(d)
	derived.rebirth = { can = canRebirth, reason = rebirthErr }
	for cityId, branch in pairs(d.cities) do
		derived.slotCounts[cityId] = Academy.slotCount(d, cityId)
		derived.members = derived.members + branch.members
		if cityId ~= d.activeCity then
			derived.passive[cityId] = Academy.estimateHourly(d, ctx, cityId) * Progression.PASSIVE_BRANCH_RATE
		end
	end
	derived.marketBought = {}
	for i = 1, #derived.market do
		derived.marketBought[i] = d.flags.market ~= nil and d.flags.market[tostring(day) .. ":" .. tostring(i)] == true
	end
	-- product preview: how much each cash pack gives right now
	derived.cashPacks = {}
	for _, product in ipairs(Monetization.products) do
		if product.cashMinutes then
			derived.cashPacks[product.key] = Formulas.cashPackAmount(product, derived.hourlyEstimate)
		end
	end
	return { serverTime = now, data = stripData(d), derived = derived }
end

local function pushState(player)
	local state = PlayerService.buildState(player)
	if state then
		stateRemote:FireClient(player, state)
	end
end
PlayerService.pushState = pushState

---------------------------------------------------------------- visitor broadcast

local function compactPlan(plan)
	return {
		id = plan.id, seed = plan.seed, category = plan.category, interest = plan.interest, t0 = plan.t0,
		queue = plan.queue, tDeskDone = plan.tDeskDone, outcome = plan.outcome, slot = plan.slot, spot = plan.spot,
		roomId = plan.roomId, roomLevel = plan.roomLevel, amenityId = plan.amenityId, amenityLevel = plan.amenityLevel, amenitySpot = plan.amenitySpot,
		tSession = plan.tSession, tEnd = plan.tEnd, amenitySlot = plan.amenitySlot, rank = plan.rank,
		name = plan.name, satisfaction = plan.satisfaction, classTier = plan.classTier, tExit = plan.tExit,
		studentName = plan.studentName,
	}
end

---------------------------------------------------------------- lifecycle

function PlayerService.resetSimulation(player)
	local rt = runtimes[player]
	local d = DataService.get(player)
	if not rt or not d then
		return
	end
	local mult = rt.sim and rt.sim.devSpawnMult
	rt.sim = Simulation.new(d.activeCity, serverNow())
	rt.sim.devSpawnMult = mult
	local index = PlotService.plotOf(player)
	if index then
		visitorsRemote:FireAllClients("clear", index)
	end
end

local function setupLeaderstats(player, d)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Format.cash(d.cash)
	cash.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = d.level
	level.Parent = ls
	local rep = Instance.new("StringValue")
	rep.Name = "Rep"
	rep.Value = Format.short(d.reputation)
	rep.Parent = ls
	ls.Parent = player
end

local function grantOffline(player, d, ctx)
	if d.lastOnline <= 0 then
		return
	end
	local away = math.min(os.time() - d.lastOnline, Progression.OFFLINE_MAX_HOURS * 3600)
	if away < 120 then
		return
	end
	local hourly = Academy.estimateAllHourly(d, ctx)
	local amount = math.floor(hourly * away / 3600 * Progression.OFFLINE_RATE)
	if amount > 0 then
		Economy.earn(d, amount)
		PlayerService.notify(player, "offline", { amount = amount, seconds = away })
	end
end

local function onPlayerAdded(player)
	local d, err = DataService.load(player)
	if not d then
		if player.Parent then
			player:Kick("Could not load your academy (" .. tostring(err) .. "). Please rejoin in a minute.")
		end
		return
	end
	local now = serverNow()
	local rt = {
		player = player,
		rng = RNG.new(player.UserId % 2147483000 + math.floor(now) % 100000),
		sim = Simulation.new(d.activeCity, now),
		lastDay = now,
		earnLog = {},
		joinedAt = now,
		dirty = true,
		lastPush = 0,
		autoTimer = 0,
		registerTimer = 0,
		overflowNotified = 0,
		visited = {},
	}
	runtimes[player] = rt
	local ctx = PlayerService.ctx()
	-- clear construction that finished while offline
	Academy.finishConstruction(d, ctx.now)
	grantOffline(player, d, ctx)
	Progress.refreshQuests(d, os.time(), player.UserId)
	Progress.syncCosmetics(d)
	-- everyone starts in a karate gi once; unequipping later is respected
	if not d.flags.defaultOutfitGiven then
		d.flags.defaultOutfitGiven = true
		d.cosmetics.owned.outfit_karate_white = true
		if not d.cosmetics.equipped.outfit then
			d.cosmetics.equipped.outfit = "outfit_karate_white"
		end
	end
	setupLeaderstats(player, d)
	PlotService.sendAll(player)
	pushState(player)
	-- auto-claim if the player does not claim a plot themselves
	task.delay(AUTO_CLAIM_SECONDS, function()
		if runtimes[player] and not PlotService.plotOf(player) then
			local ok = PlotService.claim(player)
			if ok then
				PlayerService.notify(player, "toast", { text = "We reserved an academy plot for you!" })
				PlayerService.markDirty(player)
			end
		end
	end)
end

local function onPlayerRemoving(player)
	local d = DataService.get(player)
	local rt = runtimes[player]
	if d and rt then
		d.stats.playSeconds = d.stats.playSeconds + (serverNow() - rt.joinedAt)
		-- pay out a running championship so nothing is lost
		if rt.champ then
			PlayerService.finishChampionship(player, true)
		end
	end
	local index = PlotService.plotOf(player)
	if index then
		visitorsRemote:FireAllClients("clear", index)
	end
	runtimes[player] = nil
	DataService.release(player)
end

---------------------------------------------------------------- championships

function PlayerService.startChampionship(player, disciplineId)
	local rt = runtimes[player]
	local d = DataService.get(player)
	if not rt or not d then
		return false, "Not ready"
	end
	if rt.champ then
		return false, "A championship is already running"
	end
	local branch = d.cities[d.activeCity]
	local arenaSlot
	for slot, room in pairs(branch.rooms) do
		if room.id == "arena" and not Academy.isBuilding(room, os.time()) then
			arenaSlot = tonumber(slot)
		end
	end
	if not arenaSlot then
		return false, "Build a Championship Arena in this city first"
	end
	if not d.disciplines[disciplineId] then
		return false, "Discipline locked"
	end
	local readyAt = d.flags.arenaReadyAt or 0
	if os.time() < readyAt then
		return false, "Arena is resting: " .. Format.time(readyAt - os.time())
	end
	local fee = Formulas.rewardCashUnit(d.level) * 3
	if not Economy.spend(d, fee) then
		return false, "Entry fee: " .. Format.cash(fee)
	end
	local now = serverNow()
	rt.champ = { discipline = disciplineId, endAt = now + 45, fee = fee, slot = arenaSlot, cityId = d.activeCity }
	d.flags.arenaReadyAt = os.time() + 600
	local index = PlotService.plotOf(player)
	if index then
		visitorsRemote:FireAllClients("champ", index, { slot = arenaSlot, discipline = disciplineId, t0 = now, endAt = now + 45, seedA = rt.rng:int(1, 1e9), seedB = rt.rng:int(1, 1e9) })
	end
	local disc = Disciplines.byId[disciplineId]
	PlayerService.notifyAll("social", { text = player.DisplayName .. " is hosting a " .. disc.name .. " Championship in " .. Cities.byId[d.activeCity].name .. "!" })
	return true, { fee = fee, endAt = now + 45 }
end

function PlayerService.finishChampionship(player, silent)
	local rt = runtimes[player]
	local d = DataService.get(player)
	if not rt or not rt.champ or not d then
		return
	end
	local champ = rt.champ
	rt.champ = nil
	local ctx = PlayerService.ctx()
	local city = Cities.byId[champ.cityId]
	local mult = (city.arenaMult or 1) * ((ctx.event and ctx.event.arenaMult) or 1)
	local arena = d.cities[champ.cityId] and d.cities[champ.cityId].rooms[tostring(champ.slot)]
	local level = arena and arena.level or 1
	local prize = champ.fee * (4 + level) * mult * Economy.globalMult(d, ctx) * math.sqrt(city.incomeMult)
	prize = math.floor(prize)
	Economy.earn(d, prize)
	PlayerService.recordEarning(player, prize)
	local rep = 40 * city.prestige * level
	Economy.addReputation(d, rep)
	d.stats.championships = d.stats.championships + 1
	if not silent then
		PlayerService.giveXp(player, Progression.xp.championship)
		PlayerService.notify(player, "championship", { prize = prize, reputation = rep, discipline = champ.discipline })
		PlayerService.track(player, "cashEarned", prize)
		PlayerService.track(player, "reputationGained", rep)
	end
	PlayerService.markDirty(player)
end

---------------------------------------------------------------- tick

local function handleSettlement(player, d, rt, res, ctx)
	local plan = res.plan
	if res.cash > 0 then
		PlayerService.recordEarning(player, res.cash)
		PlayerService.track(player, "cashEarned", res.cash)
	end
	PlayerService.track(player, "studentsServed", 1)
	PlayerService.track(player, "students_" .. tostring(plan.interest), 1)
	if res.newClass then
		PlayerService.track(player, "classesCompleted", 1)
		PlayerService.track(player, "classes_" .. tostring(plan.interest), 1)
	end
	if res.graduation then
		-- a student earned a new belt / rank: ceremony in the room, small rewards
		local g = res.graduation
		Economy.addReputation(d, 5)
		PlayerService.giveXp(player, 15)
		PlayerService.track(player, "graduations", 1)
		PlayerService.notify(player, "graduation", g)
		local index = PlotService.plotOf(player)
		if index then
			visitorsRemote:FireAllClients("graduate", index, { planId = g.planId, slot = g.slot })
		end
	end
	if res.happy then
		PlayerService.track(player, "happyStudents", 1)
	end
	if res.masteryXp then
		PlayerService.track(player, "masteryXp", res.masteryXp)
	end
	if res.reputation and res.reputation > 0 then
		PlayerService.track(player, "reputationGained", res.reputation)
	end
	if #res.levels > 0 then
		PlayerService.notify(player, "levelup", { level = res.levels[#res.levels], gems = res.gems })
		for _, id in ipairs(Progress.syncCosmetics(d)) do
			PlayerService.notify(player, "cosmetic", { id = id })
		end
	end
	for _, rank in ipairs(res.rankUps) do
		local disc = Disciplines.byId[plan.interest]
		PlayerService.notify(player, "rankup", { discipline = plan.interest, rank = rank, name = disc.ranks[rank].name })
		task.spawn(CosmeticService.rankUp, player, plan.interest)
		local index = PlotService.plotOf(player)
		if index then
			visitorsRemote:FireAllClients("rankup", index, { slot = plan.slot, discipline = plan.interest, rank = rank })
		end
	end
	if res.trainerLevel then
		local t = plan.trainer and d.trainers[plan.trainer]
		if t then
			PlayerService.notify(player, "trainerlevel", { name = t.name, level = res.trainerLevel })
		end
	end
	if res.eventPoints and ctx.event then
		Progress.addEventPoints(d, ctx.event, ctx.now, res.eventPoints)
	end
	if res.overflow and res.overflow > 0 and ctx.now - rt.overflowNotified > 60 then
		rt.overflowNotified = ctx.now
		PlayerService.notify(player, "toast", { text = "Your register is full! Collect it to keep earning.", kind = "warn" })
	end
	-- a VIP's or celebrity's happy visit
	local cat = Customers.byId[plan.category]
	if cat.celebrity and plan.satisfaction >= 80 then
		PlayerService.notifyAll("social", { text = (plan.name or "A celebrity") .. " loved training at " .. player.DisplayName .. "'s academy!" })
	end
end

local function tickPlayer(player, rt, dt)
	local d = DataService.get(player)
	if not d then
		return
	end
	local ctx = PlayerService.ctx()
	local now = ctx.now
	local plotIndex = PlotService.plotOf(player)

	-- construction finished?
	local done = Academy.finishConstruction(d, now)
	for _, item in ipairs(done) do
		if item.cityId == d.activeCity then
			PlotService.refreshRoomOf(player, tonumber(item.slot))
		end
		local def = Rooms.byId[item.room.id]
		PlayerService.notify(player, "built", { name = def.name, level = item.room.level, slot = tonumber(item.slot) })
		PlayerService.giveXp(player, item.room.level == 1 and Progression.xp.roomBuilt or Progression.xp.roomUpgraded)
		PlayerService.track(player, "roomsTouched", 1)
		if item.room.level > 1 then
			PlayerService.track(player, "roomsUpgraded", 1)
		end
		rt.dirty = true
	end

	if plotIndex then
		-- visitors
		local plans = Simulation.step(d, rt.sim, ctx, rt.rng, dt)
		if #plans > 0 then
			local compact = {}
			for i, plan in ipairs(plans) do
				compact[i] = compactPlan(plan)
				if Customers.byId[plan.category].celebrity and plan.outcome == "train" then
					PlayerService.notify(player, "toast", { text = "★ Celebrity " .. (plan.name or "") .. " is visiting your academy!" })
				end
			end
			visitorsRemote:FireAllClients("plans", plotIndex, compact)
		end
		-- classes that ended
		local results = Simulation.settle(d, rt.sim, ctx, rt.rng)
		for _, res in ipairs(results) do
			handleSettlement(player, d, rt, res, ctx)
		end
		if #results > 0 then
			rt.dirty = true
		end
	end

	-- business day
	if now - rt.lastDay >= Progression.DAY_SECONDS then
		rt.lastDay = now
		local avg = Simulation.takeAverageSatisfaction(rt.sim)
		if avg then
			rt.avgSatisfaction = avg
		end
		local report = Simulation.businessDay(d, ctx, rt.avgSatisfaction or 65)
		PlayerService.recordEarning(player, report.dues + report.passive)
		d.flags.todayExpenses = (d.flags.todayExpenses or 0) + report.expenses - report.unpaid
		PlayerService.notify(player, "day", report)
		rt.dirty = true
	end

	-- automatic collection (Auto Collect pass or automation upgrade)
	rt.autoTimer = rt.autoTimer + dt
	local interval
	if Economy.hasPass(d, "auto_collect") then
		interval = Monetization.passByKey.auto_collect.effect.autoCollect
	end
	if d.automation > 0 then
		local a = Progression.automation[d.automation].interval
		interval = interval and math.min(interval, a) or a
	end
	if interval and rt.autoTimer >= interval then
		rt.autoTimer = 0
		local amount = Academy.collect(d)
		if amount > 0 then
			PlayerService.notify(player, "collected", { amount = amount, auto = true })
			rt.dirty = true
		end
	end

	-- championship
	if rt.champ and now >= rt.champ.endAt then
		PlayerService.finishChampionship(player, false)
	end

	-- register display
	rt.registerTimer = rt.registerTimer + dt
	if rt.registerTimer >= 1 then
		rt.registerTimer = 0
		PlotService.updateRegister(player, d.register, Academy.registerCap(d))
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			ls.Cash.Value = Format.cash(d.cash)
			ls.Rep.Value = Format.short(d.reputation)
			ls.Level.Value = d.level
		end
		-- achievements (cheap checks, once a second)
		for _, a in ipairs(Activities.checkAchievements(d)) do
			PlayerService.notify(player, "achievement", { name = a.name, text = a.text, gems = a.gems })
			rt.dirty = true
		end
		-- daily missions roll over at midnight UTC
		if Progress.refreshQuests(d, os.time(), player.UserId) then
			PlayerService.notify(player, "toast", { text = "New daily missions are available!" })
			rt.dirty = true
		end
	end

	if rt.dirty and now - rt.lastPush >= 0.5 then
		rt.dirty = false
		rt.lastPush = now
		pushState(player)
	end
end

function PlayerService.init()
	stateRemote = Remotes.get("State")
	visitorsRemote = Remotes.get("Visitors")
	notifyRemote = Remotes.get("Notify")
	PlotService.setDataGetter(DataService.get)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local t = os.clock()
			local dt = math.min(t - last, 2)
			last = t
			for player, rt in pairs(runtimes) do
				local ok, err = pcall(tickPlayer, player, rt, dt)
				if not ok then
					warn("[PlayerService] tick error for " .. player.Name .. ": " .. tostring(err))
				end
			end
		end
	end)
end

PlayerService.serverNow = serverNow

return PlayerService
