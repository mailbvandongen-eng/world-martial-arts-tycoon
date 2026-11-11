-- Build menu for an empty slot: every room type with price, unlock state and
-- a short description. Building happens on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Rooms = require(Shared.Config.Rooms)
local Disciplines = require(Shared.Config.Disciplines)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function lockReason(d, def, branch)
	if def.discipline and def.discipline ~= "fitness" and not d.disciplines[def.discipline] then
		return "Unlock " .. Disciplines.byId[def.discipline].name .. " (Academy menu)"
	end
	if d.level < def.unlockLevel then
		return "Requires level " .. def.unlockLevel
	end
	local count = 0
	for _, r in pairs(branch.rooms) do
		if r.id == def.id then
			count = count + 1
		end
	end
	if def.kind ~= "training" and count >= 1 then
		return "Already built here"
	end
	if def.kind == "training" and count >= 2 then
		return "Max 2 per academy"
	end
	return nil
end

return {
	title = "Build a Room",
	width = 820,
	height = 580,
	build = function(body, args, ui)
		local slot = args.slot
		local filter = "training"
		local list
		local function render()
			Kit.clear(list)
			local d = State.data
			local branch = d.cities[d.activeCity]
			if branch.rooms[tostring(slot)] then
				ui.close()
				return
			end
			local order = 0
			for _, def in ipairs(Rooms.list) do
				local show = def.kind ~= "reception" and ((filter == "training" and def.kind == "training") or (filter == "other" and def.kind ~= "training"))
				if show then
					order = order + 1
					local reason = lockReason(d, def, branch)
					local cost = Formulas.roomBuildCost(def.id, d.activeCity)
					local card = Kit.card(list, 74, (reason and 1000 or 0) + order)
					local accent = Kit.c3(def.color)
					local icon = Kit.frame(card, { BackgroundColor3 = accent, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(10, 10) })
					Kit.corner(icon, 10)
					Kit.label(icon, def.icon, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 26, Font = Kit.fontBlack })
					Kit.label(card, def.name, { Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -260, 0, 22), TextSize = 18, Font = Kit.fontBlack })
					local info = def.description
					if def.capacity then
						info = info .. "  •  " .. def.capacity .. " students"
					end
					Kit.label(card, reason or info, { Position = UDim2.fromOffset(76, 32), Size = UDim2.new(1, -260, 0, 36), TextSize = 13, Font = Kit.fontBody, TextColor3 = reason and C.bad or C.muted, TextYAlignment = Enum.TextYAlignment.Top })
					local affordable = d.cash >= cost
					local b = Kit.button(card, reason and "Locked" or ("Build  " .. Format.cash(cost)), function()
						if reason then
							return
						end
						local ok = ui.act("build", { slot = slot, roomId = def.id }, def.name .. " under construction!")
						if ok then
							ui.close()
						end
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 44) }, (reason or not affordable) and "dark" or "gold")
					if reason or not affordable then
						Kit.setEnabled(b, false)
					end
				end
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "training", name = "Training Rooms", width = 160 },
			{ id = "other", name = "Facilities", width = 130 },
		}, function(id)
			filter = id
			if list then
				render()
			end
		end)
		Kit.label(body, "Slot " .. slot .. "  •  Balance: " .. Format.cash(State.data.cash), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(300, 22), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.muted, TextSize = 14 })
		list = Kit.scroll(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		Kit.list(list, 8)
		select("training")
		return render
	end,
}
