-- Client entry point: starts controllers and the interface.

local Controllers = script.Parent.Controllers
local UIFolder = script.Parent.UI

local State = require(Controllers.State)
local AudioController = require(Controllers.AudioController)
local NPCController = require(Controllers.NPCController)
local WorldController = require(Controllers.WorldController)
local EffectsController = require(Controllers.EffectsController)
local EmoteController = require(Controllers.EmoteController)
local BoutController = require(Controllers.BoutController)

local UI = require(UIFolder.UI)
local HUD = require(UIFolder.HUD)

State.init()
AudioController.init()

UI.init()
UI.audio = AudioController
UI.emotes = EmoteController
UI.npc = NPCController
for _, module in ipairs(UIFolder.Panels:GetChildren()) do
	if module:IsA("ModuleScript") then
		UI.register(string.lower(module.Name), require(module))
	end
end
HUD.build(UI)

EffectsController.init(UI, AudioController)
EmoteController.init()
NPCController.init(AudioController)
BoutController.init(AudioController)
WorldController.init(UI)

-- apply graphics setting once the first state arrives
local applied = false
State.Changed:Connect(function()
	if not applied and State.data then
		applied = true
		local settings = require(UIFolder.Panels.Settings)
		settings.applyGraphics(State.data.settings.lowGraphics == true)
		if State.derived.daily and State.derived.daily.available then
			task.delay(3, function()
				if not UI.isOpen() then
					UI.open("daily")
				end
			end)
		end
	end
end)
