-- Client copy of the player's state (read-only; the server is authoritative)
-- and the single entry point for requests to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Signal = require(Shared.Modules.Signal)

local State = {}

State.data = nil
State.localUserId = game:GetService("Players").LocalPlayer.UserId
State.derived = nil
State.serverTime = 0
State.Changed = Signal.new()
State.plots = {} -- index -> snapshot (all plots, from Plots remote)
State.PlotsChanged = Signal.new()
State.onError = nil -- set by UI to show errors

local actionRemote

function State.init()
	actionRemote = Remotes.get("Action")
	Remotes.get("State").OnClientEvent:Connect(function(state)
		State.data = state.data
		State.derived = state.derived
		State.serverTime = state.serverTime
		State.Changed:Fire()
	end)
	Remotes.get("Plots").OnClientEvent:Connect(function(kind, payload)
		if kind == "all" then
			for i, snap in pairs(payload) do
				State.plots[tonumber(i) or snap.index] = snap
			end
		elseif kind == "plot" then
			State.plots[payload.index] = payload
		end
		State.PlotsChanged:Fire()
	end)
	-- tournaments (server-wide)
	State.tournament = nil
	State.TournamentChanged = Signal.new()
	Remotes.get("Tournament").OnClientEvent:Connect(function(kind, payload)
		if kind == "state" then
			State.tournament = payload
			State.TournamentChanged:Fire()
		end
	end)
	-- ask for the first snapshot now that we are listening (retry while loading)
	task.spawn(function()
		for _ = 1, 30 do
			local ok = State.call("hello", {}, true)
			if ok and State.data then
				return
			end
			task.wait(2)
		end
	end)
end

function State.ready()
	return State.data ~= nil
end

-- Calls a server action. Returns ok, result|err. Shows errors via State.onError.
function State.call(action, payload, silent)
	local ok, response = pcall(function()
		return actionRemote:InvokeServer(action, payload or {})
	end)
	if not ok or type(response) ~= "table" then
		if State.onError and not silent then
			State.onError("Connection problem, try again")
		end
		return false, "network"
	end
	if not response.ok then
		if State.onError and not silent then
			State.onError(response.err or "Not possible")
		end
		return false, response.err
	end
	return true, response.result
end

function State.myPlot()
	return State.derived and State.derived.plot or nil
end

function State.now()
	return workspace:GetServerTimeNow()
end

return State
