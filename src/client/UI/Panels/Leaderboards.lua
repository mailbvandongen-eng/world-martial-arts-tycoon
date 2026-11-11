-- Leaderboards: global top 10 (OrderedDataStores, refreshed every few minutes)
-- and live rankings of the players in this server.

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local STATS = {
	{ id = "richest", name = "Richest" }, { id = "level", name = "Level" }, { id = "students", name = "Students" },
	{ id = "reputation", name = "Reputation" }, { id = "mastered", name = "Mastered" }, { id = "cities", name = "Cities" },
	{ id = "prestige", name = "Prestige" },
}

return {
	title = "Leaderboards",
	width = 860,
	height = 600,
	build = function(body)
		local content = Kit.frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		local function column(title, entries, x, emptyText)
			local col = Kit.frame(content, { BackgroundColor3 = C.panel2, Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0) })
			Kit.corner(col, 10)
			Kit.label(col, title, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 22), TextColor3 = C.gold, Font = Kit.fontBlack })
			local list = Kit.scroll(col, { Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 1, -44) })
			Kit.list(list, 4)
			if #entries == 0 then
				Kit.label(list, emptyText, { Size = UDim2.new(1, 0, 0, 40), TextColor3 = C.muted, TextSize = 13 })
			end
			for i, e in ipairs(entries) do
				local row = Kit.frame(list, { BackgroundColor3 = i <= 3 and C.goldDark or C.panel, Size = UDim2.new(1, -6, 0, 34), LayoutOrder = i })
				Kit.corner(row, 6)
				Kit.label(row, i .. ".  " .. e.name, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 14 })
				Kit.label(row, e.text, { Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -10, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, TextColor3 = C.gold })
			end
		end
		local function load(statId)
			Kit.clear(content)
			Kit.label(content, "Loading...", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted })
			task.spawn(function()
				local ok, res = State.call("leaderboard", { stat = statId })
				if not content.Parent then
					return
				end
				Kit.clear(content)
				if not ok then
					return
				end
				column("GLOBAL TOP 10", res.global, 0, res.available == false and "Global boards need DataStores (live game or Studio API access)." or "Refreshing every 2 minutes...")
				column("THIS SERVER", res.server, 0.5, "")
			end)
		end
		local _, select = Kit.tabs(body, (function()
			local t = {}
			for _, s in ipairs(STATS) do
				table.insert(t, { id = s.id, name = s.name, width = 108 })
			end
			return t
		end)(), load)
		select("richest")
		return nil
	end,
}
