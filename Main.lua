-- Enhanced Rayfield Gen2 v2.0.0
-- Advanced UI Library with Individual Corner Rounding & Optimizations
-- loadstring(game:HttpGet("https://your-domain.com/rayfield_gen2_enhanced"))()

local Rayfield = {}
Rayfield.__index = Rayfield

-- ============================================================================
-- CORE UTILITIES
-- ============================================================================

local CoreUtilities = {
	httpService = game:GetService("HttpService"),
	guiService = game:GetService("GuiService"),
	tweenService = game:GetService("TweenService"),
	runService = game:GetService("RunService"),
	userInputService = game:GetService("UserInputService"),
	guiContainer = game:GetService("CoreGui"),
	localPlayer = game:GetService("Players"):FindFirstChild(game:GetService("Players").LocalPlayer.Name),
}

-- ============================================================================
-- CORNER SYSTEM - WITH FALLBACK SUPPORT
-- ============================================================================

local CornerSystem = {}

function CornerSystem.supportsIndividualCorners()
	-- Check if UICorner supports individual corner properties
	local testCorner = Instance.new("UICorner")
	local supports = pcall(function()
		testCorner.TopLeftRadius = UDim.new(0, 8)
	end)
	return supports
end

function CornerSystem.applyCorners(instance, cornerConfig)
	if not instance:FindFirstChild("UICorner") then
		Instance.new("UICorner").Parent = instance
	end
	
	local corner = instance:FindFirstChild("UICorner")
	
	if CornerSystem.supportsIndividualCorners() then
		-- Use individual corners
		corner.TopLeftRadius = cornerConfig.topLeft or UDim.new(0, 8)
		corner.TopRightRadius = cornerConfig.topRight or UDim.new(0, 8)
		corner.BottomLeftRadius = cornerConfig.bottomLeft or UDim.new(0, 8)
		corner.BottomRightRadius = cornerConfig.bottomRight or UDim.new(0, 8)
	else
		-- Fallback to uniform corners
		corner.CornerRadius = cornerConfig.uniform or UDim.new(0, 8)
	end
	
	return corner
end

function CornerSystem.createPillCorners(instance)
	return CornerSystem.applyCorners(instance, {
		topLeft = UDim.new(1, 0),
		topRight = UDim.new(1, 0),
		bottomLeft = UDim.new(1, 0),
		bottomRight = UDim.new(1, 0),
		uniform = UDim.new(1, 0)
	})
end

function CornerSystem.createTopRoundedCorners(instance)
	return CornerSystem.applyCorners(instance, {
		topLeft = UDim.new(0, 12),
		topRight = UDim.new(0, 12),
		bottomLeft = UDim.new(0, 0),
		bottomRight = UDim.new(0, 0),
		uniform = UDim.new(0, 12)
	})
end

function CornerSystem.createCustomCorners(instance, config)
	return CornerSystem.applyCorners(instance, {
		topLeft = config.topLeft or UDim.new(0, 8),
		topRight = config.topRight or UDim.new(0, 8),
		bottomLeft = config.bottomLeft or UDim.new(0, 8),
		bottomRight = config.bottomRight or UDim.new(0, 8),
		uniform = config.all or UDim.new(0, 8)
	})
end

-- ============================================================================
-- OPTIMIZATION POOL SYSTEM
-- ============================================================================

local ObjectPool = {}

function ObjectPool.new(className, poolSize)
	local pool = {
		available = {},
		inUse = {},
		className = className,
		poolSize = poolSize or 50
	}
	
	for i = 1, poolSize do
		table.insert(pool.available, Instance.new(className))
	end
	
	return pool
end

function ObjectPool:acquire()
	if #self.available > 0 then
		local obj = table.remove(self.available)
		table.insert(self.inUse, obj)
		return obj
	else
		local obj = Instance.new(self.className)
		table.insert(self.inUse, obj)
		return obj
	end
end

function ObjectPool:release(obj)
	local index = table.find(self.inUse, obj)
	if index then
		table.remove(self.inUse, index)
		obj:Destroy()
		-- Don't reuse to prevent memory issues
	end
end

-- ============================================================================
-- THEME SYSTEM - ENHANCED
-- ============================================================================

local DefaultTheme = {
	-- Primary Colors
	WindowColor = Color3.fromRGB(30, 30, 30),
	ElementTransparency = 0.1,
	ElementStrokeTransparency = 0.8,
	
	-- Text Colors
	ContentColor = Color3.fromRGB(220, 220, 220),
	TitlingColor = Color3.fromRGB(255, 255, 255),
	PlaceholderColor = Color3.fromRGB(150, 150, 150),
	
	-- Interactive Elements
	AccentColor = Color3.fromRGB(66, 135, 245),
	AccentGlow = 0.7,
	ErrorColor = Color3.fromRGB(220, 53, 69),
	
	-- UI Elements
	ElementStroke = Color3.fromRGB(100, 100, 100),
	ElementStrokeHover = Color3.fromRGB(150, 150, 150),
	ElementTextHoverColor = Color3.fromRGB(255, 255, 255),
	
	-- Dropdowns & Sliders
	DropdownHighlight = Color3.fromRGB(50, 50, 50),
	SliderBackground = Color3.fromRGB(40, 40, 40),
	SliderBackgroundHover = Color3.fromRGB(50, 50, 50),
	SliderHandle = Color3.fromRGB(66, 135, 245),
	SliderProgress = Color3.fromRGB(66, 135, 245),
	SliderStroke = Color3.fromRGB(100, 100, 100),
	
	-- Fields
	FieldBackground = Color3.fromRGB(25, 25, 25),
	FieldGlow = Color3.fromRGB(66, 135, 245),
	SurfaceStroke = Color3.fromRGB(80, 80, 80),
	
	-- Utilities
	Font = Enum.Font.Gotham,
	TitleFont = Enum.Font.GothamBold,
	CornerRadius = UDim.new(0, 8),
}

-- ============================================================================
-- WINDOW CLASS - ENHANCED
-- ============================================================================

local Window = {}
Window.__index = Window

function Window.new(props)
	local self = setmetatable({}, Window)
	
	self.Name = props.Name or "Window"
	self.Size = props.Size or UDim2.fromOffset(500, 600)
	self.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	self.Theme = props.Theme or DefaultTheme
	self.Hidden = false
	self.Tabs = {}
	self.Elements = {}
	self.Connections = {}
	
	self:_buildUI()
	
	return self
end

function Window:_buildUI()
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = self.Name
	self.ScreenGui.DisplayOrder = 100
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true
	self.ScreenGui.Parent = CoreUtilities.guiContainer
	
	-- Main container
	self.MainFrame = Instance.new("Frame")
	self.MainFrame.Name = "MainFrame"
	self.MainFrame.Size = self.Size
	self.MainFrame.Position = self.Position
	self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.MainFrame.BackgroundColor3 = self.Theme.WindowColor
	self.MainFrame.BorderSizePixel = 0
	self.MainFrame.Parent = self.ScreenGui
	
	-- Apply enhanced corners
	CornerSystem.applyCorners(self.MainFrame, {
		topLeft = UDim.new(0, 12),
		topRight = UDim.new(0, 12),
		bottomLeft = UDim.new(0, 12),
		bottomRight = UDim.new(0, 12),
		uniform = UDim.new(0, 12)
	})
	
	-- Title bar
	self.TitleBar = Instance.new("Frame")
	self.TitleBar.Name = "TitleBar"
	self.TitleBar.Size = UDim2.new(1, 0, 0, 40)
	self.TitleBar.BackgroundColor3 = self.Theme.WindowColor
	self.TitleBar.BorderSizePixel = 0
	self.TitleBar.Parent = self.MainFrame
	
	CornerSystem.createTopRoundedCorners(self.TitleBar)
	
	self.TitleLabel = Instance.new("TextLabel")
	self.TitleLabel.Name = "Title"
	self.TitleLabel.Size = UDim2.new(1, -20, 1, 0)
	self.TitleLabel.Position = UDim2.new(0, 10, 0, 0)
	self.TitleLabel.BackgroundTransparency = 1
	self.TitleLabel.TextColor3 = self.Theme.TitlingColor
	self.TitleLabel.TextSize = 16
	self.TitleLabel.Font = self.Theme.TitleFont
	self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.TitleLabel.Text = self.Name
	self.TitleLabel.Parent = self.TitleBar
	
	-- Content area
	self.ContentFrame = Instance.new("ScrollingFrame")
	self.ContentFrame.Name = "Content"
	self.ContentFrame.Size = UDim2.new(1, 0, 1, -50)
	self.ContentFrame.Position = UDim2.new(0, 0, 0, 40)
	self.ContentFrame.BackgroundTransparency = 1
	self.ContentFrame.BorderSizePixel = 0
	self.ContentFrame.ScrollBarThickness = 4
	self.ContentFrame.ScrollBarImageColor3 = self.Theme.ElementStroke
	self.ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ContentFrame.Parent = self.MainFrame
	
	Instance.new("UIListLayout").Parent = self.ContentFrame
	self.ContentFrame.UIListLayout.Padding = UDim.new(0, 8)
	self.ContentFrame.UIListLayout.FillDirection = Enum.FillDirection.Vertical
	self.ContentFrame.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	self.ContentFrame.UIListLayout.LayoutOrder = 1
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = self.Theme.ElementStroke
	stroke.Thickness = 1
	stroke.Transparency = self.Theme.ElementStrokeTransparency
	stroke.Parent = self.MainFrame
end

function Window:AddTab(tabName)
	local tab = {
		Name = tabName,
		Elements = {},
		Container = Instance.new("Frame"),
	}
	
	tab.Container.Name = tabName
	tab.Container.Size = UDim2.new(1, 0, 0, 0)
	tab.Container.AutomaticSize = Enum.AutomaticSize.Y
	tab.Container.BackgroundTransparency = 1
	tab.Container.Parent = self.ContentFrame
	
	Instance.new("UIListLayout").Parent = tab.Container
	tab.Container.UIListLayout.Padding = UDim.new(0, 8)
	tab.Container.UIListLayout.FillDirection = Enum.FillDirection.Vertical
	tab.Container.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	table.insert(self.Tabs, tab)
	
	return tab
end

function Window:CreateButton(tab, config)
	local button = Instance.new("TextButton")
	button.Name = config.Name or "Button"
	button.Size = UDim2.new(1, -20, 0, 40)
	button.BackgroundColor3 = self.Theme.AccentColor
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 14
	button.Font = self.Theme.Font
	button.Text = config.Name or "Button"
	button.BorderSizePixel = 0
	button.Parent = tab.Container
	
	CornerSystem.applyCorners(button, {
		topLeft = UDim.new(0, 8),
		topRight = UDim.new(0, 8),
		bottomLeft = UDim.new(0, 8),
		bottomRight = UDim.new(0, 8),
		uniform = UDim.new(0, 8)
	})
	
	if config.Callback then
		button.MouseButton1Click:Connect(function()
			config.Callback()
		end)
	end
	
	return button
end

function Window:CreateToggle(tab, config)
	local container = Instance.new("Frame")
	container.Name = config.Name or "Toggle"
	container.Size = UDim2.new(1, -20, 0, 40)
	container.BackgroundColor3 = self.Theme.ElementStroke
	container.BackgroundTransparency = 0.8
	container.BorderSizePixel = 0
	container.Parent = tab.Container
	
	CornerSystem.applyCorners(container, {
		topLeft = UDim.new(0, 8),
		topRight = UDim.new(0, 8),
		bottomLeft = UDim.new(0, 8),
		bottomRight = UDim.new(0, 8),
		uniform = UDim.new(0, 8)
	})
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -50, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = self.Theme.ContentColor
	label.TextSize = 14
	label.Font = self.Theme.Font
	label.Text = config.Name or "Toggle"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "Toggle"
	toggleButton.Size = UDim2.fromOffset(36, 20)
	toggleButton.Position = UDim2.new(1, -40, 0.5, -10)
	toggleButton.AnchorPoint = Vector2.new(0, 0.5)
	toggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = ""
	toggleButton.Parent = container
	
	CornerSystem.createPillCorners(toggleButton)
	
	local isEnabled = config.Default or false
	local updateToggle = function()
		if isEnabled then
			toggleButton.BackgroundColor3 = self.Theme.AccentColor
			toggleButton.Position = UDim2.new(1, -22, 0.5, -10)
		else
			toggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			toggleButton.Position = UDim2.new(1, -40, 0.5, -10)
		end
	end
	
	toggleButton.MouseButton1Click:Connect(function()
		isEnabled = not isEnabled
		updateToggle()
		if config.Callback then
			config.Callback(isEnabled)
		end
	end)
	
	updateToggle()
	
	return {Container = container, Toggle = toggleButton, GetState = function() return isEnabled end}
end

function Window:CreateSlider(tab, config)
	local container = Instance.new("Frame")
	container.Name = config.Name or "Slider"
	container.Size = UDim2.new(1, -20, 0, 50)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = tab.Container
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = self.Theme.ContentColor
	label.TextSize = 12
	label.Font = self.Theme.Font
	label.Text = config.Name or "Slider"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, 0, 0, 6)
	sliderTrack.Position = UDim2.new(0, 0, 0, 24)
	sliderTrack.BackgroundColor3 = self.Theme.SliderBackground
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Parent = container
	
	CornerSystem.createPillCorners(sliderTrack)
	
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
	sliderFill.BackgroundColor3 = self.Theme.SliderProgress
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderTrack
	
	CornerSystem.createPillCorners(sliderFill)
	
	local value = config.Default or 50
	local min, max = config.Min or 0, config.Max or 100
	
	local updateSlider = function()
		local percent = (value - min) / (max - min)
		sliderFill.Size = UDim2.new(percent, 0, 1, 0)
	end
	
	sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local connection
			connection = CoreUtilities.runService.RenderStepped:Connect(function()
				local mousePos = CoreUtilities.userInputService:GetMouseLocation()
				local trackPos = sliderTrack.AbsolutePosition.X
				local trackSize = sliderTrack.AbsoluteSize.X
				
				local percent = math.clamp((mousePos.X - trackPos) / trackSize, 0, 1)
				value = math.round(min + (max - min) * percent)
				updateSlider()
				
				if config.Callback then
					config.Callback(value)
				end
			end)
			
			CoreUtilities.userInputService.InputEnded:Connect(function(input2)
				if input2.UserInputType == Enum.UserInputType.MouseButton1 then
					connection:Disconnect()
				end
			end)
		end
	end)
	
	updateSlider()
	
	return {Container = container, GetValue = function() return value end}
end

function Window:CreateInput(tab, config)
	local container = Instance.new("Frame")
	container.Name = config.Name or "Input"
	container.Size = UDim2.new(1, -20, 0, 45)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = tab.Container
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = self.Theme.ContentColor
	label.TextSize = 12
	label.Font = self.Theme.Font
	label.Text = config.Name or "Input"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, 0, 0, 20)
	inputBox.Position = UDim2.new(0, 0, 0, 20)
	inputBox.BackgroundColor3 = self.Theme.FieldBackground
	inputBox.TextColor3 = self.Theme.ContentColor
	inputBox.PlaceholderColor3 = self.Theme.PlaceholderColor
	inputBox.TextSize = 12
	inputBox.Font = self.Theme.Font
	inputBox.BorderSizePixel = 0
	inputBox.Parent = container
	
	CornerSystem.applyCorners(inputBox, {
		topLeft = UDim.new(0, 6),
		topRight = UDim.new(0, 6),
		bottomLeft = UDim.new(0, 6),
		bottomRight = UDim.new(0, 6),
		uniform = UDim.new(0, 6)
	})
	
	if config.Callback then
		inputBox.FocusLost:Connect(function()
			config.Callback(inputBox.Text)
		end)
	end
	
	return {Container = container, Input = inputBox, GetValue = function() return inputBox.Text end}
end

function Window:Show()
	self.ScreenGui.Enabled = true
	self.Hidden = false
end

function Window:Hide()
	self.ScreenGui.Enabled = false
	self.Hidden = true
end

function Window:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.ScreenGui:Destroy()
end

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

local Notifications = {}

function Notifications.notify(title, message, duration)
	duration = duration or 3
	
	local notifLabel = Instance.new("TextLabel")
	notifLabel.Size = UDim2.new(0, 300, 0, 60)
	notifLabel.Position = UDim2.fromOffset(10, 10)
	notifLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	notifLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	notifLabel.TextSize = 14
	notifLabel.Font = Enum.Font.Gotham
	notifLabel.Text = title .. "\n" .. message
	notifLabel.TextWrapped = true
	notifLabel.TextScaled = true
	notifLabel.BorderSizePixel = 0
	notifLabel.Parent = CoreUtilities.guiContainer
	
	CornerSystem.applyCorners(notifLabel, {
		topLeft = UDim.new(0, 8),
		topRight = UDim.new(0, 8),
		bottomLeft = UDim.new(0, 8),
		bottomRight = UDim.new(0, 8),
		uniform = UDim.new(0, 8)
	})
	
	game:GetService("Debris"):AddItem(notifLabel, duration)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function Rayfield.CreateWindow(props)
	return Window.new(props)
end

function Rayfield.Notify(title, message, duration)
	Notifications.notify(title, message, duration)
end

-- Export
return {
	CreateWindow = Rayfield.CreateWindow,
	Notify = Rayfield.Notify,
	CornerSystem = CornerSystem,
	Theme = DefaultTheme,
}
