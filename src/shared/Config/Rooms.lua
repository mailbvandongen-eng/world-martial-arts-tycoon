-- Buildable rooms. Discipline rooms are generated from Disciplines.lua so a new
-- discipline automatically gets a room. Kinds:
--   reception  entrance, front desk; decides how many visitors arrive
--   training   runs classes for one discipline (or general fitness)
--   coaching   private 1-on-1 coaching, any discipline (trainer decides)
--   vip        VIP and celebrity training, any discipline (trainer decides)
--   amenity    raises satisfaction of every visit
--   shop       visitors may buy drinks / merchandise after class
--   arena      hosts championships (timed events)

local Disciplines = require(script.Parent.Disciplines)

local Rooms = {}

Rooms.MAX_LEVEL = 5

local list = {
	{
		id = "reception",
		name = "Reception",
		kind = "reception",
		cost = 0,
		unlockLevel = 1,
		capacity = 6,
		capacityPerLevel = 3,
		spawnPerLevel = 0.35,
		description = "Front desk. Upgrade to welcome more visitors and shorten queues.",
		color = { 212, 175, 55 },
		icon = "★",
	},
}

for _, d in ipairs(Disciplines.list) do
	table.insert(list, {
		id = d.id .. "_room",
		name = d.name .. (d.id == "sumo" and " Arena" or d.id == "mma" and " Octagon" or (d.id == "karate" or d.id == "judo") and " Dojo" or " Room"),
		kind = "training",
		discipline = d.id,
		cost = math.max(250, math.floor(d.unlock.cost * 1.5)),
		unlockLevel = d.unlock.level,
		capacity = 4,
		capacityPerLevel = 2,
		needsTrainer = true,
		description = "Train " .. d.name .. " students. Needs a " .. d.name .. " trainer.",
		color = d.accent,
		icon = string.upper(string.sub(d.name, 1, 1)),
	})
end

local extra = {
	{ id = "fitness_room", name = "Fitness Room", kind = "training", discipline = "fitness", cost = 1200, unlockLevel = 4, capacity = 6, capacityPerLevel = 2, needsTrainer = false, basePay = 7, description = "General fitness. Attracts fitness enthusiasts, no trainer needed.", color = { 60, 180, 200 }, icon = "F" },
	{ id = "strength_room", name = "Strength Room", kind = "training", discipline = "fitness", cost = 6000, unlockLevel = 7, capacity = 5, capacityPerLevel = 2, needsTrainer = false, basePay = 11, description = "Barbells and racks. Fitness enthusiasts and athletes.", color = { 90, 90, 100 }, icon = "S" },
	{ id = "cardio_room", name = "Cardio Room", kind = "training", discipline = "fitness", cost = 15000, unlockLevel = 9, capacity = 6, capacityPerLevel = 2, needsTrainer = false, basePay = 14, description = "Treadmills, bikes and rowers.", color = { 230, 80, 120 }, icon = "C" },
	{ id = "coaching_room", name = "Personal Coaching", kind = "coaching", cost = 35000, unlockLevel = 11, capacity = 2, capacityPerLevel = 1, needsTrainer = true, payMult = 2.4, description = "Private lessons for dedicated students. Any trainer.", color = { 200, 160, 60 }, icon = "P" },
	{ id = "vip_room", name = "VIP Training Room", kind = "vip", cost = 400000, unlockLevel = 20, capacity = 3, capacityPerLevel = 1, needsTrainer = true, payMult = 4.0, description = "Luxury training for VIPs and celebrities. Any trainer.", color = { 212, 175, 55 }, icon = "V" },
	{ id = "locker_room", name = "Locker Rooms", kind = "amenity", cost = 2500, unlockLevel = 5, satisfaction = 4, description = "+satisfaction for every visitor.", color = { 120, 140, 160 }, icon = "L" },
	{ id = "showers", name = "Showers", kind = "amenity", cost = 9000, unlockLevel = 8, satisfaction = 5, description = "+satisfaction for every visitor.", color = { 80, 170, 220 }, icon = "W" },
	{ id = "recovery_room", name = "Recovery Room", kind = "amenity", cost = 60000, unlockLevel = 14, satisfaction = 7, description = "Ice baths and massage tables. Big satisfaction boost.", color = { 120, 200, 200 }, icon = "R" },
	{ id = "juice_bar", name = "Juice Bar", kind = "shop", cost = 4000, unlockLevel = 6, shopSpend = 6, shopChance = 0.45, description = "Visitors buy drinks and supplements after class.", color = { 120, 200, 60 }, icon = "J" },
	{ id = "merch_shop", name = "Merchandise Shop", kind = "shop", cost = 20000, unlockLevel = 10, shopSpend = 15, shopChance = 0.3, description = "Gloves, belts, uniforms with your academy logo.", color = { 160, 90, 200 }, icon = "M" },
	{ id = "arena", name = "Championship Arena", kind = "arena", cost = 750000, unlockLevel = 24, description = "Host championships for big prize money and reputation.", color = { 230, 50, 50 }, icon = "A" },
}
for _, r in ipairs(extra) do
	table.insert(list, r)
end

Rooms.list = list
Rooms.byId = {}
for i, r in ipairs(list) do
	r.order = i
	r.maxLevel = Rooms.MAX_LEVEL
	Rooms.byId[r.id] = r
end

-- Equipment and style for general-fitness rooms (discipline rooms take theirs from Disciplines.lua).
Rooms.generalStyle = {
	fitness_room = { floor = "rubber", floorColor = { 50, 52, 58 }, wallColor = { 220, 230, 235 }, trimColor = { 60, 180, 200 }, wallMaterial = "SmoothPlastic", equipment = { "mat_row", "dumbbells", "mirror", "kettlebells", "mat_row", "dumbbells" }, sign = "FITNESS" },
	strength_room = { floor = "rubber", floorColor = { 35, 35, 38 }, wallColor = { 80, 80, 85 }, trimColor = { 230, 200, 40 }, wallMaterial = "Concrete", equipment = { "squat_rack", "bench", "dumbbells", "squat_rack", "bench", "kettlebells" }, sign = "STRENGTH" },
	cardio_room = { floor = "rubber", floorColor = { 40, 40, 48 }, wallColor = { 235, 225, 235 }, trimColor = { 230, 80, 120 }, wallMaterial = "SmoothPlastic", equipment = { "treadmill", "bike", "rower", "treadmill", "bike", "treadmill" }, sign = "CARDIO" },
	coaching_room = { floor = "wood", floorColor = { 150, 110, 70 }, wallColor = { 60, 50, 45 }, trimColor = { 200, 160, 60 }, wallMaterial = "WoodPlanks", equipment = { "heavy_bag", "mirror", "plant", "bench" }, sign = "PERSONAL COACHING" },
	vip_room = { floor = "marble", floorColor = { 235, 230, 220 }, wallColor = { 30, 28, 26 }, trimColor = { 212, 175, 55 }, wallMaterial = "Marble", equipment = { "heavy_bag_gold", "plant", "sofa", "mirror", "plant", "chandelier" }, sign = "VIP LOUNGE" },
	locker_room = { floor = "tiles", floorColor = { 200, 205, 210 }, wallColor = { 120, 140, 160 }, trimColor = { 60, 70, 80 }, wallMaterial = "SmoothPlastic", equipment = { "lockers", "bench", "lockers", "lockers", "bench", "lockers" }, sign = "LOCKERS" },
	showers = { floor = "tiles", floorColor = { 220, 230, 235 }, wallColor = { 80, 170, 220 }, trimColor = { 240, 240, 240 }, wallMaterial = "Glass", equipment = { "shower", "shower", "shower", "bench", "shower", "shower" }, sign = "SHOWERS" },
	recovery_room = { floor = "wood", floorColor = { 200, 180, 150 }, wallColor = { 220, 240, 238 }, trimColor = { 120, 200, 200 }, wallMaterial = "SmoothPlastic", equipment = { "massage_table", "ice_bath", "plant", "massage_table", "ice_bath", "plant" }, sign = "RECOVERY" },
	juice_bar = { floor = "tiles", floorColor = { 240, 235, 220 }, wallColor = { 120, 200, 60 }, trimColor = { 250, 250, 250 }, wallMaterial = "SmoothPlastic", equipment = { "bar_counter", "stool", "fridge", "stool", "plant", "stool" }, sign = "JUICE BAR" },
	merch_shop = { floor = "wood", floorColor = { 120, 90, 60 }, wallColor = { 160, 90, 200 }, trimColor = { 250, 250, 250 }, wallMaterial = "SmoothPlastic", equipment = { "shop_shelf", "mannequin", "shop_shelf", "counter", "mannequin", "shop_shelf" }, sign = "PRO SHOP" },
	arena = { floor = "canvas", floorColor = { 240, 240, 240 }, wallColor = { 20, 20, 25 }, trimColor = { 230, 50, 50 }, wallMaterial = "Metal", equipment = { "ring", "bleachers", "bleachers", "spotlight", "spotlight", "banner" }, sign = "CHAMPIONSHIP ARENA" },
	reception = { floor = "marble", floorColor = { 225, 220, 210 }, wallColor = { 40, 38, 36 }, trimColor = { 212, 175, 55 }, wallMaterial = "SmoothPlastic", equipment = { "desk", "plant", "trophy_case", "sofa", "plant", "trophy_case" }, sign = "RECEPTION" },
}

function Rooms.style(roomId)
	local def = Rooms.byId[roomId]
	if def and def.discipline and Disciplines.byId[def.discipline] then
		return Disciplines.byId[def.discipline].room
	end
	return Rooms.generalStyle[roomId]
end

return Rooms
