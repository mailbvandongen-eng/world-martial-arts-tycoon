-- Trainer collection. Trainers are generated from a template (discipline + rarity)
-- or are one of the named masters. Stats:
--   speed         class duration multiplier (higher = shorter classes)
--   capacity      extra students per class
--   satisfaction  satisfaction points added to every class
--   salary        cash per business day

local Trainers = {}

Trainers.rarities = {
	{ id = "common", name = "Common", order = 1, odds = 60, color = { 180, 180, 180 }, speed = 1.0, capacity = 0, satisfaction = 2, salary = 8, gemPrice = 40, maxLevel = 10 },
	{ id = "uncommon", name = "Uncommon", order = 2, odds = 25, color = { 80, 200, 90 }, speed = 1.06, capacity = 1, satisfaction = 5, salary = 20, gemPrice = 90, maxLevel = 15 },
	{ id = "rare", name = "Rare", order = 3, odds = 10, color = { 60, 140, 255 }, speed = 1.12, capacity = 1, satisfaction = 8, salary = 45, gemPrice = 200, maxLevel = 20 },
	{ id = "epic", name = "Epic", order = 4, odds = 4, color = { 170, 70, 230 }, speed = 1.2, capacity = 2, satisfaction = 12, salary = 100, gemPrice = 450, maxLevel = 25 },
	{ id = "legendary", name = "Legendary", order = 5, odds = 0.9, color = { 255, 170, 30 }, speed = 1.3, capacity = 3, satisfaction = 16, salary = 220, gemPrice = 1200, maxLevel = 30 },
	{ id = "mythic", name = "Mythic", order = 6, odds = 0.1, color = { 255, 60, 90 }, speed = 1.45, capacity = 4, satisfaction = 22, salary = 400, gemPrice = nil, maxLevel = 40 },
}
Trainers.rarityById = {}
for _, r in ipairs(Trainers.rarities) do
	Trainers.rarityById[r.id] = r
end

-- Specialisations give a small flavour bonus to one class tier range.
Trainers.specializations = {
	{ id = "fundamentals", name = "Fundamentals", tiers = { 1, 2 }, bonus = 0.12 },
	{ id = "technique", name = "Technique", tiers = { 2, 3 }, bonus = 0.12 },
	{ id = "competition", name = "Competition", tiers = { 4, 5 }, bonus = 0.15 },
	{ id = "conditioning", name = "Conditioning", tiers = { 1, 3 }, bonus = 0.08, speedBonus = 0.05 },
	{ id = "kids", name = "Youth Coaching", tiers = { 1, 1 }, bonus = 0.2 },
}
Trainers.specById = {}
for _, s in ipairs(Trainers.specializations) do
	Trainers.specById[s.id] = s
end

-- Abilities. Rarer trainers roll from the stronger part of this list.
Trainers.abilities = {
	{ id = "motivator", name = "Motivator", minRarity = 2, text = "+6 satisfaction in their room", satisfaction = 6 },
	{ id = "efficient", name = "Efficient", minRarity = 2, text = "Classes 8% faster", speed = 0.08 },
	{ id = "crowd", name = "Crowd Puller", minRarity = 3, text = "+10% visitors for this discipline", demand = 0.1 },
	{ id = "bigclass", name = "Big Classes", minRarity = 3, text = "+2 class capacity", capacity = 2 },
	{ id = "famous", name = "Famous Name", minRarity = 4, text = "+15% class revenue", revenue = 0.15 },
	{ id = "sensei", name = "Master Teacher", minRarity = 4, text = "+40% mastery XP", mastery = 0.4 },
	{ id = "champion", name = "Champion Aura", minRarity = 5, text = "+25% revenue, +8 satisfaction", revenue = 0.25, satisfaction = 8 },
	{ id = "legend", name = "Living Legend", minRarity = 6, text = "+40% revenue, +3 capacity, +50% mastery XP", revenue = 0.4, capacity = 3, mastery = 0.5 },
}
Trainers.abilityById = {}
for _, a in ipairs(Trainers.abilities) do
	Trainers.abilityById[a.id] = a
end

-- Fictional name pools per culture.
Trainers.names = {
	japan = { first = { "Kenji", "Haruto", "Yuki", "Aiko", "Takeshi", "Sora", "Rin", "Daichi", "Mei", "Hiroshi", "Emi", "Ren" }, last = { "Tanaka", "Mori", "Sato", "Kobayashi", "Ishida", "Nakamura", "Okada", "Fujita", "Hayashi", "Ono" } },
	england = { first = { "Jack", "Ella", "Callum", "Grace", "Liam", "Maya", "Owen", "Isla", "Danny", "Rosie" }, last = { "Barrow", "Hughes", "Whitlock", "Carter", "Doyle", "Finch", "Marsh", "Kelly" } },
	thailand = { first = { "Somchai", "Anan", "Kiet", "Malee", "Niran", "Ploy", "Chai", "Lamai", "Sakda", "Dao" }, last = { "Sor Kiat", "Kaewsai", "Petchmuang", "Sitthong", "Banchamek", "Rattana" } },
	korea = { first = { "Min-jun", "Seo-yeon", "Ji-ho", "Ha-eun", "Do-yun", "Ye-jin", "Hyun", "Soo-ah" }, last = { "Kim", "Park", "Choi", "Jung", "Kang", "Yoon", "Han" } },
	brazil = { first = { "Rafael", "Luana", "Thiago", "Bianca", "Diego", "Camila", "Bruno", "Marina" }, last = { "Souza", "Ferreira", "Almeida", "Costa", "Ribeiro", "Barbosa" } },
	usa = { first = { "Tyler", "Jordan", "Ashley", "Marcus", "Brooke", "Devon", "Casey", "Logan", "Tasha" }, last = { "Reed", "Jackson", "Brooks", "Hayes", "Coleman", "Price", "Wallace" } },
	netherlands = { first = { "Daan", "Sanne", "Bram", "Femke", "Sem", "Lotte", "Ruben", "Noor" }, last = { "de Vries", "Bakker", "Visser", "Smit", "Mulder", "de Boer", "Jansen" } },
	china = { first = { "Wei", "Mei", "Jun", "Ling", "Hao", "Xiu", "Bo", "Yan" }, last = { "Chen", "Wong", "Li", "Zhang", "Liu", "Huang", "Lam" } },
	israel = { first = { "Noam", "Tamar", "Eitan", "Yael", "Omer", "Shira", "Ari", "Maya" }, last = { "Levi", "Cohen", "Mizrahi", "Peretz", "Ben-David", "Katz" } },
}
Trainers.cultureByOrigin = {
	Japan = "japan", England = "england", Thailand = "thailand", Korea = "korea", Brazil = "brazil",
	USA = "usa", Netherlands = "netherlands", China = "china", Israel = "israel",
}

-- Named legendary/mythic masters (fictional). Fixed stats and ability.
Trainers.masters = {
	{ id = "m_karate", name = "Master Takeshi Ishida", title = "Legendary Karate Master", discipline = "karate", rarity = "legendary", ability = "champion", spec = "technique" },
	{ id = "m_boxing", name = "Coach Danny Barrow", title = "Legendary Boxing Coach", discipline = "boxing", rarity = "legendary", ability = "bigclass", spec = "competition" },
	{ id = "m_sumo", name = "Oyakata Hiroshi Okada", title = "Legendary Sumo Master", discipline = "sumo", rarity = "legendary", ability = "champion", spec = "conditioning" },
	{ id = "m_muaythai", name = "Kru Somchai Sor Kiat", title = "Legendary Muay Thai Kru", discipline = "muaythai", rarity = "legendary", ability = "famous", spec = "competition" },
	{ id = "m_judo", name = "Sensei Emi Hayashi", title = "Legendary Judo Sensei", discipline = "judo", rarity = "legendary", ability = "sensei", spec = "technique" },
	{ id = "m_bjj", name = "Professor Rafael Souza", title = "Legendary BJJ Professor", discipline = "bjj", rarity = "legendary", ability = "champion", spec = "competition" },
	{ id = "m_tkd", name = "Sabumnim Ji-ho Park", title = "Legendary Taekwondo Master", discipline = "taekwondo", rarity = "legendary", ability = "crowd", spec = "kids" },
	{ id = "m_kickboxing", name = "Coach Bram Visser", title = "Legendary Kickboxing Coach", discipline = "kickboxing", rarity = "legendary", ability = "famous", spec = "competition" },
	{ id = "m_kungfu", name = "Sifu Wei Lam", title = "Legendary Kung Fu Sifu", discipline = "kungfu", rarity = "legendary", ability = "sensei", spec = "technique" },
	{ id = "m_wrestling", name = "Coach Marcus Coleman", title = "Legendary Wrestling Coach", discipline = "wrestling", rarity = "legendary", ability = "bigclass", spec = "conditioning" },
	{ id = "m_krav", name = "Instructor Tamar Katz", title = "Legendary Krav Maga Instructor", discipline = "kravmaga", rarity = "legendary", ability = "famous", spec = "fundamentals" },
	{ id = "m_mma", name = "Coach Jordan Reed", title = "Legendary MMA Coach", discipline = "mma", rarity = "legendary", ability = "champion", spec = "competition" },
	-- Granted by the Premium Trainer game pass. Not obtainable at random.
	{ id = "m_premium", name = "Grandmaster Kaito Arashi", title = "Mythic Grandmaster", discipline = "karate", rarity = "mythic", ability = "legend", spec = "competition", premium = true },
}
Trainers.masterById = {}
for _, m in ipairs(Trainers.masters) do
	Trainers.masterById[m.id] = m
end

-- Recruiting
Trainers.ROSTER_LIMIT = 40
Trainers.SCOUT_BASE_COST = 400 -- grows with player level, see Formulas.scoutCost
Trainers.MARKET_SIZE = 3 -- daily gem market offers (fixed price, no randomness at purchase)
Trainers.LEGENDARY_MASTER_SHARE = 0.5 -- share of legendary scouting results that are a named master
Trainers.XP_PER_CLASS = 10
Trainers.TRAIN_COST_BASE = 300 -- cash cost of a training upgrade, scaled by level and rarity

return Trainers
