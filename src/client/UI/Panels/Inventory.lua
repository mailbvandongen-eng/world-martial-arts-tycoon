-- Inventory: owned cosmetics (equip / unequip, play poses), decorations,
-- active boosts and owned passes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local KIND_NAMES = { outfit = "Outfits", aura = "Auras", pose = "Poses & Emotes", deco = "Decorations", title = "Titles" }

return {
	title = "Inventory",
	width = 860,
	height = 600,
	build = function(body, args, ui)
		local tab = args.tab or "outfit"
		local scroll = Kit.scroll(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		Kit.list(scroll, 8)
		local function render()
			Kit.clear(scroll)
			local d = State.data
			local eq = d.cosmetics.equipped
			if tab == "boosts" then
				local now = workspace:GetServerTimeNow()
				local any = false
				for kind, untilTime in pairs(d.boosts) do
					if untilTime > now then
						any = true
						local card = Kit.card(scroll, 50, 1)
						Kit.label(card, Monetization.boosts[kind].name .. "  •  " .. Format.time(untilTime - now) .. " left", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 16 })
					end
				end
				if not any then
					Kit.label(scroll, "No active boosts. Daily rewards and the Store give boosts.", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted })
				end
				local passes = Kit.card(scroll, 120, 2)
				local names = {}
				for key in pairs(d.purchases.passes) do
					local p = Monetization.passByKey[key]
					if p then
						table.insert(names, p.name)
					end
				end
				Kit.label(passes, "OWNED PASSES\n" .. (#names > 0 and table.concat(names, ", ") or "None yet"), { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
				return
			end
			local order = 0
			for _, c in ipairs(Cosmetics.list) do
				if c.kind == tab and d.cosmetics.owned[c.id] then
					order = order + 1
					local card = Kit.card(scroll, 56, order)
					local isOn
					if c.kind == "deco" then
						isOn = false
						for _, id in ipairs(eq.deco or {}) do
							if id == c.id then
								isOn = true
							end
						end
					else
						isOn = eq[c.kind] == c.id
					end
					Kit.label(card, c.name, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -300, 1, 0), TextSize = 16, Font = Kit.fontBlack, TextColor3 = isOn and C.gold or C.text })
					if c.kind == "pose" then
						Kit.button(card, "▶ Play", function()
							if ui.emotes then
								ui.emotes.request(c.id)
							end
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 38) }, "gold")
					else
						Kit.button(card, isOn and "Unequip" or "Equip", function()
							ui.act("equipCosmetic", { id = c.id, on = not isOn })
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 38) }, isOn and "dark" or "gold")
					end
				end
			end
			if order == 0 then
				Kit.label(scroll, "Nothing here yet. Get " .. KIND_NAMES[tab] .. " from events, daily rewards, levels, rebirths and the Store.", { Size = UDim2.new(1, 0, 0, 40), TextColor3 = C.muted })
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "outfit", name = "Outfits", width = 100 },
			{ id = "aura", name = "Auras", width = 90 },
			{ id = "pose", name = "Poses", width = 90 },
			{ id = "deco", name = "Decorations", width = 120 },
			{ id = "title", name = "Titles", width = 90 },
			{ id = "boosts", name = "Boosts & Passes", width = 150 },
		}, function(id)
			tab = id
			render()
		end)
		select(tab)
		return render
	end,
}
