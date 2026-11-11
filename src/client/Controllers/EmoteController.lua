-- Plays victory poses / emotes on player avatars using the procedural pose
-- library (Motor6D.Transform), for R15 and R6 avatars. The server validates
-- that the player owns the pose and broadcasts it to everyone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Poses = require(Shared.Modules.Poses)
local Remotes = require(Shared.Modules.Remotes)

local EmoteController = {}

local active = {} -- character -> { move, start, length }
local rad = math.rad

-- Motor6D names -> pose angles (R15 first, R6 fallback)
local function jointsFor(character)
	local function m(partName, motorName)
		local part = character:FindFirstChild(partName)
		return part and part:FindFirstChild(motorName)
	end
	if character:FindFirstChild("UpperTorso") then
		return {
			waist = m("UpperTorso", "Waist"), neck = m("Head", "Neck"),
			lsh = m("LeftUpperArm", "LeftShoulder"), rsh = m("RightUpperArm", "RightShoulder"),
			lel = m("LeftLowerArm", "LeftElbow"), rel = m("RightLowerArm", "RightElbow"),
			lhip = m("LeftUpperLeg", "LeftHip"), rhip = m("RightUpperLeg", "RightHip"),
			lkn = m("LeftLowerLeg", "LeftKnee"), rkn = m("RightLowerLeg", "RightKnee"),
			root = m("LowerTorso", "Root"),
		}
	end
	local torso = character:FindFirstChild("Torso")
	if not torso then
		return nil
	end
	return {
		neck = torso:FindFirstChild("Neck"),
		lsh = torso:FindFirstChild("Left Shoulder"), rsh = torso:FindFirstChild("Right Shoulder"),
		lhip = torso:FindFirstChild("Left Hip"), rhip = torso:FindFirstChild("Right Hip"),
		r6 = true,
	}
end

local function apply(joints, pose)
	local function g(k)
		return pose[k] or 0
	end
	local function set(motor, cf)
		if motor then
			motor.Transform = cf
		end
	end
	if joints.r6 then
		-- R6 shoulder/hip motors rotate around their own Z axis (sideways)
		set(joints.lsh, CFrame.Angles(0, 0, -rad(g("lsp"))) * CFrame.Angles(rad(g("lsr")), 0, 0))
		set(joints.rsh, CFrame.Angles(0, 0, rad(g("rsp"))) * CFrame.Angles(rad(g("rsr")), 0, 0))
		set(joints.lhip, CFrame.Angles(0, 0, -rad(g("lhp"))))
		set(joints.rhip, CFrame.Angles(0, 0, rad(g("rhp"))))
		set(joints.neck, CFrame.Angles(rad(g("np")), 0, 0))
		return
	end
	set(joints.root, CFrame.fromEulerAnglesYXZ(-rad(g("rp")), rad(g("ry")), -rad(g("rr"))))
	set(joints.waist, CFrame.fromEulerAnglesYXZ(-rad(g("wp")), rad(g("wy")), -rad(g("wr"))))
	set(joints.neck, CFrame.fromEulerAnglesYXZ(-rad(g("np")), rad(g("ny")), 0))
	set(joints.lsh, CFrame.Angles(0, -rad(g("lsy")), 0) * CFrame.Angles(0, 0, -rad(g("lsr"))) * CFrame.Angles(rad(g("lsp")), 0, 0))
	set(joints.rsh, CFrame.Angles(0, rad(g("rsy")), 0) * CFrame.Angles(0, 0, rad(g("rsr"))) * CFrame.Angles(rad(g("rsp")), 0, 0))
	set(joints.lel, CFrame.Angles(rad(g("lel")), 0, 0))
	set(joints.rel, CFrame.Angles(rad(g("rel")), 0, 0))
	set(joints.lhip, CFrame.Angles(0, -rad(g("lhy")), 0) * CFrame.Angles(0, 0, -rad(g("lhr"))) * CFrame.Angles(rad(g("lhp")), 0, 0))
	set(joints.rhip, CFrame.Angles(0, rad(g("rhy")), 0) * CFrame.Angles(0, 0, rad(g("rhr"))) * CFrame.Angles(rad(g("rhp")), 0, 0))
	set(joints.lkn, CFrame.Angles(-rad(g("lkn")), 0, 0))
	set(joints.rkn, CFrame.Angles(-rad(g("rkn")), 0, 0))
end

function EmoteController.play(character, animation)
	local move = Poses.moves[animation]
	if not move or not character then
		return
	end
	local joints = jointsFor(character)
	if not joints then
		return
	end
	local length = move.loop and math.max(move.length * 2, 3) or move.length
	active[character] = { move = move, start = os.clock(), length = length, joints = joints }
end

-- Request an emote (server validates ownership).
function EmoteController.request(cosmeticId)
	Remotes.get("Emote"):FireServer(cosmeticId)
end

function EmoteController.init()
	Remotes.get("Emote").OnClientEvent:Connect(function(userId, animation)
		local player = Players:GetPlayerByUserId(userId)
		if player and player.Character then
			EmoteController.play(player.Character, animation)
		end
	end)
	-- after the default Animate script has posed the avatar
	RunService.Stepped:Connect(function()
		local now = os.clock()
		for character, e in pairs(active) do
			local t = now - e.start
			if t > e.length or not character.Parent then
				active[character] = nil
			else
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
					active[character] = nil -- walking cancels the emote
				else
					apply(e.joints, Poses.sample(e.move, t))
				end
			end
		end
	end)
end

return EmoteController
