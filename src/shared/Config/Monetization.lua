-- Robux products. IMPORTANT: replace every `id = 0` with the real Game Pass /
-- Developer Product id from the Creator Dashboard (see docs/MONETIZATION.md).
-- Products with id 0 are shown in the store as "Not configured" and cannot be bought.
-- `robux` is only a display fallback; the store shows the live price from Roblox.

local Monetization = {}

Monetization.gamePasses = {
	-- Core passes
	{ key = "vip_owner", id = 0, robux = 399, category = "passes", name = "VIP Owner", description = "VIP title, golden owner suit, golden gate decoration and VIP chat tag.", grants = { cosmetics = { "title_vip", "outfit_owner_gold", "deco_golden_gate" } } },
	{ key = "double_cash", id = 0, robux = 499, category = "passes", name = "Double Cash", description = "All class, shop and membership income x2 (stacks with boosts).", effect = { cashMult = 2 } },
	{ key = "extra_slot", id = 0, robux = 249, category = "passes", name = "Extra Academy Slots", description = "+4 room slots in every city.", effect = { extraSlots = 4 } },
	{ key = "auto_collect", id = 0, robux = 199, category = "passes", name = "Auto Collect", description = "Your register empties into your balance automatically every 5 seconds.", effect = { autoCollect = 5 } },
	{ key = "premium_trainer", id = 0, robux = 349, category = "passes", name = "Premium Trainer", description = "Exclusive Mythic trainer: Grandmaster Kaito Arashi (Karate, Living Legend).", grants = { trainers = { "m_premium" } } },
	{ key = "elite_owner", id = 0, robux = 799, category = "passes", name = "Elite Owner", description = "Elite title, legendary aura and neon academy signage. Cosmetic only.", grants = { cosmetics = { "title_elite", "aura_legendary", "deco_neon" } } },
	-- Premium equipment (small, capped bonuses + unique visuals)
	{ key = "golden_ring", id = 0, robux = 299, category = "equipment", name = "Golden Boxing Ring", description = "Gold ring in all boxing rooms. +10% boxing revenue.", effect = { discipline = "boxing", revenue = 0.10, finish = "gold" } },
	{ key = "diamond_octagon", id = 0, robux = 299, category = "equipment", name = "Diamond MMA Octagon", description = "Diamond octagon in all MMA rooms. +10% MMA revenue.", effect = { discipline = "mma", revenue = 0.10, finish = "diamond" } },
	{ key = "premium_dojo", id = 0, robux = 249, category = "equipment", name = "Premium Karate Dojo", description = "Lacquered wood and gold kamiza in karate dojos. +10% karate revenue.", effect = { discipline = "karate", revenue = 0.10, finish = "premium" } },
	{ key = "luxury_sumo", id = 0, robux = 299, category = "equipment", name = "Luxury Sumo Arena", description = "Hanging roof (tsuriyane) over every dohyo. +10% sumo revenue.", effect = { discipline = "sumo", revenue = 0.10, finish = "luxury" } },
	{ key = "platinum_judo", id = 0, robux = 249, category = "equipment", name = "Platinum Judo Mats", description = "Platinum tatami in judo dojos. +10% judo revenue.", effect = { discipline = "judo", revenue = 0.10, finish = "platinum" } },
	{ key = "carbon_equipment", id = 0, robux = 399, category = "equipment", name = "Carbon Fibre Equipment", description = "Carbon bags and racks everywhere. +5% satisfaction.", effect = { satisfaction = 5, finish = "carbon" } },
	{ key = "gym_lighting", id = 0, robux = 149, category = "equipment", name = "Exclusive Gym Lighting", description = "Colour-changing spotlights in every room. Cosmetic.", effect = { lighting = true } },
	{ key = "premium_decor", id = 0, robux = 199, category = "equipment", name = "Premium Academy Decorations", description = "Marble statues and plants around your academy. +3 satisfaction.", effect = { satisfaction = 3, decor = true } },
	-- Cosmetic bundles
	{ key = "bundle_starter", id = 0, robux = 99, category = "bundles", name = "Starter Bundle", description = "One-time: 25,000 cash, 300 gems and a free Rare trainer of your first discipline.", grants = { cash = 25000, gems = 300, rareTrainer = true }, featured = true },
	{ key = "bundle_striker", id = 0, robux = 199, category = "bundles", name = "Striker Cosmetic Bundle", description = "MMA fight gear outfit. Cosmetic only.", grants = { cosmetics = { "outfit_mma" } } },
	{ key = "bundle_grappler", id = 0, robux = 199, category = "bundles", name = "Grappler Cosmetic Bundle", description = "BJJ gi with black belt and patches. Cosmetic only.", grants = { cosmetics = { "outfit_bjj_black" } } },
	{ key = "bundle_traditional", id = 0, robux = 249, category = "bundles", name = "Traditional Masters Bundle", description = "Silk Kung Fu suit, Crane pose and a Sakura garden decoration.", grants = { cosmetics = { "outfit_kungfu", "pose_crane", "deco_sakura" } }, seasonal = { from = { 3, 1 }, to = { 5, 31 }, label = "Spring collection" } },
}

Monetization.products = {
	{ key = "cash_small", id = 0, robux = 49, category = "cash", name = "Small Cash Pack", description = "10 minutes of your current income (min 5,000).", cashMinutes = 10, cashMin = 5000 },
	{ key = "cash_medium", id = 0, robux = 149, category = "cash", name = "Medium Cash Pack", description = "40 minutes of your current income (min 25,000).", cashMinutes = 40, cashMin = 25000 },
	{ key = "cash_large", id = 0, robux = 399, category = "cash", name = "Large Cash Pack", description = "2 hours of your current income (min 100,000).", cashMinutes = 120, cashMin = 100000 },
	{ key = "boost_cash", id = 0, robux = 79, category = "boosts", name = "Double Cash (30 min)", description = "x2 income for 30 minutes. Time stacks.", boost = "cash", minutes = 30 },
	{ key = "boost_training", id = 0, robux = 59, category = "boosts", name = "Training Boost (30 min)", description = "Classes run 50% faster and give double mastery XP.", boost = "training", minutes = 30 },
	{ key = "boost_customers", id = 0, robux = 59, category = "boosts", name = "Customer Rush (30 min)", description = "+75% visitors for 30 minutes.", boost = "customers", minutes = 30 },
	{ key = "instant_build", id = 0, robux = 25, category = "boosts", name = "Instant Construction", description = "Finishes every room that is under construction right now.", instantBuild = true },
}

Monetization.passByKey = {}
for _, p in ipairs(Monetization.gamePasses) do
	Monetization.passByKey[p.key] = p
end
Monetization.productByKey = {}
for _, p in ipairs(Monetization.products) do
	Monetization.productByKey[p.key] = p
end

-- Store tabs in display order.
Monetization.categories = {
	{ id = "featured", name = "Featured" },
	{ id = "passes", name = "Game Passes" },
	{ id = "boosts", name = "Boosts" },
	{ id = "cash", name = "Cash" },
	{ id = "equipment", name = "Premium Equipment" },
	{ id = "bundles", name = "Bundles" },
	{ id = "cosmetics", name = "Cosmetics" },
}

-- Boost effects
Monetization.boosts = {
	cash = { name = "Double Cash", cashMult = 2 },
	training = { name = "Training Boost", speedMult = 1.5, masteryMult = 2 },
	customers = { name = "Customer Rush", spawnMult = 1.75 },
}

return Monetization
