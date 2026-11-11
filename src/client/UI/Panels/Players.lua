-- Social: players in this server; visit their academy, inspect it (stats,
-- mastery, rare trainers in 3D), and rate it once per day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Cities = require(Shared.Config.Cities)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)

local Kit = require(script.Parent.Parent.Kit)
local Preview = require(script.Parent.Parent.Preview)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors
local myId = game:GetService("Players").LocalPlayer.UserId

local function inspectView(body, info, ui, back)
	Kit.clear(body)
	local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
	Kit.list(scroll, 8)
	local head = Kit.card(scroll, 110, 1)
	Kit.label(head, info.name .. "'s Academy", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 30), TextSize = 22, Font = Kit.fontBlack, TextColor3 = C.gold })
	Kit.label(head, string.format("Level %d%s  •  %s  •  %d cities  •  %d rooms  •  %d disciplines\nReputation %s  •  Earned %s  •  %s students  •  Rating %s",
		info.level, info.rebirths > 0 and (" ★" .. info.rebirths .. " " .. (info.prestigeTitle or "")) or "", Cities.byId[info.activeCity] and Cities.byId[info.activeCity].name or "",
		info.cities, info.rooms, info.disciplines, Format.short(info.reputation), Format.cash(info.earned), Format.short(info.students),
		info.ratingCount > 0 and string.format("%.1f★ (%d)", info.rating, info.ratingCount) or "—"), { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 60), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
	Kit.button(head, "← Back", back, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(100, 32), TextSize = 14 }, "dark")
	-- mastery
	local m = Kit.card(scroll, 90, 2)
	local text = ""
	for id, rankName in pairs(info.mastery) do
		local disc = Disciplines.byId[id]
		if disc then
			text = text .. disc.name .. ": " .. rankName .. "    "
		end
	end
	Kit.label(m, "MASTERY\n" .. (text ~= "" and text or "—"), { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top })
	-- trainers showcase
	local tcard = Kit.card(scroll, 240, 3)
	Kit.label(tcard, "TOP TRAINERS", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20), TextColor3 = C.gold, Font = Kit.fontBlack, TextSize = 13 })
	local row = Kit.frame(tcard, { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -36) })
	Kit.list(row, 8, true)
	for i, t in ipairs(info.trainers) do
		if i > 6 then
			break
		end
		local r = Trainers.rarityById[t.rarity]
		local f = Kit.frame(row, { BackgroundColor3 = C.panel, Size = UDim2.fromOffset(120, 200), LayoutOrder = i })
		Kit.corner(f, 8)
		Kit.stroke(f, Kit.c3(r.color), 2)
		Preview.character(f, { seed = t.seed, discipline = t.discipline, role = "trainer", rarity = t.rarity }, { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 140) })
		Kit.label(f, t.name, { Position = UDim2.fromOffset(6, 146), Size = UDim2.new(1, -12, 0, 30), TextSize = 12, Font = Kit.fontBlack, TextYAlignment = Enum.TextYAlignment.Top })
		Kit.label(f, r.name .. " • Lv " .. t.level, { Position = UDim2.fromOffset(6, 176), Size = UDim2.new(1, -12, 0, 18), TextSize = 11, TextColor3 = Kit.c3(r.color) })
	end
	-- rating
	if info.userId ~= myId then
		local rate = Kit.card(scroll, 60, 4)
		Kit.label(rate, "Rate this academy:", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 160, 1, 0), TextSize = 15 })
		for s = 1, 5 do
			Kit.button(rate, string.rep("★", s), function()
				ui.act("rate", { userId = info.userId, stars = s }, "Thanks for rating!")
			end, { Position = UDim2.fromOffset(170 + (s - 1) * 110, 10), Size = UDim2.fromOffset(100, 40), TextSize = 14 }, "dark")
		end
	end
end

return {
	title = "Players",
	width = 860,
	height = 600,
	build = function(body, args, ui)
		local function showList()
			Kit.clear(body)
			local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
			Kit.list(scroll, 8)
			local ok, list = State.call("players", {})
			if not ok or not body.Parent then
				return
			end
			for i, p in ipairs(list) do
				local card = Kit.card(scroll, 60, i)
				local me = p.userId == myId
				Kit.label(card, p.name .. (me and "  (you)" or ""), { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(0.4, 0, 0, 26), TextSize = 17, Font = Kit.fontBlack })
				Kit.label(card, "Lv " .. p.level .. (p.rebirths > 0 and (" ★" .. p.rebirths) or "") .. "  •  " .. (Cities.byId[p.city] and Cities.byId[p.city].name or "") .. (p.rating > 0 and string.format("  •  %.1f★", p.rating) or ""), { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(0.5, 0, 0, 22), TextSize = 13, TextColor3 = C.muted })
				Kit.button(card, "Inspect", function()
					local okI, info = State.call("inspect", { userId = p.userId })
					if okI and body.Parent then
						inspectView(body, info, ui, showList)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -140, 0.5, 0), Size = UDim2.fromOffset(120, 38), TextSize = 14 }, "dark")
				local visit = Kit.button(card, "Visit", function()
					local okV = ui.act("visit", { userId = p.userId })
					if okV then
						ui.close()
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 38), TextSize = 14 }, "gold")
				Kit.setEnabled(visit, not me and p.hasPlot)
			end
		end
		task.spawn(showList)
		return nil
	end,
}
