-- Run with:  lua5.4 tests/run.lua   (from the project root)
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local H = require("harness")
local check, eq, suite = H.check, H.eq, H.suite

local Disciplines = H.load("ReplicatedStorage/Shared/Config/Disciplines")
local Rooms = H.load("ReplicatedStorage/Shared/Config/Rooms")
local Cities = H.load("ReplicatedStorage/Shared/Config/Cities")
local Trainers = H.load("ReplicatedStorage/Shared/Config/Trainers")
local Customers = H.load("ReplicatedStorage/Shared/Config/Customers")
local Progression = H.load("ReplicatedStorage/Shared/Config/Progression")
local Quests = H.load("ReplicatedStorage/Shared/Config/Quests")
local Events = H.load("ReplicatedStorage/Shared/Config/Events")
local Cosmetics = H.load("ReplicatedStorage/Shared/Config/Cosmetics")
local Monetization = H.load("ReplicatedStorage/Shared/Config/Monetization")
local Poses = H.load("ReplicatedStorage/Shared/Modules/Poses")
local Formulas = H.load("ReplicatedStorage/Shared/Modules/Formulas")
local Layout = H.load("ReplicatedStorage/Shared/Modules/Layout")
local Visits = H.load("ReplicatedStorage/Shared/Modules/Visits")
local Format = H.load("ReplicatedStorage/Shared/Modules/Format")
local RNG = H.load("ReplicatedStorage/Shared/Modules/RNG")
local Util = H.load("ReplicatedStorage/Shared/Modules/Util")
local Schema = H.load("ServerScriptService/Server/Domain/Schema")
local Economy = H.load("ServerScriptService/Server/Domain/Economy")
local Academy = H.load("ServerScriptService/Server/Domain/Academy")
local TrainerGen = H.load("ServerScriptService/Server/Domain/TrainerGen")
local Simulation = H.load("ServerScriptService/Server/Domain/Simulation")
local Progress = H.load("ServerScriptService/Server/Domain/Progress")
local Purchases = H.load("ServerScriptService/Server/Domain/Purchases")
local ReceiptLedger = H.load("ServerScriptService/Server/Domain/ReceiptLedger")
local RateLimiter = H.load("ServerScriptService/Server/Domain/RateLimiter")
local Validate = H.load("ServerScriptService/Server/Domain/Validate")

local NOW = 1794441600 -- 2026-11-12 00:00 UTC

---------------------------------------------------------------------------
suite("config: 12 disciplines, complete definitions", function()
	eq(#Disciplines.list, 12, "discipline count")
	for _, d in ipairs(Disciplines.list) do
		check(#d.classes == 5, d.id .. " has 5 class tiers")
		check(#d.ranks >= 6, d.id .. " has at least 6 ranks")
		check(d.outfit.student and d.outfit.trainer, d.id .. " has student+trainer outfit")
		check(d.room and #d.room.equipment >= 6, d.id .. " room has equipment")
		check(Poses.moves[d.moves.idle] ~= nil, d.id .. " idle move exists: " .. d.moves.idle)
		for _, m in ipairs(d.moves.drill) do
			check(Poses.moves[m] ~= nil, d.id .. " drill move exists: " .. m)
		end
		for _, m in ipairs(d.moves.teach) do
			check(Poses.moves[m] ~= nil, d.id .. " teach move exists: " .. m)
		end
		for _, m in ipairs(d.moves.pair or {}) do
			check(Poses.moves[m] ~= nil, d.id .. " pair move exists: " .. m)
		end
		check(Rooms.byId[d.id .. "_room"] ~= nil, d.id .. " has a room")
		check(Trainers.cultureByOrigin[d.origin] ~= nil, d.id .. " origin has a name pool")
	end
	-- every discipline has its own drill set (no shared animation library)
	local signatures = {}
	for _, d in ipairs(Disciplines.list) do
		local sig = table.concat(d.moves.drill, ",") .. "|" .. d.moves.idle
		check(not signatures[sig], d.id .. " has a unique move set")
		signatures[sig] = true
	end
	check(Disciplines.byId.boxing.moves.idle ~= Disciplines.byId.judo.moves.idle, "judo does not reuse boxing idle")
	check(Disciplines.byId.sumo.outfit.student.bottom == "mawashi", "sumo students wear a mawashi")
	check(Disciplines.byId.sumo.bodyTypes.sumo ~= nil, "sumo students have sumo bodies")
end)

suite("config: rooms (24 buildable incl. reception), cities, trainers", function()
	eq(#Rooms.list, 24, "room types")
	for _, r in ipairs(Rooms.list) do
		check(Rooms.style(r.id) ~= nil, r.id .. " has a style")
		if r.kind == "training" and r.discipline ~= "fitness" then
			check(Disciplines.byId[r.discipline] ~= nil, r.id .. " discipline exists")
		end
	end
	eq(#Cities.list, 10, "city count")
	local prevLevel, prevCost = 0, -1
	for _, c in ipairs(Cities.list) do
		check(c.unlock.level >= prevLevel, c.id .. " unlock level ascending")
		check(c.unlock.cost > prevCost, c.id .. " unlock cost ascending")
		prevLevel, prevCost = c.unlock.level, c.unlock.cost
		for k in pairs(c.demand) do
			check(Disciplines.byId[k] ~= nil, c.id .. " demand references discipline " .. k)
		end
		for k in pairs(c.bonus) do
			check(Disciplines.byId[k] ~= nil, c.id .. " bonus references discipline " .. k)
		end
		for k in pairs(c.categories) do
			check(Customers.byId[k] ~= nil, c.id .. " category " .. k)
		end
		check(c.slots <= Layout.MAX_SLOTS, c.id .. " slots fit the plot")
	end
	local oddsTotal = 0
	for _, r in ipairs(Trainers.rarities) do
		oddsTotal = oddsTotal + r.odds
	end
	check(math.abs(oddsTotal - 100) < 1e-9, "rarity odds add to 100%")
	for _, m in ipairs(Trainers.masters) do
		check(Disciplines.byId[m.discipline] and Trainers.abilityById[m.ability] and Trainers.specById[m.spec], m.id .. " valid")
	end
	eq(#Customers.list, 8, "customer categories")
end)

suite("config: quests, events, cosmetics, monetization cross-references", function()
	for _, c in ipairs(Cosmetics.list) do
		if c.kind == "pose" then
			check(Poses.moves[c.animation] ~= nil, c.id .. " animation exists")
		end
		if c.source == "pass" then
			check(Monetization.passByKey[c.pass] ~= nil, c.id .. " pass exists")
		end
	end
	for _, e in ipairs(Events.list) do
		for _, r in ipairs(e.rewards) do
			if r.cosmetic then
				check(Cosmetics.byId[r.cosmetic] and Cosmetics.byId[r.cosmetic].source == "event", e.id .. " reward " .. r.cosmetic .. " is an event cosmetic")
			end
		end
	end
	for _, p in ipairs(Monetization.gamePasses) do
		for _, id in ipairs((p.grants or {}).cosmetics or {}) do
			check(Cosmetics.byId[id] ~= nil, p.key .. " grants existing cosmetic " .. id)
		end
		for _, id in ipairs((p.grants or {}).trainers or {}) do
			check(Trainers.masterById[id] ~= nil, p.key .. " grants existing trainer " .. id)
		end
	end
	for _, d in ipairs(Progression.daily) do
		if d.cosmetic then
			check(Cosmetics.byId[d.cosmetic] ~= nil, "daily cosmetic exists")
		end
	end
	-- event calendar
	eq(Events.active({ month = 11, day = 12 }).id, "festival", "default event in November")
	eq(Events.active({ month = 4, day = 15 }).id, "muaythaifest", "Muay Thai festival in April")
	eq(Events.active({ month = 12, day = 31 }).id, "globaltournament", "tournament on Dec 31")
	-- poses are well-formed
	for name, move in pairs(Poses.moves) do
		check(#move.keys >= 1, name .. " has keyframes")
		local last = -1
		for _, k in ipairs(move.keys) do
			check(k.t > last, name .. " keyframes in time order")
			last = k.t
		end
		check(move.length and move.length >= last, name .. " length covers keys")
	end
	local count = 0
	for _ in pairs(Poses.moves) do
		count = count + 1
	end
	check(count >= 60, "animation library has 60+ moves (" .. count .. ")")
end)

---------------------------------------------------------------------------
suite("modules: RNG, Util, Format", function()
	local a, b = RNG.new(42), RNG.new(42)
	for _ = 1, 10 do
		eq(a:next(), b:next(), "same seed same sequence")
	end
	local r = RNG.new(7)
	local lo, hi = 1, 0
	for _ = 1, 2000 do
		local v = r:next()
		lo = math.min(lo, v)
		hi = math.max(hi, v)
		local n = r:int(3, 5)
		check(n >= 3 and n <= 5, "int in range")
	end
	check(lo >= 0 and hi < 1, "next in [0,1)")
	eq(Util.weightedKey({ a = 1, b = 1 }, 0.25), "a", "weightedKey low")
	eq(Util.weightedKey({ a = 1, b = 1 }, 0.75), "b", "weightedKey high")
	eq(Format.short(999), "999", "short 999")
	eq(Format.short(1500), "1.5K", "short 1.5K")
	eq(Format.short(2500000), "2.5M", "short 2.5M")
	eq(Format.commas(1234567), "1,234,567", "commas")
	eq(Format.time(3725), "1h 02m", "time")
	eq(Util.weekNumber(NOW) - Util.weekNumber(NOW + 86400 * 7), -1, "weeks advance")
end)

suite("layout: slots never overlap and stay inside the plot", function()
	for i = 1, Layout.MAX_SLOTS do
		local a = Layout.slot(i)
		check(a.x0 >= -Layout.WIDTH / 2 and a.x1 <= Layout.WIDTH / 2, "slot " .. i .. " inside width")
		check(a.z0 >= Layout.RECEPTION.z1 and a.z1 <= Layout.DEPTH / 2, "slot " .. i .. " inside depth")
		for j = i + 1, Layout.MAX_SLOTS do
			local b = Layout.slot(j)
			local overlap = a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
			check(not overlap, "slots " .. i .. " and " .. j .. " do not overlap")
		end
		for spot = 1, 24 do
			local p = Layout.trainingSpot(i, spot)
			check(p.x > a.x0 + 1 and p.x < a.x1 - 1 and p.z > a.z0 and p.z < a.z1, "spot inside room")
		end
	end
	-- first slots are next to the corridor
	check(math.abs(Layout.slot(1).cx) < math.abs(Layout.slot(3).cx), "inner columns fill first")
	-- plots don't overlap
	for i = 1, Layout.PLOT_COUNT do
		for j = i + 1, Layout.PLOT_COUNT do
			local a, b = Layout.plotOrigin(i), Layout.plotOrigin(j)
			local sep = math.abs(a.x - b.x) >= Layout.WIDTH or math.abs(a.z - b.z) >= Layout.DEPTH
			check(sep, "plots " .. i .. "," .. j .. " separate")
		end
	end
end)

suite("visits: timeline is continuous and matches plan times", function()
	local plan = { t0 = 100, queue = 2, tDeskDone = 110, outcome = "train", slot = 5, spot = 7, tSession = 140, tEnd = 158, amenitySlot = 2 }
	local segs, tExit = Visits.timeline(plan)
	local t = 100
	for _, s in ipairs(segs) do
		check(math.abs(s.t0 - t) < 1e-6, "segment starts where previous ended")
		check(s.t1 >= s.t0, "segment positive length")
		t = s.t1
	end
	check(tExit > 158 + Visits.AMENITY_DWELL, "exit after class and amenity")
	local _, _, _, phase = Visits.sample(segs, 150)
	eq(phase, "train", "training at t=150")
	local _, _, _, phase2 = Visits.sample(segs, 109)
	eq(phase2, "queue", "queueing at desk at t=109")
	local leave = { t0 = 0, queue = 1, tDeskDone = 8, outcome = "leave" }
	local s2, t2 = Visits.timeline(leave)
	check(#s2 == 3 and t2 > 8, "leaving visitor walks out")
end)

---------------------------------------------------------------------------
suite("schema: defaults validate, migrations v1->v3, corrupt data repaired", function()
	local d = Schema.validate(Schema.defaults())
	eq(d.cash, Progression.START_CASH, "start cash")
	check(d.cities.smalltown.rooms["1"].trainer == "t1", "starter karate room has starter trainer")
	-- v1 save
	local v1 = { version = 1, cash = 1000, rooms = { [0] = { id = "reception", level = 2 }, [1] = { id = "karate_room", level = 3 } }, members = 12,
		trainers = { t1 = { name = "A", discipline = "karate", rarity = "rare", level = 4, room = 1, city = "smalltown" } } }
	Schema.migrate(v1)
	eq(v1.version, Schema.VERSION, "migrated to current version")
	local m = Schema.validate(v1)
	eq(m.cities.smalltown.rooms["1"].level, 3, "room level kept")
	eq(m.cities.smalltown.rooms["0"].level, 2, "reception kept")
	eq(m.cities.smalltown.members, 12, "members moved into branch")
	eq(m.cities.smalltown.rooms["1"].trainer, "t1", "trainer assignment moved to room")
	eq(m.cash, 1000, "cash kept")
	check(m.trainers.t1.room == nil, "old trainer field removed")
	-- corrupt
	local bad = Schema.defaults()
	bad.cash = 0 / 0
	bad.gems = -5
	bad.level = 9999
	bad.cities.smalltown.rooms["3"] = { id = "does_not_exist" }
	bad.cities.atlantis = { rooms = {} }
	bad.cities.smalltown.rooms["1"].trainer = "ghost"
	bad.trainers.t9 = { discipline = "nope", rarity = "common" }
	bad.cosmetics.equipped.aura = "aura_spirit" -- not owned
	Schema.validate(bad)
	eq(bad.cash, Progression.START_CASH, "NaN cash reset")
	eq(bad.gems, 0, "negative gems clamped")
	eq(bad.level, Progression.MAX_LEVEL, "level clamped")
	check(bad.cities.smalltown.rooms["3"] == nil, "unknown room removed")
	check(bad.cities.atlantis == nil, "unknown city removed")
	check(bad.cities.smalltown.rooms["1"].trainer == nil, "missing trainer unassigned")
	check(bad.trainers.t9 == nil, "invalid trainer removed")
	check(bad.cosmetics.equipped.aura == nil, "unowned cosmetic unequipped")
	-- existing saves do not receive the starter trainer again
	local custom = Schema.defaults()
	custom.trainers = { t5 = { name = "B", discipline = "boxing", rarity = "common" } }
	Schema.validate(custom)
	check(custom.trainers.t1 == nil, "defaults do not leak into existing trainer roster")
	check(Schema.validate("garbage").cash == Progression.START_CASH, "non-table becomes defaults")
end)

suite("academy: build, upgrade, assign, tiers, unlocks", function()
	local d = Schema.validate(Schema.defaults())
	local ctx = { now = NOW }
	local ok, err = Academy.build(d, ctx, "smalltown", 2, "boxing_room")
	check(not ok and err:find("Unlock"), "cannot build locked discipline room")
	ok, err = Academy.unlockDiscipline(d, "boxing")
	check(not ok and err:find("level"), "boxing needs level 2")
	d.level = 3
	d.cash = 100000
	check(Academy.unlockDiscipline(d, "boxing"), "unlock boxing")
	eq(d.cash, 100000 - 500, "licence paid")
	ok = Academy.build(d, ctx, "smalltown", 2, "boxing_room")
	check(ok, "build boxing room")
	check(Academy.isBuilding(d.cities.smalltown.rooms["2"], NOW + 1), "under construction")
	ok, err = Academy.build(d, ctx, "smalltown", 2, "karate_room")
	check(not ok, "slot occupied")
	ok, err = Academy.build(d, ctx, "smalltown", 99, "karate_room")
	check(not ok, "slot out of range")
	ok, err = Academy.build(d, ctx, "smalltown", 2.5, "karate_room")
	check(not ok, "fractional slot rejected")
	ok, err = Academy.build(d, ctx, "smalltown", 3, "reception")
	check(not ok, "cannot build a second reception")
	ok, err = Academy.upgrade(d, ctx, "smalltown", 2)
	check(not ok and err:find("construction"), "no upgrade while building")
	local done = Academy.finishConstruction(d, NOW + 1000)
	eq(#done, 1, "construction finished")
	local cash = d.cash
	check(Academy.upgrade(d, { now = NOW + 1000 }, "smalltown", 2), "upgrade boxing room")
	eq(cash - d.cash, Formulas.roomUpgradeCost("boxing_room", 1, "smalltown"), "upgrade cost charged")
	-- trainers
	local uid = TrainerGen.add(d, TrainerGen.generate(RNG.new(1), "boxing", "rare"))
	ok, err = Academy.assignTrainer(d, "smalltown", 1, uid)
	check(not ok, "boxing trainer cannot teach karate")
	check(Academy.assignTrainer(d, "smalltown", 2, uid), "assign boxing trainer")
	check(Academy.roomOperational(d, d.cities.smalltown.rooms["2"], NOW + 5000), "room operational")
	-- tiers
	ok = Academy.setTier(d, "smalltown", 2, 3)
	check(not ok, "tier 3 locked (room level 2, rank 1)")
	ok = Academy.setTier(d, "smalltown", 2, 2)
	check(not ok, "tier 2 needs mastery rank")
	Economy.addMastery(d, "boxing", 100000)
	check(Academy.setTier(d, "smalltown", 2, 2), "tier 2 after mastery + level 2")
	-- unique rooms
	d.level = 10
	check(Academy.build(d, ctx, "smalltown", 3, "locker_room"), "build lockers")
	ok = Academy.build(d, ctx, "smalltown", 4, "locker_room")
	check(not ok, "only one locker room")
	-- cities
	ok, err = Academy.unlockCity(d, "rotterdam")
	check(not ok and err:find("previous"), "cities in order")
	d.reputation = 10000
	d.cash = 1e9
	check(Academy.unlockCity(d, "amsterdam"), "unlock Amsterdam")
	check(Academy.switchCity(d, "amsterdam"), "switch to Amsterdam")
	eq(d.activeCity, "amsterdam", "active city")
	check(Formulas.roomBuildCost("boxing_room", "amsterdam") > Formulas.roomBuildCost("boxing_room", "smalltown"), "Amsterdam costs more")
	-- register
	d.register = 0
	local kept = Academy.addToRegister(d, 1e12)
	eq(kept, Academy.registerCap(d), "register caps")
	local before = d.cash
	local got = Academy.collect(d)
	eq(d.cash - before, got, "collect moves register to balance")
	eq(d.register, 0, "register empty")
	-- remove refund
	local c0 = d.cash
	check(Academy.remove(d, ctx, "smalltown", 3), "remove room")
	check(d.cash > c0, "refund paid")
	check(not Academy.remove(d, ctx, "smalltown", 0), "cannot remove reception")
end)

suite("economy: xp/levels, multipliers, passes", function()
	local d = Schema.validate(Schema.defaults())
	local ctx = { now = NOW }
	local levels = Economy.addXp(d, Progression.xpForLevel(1) + Progression.xpForLevel(2) + 1)
	eq(#levels, 2, "two level-ups")
	eq(d.level, 3, "level 3")
	local base = Economy.classMult(d, ctx, "karate", "smalltown")
	d.purchases.passes.double_cash = true
	eq(Economy.classMult(d, ctx, "karate", "smalltown"), base * 2, "double cash pass")
	Economy.addBoost(d, "cash", 30, NOW)
	eq(Economy.classMult(d, ctx, "karate", "smalltown"), base * 4, "boost stacks with pass")
	Economy.addBoost(d, "cash", 30, NOW)
	eq(d.boosts.cash, NOW + 3600, "boost time stacks")
	check(not Economy.boostActive(d, "cash", NOW + 3601), "boost expires")
	d.purchases.passes.premium_dojo = true
	check(math.abs(Economy.classMult(d, ctx, "karate", "smalltown") / Economy.classMult(d, ctx, "boxing", "smalltown") - 1.1) < 1e-9, "premium dojo +10% karate only")
	check(Economy.classMult(d, ctx, "muaythai", "bangkok") > Economy.classMult(d, ctx, "boxing", "bangkok"), "Bangkok bonus for Muay Thai")
	check(not Economy.spend(d, -5), "negative spend rejected")
	check(not Economy.spend(d, 0 / 0), "NaN spend rejected")
	check(not Economy.spend(d, d.cash + 1), "overspend rejected")
end)

suite("trainers: scouting odds, market, upgrades", function()
	local d = Schema.validate(Schema.defaults())
	d.cash = 1e15
	local counts = {}
	local rng = RNG.new(99)
	local N = 20000
	for _ = 1, N do
		local r = TrainerGen.rollRarity(rng)
		counts[r] = (counts[r] or 0) + 1
	end
	for _, r in ipairs(Trainers.rarities) do
		local observed = (counts[r.id] or 0) / N * 100
		check(math.abs(observed - r.odds) < math.max(1.2, r.odds * 0.25), "odds " .. r.id .. " ~" .. r.odds .. "% (got " .. string.format("%.2f", observed) .. ")")
	end
	local ok, res = TrainerGen.scout(d, rng, "boxing")
	check(not ok, "scouting needs unlocked discipline")
	ok, res = TrainerGen.scout(d, rng, "karate")
	check(ok and d.trainers[res.uid] and d.trainers[res.uid].discipline == "karate", "scout karate trainer")
	-- market is deterministic per day
	local a = TrainerGen.marketOffers(500, d.disciplines)
	local b = TrainerGen.marketOffers(500, d.disciplines)
	eq(a[1].trainer.name, b[1].trainer.name, "market deterministic")
	d.gems = 100000
	check(TrainerGen.buyMarket(d, 500, 1), "buy market offer")
	ok = TrainerGen.buyMarket(d, 500, 1)
	check(not ok, "cannot buy the same offer twice")
	-- train
	local t = d.trainers[res.uid]
	local before = Formulas.trainerStats(t).satisfaction
	check(TrainerGen.train(d, res.uid), "train trainer")
	check(Formulas.trainerStats(t).satisfaction > before, "training improves stats")
	-- XP
	local lvl = TrainerGen.addXp(t, 100000)
	check(lvl and lvl <= Trainers.rarityById[t.rarity].maxLevel, "trainer levels capped")
	-- roster limit
	for _ = 1, Trainers.ROSTER_LIMIT do
		TrainerGen.add(d, TrainerGen.generate(rng, "karate", "common"))
	end
	ok = TrainerGen.scout(d, rng, "karate")
	check(not ok, "roster limit enforced")
	-- premium trainer cannot be released
	local uid = TrainerGen.add(d, TrainerGen.fromMaster("m_premium"))
	check(not TrainerGen.release(d, uid, function() return false end), "premium trainer kept")
end)

---------------------------------------------------------------------------
-- Play the simulation for a while with a simple "bot" strategy and report
-- the economy. This is the balance test.
local function botPlay(hours, verbose)
	local d = Schema.validate(Schema.defaults())
	local rng = RNG.new(2024)
	local now = NOW
	local sim = Simulation.new(d.activeCity, now)
	local served, classes, visitors, left = 0, 0, 0, 0
	local milestones = {}
	local function tryBuild(roomId)
		for slot = 1, Academy.slotCount(d, d.activeCity) do
			if not d.cities[d.activeCity].rooms[tostring(slot)] then
				local ok = Academy.build(d, { now = now }, d.activeCity, slot, roomId)
				return ok, slot
			end
		end
		return false
	end
	local dt = 1
	local lastDay = now
	for step = 1, hours * 3600 do
		now = now + dt
		local ctx = { now = now, event = Events.active({ month = 11, day = 12 }) }
		Academy.finishConstruction(d, now)
		local plans = Simulation.step(d, sim, ctx, rng, dt)
		for _, p in ipairs(plans) do
			visitors = visitors + 1
			if p.outcome ~= "train" then
				left = left + 1
			end
		end
		for _, r in ipairs(Simulation.settle(d, sim, ctx, rng)) do
			served = served + 1
			if r.newClass then
				classes = classes + 1
			end
		end
		if now - lastDay >= Progression.DAY_SECONDS then
			lastDay = now
			Simulation.businessDay(d, ctx, Simulation.takeAverageSatisfaction(sim))
		end
		if verbose and step % 3600 == 0 then
			io.write(string.format("      hour %d: level %d rep %d cash %s earned %s city %s\n", step / 3600, d.level, math.floor(d.reputation), Format.cash(d.cash), Format.cash(d.stats.totalEarned), d.activeCity))
		end
		if step % 30 == 0 then
			Academy.collect(d) -- the bot collects every 30 s
			-- strategy: unlock next discipline, build its room, hire, upgrade, expand
			-- save up for the next city once level and reputation allow it
			local upcoming = Cities.list[Academy.unlockedCityCount(d) + 1]
			local saving = upcoming and d.level >= upcoming.unlock.level and d.reputation >= upcoming.unlock.reputation
			for _, disc in ipairs(Disciplines.list) do
				if not saving and not d.disciplines[disc.id] and d.level >= disc.unlock.level and d.cash > disc.unlock.cost * 2.5 then
					Academy.unlockDiscipline(d, disc.id)
				end
			end
			for _, disc in ipairs(Disciplines.list) do
				if d.disciplines[disc.id] and Academy.countRooms(d.cities[d.activeCity], disc.id .. "_room") == 0 then
					local ok, slot = tryBuild(disc.id .. "_room")
					if ok then
						local hired = TrainerGen.add(d, TrainerGen.generate(rng, disc.id, "common"))
						Academy.assignTrainer(d, d.activeCity, slot, hired)
					end
				end
			end
			for _, id in ipairs({ "locker_room", "juice_bar", "fitness_room", "showers" }) do
				if Academy.countRooms(d.cities[d.activeCity], id) == 0 and d.level >= Rooms.byId[id].unlockLevel then
					tryBuild(id)
				end
			end
			for slot, room in pairs(d.cities[d.activeCity].rooms) do
				if not saving and room.level < 5 and d.cash > Formulas.roomUpgradeCost(room.id, room.level, d.activeCity) * 3 then
					Academy.upgrade(d, { now = now }, d.activeCity, tonumber(slot))
				end
				if Rooms.byId[room.id].kind == "training" then
					Academy.setTier(d, d.activeCity, tonumber(slot), Academy.maxTier(d, room.id, room.level))
				end
			end
			local nextCity = Cities.list[Academy.unlockedCityCount(d) + 1]
			if nextCity and Academy.unlockCity(d, nextCity.id) then
				Academy.switchCity(d, nextCity.id)
				sim = Simulation.new(nextCity.id, now)
				table.insert(milestones, string.format("%5.1fh %s (lvl %d)", (now - NOW) / 3600, nextCity.name, d.level))
			end
		end
	end
	return { d = d, served = served, classes = classes, visitors = visitors, left = left, milestones = milestones, sim = sim }
end

suite("simulation: a played academy earns, levels up and expands", function()
	local r = botPlay(tonumber(os.getenv("BOT_HOURS") or 3), os.getenv("BOT_VERBOSE"))
	local d = r.d
	io.write(string.format("    bot: level %d, rep %d, cash %s, earned %s, served %d, classes %d, left %d/%d, cities %d, members %d\n",
		d.level, math.floor(d.reputation), Format.cash(d.cash), Format.cash(d.stats.totalEarned), r.served, r.classes, r.left, r.visitors, Academy.unlockedCityCount(d), d.cities[d.activeCity].members))
	for _, m in ipairs(r.milestones) do
		io.write("      " .. m .. "\n")
	end
	check(r.served > 300, "students served in 3h")
	check(r.classes > 100, "classes completed")
	check(d.level >= 8, "player levels up (level " .. d.level .. ")")
	check(Academy.unlockedCityCount(d) >= 2, "expanded to a second city within 3 hours")
	check(Academy.unlockedCityCount(d) <= 5, "not everything unlocked in 3 hours (pacing)")
	check(r.left < r.visitors * 0.6, "most visitors find a class")
	check(d.reputation > 100, "reputation grows")
	local masteryAny = false
	for _, m in pairs(d.mastery) do
		if m.rank > 1 then
			masteryAny = true
		end
	end
	check(masteryAny, "mastery ranks gained")
end)

suite("simulation: planning respects capacity and patience", function()
	local d = Schema.validate(Schema.defaults())
	local sim = Simulation.new("smalltown", NOW)
	local rng = RNG.new(5)
	local ctx = { now = NOW }
	local perSession = {}
	for i = 1, 60 do
		ctx.now = NOW + i * 0.5
		local plan = Simulation.planVisit(d, sim, ctx, rng)
		if plan.outcome == "train" then
			perSession[plan.tSession] = (perSession[plan.tSession] or 0) + 1
			check(plan.tSession >= plan.tDeskDone, "class after reception")
			check(plan.satisfaction >= 0 and plan.satisfaction <= 100, "satisfaction in range")
			check(plan.pay > 0, "positive pay")
		end
	end
	local cap = Formulas.roomCapacity("karate_room", 1, Formulas.trainerStats(d.trainers.t1))
	for t, n in pairs(perSession) do
		check(n <= cap, "session at " .. t .. " within capacity (" .. n .. "/" .. cap .. ")")
	end
	check(sim.lostTotal > 0, "some visitors leave when the dojo is full or uninterested")
	-- no operational room -> everyone leaves
	local d2 = Schema.validate(Schema.defaults())
	d2.cities.smalltown.rooms["1"].trainer = nil
	local sim2 = Simulation.new("smalltown", NOW)
	local plan = Simulation.planVisit(d2, sim2, { now = NOW }, rng)
	eq(plan.outcome, "leave", "no trainer -> visitor leaves")
end)

suite("simulation: most visitors are beginners, black belts are rare", function()
	local d = Schema.validate(Schema.defaults())
	d.mastery.karate = { rank = 9, xp = 0 }
	d.reputation = 50000
	local sim = Simulation.new("smalltown", NOW)
	local rng = RNG.new(77)
	local counts, n = {}, 0
	for i = 1, 3000 do
		local plan = Simulation.planVisit(d, sim, { now = NOW + i * 60 }, rng)
		if plan.interest == "karate" and plan.rank then
			counts[plan.rank] = (counts[plan.rank] or 0) + 1
			n = n + 1
		end
	end
	local low = (counts[1] or 0) + (counts[2] or 0) + (counts[3] or 0)
	local black = 0
	for r = 7, 9 do
		black = black + (counts[r] or 0)
	end
	io.write(string.format("    %d karate visitors: white-orange %d%%, black belt %d%%\n", n, math.floor(low * 100 / n), math.floor(black * 100 / n)))
	check(low / n > 0.6, "most karate visitors wear white, yellow or orange belts")
	check(black / n < 0.1, "black belts are rare")
	check(black > 0, "black belts do appear at a high-level academy")
end)

suite("simulation: business day pays dues and charges expenses", function()
	local d = Schema.validate(Schema.defaults())
	d.cash = 1000
	d.cities.smalltown.members = 50
	local exp = Academy.expensesPerDay(d, "smalltown")
	local rep = Simulation.businessDay(d, { now = NOW }, 80)
	check(rep.dues > 0, "members pay dues")
	eq(rep.expenses, exp.total, "expenses charged")
	check(d.cities.smalltown.members < 50, "some churn")
	d.cash = 0
	local rep2 = Simulation.businessDay(d, { now = NOW }, 80)
	check(d.cash >= 0, "cash never negative")
	check(rep2.unpaid >= 0, "unpaid tracked")
end)

---------------------------------------------------------------------------
suite("progress: missions, daily login, events, cosmetics, rebirth", function()
	local d = Schema.validate(Schema.defaults())
	check(Progress.refreshQuests(d, NOW, 123), "missions rolled")
	eq(#d.quests.daily, 3, "3 daily missions")
	eq(#d.quests.weekly, 3, "3 weekly missions")
	check(not Progress.refreshQuests(d, NOW + 60, 123), "same day keeps missions")
	local q = d.quests.daily[1]
	local def = Quests.byId[q.id]
	local done = Progress.track(d, def.track, q.target)
	check(#done >= 1, "mission completes")
	local ok = Progress.claimQuest(d, "daily", 1)
	check(ok, "claim mission")
	check(not Progress.claimQuest(d, "daily", 1), "no double claim")
	check(not Progress.claimQuest(d, "daily", 9), "invalid index rejected")
	-- daily
	local ok1, r1 = Progress.claimDaily(d, NOW)
	check(ok1 and r1.day == 1, "daily day 1")
	check(not Progress.claimDaily(d, NOW + 3600), "one claim per day")
	local ok2, r2 = Progress.claimDaily(d, NOW + 86400)
	check(ok2 and r2.day == 2, "streak continues")
	local ok3, r3 = Progress.claimDaily(d, NOW + 86400 * 4)
	check(ok3 and r3.day == 1, "missed day resets streak")
	-- events
	local ev = Events.byId.festival
	Progress.addEventPoints(d, ev, NOW, 250)
	check(Progress.claimEventReward(d, ev, NOW, 1), "event reward 1")
	check(d.cosmetics.owned.deco_festival_banner, "event cosmetic owned")
	check(not Progress.claimEventReward(d, ev, NOW, 2), "reward 2 needs more points")
	check(not Progress.claimEventReward(d, ev, NOW, 1), "no double event claim")
	-- cosmetics
	check(not Progress.buyCosmetic(d, "outfit_mma"), "pass cosmetic not for sale")
	d.gems = 1000
	check(Progress.buyCosmetic(d, "aura_spirit"), "buy cosmetic with gems")
	check(Progress.equipCosmetic(d, "aura_spirit", true), "equip aura")
	eq(d.cosmetics.equipped.aura, "aura_spirit", "aura equipped")
	check(not Progress.equipCosmetic(d, "aura_legendary", true), "cannot equip unowned")
	-- objective guide
	d.flags.hasPlot = true
	eq(Progress.currentObjective(d).id, "collect", "next objective: collect")
	-- rebirth
	check(not Progress.rebirth(d), "rebirth locked early")
	d.level = 40
	for i = 2, 6 do
		d.cities[Cities.list[i].id] = Schema.newBranch()
	end
	local gems = d.gems
	local ok4, info = Progress.rebirth(d)
	check(ok4, "rebirth")
	eq(d.level, 1, "level reset")
	eq(Academy.unlockedCityCount(d), 1, "cities reset")
	check(d.gems > gems, "gems kept + reward")
	check(d.trainers.t1 ~= nil, "trainers kept")
	check(d.cosmetics.owned.aura_spirit, "cosmetics kept")
	check(d.cosmetics.owned.aura_rebirth, "rebirth cosmetic granted")
	eq(Formulas.rebirthMult(d.rebirths), 1.25, "permanent income bonus")
	check(info.title ~= nil, "prestige title")
end)

suite("purchases: receipts are idempotent, passes apply once", function()
	local d = Schema.validate(Schema.defaults())
	local ledger = ReceiptLedger.new()
	local ctx = { now = NOW }
	local grants = 0
	local function process(receiptId, key)
		return ReceiptLedger.process(ledger, d, receiptId, function()
			grants = grants + 1
			return Purchases.grantProduct(d, key, ctx)
		end)
	end
	local cash0 = d.cash
	eq(process("r1", "cash_small"), "granted", "first receipt granted")
	eq(process("r1", "cash_small"), "duplicate", "duplicate receipt not granted again")
	eq(grants, 1, "grant ran once")
	eq(d.cash - cash0, 5000, "small cash pack min amount")
	eq(process("r2", "nonexistent"), "failed", "unknown product fails (not granted)")
	-- record survives in save data
	check(ReceiptLedger.seen(ledger, d, "r1"), "receipt remembered")
	local ledger2 = ReceiptLedger.new()
	eq(ReceiptLedger.process(ledger2, d, "r1", function() grants = grants + 1 return true end), "duplicate", "remembered across server restarts via save data")
	-- boosts
	check(Purchases.grantProduct(d, "boost_customers", ctx), "boost product")
	check(Economy.boostActive(d, "customers", NOW + 10), "boost active")
	-- passes
	local rng = RNG.new(3)
	Purchases.applyPass(d, "bundle_starter", rng)
	local cash1, gems1 = d.cash, d.gems
	Purchases.applyPass(d, "bundle_starter", rng)
	eq(d.cash, cash1, "starter bundle cash once")
	eq(d.gems, gems1, "starter bundle gems once")
	Purchases.applyPass(d, "premium_trainer", rng)
	Purchases.applyPass(d, "premium_trainer", rng)
	local n = 0
	for _, t in pairs(d.trainers) do
		if t.master == "m_premium" then
			n = n + 1
		end
	end
	eq(n, 1, "premium trainer granted once")
	Purchases.applyPass(d, "vip_owner", rng)
	check(d.cosmetics.owned.title_vip and d.cosmetics.owned.deco_golden_gate, "VIP cosmetics granted")
	check(not Purchases.applyPass(d, "nope", rng), "unknown pass rejected")
end)

suite("security: rate limiter and input validation", function()
	local rl = RateLimiter.new({ default = { rate = 5, burst = 5 } })
	local allowed = 0
	for _ = 1, 20 do
		if RateLimiter.allow(rl, 1, "build", 0) then
			allowed = allowed + 1
		end
	end
	eq(allowed, 5, "burst limited")
	check(RateLimiter.allow(rl, 1, "build", 1), "refills over time")
	check(RateLimiter.allow(rl, 2, "build", 0), "separate bucket per player")
	check(Validate.string("abc", 10) == "abc", "string ok")
	check(Validate.string(string.rep("a", 100), 10) == nil, "long string rejected")
	check(Validate.string(5, 10) == nil, "number is not a string")
	check(Validate.int(3, 1, 5) == 3, "int ok")
	check(Validate.int(3.5, 1, 5) == nil, "fraction rejected")
	check(Validate.int(0 / 0, 1, 5) == nil, "NaN rejected")
	check(Validate.int(1e300, 1, 5) == nil, "huge rejected")
	check(Validate.oneOf("karate", Disciplines.byId) == "karate", "id ok")
	check(Validate.oneOf("__index", Disciplines.byId) == nil, "unknown id rejected")
	check(Validate.oneOf({}, Disciplines.byId) == nil, "table key rejected")
end)

---------------------------------------------------------------------------
suite("appearance: every discipline looks like its martial art", function()
	local Appearance = H.load("ReplicatedStorage/Shared/Modules/Appearance")
	local function kinds(spec)
		local k = {}
		for _, e in ipairs(spec.extras) do
			k[e.kind] = e
		end
		return k
	end
	for _, d in ipairs(Disciplines.list) do
		for seed = 1, 40 do
			local s = Appearance.describe({ seed = seed, discipline = d.id, role = "student", rank = 3 })
			local k = kinds(s)
			if d.id == "karate" or d.id == "taekwondo" or d.id == "judo" then
				check(k.belt ~= nil, d.id .. " student wears a belt")
				check(k.lapel ~= nil, d.id .. " student wears a gi/dobok with lapels")
			end
			if d.id == "sumo" then
				check(s.body == "sumo", "sumo body type")
				check(k.mawashi ~= nil and k.sagari ~= nil, "sumo wears mawashi + sagari")
				check(k.hair and k.hair.style == "chonmage", "sumo topknot")
			end
			if d.id == "boxing" then
				check(k.gloves and k.gloves.style == "boxing", "boxer wears boxing gloves")
			end
			if d.id == "muaythai" then
				check(k.prajiad ~= nil, "muay thai prajiad armbands")
				check(s.bottom == "thai_shorts", "muay thai shorts")
			end
			if d.id == "kickboxing" then
				check(k.shins ~= nil, "kickboxer shin guards")
			end
			if d.id == "wrestling" then
				check(s.singlet == true, "wrestler singlet")
			end
			if d.id == "kungfu" then
				check(k.buttons ~= nil and k.belt and k.belt.sash, "kung fu uniform with sash")
			end
		end
		local t = Appearance.describe({ seed = 5, discipline = d.id, role = "trainer", rarity = "legendary" })
		check(t.aura ~= nil, d.id .. " legendary trainer has an aura")
		check(t.body ~= "kid", d.id .. " trainer is an adult")
	end
	-- karate: always a white gi; the belt shows the grade
	local k = Appearance.describe({ seed = 1, discipline = "karate", role = "trainer" })
	eq(k.colors.Chest[1], 245, "karate sensei wears a white gi")
	eq(kinds(k).belt.color[1], 25, "karate sensei wears a black belt")
	local master = Appearance.describe({ seed = 2, discipline = "karate", role = "trainer", rarity = "legendary" })
	check(kinds(master).belt.stripe ~= nil, "legendary karate master wears a dan-striped black belt")
	-- gi-based arts: always a white uniform, the belt shows the grade
	for _, id in ipairs({ "karate", "judo", "taekwondo", "bjj" }) do
		for seed = 1, 30 do
			for _, role in ipairs({ "student", "trainer" }) do
				local st = Appearance.describe({ seed = seed, discipline = id, role = role, rank = 1 + seed % 7, rarity = "rare" })
				if st.top ~= "rashguard" then
					eq(st.colors.Chest[1], 245, id .. " " .. role .. " wears a white uniform")
				end
			end
		end
	end
	-- variety: 40 karate students are not identical
	local seen = {}
	local distinct = 0
	for seed = 1, 40 do
		local s = Appearance.describe({ seed = seed, discipline = "karate", role = "student" })
		local key = s.body .. table.concat(s.skin, ",") .. ((kinds(s).hair or {}).style or "bald")
		if not seen[key] then
			seen[key] = true
			distinct = distinct + 1
		end
	end
	check(distinct >= 25, "procedural variety (" .. distinct .. "/40 distinct)")
	-- same seed, same person
	local a = Appearance.describe({ seed = 77, discipline = "judo" })
	local b = Appearance.describe({ seed = 77, discipline = "judo" })
	eq(a.body .. a.skin[1], b.body .. b.skin[1], "deterministic appearance")
	-- VIPs and celebrities stand out
	local vip = kinds(Appearance.describe({ seed = 3, discipline = "boxing", category = "vip" }))
	check(vip.sunglasses ~= nil, "VIP sunglasses")
	check(Appearance.describe({ seed = 3, discipline = "boxing", category = "celebrity" }).aura ~= nil, "celebrity glow")
end)

suite("outfits: rank outfits have clothing for every rank", function()
	local Clothing = H.load("ReplicatedStorage/Shared/Config/Clothing")
	for _, c in ipairs(Cosmetics.list) do
		if c.kind == "outfit" then
			local disc = c.discipline and Disciplines.byId[c.discipline]
			local n = disc and #disc.ranks or 1
			for rank = 1, n do
				if c.rankShirt then
					check(Clothing[Clothing.rankName(c.rankShirt, rank)] ~= nil, c.id .. " shirt for rank " .. rank)
				end
				if c.rankPants then
					check(Clothing[Clothing.rankName(c.rankPants, rank)] ~= nil, c.id .. " pants for rank " .. rank)
				end
			end
			if c.champPants then
				check(Clothing[c.champPants] ~= nil and Clothing[c.champPants .. "_champ"] ~= nil, c.id .. " champion shorts")
			end
			for _, k in ipairs({ "shirt", "pants" }) do
				if c[k] then
					check(Clothing[c[k]] ~= nil, c.id .. " " .. k .. " template exists")
				end
			end
			if c.source == "discipline" then
				check(disc ~= nil, c.id .. " has a discipline")
			end
		end
	end
	-- unlocking a discipline makes its uniform available
	local d = Schema.validate(Schema.defaults())
	d.disciplines.judo = true
	Progress.syncCosmetics(d)
	check(d.cosmetics.owned.outfit_judo, "judogi owned after unlocking judo")
end)

suite("poses: sampling and blending", function()
	local m = Poses.moves.karate_punch
	local p0 = Poses.sample(m, 0)
	local p1 = Poses.sample(m, 0.15)
	check(p1.rsp and p1.rsp > 80, "punch extends the right arm")
	check((p0.rsp or 0) < 30, "punch starts chambered")
	local looped = Poses.sample(m, m.length + 0.15)
	check(math.abs((looped.rsp or 0) - p1.rsp) < 1e-6, "looping moves wrap")
	local once = Poses.sample(Poses.moves.rankup, 100)
	check(once ~= nil, "one-shot moves hold the last key")
	local air = Poses.sample(Poses.moves.rankup, 0.6)
	eq(air.grounded, false, "jump keyframe is airborne")
end)

---------------------------------------------------------------------------
local res = H.results
io.write(string.format("\n%d checks passed, %d failed\n", res.passed, res.failed))
if res.failed > 0 then
	for _, f in ipairs(res.failures) do
		io.write("  - " .. f .. "\n")
	end
	os.exit(1)
end
