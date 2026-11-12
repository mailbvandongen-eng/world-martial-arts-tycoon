-- Minimal stand-ins for Roblox datatypes so Rig.lua (CFrame maths, part
-- creation) can run under Lua 5.4 for the pose renderer. Only what Rig uses.

local Stub = {}

local function mat(a, b)
	-- 3x3 row-major multiply
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s = s + a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.zero = Vector3.new(0, 0, 0)

local CFrame = {}
CFrame.__index = function(self, k)
	if k == "X" then
		return self.p[1]
	elseif k == "Y" then
		return self.p[2]
	elseif k == "Z" then
		return self.p[3]
	elseif k == "Position" then
		return Vector3.new(self.p[1], self.p[2], self.p[3])
	end
	return CFrame[k]
end
local function newCF(p, r)
	return setmetatable({ p = p, r = r }, CFrame)
end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return newCF({ x.X, x.Y, x.Z }, I)
	end
	return newCF({ x or 0, y or 0, z or 0 }, I)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
function CFrame.Angles(x, y, z)
	return newCF({ 0, 0, 0 }, mat(mat(rx(x), ry(y)), rz(z)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return newCF({ 0, 0, 0 }, mat(mat(ry(y), rx(x)), rz(z)))
end
local function apply(r, v)
	return {
		r[1] * v[1] + r[2] * v[2] + r[3] * v[3],
		r[4] * v[1] + r[5] * v[2] + r[6] * v[3],
		r[7] * v[1] + r[8] * v[2] + r[9] * v[3],
	}
end
CFrame.__mul = function(a, b)
	if getmetatable(b) == Vector3 then
		local v = apply(a.r, { b.X, b.Y, b.Z })
		return Vector3.new(v[1] + a.p[1], v[2] + a.p[2], v[3] + a.p[3])
	end
	local t = apply(a.r, b.p)
	return newCF({ t[1] + a.p[1], t[2] + a.p[2], t[3] + a.p[3] }, mat(a.r, b.r))
end
CFrame.__add = function(a, v)
	return newCF({ a.p[1] + v.X, a.p[2] + v.Y, a.p[3] + v.Z }, a.r)
end
function CFrame:VectorToWorldSpace(v)
	local t = apply(self.r, { v.X, v.Y, v.Z })
	return Vector3.new(t[1], t[2], t[3])
end
function CFrame:GetComponents()
	local r = self.r
	return self.p[1], self.p[2], self.p[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
function CFrame.lookAt(pos, target)
	local f = { target.X - pos.X, target.Y - pos.Y, target.Z - pos.Z }
	local len = math.sqrt(f[1] ^ 2 + f[2] ^ 2 + f[3] ^ 2)
	f = { f[1] / len, f[2] / len, f[3] / len }
	-- right = forward x up
	local up = { 0, 1, 0 }
	local right = { f[2] * up[3] - f[3] * up[2], f[3] * up[1] - f[1] * up[3], f[1] * up[2] - f[2] * up[1] }
	local rl = math.sqrt(right[1] ^ 2 + right[2] ^ 2 + right[3] ^ 2)
	right = { right[1] / rl, right[2] / rl, right[3] / rl }
	local u = { right[2] * f[3] - right[3] * f[2], right[3] * f[1] - right[1] * f[3], right[1] * f[2] - right[2] * f[1] }
	-- columns: right, up, -forward
	return newCF({ pos.X, pos.Y, pos.Z }, { right[1], u[1], -f[1], right[2], u[2], -f[2], right[3], u[3], -f[3] })
end

-- generic Instance: any property can be set; children tracked
local Instance = {}
Stub.allParts = {}
local methods = {}
function methods.FindFirstChild(self, name)
	for _, c in ipairs(self._children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.GetChildren(self)
	return self._children
end
function methods.Destroy(self)
	self._destroyed = true
end
local newInstance
function methods.Clone(self)
	local c = newInstance(self.ClassName)
	for k, v in pairs(self) do
		if k ~= "_children" and k ~= "_attrs" and k ~= "Parent" then
			rawset(c, k, v)
		end
	end
	return c
end
newInstance = function(class)
	local obj = { ClassName = class, _children = {}, _attrs = {} }
	if class == "Part" or class == "WedgePart" or class == "SpawnLocation" then
		table.insert(Stub.allParts, obj)
		obj.Transparency = 0
		obj.Size = Vector3.new(4, 1, 2)
	end
	return setmetatable(obj, {
		__index = function(t, k)
			if methods[k] then
				return methods[k]
			end
			if k == "Position" and rawget(t, "CFrame") then
				return rawget(t, "CFrame").Position
			end
			return rawget(t, k)
		end,
		__newindex = function(t, k, v)
			if k == "Parent" and type(v) == "table" and v._children then
				table.insert(v._children, t)
			end
			rawset(t, k, v)
		end,
	})
end
function Instance.new(class)
	return newInstance(class)
end

local function enumTable(name)
	return setmetatable({}, {
		__index = function(_, item)
			return name .. "." .. item
		end,
	})
end
local Enum = setmetatable({}, {
	__index = function(t, k)
		local e = enumTable(k)
		rawset(t, k, e)
		return e
	end,
})

local function passthrough(...)
	return { ... }
end

function Stub.install(env)
	env.Vector3 = Vector3
	env.CFrame = CFrame
	env.Instance = Instance
	env.Enum = Enum
	env.Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end, new = function(r, g, b)
		return { R = r, G = g, B = b }
	end }
	env.ColorSequence = { new = passthrough }
	env.NumberSequence = { new = passthrough }
	env.NumberSequenceKeypoint = { new = passthrough }
	env.NumberRange = { new = passthrough }
	env.Vector2 = { new = passthrough }
	env.typeof = function(v)
		if type(v) == "table" and v.R and v.G and v.B then
			return "Color3"
		end
		return type(v)
	end
	env.UDim2 = { new = passthrough, fromScale = passthrough, fromOffset = passthrough }
	env.UDim = { new = passthrough }
	env.workspace = {
		BulkMoveTo = function(_, parts, cfs)
			for i, p in ipairs(parts) do
				p.CFrame = cfs[i]
			end
		end,
	}
end

return Stub
