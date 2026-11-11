-- Turns server notifications into feedback: toasts, banners, cash popups,
-- sounds and particle bursts (level up, rank up, construction, purchases).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)
local Format = require(Shared.Modules.Format)
local Quests = require(Shared.Config.Quests)
local Cosmetics = require(Shared.Config.Cosmetics)
local Disciplines = require(Shared.Config.Disciplines)

local EffectsController = {}

local player = Players.LocalPlayer
local ui, audio

local function burst(color, count)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Speed = NumberRange.new(10, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(count or 40)
	task.delay(2, function()
		att:Destroy()
	end)
end

local handlers = {}

handlers.toast = function(p)
	ui.toast(p.text, p.kind)
end
handlers.social = function(p)
	ui.toast(p.text, "social")
end
handlers.collected = function(p)
	ui.cashPop("+" .. Format.cash(p.amount))
	if not p.auto then
		audio.play("cash")
		burst(Color3.fromRGB(110, 220, 120), 25)
	end
end
handlers.levelup = function(p)
	ui.banner("LEVEL " .. p.level .. "!", (p.gems and p.gems > 0) and ("+◆" .. p.gems .. " gems") or "New content may be unlocked")
	audio.play("levelup")
	burst(Color3.fromRGB(255, 210, 80), 60)
end
handlers.rankup = function(p)
	local disc = Disciplines.byId[p.discipline]
	local color = disc and Color3.fromRGB(disc.accent[1], disc.accent[2], disc.accent[3]) or Color3.new(1, 1, 1)
	ui.banner("RANK UP!", (disc and disc.name or "") .. ": " .. p.name, color)
	audio.play("rankup")
end
handlers.mission = function(p)
	local def = Quests.byId[p.id]
	ui.toast("Mission complete" .. (def and (": " .. string.gsub(def.text, "%%[ds]", "") ) or "") .. " — claim it in Missions!")
	audio.play("unlock")
end
handlers.built = function(p)
	ui.toast(p.name .. (p.level > 1 and (" upgraded to level " .. p.level) or " is open!") .. " ★")
	audio.play("build_done")
end
handlers.construct = function()
	audio.play("construct")
end
handlers.unlock = function(p)
	ui.banner("UNLOCKED!", p.text)
	audio.play("unlock")
	burst(Color3.fromRGB(212, 175, 55), 50)
end
handlers.purchase = function(p)
	ui.banner("THANK YOU!", p.name)
	audio.play("purchase")
	burst(Color3.fromRGB(120, 200, 255), 60)
end
handlers.cosmetic = function(p)
	local c = Cosmetics.byId[p.id]
	ui.toast("New cosmetic unlocked: " .. (c and c.name or p.id))
end
handlers.trainerlevel = function(p)
	ui.toast(p.name .. " reached trainer level " .. p.level .. "!")
end
handlers.offline = function(p)
	ui.banner("WELCOME BACK!", "Your academies earned " .. Format.cash(p.amount) .. " while you were away (" .. Format.time(p.seconds) .. ")")
	audio.play("cash")
end
handlers.championship = function(p)
	local disc = Disciplines.byId[p.discipline]
	ui.banner("CHAMPIONSHIP WON!", (disc and disc.name or "") .. " prize " .. Format.cash(p.prize) .. "  +" .. Format.short(p.reputation) .. " reputation")
	audio.play("announce")
	burst(Color3.fromRGB(255, 200, 60), 80)
end
handlers.day = function(p)
	local net = p.dues + p.passive - p.expenses
	if p.unpaid > 0 then
		ui.toast("Business day: could not pay " .. Format.cash(p.unpaid) .. " of expenses!", "warn")
	elseif p.dues + p.passive > 0 or p.expenses > 0 then
		ui.toast(string.format("Business day: dues %s, other academies %s, expenses %s (net %s)", Format.cash(p.dues), Format.cash(p.passive), Format.cash(p.expenses), Format.cash(net)))
	end
end

function EffectsController.init(uiModule, audioController)
	ui, audio = uiModule, audioController
	Remotes.get("Notify").OnClientEvent:Connect(function(kind, payload)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, payload or {})
			if not ok then
				warn("[Effects] " .. kind .. ": " .. tostring(err))
			end
		end
	end)
end

return EffectsController
