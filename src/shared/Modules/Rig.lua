-- Builds a lightweight 15-part character model from an Appearance description
-- and poses it with forward kinematics (Poses.lua angles). Parts are anchored
-- and moved with workspace:BulkMoveTo, so NPCs cost no physics. Client-side.

local Rig = {}

local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local YXZ = CFrame.fromEulerAnglesYXZ

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local BODY_PARTS = { "Hips", "Chest", "Head", "LUpperArm", "LLowerArm", "LHand", "RUpperArm", "RLowerArm", "RHand", "LUpperLeg", "LLowerLeg", "LFoot", "RUpperLeg", "RLowerLeg", "RFoot" }
Rig.BODY_PARTS = BODY_PARTS

local function dims(spec, scale)
	local p = spec.proportions
	local s = p.h * (scale or 1)
	local w = scale or 1
	local d = {
		hipsW = 1.8 * p.w * w, hipsH = 0.8 * s, hipsD = 0.95 * p.d * w,
		chestW = 1.8 * p.w * p.shoulders * w, chestH = 1.45 * s, chestD = 0.95 * p.d * w,
		headD = 1.2 * (p.head or 1) * math.sqrt(s),
		armW = 0.52 * p.limb * w, uaL = 1.15 * s, laL = 1.05 * s,
		handD = 0.5 * math.sqrt(p.limb) * w,
		legW = 0.72 * p.limb * w, ulL = 1.25 * s, llL = 1.2 * s,
		footH = 0.3 * s, footL = 1.0 * w,
		belly = p.belly or 0,
	}
	d.hipY = d.ulL + d.llL + d.footH + d.hipsH / 2
	return d
end

local function newPart(model, name, size, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

-- Build. Returns rig table { model, parts = { name = Part }, extras = { {part, parent, offset} }, dims }
function Rig.build(spec, opts)
	opts = opts or {}
	local d = dims(spec, opts.scale)
	local model = Instance.new("Model")
	model.Name = opts.name or "NPC"
	local rig = { model = model, parts = {}, extras = {}, dims = d, spec = spec, list = {}, cfs = {} }
	local skin = spec.skin

	-- Clothing uses SmoothPlastic too: Roblox's Fabric texture turns white
	-- uniforms grey, and gis must read as clean white with a coloured belt.
	local function fabric()
		return Enum.Material.SmoothPlastic
	end
	local function body(name, size, shape)
		local part = newPart(model, name, size, c3(spec.colors[name] or skin), shape, fabric(name))
		rig.parts[name] = part
		return part
	end
	body("Hips", Vector3.new(d.hipsW, d.hipsH, d.hipsD))
	body("Chest", Vector3.new(d.chestW, d.chestH, d.chestD))
	body("Head", Vector3.new(d.headD, d.headD, d.headD), Enum.PartType.Ball)
	for _, side in ipairs({ "L", "R" }) do
		body(side .. "UpperArm", Vector3.new(d.armW, d.uaL, d.armW))
		body(side .. "LowerArm", Vector3.new(d.armW * 0.92, d.laL, d.armW * 0.92))
		body(side .. "Hand", Vector3.new(d.handD, d.handD, d.handD), Enum.PartType.Ball)
		body(side .. "UpperLeg", Vector3.new(d.legW, d.ulL, d.legW))
		body(side .. "LowerLeg", Vector3.new(d.legW * 0.9, d.llL, d.legW * 0.9))
		body(side .. "Foot", Vector3.new(d.legW * 0.95, d.footH, d.footL))
	end

	local function attach(parentName, part, offset)
		table.insert(rig.extras, { part = part, parent = parentName, offset = offset })
	end
	local function add(parentName, name, size, color, offset, shape, material)
		local part = newPart(model, name, size, c3(color), shape, material or Enum.Material.SmoothPlastic)
		attach(parentName, part, offset)
		return part
	end

	local hd = d.headD
	-- belly (sumo / heavy)
	if d.belly > 0 then
		add("Chest", "Belly", Vector3.new(d.chestW * 0.86, d.chestH * 0.95, d.chestD * 0.9), spec.colors.Chest or skin, CF(0, -d.chestH * 0.18, -d.chestD * 0.22 * d.belly), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	end

	for _, e in ipairs(spec.extras) do
		local k = e.kind
		if k == "hair" then
			local col = e.color
			local st = e.style
			if st == "afro" then
				add("Head", "Hair", Vector3.new(hd * 1.45, hd * 1.35, hd * 1.4), col, CF(0, hd * 0.22, hd * 0.12), Enum.PartType.Ball)
			elseif st == "chonmage" then
				add("Head", "Hair", Vector3.new(hd * 1.03, hd * 1.0, hd * 1.03), col, CF(0, hd * 0.08, hd * 0.1), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
				add("Head", "Topknot", Vector3.new(hd * 0.22, hd * 0.18, hd * 0.55), col, CF(0, hd * 0.56, -hd * 0.02), nil, Enum.Material.SmoothPlastic)
			elseif st == "mohawk" then
				add("Head", "Hair", Vector3.new(hd * 0.22, hd * 0.35, hd * 0.95), col, CF(0, hd * 0.48, hd * 0.05))
			elseif st == "buzz" then
				add("Head", "Hair", Vector3.new(hd * 1.02, hd * 1.0, hd * 1.02), col, CF(0, hd * 0.06, hd * 0.07), Enum.PartType.Ball)
			else
				add("Head", "Hair", Vector3.new(hd * 1.06, hd * 1.02, hd * 1.06), col, CF(0, hd * 0.09, hd * 0.1), Enum.PartType.Ball)
				if st == "ponytail" then
					add("Head", "Ponytail", Vector3.new(hd * 0.25, hd * 0.7, hd * 0.25), col, CF(0, -hd * 0.05, hd * 0.6) * ANG(rad(-20), 0, 0))
				elseif st == "bun" then
					add("Head", "Bun", Vector3.new(hd * 0.42, hd * 0.42, hd * 0.42), col, CF(0, hd * 0.42, hd * 0.38), Enum.PartType.Ball)
				elseif st == "long" then
					add("Head", "LongHair", Vector3.new(hd * 0.95, hd * 1.0, hd * 0.3), col, CF(0, -hd * 0.32, hd * 0.42))
				elseif st == "side" then
					add("Head", "Fringe", Vector3.new(hd * 0.7, hd * 0.2, hd * 0.25), col, CF(hd * 0.12, hd * 0.38, -hd * 0.38) * ANG(0, 0, rad(-12)))
				elseif st == "curly" then
					add("Head", "Curls", Vector3.new(hd * 1.2, hd * 0.6, hd * 1.15), col, CF(0, hd * 0.38, hd * 0.08), Enum.PartType.Ball)
				end
			end
		elseif k == "eyes" then
			local gap = spec.face.eyeGap * hd
			local y = spec.face.eyeY * hd
			add("Head", "LEye", Vector3.new(0.13, 0.17, 0.1), { 20, 20, 25 }, CF(-gap, y, -hd * 0.47), nil, Enum.Material.SmoothPlastic)
			add("Head", "REye", Vector3.new(0.13, 0.17, 0.1), { 20, 20, 25 }, CF(gap, y, -hd * 0.47), nil, Enum.Material.SmoothPlastic)
			if spec.face.mouth then
				add("Head", "Mouth", Vector3.new(0.3, 0.05, 0.06), { 120, 60, 60 }, CF(0, -hd * 0.22, -hd * 0.45), nil, Enum.Material.SmoothPlastic)
			end
		elseif k == "brows" then
			local gap = spec.face.eyeGap * hd
			local y = spec.face.eyeY * hd + 0.17
			add("Head", "LBrow", Vector3.new(0.24, 0.06, 0.06), e.color, CF(-gap, y, -hd * 0.46), nil, Enum.Material.SmoothPlastic)
			add("Head", "RBrow", Vector3.new(0.24, 0.06, 0.06), e.color, CF(gap, y, -hd * 0.46), nil, Enum.Material.SmoothPlastic)
		elseif k == "beard" then
			add("Head", "Beard", Vector3.new(hd * 0.62, hd * 0.32, hd * 0.3), e.color, CF(0, -hd * 0.34, -hd * 0.28))
		elseif k == "lapel" then
			local w = e.thick and 0.34 or 0.24
			local col = e.color
			add("Chest", "LapelL", Vector3.new(w, d.chestH * 0.95, 0.06), col, CF(-0.22, 0.02, -d.chestD / 2 - 0.02) * ANG(0, 0, rad(e.vneck and 24 or 18)))
			add("Chest", "LapelR", Vector3.new(w, d.chestH * 0.95, 0.06), col, CF(0.22, 0.02, -d.chestD / 2 - 0.03) * ANG(0, 0, rad(e.vneck and -24 or -18)))
		elseif k == "belt" then
			local col = e.color
			add("Hips", "Belt", Vector3.new(d.hipsW + 0.12, 0.34, d.hipsD + 0.12), col, CF(0, d.hipsH / 2 - 0.08, 0))
			add("Hips", "BeltKnot", Vector3.new(0.38, 0.24, 0.14), col, CF(e.sash and d.hipsW * 0.35 or 0, d.hipsH / 2 - 0.08, -d.hipsD / 2 - 0.08))
			local tailX = e.sash and d.hipsW * 0.38 or 0.1
			add("Hips", "BeltTailL", Vector3.new(0.14, e.sash and 0.8 or 0.55, 0.05), col, CF(tailX - 0.12, d.hipsH / 2 - 0.45, -d.hipsD / 2 - 0.08) * ANG(0, 0, rad(8)))
			local tail = add("Hips", "BeltTailR", Vector3.new(0.14, e.sash and 0.8 or 0.55, 0.05), col, CF(tailX + 0.12, d.hipsH / 2 - 0.45, -d.hipsD / 2 - 0.08) * ANG(0, 0, rad(-8)))
			if e.stripe then
				add("Hips", "BeltStripe", Vector3.new(0.16, 0.12, 0.06), e.stripe, CF(tailX + 0.13, d.hipsH / 2 - 0.62, -d.hipsD / 2 - 0.1))
			end
			tail.Name = "BeltTailR"
		elseif k == "gloves" then
			local st = e.style
			for _, side in ipairs({ "L", "R" }) do
				if st == "boxing" then
					add(side .. "Hand", side .. "Glove", Vector3.new(d.handD * 1.75, d.handD * 1.7, d.handD * 1.9), e.color, CF(0, -0.05, -0.05), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
					add(side .. "LowerArm", side .. "Cuff", Vector3.new(d.armW * 1.2, d.laL * 0.3, d.armW * 1.2), e.color, CF(0, -d.laL * 0.38, 0), nil, Enum.Material.SmoothPlastic)
				elseif st == "mma" then
					add(side .. "Hand", side .. "Glove", Vector3.new(d.handD * 1.25, d.handD * 1.2, d.handD * 1.3), e.color, CF(), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
				elseif st == "mitts" then
					add(side .. "Hand", side .. "Mitt", Vector3.new(0.75, 0.85, 0.28), e.color, CF(0, -0.1, -0.2), nil, Enum.Material.SmoothPlastic)
				elseif st == "thai_pads" then
					add(side .. "LowerArm", side .. "Pad", Vector3.new(0.6, d.laL * 1.0, 0.5), e.color, CF(0, 0, -d.armW * 0.7), nil, Enum.Material.SmoothPlastic)
				end
			end
		elseif k == "shins" then
			for _, side in ipairs({ "L", "R" }) do
				add(side .. "LowerLeg", side .. "Shin", Vector3.new(d.legW * 1.05, d.llL * 0.82, 0.3), e.color, CF(0, 0.02, -d.legW * 0.45), nil, Enum.Material.SmoothPlastic)
			end
		elseif k == "prajiad" then
			for _, side in ipairs({ "L", "R" }) do
				add(side .. "UpperArm", side .. "Prajiad", Vector3.new(d.armW * 1.18, 0.16, d.armW * 1.18), e.color, CF(0, d.uaL * 0.2, 0))
			end
		elseif k == "headgear" then
			add("Head", "HeadgearL", Vector3.new(0.18, hd * 0.42, hd * 0.42), e.color, CF(-hd * 0.5, 0, 0), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
			add("Head", "HeadgearR", Vector3.new(0.18, hd * 0.42, hd * 0.42), e.color, CF(hd * 0.5, 0, 0), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
			add("Head", "HeadgearStrap", Vector3.new(hd * 1.02, 0.12, 0.25), e.color, CF(0, hd * 0.4, 0))
		elseif k == "cap" then
			add("Head", "Cap", Vector3.new(hd * 1.05, hd * 0.35, hd * 1.05), e.color, CF(0, hd * 0.38, 0.02))
			add("Head", "CapBrim", Vector3.new(hd * 0.8, 0.08, hd * 0.5), e.color, CF(0, hd * 0.25, -hd * 0.6))
		elseif k == "whistle" then
			add("Chest", "Whistle", Vector3.new(0.18, 0.12, 0.3), { 220, 220, 230 }, CF(0.25, d.chestH * 0.05, -d.chestD / 2 - 0.12), nil, Enum.Material.Metal)
			add("Chest", "Lanyard", Vector3.new(0.6, 0.06, 0.04), { 200, 30, 30 }, CF(0.1, d.chestH * 0.3, -d.chestD / 2 - 0.03) * ANG(0, 0, rad(-50)))
		elseif k == "boot_tops" then
			for _, side in ipairs({ "L", "R" }) do
				add(side .. "LowerLeg", side .. "BootTop", Vector3.new(d.legW * 1.05, d.llL * 0.42, d.legW * 1.05), e.color, CF(0, -d.llL * 0.29, 0), nil, Enum.Material.SmoothPlastic)
			end
		elseif k == "sandals" then
			for _, side in ipairs({ "L", "R" }) do
				add(side .. "Foot", side .. "Sandal", Vector3.new(d.legW * 1.05, 0.1, d.footL * 1.05), e.color, CF(0, -d.footH / 2, 0), nil, Enum.Material.Wood)
			end
		elseif k == "sunglasses" then
			add("Head", "Sunglasses", Vector3.new(hd * 0.78, 0.2, 0.08), { 15, 15, 18 }, CF(0, spec.face.eyeY * hd, -hd * 0.49), nil, Enum.Material.Glass)
		elseif k == "chain" then
			add("Chest", "Chain", Vector3.new(d.chestW * 0.45, 0.1, 0.06), e.color, CF(0, d.chestH * 0.3, -d.chestD / 2 - 0.03), nil, Enum.Material.Metal)
		elseif k == "mawashi" then
			add("Hips", "Mawashi", Vector3.new(d.hipsW + 0.14, d.hipsH * 1.05, d.hipsD + 0.14), e.color, CF(0, 0.02, 0))
			add("Hips", "MawashiBand", Vector3.new(d.hipsW * 0.32, d.hipsH * 1.2, d.hipsD + 0.24), e.color, CF(0, -0.1, 0))
			add("Hips", "MawashiKnot", Vector3.new(0.6, 0.5, 0.3), e.color, CF(0, 0.05, d.hipsD / 2 + 0.15))
		elseif k == "sagari" then
			for i = -2, 2 do
				add("Hips", "Sagari" .. i, Vector3.new(0.08, d.hipsH * 0.9, 0.06), e.color, CF(i * 0.16, -d.hipsH * 0.45, -d.hipsD / 2 - 0.1))
			end
		elseif k == "waistband" then
			add("Hips", "Waistband", Vector3.new(d.hipsW + 0.06, e.wide and 0.32 or 0.18, d.hipsD + 0.06), e.color, CF(0, d.hipsH / 2 - 0.1, 0))
		elseif k == "thai_text" then
			add("Hips", "ShortsText", Vector3.new(d.hipsW * 0.5, 0.18, 0.05), e.color, CF(0, -0.05, -d.hipsD / 2 - 0.03))
		elseif k == "stripe" then
			local part = e.part
			if part == "Chest" then
				add("Chest", "Stripe", Vector3.new(d.chestW + 0.04, 0.18, d.chestD + 0.04), e.color, CF(0, -d.chestH * 0.1, 0))
			else
				add(part, part .. "Stripe", Vector3.new(0.08, d.uaL * 0.95, d.armW * 0.5), e.color, CF((string.sub(part, 1, 1) == "L" and -1 or 1) * d.armW * 0.52, 0, 0))
			end
		elseif k == "logo" then
			add("Chest", "Logo", Vector3.new(0.6, 0.4, 0.05), e.color, CF(-d.chestW * 0.22, d.chestH * 0.2, -d.chestD / 2 - 0.02))
		elseif k == "collar" then
			add("Chest", "Collar", Vector3.new(d.chestW * 0.5, 0.16, d.chestD * 0.7), e.color, CF(0, d.chestH / 2, 0))
		elseif k == "patches" then
			add("LUpperArm", "PatchL", Vector3.new(0.05, 0.35, 0.35), e.color, CF(-d.armW / 2 - 0.02, d.uaL * 0.15, 0))
			add("RUpperLeg", "PatchR", Vector3.new(0.05, 0.4, 0.4), e.color, CF(d.legW / 2 + 0.02, 0, 0))
			add("Chest", "PatchBack", Vector3.new(d.chestW * 0.5, 0.25, 0.05), e.color, CF(0, d.chestH * 0.3, d.chestD / 2 + 0.02))
		elseif k == "buttons" then
			for i = 0, 3 do
				add("Chest", "Button" .. i, Vector3.new(0.3, 0.07, 0.07), e.color, CF(0.12, d.chestH * 0.32 - i * 0.28, -d.chestD / 2 - 0.03))
			end
		elseif k == "cuffs" then
			for _, side in ipairs({ "L", "R" }) do
				add(side .. "LowerArm", side .. "CuffTrim", Vector3.new(d.armW * 1.05, 0.14, d.armW * 1.05), e.color, CF(0, -d.laL * 0.44, 0))
			end
		elseif k == "obi" then
			add("Hips", "Obi", Vector3.new(d.hipsW + 0.12, 0.45, d.hipsD + 0.12), e.color, CF(0, d.hipsH / 2 - 0.05, 0))
		elseif k == "tie" then
			add("Chest", "Tie", Vector3.new(0.18, d.chestH * 0.7, 0.05), e.color, CF(0, 0.05, -d.chestD / 2 - 0.04))
		elseif k == "zip" then
			add("Chest", "Zip", Vector3.new(0.06, d.chestH * 0.95, 0.05), e.color, CF(0, 0, -d.chestD / 2 - 0.02))
		end
	end

	if spec.robe then
		-- yukata/kimono skirt over the legs
		local col = spec.colors.Hips
		add("Hips", "Robe", Vector3.new(d.hipsW + 0.2, d.ulL + d.llL * 0.7, d.hipsD + 0.25), col, CF(0, -(d.ulL + d.llL * 0.7) / 2 + d.hipsH * 0.3, 0))
	end

	if spec.aura and not opts.noAura then
		local att = Instance.new("Attachment")
		att.Parent = rig.parts.Chest
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(c3(spec.aura))
		pe.LightEmission = 0.8
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Rate = 10
		pe.Speed = NumberRange.new(1, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = att
		local light = Instance.new("PointLight")
		light.Color = c3(spec.aura)
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = rig.parts.Chest
	end

	for _, name in ipairs(BODY_PARTS) do
		table.insert(rig.list, rig.parts[name])
	end
	for _, e in ipairs(rig.extras) do
		table.insert(rig.list, e.part)
	end
	model.PrimaryPart = rig.parts.Hips
	return rig
end

-- Compute world CFrames for a pose; base = CFrame of the spot on the floor
-- (position at ground level, facing = LookVector).
function Rig.compute(rig, base, pose)
	local d = rig.dims
	local function g(key)
		return pose[key] or 0
	end
	local parts = {}
	local hips = base * CF(g("rx"), d.hipY, -g("rz")) * YXZ(-rad(g("rp")), rad(g("ry")), -rad(g("rr")))
	parts.Hips = hips
	local chest = hips * CF(0, d.hipsH / 2, 0) * YXZ(-rad(g("wp")), rad(g("wy")), -rad(g("wr"))) * CF(0, d.chestH / 2, 0)
	parts.Chest = chest
	parts.Head = chest * CF(0, d.chestH / 2, 0) * YXZ(-rad(g("np")), rad(g("ny")), 0) * CF(0, d.headD * 0.46, 0)

	for _, sideInfo in ipairs({ { "L", -1, "l" }, { "R", 1, "r" } }) do
		local S, side, p = sideInfo[1], sideInfo[2], sideInfo[3]
		-- arm
		local shoulder = chest * CF(side * (d.chestW / 2 + d.armW / 2 - 0.02), d.chestH / 2 - d.armW * 0.5, 0)
		local armJoint = ANG(0, side * rad(g(p .. "sy")), 0) * ANG(0, 0, side * rad(g(p .. "sr"))) * ANG(rad(g(p .. "sp")), 0, 0)
		local upper = shoulder * armJoint * CF(0, -d.uaL / 2 + d.armW * 0.25, 0)
		local lower = upper * CF(0, -d.uaL / 2, 0) * ANG(rad(g(p .. "el")), 0, 0) * CF(0, -d.laL / 2, 0)
		parts[S .. "UpperArm"] = upper
		parts[S .. "LowerArm"] = lower
		parts[S .. "Hand"] = lower * CF(0, -d.laL / 2 - d.handD * 0.3, 0)
		-- leg
		local hip = hips * CF(side * d.hipsW * 0.26, -d.hipsH / 2 + 0.1, 0)
		local legJoint = ANG(0, side * rad(g(p .. "hy")), 0) * ANG(0, 0, side * rad(g(p .. "hr"))) * ANG(rad(g(p .. "hp")), 0, 0)
		local thigh = hip * legJoint * CF(0, -d.ulL / 2, 0)
		local shin = thigh * CF(0, -d.ulL / 2, 0) * ANG(-rad(g(p .. "kn")), 0, 0) * CF(0, -d.llL / 2, 0)
		parts[S .. "UpperLeg"] = thigh
		parts[S .. "LowerLeg"] = shin
		parts[S .. "Foot"] = shin * CF(0, -d.llL / 2 - d.footH / 2, -0.15)
	end
	return parts
end

local function minY(cf, size)
	local _, y, _, _, _, _, r10, r11, r12 = cf:GetComponents()
	return y - (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z) / 2
end

-- Pose the rig (moves all parts). Feet are kept on the floor unless the pose
-- is airborne (grounded == false), in which case rh lifts it.
function Rig.apply(rig, base, pose)
	local parts = Rig.compute(rig, base, pose)
	local lowest = math.huge
	for _, name in ipairs(BODY_PARTS) do
		local y = minY(parts[name], rig.parts[name].Size)
		if y < lowest then
			lowest = y
		end
	end
	local lift = base.Y - lowest
	if pose.grounded == false then
		lift = lift + (pose.rh or 0)
	end
	local shift = Vector3.new(0, lift, 0)
	local cfs = rig.cfs
	local n = 0
	for _, name in ipairs(BODY_PARTS) do
		n = n + 1
		cfs[n] = parts[name] + shift
	end
	for _, e in ipairs(rig.extras) do
		n = n + 1
		cfs[n] = (parts[e.parent] * e.offset) + shift
	end
	workspace:BulkMoveTo(rig.list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	return parts.Head + shift
end

return Rig
