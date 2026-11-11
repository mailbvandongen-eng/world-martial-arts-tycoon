-- Academy overview for the active city: rooms (open to manage), disciplines
-- (unlock licences), automation, and visitor demand (what you are missing).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Rooms = require(Shared.Config.Rooms)
local Disciplines = require(Shared.Config.Disciplines)
local Cities = require(Shared.Config.Cities)
local Progression = require(Shared.Config.Progression)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "Academy Management",
	width = 860,
	height = 600,
	build = function(body, args, ui)
		local tab = args.tab or "rooms"
		local content = Kit.scroll(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		Kit.list(content, 8)
		local function render()
			Kit.clear(content)
			local d, x = State.data, State.derived
			local cityId = d.activeCity
			local branch = d.cities[cityId]
			local now = workspace:GetServerTimeNow()
			if tab == "rooms" then
				local head = Kit.card(content, 50, 0)
				Kit.label(head, Cities.byId[cityId].name .. " academy  •  " .. (x.slotCounts[cityId] or 0) .. " room slots  •  capacity " .. x.capacity .. "  •  " .. branch.members .. " members", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 15 })
				local slots = {}
				for slot in pairs(branch.rooms) do
					table.insert(slots, tonumber(slot))
				end
				table.sort(slots)
				for i, slot in ipairs(slots) do
					local room = branch.rooms[tostring(slot)]
					local def = Rooms.byId[room.id]
					local card = Kit.card(content, 54, i)
					local building = room.buildEnd and room.buildEnd > now
					local trainer = room.trainer and d.trainers[room.trainer]
					local status = building and ("🔨 " .. Format.time(room.buildEnd - now)) or (def.needsTrainer and not trainer and "⚠ needs trainer") or (trainer and ("Trainer: " .. trainer.name) or "")
					Kit.label(card, (slot == 0 and "" or ("#" .. slot .. "  ")) .. def.name, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0), TextSize = 16, Font = Kit.fontBlack, TextColor3 = Kit.c3(def.color) })
					Kit.label(card, string.rep("★", room.level), { Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), TextColor3 = C.gold })
					Kit.label(card, status, { Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.28, 0, 1, 0), TextSize = 13, TextColor3 = (def.needsTrainer and not trainer) and C.bad or C.muted })
					Kit.button(card, "Manage", function()
						ui.open("room", { slot = slot })
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 36), TextSize = 14 }, "gold")
				end
			elseif tab == "disciplines" then
				for i, disc in ipairs(Disciplines.list) do
					local card = Kit.card(content, 64, i)
					local unlocked = d.disciplines[disc.id]
					local bar = Kit.frame(card, { BackgroundColor3 = Kit.c3(disc.accent), Size = UDim2.fromOffset(6, 64) })
					bar.Name = "Accent"
					Kit.label(card, disc.name, { Position = UDim2.fromOffset(18, 6), Size = UDim2.new(0.4, 0, 0, 24), TextSize = 18, Font = Kit.fontBlack })
					Kit.label(card, disc.origin .. "  •  base class pay $" .. disc.basePay .. "  •  " .. #disc.ranks .. " ranks (" .. disc.rankSystem .. ")", { Position = UDim2.fromOffset(18, 32), Size = UDim2.new(0.62, 0, 0, 24), TextSize = 13, TextColor3 = C.muted })
					if unlocked then
						Kit.label(card, "✔ UNLOCKED", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(160, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.good, Font = Kit.fontBlack })
					else
						local okLevel = d.level >= disc.unlock.level
						local b = Kit.button(card, okLevel and ("Unlock " .. Format.cash(disc.unlock.cost)) or ("🔒 Level " .. disc.unlock.level), function()
							ui.act("unlockDiscipline", { id = disc.id })
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(190, 40), TextSize = 14 }, "gold")
						Kit.setEnabled(b, okLevel and d.cash >= disc.unlock.cost)
					end
				end
			elseif tab == "business" then
				local auto = Kit.card(content, 90, 1)
				Kit.label(auto, "AUTOMATION", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 18), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
				local current = Progression.automation[d.automation]
				local nextA = Progression.automation[d.automation + 1]
				Kit.label(auto, current and (current.name .. ": the register empties every " .. current.interval .. " s.") or "Nobody empties the register for you yet.", { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -240, 0, 40), TextSize = 14 })
				if nextA then
					local b = Kit.button(auto, (d.level >= nextA.unlockLevel and "" or "🔒 Lv " .. nextA.unlockLevel .. " ") .. "Hire " .. nextA.name .. " " .. Format.cash(nextA.cost), function()
						ui.act("buyAutomation", {})
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(240, 44), TextSize = 13 }, "gold")
					Kit.setEnabled(b, d.level >= nextA.unlockLevel and d.cash >= nextA.cost)
				end
				local exp = x.expenses
				local fin = Kit.card(content, 120, 2)
				Kit.label(fin, "DAILY BUSINESS (every " .. Progression.DAY_SECONDS .. " s)", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 18), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
				Kit.label(fin, string.format("Rent %s   •   Salaries %s   •   Maintenance %s\nTotal expenses %s per business day\nMembership dues are paid by your %d members every business day.",
					Format.cash(exp.rent), Format.cash(exp.salaries), Format.cash(exp.maintenance), Format.cash(exp.total), branch.members), { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 80), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
				-- demand
				local demand = Kit.card(content, 200, 3)
				Kit.label(demand, "UNSERVED DEMAND (visitors who left because nothing fit)", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 18), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
				local entries = {}
				for id, n in pairs(x.demand or {}) do
					table.insert(entries, { id = id, n = n })
				end
				table.sort(entries, function(a, b)
					return a.n > b.n
				end)
				local text = #entries == 0 and "Everyone found a class. Great job!" or ""
				for i = 1, math.min(6, #entries) do
					local e = entries[i]
					local name = Disciplines.byId[e.id] and Disciplines.byId[e.id].name or "Fitness"
					text = text .. string.format("%s: %d visitors left%s\n", name, e.n, (Disciplines.byId[e.id] and not d.disciplines[e.id]) and "  (discipline locked)" or "  (build/upgrade a room or add a trainer)")
				end
				Kit.label(demand, text, { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 1, -34), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, Font = Kit.fontBody })
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "rooms", name = "Rooms", width = 110 },
			{ id = "disciplines", name = "Disciplines", width = 130 },
			{ id = "business", name = "Business", width = 120 },
		}, function(id)
			tab = id
			render()
		end)
		select(tab)
		return render
	end,
}
