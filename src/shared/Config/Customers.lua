-- Visitor categories. weight = base spawn weight, spend = payment multiplier,
-- expectation = satisfaction they need to be happy, minRep = academy reputation
-- needed before they show up, patience = seconds they queue before leaving.

local Customers = {}

Customers.list = {
	{ id = "beginner", name = "Beginner", weight = 40, spend = 1.0, expectation = 40, minRep = 0, patience = 30, minTier = 1, maxTier = 2, color = { 200, 200, 200 } },
	{ id = "casual", name = "Casual Member", weight = 30, spend = 1.2, expectation = 50, minRep = 0, patience = 26, minTier = 1, maxTier = 3, color = { 150, 200, 255 } },
	{ id = "fitness", name = "Fitness Enthusiast", weight = 20, spend = 1.15, expectation = 45, minRep = 0, patience = 26, minTier = 1, maxTier = 3, fitnessBias = 0.6, color = { 60, 200, 200 } },
	{ id = "dedicated", name = "Dedicated Martial Artist", weight = 14, spend = 1.6, expectation = 60, minRep = 100, patience = 34, minTier = 2, maxTier = 4, color = { 100, 220, 120 } },
	{ id = "advanced", name = "Advanced Student", weight = 8, spend = 2.2, expectation = 68, minRep = 500, patience = 34, minTier = 3, maxTier = 5, color = { 120, 140, 255 } },
	{ id = "professional", name = "Professional Athlete", weight = 4, spend = 3.5, expectation = 76, minRep = 2000, patience = 30, minTier = 4, maxTier = 5, prefers = "coaching", color = { 255, 140, 60 } },
	{ id = "vip", name = "VIP Customer", weight = 2, spend = 6, expectation = 84, minRep = 8000, patience = 24, minTier = 3, maxTier = 5, prefers = "vip", vip = true, color = { 212, 175, 55 } },
	{ id = "celebrity", name = "Celebrity", weight = 0.5, spend = 12, expectation = 90, minRep = 30000, patience = 20, minTier = 3, maxTier = 5, prefers = "vip", vip = true, celebrity = true, color = { 255, 90, 200 } },
}

Customers.byId = {}
for i, c in ipairs(Customers.list) do
	c.order = i
	Customers.byId[c.id] = c
end

-- Membership: a satisfied visitor (satisfaction >= threshold) may sign up.
Customers.MEMBER_THRESHOLD = 70
Customers.MEMBER_CHANCE = 0.35
-- Each member pays dues every business day while total capacity allows it.
Customers.MEMBER_DUES = 3
Customers.MEMBERS_PER_CAPACITY = 6

-- Celebrity names are fictional.
Customers.celebrityNames = {
	"Rex Thunder", "Mila Starling", "DJ Kova", "Ava Lumen", "Jet Morales", "Nova Quinn", "Kai Brightwater", "Luna Vega",
}

return Customers
