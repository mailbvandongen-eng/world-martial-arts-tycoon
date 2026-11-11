-- Player level, XP sources, rebirth, daily login rewards and the business clock.

local Progression = {}

Progression.MAX_LEVEL = 100
Progression.START_CASH = 300
Progression.START_GEMS = 50

-- XP needed to go from level L to L+1.
function Progression.xpForLevel(level)
	return math.floor(60 * level ^ 1.55 + 40)
end

Progression.xp = {
	studentServed = 2,
	classCompleted = 6,
	roomBuilt = 40,
	roomUpgraded = 25,
	trainerHired = 30,
	trainerTrained = 10,
	disciplineUnlocked = 120,
	cityUnlocked = 400,
	missionCompleted = 60,
	championship = 150,
}

-- Gems awarded on level-up (level * GEMS_PER_LEVEL, every 5th level double).
Progression.GEMS_PER_LEVEL = 3

-- Business clock: expenses and membership dues settle once per business day.
Progression.DAY_SECONDS = 120
-- Cash register: class income waits at reception until collected.
Progression.REGISTER_BASE_CAP = 2500 -- multiplied by reception level and city income
Progression.OFFLINE_MAX_HOURS = 8
Progression.OFFLINE_RATE = 0.25 -- share of the passive rate earned while offline
Progression.PASSIVE_BRANCH_RATE = 0.5 -- inactive branches earn this share of their estimate

-- Automation: a cash-bought upgrade that empties the register automatically.
Progression.automation = {
	{ level = 1, name = "Assistant Manager", cost = 15000, interval = 60, unlockLevel = 8 },
	{ level = 2, name = "Office Manager", cost = 250000, interval = 30, unlockLevel = 16 },
	{ level = 3, name = "General Manager", cost = 5000000, interval = 10, unlockLevel = 28 },
}

-- Rebirth (prestige)
Progression.rebirth = {
	minLevel = 35,
	minCities = 6,
	incomeBonusPerRebirth = 0.25,
	gemsReward = 500,
	titles = { "Rising Master", "Grand Master", "Hall of Famer", "Martial Arts Mogul", "World Icon", "Immortal" },
	resets = { "Cash", "Player level and XP", "Reputation", "Cities and all rooms", "Discipline licences", "Automation upgrades", "Membership numbers" },
	keeps = { "Gems", "All trainers (levels and XP)", "Mastery ranks", "Cosmetics and decorations", "Game passes and purchases", "Achievements and statistics" },
}

-- 7-day login cycle; the cycle restarts after day 7 or after a missed day.
Progression.daily = {
	{ day = 1, cash = 500, gems = 10 },
	{ day = 2, cash = 1500, gems = 15 },
	{ day = 3, boost = "training", minutes = 15, gems = 20 },
	{ day = 4, cash = 6000, gems = 25 },
	{ day = 5, boost = "customers", minutes = 20, gems = 30 },
	{ day = 6, cash = 20000, gems = 40 },
	{ day = 7, cosmetic = "aura_golden_dragon", gems = 100, boost = "cash", minutes = 30 },
}

-- Level milestones shown in the UI (unlocks themselves are defined in their own configs).
Progression.milestones = {
	{ level = 5, text = "Locker rooms and Amsterdam" },
	{ level = 8, text = "Automation: Assistant Manager" },
	{ level = 10, text = "Merchandise shop" },
	{ level = 20, text = "VIP training room" },
	{ level = 24, text = "Championship arena" },
	{ level = 35, text = "Rebirth available (with 6 cities)" },
	{ level = 42, text = "Las Vegas" },
}

return Progression
