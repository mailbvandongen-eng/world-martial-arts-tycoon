-- What a Robux purchase grants. Called by MonetizationService only after
-- Roblox reported the purchase (ProcessReceipt / verified pass ownership).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Modules.Formulas)
local Monetization = require(Shared.Config.Monetization)
local Disciplines = require(Shared.Config.Disciplines)
local Economy = require(script.Parent.Economy)
local Academy = require(script.Parent.Academy)
local TrainerGen = require(script.Parent.TrainerGen)
local Progress = require(script.Parent.Progress)

local Purchases = {}

-- Applies a game pass the player owns. Idempotent: safe to call on every join.
function Purchases.applyPass(d, key, rng)
	local pass = Monetization.passByKey[key]
	if not pass then
		return false
	end
	local firstTime = not d.purchases.passes[key]
	d.purchases.passes[key] = true
	local granted = {}
	local g = pass.grants
	if g then
		for _, cosmeticId in ipairs(g.cosmetics or {}) do
			if not d.cosmetics.owned[cosmeticId] then
				d.cosmetics.owned[cosmeticId] = true
				table.insert(granted, cosmeticId)
			end
		end
		for _, masterId in ipairs(g.trainers or {}) do
			if not TrainerGen.ownsMaster(d, masterId) then
				TrainerGen.add(d, TrainerGen.fromMaster(masterId))
				table.insert(granted, masterId)
			end
		end
		-- one-time resources (starter bundle): only on the first grant
		if firstTime and not d.purchases.products[key] then
			d.purchases.products[key] = true
			if g.cash then
				d.cash = d.cash + g.cash
			end
			if g.gems then
				d.gems = d.gems + g.gems
			end
			if g.rareTrainer then
				local disc = "karate"
				for _, dd in ipairs(Disciplines.list) do
					if d.disciplines[dd.id] then
						disc = dd.id
						break
					end
				end
				TrainerGen.add(d, TrainerGen.generate(rng, disc, "rare"))
			end
		end
	end
	Progress.syncCosmetics(d)
	return true, granted
end

-- Developer product grant. ctx = { now }. Returns ok, description table.
function Purchases.grantProduct(d, key, ctx)
	local product = Monetization.productByKey[key]
	if not product then
		return false, "Unknown product"
	end
	if product.cashMinutes then
		local hourly = Academy.estimateAllHourly(d, ctx)
		local amount = Formulas.cashPackAmount(product, hourly)
		d.cash = d.cash + amount
		return true, { cash = amount }
	elseif product.boost then
		Economy.addBoost(d, product.boost, product.minutes, ctx.now)
		return true, { boost = product.boost, minutes = product.minutes }
	elseif product.instantBuild then
		local n = Academy.instantFinish(d)
		if n == 0 then
			-- nothing under construction: keep it as a credit for the next build
			d.flags.buildCredits = (d.flags.buildCredits or 0) + 1
		end
		return true, { finished = n, credit = n == 0 }
	end
	return false, "Product has no effect"
end

return Purchases
