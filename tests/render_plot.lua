-- Builds a full academy with the real PlotBuilder/RoomBuilder/Props code and
-- exports every part as a box for tools/render_poses.py-style drawing.
--   lua5.4 tests/render_plot.lua > build/plot.txt
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
_G.warn = function(...) io.stderr:write(table.concat({ ... }, " ") .. "\n") end
local H = require("harness")
local PlotBuilder = H.load("ServerScriptService/Server/World/PlotBuilder")
local RoomBuilder = H.load("ServerScriptService/Server/World/RoomBuilder")
local Disciplines = H.load("ReplicatedStorage/Shared/Config/Disciplines")
local city = os.getenv("CITY") or "tokyo"
local folder = Instance.new("Folder")
PlotBuilder.buildBase(folder, 5, city, "Bob")
PlotBuilder.buildSurroundings(folder, 5, city)
PlotBuilder.buildReception(folder, 5, city, 4, { premium_decor = true })
local cf = PlotBuilder.plotCFrame(5)
local passes = { golden_ring = true, luxury_sumo = true, gym_lighting = true }
local ids = {}
for _, d in ipairs(Disciplines.list) do
	table.insert(ids, d.id .. "_room")
end
for _, extra in ipairs({ "vip_room", "juice_bar", "recovery_room", "arena", "strength_room" }) do
	table.insert(ids, extra)
end
for slot, id in ipairs(ids) do
	if slot <= 16 then
		RoomBuilder.build(folder, cf, slot, { id = id, level = 1 + (slot % 5), tier = 1 }, { plotIndex = 5, passes = passes, now = 0 })
	end
end
RoomBuilder.build(folder, cf, 17, { id = "mma_room", level = 2, tier = 1, buildEnd = 100, buildStart = 0 }, { plotIndex = 5, passes = {}, now = 0 })
RoomBuilder.buildEmpty(folder, cf, 18, 5, false)
RoomBuilder.buildEmpty(folder, cf, 19, 5, true)
local n = 0
for _, part in ipairs(Stub.allParts) do
	if part.CFrame and (part.Transparency or 0) < 0.95 then
		n = n + 1
		local p = part.CFrame
		local c = part.Color or { R = 0.6, G = 0.6, B = 0.6 }
		print(string.format("P %.2f %.2f %.2f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.2f %.2f %.2f %.3f %.3f %.3f %s",
			p.p[1], p.p[2], p.p[3], p.r[1], p.r[2], p.r[3], p.r[4], p.r[5], p.r[6], p.r[7], p.r[8], p.r[9],
			part.Size.X, part.Size.Y, part.Size.Z, c.R, c.G, c.B, tostring(part.Shape or "Block")))
	end
end
io.stderr:write(n .. " parts\n")
