-- Exports posed NPC rigs (the real Appearance + Rig + Poses code) as boxes,
-- for tools/render_poses.py to draw. Usage (from project root):
--   lua5.4 tests/render_poses.lua > build/poses.txt
-- Each figure: "F <title>" then "P x y z r00 r01 r02 r10 r11 r12 r20 r21 r22 sx sy sz r g b shape" lines.
package.path = (arg[0]:match("^(.*)/[^/]+$") or ".") .. "/?.lua;" .. package.path
local Stub = require("roblox_stub")
Stub.install(_G)
local H = require("harness")

local Appearance = H.load("ReplicatedStorage/Shared/Modules/Appearance")
local Rig = H.load("ReplicatedStorage/Shared/Modules/Rig")
local Poses = H.load("ReplicatedStorage/Shared/Modules/Poses")
local Disciplines = H.load("ReplicatedStorage/Shared/Config/Disciplines")

local sheet = arg[1] or "disciplines"
local figures = {}
if sheet == "disciplines" then
	-- per discipline: student idle, two drill moves at their peak, trainer
	for _, d in ipairs(Disciplines.list) do
		table.insert(figures, { d.name .. " idle", { seed = 11, discipline = d.id, role = "student", rank = 3 }, d.moves.idle, 0.5 })
		table.insert(figures, { d.moves.drill[1], { seed = 12, discipline = d.id, role = "student", rank = 2 }, d.moves.drill[1], 0.4 })
		table.insert(figures, { d.moves.drill[2], { seed = 13, discipline = d.id, role = "student", rank = 4 }, d.moves.drill[2], 0.4 })
		table.insert(figures, { d.trainerTitle, { seed = 14, discipline = d.id, role = "trainer", rarity = "legendary" }, d.moves.teach[1], 0.3 })
	end
else
	-- every key frame of a few signature moves
	local list = { "karate_front_kick", "kick_roundhouse", "sumo_shiko", "judo_breakfall", "boxing_combo", "tkd_high_kick", "bjj_guard", "walk" }
	for _, name in ipairs(list) do
		local m = Poses.moves[name]
		for _, k in ipairs(m.keys) do
			table.insert(figures, { name .. " t=" .. k.t, { seed = 3, discipline = "karate", role = "student" }, name, k.t })
		end
	end
end

for i, f in ipairs(figures) do
	local spec = Appearance.describe(f[2])
	local rig = Rig.build(spec, { noAura = true })
	local base = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(tonumber(os.getenv("YAW") or "25")), 0)
	Rig.apply(rig, base, Poses.sample(Poses.moves[f[3]], f[4]))
	print("F " .. f[1])
	for _, part in ipairs(rig.list) do
		local cf = part.CFrame
		local c = part.Color
		print(string.format("P %.3f %.3f %.3f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f %.3f %s",
			cf.p[1], cf.p[2], cf.p[3], cf.r[1], cf.r[2], cf.r[3], cf.r[4], cf.r[5], cf.r[6], cf.r[7], cf.r[8], cf.r[9],
			part.Size.X, part.Size.Y, part.Size.Z, c.R, c.G, c.B, tostring(part.Shape or "Block")))
	end
end
