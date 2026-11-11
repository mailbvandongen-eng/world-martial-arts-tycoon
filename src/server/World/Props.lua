-- Prop library: training equipment, furniture, city architecture and
-- decorations, all built from primitive parts (no external assets).
-- Props.build(key, parent, cframe, opts) -> Model. Origin = floor centre,
-- facing = -Z (LookVector). Sizes are in studs.

local Props = {}

local rad = math.rad

local function col(c)
	if typeof(c) == "Color3" then
		return c
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

local MAT = Enum.Material
local Ctx = {}
Ctx.__index = Ctx

function Ctx:part(shape, size, pos, color, material, rot)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Color = col(color or { 200, 200, 200 })
	p.Material = material or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	local cf = self.cf * CFrame.new(pos)
	if rot then
		cf = cf * CFrame.Angles(rad(rot[1] or 0), rad(rot[2] or 0), rad(rot[3] or 0))
	end
	p.CFrame = cf
	p.CanCollide = self.collide
	p.Parent = self.model
	return p
end
function Ctx:box(size, pos, color, material, rot)
	return self:part(nil, size, pos, color, material, rot)
end
function Ctx:ball(d, pos, color, material)
	return self:part(Enum.PartType.Ball, Vector3.new(d, d, d), pos, color, material)
end
-- Cylinder standing up (Roblox cylinders lie along X, so rotate 90° around Z)
function Ctx:cyl(diameter, height, pos, color, material, rot)
	local r = rot or { 0, 0, 0 }
	return self:part(Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), pos, color, material, { r[1], r[2], (r[3] or 0) + 90 })
end
function Ctx:wedge(size, pos, color, material, rot)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.Color = col(color)
	w.Material = material or MAT.SmoothPlastic
	local cf = self.cf * CFrame.new(pos)
	if rot then
		cf = cf * CFrame.Angles(rad(rot[1] or 0), rad(rot[2] or 0), rad(rot[3] or 0))
	end
	w.CFrame = cf
	w.CanCollide = self.collide
	w.Parent = self.model
	return w
end
function Ctx:light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = col(color)
	l.Range = range or 12
	l.Brightness = brightness or 1
	l.Parent = part
	return l
end
function Ctx:text(part, face, text, color, bg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.2
	sg.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = bg and 0 or 1
	label.BackgroundColor3 = bg and col(bg) or Color3.new(0, 0, 0)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = col(color or { 255, 255, 255 })
	label.Parent = sg
	return label
end
function Ctx:neon(size, pos, color, rot)
	return self:box(size, pos, color, MAT.Neon, rot)
end

local V = Vector3.new
local WOOD = { 140, 95, 55 }
local DARKWOOD = { 85, 55, 30 }
local METAL = { 150, 150, 160 }
local BLACK = { 25, 25, 28 }
local WHITE = { 240, 240, 240 }
local LEATHER = { 140, 30, 30 }
local GOLD = { 212, 175, 55 }
local GREEN = { 60, 130, 60 }

local defs = {}

---------------------------------------------------------------- martial arts equipment
defs.makiwara = function(c)
	c:box(V(0.6, 4.5, 0.4), V(0, 2.25, 0), WOOD, MAT.Wood, { -5, 0, 0 })
	c:box(V(0.7, 1, 0.5), V(0, 3.6, -0.2), { 200, 190, 150 }, MAT.Fabric)
	c:box(V(1.4, 0.3, 1.4), V(0, 0.15, 0), DARKWOOD, MAT.Wood)
end
defs.kamiza = function(c, o)
	-- dojo shrine shelf with calligraphy scroll
	c:box(V(6, 0.4, 1.5), V(0, 4.5, 0), DARKWOOD, MAT.Wood)
	c:box(V(5.6, 0.3, 1.3), V(0, 6.8, 0), DARKWOOD, MAT.Wood)
	c:box(V(1.2, 2, 0.8), V(0, 5.7, 0), o.premium and GOLD or { 200, 160, 100 }, o.premium and MAT.Metal or MAT.Wood)
	local scroll = c:box(V(1.4, 3.5, 0.1), V(2.4, 6.3, 0.6), { 245, 240, 225 }, MAT.Fabric)
	c:text(scroll, Enum.NormalId.Front, "道", { 20, 20, 20 })
	c:box(V(1.4, 3.5, 0.1), V(-2.4, 6.3, 0.6), { 245, 240, 225 }, MAT.Fabric)
end
defs.wall_target = function(c)
	c:box(V(1.6, 2.2, 0.4), V(0, 4, 0), { 200, 40, 40 }, MAT.Fabric)
	c:box(V(1.0, 1.4, 0.45), V(0, 4, 0), WHITE, MAT.Fabric)
	c:box(V(0.3, 4, 0.3), V(0, 2, 0.2), WOOD, MAT.Wood)
end
defs.lantern = function(c)
	c:cyl(0.12, 2, V(0, 8.5, 0), BLACK)
	local l = c:ball(1.4, V(0, 7.2, 0), { 255, 235, 200 }, MAT.Neon)
	l.Transparency = 0.2
	c:light(l, { 255, 220, 170 }, 14, 0.8)
end
defs.lantern_red = function(c)
	c:cyl(0.12, 2, V(0, 8.5, 0), BLACK)
	local l = c:ball(1.6, V(0, 7.1, 0), { 220, 40, 40 }, MAT.Neon)
	c:box(V(0.6, 0.3, 0.6), V(0, 6.2, 0), GOLD, MAT.Metal)
	c:light(l, { 255, 120, 90 }, 14, 0.8)
end
defs.banner = function(c, o)
	local b = c:box(V(2.4, 5, 0.15), V(0, 6, 0), o.accent or { 180, 30, 30 }, MAT.Fabric)
	c:box(V(2.8, 0.25, 0.25), V(0, 8.6, 0), DARKWOOD, MAT.Wood)
	if o.glyph then
		c:text(b, Enum.NormalId.Front, o.glyph, WHITE)
	end
end
defs.mirror = function(c)
	local m = c:box(V(5, 5, 0.2), V(0, 3.5, 0), { 200, 220, 230 }, MAT.Glass)
	m.Reflectance = 0.6
	m.Transparency = 0.1
	c:box(V(5.3, 0.3, 0.3), V(0, 6.1, 0), METAL, MAT.Metal)
end
defs.heavy_bag = function(c, o)
	local bagColor = o.finish == "carbon" and { 40, 40, 45 } or o.finish == "gold" and GOLD or LEATHER
	c:cyl(0.1, 3, V(0, 8.5, 0), METAL, MAT.Metal)
	c:cyl(1.7, 4, V(0, 5, 0), bagColor, o.finish == "gold" and MAT.Metal or MAT.Fabric)
	c:box(V(0.4, 0.2, 2.6), V(0, 10, 0.9), BLACK)
end
defs.heavy_bag_gold = function(c, o)
	defs.heavy_bag(c, { finish = "gold" })
end
defs.heavy_bag_long = function(c, o)
	-- long Thai banana bag
	c:cyl(0.1, 2, V(0, 9.5, 0), METAL, MAT.Metal)
	c:cyl(1.5, 6.5, V(0, 5.2, 0), o.finish == "carbon" and { 40, 40, 45 } or { 30, 30, 120 }, MAT.Fabric)
end
defs.speed_bag = function(c)
	c:box(V(3, 0.4, 2), V(0, 6.6, 0.5), DARKWOOD, MAT.Wood)
	c:ball(0.9, V(0, 5.9, 0), LEATHER, MAT.Fabric)
	c:box(V(0.4, 6.6, 0.4), V(0, 3.3, 1.3), METAL, MAT.Metal)
end
defs.weights = function(c)
	c:box(V(4, 0.3, 1.5), V(0, 2.5, 0), BLACK, MAT.Metal)
	c:box(V(0.3, 2.5, 1.2), V(-1.8, 1.25, 0), BLACK, MAT.Metal)
	c:box(V(0.3, 2.5, 1.2), V(1.8, 1.25, 0), BLACK, MAT.Metal)
	for i = -1, 1 do
		c:cyl(0.6, 0.4, V(i * 1.2, 2.9, 0), { 60, 60, 65 }, MAT.Metal, { 0, 0, 90 })
	end
end
defs.throw_dummy = function(c)
	c:box(V(1.6, 2.2, 0.9), V(0, 3.4, 0), WHITE, MAT.Fabric)
	c:ball(1.1, V(0, 5.1, 0), { 200, 190, 170 }, MAT.Fabric)
	c:box(V(0.6, 2.3, 0.6), V(-0.45, 1.15, 0), WHITE, MAT.Fabric)
	c:box(V(0.6, 2.3, 0.6), V(0.45, 1.15, 0), WHITE, MAT.Fabric)
	c:box(V(1.7, 0.25, 0.95), V(0, 2.6, 0), BLACK, MAT.Fabric)
end
defs.grapple_dummy = function(c)
	c:box(V(1.5, 2, 0.9), V(0, 0.45, 0), { 60, 60, 70 }, MAT.Fabric, { 90, 0, 0 })
	c:ball(1, V(0, 0.5, -1.5), { 60, 60, 70 }, MAT.Fabric)
	c:box(V(0.6, 0.6, 2.2), V(-0.5, 0.3, 2), { 60, 60, 70 }, MAT.Fabric)
	c:box(V(0.6, 0.6, 2.2), V(0.5, 0.3, 2), { 60, 60, 70 }, MAT.Fabric)
end
defs.crash_mat = function(c)
	c:box(V(5, 1.2, 3.5), V(0, 0.6, 0), { 40, 80, 160 }, MAT.Fabric)
end
defs.kick_shield = function(c)
	c:box(V(1.4, 2.4, 0.8), V(0, 3.2, 0), { 30, 30, 35 }, MAT.Fabric)
	c:box(V(0.3, 2, 0.3), V(0, 1, 0.2), METAL, MAT.Metal)
	c:box(V(1.2, 0.2, 1.2), V(0, 0.1, 0), BLACK)
end
defs.thai_pad_rack = function(c)
	c:box(V(4, 4, 0.3), V(0, 3, 0.4), DARKWOOD, MAT.Wood)
	for i = -1, 1 do
		c:box(V(0.9, 1.4, 0.5), V(i * 1.2, 3.5, 0), { 200, 30, 40 }, MAT.Fabric)
		c:ball(0.7, V(i * 1.2, 2, 0), { 200, 30, 40 }, MAT.Fabric)
	end
end
defs.shrine_thai = function(c)
	c:box(V(2.5, 3, 2), V(0, 1.5, 0), { 230, 200, 120 }, MAT.Wood)
	c:wedge(V(3, 1.4, 1.2), V(0, 3.7, -0.5), { 200, 40, 40 }, MAT.SmoothPlastic)
	c:wedge(V(3, 1.4, 1.2), V(0, 3.7, 0.5), { 200, 40, 40 }, MAT.SmoothPlastic, { 0, 180, 0 })
	local f = c:ball(0.5, V(0, 3.3, -1.1), { 255, 200, 80 }, MAT.Neon)
	c:light(f, { 255, 190, 90 }, 8, 0.7)
	-- garlands
	c:box(V(2.6, 0.2, 0.2), V(0, 2.6, -1.05), { 255, 220, 120 }, MAT.Fabric)
end
defs.kick_target = function(c)
	c:box(V(0.3, 4.5, 0.3), V(0, 2.25, 0), METAL, MAT.Metal)
	c:box(V(1.4, 0.2, 1.4), V(0, 0.1, 0), BLACK)
	c:box(V(1.4, 1.6, 0.4), V(0, 5, 0), { 220, 40, 40 }, MAT.Fabric)
end
defs.flags_korea = function(c)
	local f = c:box(V(4, 2.6, 0.1), V(0, 6.5, 0), WHITE, MAT.Fabric)
	c:part(Enum.PartType.Cylinder, V(0.12, 1.1, 1.1), V(0, 6.5, -0.05), { 200, 40, 50 }, MAT.SmoothPlastic, { 0, 90, 0 })
	c:box(V(0.2, 7.8, 0.2), V(-2.1, 3.9, 0), GOLD, MAT.Metal)
	return f
end
defs.padded_wall = function(c, o)
	c:box(V(5, 5, 0.6), V(0, 3, 0), o.accent or { 30, 30, 35 }, MAT.Fabric)
	c:box(V(5, 0.2, 0.65), V(0, 3, 0), BLACK, MAT.Fabric)
end
defs.wooden_dummy = function(c)
	-- mook jong
	c:cyl(1.0, 5.5, V(0, 2.75, 0), WOOD, MAT.Wood)
	c:box(V(0.25, 0.25, 1.6), V(-0.35, 4.3, -0.8), DARKWOOD, MAT.Wood, { 0, 20, 0 })
	c:box(V(0.25, 0.25, 1.6), V(0.35, 4.3, -0.8), DARKWOOD, MAT.Wood, { 0, -20, 0 })
	c:box(V(0.25, 0.25, 1.3), V(0, 3.4, -0.7), DARKWOOD, MAT.Wood)
	c:box(V(0.25, 1.2, 0.25), V(0, 1.5, -0.7), DARKWOOD, MAT.Wood, { 30, 0, 0 })
end
defs.weapon_rack = function(c)
	c:box(V(4, 0.3, 0.6), V(0, 1, 0), DARKWOOD, MAT.Wood)
	c:box(V(4, 0.3, 0.6), V(0, 5, 0.2), DARKWOOD, MAT.Wood)
	for i = -1.5, 1.5, 0.75 do
		c:cyl(0.15, 5.5, V(i, 3.1, 0.1), WOOD, MAT.Wood, { 5, 0, 0 })
	end
	c:box(V(0.2, 1.4, 0.5), V(1.5, 6, 0.1), METAL, MAT.Metal)
end
defs.bob_dummy = function(c)
	c:cyl(1.6, 1.2, V(0, 0.6, 0), BLACK)
	c:cyl(0.6, 2.4, V(0, 2.4, 0), BLACK)
	c:box(V(1.6, 2, 1), V(0, 4.3, 0), { 220, 190, 160 }, MAT.SmoothPlastic)
	c:ball(1.1, V(0, 5.9, 0), { 220, 190, 160 }, MAT.SmoothPlastic)
end
defs.teppo_post = function(c)
	c:cyl(1.2, 9, V(0, 4.5, 0), { 160, 120, 70 }, MAT.Wood)
	c:box(V(1.4, 0.4, 1.4), V(0, 9, 0), DARKWOOD, MAT.Wood)
end
defs.salt_box = function(c)
	c:box(V(1.5, 1.5, 1.5), V(0, 0.75, 0), WOOD, MAT.Wood)
	c:box(V(1.3, 0.2, 1.3), V(0, 1.55, 0), WHITE, MAT.Sand)
end
defs.mat_row = function(c)
	for i = -1, 1 do
		c:box(V(1.6, 0.15, 4), V(i * 2, 0.1, 0), { 70, 160, 200 }, MAT.Fabric)
	end
end
defs.dumbbells = function(c)
	c:box(V(4, 0.3, 1.2), V(0, 1.8, 0), BLACK, MAT.Metal)
	c:box(V(0.3, 1.8, 1), V(-1.8, 0.9, 0), BLACK, MAT.Metal)
	c:box(V(0.3, 1.8, 1), V(1.8, 0.9, 0), BLACK, MAT.Metal)
	for i = -1.4, 1.4, 0.7 do
		c:cyl(0.45, 1, V(i, 2.2, 0), { 70, 70, 75 }, MAT.Metal, { 90, 0, 0 })
	end
end
defs.kettlebells = function(c)
	for i = -1, 1 do
		c:ball(0.9, V(i * 1.2, 0.45, 0), { 40, 40, 45 }, MAT.Metal)
		c:box(V(0.6, 0.15, 0.15), V(i * 1.2, 1.05, 0), { 40, 40, 45 }, MAT.Metal)
	end
end
defs.squat_rack = function(c)
	c:box(V(0.3, 7, 0.3), V(-2, 3.5, 0), BLACK, MAT.Metal)
	c:box(V(0.3, 7, 0.3), V(2, 3.5, 0), BLACK, MAT.Metal)
	c:cyl(0.2, 5.5, V(0, 4.5, -0.3), METAL, MAT.Metal, { 0, 0, 90 })
	c:cyl(1.6, 0.4, V(-2.5, 4.5, -0.3), { 40, 40, 45 }, MAT.Metal, { 0, 0, 90 })
	c:cyl(1.6, 0.4, V(2.5, 4.5, -0.3), { 40, 40, 45 }, MAT.Metal, { 0, 0, 90 })
	c:box(V(5, 0.2, 3), V(0, 0.1, 0), { 120, 90, 60 }, MAT.Wood)
end
defs.bench = function(c)
	c:box(V(4, 0.5, 1.2), V(0, 1.6, 0), { 30, 30, 35 }, MAT.Fabric)
	c:box(V(0.3, 1.4, 1), V(-1.6, 0.7, 0), METAL, MAT.Metal)
	c:box(V(0.3, 1.4, 1), V(1.6, 0.7, 0), METAL, MAT.Metal)
end
defs.treadmill = function(c)
	c:box(V(2, 0.5, 4.5), V(0, 0.4, 0), BLACK, MAT.Metal)
	c:box(V(1.6, 0.1, 4), V(0, 0.7, 0), { 50, 50, 55 }, MAT.Fabric)
	c:box(V(0.2, 3.5, 0.2), V(-0.9, 2.2, -2), METAL, MAT.Metal)
	c:box(V(0.2, 3.5, 0.2), V(0.9, 2.2, -2), METAL, MAT.Metal)
	local screen = c:box(V(2, 0.8, 0.3), V(0, 4, -2.1), { 30, 160, 220 }, MAT.Neon)
	return screen
end
defs.bike = function(c)
	c:box(V(0.5, 0.3, 3), V(0, 0.15, 0), BLACK, MAT.Metal)
	c:box(V(0.4, 2.6, 0.4), V(0, 1.4, 0.6), BLACK, MAT.Metal, { -15, 0, 0 })
	c:box(V(1, 0.3, 1.4), V(0, 2.8, 0.8), { 30, 30, 35 }, MAT.Fabric)
	c:cyl(1.5, 0.4, V(0, 1, -1), METAL, MAT.Metal, { 0, 0, 90 })
	c:box(V(1.6, 0.25, 0.25), V(0, 3.2, -1.1), BLACK, MAT.Metal)
end
defs.rower = function(c)
	c:box(V(0.6, 0.4, 6), V(0, 0.5, 0), BLACK, MAT.Metal)
	c:box(V(1, 0.4, 1.2), V(0, 1, 0.8), { 30, 30, 35 }, MAT.Fabric)
	c:cyl(1.6, 0.8, V(0, 1.2, -2.7), { 60, 60, 65 }, MAT.Metal, { 0, 0, 90 })
end
defs.plant = function(c)
	c:cyl(1.4, 1.4, V(0, 0.7, 0), { 230, 230, 225 }, MAT.SmoothPlastic)
	c:ball(2.4, V(0, 2.4, 0), GREEN, MAT.Grass)
	c:ball(1.6, V(0.5, 3.4, 0.2), { 80, 150, 70 }, MAT.Grass)
end
defs.sofa = function(c)
	c:box(V(5, 1.2, 2), V(0, 0.9, 0), { 60, 40, 30 }, MAT.Fabric)
	c:box(V(5, 1.6, 0.6), V(0, 2, 0.75), { 60, 40, 30 }, MAT.Fabric)
	c:box(V(0.6, 1.4, 2), V(-2.5, 1.4, 0), { 60, 40, 30 }, MAT.Fabric)
	c:box(V(0.6, 1.4, 2), V(2.5, 1.4, 0), { 60, 40, 30 }, MAT.Fabric)
end
defs.chandelier = function(c)
	c:cyl(0.1, 2, V(0, 9.5, 0), GOLD, MAT.Metal)
	local core = c:ball(1.5, V(0, 8.2, 0), { 255, 245, 210 }, MAT.Neon)
	c:cyl(3, 0.2, V(0, 8.4, 0), GOLD, MAT.Metal)
	c:light(core, { 255, 230, 180 }, 20, 1.2)
end
defs.lockers = function(c)
	for i = -1, 1 do
		c:box(V(1.5, 6, 1.4), V(i * 1.55, 3, 0), { 90, 110, 140 }, MAT.Metal)
		c:box(V(0.2, 0.6, 0.1), V(i * 1.55 + 0.5, 3.4, -0.72), METAL, MAT.Metal)
	end
end
defs.shower = function(c)
	c:box(V(3, 7, 0.2), V(0, 3.5, 1.4), { 220, 235, 240 }, MAT.Glass).Transparency = 0.4
	c:box(V(0.2, 7, 3), V(-1.5, 3.5, 0), { 220, 235, 240 }, MAT.Glass).Transparency = 0.4
	c:cyl(0.15, 2, V(0, 6.5, 1), METAL, MAT.Metal)
	c:cyl(0.8, 0.2, V(0, 6.6, 0.4), METAL, MAT.Metal)
	c:box(V(3, 0.1, 3), V(0, 0.05, 0), { 200, 210, 215 }, MAT.Slate)
end
defs.massage_table = function(c)
	c:box(V(2.4, 0.5, 5), V(0, 2.4, 0), WHITE, MAT.Fabric)
	c:box(V(2, 2.2, 0.3), V(0, 1.1, -2), WOOD, MAT.Wood)
	c:box(V(2, 2.2, 0.3), V(0, 1.1, 2), WOOD, MAT.Wood)
end
defs.ice_bath = function(c)
	c:cyl(3, 2.2, V(0, 1.1, 0), { 230, 230, 235 }, MAT.SmoothPlastic)
	local w = c:cyl(2.6, 0.2, V(0, 2.1, 0), { 120, 200, 240 }, MAT.Glass)
	w.Transparency = 0.3
end
defs.bar_counter = function(c)
	c:box(V(8, 3.4, 1.6), V(0, 1.7, 0), { 120, 200, 60 }, MAT.SmoothPlastic)
	c:box(V(8.4, 0.3, 2), V(0, 3.55, 0), WHITE, MAT.Marble)
	for i = -3, 3, 2 do
		c:cyl(0.5, 1, V(i, 4.2, 0), { 255, 150, 40 }, MAT.Glass)
	end
end
defs.stool = function(c)
	c:cyl(0.3, 2.6, V(0, 1.3, 0), METAL, MAT.Metal)
	c:cyl(1.3, 0.3, V(0, 2.7, 0), { 30, 30, 35 }, MAT.Fabric)
end
defs.fridge = function(c)
	local f = c:box(V(3, 6.5, 2), V(0, 3.25, 0), { 230, 240, 245 }, MAT.Glass)
	f.Transparency = 0.2
	for y = 1.5, 5.5, 1.3 do
		c:box(V(2.6, 0.9, 0.9), V(0, y, 0), { 255, 120 + y * 20, 60 }, MAT.SmoothPlastic)
	end
	c:light(f, { 180, 230, 255 }, 8, 0.5)
end
defs.shop_shelf = function(c)
	c:box(V(5, 6, 1.4), V(0, 3, 0), WOOD, MAT.Wood)
	for y = 1.5, 5, 1.5 do
		for x = -1.6, 1.6, 1.6 do
			c:box(V(1, 0.8, 0.9), V(x, y, -0.3), { 200 - y * 20, 40 + x * 30, 60 }, MAT.Fabric)
		end
	end
end
defs.mannequin = function(c)
	c:cyl(1.2, 0.2, V(0, 0.1, 0), BLACK)
	c:cyl(0.2, 2.5, V(0, 1.3, 0), METAL, MAT.Metal)
	c:box(V(1.8, 2.2, 1), V(0, 3.6, 0), WHITE, MAT.Fabric)
	c:box(V(1.9, 0.3, 1.1), V(0, 3, 0), BLACK, MAT.Fabric)
	c:ball(1, V(0, 5.3, 0), { 230, 230, 230 })
end
defs.counter = function(c)
	c:box(V(6, 3.4, 1.8), V(0, 1.7, 0), DARKWOOD, MAT.Wood)
	c:box(V(1.2, 1, 0.8), V(1.5, 3.9, 0), BLACK, MAT.SmoothPlastic)
end
defs.desk = function(c, o)
	c:box(V(9, 3.6, 2.4), V(0, 1.8, 0), { 30, 28, 26 }, MAT.SmoothPlastic)
	c:box(V(9.4, 0.3, 2.8), V(0, 3.75, 0), GOLD, MAT.Metal)
	local front = c:box(V(7, 1.6, 0.1), V(0, 2, -1.25), BLACK, MAT.SmoothPlastic)
	c:text(front, Enum.NormalId.Front, o.label or "WELCOME", GOLD)
	c:box(V(1.6, 1.2, 0.2), V(-2, 4.5, 0.5), BLACK, MAT.SmoothPlastic, { -15, 0, 0 })
end
defs.trophy_case = function(c)
	local glass = c:box(V(4, 6, 1.6), V(0, 3, 0), { 220, 235, 240 }, MAT.Glass)
	glass.Transparency = 0.6
	c:box(V(4.2, 0.3, 1.8), V(0, 0.15, 0), DARKWOOD, MAT.Wood)
	for i = -1, 1 do
		c:cyl(0.5, 1, V(i * 1.2, 2.2, 0), GOLD, MAT.Metal)
		c:ball(0.7, V(i * 1.2, 2.9, 0), GOLD, MAT.Metal)
	end
end
defs.spotlight = function(c, o)
	c:box(V(0.4, 9, 0.4), V(0, 4.5, 0), BLACK, MAT.Metal)
	local lamp = c:cyl(1, 1.2, V(0, 9.2, -0.3), BLACK, MAT.Metal, { 45, 0, 0 })
	local sl = Instance.new("SpotLight")
	sl.Angle = 50
	sl.Range = 30
	sl.Brightness = 3
	sl.Color = col(o.accent or WHITE)
	sl.Face = Enum.NormalId.Right
	sl.Parent = lamp
end
defs.bleachers = function(c, o)
	for i = 0, 2 do
		c:box(V(9, 1, 1.6), V(0, 0.5 + i, 0.8 + i * 1.6), { 70, 70, 80 }, MAT.Metal)
	end
	-- crowd silhouettes
	for i = 0, 2 do
		for x = -3.5, 3.5, 1.75 do
			c:box(V(0.9, 1.4, 0.7), V(x, 1.8 + i, 0.8 + i * 1.6), o.crowd and o.crowd[(i + math.floor(x)) % #o.crowd + 1] or { 120, 120, 140 }, MAT.Fabric)
		end
	end
end
defs.ring = function(c, o)
	local w, dp = 11, 7.5
	local canvas = o.finish == "gold" and GOLD or o.canvas or { 40, 90, 170 }
	c:box(V(w, 1.4, dp), V(0, 0.7, 0), BLACK, MAT.SmoothPlastic)
	c:box(V(w - 0.4, 0.1, dp - 0.4), V(0, 1.45, 0), canvas, o.finish == "gold" and MAT.Metal or MAT.Fabric)
	local postColor = o.finish == "gold" and GOLD or { 220, 220, 225 }
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			c:cyl(0.5, 4.6, V(sx * (w / 2 - 0.3), 3.6, sz * (dp / 2 - 0.3)), postColor, MAT.Metal)
		end
	end
	local ropeColors = { { 220, 30, 30 }, WHITE, { 30, 60, 200 } }
	for i, h in ipairs({ 2.6, 3.6, 4.6 }) do
		local rc = o.finish == "gold" and GOLD or ropeColors[i]
		c:box(V(w - 0.6, 0.18, 0.18), V(0, h, -dp / 2 + 0.3), rc, MAT.Fabric)
		c:box(V(w - 0.6, 0.18, 0.18), V(0, h, dp / 2 - 0.3), rc, MAT.Fabric)
		c:box(V(0.18, 0.18, dp - 0.6), V(-w / 2 + 0.3, h, 0), rc, MAT.Fabric)
		c:box(V(0.18, 0.18, dp - 0.6), V(w / 2 - 0.3, h, 0), rc, MAT.Fabric)
	end
end
defs.octagon = function(c, o)
	local r = 4.6
	local diamond = o.finish == "diamond"
	c:part(Enum.PartType.Cylinder, V(1, r * 2.3, r * 2.3), V(0, 0.5, 0), BLACK, MAT.SmoothPlastic, { 0, 0, 90 })
	c:part(Enum.PartType.Cylinder, V(0.1, r * 2.2, r * 2.2), V(0, 1.05, 0), diamond and { 220, 240, 255 } or { 235, 235, 235 }, diamond and MAT.Glass or MAT.Fabric, { 0, 0, 90 })
	for i = 0, 7 do
		local a = i * 45
		local x = math.sin(rad(a)) * r * 1.08
		local z = math.cos(rad(a)) * r * 1.08
		local fence = c:box(V(r * 0.85, 4, 0.15), V(x, 3, z), diamond and { 180, 220, 255 } or { 30, 30, 35 }, diamond and MAT.Glass or MAT.DiamondPlate, { 0, a, 0 })
		fence.Transparency = diamond and 0.3 or 0.45
		c:cyl(0.3, 4.2, V(math.sin(rad(a + 22.5)) * r * 1.13, 3, math.cos(rad(a + 22.5)) * r * 1.13), diamond and WHITE or BLACK, MAT.Metal)
		c:box(V(r * 0.85, 0.3, 0.3), V(x, 5.1, z), diamond and { 120, 200, 255 } or { 200, 30, 30 }, diamond and MAT.Neon or MAT.Fabric, { 0, a, 0 })
	end
end
defs.dohyo = function(c, o)
	c:box(V(11, 1.4, 7.5), V(0, 0.7, 0), { 180, 140, 90 }, MAT.Sand)
	c:part(Enum.PartType.Cylinder, V(0.1, 6.2, 6.2), V(0, 1.45, 0), { 200, 170, 120 }, MAT.Sand, { 0, 0, 90 })
	-- straw bales ring (tawara)
	for i = 0, 15 do
		local a = rad(i * 22.5)
		c:box(V(1.1, 0.35, 0.35), V(math.sin(a) * 3.1, 1.6, math.cos(a) * 3.1), { 200, 180, 110 }, MAT.Fabric, { 0, i * 22.5 + 90, 0 })
	end
	c:box(V(0.6, 0.06, 0.12), V(-0.8, 1.52, 0), WHITE, MAT.SmoothPlastic)
	c:box(V(0.6, 0.06, 0.12), V(0.8, 1.52, 0), WHITE, MAT.SmoothPlastic)
	if o.finish == "luxury" then
		-- tsuriyane: hanging roof with tassels
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				c:box(V(0.2, 3, 0.2), V(sx * 4.4, 10, sz * 3), { 200, 30, 30 }, MAT.Fabric)
			end
		end
		c:box(V(10, 0.8, 7.6), V(0, 11.8, 0), DARKWOOD, MAT.Wood)
		c:wedge(V(10, 1.6, 3.8), V(0, 13, -1.9), { 60, 70, 90 }, MAT.Slate)
		c:wedge(V(10, 1.6, 3.8), V(0, 13, 1.9), { 60, 70, 90 }, MAT.Slate, { 0, 180, 0 })
		c:box(V(10.2, 0.2, 7.8), V(0, 11.3, 0), GOLD, MAT.Metal)
	end
end

---------------------------------------------------------------- city architecture
defs.tree = function(c, o)
	c:cyl(0.8, 6, V(0, 3, 0), { 110, 80, 50 }, MAT.Wood)
	c:ball(6, V(0, 8, 0), o.leaves or { 70, 130, 60 }, MAT.Grass)
	c:ball(4, V(1.5, 10, 1), o.leaves or { 85, 145, 70 }, MAT.Grass)
end
defs.sakura = function(c)
	defs.tree(c, { leaves = { 245, 180, 200 } })
end
defs.palm = function(c)
	c:cyl(0.9, 14, V(0, 7, 0), { 150, 120, 80 }, MAT.Wood, { 0, 0, 6 })
	for i = 0, 5 do
		c:box(V(1.2, 0.3, 6), V(math.sin(rad(i * 60)) * 2.5, 14, math.cos(rad(i * 60)) * 2.5), { 60, 140, 60 }, MAT.Grass, { -25, i * 60, 0 })
	end
end
defs.house = function(c, o)
	c:box(V(12, 9, 10), V(0, 4.5, 0), o.building or { 220, 200, 170 }, MAT.Brick)
	c:wedge(V(12, 5, 5), V(0, 11.5, -2.5), o.roof or { 150, 70, 50 }, MAT.Slate)
	c:wedge(V(12, 5, 5), V(0, 11.5, 2.5), o.roof or { 150, 70, 50 }, MAT.Slate, { 0, 180, 0 })
	c:box(V(2.4, 4, 0.2), V(0, 2, -5.05), DARKWOOD, MAT.Wood)
	for _, x in ipairs({ -3.5, 3.5 }) do
		c:box(V(2, 2, 0.2), V(x, 6, -5.05), { 170, 200, 230 }, MAT.Glass)
	end
end
defs.canal_house = function(c, o)
	local h = 16 + (o.variant or 0) % 3 * 3
	c:box(V(8, h, 9), V(0, h / 2, 0), o.building or { 120, 60, 40 }, MAT.Brick)
	c:box(V(4, 3, 9), V(0, h + 1.5, 0), o.building or { 120, 60, 40 }, MAT.Brick)
	c:wedge(V(4, 2, 4.5), V(0, h + 4, -2.25), o.roof or BLACK, MAT.Slate)
	c:wedge(V(4, 2, 4.5), V(0, h + 4, 2.25), o.roof or BLACK, MAT.Slate, { 0, 180, 0 })
	for y = 4, h - 2, 4 do
		for _, x in ipairs({ -2, 2 }) do
			c:box(V(1.6, 2.4, 0.2), V(x, y, -4.55), WHITE, MAT.SmoothPlastic)
			c:box(V(1.2, 2, 0.25), V(x, y, -4.55), { 140, 170, 200 }, MAT.Glass)
		end
	end
end
defs.canal = function(c)
	local w = c:box(V(12, 0.6, 30), V(0, -0.2, 0), { 60, 100, 120 }, MAT.Glass)
	w.Transparency = 0.2
	c:box(V(1, 1.2, 30), V(-6.5, 0.3, 0), { 100, 90, 80 }, MAT.Brick)
	c:box(V(1, 1.2, 30), V(6.5, 0.3, 0), { 100, 90, 80 }, MAT.Brick)
end
defs.bike_rack = function(c)
	for i = -2, 2 do
		c:part(Enum.PartType.Cylinder, V(0.2, 2.2, 2.2), V(i * 1.2, 1.1, 0), BLACK, MAT.Metal, { 0, 90, 0 })
	end
end
defs.bike_parked = defs.bike_rack
defs.container = function(c, o)
	local colors = { { 190, 60, 40 }, { 40, 90, 160 }, { 60, 140, 70 }, { 220, 160, 40 } }
	local cc = colors[((o.variant or 0) % #colors) + 1]
	c:box(V(8, 8.5, 20), V(0, 4.25, 0), cc, MAT.CorrodedMetal)
	c:box(V(8, 8.5, 20), V(0, 12.75, 0), colors[((o.variant or 0) + 1) % #colors + 1], MAT.CorrodedMetal)
end
defs.crane = function(c)
	c:box(V(2, 40, 2), V(0, 20, 0), { 230, 180, 40 }, MAT.DiamondPlate)
	c:box(V(2, 2, 34), V(0, 40, -10), { 230, 180, 40 }, MAT.DiamondPlate)
	c:box(V(0.2, 18, 0.2), V(0, 31, -24), BLACK, MAT.Metal)
end
defs.warehouse = function(c, o)
	c:box(V(26, 14, 18), V(0, 7, 0), o.building or { 90, 95, 100 }, MAT.CorrodedMetal)
	c:box(V(10, 9, 0.3), V(0, 4.5, -9.1), { 60, 60, 65 }, MAT.DiamondPlate)
end
defs.brick_house = function(c, o)
	c:box(V(14, 18, 10), V(0, 9, 0), { 150, 70, 55 }, MAT.Brick)
	c:box(V(14.4, 1, 10.4), V(0, 18.5, 0), WHITE, MAT.SmoothPlastic)
	for y = 4, 15, 5 do
		for x = -4, 4, 4 do
			c:box(V(2, 3, 0.2), V(x, y, -5.05), WHITE, MAT.SmoothPlastic)
			c:box(V(1.6, 2.6, 0.25), V(x, y, -5.06), { 150, 170, 190 }, MAT.Glass)
		end
	end
end
defs.phone_box = function(c)
	c:box(V(3, 8, 3), V(0, 4, 0), { 200, 20, 30 }, MAT.SmoothPlastic)
	c:box(V(2.4, 5, 3.1), V(0, 4, 0), { 200, 220, 230 }, MAT.Glass)
	c:box(V(3.2, 0.6, 3.2), V(0, 8.3, 0), { 200, 20, 30 }, MAT.SmoothPlastic)
end
defs.bus = function(c)
	c:box(V(8, 7, 22), V(0, 4.5, 0), { 200, 20, 30 }, MAT.SmoothPlastic)
	c:box(V(8, 7, 22), V(0, 11.5, 0), { 200, 20, 30 }, MAT.SmoothPlastic)
	c:box(V(8.1, 2, 20), V(0, 6.5, 0), { 40, 50, 60 }, MAT.Glass)
	c:box(V(8.1, 2, 20), V(0, 12, 0), { 40, 50, 60 }, MAT.Glass)
	for _, z in ipairs({ -7, 7 }) do
		c:part(Enum.PartType.Cylinder, V(8.4, 3, 3), V(0, 1.5, z), BLACK, MAT.SmoothPlastic)
	end
end
defs.torii = function(c)
	local red = { 210, 50, 40 }
	c:cyl(1.4, 16, V(-7, 8, 0), red, MAT.SmoothPlastic)
	c:cyl(1.4, 16, V(7, 8, 0), red, MAT.SmoothPlastic)
	c:box(V(20, 1.5, 2), V(0, 16.5, 0), BLACK, MAT.SmoothPlastic)
	c:box(V(17, 1.2, 1.4), V(0, 13.5, 0), red, MAT.SmoothPlastic)
end
defs.pagoda = function(c)
	for i = 0, 3 do
		local w = 14 - i * 2.5
		c:box(V(w * 0.7, 5, w * 0.7), V(0, 2.5 + i * 7, 0), { 200, 60, 40 }, MAT.Wood)
		c:box(V(w + 2, 1, w + 2), V(0, 5.5 + i * 7, 0), { 50, 55, 65 }, MAT.Slate)
	end
	c:cyl(0.5, 6, V(0, 31, 0), GOLD, MAT.Metal)
end
defs.lantern_stone = function(c)
	c:box(V(1.6, 3, 1.6), V(0, 1.5, 0), { 150, 150, 145 }, MAT.Slate)
	local box = c:box(V(2.2, 1.8, 2.2), V(0, 3.9, 0), { 160, 160, 155 }, MAT.Slate)
	c:wedge(V(3, 1, 1.5), V(0, 5.3, -0.75), { 120, 120, 115 }, MAT.Slate)
	c:wedge(V(3, 1, 1.5), V(0, 5.3, 0.75), { 120, 120, 115 }, MAT.Slate, { 0, 180, 0 })
	c:light(box, { 255, 210, 150 }, 10, 0.6)
end
defs.thai_temple = function(c)
	c:box(V(18, 10, 14), V(0, 5, 0), { 245, 235, 210 }, MAT.SmoothPlastic)
	for i = 0, 2 do
		c:wedge(V(20 - i * 4, 5, 8 - i), V(0, 12.5 + i * 4, -3.5 + i * 0.5), { 200, 50, 40 }, MAT.Slate)
		c:wedge(V(20 - i * 4, 5, 8 - i), V(0, 12.5 + i * 4, 3.5 - i * 0.5), { 40, 110, 70 }, MAT.Slate, { 0, 180, 0 })
	end
	c:cyl(0.6, 8, V(0, 26, 0), GOLD, MAT.Metal)
	c:box(V(18.4, 1, 14.4), V(0, 10.2, 0), GOLD, MAT.Metal)
end
defs.tuk_tuk = function(c)
	c:box(V(4, 3, 6), V(0, 2.5, 0), { 40, 120, 200 }, MAT.SmoothPlastic)
	c:box(V(4.4, 0.4, 6.4), V(0, 5.6, 0), { 230, 180, 40 }, MAT.SmoothPlastic)
	for _, x in ipairs({ -1.6, 1.6 }) do
		c:part(Enum.PartType.Cylinder, V(0.6, 1.8, 1.8), V(x, 0.9, 2), BLACK, MAT.SmoothPlastic)
	end
	c:part(Enum.PartType.Cylinder, V(0.6, 1.8, 1.8), V(0, 0.9, -2.5), BLACK, MAT.SmoothPlastic)
end
defs.hanok = function(c)
	c:box(V(16, 7, 10), V(0, 3.5, 0), { 235, 225, 200 }, MAT.Wood)
	c:box(V(18, 1, 12), V(0, 7.5, 0), DARKWOOD, MAT.Wood)
	c:wedge(V(20, 4, 7), V(0, 10, -3.5), { 50, 55, 65 }, MAT.Slate)
	c:wedge(V(20, 4, 7), V(0, 10, 3.5), { 50, 55, 65 }, MAT.Slate, { 0, 180, 0 })
end
defs.tower = function(c)
	c:cyl(2.5, 50, V(0, 25, 0), { 220, 220, 225 }, MAT.Concrete)
	c:cyl(7, 5, V(0, 50, 0), { 200, 200, 210 }, MAT.Glass)
	c:cyl(0.6, 12, V(0, 58, 0), { 220, 40, 40 }, MAT.Metal)
end
defs.neon_sign = function(c, o)
	local sign = c:box(V(12, 5, 0.6), V(0, 14, 0), BLACK, MAT.SmoothPlastic)
	c:neon(V(12.4, 0.3, 0.7), V(0, 16.6, 0), o.accent or { 255, 60, 200 })
	c:neon(V(12.4, 0.3, 0.7), V(0, 11.4, 0), o.accent or { 255, 60, 200 })
	c:box(V(0.6, 12, 0.6), V(0, 6, 0.5), METAL, MAT.Metal)
	c:text(sign, Enum.NormalId.Front, o.text or "FIGHT NIGHT", o.accent or { 255, 60, 200 })
	c:light(sign, o.accent or { 255, 60, 200 }, 20, 1)
end
defs.skyscraper = function(c, o)
	local h = 70 + ((o.variant or 0) % 4) * 18
	c:box(V(20, h, 20), V(0, h / 2, 0), o.building or { 140, 130, 120 }, MAT.Concrete)
	for y = 6, h - 4, 6 do
		c:box(V(20.2, 2.2, 20.2), V(0, y, 0), { 90, 110, 130 }, MAT.Glass)
	end
	c:box(V(8, 6, 8), V(0, h + 3, 0), o.building or { 140, 130, 120 }, MAT.Concrete)
end
defs.glass_tower = function(c, o)
	local h = 90 + ((o.variant or 0) % 3) * 30
	c:box(V(16, h, 16), V(0, h / 2, 0), { 150, 190, 210 }, MAT.Glass)
	c:wedge(V(16, 20, 16), V(0, h + 10, 0), { 150, 190, 210 }, MAT.Glass)
	c:box(V(16.4, 1, 16.4), V(0, h, 0), GOLD, MAT.Metal)
end
defs.taxi = function(c)
	c:box(V(5, 2.2, 10), V(0, 1.7, 0), { 245, 200, 30 }, MAT.SmoothPlastic)
	c:box(V(4.4, 1.6, 5), V(0, 3.6, 0.5), { 245, 200, 30 }, MAT.SmoothPlastic)
	c:box(V(4.5, 1.2, 4.8), V(0, 3.6, 0.5), { 40, 50, 60 }, MAT.Glass)
	for _, z in ipairs({ -3, 3 }) do
		c:part(Enum.PartType.Cylinder, V(5.2, 1.6, 1.6), V(0, 0.8, z), BLACK, MAT.SmoothPlastic)
	end
end
defs.hydrant = function(c)
	c:cyl(0.9, 2.4, V(0, 1.2, 0), { 200, 30, 30 }, MAT.Metal)
	c:ball(1, V(0, 2.5, 0), { 200, 30, 30 }, MAT.Metal)
end
defs.fountain = function(c)
	c:cyl(9, 1.2, V(0, 0.6, 0), { 220, 215, 205 }, MAT.Marble)
	local w = c:cyl(8, 0.2, V(0, 1.15, 0), { 100, 170, 220 }, MAT.Glass)
	w.Transparency = 0.2
	c:cyl(1.5, 4, V(0, 3, 0), { 220, 215, 205 }, MAT.Marble)
	c:cyl(4, 0.6, V(0, 5, 0), { 220, 215, 205 }, MAT.Marble)
	local jet = c:part(nil, V(0.4, 0.4, 0.4), V(0, 5.6, 0), { 120, 190, 240 }, MAT.Neon)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(170, 215, 255))
	pe.Rate = 25
	pe.Speed = NumberRange.new(8, 10)
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.Acceleration = Vector3.new(0, -25, 0)
	pe.Lifetime = NumberRange.new(0.8, 1.1)
	pe.Size = NumberSequence.new(0.3)
	pe.Transparency = NumberSequence.new(0.3)
	pe.Parent = jet
end
defs.casino = function(c, o)
	c:box(V(28, 20, 16), V(0, 10, 0), { 60, 40, 70 }, MAT.SmoothPlastic)
	c:neon(V(28.4, 1, 16.4), V(0, 20, 0), o.accent or { 255, 60, 200 })
	c:neon(V(28.4, 1, 16.4), V(0, 12, 0), { 255, 220, 60 })
	local sign = c:box(V(18, 5, 1), V(0, 24, -6), BLACK, MAT.SmoothPlastic)
	c:text(sign, Enum.NormalId.Front, "★ GRAND ARENA ★", { 255, 220, 60 })
end
defs.lamp = function(c)
	c:cyl(0.4, 10, V(0, 5, 0), { 40, 40, 45 }, MAT.Metal)
	local head = c:box(V(1.4, 0.8, 1.4), V(0, 10.2, 0), { 255, 240, 200 }, MAT.Neon)
	c:light(head, { 255, 230, 180 }, 18, 0.8)
end
defs.fence = function(c)
	for i = -2, 2 do
		c:box(V(0.4, 3, 0.4), V(i * 2.5, 1.5, 0), WHITE, MAT.Wood)
	end
	c:box(V(10.4, 0.4, 0.2), V(0, 2.4, 0), WHITE, MAT.Wood)
	c:box(V(10.4, 0.4, 0.2), V(0, 1.2, 0), WHITE, MAT.Wood)
end

---------------------------------------------------------------- decorations (cosmetics)
defs.statue = function(c, o)
	c:box(V(4, 3, 4), V(0, 1.5, 0), { 220, 215, 205 }, MAT.Marble)
	c:box(V(1.8, 2.6, 1), V(0, 5.6, 0), GOLD, MAT.Metal)
	c:box(V(1.8, 0.9, 1), V(0, 3.9, 0), GOLD, MAT.Metal)
	c:box(V(0.7, 2.2, 0.7), V(-0.5, 3.4, 0), GOLD, MAT.Metal, { 0, 0, 10 })
	c:box(V(0.7, 2.2, 0.7), V(0.6, 3.6, -0.6), GOLD, MAT.Metal, { 70, 0, 0 })
	c:box(V(0.6, 2.2, 0.6), V(1.1, 7.2, 0), GOLD, MAT.Metal, { 0, 0, -30 })
	c:box(V(0.6, 2.2, 0.6), V(-1.2, 6.8, 0), GOLD, MAT.Metal, { 0, 0, 40 })
	c:ball(1.2, V(0, 7.6, 0), GOLD, MAT.Metal)
	local plate = c:box(V(3, 0.8, 0.1), V(0, 1.5, -2.05), BLACK, MAT.SmoothPlastic)
	c:text(plate, Enum.NormalId.Front, o.label or "FOUNDER", GOLD)
end
defs.trophy = function(c)
	c:box(V(3, 2, 3), V(0, 1, 0), BLACK, MAT.Marble)
	c:cyl(1, 3, V(0, 3.5, 0), GOLD, MAT.Metal)
	c:cyl(3.2, 3, V(0, 6.5, 0), GOLD, MAT.Metal)
	c:box(V(0.5, 2, 0.5), V(-1.9, 6.6, 0), GOLD, MAT.Metal, { 0, 0, 20 })
	c:box(V(0.5, 2, 0.5), V(1.9, 6.6, 0), GOLD, MAT.Metal, { 0, 0, -20 })
end
defs.trophy_world = function(c)
	defs.trophy(c)
	local globe = c:ball(2.4, V(0, 9.2, 0), { 80, 160, 255 }, MAT.Neon)
	c:light(globe, { 80, 160, 255 }, 16, 1)
end
defs.banners = function(c)
	for i = -1, 1 do
		c:box(V(0.3, 12, 0.3), V(i * 5, 6, 0), METAL, MAT.Metal)
		c:box(V(3, 6, 0.1), V(i * 5 + 1.6, 8.5, 0), ({ { 220, 40, 60 }, { 212, 175, 55 }, { 30, 90, 200 } })[i + 2], MAT.Fabric)
	end
end
defs.nobori = function(c)
	for i = -1, 1 do
		c:box(V(0.25, 11, 0.25), V(i * 3, 5.5, 0), WOOD, MAT.Wood)
		local f = c:box(V(1.8, 7, 0.08), V(i * 3 + 1, 6.5, 0), ({ { 200, 40, 40 }, { 240, 240, 240 }, { 40, 60, 150 } })[i + 2], MAT.Fabric)
		c:text(f, Enum.NormalId.Front, "相撲", i == 0 and { 30, 30, 30 } or WHITE)
	end
end
defs.golden_gate = function(c)
	c:box(V(1.5, 14, 1.5), V(-7, 7, 0), GOLD, MAT.Metal)
	c:box(V(1.5, 14, 1.5), V(7, 7, 0), GOLD, MAT.Metal)
	c:box(V(17, 1.6, 2), V(0, 14.5, 0), GOLD, MAT.Metal)
	local s = c:box(V(10, 2.2, 0.3), V(0, 12.4, 0), BLACK, MAT.SmoothPlastic)
	c:text(s, Enum.NormalId.Front, "VIP", GOLD)
end
defs.neon = function(c, o)
	defs.neon_sign(c, { accent = o.accent or { 80, 220, 255 }, text = o.label or "ELITE ACADEMY" })
end
defs.pillars = function(c)
	for i = -1, 1, 2 do
		c:cyl(2, 16, V(i * 5, 8, 0), { 235, 230, 220 }, MAT.Marble)
		local top = c:ball(2.4, V(i * 5, 17, 0), { 200, 120, 255 }, MAT.Neon)
		c:light(top, { 200, 120, 255 }, 14, 1)
	end
end
defs.sakura_garden = function(c)
	defs.tree(c, { leaves = { 245, 180, 200 } })
	c:box(V(10, 0.3, 10), V(0, 0.15, 0), { 200, 190, 170 }, MAT.Sand)
	c:box(V(1.5, 1, 1.2), V(3, 0.5, 2), { 130, 130, 125 }, MAT.Slate)
end

Props.defs = defs

-- Build a prop. opts are passed to the builder (accent, finish, variant, label...).
function Props.build(key, parent, cframe, opts)
	local fn = defs[key]
	local model = Instance.new("Model")
	model.Name = key
	if not fn then
		warn("[Props] unknown prop " .. tostring(key))
		model.Parent = parent
		return model
	end
	local ctx = setmetatable({ model = model, cf = cframe, collide = (opts and opts.collide) or false }, Ctx)
	fn(ctx, opts or {})
	model.Parent = parent
	return model
end

-- Large centrepieces occupy the back of a room (others go along the walls).
Props.CENTREPIECES = { ring = true, octagon = true, dohyo = true, bar_counter = true, desk = true }

return Props
