-- Academy management: ROOMS (level, trainer, capacity, live occupancy,
-- status), DISCIPLINES (students, mastery, training quality, revenue, unlock)
-- and BUSINESS (students, members, satisfaction, reputation, money).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Rooms = require(Shared.Config.Rooms)
local Disciplines = require(Shared.Config.Disciplines)
local Cities = require(Shared.Config.Cities)
local Progression = require(Shared.Config.Progression)
local Trainers = require(Shared.Config.Trainers)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function tile(parent, order, title, value, color)
	local f = Kit.frame(parent, { BackgroundColor3 = C.panel2, LayoutOrder = order })
	Kit.corner(f, 10)
	Kit.label(f, title, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, TextColor3 = C.muted })
	Kit.label(f, value, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 30), TextSize = 22, Font = Kit.fontBlack, TextColor3 = color or C.text })
end

return {
	title = "Academy Management",
	width = 900,
	height = 620,
	build = function(body, args, ui)
		local tab = args.tab or "rooms"
		local content = Kit.frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		local lastSig
		local function render(force)
			local d, x = State.data, State.derived
			local cityId = d.activeCity
			local branch = d.cities[cityId]
			local now = workspace:GetServerTimeNow()
			local sig = tab .. math.floor(now / 2) .. d.cash
			if sig == lastSig and not force then
				return
			end
			lastSig = sig
			local keepCanvas = content:FindFirstChild("Scroll") and content.Scroll.CanvasPosition
			Kit.clear(content)
			if tab == "rooms" then
				local scroll = Kit.scroll(content, { Size = UDim2.fromScale(1, 1), Name = "Scroll" })
				Kit.list(scroll, 6)
				local head = Kit.card(scroll, 40, 0)
				Kit.label(head, Cities.byId[cityId].name .. "  •  " .. (x.slotCounts[cityId] or 0) .. " room slots  •  total capacity " .. x.capacity .. "  •  " .. branch.members .. " members", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 14, TextColor3 = C.muted })
				local slots = {}
				for slot in pairs(branch.rooms) do
					table.insert(slots, tonumber(slot))
				end
				table.sort(slots)
				for i, slot in ipairs(slots) do
					local room = branch.rooms[tostring(slot)]
					local def = Rooms.byId[room.id]
					local card = Kit.card(scroll, 62, i)
					local building = room.buildEnd and room.buildEnd > now
					local trainer = room.trainer and d.trainers[room.trainer]
					local stats = trainer and Formulas.trainerStats(trainer)
					Kit.label(card, def.name, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.3, 0, 0, 24), TextSize = 16, Font = Kit.fontBlack, TextColor3 = Kit.c3(def.color) })
					Kit.label(card, string.rep("★", room.level) .. string.rep("☆", Rooms.MAX_LEVEL - room.level) .. "  Lv " .. room.level, { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(0.3, 0, 0, 22), TextColor3 = C.gold, TextSize = 14 })
					local who = def.needsTrainer and (trainer and (trainer.name .. " (" .. Trainers.rarityById[trainer.rarity].name .. ")") or "⚠ No trainer") or "No trainer needed"
					Kit.label(card, who, { Position = UDim2.new(0.31, 0, 0, 6), Size = UDim2.new(0.3, 0, 0, 22), TextSize = 13, TextColor3 = (def.needsTrainer and not trainer) and C.bad or C.text })
					local occupancyText = ""
					if def.capacity and def.kind ~= "reception" then
						local cap = Formulas.roomCapacity(room.id, room.level, stats)
						local inside = ui.npc and State.myPlot() and ui.npc.occupancy(State.myPlot(), slot) or 0
						occupancyText = "Training now " .. inside .. " / " .. cap
					elseif def.kind == "reception" then
						occupancyText = "Check-in desk"
					else
						occupancyText = "Facility"
					end
					Kit.label(card, occupancyText, { Position = UDim2.new(0.31, 0, 0, 32), Size = UDim2.new(0.3, 0, 0, 22), TextSize = 13, TextColor3 = C.muted })
					local status = building and ("🔨 " .. Format.time(room.buildEnd - now)) or (room.level < Rooms.MAX_LEVEL and ("Upgrade " .. Format.cash(Formulas.roomUpgradeCost(room.id, room.level, cityId))) or "Max level")
					Kit.label(card, status, { Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), TextSize = 13, TextColor3 = building and C.rep or C.muted })
					Kit.button(card, "Manage", function()
						ui.open("room", { slot = slot })
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 44), TextSize = 15 }, "gold")
				end
				if keepCanvas then
					scroll.CanvasPosition = keepCanvas
				end
			elseif tab == "disciplines" then
				local scroll = Kit.scroll(content, { Size = UDim2.fromScale(1, 1), Name = "Scroll" })
				Kit.list(scroll, 6)
				for i, disc in ipairs(Disciplines.list) do
					local unlocked = d.disciplines[disc.id]
					local card = Kit.card(scroll, 70, i)
					Kit.frame(card, { BackgroundColor3 = Kit.c3(disc.accent), Size = UDim2.fromOffset(6, 70) })
					Kit.label(card, disc.name, { Position = UDim2.fromOffset(18, 6), Size = UDim2.new(0.26, 0, 0, 26), TextSize = 18, Font = Kit.fontBlack, TextColor3 = unlocked and C.text or C.muted })
					if unlocked then
						local m = d.mastery[disc.id] or { rank = 1 }
						local students = 0
						for _, s in pairs(d.students) do
							if s.discipline == disc.id then
								students = students + 1
							end
						end
						-- training quality: best room level + best trainer rarity in this city
						local bestRoom, bestTrainer = 0, 0
						for _, room in pairs(branch.rooms) do
							if room.id == disc.id .. "_room" then
								bestRoom = math.max(bestRoom, room.level)
								local t = room.trainer and d.trainers[room.trainer]
								if t then
									bestTrainer = math.max(bestTrainer, Trainers.rarityById[t.rarity].order)
								end
							end
						end
						local quality = bestRoom == 0 and 0 or math.min(5, math.floor((bestRoom + bestTrainer) / 2 + 0.5))
						local ds = d.discStats[disc.id] or { served = 0, revenue = 0 }
						Kit.label(card, disc.ranks[m.rank].name .. "  •  " .. students .. " regular students  •  " .. Format.commas(ds.served) .. " classes given", { Position = UDim2.fromOffset(18, 34), Size = UDim2.new(0.6, 0, 0, 22), TextSize = 13, TextColor3 = C.muted })
						Kit.label(card, "Quality " .. string.rep("★", quality) .. string.rep("☆", 5 - quality), { Position = UDim2.new(0.6, 0, 0, 8), Size = UDim2.new(0.38, -10, 0, 22), TextSize = 14, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right })
						Kit.label(card, bestRoom == 0 and "⚠ Build a " .. disc.name .. " room" or ("Revenue " .. Format.cash(ds.revenue)), { Position = UDim2.new(0.6, 0, 0, 36), Size = UDim2.new(0.38, -10, 0, 22), TextSize = 13, TextColor3 = bestRoom == 0 and C.bad or C.cash, TextXAlignment = Enum.TextXAlignment.Right })
					else
						local okLevel = d.level >= disc.unlock.level
						Kit.label(card, "Locked  •  requires level " .. disc.unlock.level, { Position = UDim2.fromOffset(18, 36), Size = UDim2.new(0.5, 0, 0, 22), TextSize = 13, TextColor3 = C.muted })
						local b = Kit.button(card, okLevel and ("Unlock " .. Format.cash(disc.unlock.cost)) or ("🔒 Level " .. disc.unlock.level), function()
							ui.act("unlockDiscipline", { id = disc.id })
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(190, 44), TextSize = 14 }, "gold")
						Kit.setEnabled(b, okLevel and d.cash >= disc.unlock.cost)
					end
				end
				if keepCanvas then
					scroll.CanvasPosition = keepCanvas
				end
			else
				local scroll = Kit.scroll(content, { Size = UDim2.fromScale(1, 1), Name = "Scroll" })
				Kit.grid(scroll, UDim2.fromOffset(205, 72), 10)
				local exp = x.expenses
				local perHour = 3600 / Progression.DAY_SECONDS
				local regulars = 0
				for _ in pairs(d.students) do
					regulars = regulars + 1
				end
				tile(scroll, 1, "STUDENTS SERVED", Format.commas(d.stats.studentsServed))
				tile(scroll, 2, "REGULAR STUDENTS", tostring(regulars))
				tile(scroll, 3, "ACTIVE MEMBERSHIPS", Format.commas(x.members))
				tile(scroll, 4, "SATISFACTION", x.avgSatisfaction and (math.floor(x.avgSatisfaction) .. "%") or "—", (x.avgSatisfaction or 70) >= 70 and C.good or C.rep)
				tile(scroll, 5, "REPUTATION", Format.short(d.reputation), C.rep)
				tile(scroll, 6, "EARNINGS / HOUR", Format.cash(x.hourly), C.cash)
				tile(scroll, 7, "RENT / HOUR", Format.cash(exp.rent * perHour), C.bad)
				tile(scroll, 8, "TRAINER SALARIES / HOUR", Format.cash(exp.salaries * perHour), C.bad)
				tile(scroll, 9, "MAINTENANCE / HOUR", Format.cash(exp.maintenance * perHour), C.bad)
				tile(scroll, 10, "TOTAL REVENUE", Format.cash(d.stats.totalEarned), C.cash)
				local net = x.hourly - exp.total * perHour
				tile(scroll, 11, "NET PROFIT / HOUR", Format.cash(net), net >= 0 and C.good or C.bad)
				tile(scroll, 12, "VISITORS LOST", Format.commas(x.lostTotal), C.muted)
				-- automation
				local nextA = Progression.automation[d.automation + 1]
				if nextA then
					local f = Kit.frame(scroll, { BackgroundColor3 = C.panel2, LayoutOrder = 13 })
					Kit.corner(f, 10)
					local b = Kit.button(f, "Hire " .. nextA.name .. "\n" .. Format.cash(nextA.cost) .. (d.level < nextA.unlockLevel and ("  (Lv " .. nextA.unlockLevel .. ")") or ""), function()
						ui.act("buyAutomation", {})
					end, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), TextSize = 12 }, "gold")
					Kit.setEnabled(b, d.level >= nextA.unlockLevel and d.cash >= nextA.cost)
				end
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "rooms", name = "ROOMS", width = 120 },
			{ id = "disciplines", name = "DISCIPLINES", width = 140 },
			{ id = "business", name = "BUSINESS", width = 120 },
		}, function(id)
			tab = id
			render(true)
		end)
		select(tab)
		return render
	end,
}
