-- Training positions ("stations") of every room. A station is where one
-- student trains: in front of a heavy bag, in the ring, on a tatami pair spot,
-- on the dohyo, on a treadmill... The room builder places the equipment AT the
-- station, the simulation hands out one station per seat (so two students
-- never share a spot), and the client poses the student there with the
-- station's moves. Pure Lua, deterministic, shared by server and client.
--
-- Room-local coordinates: x across the room (0 = door), z from the front wall
-- (0) to the back wall (d). The strip 0 < z < 4 is the entry lane and is kept
-- free so nobody blocks the door.
--   station = { x, z, face, y, kind, moves, prop, propX, propZ, propFace, lane, pair, ring }
--   face: direction the student looks, degrees: 0 = towards the back wall,
--         90 = towards +x, 180 = towards the door, 270 = towards -x.
-- Students fill stations in list order, so the list is ordered by priority
-- (equipment first, then the formation / free-practice spots, back rows first
-- so later students do not walk through earlier ones).

local Config = script.Parent.Parent.Config
local Rooms = require(Config.Rooms)
local Layout = require(script.Parent.Layout)

local Stations = {}

Stations.LANE_Z = 2.2 -- entry lane inside the room

-- Which layout a room uses.
local TEMPLATE = {
	karate_room = "formation", taekwondo_room = "formation", kungfu_room = "formation", kravmaga_room = "formation",
	boxing_room = "striking", kickboxing_room = "striking", muaythai_room = "striking", mma_room = "striking",
	judo_room = "grappling", bjj_room = "grappling", wrestling_room = "grappling",
	sumo_room = "sumo",
	fitness_room = "fitness", strength_room = "fitness", cardio_room = "fitness",
	coaching_room = "coaching", vip_room = "coaching",
	locker_room = "amenity", showers = "amenity", restrooms = "amenity", recovery_room = "amenity",
	juice_bar = "amenity", merch_shop = "amenity",
	arena = "arena",
}
Stations.TEMPLATE = TEMPLATE

-- Side equipment per discipline (formation and grappling rooms).
local SIDE_PROP = {
	karate = { prop = "makiwara", moves = { "karate_punch", "karate_block" } },
	taekwondo = { prop = "kick_target", moves = { "tkd_turning_kick", "tkd_side_kick" } },
	kungfu = { prop = "wooden_dummy", moves = { "kungfu_block", "kungfu_palm" } },
	kravmaga = { prop = "bob_dummy", moves = { "krav_palm", "krav_knee" } },
	judo = { prop = "throw_dummy", moves = { "judo_grip", "judo_throw" } },
	bjj = { prop = "grapple_dummy", moves = { "bjj_guard", "bjj_submission" }, floor = true },
	wrestling = { prop = "grapple_dummy", moves = { "wrestling_shot", "wrestling_sprawl" }, floor = true },
}

-- Bag work per striking discipline.
local BAG = {
	boxing = { prop = "heavy_bag", moves = { "boxing_combo", "boxing_jab", "boxing_hook", "boxing_uppercut" } },
	kickboxing = { prop = "heavy_bag", moves = { "kickboxing_combo", "kick_roundhouse", "boxing_combo" } },
	muaythai = { prop = "heavy_bag_long", moves = { "kick_roundhouse", "muaythai_knee", "muaythai_elbow", "muaythai_teep" } },
	mma = { prop = "heavy_bag", moves = { "boxing_combo", "kick_roundhouse", "boxing_hook" } },
}

-- Evenly spaced positions centred on 0 that fit within [-half, half].
local function centred(half, step)
	local n = math.max(1, math.floor((2 * half) / step + 1e-6) + 1)
	local out = {}
	local start = -(n - 1) * step / 2
	for i = 0, n - 1 do
		table.insert(out, start + i * step)
	end
	return out
end
Stations.centred = centred

local function add(list, st)
	st.lane = st.lane or st.x
	table.insert(list, st)
	return #list
end

-- A grid of formation spots, back rows first, centre columns first.
local function formation(list, halfW, zFrom, zTo, step, moves)
	local cols = centred(halfW, step)
	local z = zFrom
	while z >= zTo - 0.01 do
		-- pair neighbouring columns for partner drills (kumite)
		local rowStart = #list + 1
		for _, cx in ipairs(cols) do
			add(list, { x = cx, z = z, face = 0, kind = "line", moves = moves })
		end
		for i = rowStart, #list - 1, 2 do
			list[i].pair = i + 1
			list[i + 1].pair = i
		end
		z = z - step
	end
end

local function sideStations(list, w, d, count, spec, zStart)
	local half = w / 2
	local z = zStart or 8
	local n = 0
	while n < count and z <= d - 6 do
		for _, side in ipairs({ -1, 1 }) do
			if n < count then
				local face = side > 0 and 90 or 270
				local floor = spec.floor
				add(list, {
					-- floor dummies are 4.6 studs long: keep their legs off the wall
					x = side * (half - (floor and 5.2 or 3.6)), z = z, face = face, kind = "equipment",
					moves = spec.moves, prop = spec.prop, propX = side * (half - (floor and 3.3 or 1.6)), propZ = z,
					propFace = face + 180, lane = side * (half - 6.5),
				})
				n = n + 1
			end
		end
		z = z + 5.5
	end
end

local function templateFormation(def, level, w, d)
	local disc = def.discipline
	local list = {}
	local trainer = { x = 0, z = d - 3.5, face = 180 }
	local side = SIDE_PROP[disc]
	if side then
		sideStations(list, w, d, math.min(2 + level - 1, 6), side, 8)
	end
	formation(list, w / 2 - 9, d - 8, 7, 3.2, nil)
	return list, trainer, { decor = { "mirror_wall", "belt_display", "kamiza_back" } }
end

local function templateStriking(def, level, w, d)
	local disc = def.discipline
	local list = {}
	local half = w / 2
	local centre = disc == "mma" and "octagon" or "ring"
	local ringZ = d - 6
	local bag = BAG[disc] or BAG.boxing
	-- heavy bags along both side walls
	local bags = math.min(2 + 2 * (level - 1), 8)
	sideStations(list, w, d, bags, bag, 7)
	-- sparring pair inside the ring / octagon (raised floor)
	local a = add(list, { x = -2.2, z = ringZ, face = 90, y = 1.45, kind = "ring", ring = true })
	local b = add(list, { x = 2.2, z = ringZ, face = 270, y = 1.45, kind = "ring", ring = true })
	list[a].pair, list[b].pair = b, a
	-- speed bags on the back wall next to the ring (boxing, kickboxing)
	if (disc == "boxing" or disc == "kickboxing") and half >= 15 then
		for _, side in ipairs({ -1, 1 }) do
			add(list, {
				x = side * (half - 9), z = d - 3.2, face = 0, kind = "speedbag", moves = { "boxing_speedbag" },
				prop = "speed_bag", propX = side * (half - 9), propZ = d - 1.4, propFace = 180, lane = side * (half - 9),
			})
		end
	end
	-- pad work with the trainer in front of the ring
	local trainer = { x = 0, z = ringZ - 6.5, face = 180, pads = true }
	add(list, { x = 0, z = ringZ - 9, face = 0, kind = "pads", moves = { "boxing_combo", "boxing_jab", "boxing_cross" } })
	-- shadow boxing / footwork in the open middle
	formation(list, half - 10, ringZ - 12, 7, 3.4, nil)
	return list, trainer, { centre = { prop = centre, x = 0, z = ringZ } }
end

local function templateGrappling(def, level, w, d)
	local disc = def.discipline
	local list = {}
	local half = w / 2
	-- partner pairs facing each other on the mat, back rows first
	local z = d - 6.5
	while z >= 7 do
		for _, cx in ipairs(centred(half - 9, 7.5)) do
			local a = add(list, { x = cx - 1.5, z = z, face = 90, kind = "pair" })
			local b = add(list, { x = cx + 1.5, z = z, face = 270, kind = "pair" })
			list[a].pair, list[b].pair = b, a
		end
		z = z - 5
	end
	local side = SIDE_PROP[disc]
	if side then
		-- dummies go first so they are always in use
		local dummies = {}
		sideStations(dummies, w, d, math.min(2 + level - 1, 6), side, 8)
		for i = #dummies, 1, -1 do
			table.insert(list, 1, dummies[i])
		end
		-- fix pair indexes after the insert
		local shift = #dummies
		for i = shift + 1, #list do
			if list[i].pair then
				list[i].pair = list[i].pair + shift
			end
		end
	end
	local trainer = { x = 0, z = d - 2.6, face = 180 }
	return list, trainer, { decor = { "belt_display", "kamiza_back" } }
end

local BASE_HALF = 8 -- half the size of the dohyo's square base (Props.dohyo_round)

local function templateSumo(def, level, w, d)
	local list = {}
	local half = w / 2
	local cz = d / 2 + 2
	-- teppo posts on the side walls
	for _, side in ipairs({ -1, 1 }) do
		add(list, {
			x = side * (half - 3.6), z = cz, face = side > 0 and 90 or 270, kind = "equipment", moves = { "sumo_teppo" },
			prop = "teppo_post", propX = side * (half - 1.4), propZ = cz, propFace = side > 0 and 270 or 90, lane = side * (half - 6.5),
		})
	end
	-- bout practice on the dohyo
	local a = add(list, { x = -1.7, z = cz, face = 90, y = 1.4, kind = "ring", ring = true, moves = { "sumo_push", "sumo_tachiai" } })
	local b = add(list, { x = 1.7, z = cz, face = 270, y = 1.4, kind = "ring", ring = true, moves = { "sumo_push", "sumo_tachiai" } })
	list[a].pair, list[b].pair = b, a
	-- shiko and balance around the dohyo, facing its centre
	local radius = 9.2
	for i = 0, 11 do
		local ang = math.rad(-165 + i * 30)
		local x = math.sin(ang) * radius
		local z = cz + math.cos(ang) * radius
		if z > 5 and z < d - 1.5 and math.abs(x) < half - 2 then
			-- standing at angle ang around the centre, looking back at the centre
			local face = (math.deg(ang) + 180) % 360
			-- the dohyo stands on a 16x16 base (0.9 high): corner spots stand on
			-- the base, spots behind the dohyo are reached around its side
			local onBase = math.abs(x) < BASE_HALF + 0.4 and math.abs(z - cz) < BASE_HALF + 0.4
			local lane = x
			if z > cz and math.abs(x) < BASE_HALF + 1.2 then
				lane = (x < 0 and -1 or 1) * (BASE_HALF + 1.5)
			end
			add(list, { x = x, z = z, face = face, y = onBase and 0.9 or nil, lane = lane, kind = "line", moves = { "sumo_shiko", "sumo_crouch", "sumo_shiko" } })
		end
	end
	local trainer = { x = 0, z = d - 1.8, face = 180 }
	return list, trainer, { centre = { prop = "dohyo_round", x = 0, z = cz } }
end

-- Machines per fitness room: prop, move, how high the user stands/lies.
-- ahead: prop distance in front of the student; propFace: prop orientation
-- (0 = the machine's front points the same way the student looks).
local MACHINES = {
	fitness_room = {
		{ prop = "mat", moves = { "fitness_pushup", "fitness_squat", "fitness_jumping_jack", "fitness_lunge" }, propFace = 0 },
		{ prop = "dumbbell_rack", moves = { "fitness_curl", "fitness_lift" }, ahead = 1.9, propFace = 180 },
		{ prop = "mat", moves = { "fitness_squat", "fitness_lunge", "fitness_pushup" }, propFace = 0 },
		{ prop = "kettlebell_set", moves = { "fitness_lift", "fitness_squat" }, ahead = 1.6, propFace = 180 },
	},
	strength_room = {
		{ prop = "squat_rack", moves = { "fitness_squat_bar" }, propFace = 0 },
		{ prop = "bench_press", moves = { "fitness_bench" }, y = 1.95, propFace = 180 },
		{ prop = "pullup_bar", moves = { "fitness_pullup" }, propFace = 0 },
		{ prop = "dumbbell_rack", moves = { "fitness_curl" }, ahead = 1.9, propFace = 180 },
	},
	cardio_room = {
		{ prop = "treadmill", moves = { "fitness_run" }, y = 0.75, propFace = 0 },
		{ prop = "bike", moves = { "fitness_cycle" }, y = 2.95, propFace = 0 },
		{ prop = "rower", moves = { "fitness_row" }, y = 1.2, propFace = 0 },
	},
}

local function templateFitness(def, level, w, d)
	local list = {}
	local machines = MACHINES[def.id] or MACHINES.fitness_room
	local half = w / 2
	local i = 0
	local z = d - 4.5
	while z >= 7.5 do
		-- racks and benches are 5.5 studs wide: strength machines need wider columns
		local spacing = def.id == "strength_room" and 7.4 or 5.5
		for _, x in ipairs(centred(half - 4, spacing)) do
			i = i + 1
			local m = machines[(i - 1) % #machines + 1]
			add(list, {
				x = x, z = z, face = 0, y = m.y, kind = "machine", moves = m.moves, prop = m.prop,
				-- walk in between the machine columns, not through the machines in front
				propX = x, propZ = z + (m.ahead or 0), propFace = m.propFace or 0, lane = x + (x <= 0 and spacing / 2 or -spacing / 2),
			})
		end
		z = z - 5.2
	end
	local trainer = { x = 0, z = 4.8, face = 0 }
	return list, trainer, { decor = { "mirror_wall" } }
end

local function templateCoaching(def, level, w, d)
	local list = {}
	local trainer = { x = 0, z = d / 2 + 2.5, face = 180, pads = true }
	add(list, { x = 0, z = d / 2, face = 0, kind = "pads", moves = { "boxing_combo", "kick_roundhouse", "boxing_jab" } })
	sideStations(list, w, d, 4, BAG.boxing, d / 2 - 2)
	formation(list, w / 2 - 8, d / 2 - 3, 7, 3.4, nil)
	return list, trainer, { decor = { "mirror_wall" } }
end

-- Amenity "visit spots" (lockers, showers, stalls, tables, stools, shelves).
local AMENITY = {
	locker_room = { prop = "locker_bank", moves = { "changing" }, along = "walls" },
	showers = { prop = "shower", moves = { "showering" }, along = "back", inside = true },
	restrooms = { prop = "stall", moves = { "idle" }, along = "back", inside = true },
	recovery_room = { prop = "massage_table", moves = { "relax_lie" }, y = 2.65, alt = { prop = "ice_bath", moves = { "relax_sit" }, y = 0.8 } },
	juice_bar = { prop = "stool", moves = { "sit_drink" }, along = "bar", y = 2.85 },
	merch_shop = { prop = "shop_shelf", moves = { "browse" }, along = "walls" },
}

local function templateAmenity(def, level, w, d)
	local list = {}
	local spec = AMENITY[def.id] or AMENITY.locker_room
	local half = w / 2
	if spec.along == "back" or spec.along == "bar" then
		for _, x in ipairs(centred(half - 3, 4)) do
			local z = spec.along == "bar" and d - 6.5 or (spec.inside and d - 2 or d - 3.4)
			add(list, {
				x = x, z = z, face = 0, y = spec.y, kind = "visit", moves = spec.moves, prop = spec.prop,
				propX = x, propZ = (spec.along == "bar" or spec.inside) and z or d - 1.6, propFace = 180, lane = x,
			})
		end
	elseif spec.along == "walls" then
		local z = 6
		while z <= d - 3 do
			for _, side in ipairs({ -1, 1 }) do
				local face = side > 0 and 90 or 270
				add(list, {
					x = side * (half - 3.4), z = z, face = face, kind = "visit", moves = spec.moves, prop = spec.prop,
					propX = side * (half - 1.3), propZ = z, propFace = face + 180, lane = side * (half - 6),
				})
			end
			z = z + 4.5
		end
	else
		local i = 0
		local z = d - 5
		while z >= 6 do
			for _, x in ipairs(centred(half - 5, 7)) do
				i = i + 1
				local s = (i % 2 == 0 and spec.alt) or spec
				add(list, { x = x, z = z, face = 0, y = s.y, kind = "visit", moves = s.moves, prop = s.prop, propX = x, propZ = z, propFace = 0, lane = x + (x <= 0 and 3.5 or -3.5) })
			end
			z = z - 7
		end
	end
	local extras = {}
	if def.id == "juice_bar" then
		extras.counters = { prop = "bar_counter", z = d - 3.6, xs = centred(half - 5, 8.4) }
	elseif def.id == "merch_shop" then
		extras.counters = { prop = "counter", z = d - 3, xs = { 0 } }
	end
	return list, nil, extras
end

local BUILDERS = {
	formation = templateFormation,
	striking = templateStriking,
	grappling = templateGrappling,
	sumo = templateSumo,
	fitness = templateFitness,
	coaching = templateCoaching,
	amenity = templateAmenity,
	arena = function(def, level, w, d)
		return {}, nil, { centre = { prop = "ring", x = 0, z = d / 2 + 4 } }
	end,
}

local cache = {}

-- Returns { stations = list, trainer = spot, extras = {...}, w, d } for a room type and level.
function Stations.forRoom(roomId, level)
	local key = roomId .. "@" .. tostring(level)
	if cache[key] then
		return cache[key]
	end
	local def = Rooms.byId[roomId]
	local w, d = Layout.roomSize(def, level)
	local builder = BUILDERS[TEMPLATE[roomId] or "formation"]
	local list, trainer, extras = builder(def, level, w, d)
	local result = { stations = list, trainer = trainer, extras = extras or {}, w = w, d = d, template = TEMPLATE[roomId] }
	cache[key] = result
	return result
end

function Stations.count(roomId, level)
	return #Stations.forRoom(roomId, level).stations
end

-- Plot-local position of a station (adds the room's position in its slot).
function Stations.plotPoint(slot, roomId, level, x, z)
	local rect = Layout.roomRect(slot, Rooms.byId[roomId], level)
	return { x = rect.cx + x, z = rect.z0 + z }
end

-- Route from the door to a station and back, in plot coordinates.
function Stations.routeIn(slot, roomId, level, index)
	local info = Stations.forRoom(roomId, level)
	local st = info.stations[index] or info.stations[1]
	local rect = Layout.roomRect(slot, Rooms.byId[roomId], level)
	local function p(x, z)
		return { x = rect.cx + x, z = rect.z0 + z }
	end
	return {
		p(0, -0.5),
		p(0, Stations.LANE_Z),
		p(st.lane, Stations.LANE_Z),
		p(st.lane, st.z),
		p(st.x, st.z),
	}, st
end

function Stations.routeOut(slot, roomId, level, index)
	local points, st = Stations.routeIn(slot, roomId, level, index)
	local out = {}
	for i = #points, 1, -1 do
		table.insert(out, points[i])
	end
	return out, st
end

-- Direction vector (plot space) for a face angle.
function Stations.faceVector(face)
	local r = math.rad(face or 0)
	return math.sin(r), math.cos(r)
end

return Stations
