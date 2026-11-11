-- Geometry of an academy plot in plot-local coordinates (studs).
-- x = right, z = depth (entrance at the front, z = -DEPTH/2), y is up.
-- Pure numbers ({x = , z = }) so the server and client compute identical
-- routes and the offline tests can check them.
--
--   back  z = +100
--   row 5 rooms   [o][i] corridor [i][o]
--         walkway ------------------------
--   ...
--   row 1 rooms
--         walkway ------------------------
--   reception (front, z -100 .. -76)
--   front z = -100 (entrance)

local Layout = {}

Layout.WIDTH = 150
Layout.DEPTH = 200
Layout.ROOM_W = 28
Layout.ROOM_D = 24
Layout.WALKWAY = 8
Layout.ROW_PITCH = 32
Layout.ROWS = 5
Layout.MAX_SLOTS = 20
Layout.WALL_H = 12
Layout.WALK_SPEED = 9 -- studs per second for visitors

local FRONT = -Layout.DEPTH / 2
Layout.FRONT = FRONT
Layout.RECEPTION = { x0 = -30, x1 = 30, z0 = FRONT, z1 = FRONT + 24 }
local ROW0 = Layout.RECEPTION.z1 -- -76

local COLUMN_X = { -52, -22, 22, 52 }
local FILL_ORDER = { 2, 3, 1, 4 } -- inner columns first

-- Slot index (1..20) -> rectangle and door.
function Layout.slot(index)
	local row = math.floor((index - 1) / 4) + 1
	local col = FILL_ORDER[((index - 1) % 4) + 1]
	local walkZ = ROW0 + (row - 1) * Layout.ROW_PITCH
	local z0 = walkZ + Layout.WALKWAY
	local cx = COLUMN_X[col]
	return {
		index = index,
		row = row,
		col = col,
		cx = cx,
		cz = z0 + Layout.ROOM_D / 2,
		x0 = cx - Layout.ROOM_W / 2,
		x1 = cx + Layout.ROOM_W / 2,
		z0 = z0,
		z1 = z0 + Layout.ROOM_D,
		walkZ = walkZ + Layout.WALKWAY / 2,
		door = { x = cx, z = z0 },
	}
end

Layout.entrance = { x = 0, z = FRONT - 6 }
Layout.desk = { x = -10, z = FRONT + 14 } -- reception desk centre
Layout.register = { x = 12, z = FRONT + 10 } -- cash register pad (collect)
Layout.receptionExit = { x = 0, z = ROW0 + 2 }

-- Queue spot q (1-based) in front of the desk.
function Layout.queueSpot(q)
	local col = (q - 1) % 6
	local row = math.floor((q - 1) / 6)
	return { x = -10 + (col - 2.5) * 3, z = FRONT + 8 - row * 3 }
end

-- Student spot inside a room. Grid of 6 x 4 in front of the trainer.
-- The back of the room (z0 + 16 .. z1) holds the centrepiece (ring, dohyo, ...).
function Layout.trainingSpot(slotIndex, spot)
	local s = Layout.slot(slotIndex)
	local col = (spot - 1) % 6
	local row = math.floor((spot - 1) / 6)
	return { x = s.cx + (col - 2.5) * 3.5, z = s.z0 + 3.5 + row * 2.8 }
end

-- Trainer stands at the back, facing the students (and the door).
function Layout.trainerSpot(slotIndex)
	local s = Layout.slot(slotIndex)
	return { x = s.cx, z = s.z0 + 14.2 }
end

-- Route from the entrance to the room door and in (list of points).
-- includeQueue: visitor first stands at queue spot q at the desk.
function Layout.routeIn(slotIndex, queueIndex, spot)
	local s = Layout.slot(slotIndex)
	local points = {
		{ x = Layout.entrance.x, z = Layout.entrance.z },
		{ x = 0, z = FRONT + 2 },
	}
	if queueIndex then
		table.insert(points, Layout.queueSpot(queueIndex))
	end
	table.insert(points, { x = 0, z = FRONT + 18 })
	table.insert(points, { x = 0, z = s.walkZ })
	table.insert(points, { x = s.door.x, z = s.walkZ })
	table.insert(points, { x = s.door.x, z = s.door.z + 1.5 })
	if spot then
		table.insert(points, Layout.trainingSpot(slotIndex, spot))
	end
	return points
end

-- Route from inside a room back out (optionally via an amenity room) to the exit.
function Layout.routeOut(slotIndex, spot, amenitySlot)
	local s = Layout.slot(slotIndex)
	local points = {}
	if spot then
		table.insert(points, Layout.trainingSpot(slotIndex, spot))
	end
	table.insert(points, { x = s.door.x, z = s.door.z + 1.5 })
	table.insert(points, { x = s.door.x, z = s.walkZ })
	if amenitySlot then
		local a = Layout.slot(amenitySlot)
		table.insert(points, { x = 0, z = s.walkZ })
		table.insert(points, { x = 0, z = a.walkZ })
		table.insert(points, { x = a.door.x, z = a.walkZ })
		table.insert(points, { x = a.door.x, z = a.door.z + 4 })
		table.insert(points, { x = a.door.x, z = a.walkZ })
		table.insert(points, { x = 0, z = a.walkZ })
	else
		table.insert(points, { x = 0, z = s.walkZ })
	end
	table.insert(points, { x = 0, z = FRONT + 18 })
	table.insert(points, { x = 6, z = FRONT + 2 })
	table.insert(points, { x = 6, z = Layout.entrance.z })
	return points
end

function Layout.pathLength(points)
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local dx, dz = b.x - a.x, b.z - a.z
		total = total + math.sqrt(dx * dx + dz * dz)
	end
	return total
end

function Layout.walkTime(points)
	return Layout.pathLength(points) / Layout.WALK_SPEED
end

-- Position along a route after `distance` studs. Returns point and heading (dx, dz).
function Layout.pointAlong(points, distance)
	if #points == 1 then
		return points[1], 0, 1
	end
	local remaining = distance
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		if remaining <= len or i == #points then
			local t = 0
			if len > 0 then
				t = math.min(remaining / len, 1)
			end
			local hx, hz = 0, 1
			if len > 0 then
				hx, hz = dx / len, dz / len
			end
			return { x = a.x + dx * t, z = a.z + dz * t }, hx, hz
		end
		remaining = remaining - len
	end
	local last = points[#points]
	return last, 0, 1
end

-- World layout: 8 plots in two rows facing a central boulevard.
Layout.PLOT_COUNT = 8
function Layout.plotOrigin(plotIndex)
	local col = (plotIndex - 1) % 4
	local rowB = plotIndex > 4
	local x = (col - 1.5) * 170
	local z = rowB and 132 or -132
	-- yaw in degrees: row A faces +z (rotated 180), row B faces -z
	local yaw = rowB and 0 or 180
	return { x = x, z = z, yaw = yaw }
end

return Layout
