-- Daily and weekly missions. Each mission counts one stat ("track"); the
-- target is scaled by the player's level where `scale` is set.
-- Tracks are incremented by the server in QuestService.track(player, track, amount).

local Quests = {}

Quests.DAILY_COUNT = 3
Quests.WEEKLY_COUNT = 3

Quests.daily = {
	{ id = "d_serve", text = "Serve %d students", track = "studentsServed", target = 25, scale = 0.5, reward = { cash = 1, gems = 10 } },
	{ id = "d_classes", text = "Complete %d classes", track = "classesCompleted", target = 10, scale = 0.2, reward = { cash = 1, gems = 10 } },
	{ id = "d_upgrade", text = "Upgrade %d rooms", track = "roomsUpgraded", target = 3, reward = { cash = 1.5, gems = 12 } },
	{ id = "d_recruit", text = "Recruit a trainer", track = "trainersHired", target = 1, reward = { cash = 1, gems = 15 } },
	{ id = "d_earn", text = "Earn %s", track = "cashEarned", target = 2000, scaleMoney = true, reward = { cash = 0.5, gems = 10 } },
	{ id = "d_collect", text = "Collect the register %d times", track = "registerCollected", target = 8, reward = { cash = 0.8, gems = 8 } },
	{ id = "d_happy", text = "Get %d very happy students (90+)", track = "happyStudents", target = 10, scale = 0.2, reward = { cash = 1.2, gems = 12 } },
	{ id = "d_mastery", text = "Earn %d mastery XP", track = "masteryXp", target = 150, scale = 3, reward = { cash = 1, gems = 10 } },
}

Quests.weekly = {
	{ id = "w_rep", text = "Gain %d reputation", track = "reputationGained", target = 400, scale = 40, reward = { cash = 6, gems = 60 } },
	{ id = "w_programmes", text = "Complete %d classes", track = "classesCompleted", target = 150, scale = 3, reward = { cash = 6, gems = 60 } },
	{ id = "w_rare", text = "Recruit %d Rare+ trainers", track = "rareTrainers", target = 2, reward = { cash = 5, gems = 80 } },
	{ id = "w_satisfaction", text = "Get %d very happy students (90+)", track = "happyStudents", target = 120, scale = 2, reward = { cash = 6, gems = 60 } },
	{ id = "w_visit", text = "Visit %d other academies", track = "academiesVisited", target = 3, reward = { cash = 3, gems = 50 } },
	{ id = "w_build", text = "Build or upgrade %d rooms", track = "roomsTouched", target = 10, reward = { cash = 5, gems = 60 } },
	{ id = "w_rate", text = "Rate %d academies", track = "academiesRated", target = 3, reward = { cash = 3, gems = 40 } },
}

-- Rewards: cash values are multiplied by Formulas.rewardCashUnit(level),
-- so missions stay meaningful at every stage of the game.

Quests.byId = {}
for _, q in ipairs(Quests.daily) do
	q.period = "daily"
	Quests.byId[q.id] = q
end
for _, q in ipairs(Quests.weekly) do
	q.period = "weekly"
	Quests.byId[q.id] = q
end

-- The always-visible "next objective" guide. First unmet step is shown.
Quests.objectives = {
	{ id = "claim", text = "Claim an academy plot", check = "hasPlot" },
	{ id = "collect", text = "Collect cash at the reception register", check = "collectedOnce" },
	{ id = "boxing", text = "Unlock Boxing in the Academy menu", check = "discipline:boxing" },
	{ id = "boxroom", text = "Build a Boxing Room", check = "room:boxing_room" },
	{ id = "hire", text = "Recruit a Boxing trainer and assign them", check = "assigned:boxing" },
	{ id = "upgrade", text = "Upgrade a room to level 2", check = "roomLevel:2" },
	{ id = "judo", text = "Unlock Judo and build a Judo Dojo", check = "room:judo_room" },
	{ id = "locker", text = "Build Locker Rooms for happier students", check = "room:locker_room" },
	{ id = "amsterdam", text = "Open your second academy in Amsterdam", check = "city:amsterdam" },
	{ id = "level10", text = "Reach player level 10", check = "level:10" },
	{ id = "rotterdam", text = "Expand to Rotterdam", check = "city:rotterdam" },
	{ id = "tokyo", text = "Expand to Tokyo", check = "city:tokyo" },
	{ id = "vip", text = "Build a VIP Training Room", check = "room:vip_room" },
	{ id = "vegas", text = "Conquer Las Vegas", check = "city:lasvegas" },
	{ id = "rebirth", text = "Rebirth for a permanent income bonus", check = "rebirths:1" },
}

return Quests
