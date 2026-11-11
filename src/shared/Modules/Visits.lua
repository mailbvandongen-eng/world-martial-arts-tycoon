-- The route and timing of one visitor. The server plans a visit (key times and
-- places), sends the plan to clients once, and both sides derive the full
-- timeline from it with this module. Pure: no Roblox APIs.

local Layout = require(script.Parent.Layout)

local Visits = {}

Visits.AMENITY_DWELL = 5
Visits.DESK_SERVICE = 2.6

local FRONT = Layout.FRONT

function Visits.toDesk(queueIndex)
	return {
		{ x = Layout.entrance.x, z = Layout.entrance.z },
		{ x = 0, z = FRONT + 2 },
		Layout.queueSpot(queueIndex),
	}
end

function Visits.deskToDoor(queueIndex, slot)
	local s = Layout.slot(slot)
	return {
		Layout.queueSpot(queueIndex),
		{ x = 0, z = FRONT + 18 },
		{ x = 0, z = s.walkZ },
		{ x = s.door.x, z = s.walkZ },
		{ x = s.door.x, z = s.door.z + 1.5 },
	}
end

function Visits.doorToSpot(slot, spot)
	local s = Layout.slot(slot)
	return {
		{ x = s.door.x, z = s.door.z + 1.5 },
		Layout.trainingSpot(slot, spot),
	}
end

-- Out of the room, to the amenity (if any). Ends inside the amenity or at the corridor.
function Visits.spotToAmenity(slot, spot, amenitySlot)
	local s = Layout.slot(slot)
	local a = Layout.slot(amenitySlot)
	return {
		Layout.trainingSpot(slot, spot),
		{ x = s.door.x, z = s.door.z + 1.5 },
		{ x = s.door.x, z = s.walkZ },
		{ x = 0, z = s.walkZ },
		{ x = 0, z = a.walkZ },
		{ x = a.door.x, z = a.walkZ },
		{ x = a.door.x, z = a.door.z + 5 },
	}
end

function Visits.amenityToExit(amenitySlot)
	local a = Layout.slot(amenitySlot)
	return {
		{ x = a.door.x, z = a.door.z + 5 },
		{ x = a.door.x, z = a.walkZ },
		{ x = 0, z = a.walkZ },
		{ x = 0, z = FRONT + 18 },
		{ x = 6, z = FRONT + 2 },
		{ x = 6, z = Layout.entrance.z },
	}
end

function Visits.spotToExit(slot, spot)
	return Layout.routeOut(slot, spot, nil)
end

function Visits.deskToExit(queueIndex)
	return {
		Layout.queueSpot(queueIndex),
		{ x = 6, z = FRONT + 4 },
		{ x = 6, z = Layout.entrance.z },
	}
end

-- Where visitors wait for their class: just outside the door, spread out.
function Visits.waitSpot(slot, spot)
	local s = Layout.slot(slot)
	local offset = ((spot - 1) % 6 - 2.5) * 2
	return { x = s.door.x + offset, z = s.walkZ - 1.5 + math.floor((spot - 1) / 6) * 0.0 }
end

-- Build the timeline: ordered list of segments
--   { kind = "walk", t0, t1, points } or { kind = "stay", t0, t1, at, phase }
-- plan fields: t0, queue, tDeskDone, outcome ("train" or "leave"), slot, spot,
--              tSession, tEnd, amenitySlot
function Visits.timeline(plan)
	local segs = {}
	local t = plan.t0
	local function walk(points)
		local t1 = t + Layout.walkTime(points)
		table.insert(segs, { kind = "walk", t0 = t, t1 = t1, points = points })
		t = t1
	end
	local function stay(untilTime, at, phase)
		if untilTime > t then
			table.insert(segs, { kind = "stay", t0 = t, t1 = untilTime, at = at, phase = phase })
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
	local toSpot = Visits.doorToSpot(plan.slot, plan.spot)
	local spotWalk = Layout.walkTime(toSpot)
	local waitPoint = Visits.waitSpot(plan.slot, plan.spot)
	if plan.tSession - spotWalk > t + 0.5 then
		-- step aside and wait for the class to start
		local aside = { { x = toSpot[1].x, z = toSpot[1].z }, waitPoint }
		walk(aside)
		stay(plan.tSession - spotWalk - Layout.walkTime(aside), waitPoint, "wait")
		walk({ waitPoint, toSpot[1], toSpot[2] })
	else
		walk(toSpot)
	end
	stay(plan.tSession, toSpot[2], "ready")
	stay(plan.tEnd, toSpot[2], "train")
	if plan.amenitySlot then
		walk(Visits.spotToAmenity(plan.slot, plan.spot, plan.amenitySlot))
		local a = Layout.slot(plan.amenitySlot)
		stay(t + Visits.AMENITY_DWELL, { x = a.door.x, z = a.door.z + 5 }, "amenity")
		walk(Visits.amenityToExit(plan.amenitySlot))
	else
		walk(Visits.spotToExit(plan.slot, plan.spot))
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
