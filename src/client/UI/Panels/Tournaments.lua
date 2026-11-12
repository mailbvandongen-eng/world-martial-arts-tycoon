-- Tournaments: the current server-wide tournament (registration, bracket that
-- reveals round by round, prizes) and the next one. All results come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Disciplines = require(Shared.Config.Disciplines)
local Config = require(Shared.Config.Activities)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors
local ROUND_NAMES = { "Quarter-finals", "Semi-finals", "Final" }

return {
	title = "Tournaments",
	width = 900,
	height = 620,
	build = function(body, args, ui)
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.list(scroll, 10)
		local lastSig
		local function render(force)
			local t = State.tournament
			local d = State.data
			local now = workspace:GetServerTimeNow()
			local phase
			if not t then
				phase = "none"
			elseif now < t.info.regEnd then
				phase = "registration"
			elseif now < t.info.endAt then
				phase = "running"
			else
				phase = "finished"
			end
			local revealed = 0
			if t and t.rounds then
				for r = 1, 3 do
					if now >= t.info.rounds[r] then
						revealed = r
					end
				end
			end
			local sig = phase .. (t and (t.info.key .. #t.entrants .. revealed) or "") .. tostring(d.tournament.key) .. math.floor(now / 5)
			if sig == lastSig and not force then
				return
			end
			lastSig = sig
			Kit.clear(scroll)
			if not t then
				Kit.label(scroll, "Loading tournament schedule...", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted })
				return
			end
			local info = t.info
			local disc = info.discipline and Disciplines.byId[info.discipline]
			local head = Kit.card(scroll, 120, 1)
			Kit.stroke(head, C.gold, 2)
			Kit.label(head, "🏆 " .. info.name, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 30), TextSize = 24, Font = Kit.fontBlack, TextColor3 = C.gold })
			local phaseText = phase == "registration" and ("Registration closes in " .. Format.time(info.regEnd - now))
				or phase == "running" and "Matches in progress"
				or "Finished • next tournament in " .. Format.time(info.nextAt - now)
			Kit.label(head, (disc and (disc.name .. " academies only") or "Open to every discipline: your strongest one competes") .. "\n" .. phaseText, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(0.6, 0, 0, 44), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
			local entered = d.tournament.key == info.key
			local fee = Formulas.rewardCashUnit(d.level) * Config.ENTRY_FEE
			if phase == "registration" then
				local locked = disc and not d.disciplines[disc.id]
				local b = Kit.button(head, entered and "✔ Entered" or (locked and ("🔒 Unlock " .. disc.name) or ("Enter • " .. Format.cash(fee))), function()
					local ok = ui.act("enterTournament", {}, "Your academy entered the " .. info.name .. "!")
					if ok then
						render(true)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(240, 54), TextSize = 17, Font = Kit.fontBlack }, entered and "dark" or "gold")
				Kit.setEnabled(b, not entered and not locked and d.cash >= fee)
			end
			-- entrants
			local list = Kit.card(scroll, 44 + math.max(1, #t.entrants) * 24, 2)
			Kit.label(list, "ENTRANTS (" .. #t.entrants .. " academies, rivals fill the bracket up to " .. Config.TOURNAMENT_SIZE .. ")", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
			for i, e in ipairs(t.entrants) do
				Kit.label(list, e.name .. "  •  strength " .. e.strength, { Position = UDim2.fromOffset(14, 32 + (i - 1) * 24), Size = UDim2.new(1, -28, 0, 22), TextSize = 14 })
			end
			if #t.entrants == 0 then
				Kit.label(list, "No academies yet. Be the first!", { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 22), TextSize = 14, TextColor3 = C.muted })
			end
			-- bracket, revealed round by round
			if t.rounds then
				for r = 1, 3 do
					local matches = t.rounds[r]
					local card = Kit.card(scroll, 40 + #matches * 30, 2 + r)
					local shown = r <= revealed
					Kit.label(card, ROUND_NAMES[r] .. (shown and "" or ("  •  starts in " .. Format.time(info.rounds[r] - now))), { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 14 })
					for i, m in ipairs(matches) do
						local mine = (m.aUser == State.localUserId) or (m.bUser == State.localUserId)
						local text = m.a .. "  vs  " .. m.b
						if shown then
							text = text .. "   →   🏅 " .. m.winner
						end
						Kit.label(card, text, { Position = UDim2.fromOffset(14, 34 + (i - 1) * 30), Size = UDim2.new(1, -28, 0, 26), TextSize = 14, TextColor3 = mine and C.gold or C.text, Font = mine and Kit.fontBlack or Kit.font })
					end
				end
			end
			-- prizes
			local prizes = Kit.card(scroll, 130, 10)
			local unit = Formulas.rewardCashUnit(d.level)
			local lines = "PRIZES\n"
			for _, p in ipairs(Config.prizes) do
				local label = p.place == 1 and "Winner" or p.place == 2 and "Runner-up" or p.place == 3 and "Semi-finalists" or "Quarter-finalists"
				lines = lines .. string.format("%s: %s  •  ◆%d  •  +%d reputation\n", label, Format.cash(p.cash * unit), p.gems, p.reputation)
			end
			Kit.label(prizes, lines, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top })
			Kit.label(scroll, "Your academy's strength comes from your mastery rank, your best trainer and your best room in the discipline. Matches are fought in the Tournament Arena on the boulevard.", { Size = UDim2.new(1, -8, 0, 40), TextColor3 = C.muted, TextSize = 12, LayoutOrder = 11 })
		end
		render(true)
		local conn = State.TournamentChanged:Connect(function()
			render(true)
		end)
		task.spawn(function()
			while scroll.Parent do
				task.wait(1)
				pcall(render)
			end
			conn:Disconnect()
		end)
		return render
	end,
}
