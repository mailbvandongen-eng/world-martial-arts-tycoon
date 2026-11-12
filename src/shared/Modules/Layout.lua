-- Geometry of an academy plot in plot-local coordinates (studs).
-- x = right, z = depth (entrance at the front, z = FRONT), y is up.
-- Pure numbers ({x = , z = }) so the server, the client and the offline tests
-- compute identical routes.
--
--   back
--   row 5   [outer][inner]  HALL  [inner][outer]     rooms grow inside their cell
--           ======= walkway ==== HALL ==== walkway =======
--   ...
--   row 1   [outer][inner]  HALL  [inner][outer]
--           ======= walkway ==== HALL ==== walkway =======
--   reception (lobby, desk, register, lounge)
--   front: entrance
--
-- Flow: ENTRANCE -> RECEPTION -> CENTRAL HALL -> WALKWAY -> ROOM DOOR -> station.
-- Visitors never cross another room: every room's door opens onto a walkway.
-- Two lanes everywhere (in / out) so visitors don't walk into each other.

local Layout = {}

Layout.CELL_W = 40 -- maximum room width (rooms grow towards this when upgraded)
Layout.CELL_D = 36 -- maximum room depth
Layout.WALKWAY = 10
Layout.CORRIDOR = 20 -- central hall width
Layout.ROW_PITCH = Layout.WALKWAY + Layout.CELL_D
Layout.ROWS = 5
Layout.MAX_SLOTS = 20
Layout.WALL_H = 13
Layout.WALK_SPEED = 9 -- studs per second for visitors

Layout.WIDTH = 192
Layout.DEPTH = 284
local FRONT = -Layout.DEPTH / 2
Layout.FRONT = FRONT
Layout.RECEPTION = { x0 = -44, x1 = 44, z0 = FRONT, z1 = FRONT + 40 }
local ROW0 = Layout.RECEPTION.z1

-- Competition hall: the free corner left of the reception. Its back opens onto
-- the first walkway. Sparring, belt exams and your own kumite happen here.
Layout.COMPETITION = { x0 = -94.5, x1 = -44.5, z0 = FRONT + 1.5, z1 = FRONT + 39.5, cx = -69.5, cz = FRONT + 21, door = 14, floor = 0.64 }

local COLUMN_X = { -73, -31, 31, 73 }
local FILL_ORDER = { 2, 3, 1, 4 } -- inner columns first

-- Lanes: inbound on the left of the hall / front of a walkway, outbound on the right / back.
Layout.LANE_IN_X = -4
Layout.LANE_OUT_X = 4

-- Slot index (1..20) -> the cell a room can occupy.
function Layout.slot(index)
	local row = math.floor((index - 1) / 4) + 1
	local col = FILL_ORDER[((index - 1) % 4) + 1]
	local walk0 = ROW0 + (row - 1) * Layout.ROW_PITCH
	local z0 = walk0 + Layout.WALKWAY
	local cx = COLUMN_X[col]
	return {
		index = index,
		row = row,
		col = col,
		cx = cx,
		cz = z0 + Layout.CELL_D / 2,
		x0 = cx - Layout.CELL_W / 2,
		x1 = cx + Layout.CELL_W / 2,
		z0 = z0,
		z1 = z0 + Layout.CELL_D,
		walkZ = walk0 + Layout.WALKWAY / 2,
		walkIn = walk0 + Layout.WALKWAY / 2 - 2,
		walkOut = walk0 + Layout.WALKWAY / 2 + 2,
		door = { x = cx, z = z0 },
	}
end

-- Room size for a room type and level. Rooms start at their base size and grow
-- by `grow` studs per level, never beyond the cell. The front wall (with the
-- door) always stays on the walkway.
function Layout.roomSize(def, level)
	local size = def and def.size or { 30, 26 }
	local grow = def and def.grow or 2.5
	local w = math.min(Layout.CELL_W, size[1] + (level - 1) * grow)
	local d = math.min(Layout.CELL_D, size[2] + (level - 1) * grow)
	return w, d
end

function Layout.roomRect(index, def, level)
	local s = Layout.slot(index)
	local w, d = Layout.roomSize(def, level)
	return {
		slot = s,
		cx = s.cx,
		w = w,
		d = d,
		x0 = s.cx - w / 2,
		x1 = s.cx + w / 2,
		z0 = s.z0,
		z1 = s.z0 + d,
		door = { x = s.cx, z = s.z0 },
	}
end

-- Room-local (x across, z from the front wall) -> plot-local.
function Layout.toPlot(rect, x, z)
	return { x = rect.cx + x, z = rect.z0 + z }
end

-- Reception
Layout.entrance = { x = 0, z = FRONT - 6 }
Layout.desk = { x = -16, z = FRONT + 20 } -- reception desk centre (faces the entrance)
Layout.register = { x = 22, z = FRONT + 14 } -- cash register pad
Layout.receptionExit = { x = 0, z = ROW0 + 2 }

-- Queue spot q (1-based): two neat lines in front of the desk.
function Layout.queueSpot(q)
	local col = (q - 1) % 6
	local row = math.floor((q - 1) / 6)
	return { x = -16 + (col - 2.5) * 3, z = FRONT + 15 - row * 3 }
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
Layout.PLOT_SPACING = 220
function Layout.plotOrigin(plotIndex)
	local col = (plotIndex - 1) % 4
	local rowB = plotIndex > 4
	local x = (col - 1.5) * Layout.PLOT_SPACING
	local offset = 32 + Layout.DEPTH / 2
	local z = rowB and offset or -offset
	-- yaw in degrees: row A faces +z (rotated 180), row B faces -z
	local yaw = rowB and 0 or 180
	return { x = x, z = z, yaw = yaw }
end

return Layout
