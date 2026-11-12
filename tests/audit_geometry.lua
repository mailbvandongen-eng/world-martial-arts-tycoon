-- Independent geometry audit (QA): builds every room type at every level with
-- the real RoomBuilder, then checks the real built equipment against
--   1. every NPC walking route (door -> lane -> station, Stations.routeIn),
--   2. the room walls (equipment sticking through a wall),
--   3. the doorway and entry lane (equipment blocking the door).
-- Prints every violation; exit code 1 when any is found.
--   lua5.4 tests/audit_geometry.lua [roomId]
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
_G.warn = function() end
local H = require("harness")
local RoomBuilder = H.load("ServerScriptService/Server/World/RoomBuilder")
local Stations = H.load("ReplicatedStorage/Shared/Modules/Stations")
local Layout = H.load("ReplicatedStorage/Shared/Modules/Layout")
local Rooms = H.load("ReplicatedStorage/Shared/Config/Rooms")

local NPC_R = 0.6 -- body radius
local NPC_H = 5 -- body height
local only = arg[1]
local SLOT = 1
local total, rooms = 0, 0
local report = {}

local function partsOf(model, out)
	for _, c in ipairs(model._children or {}) do
		if c.Size and c.CFrame then
			table.insert(out, c)
		end
		partsOf(c, out)
	end
	return out
end

-- Is plot point (x, z) within r of the part's footprint, and does the part
-- reach into the NPC's body height?
local function hits(part, x, z, r)
	local p, R, s = part.CFrame.p, part.CFrame.r, part.Size
	-- vertical extent (approximate with the largest projected half height)
	local hy = math.abs(R[4]) * s.X / 2 + math.abs(R[5]) * s.Y / 2 + math.abs(R[6]) * s.Z / 2
	local bottom, top = p[2] - hy, p[2] + hy
	if top < 0.6 or bottom > NPC_H then
		return false
	end
	-- world-aligned footprint of the (possibly rotated or tilted) part
	local hx = math.abs(R[1]) * s.X / 2 + math.abs(R[2]) * s.Y / 2 + math.abs(R[3]) * s.Z / 2
	local hz = math.abs(R[7]) * s.X / 2 + math.abs(R[8]) * s.Y / 2 + math.abs(R[9]) * s.Z / 2
	return math.abs(x - p[1]) <= hx + r and math.abs(z - p[3]) <= hz + r
end

for _, def in ipairs(Rooms.list) do
	if def.kind ~= "reception" and (not only or only == def.id) then
		for level = 1, 5 do
			rooms = rooms + 1
			local info = Stations.forRoom(def.id, level)
			local folder = Instance.new("Folder")
			local model = RoomBuilder.build(folder, CFrame.new(0, 0, 0), SLOT, { id = def.id, level = level, tier = 3 }, { plotIndex = 1, passes = {}, now = 0, capacity = #info.stations })
			local props = {}
			for _, child in ipairs((model or folder)._children or {}) do
				if child.ClassName == "Model" or (child._children and #child._children > 0 and not child.Size) then
					for _, part in ipairs(partsOf(child, {})) do
						part._prop = child.Name
						table.insert(props, part)
					end
				end
			end
			local rect = Layout.roomRect(SLOT, def, level)
			local tag = def.id .. " L" .. level
			local issues = {}
			local function issue(kind, text)
				issues[kind .. text] = issues[kind .. text] or { kind = kind, text = text, n = 0 }
				issues[kind .. text].n = issues[kind .. text].n + 1
			end
			-- 1. walking routes
			for i, st in ipairs(info.stations) do
				local route = Stations.routeIn(SLOT, def.id, level, i)
				local final = route[#route]
				-- the station's own equipment may be stepped onto / into at the end
				local ownAt = st.prop and Stations.plotPoint(SLOT, def.id, level, st.propX, st.propZ)
				for k = 1, #route - 1 do
					local a, b = route[k], route[k + 1]
					local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
					local steps = math.max(1, math.ceil(len / 0.25))
					for s = 0, steps do
						local x = a.x + (b.x - a.x) * s / steps
						local z = a.z + (b.z - a.z) * s / steps
						local nearGoal = math.sqrt((x - final.x) ^ 2 + (z - final.z) ^ 2) < 2.2
						for _, part in ipairs(props) do
							local lastLeg = k == #route - 1
							local mine = lastLeg and ownAt and part._prop == st.prop and math.abs(part.CFrame.p[1] - ownAt.x) < 3.5 and math.abs(part.CFrame.p[3] - ownAt.z) < 3.5
							local own = mine or st.ring and (part._prop == "ring" or part._prop == "octagon" or part._prop == "dohyo" or part._prop == "dohyo_round")
							if not nearGoal and not own and hits(part, x, z, NPC_R) then
								issue("route", "station " .. i .. " walks through " .. part._prop)
							end
						end
					end
				end
			end
			-- 2./3. equipment vs walls and doorway
			for _, part in ipairs(props) do
				local p, s = part.CFrame.p, part.Size
				local R = part.CFrame.r
				local hx = math.abs(R[1]) * s.X / 2 + math.abs(R[2]) * s.Y / 2 + math.abs(R[3]) * s.Z / 2
				local hz = math.abs(R[7]) * s.X / 2 + math.abs(R[8]) * s.Y / 2 + math.abs(R[9]) * s.Z / 2
				local x0, x1, z0, z1 = p[1] - hx, p[1] + hx, p[3] - hz, p[3] + hz
				local hy0 = math.abs(R[4]) * s.X / 2 + math.abs(R[5]) * s.Y / 2 + math.abs(R[6]) * s.Z / 2
				-- brackets above head height are wall mounts (heavy bags), not clipping furniture
				if p[2] - hy0 < 7 and (x0 < rect.x0 - 0.3 or x1 > rect.x1 + 0.3 or z1 > rect.z1 + 0.3) then
					issue("wall", part._prop .. " sticks through a wall")
				end
				local hy = math.abs(R[4]) * s.X / 2 + math.abs(R[5]) * s.Y / 2 + math.abs(R[6]) * s.Z / 2
				if z0 < rect.z0 + 3.2 and p[2] - hy < NPC_H and p[2] + hy > 0.6 and math.abs(p[1] - rect.cx) - hx < 3 then
					issue("door", part._prop .. " in the doorway / entry lane")
				end
			end
			local list = {}
			for _, v in pairs(issues) do
				table.insert(list, v)
				total = total + 1
			end
			table.sort(list, function(a, b)
				return a.text < b.text
			end)
			if #list > 0 then
				table.insert(report, tag .. " (" .. #info.stations .. " stations)")
				for _, v in ipairs(list) do
					table.insert(report, "    [" .. v.kind .. "] " .. v.text .. (v.n > 1 and (" (x" .. v.n .. " samples)") or ""))
				end
			end
		end
	end
end
for _, line in ipairs(report) do
	print(line)
end
print(string.format("geometry audit: %d room/level combinations, %d distinct problems", rooms, total))
os.exit(total == 0 and 0 or 1)
