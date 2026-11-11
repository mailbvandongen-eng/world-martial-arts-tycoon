-- Validation of values coming from clients. Every Remote payload passes
-- through these before it reaches game logic. Each returns the value or nil.

local Validate = {}

function Validate.string(v, maxLen)
	if type(v) ~= "string" or #v == 0 or #v > maxLen then
		return nil
	end
	return v
end

function Validate.int(v, lo, hi)
	if type(v) ~= "number" or v ~= v or v ~= math.floor(v) or v < lo or v > hi then
		return nil
	end
	return v
end

function Validate.bool(v)
	if type(v) ~= "boolean" then
		return nil
	end
	return v
end

-- v must be a key of `map` (a config byId table). rawget avoids metatables.
function Validate.oneOf(v, map)
	if type(v) ~= "string" or #v > 64 then
		return nil
	end
	if rawget(map, v) == nil then
		return nil
	end
	return v
end

function Validate.table(v)
	if type(v) ~= "table" then
		return nil
	end
	return v
end

return Validate
