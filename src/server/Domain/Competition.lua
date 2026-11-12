-- Competition hall rules: sparring between your students, belt exams and your
-- own kumite against rival fighters. Pure Lua (time and seeds come in as
-- arguments). Every bout is simulated with Modules/Bout, so the client can
-- show it move by move with a live scoreboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RNG = require(Shared.Modules.RNG)
local Bout = require(Shared.Modules.Bout)
local Formulas = require(Shared.Modules.Formulas)
local Config = require(Shared.Config.Activities)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)
local Activities = require(script.Parent.Activities)
local Economy = require(script.Parent.Economy)

local Competition = {}

local FIRST = { "Kenji", "Mara", "Tomas", "Rin", "Duko", "Ines", "Sven", "Lola", "Yusuf", "Kaito", "Bea", "Ravi", "Nina", "Joon", "Elsa", "Marco" }

-- Best trainer of a discipline adds to the skill of its students.
function Competition.trainerBonus(d, disciplineId)
	local best = 0
	for _, t in pairs(d.trainers) do
		if t.discipline == disciplineId then
			local r = Trainers.rarityById[t.rarity]
			best = math.max(best, (r and r.order or 1) * 6 + (t.level or 1) + (t.upgrade or 0) * 2)
		end
	end
	return math.min(60, best)
end

function Competition.studentSkill(d, s)
	return s.rank * 10 + s.talent * 8 + Competition.trainerBonus(d, s.discipline) + math.floor((s.satisfaction or 70) / 10)
end

-- What the client needs to draw a student (appearance seed, belt).
function Competition.fighterView(d, s)
	return { name = s.name, seed = s.seed, rank = s.rank, discipline = s.discipline, id = s.id }
end

---------------------------------------------------------------- sparring

-- Two students of the same discipline (most promising first), or nil.
function Competition.pickSparPair(d, rng, disciplineId)
	local byDisc = {}
	for _, s in pairs(d.students) do
		if not disciplineId or s.discipline == disciplineId then
			byDisc[s.discipline] = byDisc[s.discipline] or {}
			table.insert(byDisc[s.discipline], s)
		end
	end
	local options = {}
	for disc, list in pairs(byDisc) do
		if #list >= 2 then
			table.insert(options, disc)
		end
	end
	table.sort(options)
	if #options == 0 then
		return nil
	end
	-- karate first when available: it is the deepest discipline
	local disc = options[rng:int(1, #options)]
	for _, o in ipairs(options) do
		if o == "karate" then
			disc = o
		end
	end
	local list = byDisc[disc]
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	local i = rng:int(1, #list)
	local j = rng:int(1, #list - 1)
	if j >= i then
		j = j + 1
	end
	return list[i].id, list[j].id
end

function Competition.spar(d, aId, bId, now, seed)
	local a, b = d.students[aId], d.students[bId]
	if not a or not b or aId == bId then
		return false, "Pick two of your students"
	end
	if a.discipline ~= b.discipline then
		return false, "Sparring partners must train the same discipline"
	end
	local wait = Config.SPAR_COOLDOWN - (now - (d.compete.lastSpar or 0))
	if wait > 0 then
		return false, "The mat is being cleaned: " .. math.ceil(wait) .. "s"
	end
	d.compete.lastSpar = now
	local bout = Bout.simulate({ name = a.name, skill = Competition.studentSkill(d, a) }, { name = b.name, skill = Competition.studentSkill(d, b) }, seed, { discipline = a.discipline })
	local winner = bout.winner == 1 and a or b
	local loser = winner == a and b or a
	winner.wins = (winner.wins or 0) + 1
	loser.losses = (loser.losses or 0) + 1
	local ready = {}
	for _, s in ipairs({ a, b }) do
		local xp = s == winner and 8 or 5
		if Activities.addStudentXp(d, s, xp) == "ready" then
			table.insert(ready, s.name)
		end
		s.satisfaction = math.min(100, s.satisfaction + 2)
	end
	d.compete.spars = (d.compete.spars or 0) + 1
	Economy.addReputation(d, 2)
	return true, {
		kind = "spar", discipline = a.discipline,
		red = Competition.fighterView(d, a), blue = Competition.fighterView(d, b),
		bouts = { bout }, winner = winner.name, method = bout.method, ready = ready, reputation = 2,
	}
end

---------------------------------------------------------------- belt exams

function Competition.passMark(rank)
	return 18.5 + rank * 0.55
end

function Competition.examFee(d, s)
	return math.floor(Formulas.rewardCashUnit(d.level) * Config.EXAM_FEE * s.rank)
end

-- Runs the exam: a kata (three judges) and, from green belt on, a kumite
-- against an examiner. Returns the bouts and whether the student passed.
function Competition.runExam(d, s, seed)
	local skill = Competition.studentSkill(d, s)
	local rng = RNG.new(seed)
	local disc = Disciplines.byId[s.discipline]
	local moves
	if s.discipline ~= "karate" and s.discipline ~= "taekwondo" and s.discipline ~= "kungfu" then
		moves = disc.moves.drill -- technique demonstration for disciplines without forms
	end
	local kata = Bout.kataScore({ skill = skill }, seed, { discipline = s.discipline, rank = s.rank, moves = moves })
	local bouts = { kata }
	local kumiteOk = true
	if s.rank >= Config.EXAM_KUMITE_FROM then
		local examiner = { name = "Examiner", skill = 10 * (s.rank + 1) + 25 }
		local fight = Bout.simulate({ name = s.name, skill = skill }, examiner, rng:int(1, 2147483000), { discipline = s.discipline })
		table.insert(bouts, fight)
		local scored = fight.format == "rounds" and (fight.cards and fight.cards[1] or 0) or fight.score[1]
		kumiteOk = fight.winner == 1 or scored >= (fight.format == "kumite" and 3 or 1)
	end
	local passMark = Competition.passMark(s.rank)
	return { bouts = bouts, total = kata.total, marks = kata.marks, passMark = passMark, passed = kata.total >= passMark and kumiteOk, kumiteOk = kumiteOk }
end

local function promote(d, s)
	s.rank = s.rank + 1
	s.examReady = nil
	s.waited = nil
	s.examAt = nil
	d.stats.graduations = (d.stats.graduations or 0) + 1
	return s.rank
end

function Competition.exam(d, sid, now, seed)
	local s = d.students[sid]
	if not s then
		return false, "Unknown student"
	end
	if not s.examReady then
		return false, s.name .. " is not ready for an exam yet"
	end
	if s.examAt and now < s.examAt then
		return false, s.name .. " may retry in " .. math.ceil(s.examAt - now) .. "s"
	end
	local fee = Competition.examFee(d, s)
	if not Economy.spend(d, fee) then
		return false, "Exam fee " .. tostring(fee)
	end
	local disc = Disciplines.byId[s.discipline]
	local rankBefore = s.rank
	local exam = Competition.runExam(d, s, seed)
	local res = {
		kind = "exam", discipline = s.discipline, red = Competition.fighterView(d, s), blue = { name = "Examiner", seed = seed % 100000 + 7, rank = #disc.ranks, discipline = s.discipline },
		bouts = exam.bouts, total = exam.total, marks = exam.marks, passMark = exam.passMark, passed = exam.passed, fee = fee,
		fromRank = disc.ranks[rankBefore].name,
	}
	if exam.passed then
		local rank = promote(d, s)
		res.rankName = disc.ranks[rank].name
		res.rank = rank
		d.compete.examsPassed = (d.compete.examsPassed or 0) + 1
		Economy.addReputation(d, 10)
		res.reputation = 10
	else
		s.examAt = now + Config.EXAM_RETRY
		d.compete.examsFailed = (d.compete.examsFailed or 0) + 1
		res.reason = not exam.kumiteOk and "the kumite was not strong enough" or ("kata " .. exam.total .. " / needed " .. exam.passMark)
	end
	return true, res
end

-- A ready student who waited too long is examined by the sensei during class
-- (no show, no fee). Returns the new rank or nil.
function Competition.autoExam(d, s, seed)
	local exam = Competition.runExam(d, s, seed)
	if exam.passed then
		return promote(d, s)
	end
	s.waited = 0
	return nil
end

---------------------------------------------------------------- your own kumite

function Competition.kumiteLevel(d)
	local c = d.compete
	return math.max(1, math.min(20, 1 + (c.kumiteWins or 0) - math.floor((c.kumiteLosses or 0) / 2)))
end

function Competition.opponent(level, seed)
	local rng = RNG.new(seed)
	return {
		name = FIRST[rng:int(1, #FIRST)],
		academy = Config.rivals[rng:int(1, #Config.rivals)],
		level = level,
		rank = math.min(10, 1 + math.floor(level / 2)),
		seed = rng:int(1, 2147483000),
	}
end

-- Opponent attacks (prompts) for a level. Deterministic per seed.
function Competition.kumitePrompts(level, seed)
	local k = Config.kumite
	local rng = RNG.new(seed)
	local list = {}
	local gapMax = math.max(k.gapMin + 0.25, k.gapMax - k.speedUp * (level - 1))
	local gapMin = math.max(k.gapMin - 0.15, k.gapMin - k.speedUp * (level - 1) * 0.5)
	local t = 1.2
	for i = 1, k.prompts do
		local r = rng:next()
		local a
		if r < 0.3 then
			a = 1
		elseif r < 0.58 then
			a = 2
		elseif r < 0.8 + math.min(0.08, level * 0.005) then
			a = 3
		else
			a = 4
		end
		table.insert(list, { t = t, a = a })
		t = t + rng:range(gapMin, gapMax)
	end
	return list, t + 1
end

function Competition.startKumite(d, now, seed)
	local wait = Config.kumite.COOLDOWN - (now - (d.compete.lastKumite or 0))
	if wait > 0 then
		return false, "Catch your breath: " .. math.ceil(wait) .. "s"
	end
	d.compete.lastKumite = now
	local level = Competition.kumiteLevel(d)
	local prompts, duration = Competition.kumitePrompts(level, seed)
	local challenge = { kind = "kumite", seed = seed, level = level, startAt = now + Config.GAME_COUNTDOWN, duration = duration,
		opponent = Competition.opponent(level, seed + 11) }
	return true, challenge, prompts
end

-- Score the answers in order. Returns { score = {you, opponent}, winner (1 = you),
-- events (for the scoreboard replay), endT, method }.
function Competition.scoreKumite(challenge, responses)
	local k = Config.kumite
	local prompts = Competition.kumitePrompts(challenge.level, challenge.seed)
	local byPrompt = {}
	if type(responses) == "table" then
		for n, r in ipairs(responses) do
			if n > #prompts * 2 then
				break
			end
			local i = type(r) == "table" and tonumber(r.i)
			if i and prompts[i] and not byPrompt[i] and type(r.a) == "string" and type(r.t) == "number" and r.t == r.t then
				byPrompt[i] = r
			end
		end
	end
	local score = { 0, 0 }
	local events = { { t = 0.2, r = "call", txt = "Hajime!" } }
	local first
	local endT = prompts[#prompts].t + 1
	local method
	for i, p in ipairs(prompts) do
		local atk = k.attacks[p.a]
		local r = byPrompt[i]
		local dt = r and math.abs(r.t - p.t) or math.huge
		local correct = r and r.a == atk.answer
		if correct and dt <= Config.PERFECT then
			score[1] = score[1] + atk.perfect
			first = first or 1
			table.insert(events, { t = p.t, s = 1, r = "score", p = atk.perfect, m = "karate_punch", d = "hit_react", txt = atk.perfect >= 3 and "Ippon!" or "Waza-ari!" })
		elseif correct and dt <= Config.GOOD then
			score[1] = score[1] + atk.good
			first = first or 1
			table.insert(events, { t = p.t, s = 1, r = "score", p = atk.good, m = "karate_punch", d = "hit_react", txt = atk.good >= 2 and "Waza-ari!" or "Yuko!" })
		elseif atk.lose > 0 then
			score[2] = score[2] + atk.lose
			first = first or 2
			table.insert(events, { t = p.t, s = 2, r = "score", p = atk.lose, m = atk.move, d = "hit_react", txt = atk.lose >= 2 and "Waza-ari!" or "Yuko!" })
		end
		if math.abs(score[1] - score[2]) >= k.lead then
			endT = p.t + 0.5
			method = k.lead .. "-point lead"
			break
		end
	end
	local winner
	if score[1] ~= score[2] then
		winner = score[1] > score[2] and 1 or 2
		method = method or "Points"
	elseif first then
		winner = first
		method = "Senshu (first score)"
	else
		winner = 2
		method = "Hantei (referee decision)"
	end
	table.insert(events, { t = endT, r = "end", s = winner, txt = method })
	return { score = score, winner = winner, events = events, endT = endT, method = method }
end

function Competition.finishKumite(d, challenge, responses, now, dayNumber)
	if not challenge or challenge.kind ~= "kumite" then
		return false, "No kumite running"
	end
	local endAt = challenge.startAt + challenge.duration
	if now < challenge.startAt + 1 then
		return false, "Too early"
	end
	if now > endAt + 30 then
		return false, "Bout expired"
	end
	local res = Competition.scoreKumite(challenge, responses)
	-- an early finish (8-point lead) may be submitted as soon as it happened
	if now < challenge.startAt + res.endT - 0.5 then
		return false, "Too early"
	end
	if d.minigame.day ~= dayNumber then
		d.minigame.day = dayNumber
		d.minigame.plays = 0
	end
	d.minigame.plays = d.minigame.plays + 1
	local factor = d.minigame.plays <= Config.GAME_DAILY_FULL and 1 or 0.2
	local c = d.compete
	local won = res.winner == 1
	local level = challenge.level
	if won then
		c.kumiteWins = (c.kumiteWins or 0) + 1
		c.streak = (c.streak or 0) + 1
		c.bestStreak = math.max(c.bestStreak or 0, c.streak)
		res.cash = math.floor(Formulas.rewardCashUnit(d.level) * 0.8 * (1 + 0.1 * (level - 1)) * factor)
		res.xp = math.floor(40 * factor)
		res.mastery = math.floor(50 * factor)
		res.reputation = 8 + level * 2
	else
		c.kumiteLosses = (c.kumiteLosses or 0) + 1
		c.streak = 0
		res.cash = 0
		res.xp = math.floor(10 * factor)
		res.mastery = math.floor(15 * factor)
		res.reputation = 0
	end
	Economy.earn(d, res.cash)
	Economy.addReputation(d, res.reputation)
	d.stats.miniGames = (d.stats.miniGames or 0) + 1
	res.won = won
	res.level = level
	res.nextLevel = Competition.kumiteLevel(d)
	res.opponent = challenge.opponent
	res.reduced = factor < 1
	return true, res
end

return Competition
