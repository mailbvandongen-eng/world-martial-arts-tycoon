-- Player plots: claiming, building the academy of the active city, rebuilding
-- rooms when they change, the register display and broadcasting each plot's
-- layout to all clients (for NPC trainers and visitors).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Modules.Layout)
local Remotes = require(Shared.Modules.Remotes)
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)

local World = script.Parent.Parent.World
local WorldBuilder = require(World.WorldBuilder)
local PlotBuilder = require(World.PlotBuilder)
local RoomBuilder = require(World.RoomBuilder)
local Domain = script.Parent.Parent.Domain
local Academy = require(Domain.Academy)

local PlotService = {}

local plots = {} -- [index] = { folder, owner = Player?, roomsFolder, registerPad, built = { [slot] = Model } }
local playerPlot = {} -- [player] = index
local getData -- injected: function(player) -> data
local plotsRemote

function PlotService.setDataGetter(fn)
	getData = fn
end

function PlotService.plotOf(player)
	return playerPlot[player]
end

function PlotService.ownerOf(index)
	local p = plots[index]
	return p and p.owner or nil
end

function PlotService.plotCFrame(index)
	return PlotBuilder.plotCFrame(index)
end

local function clear(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- snapshots for clients

local function trainerInfo(d, uid)
	local t = uid and d.trainers[uid]
	if not t then
		return nil
	end
	return { seed = t.seed, discipline = t.discipline, rarity = t.rarity, name = t.name, master = t.master, title = t.title, level = t.level }
end

function PlotService.snapshot(index)
	local p = plots[index]
	local snap = { index = index }
	if not p.owner then
		return snap
	end
	local d = getData(p.owner)
	if not d then
		return snap
	end
	snap.ownerId = p.owner.UserId
	snap.ownerName = p.owner.DisplayName
	snap.city = d.activeCity
	snap.rooms = {}
	local branch = d.cities[d.activeCity]
	for slot, room in pairs(branch.rooms) do
		snap.rooms[slot] = {
			id = room.id,
			level = room.level,
			tier = room.tier,
			building = Academy.isBuilding(room, now()),
			trainer = trainerInfo(d, room.trainer),
			discipline = Academy.roomDiscipline(d, room),
		}
	end
	snap.rating = d.ratings.count > 0 and (d.ratings.sum / d.ratings.count) or 0
	snap.ratingCount = d.ratings.count
	return snap
end

function PlotService.broadcast(index)
	plotsRemote:FireAllClients("plot", PlotService.snapshot(index))
end

function PlotService.sendAll(player)
	local all = {}
	for i = 1, Layout.PLOT_COUNT do
		all[i] = PlotService.snapshot(i)
	end
	plotsRemote:FireClient(player, "all", all)
end

---------------------------------------------------------------- building

local function passesOf(d)
	return d and d.purchases.passes or {}
end

function PlotService.buildRoom(index, slot)
	local p = plots[index]
	local d = p.owner and getData(p.owner)
	if p.built[slot] then
		p.built[slot]:Destroy()
		p.built[slot] = nil
	end
	if not d then
		return
	end
	local cf = PlotBuilder.plotCFrame(index)
	local branch = d.cities[d.activeCity]
	local room = branch.rooms[tostring(slot)]
	local slotCount = Academy.slotCount(d, d.activeCity)
	if room then
		local trainer = room.trainer and d.trainers[room.trainer]
		local capacity = Formulas.roomCapacity(room.id, room.level, trainer and Formulas.trainerStats(trainer) or nil)
		p.built[slot] = RoomBuilder.build(p.roomsFolder, cf, slot, room, { plotIndex = index, passes = passesOf(d), now = now(), capacity = capacity })
	elseif slot <= Layout.MAX_SLOTS then
		local locked = slot > slotCount
		-- show at most one row of locked slots to hint at expansion
		if not locked or slot <= slotCount + 2 then
			p.built[slot] = RoomBuilder.buildEmpty(p.roomsFolder, cf, slot, index, locked)
		end
	end
end

function PlotService.buildAll(index)
	local p = plots[index]
	clear(p.folder)
	p.built = {}
	local d = p.owner and getData(p.owner)
	local cityId = d and d.activeCity or "smalltown"
	PlotBuilder.buildBase(p.folder, index, cityId, p.owner and p.owner.DisplayName or nil)
	PlotBuilder.buildSurroundings(p.folder, index, cityId)
	p.roomsFolder = Instance.new("Folder")
	p.roomsFolder.Name = "Rooms"
	p.roomsFolder.Parent = p.folder
	if not p.owner then
		PlotBuilder.buildClaim(p.folder, index)
		p.folder:SetAttribute("OwnerId", 0)
		p.registerPad = nil
		return
	end
	p.folder:SetAttribute("OwnerId", p.owner.UserId)
	p.folder:SetAttribute("City", cityId)
	local rec = d.cities[cityId].rooms["0"]
	local _, pad = PlotBuilder.buildReception(p.folder, index, cityId, rec and rec.level or 1, passesOf(d))
	p.registerPad = pad
	for slot = 1, Layout.MAX_SLOTS do
		PlotService.buildRoom(index, slot)
	end
	PlotService.buildDecorations(index)
end

function PlotService.buildDecorations(index)
	local p = plots[index]
	local old = p.folder:FindFirstChild("Decorations")
	if old then
		old:Destroy()
	end
	local d = p.owner and getData(p.owner)
	if d then
		PlotBuilder.buildDecorations(p.folder, index, d.cosmetics.equipped.deco, p.owner.DisplayName)
	end
end

-- Rebuild reception only (after a reception upgrade).
function PlotService.rebuildReception(index)
	local p = plots[index]
	local d = p.owner and getData(p.owner)
	local old = p.folder:FindFirstChild("Reception")
	if old then
		old:Destroy()
	end
	if d then
		local rec = d.cities[d.activeCity].rooms["0"]
		local _, pad = PlotBuilder.buildReception(p.folder, index, d.activeCity, rec and rec.level or 1, passesOf(d))
		p.registerPad = pad
	end
end

function PlotService.refreshRoomOf(player, slot)
	local index = playerPlot[player]
	if not index then
		return
	end
	if slot == 0 then
		PlotService.rebuildReception(index)
	else
		PlotService.buildRoom(index, slot)
	end
	PlotService.broadcast(index)
end

function PlotService.refreshPlotOf(player)
	local index = playerPlot[player]
	if index then
		PlotService.buildAll(index)
		PlotService.broadcast(index)
	end
end

function PlotService.updateRegister(player, amount, cap)
	local index = playerPlot[player]
	local p = index and plots[index]
	if not p or not p.registerPad then
		return
	end
	local bb = p.registerPad:FindFirstChild("RegisterLabel")
	if bb then
		bb.Amount.Text = Format.cash(amount) .. (amount >= cap and "  FULL" or "")
		bb.Amount.TextColor3 = amount >= cap and Color3.fromRGB(255, 120, 80) or Color3.fromRGB(120, 230, 120)
	end
	local stack = p.registerPad.Parent and p.registerPad.Parent:FindFirstChild("CashStack")
	if stack then
		local fill = cap > 0 and math.min(1, amount / cap) or 0
		local h = 0.2 + fill * 3
		local baseY = stack:GetAttribute("BaseY") or stack.Position.Y
		stack.Size = Vector3.new(2.4, h, 1.4)
		stack.CFrame = CFrame.new(stack.Position.X, baseY - 0.2 + h / 2, stack.Position.Z) * (stack.CFrame - stack.CFrame.Position)
	end
end

---------------------------------------------------------------- claiming

function PlotService.freePlot()
	for i = 1, Layout.PLOT_COUNT do
		if not plots[i].owner then
			return i
		end
	end
	return nil
end

function PlotService.teleportTo(player, index)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cf = PlotBuilder.plotCFrame(index)
	local target = cf * CFrame.new(0, 4, Layout.FRONT + 6) * CFrame.Angles(0, math.rad(180), 0)
	character:PivotTo(target)
end

function PlotService.claim(player, index)
	if playerPlot[player] then
		return false, "You already own an academy"
	end
	index = index or PlotService.freePlot()
	if not index or not plots[index] then
		return false, "No free plot"
	end
	if plots[index].owner then
		return false, "This plot is taken"
	end
	plots[index].owner = player
	playerPlot[player] = index
	local d = getData(player)
	if d then
		d.flags.hasPlot = true
	end
	PlotService.buildAll(index)
	PlotService.broadcast(index)
	PlotService.teleportTo(player, index)
	return true, index
end

function PlotService.release(player)
	local index = playerPlot[player]
	if not index then
		return
	end
	playerPlot[player] = nil
	plots[index].owner = nil
	PlotService.buildAll(index)
	PlotService.broadcast(index)
end

---------------------------------------------------------------- init

function PlotService.init()
	plotsRemote = Remotes.get("Plots")
	WorldBuilder.build()
	local folders = WorldBuilder.folders()
	for i = 1, Layout.PLOT_COUNT do
		local folder = Instance.new("Model")
		folder.Name = "Plot" .. i
		folder:SetAttribute("PlotIndex", i)
		folder.Parent = folders.plots
		plots[i] = { folder = folder, owner = nil, built = {} }
		PlotService.buildAll(i)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
end

return PlotService
