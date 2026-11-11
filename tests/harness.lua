-- Offline test harness: runs the game's pure modules under stock Lua 5.4.
-- It fakes just enough of Roblox (game:GetService, script.Parent, require on
-- instances) to load ModuleScripts from the Rojo source tree.

local Harness = {}

local ROOT = arg and arg[0] and arg[0]:match("^(.*)/tests/") or "."

-- Rojo mapping (default.project.json)
local SERVICES = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
}

local files = {}
local dirs = {}
do
	local p = io.popen('cd "' .. ROOT .. '" && find src -type f -name "*.lua" && find src -type d')
	for line in p:lines() do
		if line:match("%.lua$") then
			files[line] = true
		else
			dirs[line] = true
		end
	end
	p:close()
end

local Node = {}
local cache = {}

local function makeNode(path, name, parent, isFile)
	local node = setmetatable({}, Node)
	rawset(node, "__path", path)
	rawset(node, "__name", name)
	rawset(node, "__parent", parent)
	rawset(node, "__file", isFile)
	return node
end

Node.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "Name" then
		return rawget(self, "__name")
	end
	local path = rawget(self, "__path")
	if rawget(self, "__file") then
		-- module file: children not supported
		error("attempt to index child '" .. key .. "' of module " .. path, 2)
	end
	local filePath = path .. "/" .. key .. ".lua"
	local child
	if files[filePath] then
		child = makeNode(filePath, key, self, true)
	elseif dirs[path .. "/" .. key] then
		child = makeNode(path .. "/" .. key, key, self, false)
	else
		local extra = rawget(self, "__extra")
		if extra and extra[key] then
			return extra[key]
		end
		error("no child '" .. key .. "' in " .. path, 2)
	end
	rawset(self, key, child)
	return child
end

local function serviceNode(name)
	local node = makeNode("<" .. name .. ">", name, nil, false)
	local extra = {}
	for childName, path in pairs(SERVICES[name] or {}) do
		extra[childName] = makeNode(path, childName, node, false)
	end
	rawset(node, "__extra", extra)
	return node
end

local services = {}
local game = {}
function game:GetService(name)
	if not services[name] then
		services[name] = serviceNode(name)
	end
	return services[name]
end
Harness.game = game

local function robloxRequire(target)
	if type(target) ~= "table" or getmetatable(target) ~= Node then
		return require(target)
	end
	local path = rawget(target, "__path")
	if not rawget(target, "__file") then
		local init = path .. "/init.lua"
		if files[init] then
			path = init
		else
			error("require on a folder without init.lua: " .. path, 2)
		end
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local env = setmetatable({ script = target, game = game }, { __index = _G })
	env.require = robloxRequire
	local chunk, err = loadfile(ROOT .. "/" .. path, "t", env)
	if not chunk then
		error(err, 2)
	end
	local result = chunk()
	cache[path] = result
	return result
end

-- require("ReplicatedStorage/Shared/Config/Disciplines") style helper
function Harness.load(spec)
	local parts = {}
	for part in spec:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	local node = game:GetService(parts[1])
	for i = 2, #parts do
		node = node[parts[i]]
	end
	return robloxRequire(node)
end

-- Tiny assertion library
local results = { passed = 0, failed = 0, failures = {} }
Harness.results = results
local currentSuite = "?"

function Harness.suite(name, fn)
	currentSuite = name
	io.write("• " .. name .. "\n")
	local ok, err = pcall(fn)
	if not ok then
		results.failed = results.failed + 1
		table.insert(results.failures, name .. ": ERROR " .. tostring(err))
		io.write("    ERROR " .. tostring(err) .. "\n")
	end
end

function Harness.check(cond, message)
	if cond then
		results.passed = results.passed + 1
	else
		results.failed = results.failed + 1
		table.insert(results.failures, currentSuite .. ": " .. message)
		io.write("    FAIL " .. message .. "\n")
	end
end

function Harness.eq(a, b, message)
	Harness.check(a == b, message .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
end

return Harness
