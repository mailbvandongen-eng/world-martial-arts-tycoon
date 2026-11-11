-- UI manager: the ScreenGui, responsive scaling, the HUD, toasts, popups and
-- one modal panel at a time. Panels live in UI/Panels and export
--   { title = string, build = function(body, args, ui) -> refresh() }

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local UI = {}

local player = Players.LocalPlayer
local gui, scale, modalLayer, toastLayer, popupLayer
local current -- { name, window, refresh, args }
local panels = {}
UI.audio = nil
UI.emotes = nil

local C = Kit.colors

---------------------------------------------------------------- scaling

local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam or not scale then
		return
	end
	local v = cam.ViewportSize
	local s = math.min(v.X / 1280, v.Y / 760)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		s = s * 1.15 -- bigger touch targets on phones/tablets
	end
	scale.Scale = math.clamp(s, 0.55, 1.25)
end

function UI.viewport()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return v / (scale and scale.Scale or 1)
end

---------------------------------------------------------------- toasts

function UI.toast(text, kind)
	if not toastLayer then
		return
	end
	local color = kind == "error" and C.bad or kind == "warn" and Color3.fromRGB(240, 160, 60) or kind == "social" and Color3.fromRGB(120, 180, 255) or C.gold
	local t = Kit.frame(toastLayer, { BackgroundColor3 = C.bg, Size = UDim2.fromOffset(440, 40), BackgroundTransparency = 0.05 })
	Kit.corner(t, 10)
	Kit.stroke(t, color, 2)
	Kit.label(t, text, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, TextColor3 = Color3.new(1, 1, 1) })
	task.delay(kind == "social" and 5 or 3.2, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		tw:Play()
		for _, d in ipairs(t:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.35)
		t:Destroy()
	end)
	if UI.audio and kind == "error" then
		UI.audio.play("error")
	end
end

-- Big centred banner (level up, rank up, unlock).
function UI.banner(title, subtitle, color)
	local f = Kit.frame(popupLayer, { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(460, 110) })
	Kit.corner(f, 14)
	Kit.stroke(f, color or C.gold, 3)
	Kit.label(f, title, { Size = UDim2.new(1, 0, 0.6, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.fontBlack, TextScaled = true, TextColor3 = color or C.gold })
	Kit.label(f, subtitle or "", { Position = UDim2.fromScale(0, 0.58), Size = UDim2.new(1, 0, 0.35, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18 })
	local s = Instance.new("UIScale")
	s.Scale = 0.4
	s.Parent = f
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		TweenService:Create(s, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		f:Destroy()
	end)
end

-- Floating "+$123" near the bottom bar.
function UI.cashPop(text, color)
	local l = Kit.label(popupLayer, text, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, math.random(-60, 60), 1, -120), Size = UDim2.fromOffset(220, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.fontBlack, TextSize = 30, TextColor3 = color or C.cash, TextStrokeTransparency = 0.3 })
	TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromOffset(0, 90), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		l:Destroy()
	end)
end

-- Simple confirm dialog.
function UI.confirm(title, text, onYes)
	local shade = Kit.frame(popupLayer, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 50 })
	local box = Kit.frame(shade, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 260), BackgroundColor3 = C.bg, ZIndex = 51 })
	Kit.corner(box, 14)
	Kit.stroke(box, C.gold, 2)
	Kit.padding(box, 16)
	Kit.label(box, title, { Size = UDim2.new(1, 0, 0, 30), Font = Kit.fontBlack, TextSize = 22, TextColor3 = C.gold, ZIndex = 52 })
	Kit.label(box, text, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -90), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 52, Font = Kit.fontBody })
	local yes = Kit.button(box, "Confirm", function()
		shade:Destroy()
		onYes()
	end, { Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(0.48, 0, 0, 44), ZIndex = 52 }, "gold")
	Kit.button(box, "Cancel", function()
		shade:Destroy()
	end, { Position = UDim2.new(0.52, 0, 1, -44), Size = UDim2.new(0.48, 0, 0, 44), ZIndex = 52 }, "dark")
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = yes
	end
end

---------------------------------------------------------------- panels

function UI.register(name, panel)
	panels[name] = panel
end

function UI.close()
	if current then
		current.window:Destroy()
		current = nil
		GuiService.SelectedObject = nil
	end
end

function UI.isOpen(name)
	return current ~= nil and (name == nil or current.name == name)
end

function UI.open(name, args)
	local panel = panels[name]
	if not panel then
		warn("[UI] unknown panel " .. tostring(name))
		return
	end
	if not State.ready() then
		UI.toast("Loading your academy...", "warn")
		return
	end
	UI.close()
	local vp = UI.viewport()
	local w = math.min(panel.width or 780, vp.X - 40)
	local h = math.min(panel.height or 560, vp.Y - 150)
	local window = Kit.frame(modalLayer, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.bg })
	Kit.corner(window, 14)
	Kit.stroke(window, C.gold, 2)
	local header = Kit.frame(window, { BackgroundColor3 = C.panel, Size = UDim2.new(1, 0, 0, 46) })
	Kit.corner(header, 14)
	Kit.label(header, panel.title or name, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -80, 1, 0), Font = Kit.fontBlack, TextSize = 22, TextColor3 = C.gold })
	local closeBtn = Kit.button(header, "✕", UI.close, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(36, 36), TextSize = 18 }, "dark")
	local body = Kit.frame(window, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -64) })
	current = { name = name, window = window, args = args }
	local ok, refresh = pcall(panel.build, body, args or {}, UI)
	if not ok then
		warn("[UI] panel " .. name .. " failed: " .. tostring(refresh))
		Kit.label(body, "This panel could not be opened.", { Size = UDim2.new(1, 0, 0, 30) })
	elseif current then
		current.refresh = refresh
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = closeBtn
	end
	if UI.audio then
		UI.audio.play("click")
	end
end

function UI.refreshCurrent()
	if current and current.refresh then
		local ok, err = pcall(current.refresh)
		if not ok then
			warn("[UI] refresh failed: " .. tostring(err))
		end
	end
end

-- Helper: call a server action, toast success text, refresh.
function UI.act(action, payload, successText)
	local ok, result = State.call(action, payload)
	if ok and successText then
		UI.toast(successText)
		if UI.audio then
			UI.audio.play("purchase")
		end
	end
	return ok, result
end

---------------------------------------------------------------- init

function UI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "WMAT_UI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = Kit.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	scale = Instance.new("UIScale")
	scale.Parent = gui
	UI.root = root
	UI.hudLayer = Kit.frame(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "HUD" })
	modalLayer = Kit.frame(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Modal", ZIndex = 10 })
	popupLayer = Kit.frame(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Popups", ZIndex = 20 })
	toastLayer = Kit.frame(root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.new(0, 460, 0.5, 0), Name = "Toasts", ZIndex = 30 })
	local tl = Kit.list(toastLayer, 6)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- with UIScale on the ScreenGui, the root must be sized in unscaled units
	local function resize()
		updateScale()
		local s = scale.Scale
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	resize()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)

	State.onError = function(msg)
		UI.toast(msg, "error")
	end
	State.Changed:Connect(function()
		UI.refreshCurrent()
	end)
	Kit.onClickSound = function()
		if UI.audio then
			UI.audio.play("click")
		end
	end
	-- gamepad: B closes, Y collects
	ContextActionService:BindAction("WMAT_Close", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and current then
			UI.close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("WMAT_Collect", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			State.call("collect", nil, true)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonY)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and current then
			UI.close()
		end
	end)
end

return UI
