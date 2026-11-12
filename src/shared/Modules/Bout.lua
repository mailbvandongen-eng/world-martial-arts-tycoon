-- Fight engine: simulates one bout exchange by exchange with the real scoring
-- of the discipline, so a match can be shown move by move with a live
-- scoreboard. Pure Lua; the server runs it once and sends the resulting
-- timeline, clients only play it back (Bout.stateAt).
--
-- Formats
--   kumite  karate: yuko 1 (punch), waza-ari 2 (body kick), ippon 3 (head kick,
--           sweep + punch). Ends at an 8-point lead or on time; equal score:
--           the first to score wins (senshu).
--   points  taekwondo, kung fu, krav maga: body 2, head 3, punch 1. 12-point gap.
--   rounds  boxing, kickboxing, Muay Thai, MMA: 3 rounds of clean hits, knockdowns
--           (3 = stoppage), judges' decision 10-9 per round.
--   ippon   judo, wrestling, BJJ: waza-ari / takedown points; an ippon or a
--           submission ends the bout at once.
--   sumo    a few clashes until one wrestler is pushed out or thrown.
--   kata    two performers show a form; five judges raise a flag (AKA / AO).
--
-- A fighter = { name, skill (≈10-200), style (optional) }.
-- Result = { format, duration, events = { ... }, score = { a, b }, winner = 1|2,
--            method, rounds = n }. Event = { t, s = attacking side, m = move,
--            d = defender move, r = "score"|"block"|"miss"|"down"|"round"|"call"|"flags"|"end",
--            p = points, txt = referee call }.

local RNG = require(script.Parent.RNG)

local Bout = {}

Bout.FORMAT_BY_DISCIPLINE = {
	karate = "kumite", taekwondo = "points", kungfu = "points", kravmaga = "points",
	boxing = "rounds", kickboxing = "rounds", muaythai = "rounds", mma = "rounds",
	judo = "ippon", wrestling = "ippon", bjj = "ippon", sumo = "sumo",
}

-- Techniques per discipline: { move, points, call, weight }. Defence = move used to block.
local TECH = {
	kumite = {
		attacks = {
			{ "karate_punch", 1, "Yuko!", 6 },
			{ "karate_front_kick", 2, "Waza-ari!", 3 },
			{ "karate_roundhouse", 3, "Ippon!", 1.2 },
		},
		block = "karate_block", idle = "karate_stance", gap = { 1.8, 2.6 }, limit = 30, lead = 8,
	},
	points = {
		attacks = {
			{ "tkd_turning_kick", 2, "Body kick, 2", 5 },
			{ "tkd_high_kick", 3, "Head kick, 3", 2 },
			{ "kick_front", 1, "Point", 3 },
		},
		block = "karate_block", idle = "tkd_stance", gap = { 1.6, 2.4 }, limit = 30, lead = 12,
	},
	rounds = {
		attacks = {
			{ "boxing_jab", 1, nil, 6 },
			{ "boxing_cross", 1, nil, 4 },
			{ "boxing_hook", 2, nil, 3 },
			{ "boxing_uppercut", 2, nil, 2 },
		},
		block = "boxing_slip", idle = "boxing_guard", gap = { 1.1, 1.7 }, roundLength = 12, roundCount = 3,
	},
	ippon = {
		attacks = {
			{ "judo_grip", 0, nil, 4 },
			{ "judo_throw", 1, "Waza-ari!", 3 },
			{ "judo_throw", 2, "Ippon!", 0.8 },
		},
		block = "judo_breakfall", idle = "judo_stance", gap = { 2.0, 2.8 }, limit = 30, finish = 2,
	},
	sumo = {
		attacks = {
			{ "sumo_tachiai", 0, nil, 3 },
			{ "sumo_push", 1, "Oshidashi!", 2 },
		},
		block = "sumo_push", idle = "sumo_crouch", gap = { 1.5, 2.2 }, limit = 14,
	},
}

-- Discipline-specific moves for the striking families.
local STRIKES = {
	kickboxing = { { "boxing_jab", 1, nil, 5 }, { "boxing_cross", 1, nil, 4 }, { "kick_roundhouse", 2, nil, 3 }, { "kick_front", 1, nil, 2 } },
	muaythai = { { "kick_roundhouse", 2, nil, 4 }, { "muaythai_teep", 1, nil, 3 }, { "muaythai_knee", 2, nil, 2 }, { "muaythai_elbow", 2, nil, 2 } },
	mma = { { "boxing_jab", 1, nil, 5 }, { "kick_roundhouse", 2, nil, 3 }, { "mma_takedown", 2, nil, 2 }, { "mma_ground_pound", 2, nil, 1.5 } },
	kungfu = { { "kungfu_palm", 1, "Point", 4 }, { "kungfu_kick", 2, "Kick, 2", 3 }, { "kungfu_crane", 3, "Clean strike, 3", 1 } },
	kravmaga = { { "krav_palm", 1, "Point", 5 }, { "krav_knee", 2, "Knee, 2", 3 }, { "krav_escape", 1, "Escape", 1 } },
	wrestling = { { "wrestling_clinch", 0, nil, 4 }, { "wrestling_shot", 2, "Takedown, 2", 3 }, { "wrestling_throw", 4, "Fall!", 0.7 } },
	bjj = { { "bjj_guard", 0, nil, 3 }, { "bjj_sweep", 2, "Sweep, 2", 3 }, { "bjj_submission", 4, "Tap out!", 0.7 } },
}

local KATA_MOVES = {
	karate = { "karate_kata", "karate_punch", "karate_block", "karate_front_kick", "karate_kata", "karate_roundhouse", "karate_punch", "emote_kata_salute" },
	taekwondo = { "tkd_poomsae", "tkd_side_kick", "tkd_turning_kick", "tkd_poomsae", "tkd_high_kick", "kick_front" },
	kungfu = { "kungfu_form", "kungfu_palm", "kungfu_crane", "kungfu_kick", "kungfu_form", "kungfu_block" },
}
Bout.KATA_NAMES = { "Heian Shodan", "Heian Nidan", "Bassai Dai", "Kanku Dai", "Jion", "Empi", "Unsu", "Gojushiho" }

function Bout.formatFor(disciplineId)
	return Bout.FORMAT_BY_DISCIPLINE[disciplineId] or "points"
end

function Bout.techniques(format, disciplineId)
	local base = TECH[format] or TECH.points
	local attacks = STRIKES[disciplineId]
	if attacks and (format == "rounds" or format == "points" or format == "ippon") then
		return { attacks = attacks, block = base.block, idle = base.idle, gap = base.gap, limit = base.limit, lead = base.lead,
			roundLength = base.roundLength, roundCount = base.roundCount, finish = 4 }
	end
	return base
end

local function pick(rng, attacks)
	local total = 0
	for _, a in ipairs(attacks) do
		total = total + a[4]
	end
	local r = rng:next() * total
	for _, a in ipairs(attacks) do
		r = r - a[4]
		if r <= 0 then
			return a
		end
	end
	return attacks[#attacks]
end

-- Chance that side A wins an exchange. Skill matters, upsets stay possible.
function Bout.edge(a, b)
	local sa, sb = math.max(1, a.skill or 10), math.max(1, b.skill or 10)
	local p = sa / (sa + sb)
	p = 0.5 + (p - 0.5) * 1.5
	if p < 0.12 then
		p = 0.12
	elseif p > 0.88 then
		p = 0.88
	end
	return p
end

local function finish(res, winner, method, t)
	res.winner = winner
	res.method = method
	res.duration = t + 3
	table.insert(res.events, { t = t + 0.6, r = "end", s = winner, txt = method })
	return res
end

-- Who leads when time runs out (used by kumite/points/ippon/sumo).
local function onTime(res, rng, a, b, firstScorer, t)
	if res.score[1] ~= res.score[2] then
		return finish(res, res.score[1] > res.score[2] and 1 or 2, "Points", t)
	end
	if firstScorer then
		return finish(res, firstScorer, "Senshu (first score)", t)
	end
	-- hantei: the referee decides, slightly in favour of the better fighter
	return finish(res, rng:next() < Bout.edge(a, b) and 1 or 2, "Decision", t)
end

local function simulatePointFight(format, a, b, rng, tech, opts)
	local res = { format = format, events = {}, score = { 0, 0 }, rounds = 1 }
	local p = Bout.edge(a, b)
	local t = 1.5
	table.insert(res.events, { t = 0.2, r = "call", txt = format == "sumo" and "Hakkiyoi!" or format == "ippon" and "Hajime!" or "Hajime!" })
	local firstScorer
	local limit = tech.limit
	local favour = opts.favour -- forced winner (tournament brackets decided elsewhere)
	while t < limit do
		local side = rng:next() < p and 1 or 2
		if favour and rng:next() < 0.25 then
			side = favour
		end
		local atk = pick(rng, tech.attacks)
		local ev = { t = t, s = side, m = atk[1] }
		local hit = rng:next() < 0.55
		if format == "sumo" then
			-- two or three clashes, then a decisive push
			if t > 4 and rng:next() < 0.45 then
				ev.m, ev.d, ev.r, ev.p, ev.txt = "sumo_push", "judo_breakfall", "score", 1, rng:next() < 0.5 and "Oshidashi!" or "Yorikiri!"
				res.score[side] = 1
				table.insert(res.events, ev)
				return finish(res, side, ev.txt, t)
			end
			ev.m, ev.d, ev.r = "sumo_tachiai", "sumo_push", "block"
		elseif atk[2] == 0 then
			ev.d, ev.r = tech.block, "miss"
		elseif hit then
			ev.d, ev.r, ev.p, ev.txt = "hit_react", "score", atk[2], atk[3]
			if format == "ippon" and atk[2] >= tech.finish then
				ev.d = "judo_breakfall"
			end
			res.score[side] = res.score[side] + atk[2]
			firstScorer = firstScorer or side
		else
			ev.d, ev.r = tech.block, "block"
		end
		table.insert(res.events, ev)
		if ev.r == "score" then
			if format == "ippon" then
				-- judo: ippon or two waza-ari; BJJ / wrestling: submission or fall
				if atk[2] >= tech.finish then
					return finish(res, side, ev.txt or "Ippon!", t)
				elseif tech.finish == 2 and res.score[side] >= 2 then
					return finish(res, side, "Ippon! (two waza-ari)", t)
				end
			elseif tech.lead and math.abs(res.score[1] - res.score[2]) >= tech.lead then
				return finish(res, side, tech.lead .. "-point lead", t)
			end
		end
		t = t + rng:range(tech.gap[1], tech.gap[2])
	end
	table.insert(res.events, { t = t, r = "call", txt = "Yame! Time" })
	return onTime(res, rng, a, b, firstScorer, t)
end

local function simulateRounds(a, b, rng, tech, opts)
	local res = { format = "rounds", events = {}, score = { 0, 0 }, rounds = tech.roundCount, cards = { 0, 0 } }
	-- many exchanges per round: a smaller edge per exchange keeps upsets possible
	local p = 0.5 + (Bout.edge(a, b) - 0.5) * 0.6
	local downs = { 0, 0 }
	local t = 0.2
	for round = 1, tech.roundCount do
		table.insert(res.events, { t = t, r = "round", p = round, txt = "Round " .. round })
		local roundHits = { 0, 0 }
		local tEnd = t + tech.roundLength
		t = t + 1.4
		while t < tEnd do
			local side = rng:next() < p and 1 or 2
			if opts.favour and rng:next() < 0.25 then
				side = opts.favour
			end
			local atk = pick(rng, tech.attacks)
			local ev = { t = t, s = side, m = atk[1] }
			if rng:next() < 0.5 then
				ev.d, ev.r, ev.p = "hit_react", "score", atk[2]
				roundHits[side] = roundHits[side] + atk[2]
				-- a heavy shot can drop the opponent
				if atk[2] >= 2 and rng:next() < 0.06 + (side == 1 and p - 0.5 or 0.5 - p) * 0.08 then
					ev.r, ev.d, ev.txt = "down", "judo_breakfall", "Knockdown!"
					local other = 3 - side
					downs[other] = downs[other] + 1
					roundHits[side] = roundHits[side] + 3
					if downs[other] >= 3 or (rng:next() < 0.25 and not opts.favour) or (opts.favour == side and rng:next() < 0.4) then
						table.insert(res.events, ev)
						res.score[side] = res.score[side] + 1
						return finish(res, side, "KO in round " .. round, t)
					end
				end
			else
				ev.d, ev.r = tech.block, "block"
			end
			table.insert(res.events, ev)
			t = t + rng:range(tech.gap[1], tech.gap[2])
		end
		-- judges' card: 10-9 to the busier fighter
		local w = roundHits[1] == roundHits[2] and (rng:next() < p and 1 or 2) or (roundHits[1] > roundHits[2] and 1 or 2)
		if opts.favour and round == tech.roundCount then
			-- the decision must match a pre-decided bracket result
			if res.cards[3 - opts.favour] + (w == 3 - opts.favour and 1 or 0) >= 2 then
				w = opts.favour
				if res.cards[3 - opts.favour] >= 2 then
					res.cards[3 - opts.favour] = 1
					res.cards[opts.favour] = res.cards[opts.favour] + 1
				end
			end
		end
		res.cards[w] = res.cards[w] + 1
		res.score[w] = res.score[w] + 1
		table.insert(res.events, { t = tEnd, r = "round", s = w, p = round, txt = "Round " .. round .. " to " .. (w == 1 and "red" or "blue") })
		t = tEnd + 1.5
	end
	res.score = { res.cards[1], res.cards[2] }
	local winner = res.cards[1] > res.cards[2] and 1 or 2
	return finish(res, winner, "Decision " .. math.max(res.cards[1], res.cards[2]) .. "-" .. math.min(res.cards[1], res.cards[2]), t)
end

-- Kata: both perform one after another, five judges raise flags.
function Bout.kata(a, b, seed, opts)
	opts = opts or {}
	local rng = RNG.new(seed)
	local moves = KATA_MOVES[opts.discipline or "karate"] or KATA_MOVES.karate
	local res = { format = "kata", events = {}, score = { 0, 0 }, kata = {}, rounds = 1 }
	local t = 0.5
	local quality = {}
	for side, f in ipairs({ a, b }) do
		local name = Bout.KATA_NAMES[rng:int(1, #Bout.KATA_NAMES)]
		res.kata[side] = name
		table.insert(res.events, { t = t, s = side, r = "call", txt = (side == 1 and "Aka" or "Ao") .. ": " .. name })
		t = t + 1
		for i = 1, #moves do
			table.insert(res.events, { t = t, s = side, m = moves[i], r = "kata" })
			t = t + 1.25
		end
		quality[side] = (f.skill or 10) * rng:range(0.8, 1.2)
		t = t + 1
	end
	-- five judges: each compares the two performances with some noise
	local flags = {}
	local p = quality[1] / (quality[1] + quality[2])
	p = 0.5 + (p - 0.5) * 1.6
	for j = 1, 5 do
		flags[j] = rng:next() < p and 1 or 2
	end
	if opts.favour then
		local count = 0
		for j = 1, 5 do
			if flags[j] == opts.favour then
				count = count + 1
			end
		end
		local j = 1
		while count < 3 do
			if flags[j] ~= opts.favour then
				flags[j] = opts.favour
				count = count + 1
			end
			j = j + 1
		end
	end
	for j = 1, 5 do
		res.score[flags[j]] = res.score[flags[j]] + 1
	end
	res.flags = flags
	table.insert(res.events, { t = t, r = "flags", flags = flags, txt = "Hantei!" })
	local winner = res.score[1] > res.score[2] and 1 or 2
	return finish(res, winner, res.score[winner] .. "-" .. res.score[3 - winner] .. " flags", t + 1.5)
end

-- Kata performance on its own (belt exam): three judges give marks 5.0-9.5.
function Bout.kataScore(performer, seed, opts)
	opts = opts or {}
	local rng = RNG.new(seed)
	local moves = KATA_MOVES[opts.discipline or "karate"] or { "karate_kata" }
	local res = { format = "exam", events = {}, score = { 0, 0 }, rounds = 1 }
	local t = 0.5
	local name = Bout.KATA_NAMES[math.min(#Bout.KATA_NAMES, opts.rank or 1)]
	res.kata = { name }
	table.insert(res.events, { t = t, s = 1, r = "call", txt = "Kata: " .. name })
	t = t + 1
	local custom = opts.moves or moves
	for i = 1, #custom do
		table.insert(res.events, { t = t, s = 1, m = custom[i], r = "kata" })
		t = t + 1.2
	end
	local base = 5 + math.min(4.2, (performer.skill or 10) / 30)
	local marks = {}
	local total = 0
	for j = 1, 3 do
		local m = math.floor((base + rng:range(-0.7, 0.6)) * 10 + 0.5) / 10
		m = math.max(5, math.min(9.5, m))
		marks[j] = m
		total = total + m
	end
	res.marks = marks
	res.total = math.floor(total * 10 + 0.5) / 10
	table.insert(res.events, { t = t, r = "marks", marks = marks, txt = "Marks" })
	res.duration = t + 3
	return res
end

-- Simulate a bout. opts: { discipline, favour = 1|2 (forced winner), ... }
function Bout.simulate(a, b, seed, opts)
	opts = opts or {}
	local format = opts.format or Bout.formatFor(opts.discipline)
	if format == "kata" then
		return Bout.kata(a, b, seed, opts)
	end
	local rng = RNG.new(seed)
	local tech = Bout.techniques(format, opts.discipline)
	local res
	if format == "rounds" then
		res = simulateRounds(a, b, rng, tech, opts)
	else
		res = simulatePointFight(format, a, b, rng, tech, opts)
	end
	if opts.favour and res.winner ~= opts.favour and not opts.noRetry then
		-- very rare: rerun with another seed until the bracket result holds
		for k = 1, 20 do
			local again = Bout.simulate(a, b, seed + k * 7919, { discipline = opts.discipline, format = format, favour = opts.favour, noRetry = true })
			if again.winner == opts.favour then
				return again
			end
		end
		res.winner = opts.favour
	end
	res.idle = tech.idle
	return res
end

-- Scoreboard state at time t (seconds since the bout started).
function Bout.stateAt(bout, t)
	local s = { score = { 0, 0 }, call = nil, callSide = nil, round = 1, finished = false, cards = { 0, 0 } }
	for _, ev in ipairs(bout.events) do
		if ev.t > t then
			break
		end
		if ev.r == "score" or ev.r == "down" then
			if bout.format ~= "rounds" then
				s.score[ev.s] = s.score[ev.s] + (ev.p or 0)
			end
		elseif ev.r == "round" then
			s.round = ev.p or s.round
			if ev.s and bout.format == "rounds" then
				s.cards[ev.s] = s.cards[ev.s] + 1
			end
		elseif ev.r == "flags" then
			for _, f in ipairs(ev.flags) do
				s.score[f] = s.score[f] + 1
			end
		elseif ev.r == "end" then
			s.finished = true
		end
		if ev.txt then
			s.call, s.callSide, s.callT = ev.txt, ev.s, ev.t
		end
	end
	if bout.format == "rounds" then
		s.score = s.cards
	elseif bout.format == "sumo" and s.finished then
		s.score = bout.score
	end
	return s
end

-- The event a fighter is performing at time t (for animation).
function Bout.actionAt(bout, side, t)
	local best
	for _, ev in ipairs(bout.events) do
		if ev.t > t then
			break
		end
		if ev.m and (ev.s == side or (ev.d and ev.s ~= side)) and t - ev.t < 1.1 then
			best = ev
		end
	end
	if not best then
		return nil
	end
	if best.s == side then
		return best.m, t - best.t
	end
	return best.d, t - best.t
end

return Bout
