-- Martial arts mastery: rank per discipline (belts, sashes, banzuke, levels),
-- progress to the next rank and which class tiers each rank opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Modules.Formulas)
local Format = require(Shared.Modules.Format)
local Disciplines = require(Shared.Config.Disciplines)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "Martial Arts Mastery",
	width = 860,
	height = 620,
	build = function(body)
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.list(scroll, 8)
		local function render()
			Kit.clear(scroll)
			local d = State.data
			Kit.label(scroll, "Students earn mastery XP for your academy in every class. Higher ranks open better classes (Intermediate → Elite) that pay more.", { Size = UDim2.new(1, -8, 0, 40), TextSize = 14, TextColor3 = C.muted, LayoutOrder = 0 })
			for i, disc in ipairs(Disciplines.list) do
				local unlocked = d.disciplines[disc.id]
				local m = d.mastery[disc.id] or { rank = 1, xp = 0 }
				local rank = disc.ranks[m.rank]
				local card = Kit.card(scroll, 92, i)
				local swatch = Kit.frame(card, { BackgroundColor3 = Kit.c3(rank.color), Size = UDim2.fromOffset(44, 14), Position = UDim2.fromOffset(14, 14) })
				Kit.corner(swatch, 4)
				if rank.stripe then
					Kit.frame(swatch, { BackgroundColor3 = Kit.c3(rank.stripe), Size = UDim2.fromOffset(8, 14), Position = UDim2.fromOffset(30, 0) })
				end
				Kit.label(card, disc.name .. (unlocked and "" or "  (locked)"), { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(0.4, 0, 0, 26), TextSize = 18, Font = Kit.fontBlack, TextColor3 = unlocked and C.text or C.muted })
				Kit.label(card, rank.name .. "  (" .. m.rank .. "/" .. #disc.ranks .. ")", { Position = UDim2.new(0.45, 0, 0, 6), Size = UDim2.new(0.55, -14, 0, 26), TextSize = 15, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right })
				if m.rank < #disc.ranks then
					local need = Formulas.masteryXpForRank(m.rank)
					Kit.progress(card, m.xp / need, Kit.c3(disc.accent), { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 10) })
					Kit.label(card, Format.short(m.xp) .. " / " .. Format.short(need) .. " XP to " .. disc.ranks[m.rank + 1].name, { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(0.5, 0, 0, 18), TextSize = 12, TextColor3 = C.muted })
				else
					Kit.label(card, "★ MASTERED", { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 26), TextColor3 = C.gold, Font = Kit.fontBlack })
				end
				local tiers = ""
				for _, tier in ipairs(Disciplines.tiers) do
					local need = Disciplines.tierRankRequirement(disc, tier.id)
					tiers = tiers .. (m.rank >= need and "✔ " or "🔒 ") .. tier.name .. (m.rank >= need and "" or (" @" .. disc.ranks[need].name)) .. "   "
				end
				Kit.label(card, tiers, { Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 0, 18), TextSize = 11, TextColor3 = C.muted, Font = Kit.fontBody })
			end
		end
		render()
		return render
	end,
}
