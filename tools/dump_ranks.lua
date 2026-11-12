-- Prints every discipline's ranks as JSON (used by tools/gen_clothing.py).
package.path = "tests/?.lua;" .. package.path
arg = { [0] = "tests/dump.lua" }
local H = require("harness")
local D = H.load("ReplicatedStorage/Shared/Config/Disciplines")
local out = {}
for _, d in ipairs(D.list) do
	local ranks = {}
	for _, r in ipairs(d.ranks) do
		local stripe = r.stripe and string.format("[%d,%d,%d]", r.stripe[1], r.stripe[2], r.stripe[3]) or "null"
		table.insert(ranks, string.format('{"name":"%s","color":[%d,%d,%d],"stripe":%s}', r.name, r.color[1], r.color[2], r.color[3], stripe))
	end
	table.insert(out, string.format('"%s":[%s]', d.id, table.concat(ranks, ",")))
end
print("{" .. table.concat(out, ",") .. "}")
