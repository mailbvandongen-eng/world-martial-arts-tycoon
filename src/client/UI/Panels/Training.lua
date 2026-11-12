-- Training challenges (mini-games). Prompts slide towards a hit line; tap the
-- matching action at the right moment. The server generated the prompts and
-- scores the taps (Domain/Activities); this panel only shows and records them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Config = require(Shared.Config.Activities)
local Disciplines = require(Shared.Config.Disciplines)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local ACTION_COLORS = { Color3.fromRGB(220, 70, 60), Color3.fromRGB(60, 140, 230), Color3.fromRGB(240, 180, 40), Color3.fromRGB(110, 200, 110) }
local SPEED = 260 -- pixels per second

local function runGame(body, ui, challenge, onDone)
	Kit.clear(body)
	local game = Config.games[challenge.game]
	local prompts = challenge.prompts
	local answered = {}
	local responses = {}
	local perfect, good, miss = 0, 0, 0
	local finished = false

	Kit.label(body, game.icon .. "  " .. game.name, { Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = Kit.fontBlack, TextColor3 = C.gold })
	local counters = Kit.label(body, "", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = C.muted })
	local lane = Kit.frame(body, { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 130), ClipsDescendants = true })
	Kit.corner(lane, 12)
	local hitX = 110
	local hitLine = Kit.frame(lane, { BackgroundColor3 = C.gold, Position = UDim2.fromOffset(hitX - 3, 0), Size = UDim2.new(0, 6, 1, 0) })
	hitLine.Name = "HitLine"
	local banner = Kit.label(body, "", { Position = UDim2.fromOffset(0, 198), Size = UDim2.new(1, 0, 0, 44), TextSize = 30, Font = Kit.fontBlack, TextXAlignment = Enum.TextXAlignment.Center })
	local chips = {}
	for i, p in ipairs(prompts) do
		local idx = table.find(game.actions, p.a) or 1
		local chip = Kit.label(lane, p.a, { BackgroundTransparency = 0, BackgroundColor3 = ACTION_COLORS[idx], Size = UDim2.fromOffset(96, 80), Position = UDim2.fromOffset(2000, 25), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, Font = Kit.fontBlack })
		Kit.corner(chip, 12)
		chips[i] = chip
	end
	local buttons = Kit.frame(body, { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, 0, 0, 90) })
	local bl = Kit.list(buttons, 10, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function elapsed()
		return workspace:GetServerTimeNow() - challenge.startAt
	end

	local function press(action)
		if finished then
			return
		end
		local t = elapsed()
		if t < 0 then
			return
		end
		-- the nearest open prompt within the scoring window
		local best, bestDt
		for i, p in ipairs(prompts) do
			if not answered[i] then
				local dt = math.abs(p.t - t)
				if dt <= Config.GOOD and (not best or dt < bestDt) then
					best, bestDt = i, dt
				end
			end
		end
		if not best then
			return
		end
		answered[best] = true
		table.insert(responses, { i = best, a = action, t = math.floor(t * 1000) / 1000 })
		local correct = prompts[best].a == action
		if correct and bestDt <= Config.PERFECT then
			perfect = perfect + 1
			banner.Text, banner.TextColor3 = "PERFECT!", C.gold
		elseif correct then
			good = good + 1
			banner.Text, banner.TextColor3 = "GOOD", C.good
		else
			miss = miss + 1
			banner.Text, banner.TextColor3 = "WRONG MOVE", C.bad
		end
		chips[best].BackgroundTransparency = 0.7
		if correct and ui.emotes and Players.LocalPlayer.Character then
			ui.emotes.play(Players.LocalPlayer.Character, game.moves[action])
		end
		if correct and ui.audio then
			ui.audio.play(challenge.game == "boxing" and "bag_hit" or "pad_kick")
		end
	end

	for i, action in ipairs(game.actions) do
		local b = Kit.button(buttons, action .. ((not UserInputService.TouchEnabled) and ("  [" .. i .. "]") or ""), function()
			press(action)
		end, { Size = UDim2.fromOffset(150, 84), LayoutOrder = i, TextSize = 18, Font = Kit.fontBlack }, "dark")
		b.BackgroundColor3 = ACTION_COLORS[i]
		b.TextColor3 = Color3.new(1, 1, 1)
	end
	local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in ipairs(KEYS) do
			if input.KeyCode == key and game.actions[i] then
				press(game.actions[i])
			end
		end
	end)

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not body.Parent then
			conn:Disconnect()
			keyConn:Disconnect()
			return
		end
		local t = elapsed()
		if t < 0 then
			banner.Text, banner.TextColor3 = tostring(math.ceil(-t)), C.text
		end
		for i, p in ipairs(prompts) do
			local x = hitX + (p.t - t) * SPEED - 48
			chips[i].Position = UDim2.fromOffset(x, 25)
			if not answered[i] and t > p.t + Config.GOOD then
				answered[i] = true
				miss = miss + 1
				chips[i].BackgroundTransparency = 0.85
			end
		end
		counters.Text = string.format("Perfect %d   •   Good %d   •   Miss %d", perfect, good, miss)
		if not finished and t > challenge.duration + 0.4 then
			finished = true
			conn:Disconnect()
			keyConn:Disconnect()
			local ok, res = State.call("submitChallenge", { responses = responses })
			if body.Parent then
				onDone(ok and res or nil)
			end
		end
	end)
end

return {
	title = "Training Challenges",
	width = 860,
	height = 560,
	build = function(body, args, ui)
		local function showList()
			Kit.clear(body)
			local d = State.data
			Kit.label(body, "Short skill challenges between collections. Earn XP, mastery and some cash. First " .. Config.GAME_DAILY_FULL .. " plays per day give full rewards.", { Size = UDim2.new(1, 0, 0, 40), TextColor3 = C.muted, TextSize = 14 })
			local grid = Kit.scroll(body, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46) })
			Kit.grid(grid, UDim2.fromOffset(260, 190), 12)
			for i, id in ipairs(Config.gameOrder) do
				local g = Config.games[id]
				local disc = g.discipline and Disciplines.byId[g.discipline]
				local locked = disc and not d.disciplines[disc.id]
				local card = Kit.frame(grid, { BackgroundColor3 = C.panel2, LayoutOrder = i })
				Kit.corner(card, 12)
				Kit.label(card, g.icon .. "  " .. g.name, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Font = Kit.fontBlack, TextColor3 = C.gold })
				Kit.label(card, g.description, { Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 54), TextSize = 13, Font = Kit.fontBody, TextYAlignment = Enum.TextYAlignment.Top })
				local best = d.minigame.best[id]
				Kit.label(card, best and ("Best score: " .. best) or "Not played yet", { Position = UDim2.fromOffset(12, 96), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextColor3 = C.muted })
				local b = Kit.button(card, locked and ("🔒 Unlock " .. disc.name) or "▶ Play", function()
					if locked then
						return
					end
					local ok, ch = State.call("startChallenge", { game = id })
					if ok then
						runGame(body, ui, ch, function(res)
							Kit.clear(body)
							local box = Kit.card(body, 260, 1)
							box.Size = UDim2.new(1, 0, 0, 260)
							if res then
								Kit.label(box, "SCORE " .. res.score .. (res.newBest and "  •  NEW BEST!" or ""), { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 40), TextSize = 30, Font = Kit.fontBlack, TextColor3 = C.gold })
								Kit.label(box, string.format("Perfect %d  •  Good %d  •  Miss %d\n+%s  •  +%d XP%s%s", res.perfect, res.good, res.miss, Format.cash(res.cash), res.xp,
									res.mastery > 0 and ("  •  +" .. res.mastery .. " mastery") or "", res.reduced and "\n(daily limit reached: reduced rewards)" or ""), { Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 90), TextSize = 17, TextYAlignment = Enum.TextYAlignment.Top })
								if res.cash > 0 then
									ui.cashPop("+" .. Format.cash(res.cash))
								end
							else
								Kit.label(box, "The result could not be saved. Try again.", { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 40), TextSize = 18 })
							end
							Kit.button(box, "Back to challenges", showList, { Position = UDim2.new(0, 16, 1, -60), Size = UDim2.fromOffset(240, 46) }, "gold")
						end)
					end
				end, { Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 44), TextSize = 16, Font = Kit.fontBlack }, locked and "dark" or "gold")
				Kit.setEnabled(b, not locked)
			end
		end
		showList()
		return nil
	end,
}
