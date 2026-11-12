-- Robux store. Prices come live from Roblox (GetProductInfo); every item
-- says exactly what it gives. Purchases go through MarketplaceService prompts;
-- the server grants them (ProcessReceipt / verified pass ownership).
-- Items whose id is still 0 show "Not configured"; in Studio they offer a
-- clearly labelled test grant so the effects can be tried before publishing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Monetization = require(Shared.Config.Monetization)
local Cosmetics = require(Shared.Config.Cosmetics)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors
local priceCache = {}

local function livePrice(item, isPass, label)
	if item.id == 0 then
		return
	end
	local key = (isPass and "p" or "d") .. item.id
	if priceCache[key] then
		label.Text = "R$ " .. priceCache[key]
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(item.id, isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			priceCache[key] = info.PriceInRobux
			if label.Parent then
				label.Text = "R$ " .. info.PriceInRobux
			end
		end
	end)
end

local function inSeason(seasonal)
	if not seasonal then
		return true
	end
	local m = tonumber(os.date("!%m"))
	local dd = tonumber(os.date("!%d"))
	local now = m * 100 + dd
	return now >= seasonal.from[1] * 100 + seasonal.from[2] and now <= seasonal.to[1] * 100 + seasonal.to[2]
end

local function buy(item, isPass, ui)
	local player = Players.LocalPlayer
	if item.id ~= 0 then
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	elseif RunService:IsStudio() then
		ui.act("devGrant", { kind = isPass and "pass" or "product", key = item.key }, "Studio test grant: " .. item.name)
	else
		ui.toast("This item is not configured yet", "warn")
	end
end

local function noneConfigured()
	if RunService:IsStudio() then
		return false
	end
	for _, p in ipairs(Monetization.gamePasses) do
		if p.id ~= 0 then
			return false
		end
	end
	for _, p in ipairs(Monetization.products) do
		if p.id ~= 0 then
			return false
		end
	end
	return true
end

local function productCard(parent, item, isPass, d, x, ui, order)
	local owned = isPass and d.purchases.passes[item.key]
	local card = Kit.frame(parent, { BackgroundColor3 = C.panel2, LayoutOrder = order })
	Kit.corner(card, 12)
	Kit.stroke(card, owned and C.good or C.stroke, owned and 2 or 1)
	local tag = isPass and (item.category == "bundles" and "BUNDLE" or item.category == "equipment" and "PREMIUM EQUIPMENT" or "GAME PASS") or "DEVELOPER PRODUCT"
	Kit.label(card, tag, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), TextSize = 11, TextColor3 = C.gold, Font = Kit.fontBlack })
	Kit.label(card, item.name, { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Font = Kit.fontBlack })
	local desc = item.description
	if item.cashMinutes and x.cashPacks[item.key] then
		desc = "Gives " .. Format.cash(x.cashPacks[item.key]) .. " right now. " .. desc
	end
	if item.seasonal then
		desc = desc .. "\n" .. item.seasonal.label .. (inSeason(item.seasonal) and " (available now)" or " (returns later this year)")
	end
	Kit.label(card, desc, { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 1, -110), TextSize = 13, Font = Kit.fontBody, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.text })
	local price = Kit.label(card, item.id == 0 and "Not configured" or ("R$ " .. item.robux), { Position = UDim2.new(0, 12, 1, -52), Size = UDim2.new(0.45, 0, 0, 40), TextSize = 18, Font = Kit.fontBlack, TextColor3 = C.gems })
	livePrice(item, isPass, price)
	local available = not owned and inSeason(item.seasonal)
	local label = owned and "Owned" or (item.id == 0 and (RunService:IsStudio() and "Test (Studio)" or "Unavailable") or "Buy")
	local b = Kit.button(card, label, function()
		if available then
			buy(item, isPass, ui)
		end
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(130, 40) }, owned and "dark" or "gold")
	Kit.setEnabled(b, available and (item.id ~= 0 or RunService:IsStudio()))
	return card
end

local function cosmeticCard(parent, c, d, ui, order)
	local owned = d.cosmetics.owned[c.id]
	local card = Kit.frame(parent, { BackgroundColor3 = C.panel2, LayoutOrder = order })
	Kit.corner(card, 12)
	Kit.label(card, string.upper(c.kind), { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), TextSize = 11, TextColor3 = C.gold, Font = Kit.fontBlack })
	Kit.label(card, c.name, { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Font = Kit.fontBlack })
	local how = c.source == "gems" and ("◆ " .. c.price) or c.source == "cash" and Format.cash(c.price) or c.source == "event" and "Event reward" or c.source == "pass" and ("Included in " .. (Monetization.passByKey[c.pass] and Monetization.passByKey[c.pass].name or "a pass")) or c.source == "level" and ("Reach level " .. c.level) or c.source == "rebirth" and ("Rebirth " .. c.rebirths .. "x") or c.source == "daily" and "Daily reward (day 7)" or c.source == "discipline" and "Free with the discipline; shows your rank" or "Free"
	Kit.label(card, "Cosmetic only. " .. how, { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 40), TextSize = 13, Font = Kit.fontBody, TextColor3 = C.muted })
	local canBuy = (c.source == "gems" or c.source == "cash") and not owned
	local afford = c.source == "gems" and d.gems >= (c.price or 0) or c.source == "cash" and d.cash >= (c.price or 0)
	local b = Kit.button(card, owned and "Owned" or (canBuy and "Buy" or "—"), function()
		if canBuy then
			ui.act("buyCosmetic", { id = c.id }, c.name .. " added to your inventory")
		end
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(110, 36) }, canBuy and "gold" or "dark")
	Kit.setEnabled(b, canBuy and afford)
end

return {
	title = "Store",
	width = 920,
	height = 620,
	build = function(body, args, ui)
		local tab = args.tab or "featured"
		local tabs = {}
		for _, cat in ipairs(Monetization.categories) do
			table.insert(tabs, { id = cat.id, name = cat.name, width = cat.id == "equipment" and 160 or 112 })
		end
		local scroll = Kit.scroll(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		Kit.grid(scroll, UDim2.fromOffset(280, 230), 10)
		local lastSig
		local function render(force)
			local d, x = State.data, State.derived
			local owned = 0
			for _ in pairs(d.purchases.passes) do
				owned = owned + 1
			end
			local ownedCos = 0
			for _ in pairs(d.cosmetics.owned) do
				ownedCos = ownedCos + 1
			end
			local sig = tab .. owned .. ":" .. ownedCos .. ":" .. math.floor(d.gems / 10) .. ":" .. math.floor(math.log10(d.cash + 1) * 4)
			if sig == lastSig and not force then
				return
			end
			lastSig = sig
			Kit.clear(scroll)
			local order = 0
			local function addPass(p)
				order = order + 1
				productCard(scroll, p, true, d, x, ui, order)
			end
			local function addProduct(p)
				order = order + 1
				productCard(scroll, p, false, d, x, ui, order)
			end
			if tab ~= "cosmetics" and noneConfigured() then
				-- nothing configured on Roblox yet: say so instead of showing dead buttons
				order = order + 1
				local card = Kit.frame(scroll, { BackgroundColor3 = C.panel2, LayoutOrder = order })
				Kit.corner(card, 12)
				Kit.label(card, "COMING SOON\n\nRobux items are not available yet. Cosmetics for gems and cash are in the Cosmetics tab.", { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -24), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top })
			elseif tab == "featured" then
				for _, p in ipairs(Monetization.gamePasses) do
					if p.featured or (p.seasonal and inSeason(p.seasonal)) then
						addPass(p)
					end
				end
				addPass(Monetization.passByKey.double_cash)
				addProduct(Monetization.productByKey.cash_medium)
				addProduct(Monetization.productByKey.boost_cash)
			elseif tab == "cosmetics" then
				for _, c in ipairs(Cosmetics.list) do
					if c.source == "gems" or c.source == "cash" or c.source == "event" or c.source == "pass" then
						order = order + 1
						cosmeticCard(scroll, c, d, ui, order)
					end
				end
			else
				for _, p in ipairs(Monetization.gamePasses) do
					if p.category == tab then
						addPass(p)
					end
				end
				for _, p in ipairs(Monetization.products) do
					if p.category == tab then
						addProduct(p)
					end
				end
			end
		end
		local _, select = Kit.tabs(body, tabs, function(id)
			tab = id
			render(true)
		end)
		select(tab)
		return render
	end,
}
