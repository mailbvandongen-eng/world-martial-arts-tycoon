-- Small helpers. Written in the common subset of Luau and Lua 5.4 so the same
-- file runs in Roblox and in the offline test suite (tests/run.lua).

local Util = {}

function Util.clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

function Util.round(x)
	return math.floor(x + 0.5)
end

function Util.isFiniteNumber(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Util.find(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

function Util.count(map)
	local n = 0
	for _ in pairs(map) do
		n = n + 1
	end
	return n
end

function Util.keys(map)
	local out = {}
	for k in pairs(map) do
		table.insert(out, k)
	end
	table.sort(out, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return out
end

function Util.shallowCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[Util.deepCopy(k)] = Util.deepCopy(v)
	end
	return out
end

-- Fill missing keys of `target` from `defaults` (recursively). Existing values win.
function Util.reconcile(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil and v[1] == nil then
			Util.reconcile(target[k], v)
		end
	end
	return target
end

-- Pick a key from {key = weight} using a number r in [0, 1). Keys are sorted
-- so the result is deterministic for a given r.
function Util.weightedKey(weights, r)
	local total = 0
	local keys = Util.keys(weights)
	for _, k in ipairs(keys) do
		total = total + math.max(0, weights[k])
	end
	if total <= 0 then
		return nil
	end
	local target = r * total
	local acc = 0
	for _, k in ipairs(keys) do
		acc = acc + math.max(0, weights[k])
		if target < acc then
			return k
		end
	end
	return keys[#keys]
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

-- UTC day number since epoch, used for daily missions and rewards.
function Util.dayNumber(unixTime)
	return math.floor(unixTime / 86400)
end

-- Week number (weeks start on Monday). 1970-01-01 was a Thursday.
function Util.weekNumber(unixTime)
	return math.floor((math.floor(unixTime / 86400) + 3) / 7)
end

return Util
