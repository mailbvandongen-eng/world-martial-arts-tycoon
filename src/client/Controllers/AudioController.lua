-- Sound playback. Sounds with asset id 0 (not uploaded yet) are skipped.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)

local State = require(script.Parent.State)

local AudioController = {}

local templates = {}
local loops = {}
local lastPlayed = {}

local function enabled(kind)
	local s = State.data and State.data.settings
	if not s then
		return true
	end
	if kind == "music" then
		return s.music ~= false
	end
	return s.sfx ~= false
end

local function template(name)
	local def = Audio[name]
	if not def or def.id == 0 then
		return nil
	end
	if not templates[name] then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. tostring(def.id)
		s.Volume = def.volume or 0.5
		s.Looped = def.looped == true
		templates[name] = s
	end
	return templates[name]
end

function AudioController.play(name)
	if not enabled("sfx") then
		return
	end
	local t = template(name)
	if not t then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then
		return
	end
	lastPlayed[name] = now
	local s = t:Clone()
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- 3D sound at a world position (bag hits, kicks, stomps).
function AudioController.playAt(name, position)
	if not enabled("sfx") then
		return
	end
	local t = template(name)
	if not t then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.08 then
		return
	end
	lastPlayed[name] = now
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local s = t:Clone()
	s.RollOffMaxDistance = 70
	s.RollOffMinDistance = 8
	s.Parent = anchor
	s:Play()
	s.Ended:Once(function()
		anchor:Destroy()
	end)
	task.delay(5, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
end

function AudioController.loop(name, on)
	local kind = name == "music" and "music" or "sfx"
	local t = template(name)
	if not t then
		return
	end
	if on and enabled(kind) then
		if not loops[name] then
			local s = t:Clone()
			s.Parent = SoundService
			s:Play()
			loops[name] = s
		end
	elseif loops[name] then
		loops[name]:Destroy()
		loops[name] = nil
	end
end

function AudioController.init()
	State.Changed:Connect(function()
		AudioController.loop("music", true)
		AudioController.loop("ambience_gym", true)
		if not enabled("music") then
			AudioController.loop("music", false)
		end
		if not enabled("sfx") then
			AudioController.loop("ambience_gym", false)
		end
	end)
end

return AudioController
