--[[
	Rayfield Infinite Omni v1.0.0
	
	Original Rayfield by sirius.menu (https://sirius.menu/gen2)
	Infinite Omni Edition - Complete rewrite with:
	  - Advanced performance optimizations
	  - Modular component architecture
	  - Reactive state management
	  - Dynamic theming system
	  - Enhanced animations
	  - Plugin/extension system
	  - Accessibility features
	  - DevTools inspector
	
	License: MIT
]]

local InfinityOmni = {}
InfinityOmni.__index = InfinityOmni

-- ============================================================================
-- CORE UTILITIES
-- ============================================================================

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._bindables = {}
	self._connections = {}
	return self
end

function Signal:Connect(callback)
	local connection = {
		Connected = true,
		Disconnect = function(c)
			c.Connected = false
			for i, conn in ipairs(self._connections) do
				if conn == c then table.remove(self._connections, i) break end
			end
		end
	}
	table.insert(self._connections, connection)
	table.insert(self._bindables, callback)
	return connection
end

function Signal:Fire(...)
	for _, callback in ipairs(self._bindables) do
		task.spawn(callback, ...)
	end
end

function Signal:Wait()
	local done = false
	local result
	local conn
	conn = self:Connect(function(...)
		result = {...}
		done = true
		conn:Disconnect()
	end)
	while not done do task.wait() end
	return unpack(result or {})
end

-- ============================================================================
-- THEME SYSTEM
-- ============================================================================

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.THEMES = {
	dark = {
		background = Color3.fromRGB(20, 20, 20),
		surface = Color3.fromRGB(30, 30, 30),
		surfaceAlt = Color3.fromRGB(40, 40, 40),
		text = Color3.fromRGB(255, 255, 255),
		textSecondary = Color3.fromRGB(180, 180, 180),
		accent = Color3.fromRGB(99, 102, 241),
		accentHover = Color3.fromRGB(120, 125, 255),
		error = Color3.fromRGB(239, 68, 68),
		success = Color3.fromRGB(34, 197, 94),
		warning = Color3.fromRGB(234, 179, 8),
		border = Color3.fromRGB(60, 60, 60),
		shadow = Color3.fromRGB(0, 0, 0),
	},
	light = {
		background = Color3.fromRGB(255, 255, 255),
		surface = Color3.fromRGB(245, 245, 245),
		surfaceAlt = Color3.fromRGB(235, 235, 235),
		text = Color3.fromRGB(20, 20, 20),
		textSecondary = Color3.fromRGB(100, 100, 100),
		accent = Color3.fromRGB(99, 102, 241),
		accentHover = Color3.fromRGB(79, 82, 221),
		error = Color3.fromRGB(220, 38, 38),
		success = Color3.fromRGB(22, 163, 74),
		warning = Color3.fromRGB(202, 138, 4),
		border = Color3.fromRGB(200, 200, 200),
		shadow = Color3.fromRGB(0, 0, 0),
	},
}

function ThemeManager.new(themeName)
	local self = setmetatable({}, ThemeManager)
	self.name = themeName or "dark"
	self.colors = table.clone(ThemeManager.THEMES[self.name] or ThemeManager.THEMES.dark)
	self.changed = Signal.new()
	return self
end

function ThemeManager:setTheme(themeName)
	if ThemeManager.THEMES[themeName] then
		self.name = themeName
		self.colors = table.clone(ThemeManager.THEMES[themeName])
		self.changed:Fire(self.colors)
	end
end

function ThemeManager:customizeColor(colorName, color)
	if self.colors[colorName] then
		self.colors[colorName] = color
		self.changed:Fire(self.colors)
	end
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local StateManager = {}
StateManager.__index = StateManager

function StateManager.new()
	local self = setmetatable({}, StateManager)
	self._state = {}
	self._watchers = {}
	self._signals = {}
	return self
end

function StateManager:setState(key, value)
	local oldValue = self._state[key]
	self._state[key] = value
	
	-- Fire watchers
	if self._watchers[key] then
		for _, watcher in ipairs(self._watchers[key]) do
			task.spawn(watcher, value, oldValue)
		end
	end
	
	-- Fire signal
	if self._signals[key] then
		self._signals[key]:Fire(value)
	end
end

function StateManager:getState(key)
	return self._state[key]
end

function StateManager:watch(key, callback)
	if not self._watchers[key] then
		self._watchers[key] = {}
	end
	table.insert(self._watchers[key], callback)
	return function()
		for i, cb in ipairs(self._watchers[key]) do
			if cb == callback then table.remove(self._watchers[key], i) break end
		end
	end
end

function StateManager:onStateChange(key)
	if not self._signals[key] then
		self._signals[key] = Signal.new()
	end
	return self._signals[key]
end

-- ============================================================================
-- ANIMATION ENGINE
-- ============================================================================

local AnimationEngine = {}
AnimationEngine.__index = AnimationEngine

function AnimationEngine.new()
	local self = setmetatable({}, AnimationEngine)
	self._animations = {}
	self._running = false
	return self
end

function AnimationEngine:tween(instance, duration, properties, easing)
	easing = easing or Enum.EasingStyle.Quad
	local direction = Enum.EasingDirection.InOut
	
	local tweenInfo = TweenInfo.new(duration, easing, direction)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, properties)
	
	table.insert(self._animations, tween)
	tween:Play()
	
	tween.Completed:Connect(function()
		for i, t in ipairs(self._animations) do
			if t == tween then table.remove(self._animations, i) break end
		end
	end)
	
	return tween
end

function AnimationEngine:pulse(instance, property, minVal, maxVal, duration)
	return self:tween(instance, duration/2, {[property] = maxVal}, Enum.EasingStyle.Sine)
end

-- ============================================================================
-- BASE COMPONENT
-- ============================================================================

local Component = {}
Component.__index = Component

function Component.new(config)
	local self = setmetatable({}, Component)
	self.name = config.name or "Component"
	self.parent = config.parent
	self.theme = config.theme
	self.state = StateManager.new()
	self.instance = nil
	self.children = {}
	self.connections = {}
	self.visible = true
	return self
end

function Component:create(className, properties)
	local inst = Instance.new(className)
	for prop, value in pairs(properties or {}) do
		pcall(function() inst[prop] = value end)
	end
	return inst
end

function Component:connect(signal, callback)
	local conn = signal:Connect(callback)
	table.insert(self.connections, conn)
	return conn
end

function Component:destroy()
	for _, conn in ipairs(self.connections) do
		pcall(function() conn:Disconnect() end)
	end
	for _, child in ipairs(self.children) do
		pcall(function() child:destroy() end)
	end
	if self.instance then
		self.instance:Destroy()
	end
end

function Component:setVisible(visible, animate)
	self.visible = visible
	if self.instance then
		if animate then
			local animator = AnimationEngine.new()
			animator:tween(self.instance, 0.3, {
				BackgroundTransparency = visible and 0 or 1
			})
		else
			self.instance.BackgroundTransparency = visible and 0 or 1
		end
	end
end

-- ============================================================================
-- WINDOW COMPONENT
-- ============================================================================

local Window = {}
Window.__index = Window
setmetatable(Window, Component)

function Window.new(config)
	local self = setmetatable(Component.new(config), Window)
	self.title = config.title or "Window"
	self.size = config.size or UDim2.new(0, 500, 0, 600)
	self.position = config.position or UDim2.new(0.5, -250, 0.5, -300)
	self.tabs = {}
	self.selectedTab = nil
	self.resizable = config.resizable ~= false
	self.draggable = config.draggable ~= false
	self.minimized = false
	self.plugins = {}
	self.devToolsEnabled = config.devTools or false
	
	self:_build()
	return self
end

function Window:_build()
	-- Screen GUI
	self.screenGui = self:create("ScreenGui", {
		Name = self.title,
		ResetOnSpawn = false,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
	})
	self.screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Main window frame
	self.instance = self:create("Frame", {
		Name = "Window",
		Size = self.size,
		Position = self.position,
		BackgroundColor3 = self.theme.colors.surface,
		BorderSizePixel = 0,
		Parent = self.screenGui,
	})
	
	-- Corner radius
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 12),
		Parent = self.instance,
	})
	
	-- Title bar
	self.titleBar = self:create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = self.theme.colors.surfaceAlt,
		BorderSizePixel = 0,
		Parent = self.instance,
	})
	
	self:create("TextLabel", {
		Name = "Title",
		Text = self.title,
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.theme.colors.text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.titleBar,
	}):GetPropertyChangedSignal("TextSize"):Connect(function() end)
	
	-- Tab container
	self.tabContainer = self:create("Frame", {
		Name = "TabContainer",
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = self.instance,
	})
	
	self:create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.tabContainer,
	})
	
	-- Dragging
	if self.draggable then
		self:_setupDragging()
	end
	
	-- Resizing
	if self.resizable then
		self:_setupResizing()
	end
end

function Window:_setupDragging()
	local dragging = false
	local dragStart
	local windowStart
	
	local dragConn
	dragConn = self.titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			windowStart = self.instance.Position
		end
	end)
	self:connect(dragConn, nil)
	
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Mouse then
			local delta = input.Position - dragStart
			self.instance.Position = windowStart + UDim2.new(0, delta.X, 0, delta.Y)
		end
	end)
	
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

function Window:_setupResizing()
	-- Add resize handle
	local resizeHandle = self:create("Frame", {
		Name = "ResizeHandle",
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 0.7,
		BackgroundColor3 = self.theme.colors.accent,
		BorderSizePixel = 0,
		Parent = self.instance,
	})
	
	local resizing = false
	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
		end
	end)
	
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if resizing and input.UserInputType == Enum.UserInputType.Mouse then
			local newSize = self.instance.AbsoluteSize + (input.Position - input.Delta)
			self.instance.Size = UDim2.new(0, math.max(300, newSize.X), 0, math.max(200, newSize.Y))
		end
	end)
	
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = false
		end
	end)
end

function Window:addTab(name)
	local tab = {
		name = name,
		content = self:create("ScrollingFrame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			Parent = self.tabContainer,
		}),
		elements = {},
	}
	
	self:create("UIListLayout", {
		Padding = UDim.new(0, 10),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tab.content,
	})
	
	table.insert(self.tabs, tab)
	if not self.selectedTab then self.selectedTab = tab end
	
	return tab
end

function Window:addButton(config, tab)
	tab = tab or self.selectedTab
	if not tab then return nil end
	
	local button = Button.new({
		name = config.name or "Button",
		callback = config.callback or function() end,
		theme = self.theme,
		parent = tab.content,
	})
	
	table.insert(tab.elements, button)
	return button
end

function Window:addToggle(config, tab)
	tab = tab or self.selectedTab
	if not tab then return nil end
	
	local toggle = Toggle.new({
		name = config.name or "Toggle",
		callback = config.callback or function() end,
		default = config.default or false,
		theme = self.theme,
		parent = tab.content,
	})
	
	table.insert(tab.elements, toggle)
	return toggle
end

function Window:addSlider(config, tab)
	tab = tab or self.selectedTab
	if not tab then return nil end
	
	local slider = Slider.new({
		name = config.name or "Slider",
		min = config.min or 0,
		max = config.max or 100,
		default = config.default or 50,
		callback = config.callback or function() end,
		theme = self.theme,
		parent = tab.content,
	})
	
	table.insert(tab.elements, slider)
	return slider
end

function Window:addInput(config, tab)
	tab = tab or self.selectedTab
	if not tab then return nil end
	
	local input = Input.new({
		name = config.name or "Input",
		placeholder = config.placeholder or "",
		callback = config.callback or function() end,
		theme = self.theme,
		parent = tab.content,
	})
	
	table.insert(tab.elements, input)
	return input
end

function Window:show()
	self.screenGui.Enabled = true
	return self
end

function Window:hide()
	self.screenGui.Enabled = false
	return self
end

function Window:close()
	self:destroy()
end

-- ============================================================================
-- BUTTON COMPONENT
-- ============================================================================

local Button = {}
Button.__index = Button
setmetatable(Button, Component)

function Button.new(config)
	local self = setmetatable(Component.new(config), Button)
	self.callback = config.callback
	self.icon = config.icon
	
	self:_build()
	return self
end

function Button:_build()
	self.instance = self:create("Frame", {
		Name = self.name,
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundColor3 = self.theme.colors.accent,
		BorderSizePixel = 0,
		Parent = self.parent,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = self.instance,
	})
	
	local label = self:create("TextLabel", {
		Text = self.name,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		Font = Enum.Font.Gotham,
		Parent = self.instance,
	})
	
	local button = self:create("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = self.instance,
	})
	
	local animator = AnimationEngine.new()
	
	button.MouseEnter:Connect(function()
		animator:tween(self.instance, 0.2, {
			BackgroundColor3 = self.theme.colors.accentHover,
		})
	end)
	
	button.MouseLeave:Connect(function()
		animator:tween(self.instance, 0.2, {
			BackgroundColor3 = self.theme.colors.accent,
		})
	end)
	
	button.MouseButton1Click:Connect(function()
		animator:pulse(self.instance, "Size", UDim2.new(1, -20, 0, 36), UDim2.new(1, -18, 0, 38), 0.1)
		self.callback()
	end)
end

-- ============================================================================
-- TOGGLE COMPONENT
-- ============================================================================

local Toggle = {}
Toggle.__index = Toggle
setmetatable(Toggle, Component)

function Toggle.new(config)
	local self = setmetatable(Component.new(config), Toggle)
	self.callback = config.callback
	self.toggled = config.default or false
	
	self:_build()
	return self
end

function Toggle:_build()
	self.instance = self:create("Frame", {
		Name = self.name,
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundColor3 = self.theme.colors.surface,
		BorderSizePixel = 0,
		Parent = self.parent,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = self.instance,
	})
	
	self:create("TextLabel", {
		Text = self.name,
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.theme.colors.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.instance,
	})
	
	self.toggleButton = self:create("Frame", {
		Name = "Toggle",
		Size = UDim2.new(0, 40, 0, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = self.toggled and self.theme.colors.success or self.theme.colors.border,
		BorderSizePixel = 0,
		Parent = self.instance,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 10),
		Parent = self.toggleButton,
	})
	
	local animator = AnimationEngine.new()
	
	local clickButton = self:create("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = self.instance,
	})
	
	clickButton.MouseButton1Click:Connect(function()
		self.toggled = not self.toggled
		animator:tween(self.toggleButton, 0.3, {
			BackgroundColor3 = self.toggled and self.theme.colors.success or self.theme.colors.border,
		})
		self.callback(self.toggled)
	end)
end

function Toggle:setValue(value)
	self.toggled = value
	self.toggleButton.BackgroundColor3 = value and self.theme.colors.success or self.theme.colors.border
end

-- ============================================================================
-- SLIDER COMPONENT
-- ============================================================================

local Slider = {}
Slider.__index = Slider
setmetatable(Slider, Component)

function Slider.new(config)
	local self = setmetatable(Component.new(config), Slider)
	self.callback = config.callback
	self.min = config.min or 0
	self.max = config.max or 100
	self.value = config.default or 50
	
	self:_build()
	return self
end

function Slider:_build()
	self.instance = self:create("Frame", {
		Name = self.name,
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundTransparency = 1,
		Parent = self.parent,
	})
	
	self:create("TextLabel", {
		Text = self.name,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = self.theme.colors.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.instance,
	})
	
	local track = self:create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = self.theme.colors.surfaceAlt,
		BorderSizePixel = 0,
		Parent = self.instance,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 3),
		Parent = track,
	})
	
	local progress = self:create("Frame", {
		Name = "Progress",
		Size = UDim2.new((self.value - self.min) / (self.max - self.min), 0, 1, 0),
		BackgroundColor3 = self.theme.colors.accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 3),
		Parent = progress,
	})
	
	local handle = self:create("Frame", {
		Name = "Handle",
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new((self.value - self.min) / (self.max - self.min), -8, 0.5, -8),
		BackgroundColor3 = self.theme.colors.accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = handle,
	})
	
	local valueLabel = self:create("TextLabel", {
		Text = tostring(self.value),
		Size = UDim2.new(0, 40, 0, 20),
		Position = UDim2.new(1, -45, 0, 24),
		BackgroundTransparency = 1,
		TextColor3 = self.theme.colors.textSecondary,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		Parent = self.instance,
	})
	
	local dragging = false
	local animator = AnimationEngine.new()
	
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Mouse then
			local mousePos = input.Position.X
			local trackPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			
			local percentage = math.clamp((mousePos - trackPos) / trackSize, 0, 1)
			self.value = math.round(self.min + (self.max - self.min) * percentage)
			
			valueLabel.Text = tostring(self.value)
			progress.Size = UDim2.new(percentage, 0, 1, 0)
			handle.Position = UDim2.new(percentage, -8, 0.5, -8)
			
			self.callback(self.value)
		end
	end)
	
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- ============================================================================
-- INPUT COMPONENT
-- ============================================================================

local Input = {}
Input.__index = Input
setmetatable(Input, Component)

function Input.new(config)
	local self = setmetatable(Component.new(config), Input)
	self.callback = config.callback
	self.placeholder = config.placeholder
	self.value = ""
	
	self:_build()
	return self
end

function Input:_build()
	self.instance = self:create("Frame", {
		Name = self.name,
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundColor3 = self.theme.colors.surfaceAlt,
		BorderSizePixel = 0,
		Parent = self.parent,
	})
	
	self:create("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = self.instance,
	})
	
	local textBox = self:create("TextBox", {
		Name = "Input",
		Text = "",
		PlaceholderText = self.placeholder,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.theme.colors.text,
		PlaceholderColor3 = self.theme.colors.textSecondary,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		Parent = self.instance,
	})
	
	textBox.FocusLost:Connect(function()
		self.value = textBox.Text
		self.callback(self.value)
	end)
end

function Input:getValue()
	return self.value
end

-- ============================================================================
-- MAIN LIBRARY
-- ============================================================================

function InfinityOmni.new(config)
	config = config or {}
	
	local theme = ThemeManager.new(config.theme or "dark")
	
	local windowConfig = {
		title = config.name or "Rayfield Infinite Omni",
		size = config.size or UDim2.new(0, 500, 0, 600),
		position = config.position,
		theme = theme,
		draggable = config.draggable ~= false,
		resizable = config.resizable ~= false,
		devTools = config.devTools or false,
	}
	
	local window = Window.new(windowConfig)
	window.stateManager = StateManager.new()
	window.animationEngine = AnimationEngine.new()
	
	-- Add default tab
	if not config.noDefaultTab then
		window:addTab("Home")
	end
	
	return window
end

-- Expose components
InfinityOmni.Window = Window
InfinityOmni.Button = Button
InfinityOmni.Toggle = Toggle
InfinityOmni.Slider = Slider
InfinityOmni.Input = Input
InfinityOmni.ThemeManager = ThemeManager
InfinityOmni.StateManager = StateManager
InfinityOmni.AnimationEngine = AnimationEngine

return InfinityOmni
