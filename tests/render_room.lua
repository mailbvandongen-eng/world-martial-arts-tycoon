-- Builds one room with the real RoomBuilder and puts posed students and the
-- trainer on its stations (as the client does), for tools/render_scene.py.
--   ROOM=boxing_room LEVEL=5 lua5.4 tests/render_room.lua > build/room.txt
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
_G.warn = function(...) io.stderr:write(table.concat({ ... }, " ") .. "\n") end
local H = require("harness")
local RoomBuilder = H.load("ServerScriptService/Server/World/RoomBuilder")
local Stations = H.load("ReplicatedStorage/Shared/Modules/Stations")
local Appearance = H.load("ReplicatedStorage/Shared/Modules/Appearance")
local Rig = H.load("ReplicatedStorage/Shared/Modules/Rig")
local Poses = H.load("ReplicatedStorage/Shared/Modules/Poses")
local Rooms = H.load("ReplicatedStorage/Shared/Config/Rooms")
local Disciplines = H.load("ReplicatedStorage/Shared/Config/Disciplines")

local roomId = os.getenv("ROOM") or "boxing_room"
local level = tonumber(os.getenv("LEVEL") or "5")
local slot = 1
local def = Rooms.byId[roomId]
local folder = Instance.new("Folder")
local cf = CFrame.new(0, 0, 0)
local info = Stations.forRoom(roomId, level)
local capacity = tonumber(os.getenv("CAP") or tostring(#info.stations))
RoomBuilder.build(folder, cf, slot, { id = roomId, level = level, tier = 3 }, { plotIndex = 1, passes = {}, now = 0, capacity = capacity })

local disc = def.discipline and Disciplines.byId[def.discipline]
local function place(spec, x, z, face, y, moveName, t)
	local rig = Rig.build(Appearance.describe(spec), { noAura = true })
	local p = Stations.plotPoint(slot, roomId, level, x, z)
	local dx, dz = Stations.faceVector(face)
	local pos = Vector3.new(p.x, y or 0.4, p.z)
	local base = CFrame.lookAt(pos, Vector3.new(p.x + dx, y or 0.4, p.z + dz))
	Rig.apply(rig, base, Poses.sample(Poses.moves[moveName] or Poses.moves.idle, t))
end
for i = 1, math.min(capacity, #info.stations) do
	local st = info.stations[i]
	local move
	if st.pair and disc and disc.moves.pair and not st.ring and i <= capacity and st.pair <= capacity then
		move = (i < st.pair) and disc.moves.pair[1] or disc.moves.pair[2]
	elseif st.moves then
		move = st.moves[(i % #st.moves) + 1]
	elseif disc then
		move = disc.moves.drill[1]
	else
		move = "idle"
	end
	place({ seed = 100 + i, discipline = def.discipline ~= "fitness" and def.discipline or nil, rank = 1 + i % 5 }, st.x, st.z, st.face, st.y, move, 0.35 + (i % 3) * 0.1)
end
if info.trainer and def.needsTrainer then
	place({ seed = 7, discipline = def.discipline, role = "trainer", rarity = "rare" }, info.trainer.x, info.trainer.z, info.trainer.face, nil, info.trainer.pads and "coach_mitts" or (disc and disc.moves.teach[1]) or "coach_point", 0.3)
end
for _, part in ipairs(Stub.allParts) do
	if part.CFrame and (part.Transparency or 0) < 0.95 then
		local p = part.CFrame
		local c = part.Color or { R = 0.6, G = 0.6, B = 0.6 }
		print(string.format("P %.2f %.2f %.2f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.2f %.2f %.2f %.3f %.3f %.3f %s",
			p.p[1], p.p[2], p.p[3], p.r[1], p.r[2], p.r[3], p.r[4], p.r[5], p.r[6], p.r[7], p.r[8], p.r[9],
			part.Size.X, part.Size.Y, part.Size.Z, c.R, c.G, c.B, tostring(part.Shape or "Block")))
	end
end
