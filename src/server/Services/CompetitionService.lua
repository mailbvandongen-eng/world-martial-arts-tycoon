-- Competition hall shows. Bouts (sparring, belt exams, your own kumite) are
-- decided on the server (Domain/Competition) and then shown on the mat of the
-- owner's competition hall: everyone nearby sees the fighters, the referee and
-- the scoreboard. One show at a time per hall; later shows queue up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Modules.Remotes)
local Layout = require(Shared.Modules.Layout)

local PlotService = require(script.Parent.PlotService)

local CompetitionService = {}

local remote
local busyUntil = {} -- plot index -> server time the mat is free again
local BETWEEN = 1.5 -- seconds between two bouts of one show

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function showLength(show)
	local total = 0
	for i, b in ipairs(show.bouts) do
		total = total + b.duration + (i > 1 and BETWEEN or 0)
	end
	return total
end

function CompetitionService.isFree(player)
	local index = PlotService.plotOf(player)
	return index ~= nil and (busyUntil[index] or 0) <= serverNow()
end

-- Queue a show on the player's mat. Returns the server time it ends (or nil).
function CompetitionService.stage(player, show)
	local index = PlotService.plotOf(player)
	if not index then
		return nil
	end
	local now = serverNow()
	local t0 = math.max(now + 1, (busyUntil[index] or 0) + 2)
	local length = showLength(show)
	show.t0 = t0
	show.endAt = t0 + length
	show.between = BETWEEN
	busyUntil[index] = show.endAt
	remote:FireAllClients("show", index, show)
	return show.endAt, t0
end

-- Run fn when the show has been seen (results are told after the last move).
function CompetitionService.after(endAt, fn)
	task.delay(math.max(0, endAt - serverNow()) + 0.5, fn)
end

-- Put the player on the red (AKA) mark of their mat and keep them there
-- until the bout is over.
local function placeOnMat(player, index, untilT)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local c = Layout.COMPETITION
	local plotCF = PlotService.plotCFrame(index)
	local pos = plotCF * Vector3.new(c.cx - 2.8, 3.4, c.cz)
	local look = plotCF * Vector3.new(c.cx + 5, 3.4, c.cz)
	root.CFrame = CFrame.lookAt(pos, look)
	local speed, jump, height = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	task.delay(math.max(1, untilT - serverNow()), function()
		if humanoid.Parent then
			humanoid.WalkSpeed = speed > 0 and speed or 16
			humanoid.JumpPower = jump > 0 and jump or 50
			humanoid.JumpHeight = height > 0 and height or 7.2
		end
	end)
end

-- Your own kumite: the opponent's attacks are public, your answers stay on
-- your client until you submit. Everyone nearby sees the opponent fight you.
function CompetitionService.startKumite(player, challenge, prompts)
	local index = PlotService.plotOf(player)
	if not index then
		return false
	end
	local endAt = challenge.startAt + challenge.duration
	busyUntil[index] = endAt + 2
	placeOnMat(player, index, endAt + 1)
	local o = challenge.opponent
	remote:FireAllClients("kumite", index, {
		userId = player.UserId, name = player.DisplayName, t0 = challenge.startAt, endAt = endAt, prompts = prompts,
		blue = { name = o.name .. " (" .. o.academy .. ")", seed = o.seed, rank = o.rank, discipline = "karate" },
	})
	return true
end

function CompetitionService.finishKumite(player, res)
	local index = PlotService.plotOf(player)
	if not index then
		return
	end
	busyUntil[index] = serverNow() + 2
	remote:FireAllClients("kumiteResult", index, { userId = player.UserId, score = res.score, winner = res.winner, method = res.method })
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.WalkSpeed == 0 then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end

function CompetitionService.init()
	remote = Remotes.get("Competition")
	Players.PlayerRemoving:Connect(function(player)
		local index = PlotService.plotOf(player)
		if index then
			busyUntil[index] = nil
			remote:FireAllClients("clear", index)
		end
	end)
end

return CompetitionService
