-- Rebirth (prestige): requirements, rewards, exactly what resets and what stays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local Progression = require(Shared.Config.Progression)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "Rebirth",
	width = 760,
	height = 560,
	build = function(body, args, ui)
		local holder = Kit.frame(body, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		local function render()
			Kit.clear(holder)
			local d, x = State.data, State.derived
			local rb = Progression.rebirth
			local nextMult = Formulas.rebirthMult(d.rebirths + 1)
			local titles = rb.titles
			local nextTitle = titles[math.min(d.rebirths + 1, #titles)]
			Kit.label(holder, string.format("Rebirths: %d   •   Permanent income bonus now x%.2f → after rebirth x%.2f", d.rebirths, Formulas.rebirthMult(d.rebirths), nextMult), { Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 16 })
			Kit.label(holder, "Rewards: +" .. math.floor(rb.incomeBonusPerRebirth * 100) .. "% income forever, ◆" .. rb.gemsReward .. " gems, the title \"" .. nextTitle .. "\" and prestige cosmetics (Prestige Aura, Prestige Pillars).", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 44), TextSize = 14 })
			local resets = Kit.card(holder, 200, 0)
			resets.Position = UDim2.fromOffset(0, 80)
			resets.Size = UDim2.new(0.5, -6, 0, 220)
			Kit.label(resets, "RESETS\n• " .. table.concat(rb.resets, "\n• "), { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 1, -20), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.bad })
			local keeps = Kit.card(holder, 200, 0)
			keeps.Position = UDim2.new(0.5, 6, 0, 80)
			keeps.Size = UDim2.new(0.5, -6, 0, 220)
			Kit.label(keeps, "YOU KEEP\n• " .. table.concat(rb.keeps, "\n• "), { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 1, -20), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.good })
			Kit.label(holder, "Requirements: level " .. rb.minLevel .. " and " .. rb.minCities .. " cities." .. (x.rebirth.can and "  ✔ Ready!" or ("  (" .. tostring(x.rebirth.reason) .. ")")), { Position = UDim2.fromOffset(0, 310), Size = UDim2.new(1, 0, 0, 26), TextSize = 14, TextColor3 = x.rebirth.can and C.good or C.muted })
			local b = Kit.button(holder, "REBIRTH", function()
				ui.confirm("Rebirth now?", "Your cash, level, reputation, cities, rooms and licences reset. You keep gems, trainers, mastery, cosmetics and purchases, and earn +" .. math.floor(rb.incomeBonusPerRebirth * 100) .. "% income forever.", function()
					local ok, res = State.call("rebirth", { confirm = true })
					if ok then
						ui.close()
						ui.banner("REBORN!", "You are now a " .. res.title)
					end
				end)
			end, { Position = UDim2.fromOffset(0, 350), Size = UDim2.new(1, 0, 0, 56), TextSize = 22, Font = Kit.fontBlack }, "gold")
			Kit.setEnabled(b, x.rebirth.can)
		end
		render()
		return render
	end,
}
