-- Room management: level and upgrade, capacity, class selection, trainer
-- assignment, construction status (with Instant Construction), championship
-- hosting for the arena, and removing the room.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Rooms = require(Shared.Config.Rooms)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)
local Monetization = require(Shared.Config.Monetization)

local Kit = require(script.Parent.Parent.Kit)
local Preview = require(script.Parent.Parent.Preview)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

-- Highest class tier this room may run (mirror of the server rule, display only).
local function maxTier(d, room)
	local def = Rooms.byId[room.id]
	local best = 1
	for _, tier in ipairs(Disciplines.tiers) do
		local okRank = true
		if def.discipline and def.discipline ~= "fitness" then
			local disc = Disciplines.byId[def.discipline]
			local m = d.mastery[def.discipline]
			okRank = (m and m.rank or 1) >= Disciplines.tierRankRequirement(disc, tier.id)
		end
		if room.level >= tier.roomLevel and okRank then
			best = tier.id
		end
	end
	return best
end

return {
	title = "Manage Room",
	width = 820,
	height = 600,
	build = function(body, args, ui)
		local slot = args.slot
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.list(scroll, 10)
		local lastSig
		local function render()
			local d = State.data
			local cityId = d.activeCity
			local room = d.cities[cityId].rooms[tostring(slot)]
			if not room then
				ui.close()
				return
			end
			-- only rebuild when something visible changed (state arrives twice a second)
			local trainerCount = 0
			for _ in pairs(d.trainers) do
				trainerCount = trainerCount + 1
			end
			local building = room.buildEnd ~= nil and room.buildEnd > workspace:GetServerTimeNow()
			local sig = table.concat({ room.id, room.level, room.tier or 1, tostring(room.trainer), tostring(building), trainerCount,
				tostring(d.cash >= Formulas.roomUpgradeCost(room.id, math.min(room.level, Rooms.MAX_LEVEL - 1), cityId)), tostring(d.flags.arenaReadyAt), d.level }, "|")
			if sig == lastSig and not building then
				return
			end
			lastSig = sig
			Kit.clear(scroll)
			local def = Rooms.byId[room.id]
			local now = workspace:GetServerTimeNow()
			local trainer = room.trainer and d.trainers[room.trainer]
			local stats = trainer and Formulas.trainerStats(trainer)

			-- header card
			local head = Kit.card(scroll, 96, 1)
			Kit.label(head, def.name, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 30), TextSize = 24, Font = Kit.fontBlack, TextColor3 = Kit.c3(def.color) })
			Kit.label(head, string.rep("★", room.level) .. string.rep("☆", Rooms.MAX_LEVEL - room.level) .. "   Level " .. room.level .. " / " .. Rooms.MAX_LEVEL, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -200, 0, 22), TextColor3 = C.gold })
			local capText = ""
			if def.capacity then
				capText = "Capacity " .. Formulas.roomCapacity(room.id, room.level, stats) .. " students"
			elseif def.satisfaction then
				capText = "+" .. math.floor(def.satisfaction * (1 + 0.25 * (room.level - 1))) .. " satisfaction for every visitor"
			elseif def.shopSpend then
				capText = "Visitors spend ~" .. Format.cash(def.shopSpend * (1 + 0.3 * (room.level - 1))) .. " (x city income)"
			end
			Kit.label(head, capText, { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -200, 0, 22), TextColor3 = C.muted, TextSize = 14 })

			if building then
				local remaining = room.buildEnd - now
				Kit.label(head, "Under construction: " .. Format.time(remaining), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(240, 24), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(240, 160, 60) })
				local p = Monetization.productByKey.instant_build
				local b = Kit.button(head, "⚡ Finish now (Robux)", function()
					if p.id ~= 0 then
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, p.id)
					elseif RunService:IsStudio() then
						ui.act("devGrant", { kind = "product", key = p.key }, "Studio test: construction finished")
					else
						ui.toast("This product is not configured yet", "warn")
					end
				end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 44), Size = UDim2.fromOffset(220, 40) }, "gold")
				b.Name = "Instant"
				return
			end

			-- upgrade
			local up = Kit.card(scroll, 60, 2)
			if room.level < Rooms.MAX_LEVEL then
				local cost = Formulas.roomUpgradeCost(room.id, room.level, cityId)
				Kit.label(up, "Upgrade to level " .. (room.level + 1) .. ": more capacity, new equipment and better classes", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -230, 1, 0), TextSize = 14 })
				local b = Kit.button(up, "Upgrade " .. Format.cash(cost), function()
					ui.act("upgrade", { slot = slot }, def.name .. " upgrading!")
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(200, 42) }, d.cash >= cost and "gold" or "dark")
				Kit.setEnabled(b, d.cash >= cost)
			else
				Kit.label(up, "Maximum level reached ★★★★★", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), TextColor3 = C.gold })
			end

			-- classes
			if def.kind == "training" then
				local mt = maxTier(d, room)
				local classes = Kit.card(scroll, 196, 3)
				Kit.label(classes, "CLASS SCHEDULE", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = C.gold, Font = Kit.fontBlack })
				for tier = 1, 5 do
					local info = Formulas.classInfo(room.id, tier)
					local row = Kit.frame(classes, { BackgroundColor3 = room.tier == tier and C.goldDark or C.panel, Position = UDim2.fromOffset(10, 28 + (tier - 1) * 33), Size = UDim2.new(1, -20, 0, 30) })
					Kit.corner(row, 6)
					local locked = tier > mt
					Kit.label(row, info.tierName .. ": " .. info.name, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.55, 0, 1, 0), TextSize = 14, TextColor3 = locked and C.muted or C.text })
					Kit.label(row, "$" .. Format.short(info.pay) .. " base • " .. info.duration .. "s", { Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), TextSize = 13, TextColor3 = C.muted })
					if room.tier == tier then
						Kit.label(row, "RUNNING", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(110, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
					elseif locked then
						local why = room.level < Disciplines.tiers[tier].roomLevel and ("Room lvl " .. Disciplines.tiers[tier].roomLevel) or "Mastery rank"
						Kit.label(row, "🔒 " .. why, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(140, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.muted, TextSize = 12 })
					else
						Kit.button(row, "Run", function()
							ui.act("setTier", { slot = slot, tier = tier }, info.name .. " is now running")
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(70, 24), TextSize = 13 }, "gold")
					end
				end
			end

			-- trainer
			if def.needsTrainer then
				local tc = Kit.card(scroll, 170, 4)
				Kit.label(tc, "TRAINER", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = C.gold, Font = Kit.fontBlack })
				if trainer then
					local r = Trainers.rarityById[trainer.rarity]
					Preview.character(tc, { seed = trainer.seed, discipline = trainer.discipline, role = "trainer", rarity = trainer.rarity }, { Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(110, 130) })
					Kit.label(tc, trainer.name, { Position = UDim2.fromOffset(136, 30), Size = UDim2.new(1, -300, 0, 24), TextSize = 18, Font = Kit.fontBlack })
					Kit.pill(tc, r.name, Kit.c3(r.color), { Position = UDim2.fromOffset(136, 58) })
					Kit.label(tc, string.format("Lv %d  •  Speed x%.2f  •  +%d capacity  •  +%d satisfaction  •  Salary %s/day", trainer.level, stats.speed, stats.capacity, math.floor(stats.satisfaction), Format.cash(stats.salary)), { Position = UDim2.fromOffset(136, 84), Size = UDim2.new(1, -150, 0, 40), TextSize = 13, TextColor3 = C.muted })
					Kit.button(tc, "Unassign", function()
						ui.act("unassignTrainer", { slot = slot }, "Trainer unassigned")
					end, { Position = UDim2.fromOffset(136, 126), Size = UDim2.fromOffset(120, 34), TextSize = 14 }, "dark")
				else
					Kit.label(tc, "No trainer: this room cannot run classes. Assign one below or recruit in the Trainers menu.", { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 40), TextColor3 = C.bad, TextSize = 14 })
				end
				-- candidates
				local candidates = {}
				for uid, t in pairs(d.trainers) do
					local fits = def.kind ~= "training" or t.discipline == def.discipline
					if fits and uid ~= room.trainer then
						table.insert(candidates, t)
					end
				end
				table.sort(candidates, function(a, b)
					return Trainers.rarityById[a.rarity].order > Trainers.rarityById[b.rarity].order
				end)
				local candCard = Kit.card(scroll, 40 + math.max(1, math.min(#candidates, 6)) * 38, 5)
				Kit.label(candCard, #candidates > 0 and "AVAILABLE TRAINERS" or "No matching trainers in your roster.", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = C.gold, Font = Kit.fontBlack })
				for i = 1, math.min(#candidates, 6) do
					local t = candidates[i]
					local r = Trainers.rarityById[t.rarity]
					local row = Kit.frame(candCard, { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(10, 30 + (i - 1) * 38), Size = UDim2.new(1, -20, 0, 34) })
					Kit.corner(row, 6)
					Kit.label(row, t.name .. "  (" .. Disciplines.byId[t.discipline].name .. ", Lv " .. t.level .. ")", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 14 })
					Kit.pill(row, r.name, Kit.c3(r.color), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.6, 0, 0.5, 0) })
					Kit.button(row, "Assign", function()
						ui.act("assignTrainer", { slot = slot, uid = t.uid }, t.name .. " assigned")
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(90, 28), TextSize = 13 }, "gold")
				end
			end

			-- arena: championships
			if def.kind == "arena" then
				local ac = Kit.card(scroll, 150, 6)
				Kit.label(ac, "HOST A CHAMPIONSHIP", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = C.gold, Font = Kit.fontBlack })
				local fee = Formulas.rewardCashUnit(d.level) * 3
				local readyAt = d.flags.arenaReadyAt or 0
				local resting = os.time() < readyAt
				Kit.label(ac, "Entry fee " .. Format.cash(fee) .. ". Lasts 45 s. Prize money and reputation grow with arena level and city." .. (resting and ("  Arena resting: " .. Format.time(readyAt - os.time())) or ""), { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 40), TextSize = 13, TextColor3 = C.muted })
				local holder = Kit.frame(ac, { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -28, 0, 66) })
				Kit.grid(holder, UDim2.fromOffset(118, 30), 6)
				for _, disc in ipairs(Disciplines.list) do
					if d.disciplines[disc.id] then
						local b = Kit.button(holder, disc.name, function()
							ui.act("hostChampionship", { discipline = disc.id }, disc.name .. " Championship started!")
						end, { TextSize = 12 }, "dark")
						Kit.setEnabled(b, not resting and d.cash >= fee)
					end
				end
			end

			-- remove
			if room.id == "reception" then
				return
			end
			local rm = Kit.card(scroll, 50, 9)
			Kit.label(rm, "Remove this room (40% refund of its build price).", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0), TextSize = 13, TextColor3 = C.muted })
			Kit.button(rm, "Remove", function()
				ui.confirm("Remove " .. def.name .. "?", "The room and its upgrades are removed. You get 40% of the build price back. Its trainer returns to your roster.", function()
					ui.act("removeRoom", { slot = slot }, def.name .. " removed")
					ui.close()
				end)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 36), TextSize = 14 }, "bad")
		end
		render()
		return render
	end,
}
