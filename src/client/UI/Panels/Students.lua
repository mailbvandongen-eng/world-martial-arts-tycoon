-- Student roster: regular students with name, discipline, belt/rank, progress
-- to the next rank, talent, attendance and satisfaction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Disciplines = require(Shared.Config.Disciplines)
local Format = require(Shared.Modules.Format)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function rankXpNeeded(rank)
	return math.floor(30 * 1.55 ^ (rank - 1)) -- same rule as the server (Domain/Activities)
end

return {
	title = "Students",
	width = 860,
	height = 600,
	build = function(body, args, ui)
		local filter = args.discipline or "all"
		local head = Kit.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
		local scroll = Kit.scroll(body, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48) })
		Kit.list(scroll, 6)
		local lastSig
		local function render(force)
			local d = State.data
			local list = {}
			local counts = {}
			for _, s in pairs(d.students) do
				counts[s.discipline] = (counts[s.discipline] or 0) + 1
				if filter == "all" or s.discipline == filter then
					table.insert(list, s)
				end
			end
			local sig = filter .. #list
			for _, s in ipairs(list) do
				sig = sig .. s.id .. s.rank .. math.floor(s.xp)
			end
			if sig == lastSig and not force then
				return
			end
			lastSig = sig
			Kit.clear(head)
			Kit.list(head, 6, true)
			local function chip(id, text, order)
				local b = Kit.button(head, text, function()
					filter = id
					render(true)
				end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = order, TextSize = 13 }, filter == id and "gold" or "dark")
				return b
			end
			local total = 0
			for _ in pairs(d.students) do
				total = total + 1
			end
			chip("all", "All (" .. total .. ")", 0)
			for i, disc in ipairs(Disciplines.list) do
				if counts[disc.id] then
					chip(disc.id, disc.name .. " (" .. counts[disc.id] .. ")", i)
				end
			end
			Kit.clear(scroll)
			table.sort(list, function(a, b)
				if a.rank ~= b.rank then
					return a.rank > b.rank
				end
				return a.visits > b.visits
			end)
			if #list == 0 then
				Kit.label(scroll, "No regular students yet. Happy visitors sign up as regular students; they come back, train and earn new belts.", { Size = UDim2.new(1, -8, 0, 60), TextColor3 = C.muted, TextSize = 15 })
			end
			for i, s in ipairs(list) do
				local disc = Disciplines.byId[s.discipline]
				local rank = disc.ranks[s.rank]
				local card = Kit.card(scroll, 62, i)
				local belt = Kit.frame(card, { BackgroundColor3 = Kit.c3(rank.color), Size = UDim2.fromOffset(46, 14), Position = UDim2.fromOffset(12, 24) })
				Kit.corner(belt, 4)
				Kit.stroke(belt, Color3.fromRGB(90, 90, 90), 1)
				if rank.stripe then
					Kit.frame(belt, { BackgroundColor3 = Kit.c3(rank.stripe), Size = UDim2.fromOffset(8, 14), Position = UDim2.fromOffset(32, 0) })
				end
				Kit.label(card, s.name, { Position = UDim2.fromOffset(70, 6), Size = UDim2.new(0.3, 0, 0, 24), TextSize = 17, Font = Kit.fontBlack })
				Kit.label(card, disc.name .. " • " .. rank.name, { Position = UDim2.fromOffset(70, 32), Size = UDim2.new(0.34, 0, 0, 22), TextSize = 13, TextColor3 = C.muted })
				local cap = (d.mastery[s.discipline] and d.mastery[s.discipline].rank) or 1
				local need = rankXpNeeded(s.rank)
				local atCap = s.rank >= cap
				Kit.label(card, atCap and "Needs a higher academy mastery rank" or ("Next: " .. (disc.ranks[s.rank + 1] and disc.ranks[s.rank + 1].name or "max")), { Position = UDim2.new(0.42, 0, 0, 8), Size = UDim2.new(0.3, 0, 0, 18), TextSize = 12, TextColor3 = atCap and C.rep or C.muted })
				Kit.progress(card, atCap and 1 or s.xp / need, atCap and C.rep or Kit.c3(disc.accent), { Position = UDim2.new(0.42, 0, 0, 32), Size = UDim2.new(0.28, 0, 0, 10) })
				Kit.label(card, string.rep("★", s.talent) .. string.rep("☆", 5 - s.talent), { Position = UDim2.new(0.74, 0, 0, 6), Size = UDim2.new(0.24, 0, 0, 22), TextColor3 = C.gold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right })
				Kit.label(card, Format.commas(s.visits) .. " classes • " .. math.floor(s.satisfaction) .. "% happy", { Position = UDim2.new(0.74, 0, 0, 32), Size = UDim2.new(0.24, 0, 0, 20), TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
		render(true)
		return render
	end,
}
