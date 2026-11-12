-- Developer menu: test any part of the game directly. Only shown to
-- developers; every action is checked again on the server. The first change
-- switches on sandbox mode: your real progress is set aside and nothing is
-- saved until you switch the sandbox off again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Rooms = require(Shared.Config.Rooms)
local Trainers = require(Shared.Config.Trainers)
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Activities = require(Shared.Config.Activities)
local DevConfig = require(Shared.Config.Dev)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "🛠 Developer Menu",
	width = 920,
	height = 640,
	build = function(body, args, ui)
		local sel = { discipline = "karate", room = "karate_room", level = 3, rarity = "rare", rank = 3 }
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.list(scroll, 8)
		local order = 0
		local function dev(op, payload, okText)
			payload = payload or {}
			payload.op = op
			return ui.act("dev", payload, okText)
		end
		local function section(title, height)
			order = order + 1
			local card = Kit.card(scroll, height, order)
			Kit.label(card, title, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 14 })
			local row = Kit.frame(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 1, -36) })
			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.fromOffset(132, 34)
			grid.CellPadding = UDim2.fromOffset(6, 6)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = row
			return row
		end
		local function btn(row, text, fn, style)
			return Kit.button(row, text, fn, { TextSize = 12, TextWrapped = true }, style or "dark")
		end
		local function selectButtons(row, list, key, label)
			local buttons = {}
			local function paint()
				for value, b in pairs(buttons) do
					b.BackgroundColor3 = sel[key] == value and C.gold or C.panel2
					b.TextColor3 = sel[key] == value and Color3.fromRGB(20, 20, 24) or C.text
				end
			end
			for _, item in ipairs(list) do
				local value, text = item[1], item[2]
				buttons[value] = btn(row, (label or "") .. text, function()
					sel[key] = value
					paint()
				end)
			end
			paint()
		end

		-- sandbox
		local sb = section("SANDBOX", 76)
		local status = Kit.label(sb, "", { TextSize = 13 })
		btn(sb, "Sandbox ON", function()
			dev("sandbox", { on = true }, "Sandbox on: changes are not saved")
		end, "good")
		btn(sb, "Sandbox OFF (restore)", function()
			dev("sandbox", { on = false }, "Real progress restored")
		end, "bad")
		btn(sb, "Teleport: my academy", function()
			dev("teleport", { to = "home" })
		end)
		btn(sb, "Teleport: arena", function()
			dev("teleport", { to = "arena" })
		end)
		btn(sb, "Teleport: competition hall", function()
			dev("teleport", { to = "hall" })
		end)

		-- scenarios
		local sc = section("SCENARIOS (replace your sandbox save)", 76)
		for _, s in ipairs(DevConfig.scenarios) do
			btn(sc, s.name, function()
				dev("scenario", { id = s.id }, s.name .. ": " .. s.text)
			end, "gold")
		end

		-- values
		local vals = section("VALUES", 116)
		for _, item in ipairs({ { "cash", "Cash" }, { "gems", "Gems" }, { "level", "Level" }, { "reputation", "Reputation" }, { "register", "Register" } }) do
			local box = Instance.new("TextBox")
			box.PlaceholderText = item[2]
			box.Text = ""
			box.Font = Kit.font
			box.TextSize = 13
			box.TextColor3 = C.text
			box.BackgroundColor3 = C.panel
			box.ClearTextOnFocus = false
			Kit.corner(box, 6)
			box.Parent = vals
			btn(vals, "Set " .. item[2], function()
				dev("set", { key = item[1], value = tonumber(box.Text) }, item[2] .. " set")
			end, "gold")
		end

		-- cities
		local cs = section("CITIES (unlock and go)", 116)
		for _, c in ipairs(Cities.list) do
			btn(cs, c.name, function()
				dev("city", { id = c.id }, "Now in " .. c.name)
			end)
		end

		-- discipline + mastery
		local ds = section("DISCIPLINE (used by trainers, students, mastery, championship)", 156)
		local dl = {}
		for _, d in ipairs(Disciplines.list) do
			table.insert(dl, { d.id, d.name })
		end
		selectButtons(ds, dl, "discipline")
		local ms = section("MASTERY RANK of the selected discipline", 76)
		for r = 1, 9 do
			btn(ms, "Rank " .. r, function()
				dev("mastery", { id = sel.discipline, rank = r }, "Mastery set")
			end)
		end
		btn(ms, "ALL max", function()
			dev("mastery", { id = "all", rank = 99 }, "All mastery maxed")
		end, "gold")
		btn(ms, "Unlock all disciplines", function()
			dev("discipline", { id = "all" }, "All disciplines unlocked")
		end, "gold")

		-- rooms
		local rs = section("ROOM TYPE", 236)
		local rl = {}
		for _, r in ipairs(Rooms.list) do
			if r.kind ~= "reception" then
				table.insert(rl, { r.id, r.name })
			end
		end
		selectButtons(rs, rl, "room")
		local lv = section("UPGRADE LEVEL + PLACE", 116)
		selectButtons(lv, { { 1, "1" }, { 2, "2" }, { 3, "3" }, { 4, "4" }, { 5, "5" } }, "level", "Level ")
		local slotBox = Instance.new("TextBox")
		slotBox.PlaceholderText = "slot (1-20)"
		slotBox.Text = "1"
		slotBox.Font = Kit.font
		slotBox.TextSize = 13
		slotBox.TextColor3 = C.text
		slotBox.BackgroundColor3 = C.panel
		Kit.corner(slotBox, 6)
		slotBox.Parent = lv
		btn(lv, "Place room in slot", function()
			dev("room", { slot = tonumber(slotBox.Text), roomId = sel.room, level = sel.level }, "Room placed")
		end, "gold")
		btn(lv, "All rooms → level", function()
			dev("roomLevels", { level = sel.level }, "All rooms set")
		end)
		btn(lv, "Fill academy (level)", function()
			dev("fillAcademy", { level = sel.level, rarity = sel.rarity }, "Academy filled")
		end)
		btn(lv, "Clear rooms", function()
			dev("clearRooms", {}, "Rooms cleared")
		end, "bad")
		btn(lv, "Finish construction", function()
			dev("finishBuild", {}, "Construction finished")
		end)

		-- trainers
		local ts = section("TRAINERS (rarity)", 116)
		local rar = {}
		for _, r in ipairs(Trainers.rarities) do
			table.insert(rar, { r.id, r.name })
		end
		selectButtons(ts, rar, "rarity")
		btn(ts, "Add trainer (discipline)", function()
			dev("trainer", { discipline = sel.discipline, rarity = sel.rarity }, "Trainer added")
		end, "gold")
		btn(ts, "Staff every room", function()
			dev("staffAll", { rarity = sel.rarity }, "Rooms staffed")
		end, "gold")

		-- students and visitors
		local ss = section("STUDENTS & VISITORS", 116)
		for _, n in ipairs({ 5, 20 }) do
			btn(ss, "+" .. n .. " students (rank = level)", function()
				dev("students", { discipline = sel.discipline, count = n, rank = sel.level }, n .. " students added")
			end)
		end
		btn(ss, "Visitors now +10", function()
			dev("visitors", { burst = 10 }, "Visitors on their way")
		end, "gold")
		btn(ss, "Visitors now +30", function()
			dev("visitors", { burst = 30 }, "Visitors on their way")
		end, "gold")
		for _, rate in ipairs({ 1, 3, 10 }) do
			btn(ss, "Visitor rate x" .. rate, function()
				dev("visitors", { rate = rate }, "Visitor rate x" .. rate)
			end)
		end

		-- competition hall
		local ch = section("COMPETITION HALL (sparring, belt exams, your own kumite)", 156)
		btn(ch, "Spar now (discipline)", function()
			dev("compete", { mode = "cooldowns" })
			if dev("students", { discipline = sel.discipline, count = 2, rank = sel.level }) then
				ui.act("spar", { discipline = sel.discipline }, "Sparring starts in the hall")
			end
		end, "gold")
		btn(ch, "All students exam-ready", function()
			dev("compete", { mode = "examReady", discipline = sel.discipline }, "Students are ready for their exam")
		end, "gold")
		btn(ch, "Exam day now", function()
			dev("compete", { mode = "cooldowns" })
			ui.act("examAll", {}, "Exams start in the hall")
		end, "gold")
		btn(ch, "Kumite yourself", function()
			dev("compete", { mode = "cooldowns" })
			ui.open("training")
		end, "bad")
		for _, lvl in ipairs({ 1, 5, 10, 20 }) do
			btn(ch, "Kumite level " .. lvl, function()
				dev("compete", { mode = "kumiteLevel", level = lvl }, "Next opponent: level " .. lvl)
			end)
		end
		btn(ch, "Clear cooldowns", function()
			dev("compete", { mode = "cooldowns" }, "Cooldowns cleared")
		end)

		-- activities
		local as = section("CHALLENGES, TOURNAMENTS, CHAMPIONSHIP", 196)
		for _, id in ipairs(Activities.gameOrder) do
			local g = Activities.games[id]
			btn(as, "▶ " .. g.name, function()
				dev("missions", { mode = "resetDaily" })
				if g.discipline then
					dev("discipline", { id = g.discipline })
				end
				ui.open("training")
			end)
		end
		for _, t in ipairs(Activities.tournaments) do
			btn(as, "🏆 " .. t.name, function()
				dev("tournament", { id = t.id }, t.name .. " starts: register within 20 s")
				ui.open("tournaments")
			end, "gold")
		end
		btn(as, "Championship (discipline)", function()
			dev("championship", { discipline = sel.discipline }, "Championship started in your arena")
		end, "gold")

		-- missions & events
		local mi = section("MISSIONS & EVENTS", 156)
		btn(mi, "Complete all missions", function()
			dev("missions", { mode = "complete" }, "Missions complete")
		end, "gold")
		btn(mi, "New missions", function()
			dev("missions", { mode = "reroll" }, "Missions rerolled")
		end)
		btn(mi, "Reset daily + cooldowns", function()
			dev("missions", { mode = "resetDaily" }, "Daily reward and cooldowns reset")
		end)
		btn(mi, "Event: calendar", function()
			dev("event", { id = nil }, "Event follows the calendar")
		end)
		for _, e in ipairs(Events.list) do
			btn(mi, "Event: " .. e.name, function()
				dev("event", { id = e.id }, e.name .. " active")
			end)
		end

		-- purchases
		local ps = section("PURCHASE EFFECTS (test grants, removed again on a live rejoin)", 236)
		for _, p in ipairs(Monetization.gamePasses) do
			btn(ps, p.name, function()
				dev("grant", { kind = "pass", key = p.key }, p.name .. " granted")
			end)
		end
		for _, p in ipairs(Monetization.products) do
			btn(ps, p.name, function()
				dev("grant", { kind = "product", key = p.key }, p.name .. " granted")
			end)
		end

		local function refresh()
			local x = State.derived
			if x then
				status.Text = x.sandbox and "🟢 Sandbox: not saving" or "⚪ Live: changes save"
				status.TextColor3 = x.sandbox and C.good or C.muted
			end
		end
		refresh()
		return refresh
	end,
}
