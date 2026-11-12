-- Player avatar cosmetics: outfit overlays (welded parts over R15 or R6
-- bodies), auras, the title above the head, and emote/victory-pose requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Modules.Remotes)
local Cosmetics = require(Shared.Config.Cosmetics)
local Cities = require(Shared.Config.Cities)

local DataService = require(script.Parent.DataService)

local CosmeticService = {}

local emoteRemote
local lastEmote = {}

local function col(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- R15 and R6 part names for each body region.
local REGIONS = {
	torso = { "UpperTorso", "Torso" },
	hips = { "LowerTorso", "Torso" },
	lArm = { "LeftUpperArm", "Left Arm" },
	rArm = { "RightUpperArm", "Right Arm" },
	lFore = { "LeftLowerArm" },
	rFore = { "RightLowerArm" },
	lHand = { "LeftHand", "Left Arm" },
	rHand = { "RightHand", "Right Arm" },
	lLeg = { "LeftUpperLeg", "Left Leg" },
	rLeg = { "RightUpperLeg", "Right Leg" },
}

local function find(character, region)
	for _, name in ipairs(REGIONS[region]) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function weldPart(folder, target, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = "Overlay"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = target.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function shell(folder, target, color, pad, material)
	pad = pad or 0.12
	return weldPart(folder, target, target.Size + Vector3.new(pad, pad * 0.5, pad), CFrame.new(), color, material)
end

local function applyOutfit(folder, character, style)
	local isR6 = character:FindFirstChild("Torso") ~= nil
	local top = style.top
	local color = style.color and col(style.color) or Color3.new(1, 1, 1)
	local torso = find(character, "torso")
	local hips = find(character, "hips")
	if not torso then
		return
	end
	if top == "gi" or top == "dobok" or top == "kungfu" or top == "suit" or top == "rashguard" then
		shell(folder, torso, color)
		for _, r in ipairs({ "lArm", "rArm", "lFore", "rFore" }) do
			local p = find(character, r)
			if p and (top ~= "rashguard" or r == "lArm" or r == "rArm") then
				shell(folder, p, color, 0.1)
			end
		end
		if not isR6 and hips and top ~= "rashguard" then
			shell(folder, hips, color)
		end
		for _, r in ipairs({ "lLeg", "rLeg" }) do
			local p = find(character, r)
			if p and top ~= "rashguard" then
				shell(folder, p, color, 0.1)
			end
		end
		if top == "gi" or top == "dobok" or top == "suit" then
			local lapel = style.trim and col(style.trim) or (top == "dobok" and Color3.fromRGB(25, 25, 28) or color:Lerp(Color3.new(0, 0, 0), 0.15))
			for _, sx in ipairs({ -1, 1 }) do
				weldPart(folder, torso, Vector3.new(0.3, torso.Size.Y * 0.9, 0.05), CFrame.new(sx * 0.25, 0, -torso.Size.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(-sx * 20)), lapel)
			end
		end
		if top == "kungfu" and style.trim then
			for i = 0, 3 do
				weldPart(folder, torso, Vector3.new(0.35, 0.08, 0.08), CFrame.new(0.15, torso.Size.Y * 0.3 - i * 0.3, -torso.Size.Z / 2 - 0.1), col(style.trim), Enum.Material.Metal)
			end
		end
	end
	if style.belt then
		local beltHost = hips or torso
		local y = isR6 and -torso.Size.Y / 2 + 0.2 or beltHost.Size.Y / 2 - 0.15
		weldPart(folder, beltHost, Vector3.new(beltHost.Size.X + 0.2, 0.25, beltHost.Size.Z + 0.2), CFrame.new(0, y, 0), col(style.belt))
		weldPart(folder, beltHost, Vector3.new(0.15, 0.6, 0.05), CFrame.new(0.15, y - 0.35, -beltHost.Size.Z / 2 - 0.12), col(style.belt))
	end
	if style.shorts then
		if hips and not isR6 then
			shell(folder, hips, col(style.shorts))
		end
		for _, r in ipairs({ "lLeg", "rLeg" }) do
			local p = find(character, r)
			if p then
				local h = isR6 and p.Size.Y * 0.45 or p.Size.Y * 0.8
				weldPart(folder, p, Vector3.new(p.Size.X + 0.12, h, p.Size.Z + 0.12), CFrame.new(0, p.Size.Y / 2 - h / 2, 0), col(style.shorts))
			end
		end
	end
	if style.mawashi then
		local host = hips or torso
		local y = isR6 and -torso.Size.Y / 2 + 0.3 or 0
		weldPart(folder, host, Vector3.new(host.Size.X + 0.3, isR6 and 0.7 or host.Size.Y + 0.2, host.Size.Z + 0.3), CFrame.new(0, y, 0), col(style.mawashi))
	end
	if style.gloves then
		for _, r in ipairs({ "lHand", "rHand" }) do
			local p = find(character, r)
			if p then
				local y = isR6 and -p.Size.Y / 2 + 0.3 or 0
				weldPart(folder, p, Vector3.new(1.05, 1.05, 1.15), CFrame.new(0, y, 0), col(style.gloves), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end
	if style.armbands then
		for _, r in ipairs({ "lArm", "rArm" }) do
			local p = find(character, r)
			if p then
				weldPart(folder, p, Vector3.new(p.Size.X + 0.15, 0.18, p.Size.Z + 0.15), CFrame.new(0, p.Size.Y * 0.25, 0), Color3.fromRGB(220, 40, 60))
			end
		end
	end
end

local function applyAura(folder, character, style)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "AuraAttachment"
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(col(style.color))
	pe.LightEmission = 0.9
	pe.Rate = style.rate or 12
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = att
	local light = Instance.new("PointLight")
	light.Color = col(style.color)
	light.Range = 8
	light.Brightness = 1
	light.Parent = root
	-- remember for cleanup
	local tag = Instance.new("ObjectValue")
	tag.Name = "AuraRef"
	tag.Value = att
	tag.Parent = folder
	local tag2 = Instance.new("ObjectValue")
	tag2.Name = "AuraRef"
	tag2.Value = light
	tag2.Parent = folder
end

local function applyTitle(folder, character, player, d)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OwnerTitle"
	bb.Size = UDim2.fromScale(5, 1.3)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80
	bb.Adornee = head
	bb.Parent = folder
	local eq = d.cosmetics.equipped.title and Cosmetics.byId[d.cosmetics.equipped.title]
	local title = eq and eq.text or "Academy Owner"
	local gold = eq and (eq.id == "title_vip" or eq.id == "title_elite")
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(1, 0, 0.5, 0)
	t1.Text = title
	t1.TextScaled = true
	t1.Font = Enum.Font.GothamBlack
	t1.TextColor3 = gold and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(240, 240, 240)
	t1.TextStrokeTransparency = 0.4
	t1.Parent = bb
	local t2 = t1:Clone()
	t2.Position = UDim2.new(0, 0, 0.5, 0)
	local city = Cities.byId[d.activeCity]
	t2.Text = "Lv " .. d.level .. (d.flags.prestigeTitle and ("  •  " .. d.flags.prestigeTitle) or "") .. "  •  " .. (city and city.name or "")
	t2.TextColor3 = Color3.fromRGB(200, 200, 210)
	t2.Font = Enum.Font.GothamBold
	t2.Parent = bb
end

function CosmeticService.apply(player)
	local character = player.Character
	local d = DataService.get(player)
	if not character or not d then
		return
	end
	local old = character:FindFirstChild("WMAT_Cosmetics")
	if old then
		for _, ref in ipairs(old:GetChildren()) do
			if ref:IsA("ObjectValue") and ref.Value then
				ref.Value:Destroy()
			end
		end
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WMAT_Cosmetics"
	folder.Parent = character
	local eq = d.cosmetics.equipped
	local outfit = eq.outfit and Cosmetics.byId[eq.outfit]
	if outfit and outfit.style then
		applyOutfit(folder, character, outfit.style)
	end
	local aura = eq.aura and Cosmetics.byId[eq.aura]
	if aura and aura.style then
		applyAura(folder, character, aura.style)
	end
	applyTitle(folder, character, player, d)
end

local function onCharacter(player, character)
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Head", 10)
	task.wait(0.5) -- let the avatar finish loading its parts
	CosmeticService.apply(player)
end

function CosmeticService.init()
	emoteRemote = Remotes.get("Emote")
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	DataService.onLoaded(function(player)
		task.wait(1)
		CosmeticService.apply(player)
	end)
	emoteRemote.OnServerEvent:Connect(function(player, cosmeticId)
		if type(cosmeticId) ~= "string" then
			return
		end
		local d = DataService.get(player)
		local c = Cosmetics.byId[cosmeticId]
		if not d or not c or c.kind ~= "pose" or not d.cosmetics.owned[cosmeticId] then
			return
		end
		local t = os.clock()
		if lastEmote[player] and t - lastEmote[player] < 3 then
			return
		end
		lastEmote[player] = t
		emoteRemote:FireAllClients(player.UserId, c.animation)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
	end)
end

return CosmeticService
