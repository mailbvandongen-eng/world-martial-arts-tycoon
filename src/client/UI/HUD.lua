-- Main HUD (mobile first).
--   top:    cash, gems, level + XP bar, reputation, current city, active boosts
--   left:   missions, daily rewards, events, next objective
--   right:  build, academy, students, trainers, tournaments, shop, more
--   bottom: earnings per hour, collect, train (challenges) — centred, so the
--           Roblox thumbstick (left) and jump button (right) stay free.

local UserInputService = game:GetService("UserInputService")
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
	local value = Kit.label(f, "0", { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), TextSize = 20, Font = Kit.fontBlack, TextColor3 = Color3.new(1, 1, 1) })
	return f, value
end

local function navButton(parent, order, icon, text, onClick, accent)
	local b = Kit.button(parent, "", onClick, { Size = UDim2.fromOffset(84, 66), LayoutOrder = order, BackgroundTransparency = 0.05 }, "dark")
	Kit.stroke(b, accent or C.stroke, accent and 2 or 1)
	Kit.label(b, icon, { Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 26, TextColor3 = C.gold, Font = Kit.fontBlack })
	Kit.label(b, text, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, TextColor3 = C.text })
	local badge = Kit.frame(b, { BackgroundColor3 = C.bad, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -16, 0, 2), Visible = false, Name = "Badge" })
	Kit.corner(badge, 7)
	return b, badge
end

-- Opens the build menu on the first free slot of the managed city.
function HUD.openBuild(ui)
	local d = State.data
	if not d then
		return
	end
	local cityId = d.activeCity
	local count = State.derived.slotCounts[cityId] or 6
	for slot = 1, count do
		if not d.cities[cityId].rooms[tostring(slot)] then
			ui.open("build", { slot = slot })
			return
		end
	end
	ui.toast("All room slots are used. Upgrade rooms or expand to a new city!", "warn")
end

function HUD.build(ui)
	local layer = ui.hudLayer
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	ui.openBuildShortcut = function()
		HUD.openBuild(ui)
	end

	-- top bar
	local top = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(1080, 44) })
	local tl = Kit.list(top, 8, true)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local _, cash = stat(top, 1, "$", C.cash, 170)
	local _, gems = stat(top, 2, "◆", C.gems, 110)
	local levelFrame = Kit.frame(top, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(190, 44), LayoutOrder = 3 })
	Kit.corner(levelFrame, 10)
	Kit.stroke(levelFrame, C.stroke, 1)
	local levelText = Kit.label(levelFrame, "Level 1", { Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, Font = Kit.fontBlack, TextColor3 = C.gold })
	local _, xpFill = Kit.progress(levelFrame, 0, C.gold, { Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 8) })
	local _, rep = stat(top, 4, "★", C.rep, 120)
	local city = Kit.button(top, "🌍 Small Town", function()
		ui.open("map")
	end, { Size = UDim2.fromOffset(170, 44), LayoutOrder = 5, TextSize = 15, Font = Kit.fontBlack }, "dark")
	Kit.stroke(city, C.gold, 1)
	local boosts = Kit.frame(top, { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 44), LayoutOrder = 6 })
	Kit.list(boosts, 4, true)
	refs.cash, refs.gems, refs.levelText, refs.xpFill, refs.rep, refs.boosts, refs.city = cash, gems, levelText, xpFill, rep, boosts, city

	-- left column
	local left = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.42, 0), Size = UDim2.fromOffset(250, 360) })
	Kit.list(left, 8)
	local _, missionBadge = navButton(left, 1, "!", "Missions", function()
		ui.open("quests")
	end)
	local _, dailyBadge = navButton(left, 2, "🎁", "Daily", function()
		ui.open("daily")
	end)
	navButton(left, 3, "🎉", "Events", function()
		ui.open("quests", { tab = "event" })
	end)
	local objective = Kit.frame(left, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(touch and 200 or 240, 84), LayoutOrder = 4 })
	Kit.corner(objective, 10)
	Kit.stroke(objective, C.gold, 1)
	Kit.padding(objective, 8)
	Kit.label(objective, "NEXT OBJECTIVE", { Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = C.gold, Font = Kit.fontBlack })
	local objText = Kit.label(objective, "", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 1, -18), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
	refs.missionBadge, refs.dailyBadge, refs.objText = missionBadge, dailyBadge, objText

	-- right column: main navigation
	-- On touch screens the Roblox jump button sits bottom-right: the seven
	-- buttons go in a 3-column block at the top so none of them covers it.
	local right
	if touch then
		right = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 62), Size = UDim2.fromOffset(268, 216) })
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(84, 66)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
		grid.Parent = right
	else
		right = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 62), Size = UDim2.fromOffset(84, 540) })
		Kit.list(right, 8)
	end
	local nav = {
		{ "🔨", "Build", function()
			HUD.openBuild(ui)
		end },
		{ "🏯", "Academy", function()
			ui.open("academy")
		end },
		{ "🎓", "Students", function()
			ui.open("students")
		end },
		{ "🥋", "Trainers", function()
			ui.open("trainers")
		end },
		{ "🏆", "Tournaments", function()
			ui.open("tournaments")
		end },
		{ "🛒", "Shop", function()
			ui.open("store")
		end },
		{ "☰", "More", function()
			ui.open("more")
		end },
	}
	for i, b in ipairs(nav) do
		local _, badge = navButton(right, i, b[1], b[2], b[3], b[2] == "Tournaments" and C.goldDark or nil)
		if b[2] == "Tournaments" then
			refs.tourBadge = badge
		end
	end

	-- bottom bar
	local bottom = Kit.frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(560, 64) })
	local bl = Kit.list(bottom, 10, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	local earnings = Kit.frame(bottom, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(150, 60), LayoutOrder = 1 })
	Kit.corner(earnings, 10)
	Kit.stroke(earnings, C.stroke, 1)
	Kit.label(earnings, "EARNINGS / HOUR", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = C.muted })
	local hourly = Kit.label(earnings, "$0", { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 28), TextSize = 22, Font = Kit.fontBlack, TextColor3 = C.cash })
	local collect = Kit.button(bottom, "COLLECT $0", function()
		if State.myPlot() then
			State.call("collect")
		else
			State.call("claimPlot")
		end
	end, { Size = UDim2.fromOffset(230, 60), LayoutOrder = 2, TextSize = 20, Font = Kit.fontBlack }, "good")
	local _, regFill = Kit.progress(collect, 0, Color3.fromRGB(30, 90, 40), { Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 5) })
	local train = Kit.button(bottom, "🥋 TRAIN", function()
		ui.open("training")
	end, { Size = UDim2.fromOffset(140, 60), LayoutOrder = 3, TextSize = 18, Font = Kit.fontBlack }, "gold")
	refs.collect, refs.regFill, refs.hourly, refs.train = collect, regFill, hourly, train

	-- developer button (only for developers; the server checks every action)
	-- sits first in the top bar, so it never overlaps the Roblox menu buttons
	local devBtn = Kit.button(top, "🛠 DEV", function()
		ui.open("dev")
	end, { Size = UDim2.fromOffset(84, 44), LayoutOrder = 0, TextSize = 14, Font = Kit.fontBlack, Visible = false }, "bad")
	refs.devBtn = devBtn

	State.Changed:Connect(HUD.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			HUD.refreshBoosts()
			HUD.refreshTournament()
		end
	end)
end

function HUD.refreshTournament()
	local t = State.tournament and State.tournament.info
	if refs.tourBadge then
		local now = workspace:GetServerTimeNow()
		refs.tourBadge.Visible = t ~= nil and now < t.regEnd and (State.data and State.data.tournament.key ~= t.key)
	end
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
			local f = Kit.frame(refs.boosts, { BackgroundColor3 = C.goldDark, Size = UDim2.fromOffset(64, 44), LayoutOrder = order })
			Kit.corner(f, 8)
			Kit.label(f, (kind == "cash" and "x2 $" or kind == "training" and "⚡" or "👥"), { Size = UDim2.new(1, 0, 0.55, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = Kit.fontBlack })
			Kit.label(f, Format.time(untilTime - now), { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11 })
			local def = Monetization.boosts[kind]
			f.Name = def and def.name or kind
		end
	end
end

function HUD.refresh()
	local d, x = State.data, State.derived
	if not d then
		return
	end
	refs.devBtn.Visible = x.isDev == true
	refs.devBtn.Text = x.sandbox and "🛠 DEV •" or "🛠 DEV"
	refs.cash.Text = Format.cash(d.cash)
	refs.gems.Text = Format.short(d.gems)
	refs.rep.Text = Format.short(d.reputation)
	refs.levelText.Text = "Level " .. d.level .. (d.rebirths > 0 and ("  ★" .. d.rebirths) or "")
	local need = Progression.xpForLevel(d.level)
	refs.xpFill.Size = UDim2.new(math.clamp(d.xp / need, 0, 1), 0, 1, 0)
	refs.city.Text = "🌍 " .. Cities.byId[d.activeCity].name
	if x.plot then
		refs.collect.Text = "COLLECT " .. Format.cash(d.register)
	else
		refs.collect.Text = "★ CLAIM ACADEMY"
	end
	refs.regFill.Size = UDim2.new(math.clamp(d.register / math.max(x.registerCap, 1), 0, 1), 0, 1, 0)
	refs.hourly.Text = Format.cash(x.hourly)
	refs.objText.Text = x.objective and x.objective.text or "You built a martial arts empire! Keep growing."
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
