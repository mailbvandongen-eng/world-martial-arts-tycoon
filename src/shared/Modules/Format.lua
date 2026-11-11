-- Number and time formatting for the UI.

local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }

local function trim(s)
	-- "12.0" -> "12", "1.50" -> "1.5"
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function Format.short(n)
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end
	local s
	if i == 1 then
		s = tostring(math.floor(n))
	elseif n >= 100 then
		s = tostring(math.floor(n))
	elseif n >= 10 then
		s = trim(string.format("%.1f", math.floor(n * 10) / 10))
	else
		s = trim(string.format("%.2f", math.floor(n * 100) / 100))
	end
	return (neg and "-" or "") .. s .. suffixes[i]
end

function Format.cash(n)
	return "$" .. Format.short(n)
end

-- 1234567 -> "1,234,567"
function Format.commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local neg = string.sub(s, 1, 1) == "-"
	if neg then
		s = string.sub(s, 2)
	end
	local out = s
	while true do
		local replaced
		out, replaced = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return (neg and "-" or "") .. out
end

function Format.time(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.percent(x)
	return tostring(math.floor(x * 100 + 0.5)) .. "%"
end

return Format
