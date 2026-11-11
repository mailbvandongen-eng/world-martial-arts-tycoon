-- World interaction on the client: which proximity prompts this player may use,
-- what they open, construction progress boards, animated gym lighting and the
-- city lighting/atmosphere of the academy the player is standing in.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Modules.Layout)
local Format = require(Shared.Modules.Format)
local Cities = require(Shared.Config.Cities)

local State = require(script.Parent.State)

local WorldController = {}

local player = Players.LocalPlayer
local ui -- UI module (open panels, toasts)
local boards = {} -- model -> billboard
local discoLamps = {}
local currentLightingCity

local function plotsFolder()
	return workspace:WaitForChild("PlayerPlots")
end

local function refreshPrompt(prompt)
	local kind = prompt:GetAttribute("Kind")
	local plot = prompt:GetAttribute("Plot")
	local mine = State.myPlot()
	if kind == "claim" then
		prompt.Enabled = mine == nil
	elseif kind then
		prompt.Enabled = mine ~= nil and plot == mine
	end
end

local function refreshAllPrompts()
	for _, d in ipairs(plotsFolder():GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			refreshPrompt(d)
		end
	end
end

local function onPromptTriggered(prompt)
	local kind = prompt:GetAttribute("Kind")
	local slot = prompt:GetAttribute("Slot")
	if kind == "claim" then
		State.call("claimPlot", { index = prompt:GetAttribute("Plot") })
	elseif kind == "register" then
		State.call("collect")
	elseif kind == "build" then
		ui.open("build", { slot = slot })
	elseif kind == "room" then
		ui.open("room", { slot = slot })
	elseif kind == "construction" then
		ui.open("room", { slot = slot })
	end
end

local function makeBoard(model)
	local anchor = model:FindFirstChild("ProgressAnchor")
	if not anchor or boards[model] then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.MaxDistance = 150
	bb.AlwaysOnTop = true
	bb.Adornee = anchor
	bb.Parent = anchor
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0.4, 0)
	bg.Position = UDim2.new(0, 0, 0.6, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = model:GetAttribute("Accent") or Color3.fromRGB(212, 175, 55)
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "BUILDING..."
	label.Parent = bb
	boards[model] = { fill = fill, label = label }
end

local function scan(descendant)
	if descendant:IsA("ProximityPrompt") then
		refreshPrompt(descendant)
	elseif descendant:IsA("Model") and descendant:GetAttribute("Constructing") then
		task.defer(makeBoard, descendant)
	elseif descendant:IsA("BasePart") and descendant:GetAttribute("Disco") then
		discoLamps[descendant] = true
	end
end

local function updateBoards()
	local now = workspace:GetServerTimeNow()
	for model, b in pairs(boards) do
		if not model.Parent then
			boards[model] = nil
		else
			local s, e = model:GetAttribute("BuildStart") or now, model:GetAttribute("BuildEnd") or now
			local f = math.clamp((now - s) / math.max(e - s, 1), 0, 1)
			b.fill.Size = UDim2.new(f, 0, 1, 0)
			b.label.Text = f >= 1 and "FINISHING..." or ("BUILDING  " .. Format.time(e - now))
		end
	end
	local hue = (os.clock() * 0.15) % 1
	for lamp in pairs(discoLamps) do
		if not lamp.Parent then
			discoLamps[lamp] = nil
		else
			local light = lamp:FindFirstChildOfClass("SpotLight")
			if light then
				light.Color = Color3.fromHSV((hue + lamp.Position.X * 0.01) % 1, 0.8, 1)
			end
		end
	end
end

-- Which plot is the camera focus in?
local function plotAt(position)
	for i = 1, Layout.PLOT_COUNT do
		local o = Layout.plotOrigin(i)
		local cf = CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, math.rad(o.yaw), 0)
		local rel = cf:PointToObjectSpace(position)
		if math.abs(rel.X) <= Layout.WIDTH / 2 + 10 and rel.Z >= Layout.FRONT - 10 and rel.Z <= Layout.DEPTH / 2 + 10 then
			return i
		end
	end
	return nil
end

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function applyCityLighting(cityId)
	if cityId == currentLightingCity then
		return
	end
	currentLightingCity = cityId
	local lighting = cityId and Cities.byId[cityId] and Cities.byId[cityId].theme.lighting
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	local target = lighting or { clock = 15.5, ambient = { 120, 120, 125 }, fog = { 200, 215, 235 }, tint = { 255, 255, 255 } }
	TweenService:Create(Lighting, info, { ClockTime = target.clock, OutdoorAmbient = c3(target.ambient) }):Play()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		TweenService:Create(atm, info, { Color = c3(target.fog), Decay = c3(target.fog):Lerp(Color3.new(0, 0, 0), 0.3) }):Play()
	end
	local cc = Lighting:FindFirstChild("CityGrade")
	if cc then
		TweenService:Create(cc, info, { TintColor = c3(target.tint) }):Play()
	end
end

local function updateLighting()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local index = plotAt(root.Position)
	local snap = index and State.plots[index]
	applyCityLighting(snap and snap.city or nil)
end

function WorldController.init(uiModule)
	ui = uiModule
	local folder = plotsFolder()
	for _, d in ipairs(folder:GetDescendants()) do
		scan(d)
	end
	folder.DescendantAdded:Connect(scan)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	State.Changed:Connect(refreshAllPrompts)
	State.PlotsChanged:Connect(refreshAllPrompts)
	task.spawn(function()
		while true do
			updateBoards()
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			updateLighting()
			task.wait(1)
		end
	end)
end

WorldController.plotAt = plotAt

return WorldController
