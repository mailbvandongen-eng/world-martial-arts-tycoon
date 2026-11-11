-- Token-bucket rate limiting per player and action.

local RateLimiter = {}

-- limits = { default = { rate = per second, burst = n }, [action] = {...} }
function RateLimiter.new(limits)
	return { limits = limits, buckets = {} }
end

function RateLimiter.allow(rl, userId, action, now)
	local limit = rl.limits[action] or rl.limits.default
	local key = tostring(userId) .. ":" .. action
	local b = rl.buckets[key]
	if not b then
		b = { tokens = limit.burst, t = now }
		rl.buckets[key] = b
	end
	b.tokens = math.min(limit.burst, b.tokens + (now - b.t) * limit.rate)
	b.t = now
	if b.tokens >= 1 then
		b.tokens = b.tokens - 1
		return true
	end
	return false
end

function RateLimiter.forget(rl, userId)
	local prefix = tostring(userId) .. ":"
	for key in pairs(rl.buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			rl.buckets[key] = nil
		end
	end
end

return RateLimiter
