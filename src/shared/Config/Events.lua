-- Seasonal events. Dates are month/day in UTC and repeat every year.
-- While an event runs, classes earn event points; points unlock the event's
-- exclusive rewards (cosmetics). One event at a time; when none is scheduled
-- the International Martial Arts Festival runs as the default.

local Events = {}

Events.list = {
	{
		id = "festival",
		name = "International Martial Arts Festival",
		default = true,
		description = "All classes earn +10% revenue.",
		bonus = { all = 1.1 },
		color = { 212, 175, 55 },
		rewards = {
			{ points = 200, cosmetic = "deco_festival_banner" },
			{ points = 800, cosmetic = "aura_festival" },
			{ points = 2000, gems = 150 },
		},
	},
	{
		id = "karateweek",
		name = "World Karate Week",
		from = { 1, 10 }, to = { 1, 24 },
		description = "Karate classes earn +50% revenue and double mastery XP.",
		bonus = { karate = 1.5 }, masteryBonus = { karate = 2 },
		color = { 200, 40, 45 },
		rewards = {
			{ points = 200, cosmetic = "outfit_karate_red" },
			{ points = 800, cosmetic = "pose_karate_bow" },
			{ points = 2000, gems = 200 },
		},
	},
	{
		id = "sumochamp",
		name = "Japanese Sumo Championship",
		from = { 3, 8 }, to = { 3, 24 },
		description = "Sumo and judo +50% revenue.",
		bonus = { sumo = 1.5, judo = 1.5 },
		color = { 160, 110, 50 },
		rewards = {
			{ points = 200, cosmetic = "deco_sumo_banner" },
			{ points = 800, cosmetic = "outfit_sumo_gold" },
			{ points = 2000, gems = 200 },
		},
	},
	{
		id = "muaythaifest",
		name = "Bangkok Muay Thai Festival",
		from = { 4, 10 }, to = { 4, 25 },
		description = "Muay Thai +60% revenue, Bangkok academies +20%.",
		bonus = { muaythai = 1.6 }, cityBonus = { bangkok = 1.2 },
		color = { 220, 40, 60 },
		rewards = {
			{ points = 200, cosmetic = "outfit_muaythai_gold" },
			{ points = 800, cosmetic = "aura_thai_fire" },
			{ points = 2000, gems = 200 },
		},
	},
	{
		id = "boxingchamp",
		name = "Boxing Championship",
		from = { 7, 1 }, to = { 7, 20 },
		description = "Boxing and kickboxing +50% revenue.",
		bonus = { boxing = 1.5, kickboxing = 1.5 },
		color = { 210, 50, 40 },
		rewards = {
			{ points = 200, cosmetic = "outfit_boxing_gold" },
			{ points = 800, cosmetic = "pose_champion_belt" },
			{ points = 2000, gems = 200 },
		},
	},
	{
		id = "globaltournament",
		name = "Global Martial Arts Tournament",
		from = { 12, 1 }, to = { 12, 31 },
		description = "Every discipline +30%, championships pay double.",
		bonus = { all = 1.3 }, arenaMult = 2,
		color = { 80, 160, 255 },
		rewards = {
			{ points = 300, cosmetic = "deco_tournament_trophy" },
			{ points = 1200, cosmetic = "aura_world_champion" },
			{ points = 3000, gems = 300 },
		},
	},
}

Events.byId = {}
for _, e in ipairs(Events.list) do
	Events.byId[e.id] = e
end

-- Event points per completed class.
Events.POINTS_PER_CLASS = 2

local function dayOfYear(month, day)
	local cum = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
	return cum[month] + day
end

-- utcDate = { month = m, day = d } (os.date("!*t") shape). Returns event, endsAtDayOfYear.
function Events.active(utcDate)
	local today = dayOfYear(utcDate.month, utcDate.day)
	for _, e in ipairs(Events.list) do
		if e.from then
			local a = dayOfYear(e.from[1], e.from[2])
			local b = dayOfYear(e.to[1], e.to[2])
			if today >= a and today <= b then
				return e
			end
		end
	end
	for _, e in ipairs(Events.list) do
		if e.default then
			return e
		end
	end
	return nil
end

return Events
