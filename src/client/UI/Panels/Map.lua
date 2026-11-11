-- World map: all cities with requirements, rent, income multiplier, speciality,
-- passive income of your other branches; unlock and switch city.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Cities = require(Shared.Config.Cities)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

return {
	title = "World Map",
	width = 900,
	height = 620,
	build = function(body, args, ui)
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.grid(scroll, UDim2.fromOffset(280, 250), 10)
		local function render()
			Kit.clear(scroll)
			local d, x = State.data, State.derived
			for i, city in ipairs(Cities.list) do
				local owned = d.cities[city.id] ~= nil
				local active = d.activeCity == city.id
				local th = city.theme
				local card = Kit.frame(scroll, { BackgroundColor3 = C.panel2, LayoutOrder = i })
				Kit.corner(card, 12)
				Kit.stroke(card, active and C.gold or (owned and Kit.c3(th.accent) or C.stroke), active and 3 or 1)
				local banner = Kit.frame(card, { BackgroundColor3 = Kit.c3(th.accent), Size = UDim2.new(1, 0, 0, 56) })
				Kit.corner(banner, 12)
				Kit.label(banner, string.upper(city.name), { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 28), TextSize = 22, Font = Kit.fontBlack, TextColor3 = Color3.new(1, 1, 1) })
				Kit.label(banner, city.tagline, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 22), TextSize = 12, TextColor3 = Color3.new(1, 1, 1) })
				local lines = string.format("Income x%s  •  Rent %s/day  •  %d slots\nPrestige %s\n%s", tostring(city.incomeMult), Format.cash(city.rentPerDay), city.slots, string.rep("★", city.prestige), city.special)
				Kit.label(card, lines, { Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 90), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Font = Kit.fontBody })
				if owned then
					local passive = x.passive and x.passive[city.id]
					Kit.label(card, active and "★ You are managing this academy" or ("Earning ~" .. Format.cash(passive or 0) .. "/h while away"), { Position = UDim2.fromOffset(12, 156), Size = UDim2.new(1, -24, 0, 36), TextSize = 13, TextColor3 = active and C.gold or C.good })
					if not active then
						Kit.button(card, "Manage " .. city.name, function()
							ui.act("switchCity", { id = city.id }, "Welcome to " .. city.name .. "!")
							ui.close()
						end, { Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 38), TextSize = 14 }, "gold")
					end
				else
					local prev = Cities.list[i - 1]
					local req = {
						{ d.level >= city.unlock.level, "Level " .. city.unlock.level },
						{ d.reputation >= city.unlock.reputation, Format.short(city.unlock.reputation) .. " reputation" },
						{ d.cash >= city.unlock.cost, Format.cash(city.unlock.cost) },
						{ prev == nil or d.cities[prev.id] ~= nil, prev and (prev.name .. " unlocked") or "" },
					}
					local text = ""
					local all = true
					for _, r in ipairs(req) do
						if r[2] ~= "" then
							text = text .. (r[1] and "✔ " or "✘ ") .. r[2] .. "   "
						end
						all = all and r[1]
					end
					Kit.label(card, text, { Position = UDim2.fromOffset(12, 156), Size = UDim2.new(1, -24, 0, 40), TextSize = 12, TextColor3 = all and C.good or C.muted })
					local b = Kit.button(card, "Open academy " .. Format.cash(city.unlock.cost), function()
						local ok = ui.act("unlockCity", { id = city.id })
						if ok then
							ui.banner(city.name .. " unlocked!", "A new academy awaits. Switch to it from the map.", Kit.c3(th.accent))
							if ui.audio then
								ui.audio.play("unlock")
							end
						end
					end, { Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 38), TextSize = 14 }, "gold")
					Kit.setEnabled(b, all)
				end
			end
		end
		render()
		return render
	end,
}
