-- Cosmetics: purely visual, never affect income.
--   outfit  clothing worn over your avatar (built from parts, see Modules/AvatarCosmetics)
--   aura    particle aura around your avatar
--   pose    victory pose / emote (procedural animation, see Modules/Poses)
--   deco    academy decoration placed on your plot
--   title   text shown above your head
-- source: "gems" (price), "cash" (price), "event", "pass" (bundle game pass),
--         "daily", "rebirth" (rebirth count), "level" (player level), "default"

local Cosmetics = {}

Cosmetics.list = {
	-- Outfits. Discipline outfits are free once the discipline is unlocked and
	-- show your mastery rank: rankShirt/rankPants pick "<prefix>_r<rank>",
	-- champPants switches to the championship-belt shorts from champRank on.
	{ id = "outfit_karate_white", name = "Karate Gi", kind = "outfit", source = "default", discipline = "karate", rankShirt = "karate", pants = "karate_gi_pants", style = { top = "gi", color = { 245, 245, 240 }, belt = { 245, 245, 240 } } },
	{ id = "outfit_karate_red", name = "Kata Champion Gi", kind = "outfit", source = "event", discipline = "karate", rankShirt = "karate_red", pants = "karate_gi_pants", style = { top = "gi", color = { 245, 245, 240 }, belt = { 245, 245, 240 } } },
	{ id = "outfit_judo", name = "Judogi", kind = "outfit", source = "discipline", discipline = "judo", rankShirt = "judo", pants = "karate_gi_pants", style = { top = "gi", color = { 245, 245, 240 }, belt = { 245, 245, 240 } } },
	{ id = "outfit_tkd", name = "Taekwondo Dobok", kind = "outfit", source = "discipline", discipline = "taekwondo", rankShirt = "tkd", pants = "karate_gi_pants", style = { top = "dobok", color = { 245, 245, 240 }, belt = { 245, 245, 240 } } },
	{ id = "outfit_bjj", name = "BJJ Gi", kind = "outfit", source = "discipline", discipline = "bjj", rankShirt = "bjj", pants = "karate_gi_pants", style = { top = "gi", color = { 245, 245, 240 }, belt = { 245, 245, 240 }, patches = true } },
	{ id = "outfit_bjj_black", name = "Black BJJ Gi", kind = "outfit", source = "pass", pass = "bundle_grappler", discipline = "bjj", rankShirt = "bjj_black", pants = "kungfu_pants", style = { top = "gi", color = { 25, 25, 28 }, belt = { 245, 245, 240 }, patches = true } },
	{ id = "outfit_kungfu_black", name = "Kung Fu Uniform", kind = "outfit", source = "discipline", discipline = "kungfu", rankShirt = "kungfu", pants = "kungfu_pants", style = { top = "kungfu", color = { 25, 25, 28 }, trim = { 240, 240, 240 } } },
	{ id = "outfit_kungfu", name = "Silk Kung Fu Suit", kind = "outfit", source = "pass", pass = "bundle_traditional", shirt = "kungfu_shirt", pants = "kungfu_pants", style = { top = "kungfu", color = { 180, 30, 30 }, trim = { 212, 175, 55 } } },
	{ id = "outfit_muaythai_red", name = "Muay Thai Kit", kind = "outfit", source = "discipline", discipline = "muaythai", rankShirt = "muaythai", pants = "muaythai_shorts_red", style = { top = "none", shorts = { 220, 40, 60 }, armbands = true } },
	{ id = "outfit_muaythai_gold", name = "Golden Muay Thai Kit", kind = "outfit", source = "event", discipline = "muaythai", rankShirt = "muaythai", pants = "muaythai_shorts_gold", style = { top = "none", shorts = { 212, 175, 55 }, armbands = true } },
	{ id = "outfit_sumo", name = "Mawashi", kind = "outfit", source = "discipline", discipline = "sumo", rankPants = "sumo", style = { top = "none", mawashi = { 40, 50, 80 } } },
	{ id = "outfit_sumo_gold", name = "Golden Mawashi", kind = "outfit", source = "event", pants = "mawashi_gold", style = { top = "none", mawashi = { 212, 175, 55 } } },
	{ id = "outfit_boxing_red", name = "Boxing Kit", kind = "outfit", source = "discipline", discipline = "boxing", champPants = "boxing_shorts_red", champRank = 6, style = { top = "none", shorts = { 190, 30, 35 }, gloves = { 190, 30, 35 } } },
	{ id = "outfit_boxing_gold", name = "Golden Boxing Kit", kind = "outfit", source = "event", pants = "boxing_shorts_gold", style = { top = "none", shorts = { 212, 175, 55 }, gloves = { 212, 175, 55 } } },
	{ id = "outfit_kickboxing", name = "Kickboxing Kit", kind = "outfit", source = "discipline", discipline = "kickboxing", champPants = "kickboxing_shorts", champRank = 5, style = { top = "none", shorts = { 25, 25, 28 } } },
	{ id = "outfit_mma", name = "MMA Fight Gear", kind = "outfit", source = "pass", pass = "bundle_striker", discipline = "mma", shirt = "mma_rashguard", champPants = "mma_shorts", champRank = 5, style = { top = "rashguard", color = { 25, 25, 28 }, shorts = { 230, 30, 30 }, gloves = { 25, 25, 28 } } },
	{ id = "outfit_owner_gold", name = "Premium Owner Suit", kind = "outfit", source = "pass", pass = "vip_owner", shirt = "owner_suit_shirt", pants = "owner_suit_pants", style = { top = "suit", color = { 30, 28, 26 }, trim = { 212, 175, 55 } } },
	-- Auras
	{ id = "aura_golden_dragon", name = "Golden Dragon Aura", kind = "aura", source = "daily", style = { color = { 255, 200, 60 }, rate = 14 } },
	{ id = "aura_festival", name = "Festival Aura", kind = "aura", source = "event", style = { color = { 255, 120, 200 }, rate = 12 } },
	{ id = "aura_thai_fire", name = "Thai Fire Aura", kind = "aura", source = "event", style = { color = { 255, 90, 30 }, rate = 18 } },
	{ id = "aura_world_champion", name = "World Champion Aura", kind = "aura", source = "event", style = { color = { 80, 160, 255 }, rate = 16 } },
	{ id = "aura_legendary", name = "Legendary Aura", kind = "aura", source = "pass", pass = "elite_owner", style = { color = { 255, 170, 30 }, rate = 20 } },
	{ id = "aura_rebirth", name = "Prestige Aura", kind = "aura", source = "rebirth", rebirths = 1, style = { color = { 200, 120, 255 }, rate = 14 } },
	{ id = "aura_spirit", name = "Spirit Aura", kind = "aura", source = "gems", price = 600, style = { color = { 150, 255, 220 }, rate = 10 } },
	-- Poses / emotes
	{ id = "pose_bow", name = "Respectful Bow", kind = "pose", source = "default", animation = "emote_bow" },
	{ id = "pose_karate_bow", name = "Kata Salute", kind = "pose", source = "event", animation = "emote_kata_salute" },
	{ id = "pose_champion_belt", name = "Champion Belt Raise", kind = "pose", source = "event", animation = "emote_champion" },
	{ id = "pose_flex", name = "Victory Flex", kind = "pose", source = "gems", price = 150, animation = "emote_flex" },
	{ id = "pose_crane", name = "Crane Stance", kind = "pose", source = "pass", pass = "bundle_traditional", animation = "kungfu_crane" },
	{ id = "pose_shiko", name = "Sumo Stomp", kind = "pose", source = "level", level = 30, animation = "sumo_shiko" },
	-- Decorations (placed in the plot's decoration spots)
	{ id = "deco_statue", name = "Founder Statue", kind = "deco", source = "cash", price = 50000, model = "statue" },
	{ id = "deco_fountain", name = "Zen Fountain", kind = "deco", source = "gems", price = 300, model = "fountain" },
	{ id = "deco_trophy", name = "Giant Trophy", kind = "deco", source = "level", level = 15, model = "trophy" },
	{ id = "deco_festival_banner", name = "Festival Banners", kind = "deco", source = "event", model = "banners" },
	{ id = "deco_sumo_banner", name = "Nobori Flags", kind = "deco", source = "event", model = "nobori" },
	{ id = "deco_tournament_trophy", name = "Tournament Trophy", kind = "deco", source = "event", model = "trophy_world" },
	{ id = "deco_golden_gate", name = "Golden Gate", kind = "deco", source = "pass", pass = "vip_owner", model = "golden_gate" },
	{ id = "deco_neon", name = "Neon Signage", kind = "deco", source = "pass", pass = "elite_owner", model = "neon" },
	{ id = "deco_prestige_pillar", name = "Prestige Pillars", kind = "deco", source = "rebirth", rebirths = 2, model = "pillars" },
	{ id = "deco_sakura", name = "Sakura Garden", kind = "deco", source = "pass", pass = "bundle_traditional", model = "sakura_garden" },
	-- Titles
	{ id = "title_owner", name = "Academy Owner", kind = "title", source = "default", text = "Academy Owner" },
	{ id = "title_vip", name = "VIP Owner", kind = "title", source = "pass", pass = "vip_owner", text = "★ VIP OWNER ★" },
	{ id = "title_elite", name = "Elite Owner", kind = "title", source = "pass", pass = "elite_owner", text = "ELITE OWNER" },
	{ id = "title_mogul", name = "Mogul", kind = "title", source = "level", level = 50, text = "Martial Arts Mogul" },
}

Cosmetics.byId = {}
for i, c in ipairs(Cosmetics.list) do
	c.order = i
	Cosmetics.byId[c.id] = c
end

Cosmetics.kinds = { "outfit", "aura", "pose", "deco", "title" }

return Cosmetics
