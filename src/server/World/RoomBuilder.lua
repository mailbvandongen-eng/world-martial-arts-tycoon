-- Builds the 3D model of one room (or a construction site) on a plot.
-- Rooms have their own size per type and grow with every level (Layout.roomSize).
-- Equipment is placed on the room's training stations (Stations.lua), so each
-- bag, mat, machine or dohyo spot is where a student actually trains.
-- Visual upgrades per level:
--   1 floor, walls, sign, centrepiece, equipment for the room's capacity
--   2 +wall trim, bigger room, more equipment
--   3 +ceiling light strips
--   4 +floor border, accent banners
--   5 +gold trim, glowing sign, trophy case
-- Premium equipment passes change finishes (gold ring, diamond octagon, ...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Modules.Layout)
local Rooms = require(Shared.Config.Rooms)
local Disciplines = require(Shared.Config.Disciplines)
local Stations = require(Shared.Modules.Stations)
local Props = require(script.Parent.Props)

local RoomBuilder = {}

-- Size of the room being built (set at the start of every build call).
local W, D, H = Layout.CELL_W, Layout.CELL_D, Layout.WALL_H
local rad = math.rad

local function col(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local materialCache = {}
local function material(name)
	if materialCache[name] then
		return materialCache[name]
	end
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	local result = ok and m or Enum.Material.SmoothPlastic
	materialCache[name] = result
	return result
end
RoomBuilder.material = material

local function part(parent, size, cf, color, mat, name)
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = typeof(color) == "Color3" and color or col(color)
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
RoomBuilder.part = part

local function shade(c, f)
	return { math.floor(math.min(255, c[1] * f)), math.floor(math.min(255, c[2] * f)), math.floor(math.min(255, c[3] * f)) }
end

-- Floor patterns
local function buildFloor(model, origin, style, finish)
	local floorColor = style.floorColor
	if finish == "platinum" then
		floorColor = { 225, 228, 235 }
	end
	local kind = style.floor
	local base = part(model, Vector3.new(W, 0.4, D), origin * CFrame.new(0, 0.2, 0), floorColor, material("SmoothPlastic"), "Floor")
	if kind == "tatami" or kind == "tatami_large" then
		base.Material = Enum.Material.Fabric
		local tileW, tileD = kind == "tatami" and 4.5 or 6.8, kind == "tatami" and 6 or 5.8
		local border = kind == "tatami_large" and { 200, 40, 40 } or shade(floorColor, 0.6)
		if finish == "premium" or finish == "platinum" then
			border = { 212, 175, 55 }
		end
		-- tile seams
		local x = -W / 2 + tileW
		while x < W / 2 - 0.5 do
			part(model, Vector3.new(0.12, 0.05, D - 0.4), origin * CFrame.new(x, 0.43, 0), shade(floorColor, 0.75), Enum.Material.Fabric, "Seam")
			x = x + tileW
		end
		local z = -D / 2 + tileD
		while z < D / 2 - 0.5 do
			part(model, Vector3.new(W - 0.4, 0.05, 0.12), origin * CFrame.new(0, 0.43, z), shade(floorColor, 0.75), Enum.Material.Fabric, "Seam")
			z = z + tileD
		end
		-- border
		part(model, Vector3.new(W, 0.06, 0.8), origin * CFrame.new(0, 0.43, -D / 2 + 0.4), border, Enum.Material.Fabric, "Border")
		part(model, Vector3.new(W, 0.06, 0.8), origin * CFrame.new(0, 0.43, D / 2 - 0.4), border, Enum.Material.Fabric, "Border")
		part(model, Vector3.new(0.8, 0.06, D), origin * CFrame.new(-W / 2 + 0.4, 0.43, 0), border, Enum.Material.Fabric, "Border")
		part(model, Vector3.new(0.8, 0.06, D), origin * CFrame.new(W / 2 - 0.4, 0.43, 0), border, Enum.Material.Fabric, "Border")
	elseif kind == "rubber" then
		base.Material = material("Rubber")
	elseif kind == "canvas" then
		base.Material = Enum.Material.Fabric
	elseif kind == "puzzle_mat" then
		base.Material = Enum.Material.Fabric
		for i = 0, 6 do
			if i % 2 == 1 then
				part(model, Vector3.new(4, 0.05, D - 0.2), origin * CFrame.new(-W / 2 + 2 + i * 4, 0.43, 0), style.floorColor2 or { 200, 40, 50 }, Enum.Material.Fabric, "Stripe")
			end
		end
	elseif kind == "mat" then
		base.Material = Enum.Material.Fabric
		part(model, Vector3.new(W - 3, 0.05, D - 3), origin * CFrame.new(0, 0.43, 0), shade(floorColor, 1.4), Enum.Material.Fabric, "Inner")
		part(model, Vector3.new(W - 4, 0.06, D - 4), origin * CFrame.new(0, 0.44, 0), floorColor, Enum.Material.Fabric, "InnerMat")
		part(model, Vector3.new(W, 0.05, 1), origin * CFrame.new(0, 0.43, -D / 2 + 0.5), style.floorColor2 or { 40, 160, 80 }, Enum.Material.Fabric, "Accent")
	elseif kind == "wrestling_mat" then
		base.Material = Enum.Material.Fabric
		local circle = Instance.new("Part")
		circle.Shape = Enum.PartType.Cylinder
		circle.Anchored = true
		circle.Size = Vector3.new(0.08, 18, 18)
		circle.CFrame = origin * CFrame.new(0, 0.44, -1) * CFrame.Angles(0, 0, rad(90))
		circle.Color = col(style.floorColor2 or { 240, 240, 240 })
		circle.Material = Enum.Material.Fabric
		circle.Parent = model
		local inner = circle:Clone()
		inner.Size = Vector3.new(0.1, 16.5, 16.5)
		inner.Color = col(floorColor)
		inner.Parent = model
	elseif kind == "dohyo" or kind == "wood" then
		base.Material = Enum.Material.WoodPlanks
	elseif kind == "marble" then
		base.Material = Enum.Material.Marble
	elseif kind == "tiles" then
		base.Material = material("CeramicTiles")
	end
	return base
end

local function finishFor(roomDef, passes)
	local disc = roomDef.discipline
	if disc == "boxing" and passes.golden_ring then
		return "gold"
	elseif disc == "mma" and passes.diamond_octagon then
		return "diamond"
	elseif disc == "karate" and passes.premium_dojo then
		return "premium"
	elseif disc == "sumo" and passes.luxury_sumo then
		return "luxury"
	elseif disc == "judo" and passes.platinum_judo then
		return "platinum"
	elseif passes.carbon_equipment then
		return "carbon"
	end
	return nil
end

local function buildWalls(model, origin, style, level, accent, finish)
	local wallColor = style.wallColor
	local mat = material(style.wallMaterial or "SmoothPlastic")
	if finish == "premium" then
		wallColor = { 120, 40, 30 }
		mat = Enum.Material.Wood
	end
	local t = 1
	part(model, Vector3.new(W, H, t), origin * CFrame.new(0, H / 2, D / 2 - t / 2), wallColor, mat, "WallBack")
	part(model, Vector3.new(t, H, D), origin * CFrame.new(-W / 2 + t / 2, H / 2, 0), wallColor, mat, "WallLeft")
	part(model, Vector3.new(t, H, D), origin * CFrame.new(W / 2 - t / 2, H / 2, 0), wallColor, mat, "WallRight")
	-- front wall with a door gap of 6
	local seg = (W - 6) / 2
	part(model, Vector3.new(seg, H, t), origin * CFrame.new(-W / 2 + seg / 2, H / 2, -D / 2 + t / 2), wallColor, mat, "WallFrontL")
	part(model, Vector3.new(seg, H, t), origin * CFrame.new(W / 2 - seg / 2, H / 2, -D / 2 + t / 2), wallColor, mat, "WallFrontR")
	part(model, Vector3.new(6, H - 8, t), origin * CFrame.new(0, 8 + (H - 8) / 2, -D / 2 + t / 2), wallColor, mat, "Lintel")
	-- windows in the front wall so the room is visible from the corridor
	for _, sx in ipairs({ -1, 1 }) do
		local win = part(model, Vector3.new(seg - 3, 4, t + 0.1), origin * CFrame.new(sx * (3 + seg / 2), 5, -D / 2 + t / 2), { 190, 220, 235 }, Enum.Material.Glass, "Window")
		win.Transparency = 0.55
	end
	local trimColor = level >= 5 and { 212, 175, 55 } or style.trimColor
	local trimMat = level >= 5 and Enum.Material.Metal or Enum.Material.SmoothPlastic
	if level >= 2 then
		part(model, Vector3.new(W + 0.2, 0.6, 1.2), origin * CFrame.new(0, H + 0.3, D / 2 - 0.5), trimColor, trimMat, "Trim")
		part(model, Vector3.new(1.2, 0.6, D + 0.2), origin * CFrame.new(-W / 2 + 0.5, H + 0.3, 0), trimColor, trimMat, "Trim")
		part(model, Vector3.new(1.2, 0.6, D + 0.2), origin * CFrame.new(W / 2 - 0.5, H + 0.3, 0), trimColor, trimMat, "Trim")
		part(model, Vector3.new(W + 0.2, 0.6, 1.2), origin * CFrame.new(0, H + 0.3, -D / 2 + 0.5), trimColor, trimMat, "Trim")
		-- skirting
		part(model, Vector3.new(W - 2, 0.8, 0.2), origin * CFrame.new(0, 0.8, D / 2 - 1.1), trimColor, trimMat, "Skirting")
	end
	if level >= 3 then
		-- wall-mounted light bars (no ceiling beams: the camera looks in from above)
		for _, sx in ipairs({ -1, 1 }) do
			local bar = part(model, Vector3.new(0.3, 0.4, D - 6), origin * CFrame.new(sx * (W / 2 - 1.2), H - 1.5, 1), { 255, 248, 230 }, Enum.Material.Neon, "WallLight")
			local light = Instance.new("SurfaceLight")
			light.Face = sx > 0 and Enum.NormalId.Left or Enum.NormalId.Right
			light.Range = 16
			light.Brightness = 1.1
			light.Angle = 120
			light.Parent = bar
			bar.CastShadow = false
		end
	end
	if level >= 4 then
		part(model, Vector3.new(W - 2, 0.07, 0.6), origin * CFrame.new(0, 0.44, -D / 2 + 1.6), accent, Enum.Material.Fabric, "FloorAccent")
		for _, x in ipairs({ -6, 6 }) do
			Props.build("banner", model, origin * CFrame.new(x, 0, D / 2 - 0.8), { accent = accent })
		end
	end
end

local function buildSign(model, origin, text, accent, level)
	local sign = part(model, Vector3.new(14, 2.4, 0.4), origin * CFrame.new(0, H - 1.4, -D / 2 - 0.3), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "Sign")
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 36
	sg.LightInfluence = level >= 5 and 0 or 0.4
	sg.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.72, 0)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = col(accent)
	label.Parent = sg
	local stars = label:Clone()
	stars.Size = UDim2.new(1, 0, 0.28, 0)
	stars.Position = UDim2.new(0, 0, 0.72, 0)
	stars.Text = string.rep("★", level) .. string.rep("☆", Rooms.MAX_LEVEL - level)
	stars.TextColor3 = Color3.fromRGB(212, 175, 55)
	stars.Parent = sg
	part(model, Vector3.new(14.4, 0.2, 0.6), origin * CFrame.new(0, H - 2.7, -D / 2 - 0.3), accent, level >= 5 and Enum.Material.Neon or Enum.Material.SmoothPlastic, "SignBar")
end

local function addPrompt(model, origin, actionText, objectText, attrs)
	local anchor = part(model, Vector3.new(1, 1, 1), origin * CFrame.new(0, 3, -D / 2 - 1.5), { 0, 0, 0 }, Enum.Material.SmoothPlastic, "PromptAnchor")
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	for k, v in pairs(attrs) do
		prompt:SetAttribute(k, v)
	end
	prompt.Parent = anchor
	return prompt
end

-- opts: { plotIndex, passes = {key=true}, now }
function RoomBuilder.build(parent, plotCF, slot, room, opts)
	local def = Rooms.byId[room.id]
	local rect = Layout.roomRect(slot, def, room.level)
	W, D = rect.w, rect.d
	local origin = plotCF * CFrame.new(rect.cx, 0, rect.z0 + D / 2)
	local style = Rooms.style(room.id)
	local disc = def.discipline and Disciplines.byId[def.discipline]
	local accent = disc and disc.accent or def.color
	local model = Instance.new("Model")
	model.Name = "Room" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("RoomId", room.id)
	model:SetAttribute("Level", room.level)
	model:SetAttribute("Plot", opts.plotIndex)

	if room.buildEnd and room.buildEnd > opts.now then
		RoomBuilder.buildConstruction(model, origin, def, room, accent)
		model.Parent = parent
		return model
	end

	local finish = finishFor(def, opts.passes or {})
	buildFloor(model, origin, style, finish)
	buildWalls(model, origin, style, room.level, accent, finish)
	buildSign(model, origin, style.sign or def.name, accent, room.level)

	-- equipment on the training stations
	local info = Stations.forRoom(room.id, room.level)
	local propOpts = { accent = accent, finish = finish, glyph = disc and string.sub(disc.name, 1, 1) or nil }
	local function at(x, z, face)
		-- room-local (x, z from the front wall) -> CFrame; face = where the prop's front points
		return origin * CFrame.new(x, 0, z - D / 2) * CFrame.Angles(0, rad((face or 0) + 180), 0)
	end
	local count = #info.stations
	if def.kind == "training" or def.kind == "coaching" or def.kind == "vip" then
		count = math.min(count, opts.capacity or count)
	end
	for i = 1, count do
		local st = info.stations[i]
		if st.prop then
			Props.build(st.prop, model, at(st.propX, st.propZ, st.propFace), propOpts)
		end
	end
	local extras = info.extras
	if extras.centre then
		Props.build(extras.centre.prop, model, at(extras.centre.x, extras.centre.z, 180), propOpts)
	end
	if extras.counters then
		for _, x in ipairs(extras.counters.xs) do
			Props.build(extras.counters.prop, model, at(x, extras.counters.z, 180), propOpts)
		end
	end
	for _, item in ipairs(extras.decor or {}) do
		if item == "kamiza_back" then
			Props.build("kamiza", model, at(0, D - 1, 180), propOpts)
		elseif item == "belt_display" and room.level >= 2 then
			Props.build("belt_display", model, at(-(W / 2 - 5), D - 0.8, 180), propOpts)
		elseif item == "mirror_wall" then
			Props.build("mirror", model, at(W / 2 - 5.5, D - 0.7, 180), propOpts)
		end
	end
	if room.level >= 5 then
		Props.build("trophy_case", model, at(W / 2 - 1.6, D - 3, 270), {})
	end
	if (opts.passes or {}).gym_lighting then
		for _, x in ipairs({ -9, 9 }) do
			local lamp = part(model, Vector3.new(1, 1, 1), origin * CFrame.new(x, H - 1, 6), { 30, 30, 30 }, Enum.Material.Metal, "DiscoLamp")
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 70
			spot.Range = 20
			spot.Brightness = 2.5
			spot.Color = col(accent)
			spot.Parent = lamp
			lamp:SetAttribute("Disco", true)
		end
	end

	local kindText = def.kind == "training" and "Manage Class" or "Manage"
	addPrompt(model, origin, kindText, def.name, { Plot = opts.plotIndex, Slot = slot, Kind = "room" })
	model.Parent = parent
	return model
end

function RoomBuilder.buildConstruction(model, origin, def, room, accent)
	local floor = part(model, Vector3.new(W, 0.3, D), origin * CFrame.new(0, 0.15, 0), { 80, 140, 220 }, Enum.Material.SmoothPlastic, "Blueprint")
	floor.Transparency = 0.35
	-- grid lines
	for x = -W / 2 + 4, W / 2 - 4, 4 do
		part(model, Vector3.new(0.1, 0.05, D), origin * CFrame.new(x, 0.32, 0), { 220, 235, 255 }, Enum.Material.Neon, "Grid")
	end
	-- scaffolding
	for _, sx in ipairs({ -1, 0, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(model, Vector3.new(0.4, H, 0.4), origin * CFrame.new(sx * (W / 2 - 1), H / 2, sz * (D / 2 - 1)), { 200, 160, 40 }, Enum.Material.Metal, "Pole")
		end
	end
	for _, y in ipairs({ 4, 8 }) do
		part(model, Vector3.new(W - 1, 0.3, 1.6), origin * CFrame.new(0, y, D / 2 - 1), { 150, 110, 60 }, Enum.Material.WoodPlanks, "Plank")
		part(model, Vector3.new(W - 1, 0.3, 1.6), origin * CFrame.new(0, y, -D / 2 + 1), { 150, 110, 60 }, Enum.Material.WoodPlanks, "Plank")
	end
	-- half-built walls in the room style
	part(model, Vector3.new(W - 2, H * 0.4, 0.8), origin * CFrame.new(0, H * 0.2, D / 2 - 0.5), { 170, 170, 170 }, Enum.Material.Concrete, "Rising")
	local stack = part(model, Vector3.new(3, 2, 3), origin * CFrame.new(-6, 1, 0), { 150, 70, 50 }, Enum.Material.Brick, "Bricks")
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
	sparks.LightEmission = 1
	sparks.Rate = 20
	sparks.Speed = NumberRange.new(4, 8)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Size = NumberSequence.new(0.15)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Parent = stack
	-- progress board (client animates it from the BuildStart/BuildEnd attributes)
	local board = part(model, Vector3.new(1, 1, 1), origin * CFrame.new(0, H + 3, 0), { 0, 0, 0 }, Enum.Material.SmoothPlastic, "ProgressAnchor")
	board.Transparency = 1
	board.CanCollide = false
	model:SetAttribute("BuildEnd", room.buildEnd)
	model:SetAttribute("BuildStart", room.buildStart or (room.buildEnd - 10))
	model:SetAttribute("Constructing", true)
	model:SetAttribute("Accent", Color3.fromRGB(accent[1], accent[2], accent[3]))
	addPrompt(model, origin, "Under Construction", def.name, { Plot = model:GetAttribute("Plot") or 0, Slot = model:GetAttribute("Slot"), Kind = "construction" })
end

-- Empty slot: build pad with a prompt.
function RoomBuilder.buildEmpty(parent, plotCF, slot, plotIndex, locked)
	local s = Layout.slot(slot)
	W, D = Layout.CELL_W - 4, Layout.CELL_D - 4
	local origin = plotCF * CFrame.new(s.cx, 0, s.z0 + Layout.CELL_D / 2)
	local model = Instance.new("Model")
	model.Name = "Empty" .. slot
	model:SetAttribute("Slot", slot)
	local color = locked and { 90, 90, 95 } or { 212, 175, 55 }
	local pad = part(model, Vector3.new(W - 2, 0.2, D - 2), origin * CFrame.new(0, 0.1, 0), { 50, 50, 55 }, Enum.Material.Concrete, "Pad")
	pad.Transparency = 0.2
	for _, e in ipairs({ { W - 2, 0.3, 0.3, 0, -(D / 2 - 1) }, { W - 2, 0.3, 0.3, 0, D / 2 - 1 }, { 0.3, 0.3, D - 2, -(W / 2 - 1), 0 }, { 0.3, 0.3, D - 2, W / 2 - 1, 0 } }) do
		part(model, Vector3.new(e[1], e[2], e[3]), origin * CFrame.new(e[4], 0.25, e[5]), color, locked and Enum.Material.SmoothPlastic or Enum.Material.Neon, "Edge")
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.Parent = pad
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = locked and "🔒 LOCKED SLOT" or "+ BUILD"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = col(color)
	label.TextTransparency = 0.3
	label.Rotation = 180
	label.Parent = sg
	if not locked then
		addPrompt(model, origin, "Build Room", "Empty Slot " .. slot, { Plot = plotIndex, Slot = slot, Kind = "build" })
	end
	model.Parent = parent
	return model
end

return RoomBuilder
