-- Builds the shared world: the central boulevard with spawn, fountain, title
-- monument, leaderboard boards and city flags, plus lighting defaults.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Cities = require(Shared.Config.Cities)
local Layout = require(Shared.Modules.Layout)
local Props = require(script.Parent.Props)
local RoomBuilder = require(script.Parent.RoomBuilder)

local WorldBuilder = {}

local part = RoomBuilder.part
local rad = math.rad

local function col(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function board(parent, cf, title)
	local model = Instance.new("Model")
	model.Name = "Board_" .. title
	part(model, Vector3.new(1, 16, 1), cf * CFrame.new(-6.5, 8, 0.6), { 30, 30, 35 }, Enum.Material.Metal, "Leg")
	part(model, Vector3.new(1, 16, 1), cf * CFrame.new(6.5, 8, 0.6), { 30, 30, 35 }, Enum.Material.Metal, "Leg")
	local screen = part(model, Vector3.new(14, 12, 0.6), cf * CFrame.new(0, 11, 0), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "Screen")
	part(model, Vector3.new(14.6, 0.5, 0.8), cf * CFrame.new(0, 17.2, 0), { 212, 175, 55 }, Enum.Material.Metal, "Top")
	local sg = Instance.new("SurfaceGui")
	sg.Name = "BoardGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = screen
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
	header.Size = UDim2.new(1, 0, 0.13, 0)
	header.Text = title
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.TextColor3 = Color3.fromRGB(20, 20, 24)
	header.Parent = sg
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0.03, 0, 0.15, 0)
	list.Size = UDim2.new(0.94, 0, 0.83, 0)
	list.Parent = sg
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0.1, 0)
		row.TextScaled = true
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(230, 230, 230)
		row.Text = i .. ".  —"
		row.Parent = list
	end
	model.Parent = parent
	return model
end

function WorldBuilder.build()
	local env = Instance.new("Folder")
	env.Name = "Environment"
	env.Parent = workspace

	-- base ground under everything
	local ground = part(env, Vector3.new(900, 2, 700), CFrame.new(0, -1.2, 0), { 80, 120, 70 }, Enum.Material.Grass, "WorldGround")
	ground.Locked = true
	-- boulevard
	part(env, Vector3.new(700, 0.4, 62), CFrame.new(0, -0.15, 0), { 170, 165, 155 }, Enum.Material.Pavement, "Boulevard")
	for x = -330, 330, 22 do
		part(env, Vector3.new(10, 0.05, 0.6), CFrame.new(x, 0.08, 0), { 230, 230, 230 }, Enum.Material.SmoothPlastic, "Line")
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.3, 0)
	spawn.Color = Color3.fromRGB(212, 175, 55)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = env

	-- title monument
	local mon = part(env, Vector3.new(44, 9, 3), CFrame.new(0, 14, 24), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "Title")
	part(env, Vector3.new(3, 10, 3), CFrame.new(-20, 5, 24), { 212, 175, 55 }, Enum.Material.Metal, "TitlePost")
	part(env, Vector3.new(3, 10, 3), CFrame.new(20, 5, 24), { 212, 175, 55 }, Enum.Material.Metal, "TitlePost")
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.Parent = mon
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(1, 0, 0.62, 0)
	t1.Text = "WORLD MARTIAL ARTS TYCOON"
	t1.TextScaled = true
	t1.Font = Enum.Font.GothamBlack
	t1.TextColor3 = Color3.fromRGB(212, 175, 55)
	t1.Parent = sg
	local t2 = t1:Clone()
	t2.Position = UDim2.new(0, 0, 0.62, 0)
	t2.Size = UDim2.new(1, 0, 0.38, 0)
	t2.Text = "Build the ultimate martial arts empire"
	t2.TextColor3 = Color3.fromRGB(240, 240, 240)
	t2.Font = Enum.Font.GothamBold
	t2.Parent = sg

	Props.build("fountain", env, CFrame.new(0, 0, -16), {})

	-- tournament arena on the boulevard: ring, stands and a big sign
	local arenaCF = CFrame.new(-150, 0, 0)
	Props.build("ring", env, arenaCF, {})
	Props.build("bleachers", env, arenaCF * CFrame.new(0, 0, -9) * CFrame.Angles(0, rad(180), 0), { crowd = { { 200, 60, 60 }, { 60, 120, 200 }, { 230, 190, 60 } } })
	Props.build("bleachers", env, arenaCF * CFrame.new(0, 0, 9), { crowd = { { 60, 160, 90 }, { 200, 200, 200 }, { 140, 60, 170 } } })
	Props.build("spotlight", env, arenaCF * CFrame.new(-9, 0, 0) * CFrame.Angles(0, rad(-90), 0), { accent = { 255, 230, 180 } })
	Props.build("spotlight", env, arenaCF * CFrame.new(9, 0, 0) * CFrame.Angles(0, rad(90), 0), { accent = { 255, 230, 180 } })
	local arenaSign = part(env, Vector3.new(16, 3, 0.6), arenaCF * CFrame.new(0, 12, 0), { 20, 20, 24 }, Enum.Material.SmoothPlastic, "TournamentSign")
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		sg.Parent = arenaSign
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = "🏆 TOURNAMENT ARENA"
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = Color3.fromRGB(212, 175, 55)
		l.Parent = sg
	end
	part(env, Vector3.new(0.6, 12, 0.6), arenaCF * CFrame.new(-7.6, 6, 0), { 40, 40, 45 }, Enum.Material.Metal, "SignPole")
	part(env, Vector3.new(0.6, 12, 0.6), arenaCF * CFrame.new(7.6, 6, 0), { 40, 40, 45 }, Enum.Material.Metal, "SignPole")

	-- leaderboards along the boulevard
	local boards = Instance.new("Folder")
	boards.Name = "Leaderboards"
	boards.Parent = env
	local boardDefs = {
		{ "Richest Owners", -60 }, { "Highest Level", -30 }, { "Top Reputation", 30 }, { "Highest Prestige", 60 },
	}
	for _, b in ipairs(boardDefs) do
		local m = board(boards, CFrame.new(b[2], 0, 22), b[1])
		m:SetAttribute("Stat", b[1])
	end

	-- city flags
	for i, c in ipairs(Cities.list) do
		local x = -300 + (i - 1) * (600 / (#Cities.list - 1))
		for _, z in ipairs({ -28, 28 }) do
			part(env, Vector3.new(0.5, 18, 0.5), CFrame.new(x, 9, z), { 200, 200, 205 }, Enum.Material.Metal, "FlagPole")
			local flag = part(env, Vector3.new(6, 3.5, 0.15), CFrame.new(x + 3.2, 15.8, z), c.theme.accent, Enum.Material.Fabric, "Flag")
			local fs = Instance.new("SurfaceGui")
			fs.Face = z < 0 and Enum.NormalId.Back or Enum.NormalId.Front
			fs.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			fs.PixelsPerStud = 30
			fs.Parent = flag
			local ft = Instance.new("TextLabel")
			ft.BackgroundTransparency = 1
			ft.Size = UDim2.fromScale(1, 1)
			ft.Text = string.upper(c.name)
			ft.TextScaled = true
			ft.Font = Enum.Font.GothamBlack
			ft.TextColor3 = Color3.new(1, 1, 1)
			ft.Parent = fs
		end
	end
	for x = -320, 320, 40 do
		if math.abs(x) > 30 then
			Props.build("tree", env, CFrame.new(x + 10, 0, -26), {})
			Props.build("lamp", env, CFrame.new(x, 0, 26), {})
		end
	end

	-- lighting defaults (clients adjust per city)
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 15.5
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.28
		atm.Haze = 1.2
		atm.Parent = Lighting
	end
	if not Lighting:FindFirstChild("CityGrade") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CityGrade"
		cc.Saturation = 0.1
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	return env
end

-- Folders other services use.
function WorldBuilder.folders()
	local function folder(name)
		local f = workspace:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = workspace
		end
		return f
	end
	return {
		plots = folder("PlayerPlots"),
		npcs = folder("NPCs"),
		interactive = folder("InteractiveObjects"),
	}
end

WorldBuilder.Layout = Layout

return WorldBuilder
