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

-- Architecture per city: the academy building itself changes with every city
-- (facade material and height, hall floor, entrance gate), not only the colour.
local ARCH = {
	smalltown = { wall = "Brick", hall = "WoodPlanks", hallColor = { 150, 112, 72 }, gate = "classic", height = 7 },
	amsterdam = { wall = "Brick", hall = "Concrete", hallColor = { 196, 196, 200 }, gate = "gabled", height = 9 },
	rotterdam = { wall = "CorrodedMetal", hall = "DiamondPlate", hallColor = { 125, 125, 130 }, gate = "industrial", height = 10 },
	london = { wall = "Brick", hall = "Marble", hallColor = { 226, 220, 208 }, gate = "arch", height = 10 },
	tokyo = { wall = "WoodPlanks", hall = "WoodPlanks", hallColor = { 176, 136, 90 }, gate = "torii", height = 9 },
	bangkok = { wall = "SmoothPlastic", hall = "WoodPlanks", hallColor = { 150, 96, 54 }, gate = "thai", height = 9 },
	seoul = { wall = "SmoothPlastic", hall = "WoodPlanks", hallColor = { 190, 160, 120 }, gate = "hanok", height = 10 },
	newyork = { wall = "Concrete", hall = "Marble", hallColor = { 210, 210, 214 }, gate = "glass", height = 14 },
	dubai = { wall = "Marble", hall = "Marble", hallColor = { 242, 236, 224 }, gate = "gold", height = 14 },
	lasvegas = { wall = "SmoothPlastic", hall = "Marble", hallColor = { 35, 30, 40 }, gate = "neon", height = 13 },
}
PlotBuilder.ARCH = ARCH

local GATE_HALF = 13 -- the entrance is 26 studs wide

local function buildGate(model, cf, city, arch, title)
	local th = city.theme
	local z = Layout.FRONT
	local accent, roof = th.accent, th.roof
	local style = arch.gate
	local gateH = 17
	local beamColor = { 25, 25, 28 }
	if style == "torii" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2.6, 20, 2.6), cf * CFrame.new(sx * GATE_HALF, 10, z), { 210, 50, 40 }, Enum.Material.SmoothPlastic, "ToriiPost")
		end
		part(model, Vector3.new(34, 1.8, 3), cf * CFrame.new(0, 21, z), { 25, 25, 28 }, Enum.Material.SmoothPlastic, "Kasagi")
		part(model, Vector3.new(30, 1.4, 2), cf * CFrame.new(0, 17.5, z), { 210, 50, 40 }, Enum.Material.SmoothPlastic, "Nuki")
		gateH = 15
	elseif style == "thai" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(3, 16, 3), cf * CFrame.new(sx * GATE_HALF, 8, z), { 245, 235, 205 }, Enum.Material.SmoothPlastic, "Pillar")
			part(model, Vector3.new(3.4, 1, 3.4), cf * CFrame.new(sx * GATE_HALF, 16.2, z), { 212, 175, 55 }, Enum.Material.Metal, "PillarCap")
		end
		local w1 = Instance.new("WedgePart")
		w1.Anchored, w1.Size, w1.Color, w1.Material = true, Vector3.new(30, 6, 5), Color3.fromRGB(200, 50, 40), Enum.Material.Slate
		w1.CFrame = cf * CFrame.new(0, 22, z - 2.5)
		w1.Parent = model
		local w2 = w1:Clone()
		w2.CFrame = cf * CFrame.new(0, 22, z + 2.5) * CFrame.Angles(0, math.pi, 0)
		w2.Parent = model
		part(model, Vector3.new(0.8, 6, 0.8), cf * CFrame.new(0, 28, z), { 212, 175, 55 }, Enum.Material.Metal, "Spire")
	elseif style == "hanok" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2.4, 16, 2.4), cf * CFrame.new(sx * GATE_HALF, 8, z), { 120, 70, 40 }, Enum.Material.Wood, "Post")
		end
		part(model, Vector3.new(36, 1.2, 8), cf * CFrame.new(0, 20.5, z) * CFrame.Angles(0, 0, rad(0)), { 50, 55, 65 }, Enum.Material.Slate, "Roof")
		part(model, Vector3.new(38, 0.6, 9), cf * CFrame.new(0, 19.8, z), { 30, 90, 200 }, Enum.Material.SmoothPlastic, "Dancheong")
	elseif style == "glass" then
		local frame = part(model, Vector3.new(30, 22, 1), cf * CFrame.new(0, 11, z - 0.6), { 160, 200, 225 }, Enum.Material.Glass, "GlassFront")
		frame.Transparency = 0.5
		frame.CanCollide = false
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(1.5, 24, 1.5), cf * CFrame.new(sx * 15.5, 12, z), { 60, 60, 66 }, Enum.Material.Metal, "Mullion")
		end
		part(model, Vector3.new(34, 1.2, 4), cf * CFrame.new(0, 24, z), { 60, 60, 66 }, Enum.Material.Metal, "Canopy")
		gateH = 19
	elseif style == "gold" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2.8, 22, 2.8), cf * CFrame.new(sx * GATE_HALF, 11, z), { 212, 175, 55 }, Enum.Material.Metal, "GoldColumn")
		end
		local arch_ = Instance.new("Part")
		arch_.Shape = Enum.PartType.Cylinder
		arch_.Anchored = true
		arch_.Size = Vector3.new(3, 28, 28)
		arch_.CFrame = cf * CFrame.new(0, 21, z) * CFrame.Angles(0, rad(90), 0)
		arch_.Color = Color3.fromRGB(240, 235, 225)
		arch_.Material = Enum.Material.Marble
		arch_.Parent = model
		beamColor = { 30, 26, 20 }
		gateH = 18
	elseif style == "neon" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2, 20, 2), cf * CFrame.new(sx * GATE_HALF, 10, z), { 30, 30, 35 }, Enum.Material.Metal, "Post")
			part(model, Vector3.new(0.6, 20, 0.6), cf * CFrame.new(sx * GATE_HALF, 10, z - 1.2), accent, Enum.Material.Neon, "NeonTube")
		end
		part(model, Vector3.new(30, 0.6, 0.6), cf * CFrame.new(0, 20.5, z - 1.2), { 255, 220, 60 }, Enum.Material.Neon, "NeonBar")
	elseif style == "industrial" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2, 18, 2), cf * CFrame.new(sx * GATE_HALF, 9, z), { 200, 120, 30 }, Enum.Material.DiamondPlate, "Girder")
		end
		part(model, Vector3.new(30, 2, 2), cf * CFrame.new(0, 19, z), { 200, 120, 30 }, Enum.Material.DiamondPlate, "Girder")
		for i = -2, 2 do
			part(model, Vector3.new(0.4, 2, 0.4), cf * CFrame.new(i * 6, 17.5, z), { 70, 70, 75 }, Enum.Material.Metal, "Rivet")
		end
	elseif style == "arch" or style == "gabled" then
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(4, 18, 4), cf * CFrame.new(sx * (GATE_HALF + 1), 9, z), th.building, Enum.Material.Brick, "Tower")
			part(model, Vector3.new(4.6, 1, 4.6), cf * CFrame.new(sx * (GATE_HALF + 1), 18.5, z), { 235, 235, 230 }, Enum.Material.SmoothPlastic, "Cornice")
		end
		if style == "gabled" then
			local w = Instance.new("WedgePart")
			w.Anchored, w.Size, w.Color, w.Material = true, Vector3.new(3, 8, 14), Color3.fromRGB(th.building[1], th.building[2], th.building[3]), Enum.Material.Brick
			w.CFrame = cf * CFrame.new(-7, 23, z) * CFrame.Angles(0, rad(90), 0)
			w.Parent = model
			local w2 = w:Clone()
			w2.CFrame = cf * CFrame.new(7, 23, z) * CFrame.Angles(0, rad(-90), 0)
			w2.Parent = model
		end
	else -- classic
		for _, sx in ipairs({ -1, 1 }) do
			part(model, Vector3.new(2.5, 16, 2.5), cf * CFrame.new(sx * GATE_HALF, 8, z), accent, Enum.Material.SmoothPlastic, "GatePost")
		end
		gateH = 15
	end
	local beam = part(model, Vector3.new(28, 4, 2), cf * CFrame.new(0, gateH + 1.5, z) * CFrame.Angles(0, rad(180), 0), beamColor, Enum.Material.SmoothPlastic, "GateSign")
	textOn(beam, Enum.NormalId.Front, title, { 212, 175, 55 }, 24).Name = "Title"
	textOn(beam, Enum.NormalId.Back, title, { 212, 175, 55 }, 24)
	local sub = part(model, Vector3.new(16, 1.8, 0.5), cf * CFrame.new(0, gateH - 1.6, z - 1.3), accent, Enum.Material.SmoothPlastic, "CitySign")
	textOn(sub, Enum.NormalId.Front, string.upper(city.name), { 255, 255, 255 }, 24)
end

-- Ground, hall, walkways, facade and entrance. Rebuilt when the city changes.
function PlotBuilder.buildBase(parent, index, cityId, ownerName)
	local city = Cities.byId[cityId] or Cities.list[1]
	local th = city.theme
	local arch = ARCH[cityId] or ARCH.smalltown
	local cf = PlotBuilder.plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = "Base"
	local ground = part(model, Vector3.new(Layout.WIDTH, 1, Layout.DEPTH), cf * CFrame.new(0, -0.5, 0), th.ground, material(th.groundMaterial), "Ground")
	ground:SetAttribute("PlotGround", index)
	-- central hall from reception to the back, walkways in front of every room row
	local hallMat = material(arch.hall)
	local hallLen = Layout.DEPTH / 2 - Layout.RECEPTION.z1 - 2
	part(model, Vector3.new(Layout.CORRIDOR, 0.12, hallLen), cf * CFrame.new(0, 0.06, Layout.RECEPTION.z1 + hallLen / 2), arch.hallColor, hallMat, "CentralHall")
	part(model, Vector3.new(1.2, 0.14, hallLen), cf * CFrame.new(0, 0.08, Layout.RECEPTION.z1 + hallLen / 2), th.accent, Enum.Material.SmoothPlastic, "HallStripe")
	for row = 1, Layout.ROWS do
		local s = Layout.slot((row - 1) * 4 + 1)
		part(model, Vector3.new(Layout.WIDTH - 6, 0.1, Layout.WALKWAY), cf * CFrame.new(0, 0.05, s.walkZ), arch.hallColor, hallMat, "Walkway")
		-- hall lighting and plants at every crossing
		for _, sx in ipairs({ -1, 1 }) do
			local lamp = part(model, Vector3.new(0.6, 9, 0.6), cf * CFrame.new(sx * (Layout.CORRIDOR / 2 - 0.6), 4.5, s.walkZ - Layout.WALKWAY / 2 + 0.6), { 40, 40, 45 }, Enum.Material.Metal, "HallLamp")
			local bulb = part(model, Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(sx * (Layout.CORRIDOR / 2 - 0.6), 9.2, s.walkZ - Layout.WALKWAY / 2 + 0.6), { 255, 240, 210 }, Enum.Material.Neon, "HallBulb")
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.9
			light.Color = Color3.fromRGB(255, 236, 205)
			light.Parent = bulb
			lamp.CanCollide = false
		end
	end
	-- facade: material and height follow the city
	local wallH = arch.height
	local bc = th.building
	local wallMat = material(arch.wall)
	local half = Layout.WIDTH / 2
	part(model, Vector3.new(Layout.WIDTH, wallH, 1.5), cf * CFrame.new(0, wallH / 2, Layout.DEPTH / 2 - 0.75), bc, wallMat, "PerimeterBack")
	part(model, Vector3.new(1.5, wallH, Layout.DEPTH), cf * CFrame.new(-half + 0.75, wallH / 2, 0), bc, wallMat, "PerimeterL")
	part(model, Vector3.new(1.5, wallH, Layout.DEPTH), cf * CFrame.new(half - 0.75, wallH / 2, 0), bc, wallMat, "PerimeterR")
	local seg = half - GATE_HALF
	part(model, Vector3.new(seg, wallH, 1.5), cf * CFrame.new(-half + seg / 2, wallH / 2, Layout.FRONT + 0.75), bc, wallMat, "PerimeterFL")
	part(model, Vector3.new(seg, wallH, 1.5), cf * CFrame.new(half - seg / 2, wallH / 2, Layout.FRONT + 0.75), bc, wallMat, "PerimeterFR")
	for _, side in ipairs({ { 0, Layout.DEPTH / 2 - 0.75, Layout.WIDTH, 2 }, { -half + 0.75, 0, 2, Layout.DEPTH }, { half - 0.75, 0, 2, Layout.DEPTH } }) do
		part(model, Vector3.new(side[3], 0.6, side[4]), cf * CFrame.new(side[1], wallH + 0.3, side[2]), th.roof, Enum.Material.Slate, "Coping")
	end
	buildGate(model, cf, city, arch, ownerName and (ownerName .. "'s Academy") or "FREE ACADEMY")
	PlotBuilder.buildCompetitionHall(model, cf, arch, th)
	model.Parent = parent
	return model
end

-- Competition hall (left of the reception): tatami with the 8x8 fighting area,
-- AKA / AO start lines, judges' table, scoreboard frame, stands. The fighters,
-- referee, judges and the live scoreboard text are drawn by the clients
-- (BoutController). The back opens onto the first walkway.
function PlotBuilder.buildCompetitionHall(model, cf, arch, th)
	local c = Layout.COMPETITION
	local w, dpt = c.x1 - c.x0, c.z1 - c.z0
	local mid = cf * CFrame.new((c.x0 + c.x1) / 2, 0, (c.z0 + c.z1) / 2)
	part(model, Vector3.new(w, 0.4, dpt), mid * CFrame.new(0, 0.2, 0), { 168, 128, 84 }, Enum.Material.WoodPlanks, "HallFloor")
	local centre = cf * CFrame.new(c.cx, 0, c.cz)
	part(model, Vector3.new(14, 0.2, 14), centre * CFrame.new(0, 0.5, 0), { 40, 80, 170 }, Enum.Material.Fabric, "TatamiSafety")
	part(model, Vector3.new(10, 0.02, 10), centre * CFrame.new(0, 0.61, 0), { 200, 40, 40 }, Enum.Material.Fabric, "TatamiBorder")
	part(model, Vector3.new(9.2, 0.03, 9.2), centre * CFrame.new(0, 0.625, 0), { 60, 110, 200 }, Enum.Material.Fabric, "TatamiArea")
	part(model, Vector3.new(0.25, 0.04, 1.2), centre * CFrame.new(-2.8, 0.64, 0), { 220, 40, 40 }, Enum.Material.SmoothPlastic, "LineAka")
	part(model, Vector3.new(0.25, 0.04, 1.2), centre * CFrame.new(2.8, 0.64, 0), { 240, 240, 240 }, Enum.Material.SmoothPlastic, "LineAo")
	-- back wall with a wide door onto the walkway
	local wallH = 12
	local seg = (w - c.door) / 2
	local wallC = { 40, 38, 36 }
	part(model, Vector3.new(seg, wallH, 1), cf * CFrame.new(c.x0 + seg / 2, wallH / 2, c.z1 - 0.5), wallC, Enum.Material.SmoothPlastic, "HallWallBL")
	part(model, Vector3.new(seg, wallH, 1), cf * CFrame.new(c.x1 - seg / 2, wallH / 2, c.z1 - 0.5), wallC, Enum.Material.SmoothPlastic, "HallWallBR")
	part(model, Vector3.new(c.door, 2, 1), cf * CFrame.new(c.cx, wallH - 1, c.z1 - 0.5), wallC, Enum.Material.SmoothPlastic, "HallLintel")
	local sign = part(model, Vector3.new(c.door + 4, 2.4, 0.3), cf * CFrame.new(c.cx, wallH - 1, c.z1 + 0.2), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "HallSign")
	textOn(sign, Enum.NormalId.Back, "🥋 COMPETITION HALL", { 212, 175, 55 }, 30)
	-- scoreboard frame on the front wall (the client draws the live score on it)
	local board = part(model, Vector3.new(16, 6.5, 0.4), cf * CFrame.new(c.cx, 8, c.z0 + 0.4), { 15, 15, 18 }, Enum.Material.SmoothPlastic, "ScoreboardFrame")
	board:SetAttribute("Scoreboard", true)
	part(model, Vector3.new(16.6, 0.3, 0.6), cf * CFrame.new(c.cx, 11.4, c.z0 + 0.4), { 212, 175, 55 }, Enum.Material.Metal, "ScoreboardTrim")
	-- judges' table on the left (judges face the mat)
	part(model, Vector3.new(1.6, 2.6, 11), cf * CFrame.new(c.x0 + 7.2, 1.3, c.cz), { 30, 28, 26 }, Enum.Material.Wood, "JudgesTable")
	part(model, Vector3.new(1.8, 0.2, 11.2), cf * CFrame.new(c.x0 + 7.2, 2.65, c.cz), { 212, 175, 55 }, Enum.Material.Metal, "JudgesTableTop")
	for i = -2, 2 do
		part(model, Vector3.new(1.4, 1.6, 1.4), cf * CFrame.new(c.x0 + 5.2, 1.2, c.cz + i * 2.2), { 50, 50, 56 }, Enum.Material.Fabric, "JudgeChair")
	end
	-- stands for spectators along the reception wall
	for _, dz in ipairs({ -7, 7 }) do
		Props.build("bleachers", model, cf * CFrame.new(c.x1 - 9, 0.4, c.cz + dz) * CFrame.Angles(0, rad(90), 0), { crowd = { { 200, 60, 60 }, { 240, 240, 240 }, { 60, 110, 200 } } })
	end
	-- banners, lights and benches for the waiting fighters
	Props.build("banner", model, cf * CFrame.new(c.cx - 12, 0.4, c.z0 + 1), { accent = { 200, 40, 40 }, glyph = "AKA" })
	Props.build("banner", model, cf * CFrame.new(c.cx + 12, 0.4, c.z0 + 1), { accent = { 60, 110, 200 }, glyph = "AO" })
	Props.build("spotlight", model, cf * CFrame.new(c.cx - 9, 0.4, c.z1 - 4) * CFrame.Angles(0, rad(180), 0), { accent = { 255, 235, 200 } })
	Props.build("spotlight", model, cf * CFrame.new(c.cx + 9, 0.4, c.z1 - 4) * CFrame.Angles(0, rad(180), 0), { accent = { 255, 235, 200 } })
	Props.build("bench", model, cf * CFrame.new(c.cx - 10, 0.4, c.z1 - 3), {})
	Props.build("bench", model, cf * CFrame.new(c.cx + 10, 0.4, c.z1 - 3), {})
	local lamp = part(model, Vector3.new(3, 0.4, 3), cf * CFrame.new(c.cx, wallH - 0.5, c.cz), { 255, 245, 225 }, Enum.Material.Neon, "HallLight")
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.2
	light.Parent = lamp
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

-- Reception: wide lobby with glass front, desk and check-in queue, register,
-- waiting lounge, trophies. The back opens onto the central hall.
function PlotBuilder.buildReception(parent, index, cityId, level, passes)
	local cf = PlotBuilder.plotCFrame(index)
	local r = Layout.RECEPTION
	local arch = ARCH[cityId] or ARCH.smalltown
	local model = Instance.new("Model")
	model.Name = "Reception"
	local w, dpt = r.x1 - r.x0, r.z1 - r.z0
	local centre = cf * CFrame.new((r.x0 + r.x1) / 2, 0, (r.z0 + r.z1) / 2)
	part(model, Vector3.new(w, 0.4, dpt), centre * CFrame.new(0, 0.2, 0), arch.hallColor, material(arch.hall), "Floor")
	part(model, Vector3.new(24, 0.06, dpt - 2), centre * CFrame.new(0, 0.43, 0), { 150, 30, 30 }, Enum.Material.Fabric, "Carpet")
	local wallC = { 40, 38, 36 }
	local wallH = 12
	part(model, Vector3.new(1, wallH, dpt), centre * CFrame.new(-w / 2 + 0.5, wallH / 2, 0), wallC, Enum.Material.SmoothPlastic, "WallL")
	part(model, Vector3.new(1, wallH, dpt), centre * CFrame.new(w / 2 - 0.5, wallH / 2, 0), wallC, Enum.Material.SmoothPlastic, "WallR")
	-- back wall with a wide opening onto the hall
	local opening = Layout.CORRIDOR + 4
	local backSeg = (w - opening) / 2
	part(model, Vector3.new(backSeg, wallH, 1), centre * CFrame.new(-w / 2 + backSeg / 2, wallH / 2, dpt / 2 - 0.5), wallC, Enum.Material.SmoothPlastic, "WallBL")
	part(model, Vector3.new(backSeg, wallH, 1), centre * CFrame.new(w / 2 - backSeg / 2, wallH / 2, dpt / 2 - 0.5), wallC, Enum.Material.SmoothPlastic, "WallBR")
	-- glass front on both sides of the entrance
	local frontSeg = (w - 26) / 2
	for _, sx in ipairs({ -1, 1 }) do
		local glass = part(model, Vector3.new(frontSeg, wallH - 2, 0.4), centre * CFrame.new(sx * (13 + frontSeg / 2), (wallH - 2) / 2 + 0.4, -dpt / 2 + 1.6), { 180, 210, 230 }, Enum.Material.Glass, "Glass")
		glass.Transparency = 0.55
	end
	part(model, Vector3.new(w + 0.4, 0.6, 1.4), centre * CFrame.new(0, wallH + 0.3, dpt / 2 - 0.5), { 212, 175, 55 }, Enum.Material.Metal, "Trim")
	-- academy logo wall behind the desk
	local logo = part(model, Vector3.new(16, 5, 0.3), centre * CFrame.new(-w / 2 + 12, 7, dpt / 2 - 1.2), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "LogoWall")
	textOn(logo, Enum.NormalId.Front, "WORLD MARTIAL ARTS ACADEMY", { 212, 175, 55 }, 24)
	-- class board
	local board = part(model, Vector3.new(10, 5, 0.3), centre * CFrame.new(w / 2 - 9, 7, dpt / 2 - 1.2), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "ClassBoard")
	textOn(board, Enum.NormalId.Front, "TODAY'S CLASSES\nKihon • Kata • Sparring • Randori", { 240, 240, 240 }, 20)

	-- desk (faces the entrance) and check-in queue rails
	local desk = cf * CFrame.new(Layout.desk.x, 0, Layout.desk.z)
	Props.build("desk", model, desk, { label = "CHECK-IN" })
	for _, sx in ipairs({ -1, 1 }) do
		local rail = part(model, Vector3.new(0.25, 3, 14), cf * CFrame.new(Layout.desk.x + sx * 9.5, 1.5, Layout.desk.z - 9), { 212, 175, 55 }, Enum.Material.Metal, "QueueRail")
		rail.CanCollide = false
	end
	-- waiting lounge on the right side
	Props.build("sofa", model, cf * CFrame.new(r.x1 - 8, 0, r.z1 - 5), {})
	Props.build("sofa", model, cf * CFrame.new(r.x1 - 3.5, 0, r.z1 - 14) * CFrame.Angles(0, rad(-90), 0), {})
	Props.build("plant", model, cf * CFrame.new(r.x0 + 3, 0, r.z0 + 4), {})
	Props.build("plant", model, cf * CFrame.new(r.x1 - 3, 0, r.z0 + 4), {})
	Props.build("plant", model, cf * CFrame.new(-Layout.CORRIDOR / 2 - 3, 0, r.z1 - 3), {})
	Props.build("plant", model, cf * CFrame.new(Layout.CORRIDOR / 2 + 3, 0, r.z1 - 3), {})
	if level >= 2 then
		Props.build("trophy_case", model, cf * CFrame.new(r.x0 + 2.5, 0, r.z1 - 12) * CFrame.Angles(0, rad(-90), 0), {})
		Props.build("belt_display", model, cf * CFrame.new(r.x0 + 1.2, 0, r.z0 + 16) * CFrame.Angles(0, rad(-90), 0), {})
	end
	if level >= 3 then
		Props.build("chandelier", model, cf * CFrame.new(0, 2, (r.z0 + r.z1) / 2), {})
	end
	if level >= 4 then
		Props.build("fountain", model, cf * CFrame.new(r.x1 - 12, 0, r.z0 + 10), {})
	end
	if level >= 5 then
		Props.build("statue", model, cf * CFrame.new(0, 0, r.z1 - 8) * CFrame.Angles(0, rad(180), 0), { label = "SENSEI" })
	end
	if passes and passes.premium_decor then
		Props.build("statue", model, cf * CFrame.new(r.x0 + 7, 0, r.z0 + 6), { label = "LEGEND" })
	end
	-- register pad
	local pad = part(model, Vector3.new(5, 0.3, 5), cf * CFrame.new(Layout.register.x, 0.5, Layout.register.z), { 212, 175, 55 }, Enum.Material.Neon, "RegisterPad")
	pad.Transparency = 0.25
	-- counter with a cash register machine and a sign behind the pad
	local rx, rz = Layout.register.x, Layout.register.z
	part(model, Vector3.new(6, 3.4, 1.6), cf * CFrame.new(rx, 1.7, rz + 3.6), { 30, 28, 26 }, Enum.Material.SmoothPlastic, "RegisterCounter")
	part(model, Vector3.new(6.2, 0.25, 1.8), cf * CFrame.new(rx, 3.5, rz + 3.6), { 212, 175, 55 }, Enum.Material.Metal, "RegisterTop")
	part(model, Vector3.new(1.8, 1.1, 1.2), cf * CFrame.new(rx, 4.15, rz + 3.6), { 60, 60, 66 }, Enum.Material.Metal, "RegisterMachine")
	part(model, Vector3.new(1.4, 0.5, 0.1), cf * CFrame.new(rx, 4.5, rz + 2.95), { 80, 220, 120 }, Enum.Material.Neon, "RegisterDisplay")
	local sign = part(model, Vector3.new(6, 1.6, 0.3), cf * CFrame.new(rx, 6.4, rz + 3.9), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "RegisterSign")
	textOn(sign, Enum.NormalId.Front, "💰 CASH REGISTER", { 120, 230, 120 }, 30)
	local stack = part(model, Vector3.new(2.4, 0.4, 1.4), cf * CFrame.new(rx, 1, rz), { 80, 170, 80 }, Enum.Material.SmoothPlastic, "CashStack")
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
