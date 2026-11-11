-- Trainer collection (3D previews, stats, abilities, training), recruiting
-- with cash (odds shown) and the daily gem market (fixed offers and prices).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)

local Kit = require(script.Parent.Parent.Kit)
local Preview = require(script.Parent.Parent.Preview)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function assignedRoom(d, uid)
	for cityId, branch in pairs(d.cities) do
		for slot, room in pairs(branch.rooms) do
			if room.trainer == uid then
				return cityId, slot
			end
		end
	end
	return nil
end

local function trainerCard(parent, t, d, ui, order)
	local r = Trainers.rarityById[t.rarity]
	local disc = Disciplines.byId[t.discipline]
	local stats = Formulas.trainerStats(t)
	local card = Kit.frame(parent, { BackgroundColor3 = C.panel2, LayoutOrder = order })
	Kit.corner(card, 10)
	Kit.stroke(card, Kit.c3(r.color), 2)
	Preview.character(card, { seed = t.seed, discipline = t.discipline, role = "trainer", rarity = t.rarity }, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 150) })
	Kit.pill(card, r.name, Kit.c3(r.color), { Position = UDim2.fromOffset(10, 10) })
	Kit.label(card, t.name, { Position = UDim2.fromOffset(8, 160), Size = UDim2.new(1, -16, 0, 20), TextSize = 15, Font = Kit.fontBlack })
	Kit.label(card, (t.title or (disc.trainerTitle .. " • " .. disc.name)) .. "  •  Lv " .. t.level, { Position = UDim2.fromOffset(8, 180), Size = UDim2.new(1, -16, 0, 18), TextSize = 12, TextColor3 = C.muted })
	local ability = t.ability and Trainers.abilityById[t.ability]
	local spec = t.spec and Trainers.specById[t.spec]
	local lines = string.format("Speed x%.2f  Cap +%d  Sat +%d\nSalary %s/day", stats.speed, stats.capacity, math.floor(stats.satisfaction), Format.cash(stats.salary))
	if spec then
		lines = lines .. "\n" .. spec.name
	end
	if ability then
		lines = lines .. "\n★ " .. ability.name .. ": " .. ability.text
	end
	Kit.label(card, lines, { Position = UDim2.fromOffset(8, 200), Size = UDim2.new(1, -16, 0, 70), TextSize = 12, Font = Kit.fontBody, TextYAlignment = Enum.TextYAlignment.Top })
	local _, xpFill = Kit.progress(card, t.xp / math.max(1, Formulas.trainerXpForLevel(t.level)), Kit.c3(r.color), { Position = UDim2.new(0, 8, 0, 272), Size = UDim2.new(1, -16, 0, 6) })
	xpFill.Name = "XP"
	local cityId, slot = assignedRoom(d, t.uid)
	local status = cityId and ("Teaching in slot " .. slot .. (cityId ~= d.activeCity and (" (" .. cityId .. ")") or "")) or "Available"
	Kit.label(card, status, { Position = UDim2.fromOffset(8, 282), Size = UDim2.new(1, -16, 0, 16), TextSize = 11, TextColor3 = cityId and C.good or C.muted })
	local maxUp = Formulas.trainerMaxUpgrade(t)
	if t.upgrade < maxUp then
		local cost = Formulas.trainerTrainCost(t)
		local b = Kit.button(card, "Train " .. Format.cash(cost) .. " (" .. t.upgrade .. "/" .. maxUp .. ")", function()
			ui.act("trainTrainer", { uid = t.uid }, t.name .. " trained!")
		end, { Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(1, -54, 0, 34), TextSize = 12 }, "gold")
		Kit.setEnabled(b, d.cash >= cost)
	else
		Kit.label(card, "Fully trained", { Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(1, -54, 0, 34), TextColor3 = C.gold, TextSize = 13 })
	end
	if not t.master or t.master ~= "m_premium" then
		Kit.button(card, "✕", function()
			ui.confirm("Release " .. t.name .. "?", "This trainer leaves your academy for good.", function()
				ui.act("releaseTrainer", { uid = t.uid }, t.name .. " released")
			end)
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 1, -42), Size = UDim2.fromOffset(38, 34), TextSize = 14 }, "bad")
	end
	return card
end

return {
	title = "Trainers",
	width = 900,
	height = 620,
	build = function(body, args, ui)
		local tab = args.tab or "collection"
		local content = Kit.frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		local lastSig
		local function render(force)
			local d, x = State.data, State.derived
			local count = 0
			local levelSum = 0
			for _, t in pairs(d.trainers) do
				count = count + 1
				levelSum = levelSum + t.level * 100 + t.upgrade
			end
			local sig = tab .. "|" .. count .. "|" .. levelSum .. "|" .. tostring(d.cash >= x.scoutCost) .. "|" .. d.gems .. "|" .. table.concat((function()
				local b = {}
				for i, v in ipairs(x.marketBought) do
					b[i] = tostring(v)
				end
				return b
			end)(), ",")
			if sig == lastSig and not force then
				return
			end
			lastSig = sig
			Kit.clear(content)
			if tab == "collection" then
				local list = {}
				for _, t in pairs(d.trainers) do
					table.insert(list, t)
				end
				table.sort(list, function(a, b)
					local ra, rb = Trainers.rarityById[a.rarity].order, Trainers.rarityById[b.rarity].order
					if ra ~= rb then
						return ra > rb
					end
					return a.level > b.level
				end)
				Kit.label(content, count .. " / " .. Trainers.ROSTER_LIMIT .. " trainers", { Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.muted, TextSize = 14 })
				local scroll = Kit.scroll(content, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24) })
				Kit.grid(scroll, UDim2.fromOffset(200, 350), 10)
				for i, t in ipairs(list) do
					trainerCard(scroll, t, d, ui, i)
				end
			elseif tab == "recruit" then
				local info = Kit.card(content, 150, 1)
				info.Size = UDim2.new(1, 0, 0, 150)
				Kit.label(info, "SCOUT A TRAINER", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -20, 0, 20), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 14 })
				Kit.label(info, "Pick a discipline and pay the scouting fee (" .. Format.cash(x.scoutCost) .. "). The rarity is random with these published odds:", { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 36), TextSize = 14 })
				local odds = Kit.frame(info, { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -28, 0, 30) })
				Kit.list(odds, 6, true)
				for i, r in ipairs(Trainers.rarities) do
					Kit.pill(odds, r.name .. " " .. r.odds .. "%", Kit.c3(r.color), { Size = UDim2.fromOffset(118, 26), LayoutOrder = i })
				end
				Kit.label(info, "Legendary results have a 50% chance to be the discipline's named master (once). The Mythic Grandmaster from the Premium Trainer pass is never a random result.", { Position = UDim2.fromOffset(14, 108), Size = UDim2.new(1, -28, 0, 36), TextSize = 12, TextColor3 = C.muted, Font = Kit.fontBody })
				local grid = Kit.scroll(content, { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 1, -160) })
				Kit.grid(grid, UDim2.fromOffset(205, 60), 8)
				for i, disc in ipairs(Disciplines.list) do
					local unlocked = d.disciplines[disc.id]
					local b = Kit.button(grid, unlocked and ("Scout " .. disc.name) or ("🔒 " .. disc.name), function()
						if not unlocked then
							return
						end
						local ok, res = ui.act("scout", { discipline = disc.id })
						if ok then
							local r = Trainers.rarityById[res.trainer.rarity]
							ui.banner(r.name .. " Trainer!", res.trainer.name .. " joins your " .. disc.name .. " team", Kit.c3(r.color))
							if ui.audio then
								ui.audio.play(r.order >= 4 and "unlock" or "purchase")
							end
						end
					end, { LayoutOrder = i, TextSize = 14, BackgroundColor3 = Kit.c3(disc.accent) }, unlocked and "gold" or "dark")
					if unlocked then
						b.BackgroundColor3 = Kit.c3(disc.accent)
						b.TextColor3 = Color3.new(1, 1, 1)
					end
					Kit.setEnabled(b, unlocked and d.cash >= x.scoutCost)
				end
			elseif tab == "market" then
				Kit.label(content, "Today's market: fixed trainers at fixed gem prices (no randomness). New offers every day at 00:00 UTC.  You have ◆ " .. Format.commas(d.gems), { Size = UDim2.new(1, 0, 0, 40), TextSize = 14, TextColor3 = C.muted })
				local row = Kit.frame(content, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46) })
				Kit.grid(row, UDim2.fromOffset(260, 400), 14)
				for i, offer in ipairs(x.market) do
					local t = offer.trainer
					t.uid = "market" .. i
					local card = trainerCard(row, t, d, ui, i)
					-- replace the train/release buttons with a buy button
					for _, child in ipairs(card:GetChildren()) do
						if child:IsA("TextButton") or (child:IsA("TextLabel") and (child.Text == "Available" or child.Text == "Fully trained")) then
							child:Destroy()
						end
					end
					local bought = x.marketBought[i]
					local b = Kit.button(card, bought and "Recruited" or ("Recruit ◆ " .. offer.price), function()
						ui.act("buyMarket", { index = i }, t.name .. " joined your academy!")
					end, { Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(1, -16, 0, 34), TextSize = 14 }, "gold")
					Kit.setEnabled(b, not bought and d.gems >= offer.price)
				end
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "collection", name = "Collection", width = 130 },
			{ id = "recruit", name = "Recruit", width = 110 },
			{ id = "market", name = "Gem Market", width = 130 },
		}, function(id)
			tab = id
			render(true)
		end)
		select(tab)
		return render
	end,
}
