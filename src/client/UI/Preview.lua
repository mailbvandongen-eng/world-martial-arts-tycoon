-- 3D character preview inside a ViewportFrame (trainer cards, inspect view).
-- Uses the same Appearance + Rig + Poses as the NPCs in the world.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Appearance = require(Shared.Modules.Appearance)
local Rig = require(Shared.Modules.Rig)
local Poses = require(Shared.Modules.Poses)
local Disciplines = require(Shared.Config.Disciplines)

local Preview = {}

local active = {}

-- opts: { seed, discipline, role, rarity, rank, animate = true }
function Preview.character(parent, opts, props)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(150, 150, 160)
	vf.LightColor = Color3.fromRGB(255, 245, 230)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in pairs(props or {}) do
		vf[k] = v
	end
	vf.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vf
	local spec = Appearance.describe({ seed = opts.seed, discipline = opts.discipline, role = opts.role or "trainer", rarity = opts.rarity, rank = opts.rank })
	local rig = Rig.build(spec, { noAura = true })
	rig.model.Parent = world
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	local disc = Disciplines.byId[opts.discipline]
	local move = Poses.moves[disc and disc.moves.idle or "idle"] or Poses.moves.idle
	local base = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(200), 0)
	-- BulkMoveTo needs the parts in a WorldModel; posing happens on the model directly
	local function pose(t)
		local parts = Rig.compute(rig, base, Poses.sample(move, t))
		for name, cf in pairs(parts) do
			rig.parts[name].CFrame = cf
		end
		for _, e in ipairs(rig.extras) do
			e.part.CFrame = parts[e.parent] * e.offset
		end
	end
	pose(0)
	local height = rig.dims.hipY + rig.dims.hipsH + rig.dims.chestH + rig.dims.headD
	cam.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.55, -height * 2.1), Vector3.new(0, height * 0.5, 0))
	if opts.animate ~= false then
		local entry = { vf = vf, pose = pose, t = 0 }
		active[vf] = entry
		vf.Destroying:Connect(function()
			active[vf] = nil
		end)
	end
	return vf
end

RunService.RenderStepped:Connect(function(dt)
	for vf, e in pairs(active) do
		if not vf.Parent then
			active[vf] = nil
		elseif vf.Visible then
			e.t = e.t + dt
			e.pose(e.t)
		end
	end
end)

return Preview
