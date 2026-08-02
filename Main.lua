-- Celestial UI Library v1.0.0
-- Optimized & Enhanced Rayfield Gen2
-- Made to work reliably with improved performance
-- Usage: loadstring(game:HttpGet("https://your-domain/celestial"))()

local Celestial = {}
Celestial.__index = Celestial

-- Services
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Config
local CONFIG = {
	DisplayOrder = 999,
	CornerRadius = UDim.new(0, 8),
	AnimationSpeed = 0.25,
	WindowMinWidth = 400,
	WindowMinHeight = 300,
}

-- Utility Functions
local function CreateTween(instance, duration, easing, properties)
	local tweenInfo = TweenInfo.new(
		duration,
		easing or Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

local function GetContrast(color)
	local r, g, b = color.R, color.G, color.B
	local brightness = (r * 299 + g * 587 + b * 114) / 1000
	return brightness > 0.5 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
end

-- ============================================================================
-- THEME
-- ============================================================================

local DefaultTheme = {
	Primary = Color3.fromRGB(66, 135, 245),
	Background = Color3.fromRGB(30, 30, 30),
	Surface = Color3.fromRGB(40, 40, 40),
	Border = Color3.fromRGB(100, 100, 100),
	Text = Color3.fromRGB(220, 220, 220),
	TextDark = Color3.fromRGB(150, 150, 150),
	Accent = Color3.fromRGB(66, 135, 245),
	Error = Color3.fromRGB(220, 53, 69),
	Success = Color3.fromRGB(40, 167, 69),
	Warn = Color3.fromRGB(255, 193, 7),
}

-- ============================================================================
-- WINDOW CLASS
-- ============================================================================

local Window = {}
Window.__index = Window

function Window.new(props)
	local self = setmetatable({}, Window)
	
	self.Name = props.Name or "Celestial Window"
	self.Size = props.Size or UDim2.fromOffset(500, 600)
	self.Theme = props.Theme or DefaultTheme
	self.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	self.Tabs = {}
	self.Elements = {}
	self.Connections = {}
	self.Hidden = false
	
	self:_build()
	return self
end

function Window:_build()
	-- Screen GUI
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = self.Name
	self.ScreenGui.DisplayOrder = CONFIG.DisplayOrder
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true
	self.ScreenGui.Parent = CoreGui
	
	-- Main Frame
	self.MainFrame = Instance.new("Frame")
	self.MainFrame.Name = "MainFrame"
	self.MainFrame.Size = self.Size
	self.MainFrame.Position = self.Position
	self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.MainFrame.BackgroundColor3 = self.Theme.Background
	self.MainFrame.BorderSizePixel = 0
	self.MainFrame.Parent = self.ScreenGui
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = CONFIG.CornerRadius
	corner.Parent = self.MainFrame
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = self.Theme.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.8
	stroke.Parent = self.MainFrame
	
	-- Title Bar
	self.TitleBar = Instance.new("Frame")
	self.TitleBar.Name = "TitleBar"
	self.TitleBar.Size = UDim2.new(1, 0, 0, 45)
	self.TitleBar.BackgroundColor3 = self.Theme.Background
	self.TitleBar.BorderSizePixel = 0
	self.TitleBar.Parent = self.MainFrame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = CONFIG.CornerRadius
	titleCorner.Parent = self.TitleBar
	
	-- Title Label
	self.TitleLabel = Instance.new("TextLabel")
	self.TitleLabel.Name = "Title"
	self.TitleLabel.Size = UDim2.new(1, -20, 1, 0)
	self.TitleLabel.Position = UDim2.new(0, 10, 0, 0)
	self.TitleLabel.BackgroundTransparency = 1
	self.TitleLabel.TextColor3 = self.Theme.Text
	self.TitleLabel.TextSize = 16
	self.TitleLabel.Font = Enum.Font.GothamBold
	self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.TitleLabel.Text = self.Name
	self.TitleLabel.Parent = self.TitleBar
	
	-- Content Area
	self.ContentFrame = Instance.new("ScrollingFrame")
	self.ContentFrame.Name = "Content"
	self.ContentFrame.Size = UDim2.new(1, 0, 1, -45)
	self.ContentFrame.Position = UDim2.new(0, 0, 0, 45)
	self.ContentFrame.BackgroundTransparency = 1
	self.ContentFrame.BorderSizePixel = 0
	self.ContentFrame.ScrollBarThickness = 4
	self.ContentFrame.ScrollBarImageColor3 = self.Theme.Border
	self.ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ContentFrame.Parent = self.MainFrame
	
	-- Content List Layout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.ContentFrame
	
	-- Make draggable
	self:_makeDraggable()
end

function Window:_makeDraggable()
	local dragging = false
	local dragStart = Vector2.new()
	
	local function onInputBegan(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		
		local mousePos = UIS:GetMouseLocation()
		local titlePos = self.TitleBar.AbsolutePosition
		local titleSize = self.TitleBar.AbsoluteSize
		
		if mousePos.X >= titlePos.X and mousePos.X <= titlePos.X + titleSize.X and
		   mousePos.Y >= titlePos.Y and mousePos.Y <= titlePos.Y + titleSize.Y then
			dragging = true
			dragStart = mousePos - self.MainFrame.AbsolutePosition
		end
	end
	
	local function onInputEnded(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end
	
	local function onMouseMove()
		if not dragging then return end
		local mousePos = UIS:GetMouseLocation()
		self.MainFrame.Position = UDim2.new(0, mousePos.X - dragStart.X, 0, mousePos.Y - dragStart.Y)
	end
	
	table.insert(self.Connections, UIS.InputBegan:Connect(onInputBegan))
	table.insert(self.Connections, UIS.InputEnded:Connect(onInputEnded))
	table.insert(self.Connections, RunService.RenderStepped:Connect(onMouseMove))
end

function Window:AddTab(name)
	local tab = {
		Name = name,
		Elements = {},
		Container = Instance.new("Frame"),
	}
	
	tab.Container.Name = name
	tab.Container.Size = UDim2.new(1, 0, 0, 0)
	tab.Container.AutomaticSize = Enum.AutomaticSize.Y
	tab.Container.BackgroundTransparency = 1
	tab.Container.Parent = self.ContentFrame
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tab.Container
	
	table.insert(self.Tabs, tab)
	return tab
end

function Window:CreateButton(tab, config)
	local button = Instance.new("TextButton")
	button.Name = config.Name or "Button"
	button.Size = UDim2.new(1, -20, 0, 40)
	button.BackgroundColor3 = self.Theme.Accent
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 14
	button.Font = Enum.Font.Gotham
	button.Text = config.Name or "Button"
	button.BorderSizePixel = 0
	button.Parent = tab.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = CONFIG.CornerRadius
	corner.Parent = button
	
	if config.Callback then
		button.MouseButton1Click:Connect(function()
			CreateTween(button, 0.1, Enum.EasingStyle.Quad, {
				BackgroundColor3 = Color3.fromRGB(56, 125, 225)
			})
			config.Callback()
			task.wait(0.1)
			CreateTween(button, 0.1, Enum.EasingStyle.Quad, {
				BackgroundColor3 = self.Theme.Accent
			})
		end)
	end
	
	return button
end

function Window:CreateToggle(tab, config)
	local container = Instance.new("Frame")
	container.Name = config.Name or "Toggle"
	container.Size = UDim2.new(1, -20, 0, 40)
	container.BackgroundColor3 = self.Theme.Surface
	container.BackgroundTransparency = 0.5
	container.BorderSizePixel = 0
	container.Parent = tab.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = CONFIG.CornerRadius
	corner.Parent = container
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -50, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = self.Theme.Text
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
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
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(1, 0)
	toggleCorner.Parent = toggleButton
	
	local isEnabled = config.Default or false
	local updateToggle = function()
		if isEnabled then
			CreateTween(toggleButton, CONFIG.AnimationSpeed, Enum.EasingStyle.Quad, {
				BackgroundColor3 = self.Theme.Accent,
				Position = UDim2.new(1, -22, 0.5, -10)
			})
		else
			CreateTween(toggleButton, CONFIG.AnimationSpeed, Enum.EasingStyle.Quad, {
				BackgroundColor3 = Color3.fromRGB(100, 100, 100),
				Position = UDim2.new(1, -40, 0.5, -10)
			})
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
	
	return {
		Container = container,
		Toggle = toggleButton,
		GetState = function() return isEnabled end
	}
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
	label.TextColor3 = self.Theme.Text
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.Text = config.Name or "Slider"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = self.Theme.Surface
	track.BorderSizePixel = 0
	track.Parent = container
	
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = CONFIG.CornerRadius
	trackCorner.Parent = track
	
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.BackgroundColor3 = self.Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = CONFIG.CornerRadius
	fillCorner.Parent = fill
	
	local value = config.Default or 50
	local min, max = config.Min or 0, config.Max or 100
	
	local updateSlider = function()
		local percent = (value - min) / (max - min)
		fill.Size = UDim2.new(percent, 0, 1, 0)
	end
	
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local mousePos = UIS:GetMouseLocation()
				local trackPos = track.AbsolutePosition.X
				local trackSize = track.AbsoluteSize.X
				
				local percent = math.clamp((mousePos.X - trackPos) / trackSize, 0, 1)
				value = math.round(min + (max - min) * percent)
				updateSlider()
				
				if config.Callback then
					config.Callback(value)
				end
			end)
			
			UIS.InputEnded:Connect(function(input2)
				if input2.UserInputType == Enum.UserInputType.MouseButton1 then
					connection:Disconnect()
				end
			end)
		end
	end)
	
	updateSlider()
	
	return {
		Container = container,
		GetValue = function() return value end
	}
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
	label.TextColor3 = self.Theme.Text
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.Text = config.Name or "Input"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, 0, 0, 20)
	inputBox.Position = UDim2.new(0, 0, 0, 20)
	inputBox.BackgroundColor3 = self.Theme.Surface
	inputBox.TextColor3 = self.Theme.Text
	inputBox.PlaceholderColor3 = self.Theme.TextDark
	inputBox.TextSize = 12
	inputBox.Font = Enum.Font.Gotham
	inputBox.BorderSizePixel = 0
	inputBox.Parent = container
	
	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = CONFIG.CornerRadius
	inputCorner.Parent = inputBox
	
	if config.Callback then
		inputBox.FocusLost:Connect(function()
			config.Callback(inputBox.Text)
		end)
	end
	
	return {
		Container = container,
		Input = inputBox,
		GetValue = function() return inputBox.Text end
	}
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
-- PUBLIC API
-- ============================================================================

function Celestial.CreateWindow(props)
	return Window.new(props)
end

function Celestial.Notify(title, message, duration)
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
	notifLabel.BorderSizePixel = 0
	notifLabel.Parent = CoreGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = CONFIG.CornerRadius
	corner.Parent = notifLabel
	
	game:GetService("Debris"):AddItem(notifLabel, duration)
end

return {
	CreateWindow = Celestial.CreateWindow,
	Notify = Celestial.Notify,
	DefaultTheme = DefaultTheme,
}
