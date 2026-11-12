-- Robux purchases. Server-authoritative:
--  * Game Pass ownership is verified with UserOwnsGamePassAsync (on join and
--    after PromptGamePassPurchaseFinished) - the client's word is never used.
--  * Developer Products are granted only in ProcessReceipt, exactly once per
--    PurchaseId (memory + save data + permanent receipt DataStore), and only
--    reported as granted after the player's data was saved.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RNG = require(Shared.Modules.RNG)
local Format = require(Shared.Modules.Format)
local Monetization = require(Shared.Config.Monetization)

local Domain = script.Parent.Parent.Domain
local Purchases = require(Domain.Purchases)
local ReceiptLedger = require(Domain.ReceiptLedger)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)

local MonetizationService = {}

local ledger = ReceiptLedger.new()
local passById = {}
local productById = {}
for _, p in ipairs(Monetization.gamePasses) do
	if p.id ~= 0 then
		passById[p.id] = p
	end
end
for _, p in ipairs(Monetization.products) do
	if p.id ~= 0 then
		productById[p.id] = p
	end
end

local function ownsPass(player, pass)
	if pass.id == 0 then
		return false
	end
	for attempt = 1, 3 do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok then
			return owns
		end
		task.wait(attempt)
	end
	return false
end

local function applyPass(player, pass, announce)
	local d = DataService.get(player)
	if not d then
		return
	end
	local rng = RNG.new(player.UserId + os.time())
	local _, granted = Purchases.applyPass(d, pass.key, rng)
	if announce then
		PlayerService.notify(player, "purchase", { name = pass.name, granted = granted })
	end
	-- visuals that depend on passes (premium equipment, decorations)
	if pass.category == "equipment" or (pass.grants and pass.grants.cosmetics) then
		PlotService.refreshPlotOf(player)
	end
	PlayerService.markDirty(player)
end

-- Verify all configured passes for a player (on join).
-- On live servers the recorded passes are replaced by the verified set, so a
-- pass granted by a Studio test (or refunded) never sticks.
function MonetizationService.verifyPasses(player)
	local verified = {}
	for _, pass in ipairs(Monetization.gamePasses) do
		if pass.id ~= 0 and ownsPass(player, pass) then
			verified[pass.key] = true
			applyPass(player, pass, false)
		end
	end
	local d = DataService.get(player)
	if d and not RunService:IsStudio() then
		for key in pairs(d.purchases.passes) do
			if not verified[key] then
				d.purchases.passes[key] = nil
			end
		end
		PlayerService.markDirty(player)
	end
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataService.get(player)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById[receiptInfo.ProductId]
	if not product then
		warn("[Monetization] Unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	-- permanent store first: a receipt granted on another server/session is done
	local recorded = DataService.receiptGranted(purchaseId)
	if recorded == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- store unavailable: try later
	end
	if recorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local grantResult
	local status = ReceiptLedger.process(ledger, d, purchaseId, function()
		local ctx = PlayerService.ctx()
		local ok, result = Purchases.grantProduct(d, product.key, ctx)
		grantResult = result
		return ok
	end)
	if status == "failed" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- persist before telling Roblox it is granted
	if not DataService.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.recordReceipt(purchaseId, player.UserId, receiptInfo.ProductId)
	if status == "granted" then
		local text = product.name
		if grantResult and grantResult.cash then
			text = text .. ": +" .. Format.cash(grantResult.cash)
		end
		PlayerService.notify(player, "purchase", { name = text })
		if product.instantBuild then
			PlotService.refreshPlotOf(player)
		end
		PlayerService.markDirty(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Studio-only test grant (lets you test the store and its effects before the
-- real ids exist). Never active on live servers.
function MonetizationService.devGrant(player, kind, key, trustedDev)
	-- Studio, or a verified developer (ActionService checks). On live servers a
	-- dev-granted pass is removed again at the next join (verifyPasses).
	if not RunService:IsStudio() and not trustedDev then
		return false, "Not available"
	end
	local d = DataService.get(player)
	if not d then
		return false, "Not loaded"
	end
	if kind == "pass" then
		local pass = Monetization.passByKey[key]
		if not pass then
			return false, "Unknown pass"
		end
		applyPass(player, pass, true)
		return true
	elseif kind == "product" then
		local product = Monetization.productByKey[key]
		if not product then
			return false, "Unknown product"
		end
		local ok, result = Purchases.grantProduct(d, key, PlayerService.ctx())
		if ok and product.instantBuild then
			PlotService.refreshPlotOf(player)
		end
		PlayerService.notify(player, "purchase", { name = product.name .. " (Studio test)" })
		PlayerService.markDirty(player)
		return ok, result
	end
	return false, "Unknown kind"
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = passById[passId]
		if pass and ownsPass(player, pass) then
			applyPass(player, pass, true)
		end
	end)
	DataService.onLoaded(function(player)
		MonetizationService.verifyPasses(player)
	end)
end

return MonetizationService
