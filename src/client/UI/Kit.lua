-- UI kit: themed building blocks so every panel looks the same.
-- Dark charcoal / black panels, gold accents, white type, rounded corners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)

local Kit = {}

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
Kit.c3 = c3

Kit.colors = {
	bg = c3(Theme.bg), panel = c3(Theme.panel), panel2 = c3(Theme.panel2), stroke = c3(Theme.stroke),
	gold = c3(Theme.gold), goldDark = c3(Theme.goldDark), text = c3(Theme.text), muted = c3(Theme.muted),
	good = c3(Theme.good), bad = c3(Theme.bad), cash = c3(Theme.cash), gems = c3(Theme.gems), rep = c3(Theme.rep),
}
local C = Kit.colors
Kit.font = Enum.Font.GothamBold
Kit.fontBlack = Enum.Font.GothamBlack
Kit.fontBody = Enum.Font.Gotham

function Kit.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.corner)
	c.Parent = parent
	return c
end

function Kit.stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or C.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Kit.padding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Kit.frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.panel
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

function Kit.label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = C.text
	l.Font = Kit.font
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Button: style "gold" (primary), "dark", "good", "bad", "ghost"
function Kit.button(parent, text, onClick, props, style)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text or ""
	b.Font = Kit.font
	b.TextSize = 16
	b.BorderSizePixel = 0
	style = style or "gold"
	local bg, fg = C.gold, Color3.fromRGB(20, 20, 24)
	if style == "dark" then
		bg, fg = C.panel2, C.text
	elseif style == "good" then
		bg, fg = C.good, Color3.fromRGB(15, 30, 15)
	elseif style == "bad" then
		bg, fg = C.bad, Color3.new(1, 1, 1)
	elseif style == "ghost" then
		bg, fg = C.panel, C.muted
	end
	b.BackgroundColor3 = bg
	b.TextColor3 = fg
	b.Selectable = true
	Kit.corner(b, 8)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	if onClick then
		b.Activated:Connect(function()
			if Kit.onClickSound then
				Kit.onClickSound()
			end
			onClick(b)
		end)
	end
	b.Parent = parent
	return b
end

function Kit.setEnabled(button, enabled)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundTransparency = enabled and 0 or 0.5
	button.TextTransparency = enabled and 0 or 0.4
end

function Kit.list(parent, padding, horizontal)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	l.Parent = parent
	return l
end

function Kit.grid(parent, cellSize, padding)
	local g = Instance.new("UIGridLayout")
	g.CellSize = cellSize
	g.CellPadding = UDim2.fromOffset(padding or 8, padding or 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

function Kit.scroll(parent, props)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = C.gold
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	for k, v in pairs(props or {}) do
		s[k] = v
	end
	s.Parent = parent
	return s
end

function Kit.progress(parent, fraction, color, props)
	local bar = Kit.frame(parent, { BackgroundColor3 = Color3.fromRGB(15, 15, 18), Size = UDim2.new(1, 0, 0, 10) })
	for k, v in pairs(props or {}) do
		bar[k] = v
	end
	Kit.corner(bar, 5)
	local fill = Kit.frame(bar, { BackgroundColor3 = color or C.gold, Size = UDim2.new(math.clamp(fraction or 0, 0, 1), 0, 1, 0), Name = "Fill" })
	Kit.corner(fill, 5)
	return bar, fill
end

function Kit.clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

-- A card row used in most lists.
function Kit.card(parent, height, order)
	local card = Kit.frame(parent, { BackgroundColor3 = C.panel2, Size = UDim2.new(1, -8, 0, height), LayoutOrder = order or 0 })
	Kit.corner(card, 8)
	return card
end

-- Tabs: returns container with setTab(id)
function Kit.tabs(parent, tabs, onSelect)
	local bar = Kit.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34) })
	Kit.list(bar, 6, true)
	local buttons = {}
	local function select(id)
		for tid, b in pairs(buttons) do
			b.BackgroundColor3 = tid == id and C.gold or C.panel2
			b.TextColor3 = tid == id and Color3.fromRGB(20, 20, 24) or C.text
		end
		onSelect(id)
	end
	for i, t in ipairs(tabs) do
		local b = Kit.button(bar, t.name, function()
			select(t.id)
		end, { Size = UDim2.new(0, t.width or 110, 1, 0), LayoutOrder = i, TextSize = 14, TextScaled = false }, "dark")
		buttons[t.id] = b
	end
	return bar, select
end

-- Rarity / accent pill
function Kit.pill(parent, text, color, props)
	local l = Kit.label(parent, text, { BackgroundTransparency = 0, BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Size = UDim2.fromOffset(80, 20) })
	Kit.corner(l, 10)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

return Kit
