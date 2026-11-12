-- Handles every client request (Remotes.Action). Each action validates its
-- payload (types, ranges, known ids), is rate limited per player, runs the
-- server-side domain logic and returns { ok = bool, err = string?, result = table? }.
-- Clients never send amounts of money: only intentions ("upgrade slot 3").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Modules.Remotes)
local Util = require(Shared.Modules.Util)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Cities = require(Shared.Config.Cities)
local Cosmetics = require(Shared.Config.Cosmetics)
local Trainers = require(Shared.Config.Trainers)
local Progression = require(Shared.Config.Progression)
local Layout = require(Shared.Modules.Layout)

local Domain = script.Parent.Parent.Domain
local Academy = require(Domain.Academy)
local Economy = require(Domain.Economy)
local TrainerGen = require(Domain.TrainerGen)
local Progress = require(Domain.Progress)
local RateLimiter = require(Domain.RateLimiter)
local Validate = require(Domain.Validate)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)
local CosmeticService = require(script.Parent.CosmeticService)
local TournamentService = require(script.Parent.TournamentService)
local Activities = require(Domain.Activities)
local ActivityConfig = require(Shared.Config.Activities)

local ActionService = {}

local limiter = RateLimiter.new({
	default = { rate = 4, burst = 8 },
	collect = { rate = 2, burst = 4 },
	scout = { rate = 2, burst = 4 },
	inspect = { rate = 1, burst = 3 },
	leaderboard = { rate = 0.5, burst = 3 },
	rate = { rate = 0.5, burst = 2 },
	visit = { rate = 0.5, burst = 2 },
})

local handlers = {}

local function slotArg(p)
	return Validate.int(p.slot, 0, Layout.MAX_SLOTS)
end

local function ok(result)
	return { ok = true, result = result }
end
local function fail(err)
	return { ok = false, err = err }
end

local function needPlot(player)
	if not PlotService.plotOf(player) then
		return false
	end
	return true
end

---------------------------------------------------------------- session

-- The client says hello once its listeners are connected; reply with the
-- full state and all plot layouts (events fired before that may be missed).
handlers.hello = function(player)
	PlotService.sendAll(player)
	PlayerService.pushState(player)
	return ok()
end

---------------------------------------------------------------- academy

handlers.claimPlot = function(player, d, p)
	local index = p.index ~= nil and Validate.int(p.index, 1, Layout.PLOT_COUNT) or nil
	if p.index ~= nil and not index then
		return fail("Invalid plot")
	end
	local success, res = PlotService.claim(player, index)
	if not success then
		return fail(res)
	end
	return ok({ plot = res })
end

handlers.goHome = function(player)
	local index = PlotService.plotOf(player)
	if not index then
		return fail("Claim an academy first")
	end
	PlotService.teleportTo(player, index)
	return ok()
end

handlers.collect = function(player, d)
	local amount = Academy.collect(d)
	if amount <= 0 then
		return fail("Register is empty")
	end
	PlayerService.track(player, "registerCollected", 1)
	PlayerService.notify(player, "collected", { amount = amount })
	return ok({ amount = amount })
end

local function applyBuildCredit(player, d, cityId, slot)
	local credits = d.flags.buildCredits or 0
	if credits > 0 then
		local room = d.cities[cityId].rooms[tostring(slot)]
		if room and room.buildEnd then
			room.buildEnd = 0
			d.flags.buildCredits = credits - 1
			PlayerService.notify(player, "toast", { text = "Instant Construction credit used!" })
		end
	end
end

handlers.build = function(player, d, p)
	local slot = Validate.int(p.slot, 1, Layout.MAX_SLOTS)
	local roomId = Validate.oneOf(p.roomId, Rooms.byId)
	if not slot or not roomId then
		return fail("Invalid request")
	end
	if not needPlot(player) then
		return fail("Claim an academy first")
	end
	local success, res = Academy.build(d, PlayerService.ctx(), d.activeCity, slot, roomId)
	if not success then
		return fail(res)
	end
	applyBuildCredit(player, d, d.activeCity, slot)
	PlotService.refreshRoomOf(player, slot)
	PlayerService.notify(player, "construct", { slot = slot })
	return ok(res)
end

handlers.upgrade = function(player, d, p)
	local slot = slotArg(p)
	if not slot then
		return fail("Invalid slot")
	end
	if not needPlot(player) then
		return fail("Claim an academy first")
	end
	local success, res = Academy.upgrade(d, PlayerService.ctx(), d.activeCity, slot)
	if not success then
		return fail(res)
	end
	applyBuildCredit(player, d, d.activeCity, slot)
	PlotService.refreshRoomOf(player, slot)
	PlayerService.notify(player, "construct", { slot = slot })
	return ok(res)
end

handlers.removeRoom = function(player, d, p)
	local slot = Validate.int(p.slot, 1, Layout.MAX_SLOTS)
	if not slot then
		return fail("Invalid slot")
	end
	local success, res = Academy.remove(d, PlayerService.ctx(), d.activeCity, slot)
	if not success then
		return fail(res)
	end
	PlotService.refreshRoomOf(player, slot)
	return ok(res)
end

handlers.assignTrainer = function(player, d, p)
	local slot = Validate.int(p.slot, 1, Layout.MAX_SLOTS)
	local uid = Validate.string(p.uid, 20)
	if not slot or not uid then
		return fail("Invalid request")
	end
	local cityBefore = Academy.findTrainerRoom(d, uid)
	local success, res = Academy.assignTrainer(d, d.activeCity, slot, uid)
	if not success then
		return fail(res)
	end
	PlotService.refreshRoomOf(player, slot)
	if res.movedFrom and cityBefore == d.activeCity then
		PlotService.refreshRoomOf(player, tonumber(res.movedFrom))
	end
	return ok()
end

handlers.unassignTrainer = function(player, d, p)
	local slot = Validate.int(p.slot, 1, Layout.MAX_SLOTS)
	if not slot then
		return fail("Invalid slot")
	end
	local success, err = Academy.unassign(d, d.activeCity, slot)
	if not success then
		return fail(err)
	end
	PlotService.refreshRoomOf(player, slot)
	return ok()
end

handlers.setTier = function(player, d, p)
	local slot = Validate.int(p.slot, 1, Layout.MAX_SLOTS)
	local tier = Validate.int(p.tier, 1, 5)
	if not slot or not tier then
		return fail("Invalid request")
	end
	local success, err = Academy.setTier(d, d.activeCity, slot, tier)
	if not success then
		return fail(err)
	end
	PlotService.refreshRoomOf(player, slot)
	return ok()
end

handlers.unlockDiscipline = function(player, d, p)
	local id = Validate.oneOf(p.id, Disciplines.byId)
	if not id then
		return fail("Unknown discipline")
	end
	local success, res = Academy.unlockDiscipline(d, id)
	if not success then
		return fail(res)
	end
	PlayerService.giveXp(player, Progression.xp.disciplineUnlocked)
	PlayerService.notify(player, "unlock", { text = Disciplines.byId[id].name .. " unlocked!" })
	-- the discipline's uniform becomes available in the inventory
	for _, cid in ipairs(Progress.syncCosmetics(d)) do
		PlayerService.notify(player, "cosmetic", { id = cid })
	end
	return ok(res)
end

handlers.unlockCity = function(player, d, p)
	local id = Validate.oneOf(p.id, Cities.byId)
	if not id then
		return fail("Unknown city")
	end
	local success, res = Academy.unlockCity(d, id)
	if not success then
		return fail(res)
	end
	PlayerService.giveXp(player, Progression.xp.cityUnlocked)
	PlayerService.notify(player, "unlock", { text = Cities.byId[id].name .. " academy opened!" })
	PlayerService.notifyAll("social", { text = player.DisplayName .. " expanded to " .. Cities.byId[id].name .. "!" })
	return ok(res)
end

handlers.switchCity = function(player, d, p)
	local id = Validate.oneOf(p.id, Cities.byId)
	if not id then
		return fail("Unknown city")
	end
	if d.activeCity == id then
		return fail("Already managing this city")
	end
	local rt = PlayerService.runtime(player)
	if rt and rt.champ then
		return fail("Wait for the championship to finish")
	end
	local success, err = Academy.switchCity(d, id)
	if not success then
		return fail(err)
	end
	PlayerService.resetSimulation(player)
	PlotService.refreshPlotOf(player)
	CosmeticService.apply(player)
	local index = PlotService.plotOf(player)
	if index then
		PlotService.teleportTo(player, index)
	end
	return ok()
end

handlers.buyAutomation = function(player, d)
	local success, res = Academy.buyAutomation(d)
	if not success then
		return fail(res)
	end
	PlayerService.notify(player, "unlock", { text = res.name .. " hired: the register now empties automatically." })
	return ok(res)
end

---------------------------------------------------------------- trainers

handlers.scout = function(player, d, p)
	local id = Validate.oneOf(p.discipline, Disciplines.byId)
	if not id then
		return fail("Unknown discipline")
	end
	local rt = PlayerService.runtime(player)
	local success, res = TrainerGen.scout(d, rt.rng, id)
	if not success then
		return fail(res)
	end
	PlayerService.giveXp(player, Progression.xp.trainerHired)
	PlayerService.track(player, "trainersHired", 1)
	local order = Trainers.rarityById[res.trainer.rarity].order
	if order >= 3 then
		PlayerService.track(player, "rareTrainers", 1)
	end
	if order >= 5 then
		PlayerService.notifyAll("social", { text = player.DisplayName .. " recruited " .. Trainers.rarityById[res.trainer.rarity].name .. " trainer " .. res.trainer.name .. "!" })
	end
	return ok({ uid = res.uid, trainer = res.trainer, cost = res.cost })
end

handlers.buyMarket = function(player, d, p)
	local index = Validate.int(p.index, 1, Trainers.MARKET_SIZE)
	if not index then
		return fail("Invalid offer")
	end
	local day = Util.dayNumber(os.time())
	local success, res = TrainerGen.buyMarket(d, day, index)
	if not success then
		return fail(res)
	end
	PlayerService.giveXp(player, Progression.xp.trainerHired)
	PlayerService.track(player, "trainersHired", 1)
	if Trainers.rarityById[res.trainer.rarity].order >= 3 then
		PlayerService.track(player, "rareTrainers", 1)
	end
	return ok({ uid = res.uid, trainer = res.trainer })
end

handlers.trainTrainer = function(player, d, p)
	local uid = Validate.string(p.uid, 20)
	if not uid then
		return fail("Invalid trainer")
	end
	local success, res = TrainerGen.train(d, uid)
	if not success then
		return fail(res)
	end
	PlayerService.giveXp(player, Progression.xp.trainerTrained)
	return ok(res)
end

handlers.releaseTrainer = function(player, d, p)
	local uid = Validate.string(p.uid, 20)
	if not uid then
		return fail("Invalid trainer")
	end
	local success, err = TrainerGen.release(d, uid, function(id)
		return Academy.findTrainerRoom(d, id) ~= nil
	end)
	if not success then
		return fail(err)
	end
	return ok()
end

---------------------------------------------------------------- progression

handlers.claimQuest = function(player, d, p)
	local period = p.period == "weekly" and "weekly" or (p.period == "daily" and "daily" or nil)
	local index = Validate.int(p.index, 1, 10)
	if not period or not index then
		return fail("Invalid mission")
	end
	local success, res = Progress.claimQuest(d, period, index)
	if not success then
		return fail(res)
	end
	if #res.levels > 0 then
		PlayerService.notify(player, "levelup", { level = res.levels[#res.levels] })
	end
	return ok(res)
end

handlers.claimDaily = function(player, d)
	local success, res = Progress.claimDaily(d, os.time())
	if not success then
		return fail(res)
	end
	if res.cosmetic then
		CosmeticService.apply(player)
	end
	return ok(res)
end

handlers.claimEvent = function(player, d, p)
	local index = Validate.int(p.index, 1, 10)
	if not index then
		return fail("Invalid reward")
	end
	local ctx = PlayerService.ctx()
	if not ctx.event then
		return fail("No event running")
	end
	local success, res = Progress.claimEventReward(d, ctx.event, ctx.now, index)
	if not success then
		return fail(res)
	end
	return ok(res)
end

handlers.buyCosmetic = function(player, d, p)
	local id = Validate.oneOf(p.id, Cosmetics.byId)
	if not id then
		return fail("Unknown item")
	end
	local success, err = Progress.buyCosmetic(d, id)
	if not success then
		return fail(err)
	end
	return ok()
end

handlers.equipCosmetic = function(player, d, p)
	local id = Validate.oneOf(p.id, Cosmetics.byId)
	local on = Validate.bool(p.on)
	if not id or on == nil then
		return fail("Invalid request")
	end
	local success, err = Progress.equipCosmetic(d, id, on)
	if not success then
		return fail(err)
	end
	if Cosmetics.byId[id].kind == "deco" then
		local index = PlotService.plotOf(player)
		if index then
			PlotService.buildDecorations(index)
		end
	else
		CosmeticService.apply(player)
	end
	return ok()
end

handlers.rebirth = function(player, d, p)
	if p.confirm ~= true then
		return fail("Confirmation required")
	end
	local rt = PlayerService.runtime(player)
	if rt and rt.champ then
		return fail("Wait for the championship to finish")
	end
	local success, res = Progress.rebirth(d)
	if not success then
		return fail(res)
	end
	PlayerService.resetSimulation(player)
	PlotService.refreshPlotOf(player)
	CosmeticService.apply(player)
	PlayerService.notifyAll("social", { text = player.DisplayName .. " was reborn as a " .. res.title .. "!" })
	return ok(res)
end

handlers.hostChampionship = function(player, d, p)
	local id = Validate.oneOf(p.discipline, Disciplines.byId)
	if not id then
		return fail("Unknown discipline")
	end
	local success, res = PlayerService.startChampionship(player, id)
	if not success then
		return fail(res)
	end
	return ok(res)
end

handlers.settings = function(player, d, p)
	local key = Validate.string(p.key, 20)
	if key == "music" or key == "sfx" or key == "lowGraphics" then
		local v = Validate.bool(p.value)
		if v == nil then
			return fail("Invalid value")
		end
		d.settings[key] = v
	elseif key == "npcDensity" then
		local v = Validate.int(p.value, 0, 2)
		if not v then
			return fail("Invalid value")
		end
		d.settings.npcDensity = v
	else
		return fail("Unknown setting")
	end
	return ok()
end

---------------------------------------------------------------- social

local function findPlayer(userId)
	local id = Validate.int(userId, 1, 1e12)
	return id and Players:GetPlayerByUserId(id) or nil
end

handlers.visit = function(player, d, p)
	local target = findPlayer(p.userId)
	if not target or target == player then
		return fail("Player not found")
	end
	local index = PlotService.plotOf(target)
	if not index then
		return fail(target.DisplayName .. " has no academy yet")
	end
	PlotService.teleportTo(player, index)
	local rt = PlayerService.runtime(player)
	if rt and not rt.visited[target.UserId] then
		rt.visited[target.UserId] = true
		d.stats.visitsMade = d.stats.visitsMade + 1
		PlayerService.track(player, "academiesVisited", 1)
	end
	PlayerService.notify(target, "toast", { text = player.DisplayName .. " is visiting your academy!" })
	return ok({ plot = index })
end

handlers.inspect = function(player, d, p)
	local target = findPlayer(p.userId)
	if not target then
		return fail("Player not found")
	end
	local td = DataService.get(target)
	if not td then
		return fail("Not loaded yet")
	end
	local trainers = {}
	for _, t in pairs(td.trainers) do
		table.insert(trainers, { name = t.name, rarity = t.rarity, discipline = t.discipline, level = t.level, seed = t.seed, master = t.master, title = t.title })
	end
	table.sort(trainers, function(a, b)
		return Trainers.rarityById[a.rarity].order > Trainers.rarityById[b.rarity].order
	end)
	while #trainers > 8 do
		table.remove(trainers)
	end
	local rooms = 0
	for _, branch in pairs(td.cities) do
		for slot in pairs(branch.rooms) do
			if slot ~= "0" then
				rooms = rooms + 1
			end
		end
	end
	local mastery = {}
	for id, m in pairs(td.mastery) do
		local disc = Disciplines.byId[id]
		if disc then
			mastery[id] = disc.ranks[m.rank].name
		end
	end
	return ok({
		name = target.DisplayName,
		userId = target.UserId,
		level = td.level,
		rebirths = td.rebirths,
		prestigeTitle = td.flags.prestigeTitle,
		reputation = td.reputation,
		earned = td.stats.totalEarned,
		students = td.stats.studentsServed,
		classes = td.stats.classesCompleted,
		cities = Util.count(td.cities),
		activeCity = td.activeCity,
		rooms = rooms,
		disciplines = Util.count(td.disciplines),
		mastery = mastery,
		trainers = trainers,
		rating = td.ratings.count > 0 and td.ratings.sum / td.ratings.count or 0,
		ratingCount = td.ratings.count,
		title = td.cosmetics.equipped.title,
		passes = { vip = td.purchases.passes.vip_owner == true, elite = td.purchases.passes.elite_owner == true },
	})
end

handlers.rate = function(player, d, p)
	local target = findPlayer(p.userId)
	local stars = Validate.int(p.stars, 1, 5)
	if not target or target == player or not stars then
		return fail("Invalid rating")
	end
	local td = DataService.get(target)
	if not td then
		return fail("Not loaded yet")
	end
	local day = Util.dayNumber(os.time())
	local key = tostring(player.UserId)
	if td.ratings.given[key] == day then
		return fail("You already rated this academy today")
	end
	-- keep the list of raters bounded
	if Util.count(td.ratings.given) > 200 then
		td.ratings.given = {}
	end
	td.ratings.given[key] = day
	td.ratings.sum = td.ratings.sum + stars
	td.ratings.count = td.ratings.count + 1
	Economy.addReputation(td, stars * 5)
	PlayerService.track(player, "academiesRated", 1)
	PlayerService.notify(target, "toast", { text = player.DisplayName .. " rated your academy " .. string.rep("★", stars) })
	PlayerService.markDirty(target)
	local index = PlotService.plotOf(target)
	if index then
		PlotService.broadcast(index)
	end
	return ok()
end

handlers.leaderboard = function(player, d, p)
	local stat = Validate.string(p.stat, 20)
	if not stat then
		return fail("Unknown leaderboard")
	end
	return ok(LeaderboardService.list(stat))
end

handlers.players = function(player)
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local od = DataService.get(other)
		if od then
			table.insert(list, {
				userId = other.UserId, name = other.DisplayName, level = od.level, city = od.activeCity,
				hasPlot = PlotService.plotOf(other) ~= nil, rebirths = od.rebirths,
				rating = od.ratings.count > 0 and od.ratings.sum / od.ratings.count or 0,
			})
		end
	end
	return ok(list)
end

---------------------------------------------------------------- active gameplay

handlers.startChallenge = function(player, d, p)
	local gameId = Validate.oneOf(p.game, ActivityConfig.games)
	if not gameId then
		return fail("Unknown challenge")
	end
	local rt = PlayerService.runtime(player)
	local now = workspace:GetServerTimeNow()
	local success, challenge, prompts = Activities.startChallenge(d, gameId, now, rt.rng:int(1, 2147483000))
	if not success then
		return fail(challenge)
	end
	rt.challenge = challenge
	return ok({ game = gameId, startAt = challenge.startAt, duration = challenge.duration, prompts = prompts })
end

handlers.submitChallenge = function(player, d, p)
	local rt = PlayerService.runtime(player)
	local challenge = rt.challenge
	if type(p.responses) ~= "table" then
		return fail("Invalid answers")
	end
	local success, res = Activities.finishChallenge(d, challenge, p.responses, workspace:GetServerTimeNow(), Util.dayNumber(os.time()))
	if not success then
		return fail(res)
	end
	rt.challenge = nil
	local game = ActivityConfig.games[challenge.game]
	if game.discipline and res.mastery > 0 then
		for _, rank in ipairs(Economy.addMastery(d, game.discipline, res.mastery)) do
			PlayerService.notify(player, "rankup", { discipline = game.discipline, rank = rank, name = Disciplines.byId[game.discipline].ranks[rank].name })
			task.spawn(CosmeticService.rankUp, player, game.discipline)
		end
	end
	PlayerService.giveXp(player, res.xp)
	PlayerService.recordEarning(player, res.cash)
	PlayerService.track(player, "miniGames", 1)
	PlayerService.track(player, "miniGame_" .. challenge.game, 1)
	if res.score >= 80 then
		PlayerService.track(player, "miniGameGood", 1)
	end
	local ctx = PlayerService.ctx()
	if ctx.event and res.score > 0 then
		Progress.addEventPoints(d, ctx.event, ctx.now, 3)
	end
	return ok(res)
end

handlers.tournament = function(player, d)
	return ok({ state = TournamentService.state(), myKey = d.tournament.key })
end

handlers.enterTournament = function(player)
	local success, res = TournamentService.enter(player)
	if not success then
		return fail(res)
	end
	return ok(res)
end

---------------------------------------------------------------- studio testing

handlers.devGrant = function(player, d, p)
	local kind = Validate.string(p.kind, 10)
	local key = Validate.string(p.key, 40)
	if not kind or not key then
		return fail("Invalid request")
	end
	local success, res = MonetizationService.devGrant(player, kind, key)
	if not success then
		return fail(res)
	end
	return ok(res)
end

---------------------------------------------------------------- dispatch

function ActionService.init()
	local remote = Remotes.get("Action")
	remote.OnServerInvoke = function(player, action, payload)
		if type(action) ~= "string" or not handlers[action] then
			return fail("Unknown action")
		end
		if payload ~= nil and type(payload) ~= "table" then
			return fail("Invalid payload")
		end
		payload = payload or {}
		if not RateLimiter.allow(limiter, player.UserId, action, os.clock()) then
			return fail("Slow down!")
		end
		local d = DataService.get(player)
		if not d or not PlayerService.runtime(player) then
			return fail("Your academy is still loading")
		end
		local success, result = pcall(handlers[action], player, d, payload)
		if not success then
			warn("[ActionService] " .. action .. " failed: " .. tostring(result))
			return fail("Something went wrong")
		end
		if result.ok then
			PlayerService.markDirty(player)
		end
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.forget(limiter, player.UserId)
	end)
end

ActionService.handlers = handlers

return ActionService
