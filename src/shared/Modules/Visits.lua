-- The route and timing of one visitor. The server plans a visit (key times,
-- room, station), sends the plan to clients once, and both sides derive the
-- full timeline from it with this module. Pure: no Roblox APIs.
--
-- Route: entrance -> reception queue -> central hall (inbound lane) ->
-- walkway -> room door -> entry lane -> station ... and back out through the
-- outbound lanes. Visitors wait for their class just outside the door.

local Layout = require(script.Parent.Layout)
local Stations = require(script.Parent.Stations)

local Visits = {}

Visits.AMENITY_DWELL = 6
Visits.DESK_SERVICE = 2.6

local FRONT = Layout.FRONT
local IN_X, OUT_X = Layout.LANE_IN_X, Layout.LANE_OUT_X
local HALL_Z = Layout.RECEPTION.z1 - 4 -- where the hall starts behind reception

local function append(route, points)
	for _, p in ipairs(points) do
		local last = route[#route]
		if not last or last.x ~= p.x or last.z ~= p.z then
			table.insert(route, p)
		end
	end
	return route
end

function Visits.toDesk(queueIndex)
	return {
		{ x = Layout.entrance.x - 2, z = Layout.entrance.z },
		{ x = IN_X, z = FRONT + 3 },
		Layout.queueSpot(queueIndex),
	}
end

-- From the desk through the hall to just in front of a room door.
function Visits.deskToDoor(queueIndex, slot)
	local s = Layout.slot(slot)
	return {
		Layout.queueSpot(queueIndex),
		{ x = IN_X, z = HALL_Z },
		{ x = IN_X, z = s.walkIn },
		{ x = s.door.x, z = s.walkIn },
		{ x = s.door.x, z = s.door.z - 0.5 },
	}
end

-- Waiting area: along the room front in the walkway, spread out by station.
function Visits.waitSpot(slot, spot)
	local s = Layout.slot(slot)
	local k = (spot - 1) % 8
	local offset = (k - 3.5) * 2.2
	if math.abs(offset) < 2 then
		offset = offset < 0 and -2.4 or 2.4 -- keep the doorway itself free
	end
	return { x = s.door.x + offset, z = s.door.z - 1.6 - math.floor((spot - 1) / 8) * 1.8 }
end

-- From the room door into the hall's outbound lane (ends at the hall).
local function doorToHall(slot)
	local s = Layout.slot(slot)
	return {
		{ x = s.door.x, z = s.door.z - 0.5 },
		{ x = s.door.x, z = s.walkOut },
		{ x = OUT_X, z = s.walkOut },
	}
end

local function hallToExit()
	return {
		{ x = OUT_X, z = HALL_Z },
		{ x = OUT_X + 4, z = FRONT + 3 },
		{ x = OUT_X + 4, z = Layout.entrance.z },
	}
end

-- From inside a room (station) to the exit, optionally via an amenity station.
function Visits.leaveRoute(plan)
	local route = {}
	append(route, (Stations.routeOut(plan.slot, plan.roomId, plan.roomLevel, plan.spot)))
	append(route, doorToHall(plan.slot))
	append(route, hallToExit())
	return route
end

function Visits.toAmenity(plan)
	local route = {}
	append(route, (Stations.routeOut(plan.slot, plan.roomId, plan.roomLevel, plan.spot)))
	append(route, doorToHall(plan.slot))
	local a = Layout.slot(plan.amenitySlot)
	append(route, {
		{ x = OUT_X, z = a.walkIn },
		{ x = a.door.x, z = a.walkIn },
		{ x = a.door.x, z = a.door.z - 0.5 },
	})
	append(route, (Stations.routeIn(plan.amenitySlot, plan.amenityId, plan.amenityLevel, plan.amenitySpot)))
	return route
end

function Visits.amenityToExit(plan)
	local route = {}
	append(route, (Stations.routeOut(plan.amenitySlot, plan.amenityId, plan.amenityLevel, plan.amenitySpot)))
	append(route, doorToHall(plan.amenitySlot))
	append(route, hallToExit())
	return route
end

function Visits.deskToExit(queueIndex)
	return {
		Layout.queueSpot(queueIndex),
		{ x = OUT_X + 4, z = FRONT + 5 },
		{ x = OUT_X + 4, z = Layout.entrance.z },
	}
end

-- Station position (plot space) of a plan's training spot.
function Visits.stationPoint(slot, roomId, level, index)
	local info = Stations.forRoom(roomId, level)
	local st = info.stations[index] or info.stations[1]
	return Stations.plotPoint(slot, roomId, level, st.x, st.z), st
end

-- Build the timeline: ordered list of segments
--   { kind = "walk", t0, t1, points } or { kind = "stay", t0, t1, at, phase, station }
-- plan fields: t0, queue, tDeskDone, outcome ("train"/"leave"), slot, roomId,
--   roomLevel, spot, tSession, tEnd, amenitySlot, amenityId, amenityLevel, amenitySpot
function Visits.timeline(plan)
	local segs = {}
	local t = plan.t0
	local function walk(points)
		local t1 = t + Layout.walkTime(points)
		table.insert(segs, { kind = "walk", t0 = t, t1 = t1, points = points })
		t = t1
	end
	local function stay(untilTime, at, phase, station)
		if untilTime > t then
			table.insert(segs, { kind = "stay", t0 = t, t1 = untilTime, at = at, phase = phase, station = station })
			t = untilTime
		end
	end

	walk(Visits.toDesk(plan.queue))
	stay(plan.tDeskDone, Layout.queueSpot(plan.queue), "queue")
	if plan.outcome ~= "train" then
		walk(Visits.deskToExit(plan.queue))
		return segs, t
	end
	walk(Visits.deskToDoor(plan.queue, plan.slot))
	local inside, st = Stations.routeIn(plan.slot, plan.roomId, plan.roomLevel, plan.spot)
	local spotWalk = Layout.walkTime(inside)
	local spotPoint = inside[#inside]
	if plan.tSession - spotWalk > t + 0.5 then
		-- wait outside the door until the previous class has left
		local door = inside[1]
		local waitPoint = Visits.waitSpot(plan.slot, plan.spot)
		walk({ door, waitPoint })
		stay(plan.tSession - spotWalk - Layout.walkTime({ waitPoint, door }), waitPoint, "wait")
		walk({ waitPoint, door })
	end
	walk(inside)
	stay(plan.tSession, spotPoint, "ready", st)
	stay(plan.tEnd, spotPoint, "train", st)
	if plan.amenitySlot then
		local route = Visits.toAmenity(plan)
		walk(route)
		local _, ast = Visits.stationPoint(plan.amenitySlot, plan.amenityId, plan.amenityLevel, plan.amenitySpot)
		stay(t + Visits.AMENITY_DWELL, route[#route], "amenity", ast)
		walk(Visits.amenityToExit(plan))
	else
		walk(Visits.leaveRoute(plan))
	end
	return segs, t
end

-- Position at time `now`: returns point, heading x/z, phase, segment.
function Visits.sample(segs, now)
	for _, seg in ipairs(segs) do
		if now < seg.t1 then
			if seg.kind == "walk" then
				local dist = (math.max(now, seg.t0) - seg.t0) * Layout.WALK_SPEED
				local p, hx, hz = Layout.pointAlong(seg.points, dist)
				return p, hx, hz, "walk", seg
			end
			return seg.at, nil, nil, seg.phase, seg
		end
	end
	local last = segs[#segs]
	if last.kind == "walk" then
		return last.points[#last.points], 0, -1, "gone", last
	end
	return last.at, nil, nil, "gone", last
end

return Visits
