-- Builds the competition hall of a plot with the real PlotBuilder and poses a
-- kumite bout (AKA vs AO), the referee and the five judges as BoutController
-- does, for tools/render_scene.py.
--   BOUT_T=4 lua5.4 tests/render_hall.lua > build/hall.txt
--   FLIP=1 EYE=0.16 python3 tools/render_scene.py build/hall.txt docs/images/competition_hall.png
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
_G.warn = function(...) io.stderr:write(table.concat({ ... }, " ") .. "\n") end
local H = require("harness")
local PlotBuilder = H.load("ServerScriptService/Server/World/PlotBuilder")
local Layout = H.load("ReplicatedStorage/Shared/Modules/Layout")
local Appearance = H.load("ReplicatedStorage/Shared/Modules/Appearance")
local Rig = H.load("ReplicatedStorage/Shared/Modules/Rig")
local Poses = H.load("ReplicatedStorage/Shared/Modules/Poses")
local Bout = H.load("ReplicatedStorage/Shared/Modules/Bout")

local folder = Instance.new("Folder")
PlotBuilder.buildBase(folder, 5, os.getenv("CITY") or "smalltown", "Bob")
PlotBuilder.buildReception(folder, 5, os.getenv("CITY") or "smalltown", 3, {})
local pcf = PlotBuilder.plotCFrame(5)
local c = Layout.COMPETITION
local stage = pcf * CFrame.new(c.cx, c.floor, c.cz)
local function at(x, z, fx, fz)
	local pos = stage * Vector3.new(x, 0, z)
	local dir = stage:VectorToWorldSpace(Vector3.new(fx, 0, fz))
	return CFrame.lookAt(pos, pos + dir)
end
local bout = Bout.simulate({ name = "A", skill = 70 }, { name = "B", skill = 60 }, 11, { discipline = "karate" })
local t = tonumber(os.getenv("BOUT_T") or "0")
if t == 0 then
	for _, ev in ipairs(bout.events) do
		if ev.r == "score" then
			t = ev.t + 0.25
			break
		end
	end
end
for side = 1, 2 do
	local dir = side == 1 and 1 or -1
	local rig = Rig.build(Appearance.describe({ seed = 40 + side, discipline = "karate", rank = 6, category = "professional", beltColor = side == 1 and { 200, 30, 30 } or { 40, 80, 200 } }), {})
	local m, dt = Bout.actionAt(bout, side, t)
	local x = -2.8 * dir
	if m and m ~= "hit_react" then
		x = x + dir * 1.1 * math.sin(math.pi * math.min(1, dt / 0.9))
	end
	local mv = Poses.moves[m or "karate_stance"]
	Rig.apply(rig, at(x, 0, dir, 0), Poses.sample(mv, math.min(dt or t, mv.length - 0.01)))
end
local ref = Rig.build(Appearance.describe({ seed = 777, role = "staff" }), {})
Rig.apply(ref, at(0, -3.8, 0, 1), Poses.sample(Poses.moves.ref_point_r, 0.6))
for i = -2, 2 do
	local seat = pcf * Vector3.new(c.x0 + 5.2, 2.0, c.cz + i * 2.2)
	local j = Rig.build(Appearance.describe({ seed = 900 + i, role = "staff" }), {})
	Rig.apply(j, CFrame.lookAt(seat, seat + pcf:VectorToWorldSpace(Vector3.new(1, 0, 0))), Poses.sample(i % 2 == 0 and Poses.moves.judge_flag_r or Poses.moves.judge_sit, 0.5))
end
-- only what is inside (or right around) the hall
local lo = pcf * Vector3.new(c.x0 - 2, 0, c.z0 - 2)
local hi = pcf * Vector3.new(c.x1 + 8, 0, c.z1 + 12)
local minX, maxX = math.min(lo.X, hi.X), math.max(lo.X, hi.X)
local minZ, maxZ = math.min(lo.Z, hi.Z), math.max(lo.Z, hi.Z)
for _, part in ipairs(Stub.allParts) do
	local p = part.CFrame
	if p and (part.Transparency or 0) < 0.95 and p.p[1] >= minX and p.p[1] <= maxX and p.p[3] >= minZ and p.p[3] <= maxZ and part.Size.X < 60 and part.Size.Z < 60 then
		local col = part.Color or { R = 0.6, G = 0.6, B = 0.6 }
		print(string.format("P %.2f %.2f %.2f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.2f %.2f %.2f %.3f %.3f %.3f %s",
			p.p[1], p.p[2], p.p[3], p.r[1], p.r[2], p.r[3], p.r[4], p.r[5], p.r[6], p.r[7], p.r[8], p.r[9],
			part.Size.X, part.Size.Y, part.Size.Z, col.R, col.G, col.B, tostring(part.Shape or "Block")))
	end
end
