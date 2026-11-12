-- Active gameplay between income cycles: training challenges (mini-games),
-- tournaments and achievements. All numbers are tuned so active play helps
-- but never replaces academy income.

local Activities = {}

---------------------------------------------------------------- training challenges
-- A challenge shows timed prompts; the player taps the matching action.
-- The server generates the prompts and scores the taps.
Activities.games = {
	karate = {
		name = "Kata Challenge", discipline = "karate", icon = "🥋",
		description = "Follow the kata: punch, block, kick and kiai on the beat.",
		actions = { "Punch", "Block", "Kick", "Kiai" }, prompts = 14, gapMin = 0.75, gapMax = 1.1,
		moves = { Punch = "karate_punch", Block = "karate_block", Kick = "karate_front_kick", Kiai = "emote_kata_salute" },
	},
	boxing = {
		name = "Heavy Bag Combos", discipline = "boxing", icon = "🥊",
		description = "Hit the bag with the called punch. Fast hands, perfect timing.",
		actions = { "Jab", "Cross", "Hook", "Upper" }, prompts = 16, gapMin = 0.55, gapMax = 0.85,
		moves = { Jab = "boxing_jab", Cross = "boxing_cross", Hook = "boxing_hook", Upper = "boxing_uppercut" },
	},
	sumo = {
		name = "Dohyo Balance", discipline = "sumo", icon = "🏋",
		description = "Keep your balance: shift left or right, push when the opponent leans in.",
		actions = { "Left", "Right", "Push" }, prompts = 14, gapMin = 0.7, gapMax = 1.0,
		moves = { Left = "sumo_shiko", Right = "sumo_shiko", Push = "sumo_push" },
	},
	judo = {
		name = "Throw Practice", discipline = "judo", icon = "🤼",
		description = "Grip, break the balance, throw. Keep the sequence and the timing.",
		actions = { "Grip", "Balance", "Throw" }, prompts = 15, gapMin = 0.7, gapMax = 0.95, sequence = true,
		moves = { Grip = "judo_grip", Balance = "judo_grip", Throw = "judo_throw" },
	},
	fitness = {
		name = "Workout Rush", discipline = nil, icon = "💪",
		description = "Squat, push-up and jump on the rhythm of the coach.",
		actions = { "Squat", "Push-up", "Jump" }, prompts = 16, gapMin = 0.6, gapMax = 0.8,
		moves = { Squat = "fitness_squat", ["Push-up"] = "fitness_pushup", Jump = "fitness_jumping_jack" },
	},
}
Activities.gameOrder = { "karate", "boxing", "judo", "sumo", "fitness" }
Activities.GAME_COUNTDOWN = 3
Activities.GAME_COOLDOWN = 25 -- seconds between rewarded plays of any challenge
Activities.GAME_DAILY_FULL = 15 -- full rewards per UTC day; after that 20%
Activities.PERFECT = 0.15 -- seconds
Activities.GOOD = 0.35

---------------------------------------------------------------- tournaments
-- One tournament every ROUND_LENGTH seconds, rotating through the list. Players
-- enter their academy during registration; empty places are filled by rival
-- academies. Matches are simulated on the server.
Activities.TOURNAMENT_EVERY = 480
Activities.TOURNAMENT_REGISTRATION = 150
Activities.TOURNAMENT_ROUND_GAP = 35
Activities.TOURNAMENT_SIZE = 8
Activities.tournaments = {
	{ id = "karate_champ", name = "Karate Championship", discipline = "karate" },
	{ id = "boxing_tour", name = "Boxing Tournament", discipline = "boxing" },
	{ id = "judo_champ", name = "Judo Championship", discipline = "judo" },
	{ id = "intl_cup", name = "International Martial Arts Cup", discipline = nil },
	{ id = "kickboxing_cup", name = "Kickboxing Cup", discipline = "kickboxing" },
	{ id = "sumo_challenge", name = "Sumo Challenge", discipline = "sumo" },
	{ id = "muaythai_night", name = "Muay Thai Fight Night", discipline = "muaythai" },
	{ id = "tkd_open", name = "Taekwondo Open", discipline = "taekwondo" },
}
Activities.rivals = {
	"Tiger Claw Dojo", "Iron Fist Gym", "Rising Sun Academy", "Crimson Lotus School", "Thunder Ring Club",
	"Silver Crane Dojo", "Golden Glove Gym", "Black Belt Factory", "Northern Wind Academy", "Kumite Kings",
	"Red Dragon Kwoon", "Harbor Fight Team", "Stone Mountain Stable", "Blue Wave Judo Club",
}
-- Prize multipliers (x mission cash unit) per final place: 1, 2, 3-4, 5-8.
Activities.prizes = {
	{ place = 1, cash = 10, gems = 40, reputation = 120, xp = 250 },
	{ place = 2, cash = 5, gems = 20, reputation = 60, xp = 150 },
	{ place = 3, cash = 2.5, gems = 10, reputation = 30, xp = 90 },
	{ place = 5, cash = 1, gems = 0, reputation = 10, xp = 50 },
}
Activities.ENTRY_FEE = 1 -- x mission cash unit

---------------------------------------------------------------- achievements
-- check = stat path or special check; target = value needed.
Activities.achievements = {
	{ id = "first_student", name = "First Student", text = "Serve your first student.", check = "stat:studentsServed", target = 1, gems = 10 },
	{ id = "students_100", name = "Busy Dojo", text = "Serve 100 students.", check = "stat:studentsServed", target = 100, gems = 25 },
	{ id = "students_1000", name = "Packed Halls", text = "Serve 1,000 students.", check = "stat:studentsServed", target = 1000, gems = 60 },
	{ id = "students_10000", name = "Martial Arts Institution", text = "Serve 10,000 students.", check = "stat:studentsServed", target = 10000, gems = 150 },
	{ id = "first_tournament", name = "First Tournament Victory", text = "Win a tournament.", check = "stat:tournamentWins", target = 1, gems = 40 },
	{ id = "tournaments_10", name = "Tournament Dynasty", text = "Win 10 tournaments.", check = "stat:tournamentWins", target = 10, gems = 120 },
	{ id = "karate_master", name = "Karate Master", text = "Reach black belt mastery in karate.", check = "rank:karate", target = 7, gems = 80 },
	{ id = "boxing_champion", name = "Boxing Champion", text = "Reach Champion rank in boxing.", check = "rank:boxing", target = 6, gems = 80 },
	{ id = "sumo_legend", name = "Sumo Legend", text = "Reach Yokozuna in sumo.", check = "rank:sumo", target = 8, gems = 120 },
	{ id = "judo_expert", name = "Judo Expert", text = "Reach black belt mastery in judo.", check = "rank:judo", target = 7, gems = 80 },
	{ id = "legendary_trainer", name = "First Legendary Trainer", text = "Recruit a Legendary (or Mythic) trainer.", check = "trainer:5", target = 1, gems = 50 },
	{ id = "millionaire", name = "Millionaire Academy", text = "Earn $1,000,000 in total.", check = "stat:totalEarned", target = 1000000, gems = 60 },
	{ id = "international", name = "International Academy Owner", text = "Run academies in 3 cities.", check = "cities", target = 3, gems = 60 },
	{ id = "world_empire", name = "World Empire", text = "Unlock all 10 cities.", check = "cities", target = 10, gems = 300 },
	{ id = "challenger", name = "Challenger", text = "Complete 50 training challenges.", check = "stat:miniGames", target = 50, gems = 40 },
	{ id = "graduations_25", name = "Proud Teacher", text = "Promote 25 students to a new rank.", check = "stat:graduations", target = 25, gems = 50 },
}

---------------------------------------------------------------- students
Activities.ROSTER_MAX = 36
Activities.RETURN_CHANCE = 0.45 -- chance a visitor is a returning roster student

return Activities
