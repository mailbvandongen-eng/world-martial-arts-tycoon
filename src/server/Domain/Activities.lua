-- Active gameplay rules: training challenges, tournaments, student profiles
-- and achievements. Pure Lua (time and randomness come in as arguments), so
-- every rule is covered by the offline tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RNG = require(Shared.Modules.RNG)
local Util = require(Shared.Modules.Util)
local Formulas = require(Shared.Modules.Formulas)
local Config = require(Shared.Config.Activities)
local Disciplines = require(Shared.Config.Disciplines)
local Trainers = require(Shared.Config.Trainers)
local Economy = require(script.Parent.Economy)

local Activities = {}

---------------------------------------------------------------- training challenges

-- Prompt schedule for a challenge (deterministic per seed).
function Activities.prompts(gameId, seed)
	local game = Config.games[gameId]
	local rng = RNG.new(seed)
	local list = {}
	local t = 0.6
	for i = 1, game.prompts do
		local action
		if game.sequence then
			action = game.actions[(i - 1) % #game.actions + 1]
		else
			action = game.actions[rng:int(1, #game.actions)]
		end
		table.insert(list, { t = t, a = action })
		t = t + rng:range(game.gapMin, game.gapMax)
	end
	return list, t + 0.6
end

function Activities.startChallenge(d, gameId, now, seed)
	local game = Config.games[gameId]
	if not game then
		return false, "Unknown challenge"
	end
	if game.discipline and not d.disciplines[game.discipline] then
		return false, "Unlock " .. Disciplines.byId[game.discipline].name .. " first"
	end
	local last = d.minigame.lastAt or 0
	if now - last < Config.GAME_COOLDOWN then
		return false, "Catch your breath: " .. math.ceil(Config.GAME_COOLDOWN - (now - last)) .. "s"
	end
	local prompts, duration = Activities.prompts(gameId, seed)
	local challenge = { game = gameId, seed = seed, startAt = now + Config.GAME_COUNTDOWN, duration = duration, count = #prompts }
	d.minigame.lastAt = now
	return true, challenge, prompts
end

-- responses: list of { i = prompt index, a = action, t = seconds since start }.
-- Returns { perfect, good, miss, score (0-100) }. Only the first answer per prompt counts.
function Activities.scoreChallenge(challenge, responses)
	local prompts = Activities.prompts(challenge.game, challenge.seed)
	local answered = {}
	local perfect, good = 0, 0
	if type(responses) == "table" then
		for n, r in ipairs(responses) do
			if n > #prompts * 2 then
				break
			end
			local i = type(r) == "table" and tonumber(r.i)
			local p = i and prompts[i]
			if p and not answered[i] and r.a == p.a and type(r.t) == "number" and r.t == r.t then
				answered[i] = true
				local dt = math.abs(r.t - p.t)
				if dt <= Config.PERFECT then
					perfect = perfect + 1
				elseif dt <= Config.GOOD then
					good = good + 1
				end
			end
		end
	end
	local miss = #prompts - perfect - good
	local score = math.floor((perfect * 1 + good * 0.6) / #prompts * 100 + 0.5)
	return { perfect = perfect, good = good, miss = miss, score = score }
end

-- Validates the timing of a submission and grants rewards. now = server time.
function Activities.finishChallenge(d, challenge, responses, now, dayNumber)
	if not challenge then
		return false, "No challenge running"
	end
	local endAt = challenge.startAt + challenge.duration
	if now < endAt - 0.5 then
		return false, "Too early"
	end
	if now > endAt + 30 then
		return false, "Challenge expired"
	end
	local result = Activities.scoreChallenge(challenge, responses)
	local game = Config.games[challenge.game]
	if d.minigame.day ~= dayNumber then
		d.minigame.day = dayNumber
		d.minigame.plays = 0
	end
	d.minigame.plays = d.minigame.plays + 1
	local factor = d.minigame.plays <= Config.GAME_DAILY_FULL and 1 or 0.2
	local q = result.score / 100
	result.cash = math.floor(Formulas.rewardCashUnit(d.level) * 0.6 * q * factor)
	result.xp = math.floor(30 * q * factor)
	result.mastery = game.discipline and math.floor(40 * q * factor) or 0
	result.reduced = factor < 1
	Economy.earn(d, result.cash)
	d.stats.miniGames = (d.stats.miniGames or 0) + 1
	if result.score > (d.minigame.best[challenge.game] or 0) then
		d.minigame.best[challenge.game] = result.score
		result.newBest = true
	end
	return true, result
end

---------------------------------------------------------------- tournaments

-- The tournament of the time slot containing `now`.
function Activities.tournamentAt(now)
	local slot = math.floor(now / Config.TOURNAMENT_EVERY)
	local def = Config.tournaments[slot % #Config.tournaments + 1]
	local startAt = slot * Config.TOURNAMENT_EVERY
	local regEnd = startAt + Config.TOURNAMENT_REGISTRATION
	local rounds = {}
	for r = 1, 3 do
		rounds[r] = regEnd + (r - 1) * Config.TOURNAMENT_ROUND_GAP
	end
	return {
		key = slot, id = def.id, name = def.name, discipline = def.discipline,
		startAt = startAt, regEnd = regEnd, rounds = rounds, endAt = rounds[3] + 8,
		nextAt = startAt + Config.TOURNAMENT_EVERY,
	}
end

-- Strength of an academy in a discipline (nil = best discipline).
function Activities.strength(d, disciplineId)
	local best = 0
	for _, disc in ipairs(Disciplines.list) do
		if (disciplineId == nil or disc.id == disciplineId) and d.disciplines[disc.id] then
			local m = d.mastery[disc.id]
			local s = (m and m.rank or 1) * 12
			local bestTrainer = 0
			for _, t in pairs(d.trainers) do
				if t.discipline == disc.id then
					local r = Trainers.rarityById[t.rarity]
					bestTrainer = math.max(bestTrainer, r.order * 9 + t.level + t.upgrade * 2)
				end
			end
			local bestRoom = 0
			for _, branch in pairs(d.cities) do
				for _, room in pairs(branch.rooms) do
					if room.id == disc.id .. "_room" then
						bestRoom = math.max(bestRoom, room.level)
					end
				end
			end
			s = s + bestTrainer + bestRoom * 6
			best = math.max(best, s)
		end
	end
	return best
end

-- Fill the bracket with rival academies around the entrants' strength.
function Activities.fillBracket(entrants, seed)
	local rng = RNG.new(seed)
	local list = {}
	local total = 0
	for _, e in ipairs(entrants) do
		table.insert(list, e)
		total = total + e.strength
	end
	local avg = #entrants > 0 and total / #entrants or 30
	local names = Util.shallowCopy(Config.rivals)
	while #list < Config.TOURNAMENT_SIZE do
		local name = table.remove(names, rng:int(1, #names))
		table.insert(list, { name = name, strength = math.max(10, avg * rng:range(0.6, 1.25)), rival = true })
	end
	-- shuffle
	for i = #list, 2, -1 do
		local j = rng:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Simulate one match. Higher strength wins more often, upsets happen.
function Activities.match(a, b, rng)
	local pa = a.strength / (a.strength + b.strength)
	pa = Util.clamp(0.5 + (pa - 0.5) * 1.6, 0.08, 0.92)
	local winner = rng:next() < pa and a or b
	local loser = winner == a and b or a
	return winner, loser
end

-- Plays the whole bracket. Returns rounds = { { {a, b, winner} ... } ... } and
-- places = { [entry] = place }.
function Activities.playBracket(bracket, seed)
	local rng = RNG.new(seed + 99)
	local rounds = {}
	local places = {}
	local current = bracket
	local placeForLosers = { 5, 3, 2 }
	for r = 1, 3 do
		local results = {}
		local nextRound = {}
		for i = 1, #current, 2 do
			local a, b = current[i], current[i + 1]
			local winner, loser = Activities.match(a, b, rng)
			table.insert(results, { a = a, b = b, winner = winner })
			table.insert(nextRound, winner)
			places[loser] = placeForLosers[r]
		end
		rounds[r] = results
		current = nextRound
	end
	places[current[1]] = 1
	return rounds, places
end

function Activities.prizeFor(place)
	local best
	for _, p in ipairs(Config.prizes) do
		if place >= p.place then
			best = p
		end
	end
	return best
end

function Activities.enterTournament(d, t, now)
	if now >= t.regEnd then
		return false, "Registration is closed"
	end
	if t.discipline and not d.disciplines[t.discipline] then
		return false, "Unlock " .. Disciplines.byId[t.discipline].name .. " to enter"
	end
	if d.tournament.key == t.key then
		return false, "Already entered"
	end
	local fee = Formulas.rewardCashUnit(d.level) * Config.ENTRY_FEE
	if not Economy.spend(d, fee) then
		return false, "Entry fee " .. tostring(fee)
	end
	d.tournament = { key = t.key }
	d.stats.tournamentsPlayed = (d.stats.tournamentsPlayed or 0) + 1
	return true, { fee = fee, strength = Activities.strength(d, t.discipline) }
end

function Activities.awardTournament(d, place)
	local prize = Activities.prizeFor(place)
	local unit = Formulas.rewardCashUnit(d.level)
	local cash = math.floor(prize.cash * unit)
	Economy.earn(d, cash)
	d.gems = d.gems + prize.gems
	Economy.addReputation(d, prize.reputation)
	if place == 1 then
		d.stats.tournamentWins = (d.stats.tournamentWins or 0) + 1
	end
	local levels, gems = Economy.addXp(d, prize.xp)
	return { place = place, cash = cash, gems = prize.gems, reputation = prize.reputation, xp = prize.xp, levels = levels, levelGems = gems }
end

---------------------------------------------------------------- students

local FIRST = { "Aiko", "Ben", "Chen", "Dara", "Eli", "Femke", "Gio", "Hana", "Ivan", "Jade", "Kofi", "Lena", "Milo", "Nora", "Omar", "Pia",
	"Quinn", "Rosa", "Sami", "Tess", "Umar", "Vera", "Wes", "Xena", "Yuki", "Zane", "Liam", "Mila", "Noah", "Sara", "Tom", "Yara" }
local LAST = { "A.", "B.", "C.", "D.", "E.", "F.", "G.", "H.", "J.", "K.", "L.", "M.", "N.", "P.", "R.", "S.", "T.", "V.", "W." }

function Activities.rankXpNeeded(rank)
	return math.floor(30 * 1.55 ^ (rank - 1))
end

-- New student profile (a satisfied visitor who became a member).
function Activities.newStudent(d, rng, disciplineId, seed)
	d.nextStudentId = (d.nextStudentId or 1)
	local id = "s" .. d.nextStudentId
	d.nextStudentId = d.nextStudentId + 1
	local student = {
		id = id,
		name = rng:pick(FIRST) .. " " .. rng:pick(LAST),
		discipline = disciplineId,
		rank = 1,
		xp = 0,
		talent = rng:int(1, 5),
		satisfaction = 70,
		visits = 1,
		seed = seed,
	}
	-- roster is bounded: replace the student who visited least
	local count = Util.count(d.students)
	if count >= Config.ROSTER_MAX then
		local worst
		for sid, s in pairs(d.students) do
			if not worst or s.visits < d.students[worst].visits then
				worst = sid
			end
		end
		d.students[worst] = nil
	end
	d.students[id] = student
	return student
end

-- Pick a returning student for a discipline (or nil).
function Activities.returningStudent(d, rng, disciplineId)
	local options = {}
	for _, s in pairs(d.students) do
		if s.discipline == disciplineId then
			table.insert(options, s)
		end
	end
	table.sort(options, function(a, b)
		return a.id < b.id
	end)
	if #options == 0 or not rng:chance(Config.RETURN_CHANCE) then
		return nil
	end
	return rng:pick(options)
end

-- A class finished for a roster student: progress, maybe a graduation.
-- Returns new rank (or nil). The academy's mastery caps student ranks.
function Activities.studentAttended(d, student, classXp, satisfaction)
	student.visits = student.visits + 1
	student.satisfaction = math.floor(student.satisfaction * 0.8 + satisfaction * 0.2 + 0.5)
	local disc = Disciplines.byId[student.discipline]
	if not disc then
		return nil
	end
	local cap = (d.mastery[student.discipline] and d.mastery[student.discipline].rank) or 1
	student.xp = student.xp + classXp * (0.6 + student.talent * 0.2)
	if student.rank < cap and student.xp >= Activities.rankXpNeeded(student.rank) then
		student.xp = student.xp - Activities.rankXpNeeded(student.rank)
		student.rank = student.rank + 1
		d.stats.graduations = (d.stats.graduations or 0) + 1
		return student.rank
	end
	if student.rank >= cap then
		student.xp = math.min(student.xp, Activities.rankXpNeeded(student.rank))
	end
	return nil
end

---------------------------------------------------------------- achievements

local function achieved(d, a)
	local kind, arg = string.match(a.check, "^(%w+):?(.*)$")
	if kind == "stat" then
		return (d.stats[arg] or 0) >= a.target
	elseif kind == "rank" then
		local m = d.mastery[arg]
		return m ~= nil and m.rank >= a.target
	elseif kind == "trainer" then
		local minOrder = tonumber(arg)
		for _, t in pairs(d.trainers) do
			if Trainers.rarityById[t.rarity].order >= minOrder then
				return true
			end
		end
		return false
	elseif kind == "cities" then
		return Util.count(d.cities) >= a.target
	end
	return false
end

-- Unlock every achievement that is now met. Returns the newly unlocked list.
function Activities.checkAchievements(d)
	local new = {}
	for _, a in ipairs(Config.achievements) do
		if not d.achievements[a.id] and achieved(d, a) then
			d.achievements[a.id] = true
			d.gems = d.gems + a.gems
			table.insert(new, a)
		end
	end
	return new
end

return Activities
