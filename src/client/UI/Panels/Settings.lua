-- Settings: music, sound effects, NPC density and low graphics.

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function applyGraphics(low)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
			e.Enabled = not low
		end
	end
	Lighting.GlobalShadows = not low
end

return {
	title = "Settings",
	width = 620,
	height = 440,
	applyGraphics = applyGraphics,
	build = function(body, args, ui)
		local list = Kit.frame(body, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		Kit.list(list, 10)
		local function render()
			Kit.clear(list)
			local s = State.data.settings
			local function toggle(order, label, key)
				local card = Kit.card(list, 56, order)
				Kit.label(card, label, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0), TextSize = 16 })
				local on = s[key] == true
				Kit.button(card, on and "ON" or "OFF", function()
					State.call("settings", { key = key, value = not on })
					if key == "lowGraphics" then
						applyGraphics(not on)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 38) }, on and "good" or "dark")
			end
			toggle(1, "Music", "music")
			toggle(2, "Sound effects", "sfx")
			toggle(3, "Low graphics (no shadows / bloom)", "lowGraphics")
			local density = Kit.card(list, 56, 4)
			Kit.label(density, "Visitors shown", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -380, 1, 0), TextSize = 16 })
			for i, name in ipairs({ "Low", "Normal", "High" }) do
				local v = i - 1
				Kit.button(density, name, function()
					State.call("settings", { key = "npcDensity", value = v })
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - (3 - i) * 120, 0.5, 0), Size = UDim2.fromOffset(110, 38) }, s.npcDensity == v and "gold" or "dark")
			end
			Kit.label(list, "Controls: walk to a room door and press E (gamepad X, or tap) to manage it. Gamepad: Y collects, B closes menus.", { Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.muted, TextSize = 13, LayoutOrder = 5 })
		end
		render()
		return render
	end,
}
