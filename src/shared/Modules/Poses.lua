-- Procedural animation library. Original keyframe animations for the 11-part
-- NPC rig (see Rig.lua). No animation assets are needed.
--
-- A pose is a flat table of joint angles in degrees (missing = 0):
--   ry rp rr      root yaw / pitch (lean forward +) / roll (lean right +)
--   rx rz rh      root offset sideways / forward / height (jumps only; feet are auto-grounded)
--   wp wy wr      waist (chest relative to hips): pitch, yaw (twist left +), roll
--   np ny         neck pitch (look down +), yaw
--   lsp lsy lsr   left shoulder: pitch (raise forward +), yaw, roll (raise sideways +)
--   lel           left elbow bend
--   rsp rsy rsr rel   right arm
--   lhp lhy lhr lkn   left hip: pitch (leg forward +), yaw, roll (leg out +), knee bend
--   rhp rhy rhr rkn   right leg
--   grounded = false  disables auto-grounding (for a pose in the air)
-- A move = { length = seconds, loop = bool, keys = { { t = s, p = pose, e = easing }, ... },
--            sounds = { { t = s, name = "bag_hit" } } }

local Poses = {}

local function merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		if t then
			for k, v in pairs(t) do
				out[k] = v
			end
		end
	end
	return out
end
Poses.merge = merge

local function K(t, ...)
	return { t = t, p = merge(...) }
end

local function move(length, keys, opts)
	local m = { length = length, keys = keys, loop = true }
	if opts then
		for k, v in pairs(opts) do
			m[k] = v
		end
	end
	return m
end

---------------------------------------------------------------- base poses
local P = {}
P.stand = { lsr = 6, rsr = 6, lel = 8, rel = 8 }
P.relaxed = { lsr = 8, rsr = 8, lel = 12, rel = 12, lsp = 4, rsp = 4 }
P.handsHips = { lsr = 35, rsr = 35, lel = 100, rel = 100, lsy = -30, rsy = -30 }
P.armsCrossed = { lsp = 40, rsp = 40, lel = 110, rel = 110, lsy = 50, rsy = 50 }
P.guardBox = { lsp = 40, lel = 125, rsp = 30, rel = 135, lsy = 15, rsy = 20, ry = 25, wy = -15, lhp = 14, lkn = 14, rhp = -12, rkn = 16, np = 6 }
P.guardThai = { lsp = 55, lel = 115, rsp = 50, rel = 120, lsy = 10, rsy = 10, ry = 10, wy = -5, lhp = 8, lkn = 10, rhp = -6, rkn = 10, wp = -4 }
P.zenkutsu = { lhp = 30, lkn = 25, rhp = -25, rkn = 0, ry = 20, wy = -20, lsp = 30, lsr = 20, lel = 30, rsp = 10, rsr = 30, rel = 100, rsy = -40 }
P.kiba = { lhr = 32, rhr = 32, lhp = 40, rhp = 40, lkn = 75, rkn = 75, rp = 4 }
P.judo = { lsp = 55, lel = 60, rsp = 55, rel = 60, lsr = 10, rsr = 10, rp = 12, np = -8, lhp = 15, rhp = 15, lkn = 25, rkn = 25, lhr = 10, rhr = 10 }
P.wrestle = { rp = 35, np = -25, lsp = 60, rsp = 60, lel = 70, rel = 70, lsr = 15, rsr = 15, lhp = 55, rhp = 40, lkn = 70, rkn = 60, lhr = 12, rhr = 12 }
P.sumoCrouch = { lhr = 40, rhr = 40, lhp = 65, rhp = 65, lkn = 95, rkn = 95, rp = 20, np = -15, lsp = 40, rsp = 40, lel = 20, rel = 20, lsr = 15, rsr = 15 }
P.tkd = { lsp = 30, lel = 110, rsp = 20, rel = 120, ry = 40, wy = -20, lhp = 10, lkn = 10, rhp = -8, rkn = 12 }
P.horse = merge(P.kiba, { lsp = 0, rsp = 0, lsr = 10, rsr = 10, lel = 120, rel = 120, lsy = -60, rsy = -60 })
P.lying = { rp = -88, lhp = 60, rhp = 60, lkn = 90, rkn = 90, lsr = 40, rsr = 40, lel = 30, rel = 30, np = 30 }
P.seatedGuard = { rp = -60, lhp = 85, rhp = 85, lkn = 70, rkn = 70, lhr = 30, rhr = 30, lsp = 60, rsp = 60, lel = 50, rel = 50, np = 25 }

---------------------------------------------------------------- moves
local M = {}

-- generic
M.idle = move(4, { K(0, P.stand), K(2, P.stand, { wp = 2, np = 3, lsr = 8, rsr = 8 }), K(4, P.stand) })
M.walk = move(0.8, {
	K(0, P.relaxed, { lhp = 25, rhp = -25, rkn = 15, lsp = -20, rsp = 20, lel = 15, rel = 25 }),
	K(0.2, P.relaxed, { lhp = 0, rhp = 0, lkn = 25, rkn = 5 }),
	K(0.4, P.relaxed, { lhp = -25, rhp = 25, lkn = 15, lsp = 20, rsp = -20, lel = 25, rel = 15 }),
	K(0.6, P.relaxed, { lhp = 0, rhp = 0, rkn = 25, lkn = 5 }),
	K(0.8, P.relaxed, { lhp = 25, rhp = -25, rkn = 15, lsp = -20, rsp = 20, lel = 15, rel = 25 }),
})
M.wait = move(3, { K(0, P.armsCrossed), K(1.5, P.armsCrossed, { ny = 20, wp = 2 }), K(3, P.armsCrossed) })
M.queue = move(3.5, { K(0, P.stand, { ny = -10 }), K(1.75, P.stand, { ny = 15, lhr = 4 }), K(3.5, P.stand, { ny = -10 }) })
M.drink = move(2.4, { K(0, P.stand, { rsp = 40, rel = 120 }), K(0.8, P.stand, { rsp = 70, rel = 140, np = -20 }), K(1.6, P.stand, { rsp = 70, rel = 140, np = -20 }), K(2.4, P.stand, { rsp = 40, rel = 120 }) })
M.cheer = move(1, { K(0, P.stand, { lsr = 150, rsr = 150, lel = 20, rel = 20 }), K(0.5, P.stand, { lsr = 165, rsr = 165, lel = 5, rel = 5, rh = 0.6, grounded = false }), K(1, P.stand, { lsr = 150, rsr = 150, lel = 20, rel = 20 }) })
M.rankup = move(2.2, {
	K(0, P.stand),
	K(0.3, P.stand, { lhp = 30, rhp = 30, lkn = 60, rkn = 60, rp = 10 }),
	K(0.6, P.stand, { rsp = 170, rel = 10, lsr = 20, rh = 1.6, grounded = false }),
	K(0.9, P.stand, { rsp = 170, rel = 10, lsr = 20 }),
	K(1.6, P.stand, { rsp = 150, rel = 40, lsp = 30, lel = 90, np = -10 }),
	K(2.2, P.stand),
}, { loop = false })
M.receptionist = move(2, { K(0, P.stand, { lsp = 45, rsp = 45, lel = 60, rel = 60, np = 15 }), K(0.5, P.stand, { lsp = 50, rsp = 40, lel = 55, rel = 65, np = 15 }), K(1, P.stand, { lsp = 40, rsp = 50, lel = 65, rel = 55, np = 15 }), K(2, P.stand, { lsp = 45, rsp = 45, lel = 60, rel = 60, np = 15 }) })

-- coaching (trainers)
M.coach_count = move(2, { K(0, P.handsHips), K(0.5, P.handsHips, { np = -5, wy = 10 }), K(1, P.handsHips, { rsp = 30, rel = 90, rsy = 0 }), K(1.5, P.handsHips, { np = -5, wy = -10 }), K(2, P.handsHips) }, { sounds = { { t = 1, name = "whistle", chance = 0.15 } } })
M.coach_point = move(2.4, { K(0, P.stand), K(0.4, P.stand, { rsp = 90, rel = 0, wy = 10 }), K(1.2, P.stand, { rsp = 90, rel = 0, wy = -15 }), K(1.8, P.stand, { rsp = 90, rel = 0, wy = 15 }), K(2.4, P.stand) })
M.coach_clap = move(1.2, { K(0, P.stand, { lsp = 60, rsp = 60, lel = 40, rel = 40, lsy = 30, rsy = 30 }), K(0.3, P.stand, { lsp = 70, rsp = 70, lel = 30, rel = 30, lsy = 50, rsy = 50 }), K(0.6, P.stand, { lsp = 60, rsp = 60, lel = 40, rel = 40, lsy = 30, rsy = 30 }), K(0.9, P.stand, { lsp = 70, rsp = 70, lel = 30, rel = 30, lsy = 50, rsy = 50 }), K(1.2, P.stand, { lsp = 60, rsp = 60, lel = 40, rel = 40, lsy = 30, rsy = 30 }) })
M.coach_whistle = move(2, { K(0, P.handsHips), K(0.4, P.handsHips, { rsp = 80, rel = 140, rsr = 10, np = -5 }), K(1.2, P.handsHips, { rsp = 80, rel = 140, rsr = 10 }), K(2, P.handsHips) }, { sounds = { { t = 0.5, name = "whistle" } } })
M.coach_mitts = move(1.6, {
	K(0, P.guardBox, { lsp = 80, lel = 60, rsp = 80, rel = 60 }),
	K(0.25, P.guardBox, { lsp = 85, lel = 40, rsp = 70, rel = 80, wy = 10 }),
	K(0.5, P.guardBox, { lsp = 80, lel = 60, rsp = 80, rel = 60 }),
	K(0.8, P.guardBox, { lsp = 70, lel = 80, rsp = 90, rel = 40, wy = -10 }),
	K(1.1, P.guardBox, { lsp = 80, lel = 60, rsp = 80, rel = 60 }),
	K(1.6, P.guardBox, { lsp = 80, lel = 60, rsp = 80, rel = 60, lhp = 0, rhp = 0 }),
}, { sounds = { { t = 0.25, name = "pad_kick" }, { t = 0.8, name = "pad_kick" } } })
M.coach_thai_pads = move(1.8, {
	K(0, P.guardThai, { lsp = 75, lel = 80, rsp = 75, rel = 80, lsy = 30, rsy = 30 }),
	K(0.4, P.guardThai, { lsp = 30, lel = 100, rsp = 30, rel = 100, lsr = 40, wy = -30, ry = -10 }),
	K(0.7, P.guardThai, { lsp = 30, lel = 100, rsp = 30, rel = 100, lsr = 40, wy = -30, ry = -10, rp = 5 }),
	K(1.2, P.guardThai, { lsp = 75, lel = 80, rsp = 75, rel = 80, lsy = 30, rsy = 30 }),
	K(1.8, P.guardThai, { lsp = 75, lel = 80, rsp = 75, rel = 80, lsy = 30, rsy = 30 }),
}, { sounds = { { t = 0.6, name = "pad_kick" } } })
M.coach_paddle = move(1.6, { K(0, P.tkd, { rsp = 80, rel = 30, rsr = 30 }), K(0.5, P.tkd, { rsp = 120, rel = 20, rsr = 50 }), K(0.8, P.tkd, { rsp = 120, rel = 20, rsr = 50, wy = 10 }), K(1.6, P.tkd, { rsp = 80, rel = 30, rsr = 30 }) }, { sounds = { { t = 0.75, name = "pad_kick" } } })

-- karate
M.karate_stance = move(3, { K(0, P.zenkutsu), K(1.5, P.zenkutsu, { wp = 2, lsp = 32 }), K(3, P.zenkutsu) })
M.karate_punch = move(1.2, {
	K(0, P.zenkutsu),
	K(0.15, P.zenkutsu, { rsp = 90, rel = 0, rsr = 0, rsy = 0, lsp = 20, lel = 110, lsr = 15, lsy = -40, wy = 15 }),
	K(0.6, P.zenkutsu, { rsp = 90, rel = 0, rsr = 0, rsy = 0, lsp = 20, lel = 110, lsr = 15, lsy = -40, wy = 15 }),
	K(0.75, P.zenkutsu, { lsp = 90, lel = 0, lsr = 0, lsy = 0, rsp = 20, rel = 110, rsr = 15, rsy = -40, wy = -15 }),
	K(1.2, P.zenkutsu),
}, { sounds = { { t = 0.15, name = "bag_hit", chance = 0.4 } } })
M.karate_front_kick = move(1.4, {
	K(0, P.zenkutsu),
	K(0.25, P.zenkutsu, { rhp = 85, rkn = 100, lkn = 15, lhp = 5 }),
	K(0.45, P.zenkutsu, { rhp = 95, rkn = 5, lkn = 15, lhp = 5, rp = -8 }),
	K(0.7, P.zenkutsu, { rhp = 85, rkn = 100, lkn = 15, lhp = 5 }),
	K(1.0, P.zenkutsu),
	K(1.4, P.zenkutsu),
})
M.karate_block = move(1.6, {
	K(0, P.zenkutsu),
	K(0.2, P.zenkutsu, { lsp = 130, lel = 70, lsy = 20, lsr = 10 }),
	K(0.6, P.zenkutsu, { lsp = 130, lel = 70, lsy = 20, lsr = 10 }),
	K(0.9, P.zenkutsu, { rsp = 60, rel = 90, rsy = 50, rsr = 0, wy = -20 }),
	K(1.6, P.zenkutsu),
})
M.karate_roundhouse = move(1.6, {
	K(0, P.zenkutsu),
	K(0.3, P.zenkutsu, { rhp = 50, rhr = 50, rkn = 110, ry = -20, rr = -10, lhy = -30 }),
	K(0.5, P.zenkutsu, { rhp = 40, rhr = 80, rkn = 10, ry = -50, rr = -20, lhy = -50 }),
	K(0.8, P.zenkutsu, { rhp = 50, rhr = 50, rkn = 110, ry = -20, rr = -10 }),
	K(1.2, P.zenkutsu),
	K(1.6, P.zenkutsu),
})
M.karate_kata = move(6, {
	K(0, P.stand, { lsp = 10, rsp = 10 }),
	K(0.6, P.kiba, { lsp = 90, lel = 0, rsp = 20, rel = 110, rsr = 15, rsy = -40, wy = 10 }),
	K(1.4, P.kiba, { rsp = 90, rel = 0, lsp = 20, lel = 110, lsr = 15, lsy = -40, wy = -10 }),
	K(2.2, P.zenkutsu, { ry = 90, lsp = 130, lel = 70, lsy = 20 }),
	K(3.0, P.zenkutsu, { ry = 90, rsp = 90, rel = 0 }),
	K(3.8, P.zenkutsu, { ry = -90, rhp = 90, rkn = 5 }),
	K(4.6, P.zenkutsu, { ry = -90, rsp = 60, rel = 90, rsy = 50 }),
	K(5.4, P.kiba, { lsp = 90, lel = 0, rsp = 90, rel = 0, wp = 5 }),
	K(6, P.stand, { lsp = 10, rsp = 10 }),
})

-- boxing
local boxGuard = P.guardBox
M.boxing_guard = move(1.2, { K(0, boxGuard), K(0.3, boxGuard, { rh = 0.15, grounded = false }), K(0.6, boxGuard), K(0.9, boxGuard, { rh = 0.15, grounded = false }), K(1.2, boxGuard) })
M.boxing_jab = move(0.8, { K(0, boxGuard), K(0.12, boxGuard, { lsp = 88, lel = 5, lsy = 0, wy = -25 }), K(0.3, boxGuard), K(0.8, boxGuard) }, { sounds = { { t = 0.12, name = "bag_hit", chance = 0.6 } } })
M.boxing_cross = move(1, { K(0, boxGuard), K(0.15, boxGuard, { rsp = 88, rel = 5, rsy = 0, wy = 25, ry = 5, rkn = 25, rhy = -20 }), K(0.4, boxGuard), K(1, boxGuard) }, { sounds = { { t = 0.15, name = "bag_hit", chance = 0.6 } } })
M.boxing_hook = move(1.1, { K(0, boxGuard), K(0.12, boxGuard, { lsp = 80, lel = 90, lsr = 70, lsy = 30, wy = 10 }), K(0.25, boxGuard, { lsp = 80, lel = 90, lsr = 70, lsy = 60, wy = -35 }), K(0.5, boxGuard), K(1.1, boxGuard) }, { sounds = { { t = 0.25, name = "bag_hit", chance = 0.6 } } })
M.boxing_uppercut = move(1.1, { K(0, boxGuard), K(0.15, boxGuard, { rsp = 10, rel = 100, lkn = 30, rkn = 35, rp = 8 }), K(0.3, boxGuard, { rsp = 110, rel = 80, wy = 20, rp = -5 }), K(0.55, boxGuard), K(1.1, boxGuard) }, { sounds = { { t = 0.3, name = "bag_hit", chance = 0.6 } } })
M.boxing_slip = move(1.2, { K(0, boxGuard), K(0.2, boxGuard, { rr = -15, wr = -10, lkn = 30 }), K(0.5, boxGuard), K(0.7, boxGuard, { rr = 15, wr = 10, rkn = 30 }), K(1.2, boxGuard) })
M.boxing_combo = move(1.8, {
	K(0, boxGuard),
	K(0.12, boxGuard, { lsp = 88, lel = 5, lsy = 0, wy = -25 }),
	K(0.3, boxGuard),
	K(0.45, boxGuard, { rsp = 88, rel = 5, rsy = 0, wy = 25, rkn = 25 }),
	K(0.65, boxGuard),
	K(0.8, boxGuard, { lsp = 80, lel = 90, lsr = 70, lsy = 60, wy = -35 }),
	K(1.1, boxGuard),
	K(1.8, boxGuard),
}, { sounds = { { t = 0.12, name = "bag_hit" }, { t = 0.45, name = "bag_hit" }, { t = 0.8, name = "bag_hit" } } })

-- kickboxing
local kbGuard = merge(P.guardBox, { ry = 15, wy = -8, lsp = 45, rsp = 40 })
M.kickboxing_guard = move(1.2, { K(0, kbGuard), K(0.6, kbGuard, { rh = 0.12, grounded = false, lhp = 18 }), K(1.2, kbGuard) })
M.kick_roundhouse = move(1.4, {
	K(0, kbGuard),
	K(0.2, kbGuard, { rhp = 40, rhr = 45, rkn = 70, ry = -20, lhy = -40, rsp = -20, rsr = 30, rel = 20 }),
	K(0.38, kbGuard, { rhp = 35, rhr = 75, rkn = 5, ry = -70, rr = -20, lhy = -70, rsp = -30, rsr = 40, rel = 10 }),
	K(0.6, kbGuard, { rhp = 30, rhr = 40, rkn = 60, ry = -30 }),
	K(0.9, kbGuard),
	K(1.4, kbGuard),
}, { sounds = { { t = 0.38, name = "pad_kick", chance = 0.7 } } })
M.kick_front = move(1.2, {
	K(0, kbGuard),
	K(0.2, kbGuard, { rhp = 80, rkn = 100 }),
	K(0.35, kbGuard, { rhp = 85, rkn = 5, rp = -10 }),
	K(0.6, kbGuard, { rhp = 70, rkn = 100 }),
	K(1.2, kbGuard),
}, { sounds = { { t = 0.35, name = "pad_kick", chance = 0.5 } } })
M.kickboxing_combo = move(2.2, {
	K(0, kbGuard),
	K(0.12, kbGuard, { lsp = 88, lel = 5, lsy = 0, wy = -25 }),
	K(0.3, kbGuard),
	K(0.45, kbGuard, { rsp = 88, rel = 5, rsy = 0, wy = 25, rkn = 25 }),
	K(0.7, kbGuard),
	K(0.95, kbGuard, { lhp = 35, lhr = 75, lkn = 5, ry = 70, rr = 20, rhy = 70 }),
	K(1.3, kbGuard),
	K(2.2, kbGuard),
}, { sounds = { { t = 0.12, name = "bag_hit" }, { t = 0.45, name = "bag_hit" }, { t = 0.95, name = "pad_kick" } } })

-- muay thai
local mt = P.guardThai
M.muaythai_stance = move(1.6, { K(0, mt), K(0.8, mt, { lhp = 20, lkn = 25, rh = 0.1, grounded = false }), K(1.6, mt) })
M.muaythai_teep = move(1.4, { K(0, mt), K(0.25, mt, { lhp = 85, lkn = 100, rp = -5 }), K(0.45, mt, { lhp = 90, lkn = 0, rp = -15 }), K(0.75, mt, { lhp = 70, lkn = 90 }), K(1.4, mt) }, { sounds = { { t = 0.45, name = "pad_kick", chance = 0.6 } } })
M.muaythai_knee = move(1.3, { K(0, mt), K(0.2, mt, { lsp = 100, rsp = 100, lel = 70, rel = 70, rp = -15 }), K(0.4, mt, { lsp = 100, rsp = 100, lel = 70, rel = 70, rhp = 110, rkn = 130, rp = -20 }), K(0.7, mt, { lsp = 100, rsp = 100, lel = 70, rel = 70 }), K(1.3, mt) }, { sounds = { { t = 0.4, name = "bag_hit", chance = 0.7 } } })
M.muaythai_elbow = move(1.2, { K(0, mt), K(0.15, mt, { rsp = 90, rel = 150, rsr = 60, rsy = 30, wy = 10 }), K(0.3, mt, { rsp = 90, rel = 150, rsr = 60, rsy = 80, wy = -40 }), K(0.55, mt), K(1.2, mt) }, { sounds = { { t = 0.3, name = "bag_hit", chance = 0.6 } } })
M.muaythai_clinch = move(2, { K(0, mt), K(0.3, mt, { lsp = 120, rsp = 120, lel = 90, rel = 90, lsy = 40, rsy = 40, np = 10, rp = 8 }), K(0.8, mt, { lsp = 120, rsp = 120, lel = 90, rel = 90, lsy = 40, rsy = 40, np = 10, rp = 8, lhp = 100, lkn = 130 }), K(1.2, mt, { lsp = 120, rsp = 120, lel = 90, rel = 90, lsy = 40, rsy = 40, np = 10, rp = 8 }), K(2, mt) })

-- judo
local jd = P.judo
M.judo_stance = move(2, { K(0, jd), K(1, jd, { ry = 15, lhp = 25 }), K(2, jd) })
M.judo_grip = move(1.6, { K(0, jd), K(0.4, jd, { lsp = 85, lel = 30, rsp = 100, rel = 50, rz = 0.4 }), K(0.8, jd, { lsp = 70, lel = 60, rsp = 80, rel = 60, rz = -0.3, ry = 15 }), K(1.2, jd, { lsp = 85, lel = 30, rsp = 100, rel = 50 }), K(1.6, jd) })
M.judo_throw = move(2.4, {
	K(0, jd),
	K(0.3, jd, { ry = 170, rp = 30, lsp = 90, lel = 40, rsp = 110, rel = 60, lkn = 50, rkn = 50, lhp = 30, rhp = 30 }),
	K(0.7, jd, { ry = 180, rp = 70, lsp = 40, lel = 20, rsp = 150, rel = 30, lkn = 20, rkn = 20 }),
	K(1.2, jd, { ry = 180, rp = 50, lsp = 30, rsp = 60 }),
	K(2.0, jd),
	K(2.4, jd),
}, { loop = true })
M.judo_breakfall = move(2.4, {
	K(0, jd),
	K(0.5, jd, { rp = -20, rh = 1, grounded = false, lhp = 60, rhp = 60 }),
	K(0.8, P.lying, { lsr = 70, rsr = 70, lel = 0, rel = 0 }),
	K(1.3, P.lying, { lsr = 70, rsr = 70, lel = 0, rel = 0 }),
	K(1.9, merge(P.lying, { rp = -40 })),
	K(2.4, jd),
}, { sounds = { { t = 0.8, name = "mat_fall" } } })
M.judo_ground = move(3, { K(0, P.lying, { rp = -85 }), K(0.8, merge(P.lying, { rr = 40, lsp = 90, rsp = 90 })), K(1.6, merge(P.lying, { rr = 60, rp = -80, lhp = 30, rhp = 80 })), K(2.4, merge(P.lying, { rr = 30 })), K(3, P.lying, { rp = -85 }) })

-- BJJ
local bj = merge(P.judo, { rp = 18, lkn = 35, rkn = 35 })
M.bjj_stance = move(2, { K(0, bj), K(1, bj, { lhp = 30, ry = -10 }), K(2, bj) })
M.bjj_guard = move(2.4, { K(0, P.seatedGuard), K(0.8, P.seatedGuard, { lhp = 100, lkn = 50, rhp = 70 }), K(1.6, P.seatedGuard, { rhp = 100, rkn = 50, lhp = 70 }), K(2.4, P.seatedGuard) })
M.bjj_sweep = move(2.4, { K(0, P.seatedGuard), K(0.5, P.seatedGuard, { rr = 30, lhp = 110, lkn = 20, lhr = 50 }), K(1.0, merge(P.wrestle, { rp = 30 })), K(1.6, merge(P.wrestle, { rp = 40, np = -10 })), K(2.4, P.seatedGuard) })
M.bjj_shrimp = move(1.6, { K(0, P.lying), K(0.4, merge(P.lying, { rr = 70, lhp = 90, lkn = 110, rhp = 40, rkn = 60, rz = -0.5 })), K(0.8, merge(P.lying, { rr = 60, lhp = 40, lkn = 40, rhp = 100, rkn = 110, rz = -1.0 })), K(1.6, P.lying) })
M.bjj_submission = move(3, { K(0, P.seatedGuard), K(0.6, merge(P.lying, { lhp = 120, rhp = 120, lkn = 30, rkn = 30, lsp = 120, rsp = 120, lel = 60, rel = 60 })), K(2.0, merge(P.lying, { lhp = 125, rhp = 125, lkn = 25, rkn = 25, lsp = 125, rsp = 125, lel = 70, rel = 70, wp = 10 })), K(3, P.seatedGuard) })

-- taekwondo
local tk = P.tkd
M.tkd_stance = move(1, { K(0, tk), K(0.5, tk, { rh = 0.25, grounded = false }), K(1, tk) })
M.tkd_turning_kick = move(1.3, { K(0, tk), K(0.15, tk, { rhp = 60, rhr = 40, rkn = 110, ry = 0, lhy = -40 }), K(0.32, tk, { rhp = 50, rhr = 95, rkn = 5, ry = -60, rr = -25, lhy = -80, rsp = -30 }), K(0.6, tk, { rhp = 50, rhr = 40, rkn = 100 }), K(1.3, tk) }, { sounds = { { t = 0.32, name = "pad_kick", chance = 0.7 } } })
M.tkd_side_kick = move(1.5, { K(0, tk), K(0.25, tk, { rhp = 60, rhr = 30, rkn = 120, ry = 80 }), K(0.45, tk, { rhp = 10, rhr = 90, rkn = 0, ry = 90, rr = -35 }), K(0.8, tk, { rhp = 60, rhr = 30, rkn = 120, ry = 80 }), K(1.5, tk) }, { sounds = { { t = 0.45, name = "pad_kick", chance = 0.6 } } })
M.tkd_high_kick = move(1.5, { K(0, tk), K(0.2, tk, { rhp = 90, rhr = 50, rkn = 120 }), K(0.38, tk, { rhp = 70, rhr = 120, rkn = 5, ry = -70, rr = -35, lhy = -80 }), K(0.7, tk, { rhp = 90, rhr = 50, rkn = 110 }), K(1.5, tk) }, { sounds = { { t = 0.38, name = "pad_kick", chance = 0.6 } } })
M.tkd_poomsae = move(6, {
	K(0, P.stand, { lsp = 10, rsp = 10 }),
	K(0.8, P.zenkutsu, { ry = -90, lsp = 20, lel = 10, lsr = 30 }),
	K(1.6, P.zenkutsu, { ry = -90, rsp = 90, rel = 0, wy = 15 }),
	K(2.4, P.zenkutsu, { ry = 90, lsp = 130, lel = 70 }),
	K(3.2, P.zenkutsu, { ry = 90, rhp = 90, rkn = 5 }),
	K(4.0, P.zenkutsu, { ry = 0, lsp = 90, lel = 0 }),
	K(4.8, P.zenkutsu, { ry = 0, rsp = 90, rel = 0, wy = 15 }),
	K(6, P.stand, { lsp = 10, rsp = 10 }),
}, { sounds = { { t = 1.6, name = "pad_kick", chance = 0.2 } } })

-- wrestling
local wr = P.wrestle
M.wrestling_stance = move(1.6, { K(0, wr), K(0.8, wr, { rx = 0.4, ry = 8 }), K(1.6, wr) })
M.wrestling_shot = move(1.8, { K(0, wr), K(0.3, wr, { rp = 50, rz = 1.5, lhp = 80, lkn = 100, rhp = -10, rkn = 100, lsp = 90, rsp = 90, lel = 40, rel = 40 }), K(0.7, wr, { rp = 45, rz = 1.8, lhp = 20, lkn = 30, rhp = 50, rkn = 90, lsp = 80, rsp = 80, lel = 60, rel = 60 }), K(1.2, wr), K(1.8, wr) })
M.wrestling_sprawl = move(1.6, { K(0, wr), K(0.3, wr, { rp = 75, lhp = -40, rhp = -40, lkn = 0, rkn = 0, lhr = 25, rhr = 25, lsp = 90, rsp = 90, lel = 60, rel = 60, rz = -0.5 }), K(0.8, wr, { rp = 75, lhp = -40, rhp = -40, lkn = 0, rkn = 0, lhr = 25, rhr = 25, lsp = 90, rsp = 90 }), K(1.6, wr) }, { sounds = { { t = 0.3, name = "mat_fall", chance = 0.5 } } })
M.wrestling_clinch = move(2, { K(0, wr), K(0.4, wr, { rp = 20, lsp = 120, rsp = 70, lel = 80, rel = 100, lsy = 40, rsy = 40 }), K(1.0, wr, { rp = 25, lsp = 70, rsp = 120, lel = 100, rel = 80, lsy = 40, rsy = 40, ry = 20 }), K(1.5, wr, { rp = 20, lsp = 120, rsp = 70, lel = 80, rel = 100 }), K(2, wr) })
M.wrestling_throw = move(2.4, { K(0, wr), K(0.4, wr, { rp = 10, lsp = 110, rsp = 110, lel = 50, rel = 50, lsy = 40, rsy = 40 }), K(0.8, wr, { rp = -30, ry = 90, lsp = 140, rsp = 140, lel = 40, rel = 40, lkn = 40, rkn = 40 }), K(1.2, wr, { rp = 30, ry = 180, lsp = 60, rsp = 60 }), K(2.0, wr), K(2.4, wr) })

-- kung fu
local hs = P.horse
M.kungfu_horse = move(3, { K(0, hs), K(1.5, hs, { wp = 3, lel = 115, rel = 115 }), K(3, hs) })
M.kungfu_palm = move(1.4, { K(0, hs), K(0.2, hs, { rsp = 90, rel = 0, rsy = 0, wy = 20 }), K(0.6, hs, { rsp = 90, rel = 0, rsy = 0, wy = 20 }), K(0.8, hs, { lsp = 90, lel = 0, lsy = 0, wy = -20 }), K(1.4, hs) })
M.kungfu_kick = move(1.6, { K(0, P.stand, { lsp = 40, lel = 100, rsp = 40, rel = 100 }), K(0.3, P.stand, { lsp = 40, lel = 100, rsp = 40, rel = 100, rhp = 110, rkn = 0, rp = -10 }), K(0.6, P.stand, { lsp = 40, lel = 100, rsp = 40, rel = 100 }), K(1.0, hs), K(1.6, hs) }, { sounds = { { t = 0.3, name = "pad_kick", chance = 0.3 } } })
M.kungfu_block = move(1.6, { K(0, hs), K(0.3, hs, { lsp = 100, lel = 60, lsy = 50, rsp = 40, rel = 100 }), K(0.8, hs, { rsp = 100, rel = 60, rsy = 50, lsp = 40, lel = 100 }), K(1.6, hs) })
M.kungfu_crane = move(4, {
	K(0, P.stand),
	K(0.6, P.stand, { lhp = 70, lkn = 100, lsr = 120, rsr = 120, lel = 20, rel = 20, lsp = 20, rsp = 20 }),
	K(2.0, P.stand, { lhp = 75, lkn = 105, lsr = 130, rsr = 130, lel = 30, rel = 30, lsp = 30, rsp = 30, np = -5 }),
	K(2.6, P.stand, { lhp = 75, lkn = 105, rsp = 90, rel = 10, lsr = 120, lel = 20 }),
	K(3.4, P.stand, { lhp = 70, lkn = 100, lsr = 120, rsr = 120 }),
	K(4, P.stand),
})
M.kungfu_form = move(6, {
	K(0, P.stand, { lsp = 60, lel = 90, rsp = 60, rel = 90, lsy = 40, rsy = -40 }),
	K(0.8, hs, { rsp = 90, rel = 0, wy = 20 }),
	K(1.6, hs, { lsp = 90, lel = 0, wy = -20 }),
	K(2.4, P.zenkutsu, { ry = 45, rsp = 150, rel = 30, lsp = 90, lel = 0 }),
	K(3.2, P.stand, { lhp = 70, lkn = 100, lsr = 120, rsr = 120 }),
	K(4.0, P.stand, { rhp = 110, rkn = 0, lsp = 40, lel = 100, rsp = 40, rel = 100 }),
	K(4.8, hs, { lsp = 100, lel = 60, lsy = 50 }),
	K(6, P.stand, { lsp = 60, lel = 90, rsp = 60, rel = 90, lsy = 40, rsy = -40 }),
})

-- krav maga
local kv = merge(P.guardBox, { lsp = 60, lel = 90, rsp = 55, rel = 95, lsy = 0, rsy = 0 })
M.krav_stance = move(1.6, { K(0, kv), K(0.8, kv, { wp = 3, lhp = 18 }), K(1.6, kv) })
M.krav_360_block = move(2.4, {
	K(0, kv),
	K(0.3, kv, { lsp = 150, lel = 90, lsr = 30 }),
	K(0.7, kv, { lsp = 90, lel = 90, lsr = 80 }),
	K(1.1, kv, { lsp = 30, lel = 90, lsr = 60 }),
	K(1.5, kv, { rsp = 90, rel = 0, wy = 20 }),
	K(2.4, kv),
})
M.krav_palm = move(1.2, { K(0, kv), K(0.15, kv, { rsp = 100, rel = 10, wy = 25, rz = 0.3 }), K(0.5, kv), K(1.2, kv) }, { sounds = { { t = 0.15, name = "bag_hit", chance = 0.5 } } })
M.krav_knee = move(1.3, { K(0, kv), K(0.2, kv, { lsp = 100, rsp = 100, lel = 60, rel = 60, rp = -10 }), K(0.35, kv, { lsp = 100, rsp = 100, lel = 60, rel = 60, rhp = 100, rkn = 120 }), K(0.7, kv), K(1.3, kv) }, { sounds = { { t = 0.35, name = "bag_hit", chance = 0.5 } } })
M.krav_escape = move(2, { K(0, P.stand, { np = -20, lsp = 100, rsp = 100, lel = 120, rel = 120 }), K(0.4, P.stand, { lsp = 170, rel = 40, ry = 40, lkn = 40, rkn = 40 }), K(0.9, P.stand, { lsp = 90, lel = 100, ry = 90, rsp = 90, rel = 0 }), K(1.4, kv), K(2, kv) })

-- MMA
local mm = merge(P.guardBox, { lsp = 50, rsp = 45, lel = 110, rel = 115, lkn = 22, rkn = 22, rp = 6 })
M.mma_stance = move(1.4, { K(0, mm), K(0.7, mm, { rx = 0.3, rh = 0.1, grounded = false }), K(1.4, mm) })
M.mma_takedown = move(2.4, { K(0, mm), K(0.3, mm, { rp = 50, rz = 1.5, lhp = 80, lkn = 100, rkn = 100, lsp = 90, rsp = 90, lel = 40, rel = 40 }), K(0.8, mm, { rp = 30, ry = 40, lsp = 120, rsp = 120, lel = 60, rel = 60 }), K(1.4, mm, { rp = 60, lhp = 60, rhp = 60, lkn = 100, rkn = 100 }), K(2.4, mm) })
M.mma_ground_pound = move(1.6, { K(0, mm, { rp = 50, lhp = 80, rhp = 80, lkn = 110, rkn = 110 }), K(0.2, mm, { rp = 55, lhp = 80, rhp = 80, lkn = 110, rkn = 110, rsp = 160, rel = 60 }), K(0.4, mm, { rp = 60, lhp = 80, rhp = 80, lkn = 110, rkn = 110, rsp = 80, rel = 0 }), K(0.7, mm, { rp = 55, lhp = 80, rhp = 80, lkn = 110, rkn = 110, lsp = 160, lel = 60 }), K(0.9, mm, { rp = 60, lhp = 80, rhp = 80, lkn = 110, rkn = 110, lsp = 80, lel = 0 }), K(1.6, mm, { rp = 50, lhp = 80, rhp = 80, lkn = 110, rkn = 110 }) }, { sounds = { { t = 0.4, name = "mat_fall", chance = 0.4 }, { t = 0.9, name = "mat_fall", chance = 0.4 } } })

-- sumo
local sc = P.sumoCrouch
M.sumo_crouch = move(3, { K(0, sc), K(1.5, sc, { rp = 24, np = -10 }), K(3, sc) })
M.sumo_shiko = move(4, {
	K(0, sc),
	K(0.8, sc, { rhr = 75, rhp = 30, rkn = 30, lhr = 25, lhp = 20, lkn = 20, rr = -20, rsp = 60, rel = 0, rsr = 20 }),
	K(1.2, sc, { rhr = 75, rhp = 30, rkn = 30, lhr = 25, lhp = 20, lkn = 20, rr = -22, rsp = 60, rel = 0, rsr = 20 }),
	K(1.5, sc),
	K(2.3, sc, { lhr = 75, lhp = 30, lkn = 30, rhr = 25, rhp = 20, rkn = 20, rr = 20, lsp = 60, lel = 0, lsr = 20 }),
	K(2.7, sc, { lhr = 75, lhp = 30, lkn = 30, rhr = 25, rhp = 20, rkn = 20, rr = 22, lsp = 60, lel = 0, lsr = 20 }),
	K(3.0, sc),
	K(4, sc),
}, { sounds = { { t = 1.5, name = "stomp" }, { t = 3.0, name = "stomp" } } })
M.sumo_tachiai = move(2.4, {
	K(0, sc, { rp = 35, lsp = 20, rsp = 20, lel = 0, rel = 0 }),
	K(0.6, sc, { rp = 45, lsp = 10, rsp = 10, lel = 0, rel = 0, lhp = 80, rhp = 80 }),
	K(0.85, sc, { rp = 30, rz = 2, lsp = 90, rsp = 90, lel = 10, rel = 10, lhp = 40, rhp = -10, lkn = 60, rkn = 20, lhr = 20, rhr = 20 }),
	K(1.5, sc, { rp = 30, rz = 2, lsp = 90, rsp = 90, lel = 30, rel = 30 }),
	K(2.4, sc, { rp = 35, lsp = 20, rsp = 20, lel = 0, rel = 0 }),
}, { sounds = { { t = 0.85, name = "stomp" } } })
M.sumo_push = move(1.4, { K(0, sc, { rp = 25, lsp = 80, rsp = 80, lel = 60, rel = 60 }), K(0.3, sc, { rp = 25, rz = 0.8, lsp = 95, rsp = 70, lel = 10, rel = 60 }), K(0.7, sc, { rp = 25, rz = 0.8, lsp = 70, rsp = 95, lel = 60, rel = 10 }), K(1.4, sc, { rp = 25, lsp = 80, rsp = 80, lel = 60, rel = 60 }) })
M.sumo_teppo = move(1.4, { K(0, sc, { rp = 15, rsp = 80, rel = 60 }), K(0.25, sc, { rp = 15, rsp = 95, rel = 5, wy = 20 }), K(0.6, sc, { rp = 15, lsp = 80, lel = 60 }), K(0.85, sc, { rp = 15, lsp = 95, lel = 5, wy = -20 }), K(1.4, sc, { rp = 15, rsp = 80, rel = 60 }) }, { sounds = { { t = 0.25, name = "bag_hit" }, { t = 0.85, name = "bag_hit" } } })

-- general fitness
M.fitness_idle = move(2, { K(0, P.stand, { lsr = 15, rsr = 15 }), K(1, P.stand, { lsr = 20, rsr = 20, wr = 5 }), K(2, P.stand, { lsr = 15, rsr = 15 }) })
M.fitness_squat = move(1.8, { K(0, P.stand, { lsp = 90, rsp = 90, lel = 0, rel = 0 }), K(0.8, P.stand, { lsp = 90, rsp = 90, lel = 0, rel = 0, lhp = 90, rhp = 90, lkn = 110, rkn = 110, rp = 25, lhr = 15, rhr = 15 }), K(1.8, P.stand, { lsp = 90, rsp = 90, lel = 0, rel = 0 }) })
M.fitness_jumping_jack = move(0.9, { K(0, P.stand), K(0.45, P.stand, { lsr = 160, rsr = 160, lhr = 20, rhr = 20, rh = 0.4, grounded = false }), K(0.9, P.stand) })
M.fitness_pushup = move(1.6, { K(0, P.stand, { rp = 75, lsp = 90, rsp = 90, lel = 0, rel = 0, lhp = -10, rhp = -10 }), K(0.8, P.stand, { rp = 85, lsp = 60, rsp = 60, lel = 90, rel = 90, lhp = -10, rhp = -10 }), K(1.6, P.stand, { rp = 75, lsp = 90, rsp = 90, lel = 0, rel = 0, lhp = -10, rhp = -10 }) })
M.fitness_lunge = move(2, { K(0, P.handsHips), K(0.7, P.handsHips, { lhp = 70, lkn = 90, rhp = -30, rkn = 80 }), K(1.0, P.handsHips), K(1.7, P.handsHips, { rhp = 70, rkn = 90, lhp = -30, lkn = 80 }), K(2, P.handsHips) })
M.fitness_lift = move(2.4, { K(0, P.stand, { lsp = 30, rsp = 30, lel = 140, rel = 140 }), K(0.8, P.stand, { lsp = 170, rsp = 170, lel = 0, rel = 0 }), K(1.4, P.stand, { lsp = 170, rsp = 170, lel = 0, rel = 0 }), K(2.4, P.stand, { lsp = 30, rsp = 30, lel = 140, rel = 140 }) })
M.fitness_run = move(0.6, { K(0, P.relaxed, { lhp = 45, lkn = 30, rhp = -30, rkn = 70, lsp = -40, rsp = 40, lel = 90, rel = 90, rp = 8 }), K(0.3, P.relaxed, { rhp = 45, rkn = 30, lhp = -30, lkn = 70, rsp = -40, lsp = 40, lel = 90, rel = 90, rp = 8 }), K(0.6, P.relaxed, { lhp = 45, lkn = 30, rhp = -30, rkn = 70, lsp = -40, rsp = 40, lel = 90, rel = 90, rp = 8 }) })
M.fitness_curl = move(1.6, { K(0, P.stand, { lel = 10, rel = 10 }), K(0.6, P.stand, { lel = 140, rel = 10 }), K(0.8, P.stand, { lel = 10, rel = 10 }), K(1.4, P.stand, { rel = 140, lel = 10 }), K(1.6, P.stand, { lel = 10, rel = 10 }) })
M.relax_sit = move(4, { K(0, P.stand, { seat = true, lhp = 90, rhp = 90, lkn = 90, rkn = 90, lsp = 30, rsp = 30, lel = 40, rel = 40 }), K(2, P.stand, { seat = true, lhp = 90, rhp = 90, lkn = 90, rkn = 90, lsp = 30, rsp = 30, lel = 40, rel = 40, np = 10 }), K(4, P.stand, { seat = true, lhp = 90, rhp = 90, lkn = 90, rkn = 90, lsp = 30, rsp = 30, lel = 40, rel = 40 }) })

-- equipment use (stations)
local guardHigh = { lsp = 75, lel = 105, rsp = 75, rel = 105, lsy = 25, rsy = 25, np = -4 }
M.boxing_speedbag = move(0.5, { K(0, P.stand, guardHigh), K(0.12, P.stand, guardHigh, { lsp = 95, lel = 80 }), K(0.25, P.stand, guardHigh), K(0.37, P.stand, guardHigh, { rsp = 95, rel = 80 }), K(0.5, P.stand, guardHigh) }, { sounds = { { t = 0.12, name = "bag_hit", chance = 0.25 } } })
local seated = { lhp = 90, rhp = 90, lkn = 90, rkn = 90, seat = true }
M.fitness_cycle = move(0.8, {
	K(0, seated, { rp = 22, lsp = 75, rsp = 75, lel = 25, rel = 25, lhp = 110, lkn = 120, rhp = 70, rkn = 60 }),
	K(0.4, seated, { rp = 22, lsp = 75, rsp = 75, lel = 25, rel = 25, lhp = 70, lkn = 60, rhp = 110, rkn = 120 }),
	K(0.8, seated, { rp = 22, lsp = 75, rsp = 75, lel = 25, rel = 25, lhp = 110, lkn = 120, rhp = 70, rkn = 60 }),
})
M.fitness_row = move(2, {
	K(0, seated, { rp = 30, lsp = 80, rsp = 80, lel = 0, rel = 0, lhp = 120, rhp = 120, lkn = 130, rkn = 130 }),
	K(0.8, seated, { rp = -15, lsp = 40, rsp = 40, lel = 110, rel = 110, lhp = 80, rhp = 80, lkn = 10, rkn = 10 }),
	K(2, seated, { rp = 30, lsp = 80, rsp = 80, lel = 0, rel = 0, lhp = 120, rhp = 120, lkn = 130, rkn = 130 }),
})
local benchLie = { rp = -88, lhp = 40, rhp = 40, lkn = 85, rkn = 85, lhr = 15, rhr = 15, np = 20 }
M.fitness_bench = move(2.2, {
	K(0, benchLie, { lsp = 90, rsp = 90, lsr = 40, rsr = 40, lel = 100, rel = 100 }),
	K(1.0, benchLie, { lsp = 90, rsp = 90, lsr = 10, rsr = 10, lel = 0, rel = 0 }),
	K(2.2, benchLie, { lsp = 90, rsp = 90, lsr = 40, rsr = 40, lel = 100, rel = 100 }),
})
M.fitness_pullup = move(2, {
	K(0, P.stand, { lsr = 165, rsr = 165, lel = 5, rel = 5, lkn = 40, rkn = 40, rh = 1.2, grounded = false }),
	K(0.9, P.stand, { lsr = 135, rsr = 135, lel = 120, rel = 120, lkn = 40, rkn = 40, np = -10, rh = 2.6, grounded = false }),
	K(2, P.stand, { lsr = 165, rsr = 165, lel = 5, rel = 5, lkn = 40, rkn = 40, rh = 1.2, grounded = false }),
})
local barOnBack = { lsr = 75, rsr = 75, lel = 120, rel = 120, lsy = -40, rsy = -40 }
M.fitness_squat_bar = move(2.4, {
	K(0, P.stand, barOnBack),
	K(1.1, P.stand, barOnBack, { lhp = 95, rhp = 95, lkn = 115, rkn = 115, rp = 28, lhr = 15, rhr = 15 }),
	K(2.4, P.stand, barOnBack),
})
M.changing = move(3, {
	K(0, P.stand, { lsp = 60, rsp = 60, lel = 120, rel = 120, lsy = 40, rsy = 40, np = 10 }),
	K(1, P.stand, { lsr = 120, rsr = 120, lel = 60, rel = 60, np = -5 }),
	K(2, P.stand, { rsp = 70, rel = 60, np = 15, wy = 15 }),
	K(3, P.stand, { lsp = 60, rsp = 60, lel = 120, rel = 120, lsy = 40, rsy = 40, np = 10 }),
})
M.showering = move(2.6, {
	K(0, P.stand, { lsr = 140, rsr = 140, lel = 70, rel = 70, np = -15 }),
	K(1.3, P.stand, { lsr = 150, rsr = 130, lel = 50, rel = 90, np = -10, wr = 4 }),
	K(2.6, P.stand, { lsr = 140, rsr = 140, lel = 70, rel = 70, np = -15 }),
})
M.sit_drink = move(3, {
	K(0, seated, { rsp = 40, rel = 110, lsp = 30, lel = 40 }),
	K(1, seated, { rsp = 70, rel = 140, lsp = 30, lel = 40, np = -18 }),
	K(1.8, seated, { rsp = 70, rel = 140, lsp = 30, lel = 40, np = -18 }),
	K(3, seated, { rsp = 40, rel = 110, lsp = 30, lel = 40 }),
})
M.relax_lie = move(4, { K(0, P.lying, { lhp = 0, rhp = 0, lkn = 0, rkn = 0, lsr = 20, rsr = 20 }), K(2, P.lying, { lhp = 0, rhp = 0, lkn = 0, rkn = 0, lsr = 22, rsr = 22, wp = -3 }), K(4, P.lying, { lhp = 0, rhp = 0, lkn = 0, rkn = 0, lsr = 20, rsr = 20 }) })
M.browse = move(4, {
	K(0, P.stand, { ny = 25, np = 5 }),
	K(1.2, P.stand, { ny = -10, np = -5, rsp = 80, rel = 30 }),
	K(2.4, P.stand, { ny = -25, np = 8 }),
	K(4, P.stand, { ny = 25, np = 5 }),
})

-- emotes (also used for victory poses on player avatars)
M.emote_bow = move(2.5, { K(0, P.stand), K(0.6, P.stand, { rp = 35, np = 10 }), K(1.6, P.stand, { rp = 35, np = 10 }), K(2.5, P.stand) }, { loop = false })
M.emote_kata_salute = move(3, { K(0, P.stand), K(0.5, P.stand, { lsp = 80, rsp = 80, lel = 90, rel = 90, lsy = 50, rsy = 50 }), K(1.4, P.stand, { lsp = 80, rsp = 80, lel = 90, rel = 90, lsy = 50, rsy = 50, rp = 20 }), K(2.2, P.kiba, { lsp = 90, lel = 0, rsp = 20, rel = 110 }), K(3, P.stand) }, { loop = false })
M.emote_champion = move(3, { K(0, P.stand), K(0.5, P.stand, { lsr = 160, rsr = 160, lel = 0, rel = 0, np = -15 }), K(2.2, P.stand, { lsr = 165, rsr = 165, lel = 0, rel = 0, np = -20, wy = 15 }), K(3, P.stand) }, { loop = false })
M.emote_flex = move(3, { K(0, P.stand), K(0.5, P.stand, { lsr = 90, rsr = 90, lel = 120, rel = 120, lsy = -60, rsy = -60, lhr = 15, rhr = 15 }), K(2.2, P.stand, { lsr = 95, rsr = 95, lel = 130, rel = 130, lsy = -60, rsy = -60, lhr = 15, rhr = 15, wp = -5 }), K(3, P.stand) }, { loop = false })

Poses.moves = M
Poses.base = P

-- Moves for general rooms (no discipline).
Poses.roomMoves = {
	fitness_room = { idle = "fitness_idle", drill = { "fitness_squat", "fitness_jumping_jack", "fitness_pushup", "fitness_lunge" }, teach = { "coach_count", "coach_clap" } },
	strength_room = { idle = "fitness_idle", drill = { "fitness_lift", "fitness_curl", "fitness_squat" }, teach = { "coach_point", "coach_clap" } },
	cardio_room = { idle = "fitness_idle", drill = { "fitness_run", "fitness_jumping_jack", "fitness_run" }, teach = { "coach_whistle", "coach_clap" } },
	recovery_room = { idle = "relax_sit", drill = { "relax_sit" } },
	locker_room = { idle = "idle", drill = { "idle" } },
	showers = { idle = "idle", drill = { "idle" } },
	juice_bar = { idle = "drink", drill = { "drink" } },
	merch_shop = { idle = "idle", drill = { "idle" } },
}

-- Sample a move at time t (seconds). Returns a pose table.
function Poses.sample(m, t)
	local keys = m.keys
	if m.loop then
		t = t % m.length
	elseif t >= m.length then
		return keys[#keys].p
	end
	if t <= keys[1].t then
		return keys[1].p
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local span = b.t - a.t
			local x = span > 0 and (t - a.t) / span or 1
			-- smoothstep easing
			x = x * x * (3 - 2 * x)
			return Poses.blend(a.p, b.p, x)
		end
	end
	return keys[#keys].p
end

function Poses.blend(a, b, x)
	local out = {}
	for k, v in pairs(a) do
		if type(v) == "number" then
			local w = b[k]
			if type(w) ~= "number" then
				w = 0
			end
			out[k] = v + (w - v) * x
		end
	end
	for k, w in pairs(b) do
		if type(w) == "number" and out[k] == nil then
			out[k] = w * x
		end
	end
	-- grounding: a pose is airborne if either side is airborne
	out.grounded = not ((a.grounded == false and x < 0.999) or (b.grounded == false and x > 0.001))
	-- seated poses rest the hips on the seat instead of the feet on the floor
	out.seat = (a.seat == true) or (b.seat == true) or nil
	return out
end


return Poses
