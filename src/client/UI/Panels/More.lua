-- "More" menu: everything that is not on the main navigation.

local Kit = require(script.Parent.Parent.Kit)

local C = Kit.colors

local ITEMS = {
	{ "🌍", "World Map", "map" },
	{ "🎒", "Inventory", "inventory" },
	{ "🥋", "Martial Arts", "academy", { tab = "disciplines" } },
	{ "🎖", "Mastery", "mastery" },
	{ "📊", "Statistics", "stats" },
	{ "🏅", "Achievements", "stats", { tab = "achievements" } },
	{ "🏆", "Leaderboards", "leaderboards" },
	{ "👥", "Visit Players", "players" },
	{ "⚙", "Settings", "settings" },
	{ "♻", "Rebirth", "rebirth" },
}

return {
	title = "More",
	width = 640,
	height = 470,
	build = function(body, args, ui)
		local grid = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.grid(grid, UDim2.fromOffset(140, 110), 12)
		for i, item in ipairs(ITEMS) do
			local b = Kit.button(grid, "", function()
				ui.open(item[3], item[4])
			end, { LayoutOrder = i }, "dark")
			Kit.stroke(b, C.stroke, 1)
			Kit.label(b, item[1], { Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 34, TextColor3 = C.gold })
			Kit.label(b, item[2], { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15 })
		end
		return nil
	end,
}
