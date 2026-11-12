-- Scheduled tournaments. Every few minutes a tournament opens (rotating
-- disciplines). Players enter their academy during registration; the server
-- fills the bracket with rival academies, simulates the matches, reveals the
-- rounds over time and pays prizes. Everything is decided on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Modules.Remotes)
local Config = require(Shared.Config.Activities)

local Domain = script.Parent.Parent.Domain
local Activities = require(Domain.Activities)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local TournamentService = {}

local current -- { info, entrants = { userId -> entry }, resolved, rounds, places, awarded }
local remote

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function newTournament(now)
	local info = Activities.tournamentAt(now)
	return { info = info, entrants = {}, order = {} }
end

-- Public view sent to clients.
local function snapshot()
	if not current then
		return nil
	end
	local entrants = {}
	for _, e in ipairs(current.order) do
		table.insert(entrants, { name = e.name, strength = math.floor(e.strength), userId = e.userId })
	end
	local rounds
	if current.rounds then
		rounds = {}
		for r, list in ipairs(current.rounds) do
			rounds[r] = {}
			for i, m in ipairs(list) do
				rounds[r][i] = { a = m.a.name, b = m.b.name, winner = m.winner.name, aUser = m.a.userId, bUser = m.b.userId }
			end
		end
	end
	return { info = current.info, entrants = entrants, rounds = rounds, resolved = current.resolved == true }
end

function TournamentService.state()
	return snapshot()
end

function TournamentService.enter(player)
	local d = DataService.get(player)
	if not d or not current then
		return false, "Not ready"
	end
	local ok, res = Activities.enterTournament(d, current.info, serverNow())
	if not ok then
		return false, res
	end
	local entry = { userId = player.UserId, name = player.DisplayName .. "'s Academy", strength = res.strength }
	current.entrants[player.UserId] = entry
	table.insert(current.order, entry)
	PlayerService.track(player, "tournamentsEntered", 1)
	remote:FireAllClients("state", snapshot())
	PlayerService.notifyAll("social", { text = player.DisplayName .. " entered the " .. current.info.name .. "!" })
	return true, res
end

local function resolve()
	local list = {}
	for _, e in ipairs(current.order) do
		-- players who left keep their place (the academy still competes)
		table.insert(list, e)
	end
	local bracket = Activities.fillBracket(list, current.info.key * 7 + 3)
	local rounds, places = Activities.playBracket(bracket, current.info.key * 13 + 1)
	current.rounds = rounds
	current.places = places
	current.resolved = true
	remote:FireAllClients("state", snapshot())
end

local function award()
	current.awarded = true
	for entry, place in pairs(current.places) do
		if entry.userId then
			local player = Players:GetPlayerByUserId(entry.userId)
			local d = player and DataService.get(player)
			if d then
				local r = Activities.awardTournament(d, place)
				r.name = current.info.name
				PlayerService.notify(player, "tournament", r)
				PlayerService.recordEarning(player, r.cash)
				if place == 1 then
					PlayerService.track(player, "tournamentWins", 1)
					PlayerService.notifyAll("social", { text = "🏆 " .. player.DisplayName .. " won the " .. current.info.name .. "!" })
				end
				PlayerService.markDirty(player)
			end
		end
	end
end

-- Developer menu: start a tournament right now with a short registration.
function TournamentService.devStart(tournamentId, registrationSeconds)
	local def
	for _, t in ipairs(Config.tournaments) do
		if t.id == tournamentId then
			def = t
		end
	end
	if not def then
		return false, "Unknown tournament"
	end
	local now = serverNow()
	local reg = now + (registrationSeconds or 20)
	local info = {
		key = -math.floor(now), id = def.id, name = def.name .. " (test)", discipline = def.discipline,
		startAt = now, regEnd = reg, rounds = { reg, reg + 12, reg + 24 }, endAt = reg + 30, nextAt = reg + 60,
	}
	current = { info = info, entrants = {}, order = {} }
	remote:FireAllClients("state", snapshot())
	return true
end

function TournamentService.init()
	remote = Remotes.get("Tournament")
	current = newTournament(serverNow())
	task.spawn(function()
		while true do
			task.wait(1)
			local now = serverNow()
			if now >= current.info.nextAt then
				current = newTournament(now)
				remote:FireAllClients("state", snapshot())
				PlayerService.notifyAll("social", { text = "📣 " .. current.info.name .. " is open for registration!" })
			elseif not current.resolved and now >= current.info.regEnd then
				if #current.order == 0 then
					-- nobody entered: skip the simulation, keep the schedule
					current.resolved = true
					current.awarded = true
				else
					resolve()
				end
			elseif current.resolved and not current.awarded and now >= current.info.endAt then
				award()
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		remote:FireClient(player, "state", snapshot())
	end)
end

return TournamentService
