-- Modular NPC appearance. describe() turns (seed, discipline, role, rank,
-- category) into a full description: body type, proportions, skin tone, face,
-- hair and discipline-specific clothing and gear. Pure Lua: Rig.lua builds the
-- 3D model from this description. The same seed always gives the same person.

local Config = script.Parent.Parent.Config
local Disciplines = require(Config.Disciplines)
local Customers = require(Config.Customers)
local Trainers = require(Config.Trainers)
local RNG = require(script.Parent.RNG)
local Util = require(script.Parent.Util)

local Appearance = {}

Appearance.SKIN = {
	{ 255, 224, 196 }, { 241, 194, 160 }, { 224, 172, 125 }, { 198, 145, 100 }, { 170, 120, 80 },
	{ 141, 94, 60 }, { 110, 72, 45 }, { 86, 56, 36 }, { 250, 210, 175 }, { 210, 160, 115 },
}
Appearance.HAIR_COLORS = {
	{ 20, 18, 16 }, { 45, 30, 20 }, { 80, 50, 30 }, { 120, 80, 40 }, { 190, 150, 90 }, { 230, 200, 140 },
	{ 150, 60, 30 }, { 160, 160, 165 }, { 230, 230, 230 },
}
Appearance.HAIR_STYLES = { "short", "buzz", "ponytail", "bun", "long", "bald", "mohawk", "afro", "side", "curly" }
Appearance.BRIGHT = {
	{ 220, 40, 60 }, { 30, 90, 200 }, { 230, 180, 30 }, { 40, 160, 80 }, { 140, 50, 170 }, { 240, 120, 30 }, { 20, 20, 25 }, { 240, 240, 240 },
}
Appearance.TEAM = { { 150, 30, 40 }, { 30, 60, 150 }, { 30, 30, 35 }, { 40, 120, 60 }, { 200, 150, 30 } }
Appearance.DARK = { { 25, 25, 28 }, { 50, 55, 60 }, { 40, 50, 40 }, { 60, 40, 40 }, { 30, 35, 55 } }

-- Body proportions. w = width, d = depth, limb = arm/leg thickness, h = height scale.
Appearance.BODY = {
	average = { w = 1.0, d = 1.0, limb = 1.0, h = 1.0, shoulders = 1.0, belly = 0 },
	slim = { w = 0.88, d = 0.88, limb = 0.86, h = 1.02, shoulders = 0.95, belly = 0 },
	athletic = { w = 1.08, d = 1.0, limb = 1.12, h = 1.03, shoulders = 1.18, belly = 0 },
	heavy = { w = 1.3, d = 1.35, limb = 1.22, h = 1.0, shoulders = 1.1, belly = 0.35 },
	sumo = { w = 1.75, d = 1.95, limb = 1.5, h = 1.06, shoulders = 1.25, belly = 1 },
	kid = { w = 0.9, d = 0.9, limb = 0.85, h = 0.72, shoulders = 0.95, belly = 0, head = 1.18 },
}

local function pickBody(rng, weights)
	return Util.weightedKey(weights, rng:next()) or "average"
end

local function resolveColor(rng, value, fallback)
	if type(value) == "table" then
		return value
	end
	if value == "random" or value == "bright" then
		return rng:pick(Appearance.BRIGHT)
	elseif value == "team" then
		return rng:pick(Appearance.TEAM)
	elseif value == "dark" then
		return rng:pick(Appearance.DARK)
	elseif value == "judogi" then
		return rng:chance(0.3) and { 30, 70, 170 } or { 245, 245, 240 }
	elseif value == "bjjgi" then
		local r = rng:next()
		if r < 0.55 then
			return { 245, 245, 240 }
		elseif r < 0.85 then
			return { 30, 60, 150 }
		end
		return { 25, 25, 28 }
	elseif value == "mawashi" then
		return rng:pick({ { 40, 45, 70 }, { 30, 30, 35 }, { 90, 60, 40 }, { 60, 30, 80 } })
	end
	return fallback or { 200, 200, 200 }
end

-- Parts of the rig: Hips, Chest, Head, LUpperArm, LLowerArm, LHand, RUpperArm,
-- RLowerArm, RHand, LUpperLeg, LLowerLeg, LFoot, RUpperLeg, RLowerLeg, RFoot
local function paint(colors, names, color)
	for _, n in ipairs(names) do
		colors[n] = color
	end
end

-- Describe a person.
-- opts: { seed, discipline ("fitness" allowed), role = "student"|"trainer"|"staff",
--         rank = rank index, category = customer category id, rarity, master }
function Appearance.describe(opts)
	local rng = RNG.new(opts.seed or 1)
	local disc = Disciplines.byId[opts.discipline]
	local role = opts.role or "student"
	local outfit
	if disc then
		outfit = role == "trainer" and disc.outfit.trainer or disc.outfit.student
	elseif role == "staff" then
		outfit = { top = "suit", topColor = { 30, 30, 34 }, trim = { 212, 175, 55 }, bottom = "pants", bottomColor = { 30, 30, 34 }, feet = "shoes" }
	else
		outfit = { top = rng:chance(0.5) and "tank" or "tshirt", topColor = "bright", bottom = rng:chance(0.5) and "shorts" or "leggings", bottomColor = "dark", feet = "shoes" }
	end

	local weights = (role == "trainer" and disc and disc.trainerBodyTypes) or (disc and disc.bodyTypes) or { average = 3, athletic = 2, slim = 2, heavy = 1 }
	if role == "trainer" and weights.kid then
		weights = Util.shallowCopy(weights)
		weights.kid = nil
	end
	local bodyType = pickBody(rng, weights)
	local skin = rng:pick(Appearance.SKIN)
	local hairColor = rng:pick(Appearance.HAIR_COLORS)
	if bodyType ~= "kid" and role == "trainer" and rng:chance(0.3) then
		hairColor = { 160, 160, 165 }
	end
	local hairStyle = rng:pick(Appearance.HAIR_STYLES)
	if outfit.hair then
		hairStyle = outfit.hair
		hairColor = { 20, 18, 16 }
	end

	local spec = {
		seed = opts.seed,
		role = role,
		discipline = opts.discipline,
		body = bodyType,
		proportions = Appearance.BODY[bodyType],
		skin = skin,
		colors = {},
		materials = {},
		extras = {},
		face = { eyeGap = rng:range(0.22, 0.3), eyeY = rng:range(0.05, 0.15), brows = rng:chance(0.7), mouth = rng:chance(0.5) },
	}
	local colors = spec.colors
	-- skin everywhere first
	for _, n in ipairs({ "Hips", "Chest", "Head", "LUpperArm", "LLowerArm", "LHand", "RUpperArm", "RLowerArm", "RHand", "LUpperLeg", "LLowerLeg", "LFoot", "RUpperLeg", "RLowerLeg", "RFoot" }) do
		colors[n] = skin
	end
	local function extra(e)
		table.insert(spec.extras, e)
	end

	-- hair and face
	if hairStyle ~= "bald" then
		extra({ kind = "hair", style = hairStyle, color = hairColor })
	end
	extra({ kind = "eyes" })
	if spec.face.brows then
		extra({ kind = "brows", color = hairColor })
	end
	if outfit.beard and rng:chance(outfit.beard) or (role == "trainer" and bodyType ~= "kid" and rng:chance(0.2)) then
		extra({ kind = "beard", color = hairColor })
	end

	-- top
	local top = outfit.top
	local topColor = resolveColor(rng, outfit.topColor)
	if outfit.nogiChance and rng:chance(outfit.nogiChance) then
		top = "rashguard"
	end
	if outfit.shirtlessChance and rng:chance(outfit.shirtlessChance) then
		top = "none"
	end
	local trim = outfit.trim or topColor
	if top == "gi" or top == "judogi" or top == "dobok" or top == "kungfu" or top == "yukata" or top == "suit" or top == "tracksuit" then
		-- long sleeves
		paint(colors, { "Chest", "LUpperArm", "LLowerArm", "RUpperArm", "RLowerArm" }, topColor)
		spec.materials.Chest = "Fabric"
		if top == "gi" or top == "judogi" then
			extra({ kind = "lapel", color = trim ~= topColor and trim or { math.max(topColor[1] - 25, 0), math.max(topColor[2] - 25, 0), math.max(topColor[3] - 25, 0) }, thick = top == "judogi" })
		elseif top == "dobok" then
			extra({ kind = "lapel", color = trim, vneck = true })
		elseif top == "kungfu" then
			extra({ kind = "buttons", color = trim })
			extra({ kind = "cuffs", color = trim })
		elseif top == "yukata" then
			extra({ kind = "lapel", color = trim })
			extra({ kind = "obi", color = { 30, 30, 35 } })
		elseif top == "suit" then
			extra({ kind = "lapel", color = trim, vneck = true })
			extra({ kind = "tie", color = trim })
		elseif top == "tracksuit" then
			extra({ kind = "stripe", part = "LUpperArm", color = trim })
			extra({ kind = "stripe", part = "RUpperArm", color = trim })
			extra({ kind = "zip", color = trim })
		end
		if outfit.patches then
			extra({ kind = "patches", color = rng:pick(Appearance.BRIGHT) })
		end
	elseif top == "tshirt" or top == "polo" or top == "rashguard" then
		paint(colors, { "Chest", "LUpperArm", "RUpperArm" }, topColor)
		if top == "rashguard" then
			paint(colors, { "LLowerArm", "RLowerArm" }, topColor)
			extra({ kind = "stripe", part = "Chest", color = rng:pick(Appearance.BRIGHT) })
		end
		if outfit.trim then
			extra({ kind = "logo", color = trim })
		end
		if top == "polo" then
			extra({ kind = "collar", color = trim })
		end
	elseif top == "tank" then
		colors.Chest = topColor
	elseif top == "singlet" then
		paint(colors, { "Chest", "Hips", "LUpperLeg", "RUpperLeg" }, topColor)
		extra({ kind = "stripe", part = "Chest", color = { 240, 240, 240 } })
		spec.singlet = true
	end
	spec.top = top

	-- bottom
	local bottom = outfit.bottom
	local bottomColor = outfit.bottomColor == "match" and topColor or resolveColor(rng, outfit.bottomColor, topColor)
	if bottom == "pants" or bottom == "leggings" or bottom == "yukata" then
		paint(colors, { "Hips", "LUpperLeg", "LLowerLeg", "RUpperLeg", "RLowerLeg" }, bottomColor)
		if bottom == "yukata" then
			spec.robe = true
		end
	elseif bottom == "shorts" or bottom == "thai_shorts" then
		paint(colors, { "Hips", "LUpperLeg", "RUpperLeg" }, bottomColor)
		extra({ kind = "waistband", color = bottom == "thai_shorts" and { 240, 240, 240 } or { 30, 30, 30 }, wide = bottom == "thai_shorts" })
		if bottom == "thai_shorts" then
			extra({ kind = "thai_text", color = { 240, 220, 120 } })
		end
	elseif bottom == "mawashi" then
		extra({ kind = "mawashi", color = resolveColor(rng, outfit.bottomColor) })
		extra({ kind = "sagari", color = { 60, 50, 40 } })
	end
	spec.bottom = bottom

	-- belt / rank
	local rank = opts.rank or 1
	if disc and outfit.belt then
		local r = rank
		if role == "trainer" then
			r = math.max(r, outfit.beltRankMin or #disc.ranks - 2)
		end
		r = Util.clamp(r, 1, #disc.ranks)
		local rk = disc.ranks[r]
		extra({ kind = "belt", color = rk.color, stripe = rk.stripe, sash = outfit.beltStyle == "sash" })
		spec.rankName = rk.name
	elseif disc then
		spec.rankName = disc.ranks[Util.clamp(rank, 1, #disc.ranks)].name
	end

	-- gear
	local wantGloves = outfit.gloves and (not outfit.glovesChance or rng:chance(outfit.glovesChance))
	if wantGloves then
		local gc = resolveColor(rng, outfit.gloveColor, { 200, 30, 30 })
		extra({ kind = "gloves", style = outfit.gloves, color = gc })
	elseif outfit.wraps then
		colors.LHand = { 240, 240, 240 }
		colors.RHand = { 240, 240, 240 }
	end
	if outfit.shins then
		extra({ kind = "shins", color = resolveColor(rng, "bright") })
	end
	if outfit.prajiad then
		extra({ kind = "prajiad", color = rng:pick({ { 220, 40, 60 }, { 30, 90, 200 }, { 230, 180, 30 }, { 240, 240, 240 } }) })
	end
	if outfit.headgear and rng:chance(outfit.headgear) then
		extra({ kind = "headgear", color = { 30, 30, 35 } })
	end
	if outfit.cap then
		extra({ kind = "cap", color = topColor })
	end
	if outfit.whistle then
		extra({ kind = "whistle" })
	end

	-- feet
	local feet = outfit.feet
	if feet == "boots" or feet == "wrestling_shoes" then
		local fc = feet == "boots" and { 30, 30, 35 } or resolveColor(rng, "team")
		colors.LFoot, colors.RFoot = fc, fc
		extra({ kind = "boot_tops", color = fc })
	elseif feet == "shoes" then
		local fc = rng:pick({ { 30, 30, 35 }, { 240, 240, 240 }, { 60, 60, 70 } })
		colors.LFoot, colors.RFoot = fc, fc
	elseif feet == "sandals" then
		extra({ kind = "sandals", color = { 120, 80, 50 } })
	end

	-- category markers (VIPs and celebrities stand out)
	local cat = opts.category and Customers.byId[opts.category]
	if cat and cat.vip then
		extra({ kind = "sunglasses" })
		extra({ kind = "chain", color = { 212, 175, 55 } })
	end
	if cat and cat.celebrity then
		spec.aura = { 255, 200, 80 }
	end

	-- trainers: rarity shows as a coloured aura for epic+
	if role == "trainer" and opts.rarity then
		local r = Trainers.rarityById[opts.rarity]
		if r and r.order >= 4 then
			spec.aura = r.color
		end
		spec.rarity = opts.rarity
	end
	return spec
end

return Appearance
