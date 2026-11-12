-- Renders the living academy on this client: visitors (from server plans),
-- trainers in their rooms, receptionists, championship fighters and rank-up
-- celebrations. NPCs are client-side models posed procedurally (Rig + Poses).
-- Performance: render-distance culling, NPC cap from settings, far NPCs are
-- updated at a lower rate, models are created lazily and destroyed when gone.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Modules.Layout)
local Visits = require(Shared.Modules.Visits)
local Stations = require(Shared.Modules.Stations)
local Rig = require(Shared.Modules.Rig)
local Poses = require(Shared.Modules.Poses)
local Appearance = require(Shared.Modules.Appearance)
local Remotes = require(Shared.Modules.Remotes)
local RNG = require(Shared.Modules.RNG)
local Disciplines = require(Shared.Config.Disciplines)
local Customers = require(Shared.Config.Customers)
local Trainers = require(Shared.Config.Trainers)

local State = require(script.Parent.State)

local NPCController = {}

local RENDER_DISTANCE = 260
local DRILL_PERIOD = 6
local CAPS = { [0] = 12, [1] = 32, [2] = 60 }

local folder
local visitors = {} -- id key -> entry
local trainers = {} -- "plot:slot" -> entry
local staff = {} -- plot -> entry
local champs = {} -- plot -> entry
local rankups = {} -- "plot:slot" -> until time
local sessions = {} -- "plot:slot" -> { tSession, tEnd } latest
local sessionSeats = {} -- "plot:slot@tSession" -> { [station] = true, expires }
local plotCFs = {}
local audio -- AudioController (optional)
local frame = 0

local function plotCF(index)
	if not plotCFs[index] then
		local o = Layout.plotOrigin(index)
		plotCFs[index] = CFrame.new(o.x, 0, o.z) * CFrame.Angles(0, math.rad(o.yaw), 0)
	end
	return plotCFs[index]
end

local function floorY(p)
	local r = Layout.RECEPTION
	if p.x >= r.x0 and p.x <= r.x1 and p.z >= r.z0 and p.z <= r.z1 then
		return 0.4
	end
	if p.z > r.z1 and math.abs(p.x) > Layout.CORRIDOR / 2 then
		-- inside a room cell? rooms start behind the walkway of their row
		local rel = (p.z - r.z1) % Layout.ROW_PITCH
		if rel >= Layout.WALKWAY then
			return 0.4
		end
	end
	return 0.12
end

-- World CFrame at plot-local point facing direction (dx, dz) in plot space.
local function worldCF(index, p, dx, dz, y)
	local cf = plotCF(index)
	local pos = cf * Vector3.new(p.x, y or floorY(p), p.z)
	local dir = cf:VectorToWorldSpace(Vector3.new(dx, 0, dz))
	if dir.Magnitude < 1e-3 then
		dir = cf.LookVector
	end
	return CFrame.lookAt(pos, pos + dir)
end

local function cameraPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function npcCap()
	local density = State.data and State.data.settings and State.data.settings.npcDensity or 1
	return CAPS[density] or 32
end

local function makeBillboard(model, adornee, text, color, sub)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Size = UDim2.fromScale(5, sub and 1.1 or 0.6)
	bb.StudsOffset = Vector3.new(0, 1.8, 0)
	bb.MaxDistance = 70
	bb.Adornee = adornee
	bb.Parent = model
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, sub and 0.55 or 1, 0)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.Parent = bb
	if sub then
		local s = l:Clone()
		s.Position = UDim2.new(0, 0, 0.55, 0)
		s.Size = UDim2.new(1, 0, 0.45, 0)
		s.Text = sub
		s.Font = Enum.Font.GothamBold
		s.TextColor3 = Color3.fromRGB(220, 220, 220)
		s.Parent = bb
	end
	return bb
end

local function roomInfo(plotIndex, slot)
	local snap = State.plots[plotIndex]
	return snap and snap.rooms and snap.rooms[tostring(slot)] or nil
end

-- Moves for a room: discipline moves or general-room moves.
local function movesFor(plotIndex, slot, discipline)
	local disc = discipline and Disciplines.byId[discipline]
	if disc then
		return disc.moves
	end
	local info = roomInfo(plotIndex, slot)
	return (info and Poses.roomMoves[info.id]) or Poses.roomMoves.fitness_room
end

local function playMoveSounds(entry, move, tPrev, tNow, position)
	if not audio or not move.sounds then
		return
	end
	if (position - cameraPos()).Magnitude > 60 then
		return
	end
	local len = move.length
	local a, b = tPrev % len, tNow % len
	for _, s in ipairs(move.sounds) do
		local crossed = (a <= b and s.t > a and s.t <= b) or (a > b and (s.t > a or s.t <= b))
		if crossed and (not s.chance or entry.rng:next() < s.chance) then
			audio.playAt(s.name, position)
		end
	end
end

---------------------------------------------------------------- visitors

local function createVisitorRig(entry)
	local plan = entry.plan
	local spec = Appearance.describe({
		seed = plan.seed,
		discipline = Disciplines.byId[plan.interest] and plan.interest or nil,
		role = "student",
		rank = plan.rank or 1,
		category = plan.category,
	})
	local rig = Rig.build(spec, { name = "Visitor" })
	local cat = Customers.byId[plan.category]
	if cat and cat.celebrity then
		makeBillboard(rig.model, rig.parts.Head, "★ " .. (plan.name or "Celebrity"), Color3.fromRGB(255, 200, 80), "Celebrity")
	elseif cat and cat.vip then
		makeBillboard(rig.model, rig.parts.Head, "VIP", Color3.fromRGB(212, 175, 55))
	end
	rig.model.Parent = folder
	entry.rig = rig
	entry.rng = RNG.new(plan.seed)
end

local function destroyRig(entry)
	if entry.rig then
		entry.rig.model:Destroy()
		entry.rig = nil
	end
end

-- Is the partner seat of a pair station taken in the same class session?
local function partnerPresent(entry, st)
	if not st.pair then
		return false
	end
	local plan = entry.plan
	local seats = sessionSeats[entry.plot .. ":" .. plan.slot .. "@" .. tostring(plan.tSession)]
	return seats ~= nil and seats[st.pair] == true
end

local function visitorPose(entry, now)
	local plan = entry.plan
	local p, hx, hz, phase, seg = Visits.sample(entry.segs, now)
	local moves = movesFor(entry.plot, plan.slot, plan.interest)
	local move, t
	local dx, dz = hx, hz
	local y
	local st = seg and seg.station
	if st and (phase == "ready" or phase == "train" or phase == "amenity") then
		dx, dz = Stations.faceVector(st.face)
		y = st.y
	end
	if phase == "walk" then
		move, t = Poses.moves.walk, now - plan.t0
	elseif phase == "queue" then
		move, t = Poses.moves.queue, now + plan.seed % 7
		dx, dz = 0, 1
	elseif phase == "wait" then
		move, t = Poses.moves.wait, now + plan.seed % 5
		dx, dz = 0, 1
	elseif phase == "ready" then
		move, t = Poses.moves[moves.idle] or Poses.moves.idle, now
	elseif phase == "train" then
		local key = entry.plot .. ":" .. tostring(plan.slot)
		local since = now - plan.tSession
		if rankups[key] and now < rankups[key] then
			move, t = Poses.moves.rankup, now - (rankups[key] - 2.2)
		else
			local period = math.floor(since / DRILL_PERIOD)
			local pairMoves = moves.pair
			local hasPartner = st and partnerPresent(entry, st)
			if st and st.ring and hasPartner then
				-- sparring / bout practice with the partner in the ring or on the dohyo
				local list = st.moves or (pairMoves and { pairMoves[1] }) or moves.drill
				move = Poses.moves[list[(period + plan.spot) % #list + 1]] or Poses.moves.idle
			elseif hasPartner and pairMoves and period % 2 == 1 and (plan.classTier or 1) >= 2 then
				-- partner drill: the lower station throws / attacks, the other receives
				move = Poses.moves[(plan.spot < st.pair) and pairMoves[1] or pairMoves[2]]
			elseif st and st.moves then
				-- equipment station: bag, makiwara, machine... uses its own moves
				move = Poses.moves[st.moves[(period + plan.spot) % #st.moves + 1]] or Poses.moves.idle
			else
				-- formation: the whole class performs the same technique in sync
				local drill = moves.drill
				local idx = (math.floor(plan.tSession) + period) % #drill + 1
				move = Poses.moves[drill[idx]] or Poses.moves.idle
			end
			t = since % DRILL_PERIOD
		end
	elseif phase == "amenity" then
		local list = st and st.moves or { "idle" }
		move, t = Poses.moves[list[1]] or Poses.moves.idle, now + plan.seed % 9
	else
		return nil
	end
	return worldCF(entry.plot, p, dx, dz, y), move, t
end

local function addPlans(plotIndex, list)
	for _, plan in ipairs(list) do
		local key = plotIndex .. ":" .. plan.id
		local segs = Visits.timeline(plan)
		visitors[key] = { key = key, plot = plotIndex, plan = plan, segs = segs, lastT = 0 }
		if plan.outcome == "train" and plan.slot then
			-- seat reservations of this class session (for partner drills)
			local seatKey = plotIndex .. ":" .. plan.slot .. "@" .. tostring(plan.tSession)
			sessionSeats[seatKey] = sessionSeats[seatKey] or { expires = plan.tEnd + 30 }
			sessionSeats[seatKey][plan.spot] = true
			local skey = plotIndex .. ":" .. plan.slot
			local s = sessions[skey]
			if not s or plan.tEnd > s.tEnd then
				sessions[skey] = { tSession = plan.tSession, tEnd = plan.tEnd }
			end
		end
	end
end

local function clearPlot(plotIndex)
	for key, entry in pairs(visitors) do
		if entry.plot == plotIndex then
			destroyRig(entry)
			visitors[key] = nil
		end
	end
	if champs[plotIndex] then
		for _, f in ipairs(champs[plotIndex].fighters) do
			f.model:Destroy()
		end
		champs[plotIndex] = nil
	end
end

---------------------------------------------------------------- trainers & staff

local function trainerKey(t)
	return tostring(t.seed) .. ":" .. t.discipline .. ":" .. t.rarity
end

local function syncTrainers()
	local wanted = {}
	for plotIndex, snap in pairs(State.plots) do
		if snap.rooms then
			for slot, room in pairs(snap.rooms) do
				if room.trainer and not room.building and slot ~= "0" then
					local key = plotIndex .. ":" .. slot
					wanted[key] = true
					local t = room.trainer
					local existing = trainers[key]
					if existing and existing.sig ~= trainerKey(t) then
						if existing.rig then
							existing.rig.model:Destroy()
						end
						trainers[key] = nil
						existing = nil
					end
					if not existing then
						trainers[key] = { key = key, plot = plotIndex, slot = tonumber(slot), trainer = t, sig = trainerKey(t), roomId = room.id, level = room.level }
					else
						existing.roomId = room.id
						existing.level = room.level
					end
				end
			end
		end
	end
	for key, entry in pairs(trainers) do
		if not wanted[key] then
			if entry.rig then
				entry.rig.model:Destroy()
			end
			trainers[key] = nil
		end
	end
	-- receptionists for owned plots
	for plotIndex, snap in pairs(State.plots) do
		if snap.ownerId and not staff[plotIndex] then
			staff[plotIndex] = { plot = plotIndex, seed = snap.ownerId % 100000 + plotIndex }
		elseif not snap.ownerId and staff[plotIndex] then
			if staff[plotIndex].rig then
				staff[plotIndex].rig.model:Destroy()
			end
			staff[plotIndex] = nil
		end
	end
end

local function createTrainerRig(entry)
	local t = entry.trainer
	local spec = Appearance.describe({ seed = t.seed, discipline = t.discipline, role = "trainer", rarity = t.rarity })
	local rig = Rig.build(spec, { name = "Trainer" })
	local r = Trainers.rarityById[t.rarity]
	local disc = Disciplines.byId[t.discipline]
	local color = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
	makeBillboard(rig.model, rig.parts.Head, (disc and disc.trainerTitle or "Coach") .. " " .. t.name, color, r.name .. (t.title and (" • " .. t.title) or ""))
	rig.model.Parent = folder
	entry.rig = rig
	entry.rng = RNG.new(t.seed)
end

local function trainerPose(entry, now)
	local key = entry.plot .. ":" .. entry.slot
	local s = sessions[key]
	local teaching = s and now >= s.tSession and now <= s.tEnd
	local moves = movesFor(entry.plot, entry.slot, Disciplines.byId[entry.trainer.discipline] and entry.trainer.discipline or nil)
	local move
	local info = Stations.forRoom(entry.roomId, entry.level or 1)
	local spot = info.trainer or { x = 0, z = info.d - 3, face = 180 }
	if rankups[key] and now < rankups[key] then
		move = Poses.moves.coach_clap
	elseif teaching and spot.pads then
		-- pad work with the student in front of the ring
		local period = math.floor((now - s.tSession) / DRILL_PERIOD)
		move = Poses.moves[period % 3 == 2 and "coach_point" or "coach_mitts"]
	elseif teaching and moves.teach then
		local period = math.floor((now - s.tSession) / DRILL_PERIOD)
		move = Poses.moves[moves.teach[period % #moves.teach + 1]] or Poses.moves.coach_point
	else
		move = Poses.moves[moves.idle] or Poses.moves.idle
	end
	local p = Stations.plotPoint(entry.slot, entry.roomId, entry.level or 1, spot.x, spot.z)
	local dx, dz = Stations.faceVector(spot.face)
	return worldCF(entry.plot, p, dx, dz), move, now + entry.trainer.seed % 10
end

---------------------------------------------------------------- championships

local function startChamp(plotIndex, info)
	local previous = champs[plotIndex]
	if previous then
		for _, f in ipairs(previous.fighters) do
			f.model:Destroy()
		end
	end
	local fighters = {}
	for i, seed in ipairs({ info.seedA, info.seedB }) do
		local spec = Appearance.describe({ seed = seed, discipline = info.discipline, role = "student", rank = 6, category = "professional" })
		local rig = Rig.build(spec, { name = "Fighter" })
		rig.model.Parent = folder
		table.insert(fighters, { rig = rig, side = i == 1 and -1 or 1, model = rig.model })
	end
	champs[plotIndex] = { info = info, fighters = fighters }
end

local function updateChamp(plotIndex, c, now)
	local info = c.info
	local arena = Stations.forRoom("arena", 1)
	local centre = Stations.plotPoint(info.slot, "arena", 1, arena.extras.centre.x, arena.extras.centre.z)
	local disc = Disciplines.byId[info.discipline]
	if now > info.endAt + 4 then
		for _, f in ipairs(c.fighters) do
			f.model:Destroy()
		end
		champs[plotIndex] = nil
		return
	end
	for i, f in ipairs(c.fighters) do
		local p = { x = centre.x + f.side * 2.2, z = centre.z }
		local cf = worldCF(plotIndex, p, -f.side, 0, 1.5)
		local move, t
		if now > info.endAt then
			move = i == 1 and Poses.moves.emote_champion or Poses.moves.emote_bow
			t = now - info.endAt
		else
			local drill = disc.moves.pair or disc.moves.drill
			local period = math.floor((now - info.t0) / 3)
			move = Poses.moves[drill[(period + i) % #drill + 1]] or Poses.moves[disc.moves.idle]
			t = (now - info.t0) % 3
		end
		Rig.apply(f.rig, cf, Poses.sample(move, t))
	end
end

---------------------------------------------------------------- staff

local function createStaffRig(entry)
	local spec = Appearance.describe({ seed = entry.seed, role = "staff" })
	entry.rig = Rig.build(spec, { name = "Receptionist" })
	makeBillboard(entry.rig.model, entry.rig.parts.Head, "Reception", Color3.fromRGB(212, 175, 55))
	entry.rig.model.Parent = folder
end

---------------------------------------------------------------- frame update

local function shouldRender(position, cam)
	return (position - cam).Magnitude < RENDER_DISTANCE
end

local function step()
	frame = frame + 1
	local now = workspace:GetServerTimeNow()
	if frame % 600 == 0 then
		for k, seats in pairs(sessionSeats) do
			if seats.expires < now then
				sessionSeats[k] = nil
			end
		end
	end
	local cam = cameraPos()
	local cap = npcCap()
	local rendered = 0

	-- visitors: nearest first by plot distance
	for key, entry in pairs(visitors) do
		local plan = entry.plan
		if now > (plan.tExit or plan.t0 + 300) then
			destroyRig(entry)
			visitors[key] = nil
		elseif now >= plan.t0 then
			local origin = plotCF(entry.plot).Position
			local near = shouldRender(origin, cam) or (origin - cam).Magnitude < RENDER_DISTANCE + 100
			if near and (entry.rig or rendered < cap) then
				rendered = rendered + 1
				if not entry.rig then
					createVisitorRig(entry)
				end
				local far = (origin - cam).Magnitude > 140
				if not far or (frame + plan.id) % 3 == 0 then
					local cf, move, t = visitorPose(entry, now)
					if cf and move then
						local head = Rig.apply(entry.rig, cf, Poses.sample(move, t))
						if not far then
							playMoveSounds(entry, move, entry.lastT, t, head.Position)
						end
						entry.lastT = t
					end
				end
			elseif entry.rig then
				destroyRig(entry)
			end
		end
	end

	for _, entry in pairs(trainers) do
		local origin = plotCF(entry.plot).Position
		if shouldRender(origin, cam) then
			if not entry.rig then
				createTrainerRig(entry)
			end
			if frame % 2 == 0 or (origin - cam).Magnitude < 120 then
				local cf, move, t = trainerPose(entry, now)
				local head = Rig.apply(entry.rig, cf, Poses.sample(move, t))
				playMoveSounds(entry, move, entry.lastT or 0, t, head.Position)
				entry.lastT = t
			end
		elseif entry.rig then
			entry.rig.model:Destroy()
			entry.rig = nil
		end
	end

	for plotIndex, entry in pairs(staff) do
		local origin = plotCF(plotIndex).Position
		if shouldRender(origin, cam) then
			if not entry.rig then
				createStaffRig(entry)
			end
			if frame % 3 == 0 then
				local cf = worldCF(plotIndex, { x = Layout.desk.x, z = Layout.desk.z + 2.2 }, 0, -1)
				Rig.apply(entry.rig, cf, Poses.sample(Poses.moves.receptionist, now))
			end
		elseif entry.rig then
			entry.rig.model:Destroy()
			entry.rig = nil
		end
	end

	for plotIndex, c in pairs(champs) do
		updateChamp(plotIndex, c, now)
	end
end

function NPCController.init(audioController)
	audio = audioController
	folder = Instance.new("Folder")
	folder.Name = "ClientNPCs"
	folder.Parent = workspace
	local remote = Remotes.get("Visitors")
	remote.OnClientEvent:Connect(function(kind, plotIndex, payload)
		if kind == "plans" then
			addPlans(plotIndex, payload)
		elseif kind == "clear" then
			clearPlot(plotIndex)
		elseif kind == "champ" then
			startChamp(plotIndex, payload)
		elseif kind == "rankup" then
			local key = plotIndex .. ":" .. tostring(payload.slot)
			rankups[key] = workspace:GetServerTimeNow() + 2.2
			if audio then
				local origin = plotCF(plotIndex).Position
				if (origin - cameraPos()).Magnitude < 150 then
					audio.play("rankup")
				end
			end
		end
	end)
	State.PlotsChanged:Connect(syncTrainers)
	syncTrainers()
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[NPCController] " .. tostring(err))
		end
	end)
end

return NPCController
