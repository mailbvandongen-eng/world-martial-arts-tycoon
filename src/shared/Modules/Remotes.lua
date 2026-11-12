-- Remote names in one place. The server creates them (Remotes.setup), clients
-- wait for them (Remotes.get).
--   Action    RemoteFunction  client -> server: (action, payload) -> { ok, err | result }
--   State     RemoteEvent     server -> owner:  full player state snapshot
--   Plots     RemoteEvent     server -> all:    academy layout of every plot (for rendering)
--   Visitors  RemoteEvent     server -> all:    visitor plans (one message per visitor)
--   Notify    RemoteEvent     server -> client: toasts and effects
--   Emote     RemoteEvent     client -> server request / server -> all broadcast
--   Tournament   RemoteEvent  server -> all: current tournament (bracket + bouts)
--   Competition  RemoteEvent  server -> all: bouts shown on a competition hall mat

local Remotes = {}

Remotes.FUNCTIONS = { "Action" }
Remotes.EVENTS = { "State", "Plots", "Visitors", "Notify", "Emote", "Tournament", "Competition" }

function Remotes.setup()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(Remotes.FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = folder
		end
	end
	for _, name in ipairs(Remotes.EVENTS) do
		if not folder:FindFirstChild(name) then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = folder
		end
	end
	return folder
end

function Remotes.get(name)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name)
end

return Remotes
