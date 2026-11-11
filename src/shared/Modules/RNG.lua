-- Deterministic random numbers (Park-Miller). The same seed gives the same
-- sequence on server and client, which lets clients rebuild a visitor's look and
-- moves from a single number instead of receiving the whole description.

local RNG = {}
RNG.__index = RNG

local MOD = 2147483647
local MUL = 16807

function RNG.new(seed)
	local s = math.floor(math.abs(seed or 1)) % MOD
	if s == 0 then
		s = 1
	end
	local self = setmetatable({ state = s }, RNG)
	-- warm up so close seeds diverge
	self:next()
	self:next()
	return self
end

function RNG:next()
	self.state = (self.state * MUL) % MOD
	return (self.state - 1) / (MOD - 1)
end

-- Integer in [a, b]
function RNG:int(a, b)
	return a + math.floor(self:next() * (b - a + 1))
end

function RNG:range(a, b)
	return a + self:next() * (b - a)
end

function RNG:chance(p)
	return self:next() < p
end

function RNG:pick(list)
	if #list == 0 then
		return nil
	end
	return list[self:int(1, #list)]
end

-- Hash a string to a seed.
function RNG.hash(str)
	local h = 7
	for i = 1, #str do
		h = (h * 31 + string.byte(str, i)) % MOD
	end
	return h
end

return RNG
