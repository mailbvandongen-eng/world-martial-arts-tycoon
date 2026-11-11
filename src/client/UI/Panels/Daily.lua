-- Daily login rewards: 7-day track, claim once per UTC day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Progression = require(Shared.Config.Progression)
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "Daily Rewards",
	width = 860,
	height = 420,
	build = function(body, args, ui)
		local row = Kit.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 240) })
		local l = Kit.list(row, 8, true)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local claim
		local function render()
			Kit.clear(row)
			local d, x = State.data, State.derived
			local st = x.daily
			for i, r in ipairs(Progression.daily) do
				local isNext = i == st.nextDay
				local done = i < st.nextDay
				local card = Kit.frame(row, { BackgroundColor3 = isNext and C.goldDark or C.panel2, Size = UDim2.fromOffset(108, 230), LayoutOrder = i })
				Kit.corner(card, 10)
				Kit.stroke(card, isNext and C.gold or C.stroke, isNext and 2 or 1)
				Kit.label(card, "DAY " .. i, { Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.fontBlack, TextColor3 = C.gold })
				local lines = {}
				if r.cash then
					table.insert(lines, Format.cash(math.floor(r.cash * math.max(1, Formulas.rewardCashUnit(d.level) / 400))))
				end
				if r.gems then
					table.insert(lines, "◆ " .. r.gems)
				end
				if r.boost then
					table.insert(lines, Monetization.boosts[r.boost].name .. " " .. r.minutes .. "m")
				end
				if r.cosmetic then
					table.insert(lines, Cosmetics.byId[r.cosmetic].name)
				end
				Kit.label(card, table.concat(lines, "\n"), { Position = UDim2.fromOffset(6, 36), Size = UDim2.new(1, -12, 1, -70), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14 })
				Kit.label(card, done and "✔" or "", { Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.good, TextSize = 22, Font = Kit.fontBlack })
			end
			claim.Text = st.available and ("Claim day " .. st.nextDay) or "Come back tomorrow"
			Kit.setEnabled(claim, st.available)
		end
		claim = Kit.button(body, "Claim", function()
			local ok, res = ui.act("claimDaily", {})
			if ok then
				ui.banner("Day " .. res.day .. " reward!", (res.cash > 0 and ("+" .. Format.cash(res.cash) .. "  ") or "") .. "+◆" .. res.gems .. (res.cosmetic and ("  + " .. Cosmetics.byId[res.cosmetic].name) or ""))
				if ui.audio then
					ui.audio.play("cash")
				end
			end
		end, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 256), Size = UDim2.fromOffset(300, 54), TextSize = 20, Font = Kit.fontBlack }, "gold")
		Kit.label(body, "Log in every day: the streak restarts at day 1 after day 7 or when you miss a day.", { Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.muted, TextSize = 13 })
		render()
		return render
	end,
}
