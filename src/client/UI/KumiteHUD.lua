-- Your own kumite: you stand on the red mark of your competition hall, the
-- opponent attacks. Each attack slides towards the hit line; tap the right
-- answer when it gets there. The 3D bout, referee and scoreboard are drawn by
-- BoutController; the server scores your answers (Domain/Competition).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Config = require(Shared.Config.Activities)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)
local BoutController = require(script.Parent.Parent.Controllers.BoutController)

local KumiteHUD = {}

local C = Kit.colors
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local COLORS = {
	["High block"] = Color3.fromRGB(220, 70, 60),
	["Mid block"] = Color3.fromRGB(60, 140, 230),
	["Low block"] = Color3.fromRGB(240, 170, 40),
	Punch = Color3.fromRGB(90, 190, 100),
}
local SPEED = 240
local running = false

function KumiteHUD.isRunning()
	return running
end

local function showResult(ui, res)
	if not res then
		ui.toast("The bout could not be saved. Try again.", "error")
		return
	end
	local o = res.opponent or {}
	if res.won then
		ui.banner("🏆 YOU WIN!", res.score[1] .. " - " .. res.score[2] .. "  •  " .. res.method .. "  •  +" .. Format.cash(res.cash) .. "  +" .. res.reputation .. " rep", Color3.fromRGB(255, 215, 90))
		if res.cash > 0 then
			ui.cashPop("+" .. Format.cash(res.cash))
		end
	else
		ui.banner("DEFEATED", (o.name or "Opponent") .. " wins " .. res.score[2] .. " - " .. res.score[1] .. "  •  " .. res.method, Color3.fromRGB(220, 90, 80))
	end
	if res.nextLevel and res.nextLevel ~= res.level then
		ui.toast("Next opponent: level " .. res.nextLevel)
	end
end

function KumiteHUD.start(ui)
	if running then
		return
	end
	local ok, data = State.call("startKumite")
	if not ok then
		return
	end
	running = true
	ui.close()
	local k = Config.kumite
	local prompts = data.prompts
	local answered = {}
	local responses = {}
	local score = { 0, 0 }
	local first
	local finished = false

	local root = Kit.frame(ui.hudLayer, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Name = "Kumite" })
	local o = data.opponent
	local head = Kit.label(root, "KUMITE  •  vs " .. o.name .. " (" .. o.academy .. ")  •  level " .. data.level, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 172), Size = UDim2.fromOffset(620, 26),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, TextColor3 = C.gold, Font = Kit.fontBlack, TextStrokeTransparency = 0.4,
	})
	local banner = Kit.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(620, 60),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 40, Font = Kit.fontBlack, TextStrokeTransparency = 0.3,
	})
	local panel = Kit.frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(780, 206), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15 })
	Kit.corner(panel, 14)
	local lane = Kit.frame(panel, { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 92), ClipsDescendants = true })
	Kit.corner(lane, 10)
	local hitX = 100
	Kit.frame(lane, { BackgroundColor3 = C.gold, Position = UDim2.fromOffset(hitX - 3, 0), Size = UDim2.new(0, 6, 1, 0) })
	local chips = {}
	for i, p in ipairs(prompts) do
		local atk = k.attacks[p.a]
		local chip = Kit.label(lane, atk.call .. "\n" .. atk.hint, {
			BackgroundTransparency = 0, BackgroundColor3 = COLORS[atk.answer], Size = UDim2.fromOffset(120, 72), Position = UDim2.fromOffset(3000, 10),
			TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = Kit.fontBlack,
		})
		Kit.corner(chip, 10)
		chips[i] = chip
	end
	local conn, keyConn
	-- leave the bout (counts as a loss)
	Kit.button(root, "✕ Leave bout", function()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
		end
		if keyConn then
			keyConn:Disconnect()
		end
		State.call("quitKumite", nil, true)
		root:Destroy()
		running = false
		BoutController.setLiveScore(nil, nil)
		ui.toast("You left the mat (counts as a loss).", "warn")
	end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -222), Size = UDim2.fromOffset(170, 40), TextSize = 14, Font = Kit.fontBlack }, "dark")
	local buttons = Kit.frame(panel, { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 86) })
	local bl = Kit.list(buttons, 10, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function elapsed()
		return workspace:GetServerTimeNow() - data.startAt
	end
	local function push(call)
		BoutController.setLiveScore({ score[1], score[2] }, call)
	end
	local function scoreFor(side, points, call)
		if points <= 0 then
			return
		end
		score[side] = score[side] + points
		first = first or side
		push(call)
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
		end
		if keyConn then
			keyConn:Disconnect()
		end
		-- the server only accepts the result once the bout has really been fought
		task.spawn(function()
			local okR, res
			for _ = 1, 4 do
				okR, res = State.call("submitKumite", { responses = responses }, true)
				if okR then
					break
				end
				task.wait(0.6)
			end
			root:Destroy()
			running = false
			BoutController.setLiveScore(nil, nil)
			showResult(ui, okR and res or nil)
		end)
	end

	local function press(answer)
		if finished then
			return
		end
		local t = elapsed()
		if t < 0 then
			return
		end
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
		table.insert(responses, { i = best, a = answer, t = math.floor(t * 1000) / 1000 })
		local atk = k.attacks[prompts[best].a]
		chips[best].BackgroundTransparency = 0.75
		if answer == atk.answer then
			local perfect = bestDt <= Config.PERFECT
			local pts = perfect and atk.perfect or atk.good
			banner.Text, banner.TextColor3 = (pts >= 3 and "IPPON!" or pts >= 2 and "WAZA-ARI!" or "YUKO!"), C.gold
			scoreFor(1, pts, banner.Text)
			if ui.emotes and Players.LocalPlayer.Character then
				ui.emotes.play(Players.LocalPlayer.Character, k.answerMoves[answer])
			end
			if ui.audio then
				ui.audio.play("pad_kick")
			end
		else
			banner.Text, banner.TextColor3 = "WRONG ANSWER", C.bad
			scoreFor(2, atk.lose, "Point for " .. o.name)
		end
		if math.abs(score[1] - score[2]) >= k.lead then
			banner.Text = score[1] > score[2] and "8-POINT LEAD!" or "STOPPED"
			finish()
		end
	end

	for i, answer in ipairs(k.answers) do
		local b = Kit.button(buttons, answer .. ((not UserInputService.TouchEnabled) and ("  [" .. i .. "]") or ""), function()
			press(answer)
		end, { Size = UDim2.fromOffset(176, 82), LayoutOrder = i, TextSize = 18, Font = Kit.fontBlack }, "dark")
		b.BackgroundColor3 = COLORS[answer]
		b.TextColor3 = Color3.new(1, 1, 1)
	end
	keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in ipairs(KEYS) do
			if input.KeyCode == key and k.answers[i] then
				press(k.answers[i])
			end
		end
	end)

	push("Rei!")
	conn = RunService.RenderStepped:Connect(function()
		local t = elapsed()
		if t < 0 then
			banner.Text, banner.TextColor3 = tostring(math.ceil(-t)), C.text
		elseif t < 0.8 then
			banner.Text, banner.TextColor3 = "HAJIME!", C.gold
		end
		for i, p in ipairs(prompts) do
			chips[i].Position = UDim2.fromOffset(hitX + (p.t - t) * SPEED - 60, 10)
			if not answered[i] and t > p.t + Config.GOOD then
				answered[i] = true
				chips[i].BackgroundTransparency = 0.85
				local atk = k.attacks[p.a]
				if atk.lose > 0 then
					banner.Text, banner.TextColor3 = "TOO LATE", C.bad
					scoreFor(2, atk.lose, "Point for " .. o.name)
				end
				if math.abs(score[1] - score[2]) >= k.lead then
					finish()
					return
				end
			end
		end
		head.Text = string.format("KUMITE  •  YOU %d - %d %s  •  level %d", score[1], score[2], o.name, data.level)
		if t > prompts[#prompts].t + 1 then
			finish()
		end
	end)
end

return KumiteHUD
