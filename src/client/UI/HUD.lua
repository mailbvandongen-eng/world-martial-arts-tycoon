-- Main HUD.
--   top:    cash, gems, level + XP bar, reputation, active boosts
--   left:   missions, daily rewards, world map, next objective
--   right:  shop, inventory, trainers, academy, mastery, stats, leaderboards, players, settings
--   bottom: collect register, build shortcut, earnings per hour, go home / claim

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Progression = require(Shared.Config.Progression)
local Monetization = require(Shared.Config.Monetization)
local Cities = require(Shared.Config.Cities)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local HUD = {}
local C = Kit.colors
local refs = {}

local function stat(parent, order, icon, color, width)
	local f = Kit.frame(parent, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(width or 150, 44), LayoutOrder = order })
	Kit.corner(f, 10)
	Kit.stroke(f, C.stroke, 1)
	Kit.label(f, icon, { Size = UDim2.fromOffset(34, 44), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, TextColor3 = color, Font = Kit.fontBlack })
	local value = Kit.label(f, "0", { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), TextSize = 20, Font = Kit.fontBlack, TextColor3 = Color3.new(1, 1, 1), TextScaled = false })
	return f, value
end

local function sideButton(parent, order, icon, text, onClick)
	local b = Kit.button(parent, "", onClick, { Size = UDim2.fromOffset(78, 64), LayoutOrder = order, BackgroundTransparency = 0.05 }, "dark")
	Kit.stroke(b, C.stroke, 1)
	Kit.label(b, icon, { Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 26, TextColor3 = C.gold, Font = Kit.fontBlack })
	Kit.label(b, text, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, TextColor3 = C.text })
	local badge = Kit.frame(b, { BackgroundColor3 = C.bad, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -16, 0, 2), Visible = false, Name = "Badge" })
	Kit.corner(badge, 7)
	return b, badge
end

function HUD.build(ui)
	local layer = ui.hudLayer

	-- top bar
	local top = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(900, 44) })
	local tl = Kit.list(top, 8, true)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local _, cash = stat(top, 1, "$", C.cash, 170)
	local _, gems = stat(top, 2, "◆", C.gems, 120)
	local levelFrame = Kit.frame(top, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(200, 44), LayoutOrder = 3 })
	Kit.corner(levelFrame, 10)
	Kit.stroke(levelFrame, C.stroke, 1)
	local levelText = Kit.label(levelFrame, "Level 1", { Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, Font = Kit.fontBlack, TextColor3 = C.gold })
	local _, xpFill = Kit.progress(levelFrame, 0, C.gold, { Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 8) })
	local _, rep = stat(top, 4, "★", C.rep, 130)
	local boosts = Kit.frame(top, { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 44), LayoutOrder = 5 })
	Kit.list(boosts, 4, true)
	refs.cash, refs.gems, refs.levelText, refs.xpFill, refs.rep, refs.boosts = cash, gems, levelText, xpFill, rep, boosts

	-- left column
	local left = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.45, 0), Size = UDim2.fromOffset(250, 420) })
	Kit.list(left, 8)
	local _, missionBadge = sideButton(left, 1, "!", "Missions", function()
		ui.open("quests")
	end)
	local _, dailyBadge = sideButton(left, 2, "🎁", "Daily", function()
		ui.open("daily")
	end)
	sideButton(left, 3, "🌍", "World Map", function()
		ui.open("map")
	end)
	local objective = Kit.frame(left, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(240, 92), LayoutOrder = 4 })
	Kit.corner(objective, 10)
	Kit.stroke(objective, C.gold, 1)
	Kit.padding(objective, 8)
	Kit.label(objective, "NEXT OBJECTIVE", { Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = C.gold, Font = Kit.fontBlack })
	local objText = Kit.label(objective, "", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 1, -18), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top })
	refs.missionBadge, refs.dailyBadge, refs.objText = missionBadge, dailyBadge, objText

	-- right column (two columns of buttons)
	local right = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.45, 0), Size = UDim2.fromOffset(164, 360) })
	Kit.grid(right, UDim2.fromOffset(78, 64), 8)
	local rightButtons = {
		{ "🛒", "Shop", "store" }, { "🎒", "Inventory", "inventory" }, { "🥋", "Trainers", "trainers" }, { "🏯", "Academy", "academy" },
		{ "🎖", "Mastery", "mastery" }, { "📊", "Stats", "stats" }, { "🏆", "Ranks", "leaderboards" }, { "👥", "Players", "players" },
		{ "⚙", "Settings", "settings" }, { "♻", "Rebirth", "rebirth" },
	}
	for i, b in ipairs(rightButtons) do
		sideButton(right, i, b[1], b[2], function()
			ui.open(b[3])
		end)
	end

	-- bottom bar
	local bottom = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(760, 64) })
	local bl = Kit.list(bottom, 10, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	local collect = Kit.button(bottom, "COLLECT $0", function()
		State.call("collect")
	end, { Size = UDim2.fromOffset(250, 60), LayoutOrder = 2, TextSize = 20, Font = Kit.fontBlack }, "good")
	local _, regFill = Kit.progress(collect, 0, Color3.fromRGB(30, 90, 40), { Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 5) })
	local build = Kit.button(bottom, "🔨 BUILD", function()
		local d = State.data
		local cityId = d.activeCity
		local count = State.derived.slotCounts[cityId] or 6
		for slot = 1, count do
			if not d.cities[cityId].rooms[tostring(slot)] then
				ui.open("build", { slot = slot })
				return
			end
		end
		ui.toast("All slots are used. Upgrade rooms or expand to a new city!", "warn")
	end, { Size = UDim2.fromOffset(130, 60), LayoutOrder = 3, TextSize = 18, Font = Kit.fontBlack }, "gold")
	local earnings = Kit.frame(bottom, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(170, 60), LayoutOrder = 1 })
	Kit.corner(earnings, 10)
	Kit.stroke(earnings, C.stroke, 1)
	Kit.label(earnings, "EARNINGS / HOUR", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = C.muted })
	local hourly = Kit.label(earnings, "$0", { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 28), TextSize = 22, Font = Kit.fontBlack, TextColor3 = C.cash })
	local home = Kit.button(bottom, "🏠 HOME", function()
		if State.myPlot() then
			State.call("goHome")
		else
			State.call("claimPlot")
		end
	end, { Size = UDim2.fromOffset(150, 60), LayoutOrder = 4, TextSize = 16, Font = Kit.fontBlack }, "dark")
	refs.collect, refs.regFill, refs.hourly, refs.home, refs.build = collect, regFill, hourly, home, build

	State.Changed:Connect(HUD.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			HUD.refreshBoosts()
		end
	end)
end

function HUD.refreshBoosts()
	local d = State.data
	if not d or not refs.boosts then
		return
	end
	Kit.clear(refs.boosts)
	local now = workspace:GetServerTimeNow()
	local order = 0
	for kind, untilTime in pairs(d.boosts) do
		if untilTime > now then
			order = order + 1
			local def = Monetization.boosts[kind]
			local f = Kit.frame(refs.boosts, { BackgroundColor3 = C.goldDark, Size = UDim2.fromOffset(64, 44), LayoutOrder = order })
			Kit.corner(f, 8)
			Kit.label(f, (kind == "cash" and "x2 $" or kind == "training" and "⚡" or "👥"), { Size = UDim2.new(1, 0, 0.55, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = Kit.fontBlack })
			Kit.label(f, Format.time(untilTime - now), { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11 })
			f.Name = def and def.name or kind
		end
	end
end

function HUD.refresh()
	local d, x = State.data, State.derived
	if not d then
		return
	end
	refs.cash.Text = Format.cash(d.cash)
	refs.gems.Text = Format.short(d.gems)
	refs.rep.Text = Format.short(d.reputation)
	refs.levelText.Text = "Level " .. d.level .. (d.rebirths > 0 and ("  ★" .. d.rebirths) or "")
	local need = Progression.xpForLevel(d.level)
	refs.xpFill.Size = UDim2.new(math.clamp(d.xp / need, 0, 1), 0, 1, 0)
	refs.collect.Text = "COLLECT " .. Format.cash(d.register)
	refs.regFill.Size = UDim2.new(math.clamp(d.register / math.max(x.registerCap, 1), 0, 1), 0, 1, 0)
	refs.hourly.Text = Format.cash(x.hourly)
	refs.home.Text = x.plot and ("🏠 " .. string.upper(Cities.byId[d.activeCity].name)) or "★ CLAIM ACADEMY"
	refs.objText.Text = x.objective and x.objective.text or "You built a martial arts empire! Keep growing."
	-- badges
	local claimable = false
	for _, list in ipairs({ d.quests.daily, d.quests.weekly }) do
		for _, q in ipairs(list) do
			if q.progress >= q.target and not q.claimed then
				claimable = true
			end
		end
	end
	refs.missionBadge.Visible = claimable
	refs.dailyBadge.Visible = x.daily and x.daily.available or false
	HUD.refreshBoosts()
end

return HUD
