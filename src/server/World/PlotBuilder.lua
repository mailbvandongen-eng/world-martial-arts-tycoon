-- Builds a player's plot: ground and paths in the style of the active city,
-- perimeter facade, entrance gate with the academy name, reception (desk,
-- register pad), the city's architecture around the plot and decorations.
-- Rooms are built separately by RoomBuilder (PlotService rebuilds them on change).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Modules.Layout)
local Cities = require(Shared.Config.Cities)
local Cosmetics = require(Shared.Config.Cosmetics)
local Props = require(script.Parent.Props)
local RoomBuilder = require(script.Parent.RoomBuilder)

local PlotBuilder = {}

local part = RoomBuilder.part
local material = RoomBuilder.material
local rad = math.rad

local function col(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

function PlotBuilder.plotCFrame(index)
	local o = Layout.plotOrigin(index)
	return CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, rad(o.yaw), 0)
end

local function textOn(p, face, text, color, ppS)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = ppS or 30
	sg.LightInfluence = 0
	sg.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = col(color)
	label.Parent = sg
	return label
end

-- Ground, paths, perimeter. Rebuilt when the city changes.
function PlotBuilder.buildBase(parent, index, cityId, ownerName)
	local city = Cities.byId[cityId] or Cities.list[1]
	local th = city.theme
	local cf = PlotBuilder.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Base"
	local ground = part(model, Vector3.new(Layout.WIDTH, 1, Layout.DEPTH), cf * CFrame.new(0, -0.5, 0), th.ground, material(th.groundMaterial), "Ground")
	ground:SetAttribute("PlotGround", index)
	-- paths: entrance, central corridor and the walkways in front of each room row
	local pathColor = th.street
	part(model, Vector3.new(16, 0.1, Layout.DEPTH - 24), cf * CFrame.new(0, 0.05, Layout.FRONT + 24 + (Layout.DEPTH - 24) / 2 - 12), pathColor, Enum.Material.Pavement, "Corridor")
	for row = 1, Layout.ROWS do
		local s = Layout.slot((row - 1) * 4 + 1)
		part(model, Vector3.new(Layout.WIDTH - 12, 0.1, Layout.WALKWAY), cf * CFrame.new(0, 0.06, s.walkZ), pathColor, Enum.Material.Pavement, "Walkway")
	end
	-- perimeter facade (city architecture colour), entrance gap of 16
	local wallH = 5
	local bc = th.building
	local half = Layout.WIDTH / 2
	part(model, Vector3.new(Layout.WIDTH, wallH, 1.5), cf * CFrame.new(0, wallH / 2, Layout.DEPTH / 2 - 0.75), bc, Enum.Material.Brick, "PerimeterBack")
	part(model, Vector3.new(1.5, wallH, Layout.DEPTH), cf * CFrame.new(-half + 0.75, wallH / 2, 0), bc, Enum.Material.Brick, "PerimeterL")
	part(model, Vector3.new(1.5, wallH, Layout.DEPTH), cf * CFrame.new(half - 0.75, wallH / 2, 0), bc, Enum.Material.Brick, "PerimeterR")
	local seg = (Layout.WIDTH - 16) / 2
	part(model, Vector3.new(seg, wallH, 1.5), cf * CFrame.new(-half + seg / 2, wallH / 2, Layout.FRONT + 0.75), bc, Enum.Material.Brick, "PerimeterFL")
	part(model, Vector3.new(seg, wallH, 1.5), cf * CFrame.new(half - seg / 2, wallH / 2, Layout.FRONT + 0.75), bc, Enum.Material.Brick, "PerimeterFR")
	-- coping in the roof colour
	part(model, Vector3.new(Layout.WIDTH, 0.5, 2), cf * CFrame.new(0, wallH + 0.25, Layout.DEPTH / 2 - 0.75), th.roof, Enum.Material.Slate, "Coping")

	-- entrance gate with academy name
	local gateH = 16
	part(model, Vector3.new(2.5, gateH, 2.5), cf * CFrame.new(-9.5, gateH / 2, Layout.FRONT), th.accent, Enum.Material.SmoothPlastic, "GatePostL")
	part(model, Vector3.new(2.5, gateH, 2.5), cf * CFrame.new(9.5, gateH / 2, Layout.FRONT), th.accent, Enum.Material.SmoothPlastic, "GatePostR")
	local beam = part(model, Vector3.new(24, 4, 2), cf * CFrame.new(0, gateH + 1.5, Layout.FRONT) * CFrame.Angles(0, rad(180), 0), { 25, 25, 28 }, Enum.Material.SmoothPlastic, "GateSign")
	local title = ownerName and (ownerName .. "'s Academy") or "FREE ACADEMY"
	textOn(beam, Enum.NormalId.Front, title, { 212, 175, 55 }, 24).Name = "Title"
	textOn(beam, Enum.NormalId.Back, title, { 212, 175, 55 }, 24)
	local sub = part(model, Vector3.new(14, 1.6, 0.5), cf * CFrame.new(0, gateH - 1.4, Layout.FRONT - 1.3), th.accent, Enum.Material.SmoothPlastic, "CitySign")
	textOn(sub, Enum.NormalId.Front, string.upper(city.name), { 255, 255, 255 }, 24)
	model.Parent = parent
	return model
end

-- City architecture around the plot (outside the playable area).
function PlotBuilder.buildSurroundings(parent, index, cityId)
	local city = Cities.byId[cityId] or Cities.list[1]
	local th = city.theme
	local cf = PlotBuilder.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Surroundings"
	local props = th.props
	local opts = { building = th.building, roof = th.roof, accent = th.accent }
	-- backdrop behind the plot
	local n = 0
	for x = -60, 60, 30 do
		n = n + 1
		local key = props[(n - 1) % #props + 1]
		local o = { building = th.building, roof = th.roof, accent = th.accent, variant = n }
		Props.build(key, model, cf * CFrame.new(x, 0, Layout.DEPTH / 2 + 14), o)
	end
	-- small props on the side margins inside the perimeter
	for z = -60, 80, 35 do
		Props.build("lamp", model, cf * CFrame.new(-Layout.WIDTH / 2 + 4, 0, z), opts)
		Props.build("lamp", model, cf * CFrame.new(Layout.WIDTH / 2 - 4, 0, z), opts)
	end
	-- signature props flanking the entrance
	local sig = props[1]
	if sig == "torii" or sig == "thai_temple" or sig == "neon_sign" or sig == "golden_gate" then
		Props.build(sig == "thai_temple" and "palm" or sig, model, cf * CFrame.new(0, 0, Layout.FRONT - 14), opts)
	end
	for _, side in ipairs({ -1, 1 }) do
		local key = props[#props] == "lamp" and props[#props - 1] or props[#props]
		if key == "house" or key == "canal_house" or key == "skyscraper" or key == "glass_tower" or key == "warehouse" or key == "casino" or key == "brick_house" or key == "hanok" or key == "pagoda" or key == "tower" or key == "thai_temple" then
			key = "tree"
		end
		Props.build(key, model, cf * CFrame.new(side * 24, 0, Layout.FRONT - 6), opts)
	end
	model.Parent = parent
	return model
end

-- Reception: desk, register pad, lounge.
function PlotBuilder.buildReception(parent, index, cityId, level, passes)
	local cf = PlotBuilder.plotCFrame(index)
	local r = Layout.RECEPTION
	local model = Instance.new("Model")
	model.Name = "Reception"
	local w, dpt = r.x1 - r.x0, r.z1 - r.z0
	local centre = cf * CFrame.new((r.x0 + r.x1) / 2, 0, (r.z0 + r.z1) / 2)
	part(model, Vector3.new(w, 0.4, dpt), centre * CFrame.new(0, 0.2, 0), { 225, 220, 210 }, Enum.Material.Marble, "Floor")
	part(model, Vector3.new(w - 4, 0.06, 2), centre * CFrame.new(0, 0.43, -dpt / 2 + 2), { 150, 30, 30 }, Enum.Material.Fabric, "Carpet")
	part(model, Vector3.new(6, 0.06, dpt - 4), centre * CFrame.new(0, 0.43, 0), { 150, 30, 30 }, Enum.Material.Fabric, "Carpet")
	local wallC = { 40, 38, 36 }
	part(model, Vector3.new(1, 10, dpt), centre * CFrame.new(-w / 2 + 0.5, 5, 0), wallC, Enum.Material.SmoothPlastic, "WallL")
	part(model, Vector3.new(1, 10, dpt), centre * CFrame.new(w / 2 - 0.5, 5, 0), wallC, Enum.Material.SmoothPlastic, "WallR")
	local backSeg = (w - 16) / 2
	part(model, Vector3.new(backSeg, 10, 1), centre * CFrame.new(-w / 2 + backSeg / 2, 5, dpt / 2 - 0.5), wallC, Enum.Material.SmoothPlastic, "WallBL")
	part(model, Vector3.new(backSeg, 10, 1), centre * CFrame.new(w / 2 - backSeg / 2, 5, dpt / 2 - 0.5), wallC, Enum.Material.SmoothPlastic, "WallBR")
	part(model, Vector3.new(w + 0.4, 0.6, 1.4), centre * CFrame.new(0, 10.3, dpt / 2 - 0.5), { 212, 175, 55 }, Enum.Material.Metal, "Trim")

	-- desk (faces the entrance) and lounge
	local desk = cf * CFrame.new(Layout.desk.x, 0, Layout.desk.z)
	Props.build("desk", model, desk, { label = "WELCOME" })
	Props.build("plant", model, cf * CFrame.new(r.x0 + 3, 0, r.z0 + 3), {})
	Props.build("plant", model, cf * CFrame.new(r.x1 - 3, 0, r.z0 + 3), {})
	Props.build("sofa", model, cf * CFrame.new(r.x1 - 6, 0, r.z1 - 4), {})
	if level >= 2 then
		Props.build("trophy_case", model, cf * CFrame.new(r.x0 + 3, 0, r.z1 - 4) * CFrame.Angles(0, rad(-90), 0), {})
	end
	if level >= 3 then
		Props.build("chandelier", model, cf * CFrame.new(0, 0, (r.z0 + r.z1) / 2), {})
	end
	if level >= 4 then
		Props.build("fountain", model, cf * CFrame.new(r.x1 - 8, 0, r.z0 + 8), {})
	end
	if passes and passes.premium_decor then
		Props.build("statue", model, cf * CFrame.new(r.x0 + 6, 0, r.z0 + 5), { label = "LEGEND" })
	end
	-- register pad
	local pad = part(model, Vector3.new(5, 0.3, 5), cf * CFrame.new(Layout.register.x, 0.5, Layout.register.z), { 212, 175, 55 }, Enum.Material.Neon, "RegisterPad")
	pad.Transparency = 0.25
	local stack = part(model, Vector3.new(2.4, 0.4, 1.4), cf * CFrame.new(Layout.register.x, 1, Layout.register.z), { 80, 170, 80 }, Enum.Material.SmoothPlastic, "CashStack")
	stack:SetAttribute("BaseY", stack.Position.Y)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Register"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("Plot", index)
	prompt:SetAttribute("Kind", "register")
	prompt.Parent = pad
	local bb = Instance.new("BillboardGui")
	bb.Name = "RegisterLabel"
	bb.Size = UDim2.fromScale(7, 1.8)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 80
	bb.AlwaysOnTop = false
	bb.Parent = pad
	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "$0"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(120, 230, 120)
	label.TextStrokeTransparency = 0.4
	label.Parent = bb
	model.Parent = parent
	return model, pad
end

-- Claim gate for an unowned plot.
function PlotBuilder.buildClaim(parent, index)
	local cf = PlotBuilder.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Claim"
	local pad = part(model, Vector3.new(14, 0.4, 8), cf * CFrame.new(0, 0.3, Layout.FRONT - 6), { 212, 175, 55 }, Enum.Material.Neon, "ClaimPad")
	pad.Transparency = 0.3
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim Academy"
	prompt.ObjectText = "Free plot #" .. index
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Plot", index)
	prompt:SetAttribute("Kind", "claim")
	prompt.Parent = pad
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(16, 2.6)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.MaxDistance = 250
	bb.Parent = pad
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "★ CLAIM THIS ACADEMY ★"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(212, 175, 55)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	model.Parent = parent
	return model
end

-- Decorations from cosmetics, on four fixed spots in front of the plot.
local DECO_SPOTS = { { -30, Layout.FRONT - 10 }, { 30, Layout.FRONT - 10 }, { -50, Layout.FRONT - 10 }, { 50, Layout.FRONT - 10 } }
function PlotBuilder.buildDecorations(parent, index, decoIds, ownerName)
	local cf = PlotBuilder.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Decorations"
	for i, id in ipairs(decoIds or {}) do
		local c = Cosmetics.byId[id]
		local spot = DECO_SPOTS[i]
		if c and c.model and spot then
			Props.build(c.model, model, cf * CFrame.new(spot[1], 0, spot[2]), { label = ownerName })
		end
	end
	model.Parent = parent
	return model
end

return PlotBuilder
