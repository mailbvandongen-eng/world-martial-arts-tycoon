-- Shows bouts move by move: sparring, belt exams and your own kumite on the
-- mat of every academy's competition hall, and the featured tournament match
-- in the arena on the boulevard. Fighters, referee and judges are client-side
-- rigs (Rig + Poses); the scoreboard on the wall and a small on-screen board
-- follow the bout timeline that the server decided (Modules/Bout).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Modules.Layout)
local Rig = require(Shared.Modules.Rig)
local Poses = require(Shared.Modules.Poses)
local Appearance = require(Shared.Modules.Appearance)
local Remotes = require(Shared.Modules.Remotes)
local Bout = require(Shared.Modules.Bout)
local Disciplines = require(Shared.Config.Disciplines)
local ActivityConfig = require(Shared.Config.Activities)

local State = require(script.Parent.State)

local BoutController = {}

local RENDER_DISTANCE = 200
local OVERLAY_DISTANCE = 55
local ARENA_CF = CFrame.new(-150, 1.5, 0)
local RED = Color3.fromRGB(215, 45, 45)
local BLUE = Color3.fromRGB(50, 105, 215)
local AKA_BELT = { 200, 30, 30 }
local AO_BELT = { 40, 80, 200 }

local folder
local audio
local stages = {} -- key -> stage
local overlay -- { gui, frame, labels }
local live = { score = nil, call = nil } -- set by the kumite HUD of the local player

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function cameraPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function plotCF(index)
	local o = Layout.plotOrigin(index)
	return CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, math.rad(o.yaw), 0)
end

---------------------------------------------------------------- scoreboards

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Builds the board content (used on the wall and on screen).
local function boardContent(parent)
	local refs = {}
	local function side(x, color)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(x, 0)
		f.Size = UDim2.fromScale(0.5, 0.62)
		f.Parent = parent
		local name = label(f, { Position = UDim2.fromScale(0.04, 0.04), Size = UDim2.fromScale(0.92, 0.3), Font = Enum.Font.GothamBold })
		local score = label(f, { Position = UDim2.fromScale(0.04, 0.34), Size = UDim2.fromScale(0.92, 0.62) })
		return name, score
	end
	refs.redName, refs.redScore = side(0, RED)
	refs.blueName, refs.blueScore = side(0.5, BLUE)
	refs.call = label(parent, { Position = UDim2.fromScale(0.02, 0.63), Size = UDim2.fromScale(0.96, 0.21), TextColor3 = Color3.fromRGB(255, 215, 90) })
	refs.info = label(parent, { Position = UDim2.fromScale(0.02, 0.84), Size = UDim2.fromScale(0.96, 0.15), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 210) })
	return refs
end

local function makeWallBoard(cf, size, twoSided)
	local p = Instance.new("Part")
	p.Name = "LiveScoreboard"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromRGB(10, 10, 12)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = folder
	local boards = {}
	for _, face in ipairs(twoSided and { Enum.NormalId.Front, Enum.NormalId.Back } or { Enum.NormalId.Front }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = p
		local bg = Instance.new("Frame")
		bg.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
		bg.BorderSizePixel = 0
		bg.Size = UDim2.fromScale(1, 1)
		bg.Parent = sg
		table.insert(boards, boardContent(bg))
	end
	return { part = p, boards = boards }
end

local function setBoard(board, v)
	for _, refs in ipairs(board.boards or { board }) do
		refs.redName.Text = v.redName or ""
		refs.blueName.Text = v.blueName or ""
		refs.redScore.Text = v.redScore or ""
		refs.blueScore.Text = v.blueScore or ""
		refs.call.Text = v.call or ""
		refs.info.Text = v.info or ""
	end
end

local function buildOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoutOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	gui.DisplayOrder = 2
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 62)
	frame.Size = UDim2.fromOffset(380, 104)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	overlay = { gui = gui, frame = frame, refs = boardContent(inner), scale = scale }
end

---------------------------------------------------------------- stages

local function stageFor(key)
	local st = stages[key]
	if st then
		return st
	end
	if key == "arena" then
		st = { key = key, cf = ARENA_CF, judges = false, queue = {} }
		st.boardCF = CFrame.new(-150, 17, 0)
		st.boardSize = Vector3.new(14, 5.6, 0.3)
		st.twoSided = true
	else
		local c = Layout.COMPETITION
		local pcf = plotCF(key)
		st = { key = key, plot = key, cf = pcf * CFrame.new(c.cx, c.floor, c.cz), judges = true, queue = {} }
		local pos = pcf * Vector3.new(c.cx, 8, c.z0 + 0.7)
		st.boardCF = CFrame.lookAt(pos, pos + pcf:VectorToWorldSpace(Vector3.new(0, 0, 1)))
		st.boardSize = Vector3.new(15.4, 6, 0.2)
		-- judges sit on the chairs left of the mat and face it
		st.judgeSeats = {}
		for i = -2, 2 do
			local seat = pcf * Vector3.new(c.x0 + 5.2, 2.0, c.cz + i * 2.2)
			table.insert(st.judgeSeats, CFrame.lookAt(seat, seat + pcf:VectorToWorldSpace(Vector3.new(1, 0, 0))))
		end
	end
	stages[key] = st
	return st
end

local function at(st, x, z, faceX, faceZ)
	local pos = st.cf * Vector3.new(x, 0, z)
	local dir = st.cf:VectorToWorldSpace(Vector3.new(faceX, 0, faceZ))
	return CFrame.lookAt(pos, pos + dir)
end

local function destroyRig(r)
	if r and r.rig then
		r.rig.model:Destroy()
	end
end

local function clearCast(st)
	for _, k in ipairs({ "red", "blue", "ref" }) do
		destroyRig(st[k])
		st[k] = nil
	end
	for _, j in ipairs(st.judgeRigs or {}) do
		destroyRig(j)
	end
	st.judgeRigs = nil
	st.castKey = nil
end

local function tag(rig, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 0.6)
	bb.StudsOffset = Vector3.new(0, 1.9, 0)
	bb.MaxDistance = 60
	bb.Adornee = rig.parts.Head
	bb.Parent = rig.model
	label(bb, { Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, TextStrokeTransparency = 0.3 })
end

local function fighterRig(view, beltColor, color, role)
	local spec = Appearance.describe({ seed = view.seed or 1, discipline = view.discipline or "karate", role = role or "student", rank = view.rank or 1, category = "professional", beltColor = beltColor })
	local rig = Rig.build(spec, { name = "Fighter" })
	tag(rig, view.name or "", color)
	rig.model.Parent = folder
	return { rig = rig }
end

local function officialRig(seed, name)
	local spec = Appearance.describe({ seed = seed, role = "staff" })
	local rig = Rig.build(spec, { name = name })
	rig.model.Parent = folder
	return { rig = rig }
end

-- Make sure the right fighters/officials exist for what is shown now.
local function cast(st, castKey, red, blue, opts)
	if st.castKey == castKey then
		return
	end
	clearCast(st)
	st.castKey = castKey
	local kata = opts.examRed -- belt exam: the student wears their own belt
	if red then
		st.red = fighterRig(red, (not kata and opts.belts) and AKA_BELT or nil, RED)
	end
	if blue then
		st.blue = fighterRig(blue, opts.belts and not opts.examiner and AO_BELT or nil, BLUE, opts.examiner and "trainer" or nil)
	end
	st.ref = officialRig(777 + (tonumber(st.key) or 3), "Referee")
	if st.judges and opts.judges then
		st.judgeRigs = {}
		for i = 1, 5 do
			table.insert(st.judgeRigs, officialRig(900 + i, "Judge"))
		end
	end
end

local function sample(move, t, once)
	local m = Poses.moves[move] or Poses.moves.idle
	if once then
		t = math.min(t, m.length - 0.01)
	end
	return Poses.sample(m, t)
end

-- Pose one fighter for bout time t.
local function poseFighter(st, f, side, bout, t, idle, kataMode)
	if not f then
		return
	end
	local dir = side == 1 and 1 or -1
	local x, z = -2.8 * dir, 0
	local fx, fz = dir, 0
	local move, mt, once = idle, t, false
	local endEv = bout.events[#bout.events]
	if endEv and endEv.r == "end" and t >= endEv.t then
		move, mt, once = endEv.s == side and "emote_champion" or "emote_bow", t - endEv.t, false
	elseif kataMode then
		local performer
		for _, ev in ipairs(bout.events) do
			if ev.t > t then
				break
			end
			if ev.r == "kata" or (ev.r == "call" and ev.s) then
				performer = ev.s
			end
		end
		if performer == side then
			x, z = 0, 0
			fx, fz = st.judges and -1 or 0, st.judges and 0 or 1
			local m, dt = Bout.actionAt(bout, side, t)
			if m then
				move, mt, once = m, dt, true
			else
				move, mt = "karate_stance", t
			end
		else
			move = "wait"
		end
	else
		local m, dt = Bout.actionAt(bout, side, t)
		if m then
			move, mt, once = m, dt, true
			if m == "hit_react" or m == "judo_breakfall" then
				x = x - dir * 0.4 * math.sin(math.pi * math.min(1, dt / 0.8))
			elseif m ~= bout.idle then
				x = x + dir * 1.1 * math.sin(math.pi * math.min(1, dt / 0.9))
			end
		end
	end
	Rig.apply(f.rig, at(st, x, z, fx, fz), sample(move, mt, once))
end

local function poseOfficials(st, bout, t, flagsOn)
	if st.ref then
		local move, mt = "ref_stand", t
		if t < 1.6 then
			move = "ref_start"
		end
		for _, ev in ipairs(bout and bout.events or {}) do
			if ev.t > t then
				break
			end
			if (ev.r == "score" or ev.r == "down" or ev.r == "end") and ev.s and t - ev.t < 1.6 then
				move, mt = ev.s == 1 and "ref_point_r" or "ref_point_l", t - ev.t
			end
		end
		Rig.apply(st.ref.rig, at(st, 0, -3.8, 0, 1), sample(move, mt, false))
	end
	if st.judgeRigs then
		for i, j in ipairs(st.judgeRigs) do
			local move = "judge_sit"
			if flagsOn and flagsOn[i] then
				move = flagsOn[i] == 1 and "judge_flag_r" or "judge_flag_l"
			end
			Rig.apply(j.rig, st.judgeSeats[i], sample(move, t, false))
		end
	end
end

local function playSounds(st, bout, t)
	local last = st.lastT or t
	st.lastT = t
	if not audio or (st.cf.Position - cameraPos()).Magnitude > 70 then
		return
	end
	for _, ev in ipairs(bout.events) do
		if ev.t > last and ev.t <= t then
			if ev.r == "score" or ev.r == "down" then
				audio.play(bout.format == "rounds" and "bag_hit" or "pad_kick")
			elseif ev.r == "end" or ev.r == "flags" then
				audio.play("whistle")
			end
		end
	end
end

---------------------------------------------------------------- what to show

local function scoreText(bout, s)
	if bout.format == "exam" then
		return nil
	end
	return tostring(s.score[1]), tostring(s.score[2])
end

local function showBout(st, show, bout, t, boardRefs)
	local s = Bout.stateAt(bout, t)
	local kataMode = bout.format == "kata" or bout.format == "exam"
	local discId = show.discipline or "karate"
	local disc = Disciplines.byId[discId]
	local idle = bout.idle or (disc and disc.moves.idle) or "karate_stance"
	poseFighter(st, st.red, 1, bout, t, idle, kataMode)
	if bout.format == "exam" then
		-- the examiner watches from the side during the kata
		if st.blue then
			Rig.apply(st.blue.rig, at(st, 3.5, -3.2, -0.6, 0.6), sample("coach_count", t, false))
		end
	else
		poseFighter(st, st.blue, 2, bout, t, idle, kataMode)
	end
	local flags
	for _, ev in ipairs(bout.events) do
		if ev.t <= t and (ev.r == "flags" or ev.r == "marks") then
			flags = ev.flags or { 1, 1, 1 }
		end
	end
	poseOfficials(st, bout, t, flags)
	playSounds(st, bout, t)
	-- scoreboard
	local v = { redName = show.red and show.red.name or "", blueName = show.blue and show.blue.name or "" }
	v.redScore, v.blueScore = scoreText(bout, s)
	v.call = s.call or ""
	local title = show.title or ""
	if bout.format == "rounds" then
		v.info = title .. "  •  Round " .. s.round .. " of " .. (bout.rounds or 3)
	elseif bout.format == "exam" then
		local marksEv
		for _, ev in ipairs(bout.events) do
			if ev.r == "marks" and ev.t <= t then
				marksEv = ev
			end
		end
		v.blueName = "PASS MARK"
		v.blueScore = show.passMark and tostring(show.passMark) or ""
		if marksEv then
			v.redScore = tostring(bout.total)
			v.call = string.format("%.1f  •  %.1f  •  %.1f", marksEv.marks[1], marksEv.marks[2], marksEv.marks[3])
		else
			v.redScore = "…"
		end
		v.info = title .. "  •  " .. (bout.kata and bout.kata[1] or "Kata")
	elseif bout.format == "kata" then
		v.info = title .. "  •  " .. (bout.kata and (bout.kata[1] .. " vs " .. bout.kata[2]) or "Kata")
	else
		v.info = title .. "  •  " .. math.max(0, math.floor((bout.duration - 3) - t)) .. "s"
	end
	if s.finished then
		v.info = (bout.winner == 1 and v.redName or v.blueName) .. " wins  •  " .. (bout.method or "")
		if bout.format == "exam" then
			v.info = show.passed and ("PASSED  •  " .. (show.rankName or "")) or "NOT PASSED  •  try again later"
		end
	end
	setBoard(boardRefs, v)
	return v
end

local function titleOf(show)
	local disc = Disciplines.byId[show.discipline or "karate"]
	local name = disc and disc.name or ""
	if show.kind == "spar" then
		return name .. " sparring"
	elseif show.kind == "exam" then
		return name .. " belt exam"
	end
	return show.title or name
end

-- Hall show (spar / exam): returns the board values when something is shown.
local function updateShow(st, now)
	while st.queue[1] and now > st.queue[1].endAt + 4 do
		table.remove(st.queue, 1)
	end
	local show = st.queue[1]
	if not show or now < show.t0 - 1 then
		return nil
	end
	show.title = titleOf(show)
	local t = now - show.t0
	local index, bout, bt = #show.bouts, show.bouts[#show.bouts], 0
	local acc = 0
	for i, b in ipairs(show.bouts) do
		local start = acc + (i > 1 and (show.between or 1.5) or 0)
		if t < start + b.duration or i == #show.bouts then
			index, bout, bt = i, b, t - start
			break
		end
		acc = start + b.duration
	end
	local belts = show.discipline == "karate" and show.kind ~= "exam"
	cast(st, "show:" .. show.t0 .. ":" .. index, show.red, show.blue, { belts = belts, examiner = show.kind == "exam", examRed = show.kind == "exam", judges = true })
	return showBout(st, show, bout, math.max(0, bt), st.board)
end

-- Your own kumite (or another player's): opponent attacks on the prompts.
local function updateLive(st, now)
	local k = st.live
	if not k then
		return nil
	end
	local finishedAt = k.result and k.resultAt or nil
	if now > (finishedAt and finishedAt + 5 or k.endAt + 6) then
		st.live = nil
		clearCast(st)
		return nil
	end
	cast(st, "live:" .. k.t0, nil, k.blue, { belts = true, judges = false })
	local t = now - k.t0
	local attacks = ActivityConfig.kumite.attacks
	local move, mt, once = "karate_stance", t, false
	local x = 2.8
	if finishedAt then
		move, mt = (k.result.winner == 2) and "emote_champion" or "emote_bow", now - finishedAt
	else
		for _, p in ipairs(k.prompts) do
			local start = p.t - 0.35
			if t >= start and t < start + 1.1 then
				move, mt, once = attacks[p.a].move, t - start, true
				local step = math.sin(math.pi * math.min(1, (t - start) / 0.9))
				x = attacks[p.a].lose > 0 and (2.8 - 1.1 * step) or (2.8 + 0.6 * step)
			end
		end
	end
	if st.blue then
		Rig.apply(st.blue.rig, at(st, x, 0, -1, 0), sample(move, math.max(0, mt), once))
	end
	poseOfficials(st, nil, t, nil)
	local v = { redName = k.name, blueName = k.blue.name }
	local mine = k.userId == Players.LocalPlayer.UserId
	if k.result then
		v.redScore, v.blueScore = tostring(k.result.score[1]), tostring(k.result.score[2])
		v.call = (k.result.winner == 1 and k.name or k.blue.name) .. " wins"
		v.info = k.result.method or ""
	elseif mine and live.score then
		v.redScore, v.blueScore = tostring(live.score[1]), tostring(live.score[2])
		v.call = live.call or ""
		v.info = "Kumite  •  " .. math.max(0, math.floor(k.endAt - now)) .. "s"
	else
		v.redScore, v.blueScore = "-", "-"
		v.call = t < 0 and "Rei!" or "Hajime!"
		v.info = "Kumite  •  live"
	end
	setBoard(st.board, v)
	return v
end

-- Featured tournament match in the arena.
local function updateArena(st, now)
	local tour = State.tournament
	if not tour or not tour.rounds then
		return nil
	end
	local info = tour.info
	local gap = ActivityConfig.TOURNAMENT_ROUND_GAP
	for r = 1, 3 do
		local start = info.rounds[r] - gap + 2
		local matches = tour.rounds[r]
		if matches and now >= start and now < info.rounds[r] + 6 then
			local m = matches[1]
			for _, mm in ipairs(matches) do
				if mm.aUser or mm.bUser then
					m = mm
				end
			end
			local bout = m.bout
			if not bout then
				return nil
			end
			local disc = info.discipline or "karate"
			local red = { name = m.a, seed = #m.a * 131 + 1, rank = 8, discipline = disc }
			local blue = { name = m.b, seed = #m.b * 131 + 2, rank = 8, discipline = disc }
			cast(st, "arena:" .. info.key .. ":" .. r, red, blue, { belts = disc == "karate", judges = false })
			local roundName = r == 1 and "Quarter-final" or r == 2 and "Semi-final" or "Final"
			local show = { red = red, blue = blue, discipline = disc, title = info.name .. "  •  " .. roundName }
			return showBout(st, show, bout, now - start, st.board)
		end
	end
	return nil
end

local function step()
	local now = serverNow()
	local cam = cameraPos()
	local nearest, nearestDist
	for key, st in pairs(stages) do
		local dist = (st.cf.Position - cam).Magnitude
		local v
		if dist < RENDER_DISTANCE then
			if not st.board then
				st.board = makeWallBoard(st.boardCF, st.boardSize, st.twoSided)
				setBoard(st.board, { call = key == "arena" and "TOURNAMENT ARENA" or "COMPETITION HALL", info = "Sparring • Belt exams • Kumite" })
			end
			if key == "arena" then
				v = updateArena(st, now)
			else
				v = updateLive(st, now) or updateShow(st, now)
			end
			if not v and st.castKey then
				clearCast(st)
				setBoard(st.board, { call = key == "arena" and "TOURNAMENT ARENA" or "COMPETITION HALL", info = "Sparring • Belt exams • Kumite" })
			end
		elseif st.castKey then
			clearCast(st)
		end
		if v and dist < OVERLAY_DISTANCE and (not nearestDist or dist < nearestDist) then
			nearest, nearestDist = v, dist
		end
	end
	if overlay then
		overlay.frame.Visible = nearest ~= nil
		if nearest then
			setBoard(overlay.refs, nearest)
		end
	end
end

-- Kumite HUD of the local player: live score for the boards.
function BoutController.setLiveScore(score, call)
	live.score = score
	live.call = call
end

function BoutController.init(audioController)
	audio = audioController
	folder = Instance.new("Folder")
	folder.Name = "Bouts"
	folder.Parent = workspace
	buildOverlay()
	stageFor("arena")
	local remote = Remotes.get("Competition")
	remote.OnClientEvent:Connect(function(kind, plotIndex, payload)
		local st = stageFor(plotIndex)
		if kind == "show" then
			table.insert(st.queue, payload)
			table.sort(st.queue, function(a, b)
				return a.t0 < b.t0
			end)
		elseif kind == "kumite" then
			st.live = payload
		elseif kind == "kumiteResult" then
			if st.live and st.live.userId == payload.userId then
				st.live.result = payload
				st.live.resultAt = serverNow()
			end
			if payload.userId == Players.LocalPlayer.UserId then
				live.score, live.call = nil, nil
			end
		elseif kind == "clear" then
			st.queue = {}
			st.live = nil
			clearCast(st)
		end
	end)
	-- every claimed plot gets its hall board once it is near
	State.PlotsChanged:Connect(function()
		for index in pairs(State.plots or {}) do
			stageFor(index)
		end
	end)
	for index in pairs(State.plots or {}) do
		stageFor(index)
	end
	local frame = 0
	RunService.Heartbeat:Connect(function()
		frame = frame + 1
		if frame % 2 == 0 then
			local ok, err = pcall(step)
			if not ok then
				warn("[BoutController] " .. tostring(err))
			end
		end
	end)
end

return BoutController
