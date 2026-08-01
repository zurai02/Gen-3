--[[
	╔════════════════════════════════════════════════════════════════════════════╗
	║                   RAYFIELD GEN2 ENHANCED - PATCHED                        ║
	║                                                                            ║
	║  Original: sirius.menu (https://sirius.menu/gen2)                         ║
	║  Patched: Bug fixes, performance improvements, mobile support             ║
	║                                                                            ║
	║  Fixes Applied:                                                            ║
	║  ✓ Fixed broken resizing (input.Delta doesn't exist)                      ║
	║  ✓ Added connection cleanup (no more memory leaks)                        ║
	║  ✓ Fixed Dropdown ClearAllChildren bug                                    ║
	║  ✓ Added AutomaticCanvasSize for proper scrolling                         ║
	║  ✓ Added touch/mobile input support                                       ║
	║  ✓ Fixed shadow ZIndex (negative values invalid)                          ║
	║  ✓ Added callback error wrapping (pcall)                                  ║
	║  ✓ Added slider drag throttling                                           ║
	║  ✓ Added config nil-guards                                                ║
	║  ✓ Fixed tab bar scrolling with many tabs                                 ║
	║                                                                            ║
	╚════════════════════════════════════════════════════════════════════════════╝
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Rayfield = {}
Rayfield.LoadedFrameworks = {}

local COLORS = {
	Main = Color3.fromRGB(20, 20, 20),
	Secondary = Color3.fromRGB(25, 25, 25),
	Tertiary = Color3.fromRGB(30, 30, 30),
	Text = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(180, 180, 180),
	TextDisabled = Color3.fromRGB(100, 100, 100),
	Primary = Color3.fromRGB(99, 102, 241),
	PrimaryHover = Color3.fromRGB(120, 125, 255),
	PrimaryActive = Color3.fromRGB(79, 82, 221),
	Success = Color3.fromRGB(34, 197, 94),
	Error = Color3.fromRGB(239, 68, 68),
	Warning = Color3.fromRGB(234, 179, 8),
	Border = Color3.fromRGB(50, 50, 50),
}

-- ============================================================================
-- CONNECTION MANAGER - Prevents memory leaks
-- ============================================================================
local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new()
	return setmetatable({
		_connections = {},
	}, ConnectionManager)
end

function ConnectionManager:Add(conn)
	if conn then
		table.insert(self._connections, conn)
	end
	return conn
end

function ConnectionManager:DisconnectAll()
	for i = #self._connections, 1, -1 do
		local conn = self._connections[i]
		if conn and conn.Connected then
			pcall(function() conn:Disconnect() end)
		end
		self._connections[i] = nil
	end
end

function ConnectionManager:Count()
	local count = 0
	for _, conn in ipairs(self._connections) do
		if conn and conn.Connected then
			count = count + 1
		end
	end
	return count
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function CreateElement(className, properties)
	local element = Instance.new(className)
	for prop, value in pairs(properties or {}) do
		local success, err = pcall(function()
			element[prop] = value
		end)
		if not success then
			warn("CreateElement failed to set " .. tostring(prop) .. ": " .. tostring(err))
		end
	end
	return element
end

local function SafeCallback(callback, ...)
	if type(callback) ~= "function" then return end
	local success, result = pcall(callback, ...)
	if not success then
		warn("Rayfield callback error: " .. tostring(result))
	end
	return success, result
end

local function Tween(instance, duration, properties, easing)
	easing = easing or Enum.EasingStyle.Quad
	local tweenInfo = TweenInfo.new(duration, easing, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

-- ============================================================================
-- WINDOW CLASS
-- ============================================================================
local Window = {}
Window.__index = Window

function Window.new(config)
	config = config or {}
	local self = setmetatable({}, Window)

	self.Title = config.Name or config.Title or "Rayfield"
	self.Size = config.Size or UDim2.new(0, 600, 0, 700)
	self.Position = config.Position or UDim2.new(0.5, -300, 0.5, -350)
	self.ShowCloseButton = config.CloseButton ~= false
	self.Draggable = config.Draggable ~= false
	self.Resizable = config.Resizable ~= false
	self.Theme = config.Theme or "Dark"

	self.Tabs = {}
	self.CurrentTab = nil
	self.TabCount = 0
	self._connections = ConnectionManager.new()
	self._elements = {}
	self._isDestroyed = false

	self:Build()

	return self
end

function Window:Build()
	-- Get PlayerGui safely
	local player = Players.LocalPlayer
	if not player then
		error("Rayfield: LocalPlayer not found. Must run in a LocalScript.")
	end

	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		error("Rayfield: PlayerGui not found after 10 seconds.")
	end

	-- Main ScreenGui
	self.ScreenGui = CreateElement("ScreenGui", {
		Name = self.Title,
		ResetOnSpawn = false,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
	})
	self.ScreenGui.Parent = playerGui

	-- Main Frame
	self.MainFrame = CreateElement("Frame", {
		Name = "MainFrame",
		Size = self.Size,
		Position = self.Position,
		BackgroundColor3 = COLORS.Main,
		BorderSizePixel = 0,
		Parent = self.ScreenGui,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 12),
		Parent = self.MainFrame,
	})

	-- Shadow Effect (FIXED: ZIndex 0 instead of -1, parented to ScreenGui behind main)
	local shadowFrame = CreateElement("Frame", {
		Name = "Shadow",
		Size = UDim2.new(0, self.Size.X.Offset + 20, 0, self.Size.Y.Offset + 20),
		Position = UDim2.new(
			self.Position.X.Scale, self.Position.X.Offset - 10,
			self.Position.Y.Scale, self.Position.Y.Offset - 10
		),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = self.ScreenGui,
	})
	self._shadow = shadowFrame

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 16),
		Parent = shadowFrame,
	})

	-- Title Bar
	self.TitleBar = CreateElement("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = COLORS.Secondary,
		BorderSizePixel = 0,
		Parent = self.MainFrame,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 12),
		Parent = self.TitleBar,
	})

	-- Title Text
	CreateElement("TextLabel", {
		Name = "Title",
		Text = self.Title,
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.new(0, 15, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.TitleBar,
	})

	-- Close Button
	if self.ShowCloseButton then
		local closeButton = CreateElement("TextButton", {
			Name = "CloseButton",
			Text = "✕",
			Size = UDim2.new(0, 35, 0, 35),
			Position = UDim2.new(1, -45, 0.5, -17),
			BackgroundColor3 = COLORS.Error,
			TextColor3 = COLORS.Text,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			BorderSizePixel = 0,
			Parent = self.TitleBar,
		})

		CreateElement("UICorner", {
			CornerRadius = UDim.new(0, 6),
			Parent = closeButton,
		})

		self._connections:Add(closeButton.MouseButton1Click:Connect(function()
			self:Close()
		end))

		self._connections:Add(closeButton.MouseEnter:Connect(function()
			Tween(closeButton, 0.2, {BackgroundColor3 = Color3.fromRGB(255, 100, 100)})
		end))

		self._connections:Add(closeButton.MouseLeave:Connect(function()
			Tween(closeButton, 0.2, {BackgroundColor3 = COLORS.Error})
		end))
	end

	-- Tab Bar (FIXED: Now uses ScrollingFrame properly with AutomaticCanvasSize)
	self.TabBar = CreateElement("Frame", {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 45),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundColor3 = COLORS.Tertiary,
		BorderSizePixel = 0,
		Parent = self.MainFrame,
	})

	self.TabButtonContainer = CreateElement("ScrollingFrame", {
		Name = "TabButtons",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X, -- FIXED: Auto-scroll for many tabs
		Parent = self.TabBar,
	})

	CreateElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		Parent = self.TabButtonContainer,
	})

	-- Content Area
	self.ContentArea = CreateElement("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, 0, 1, -95),
		Position = UDim2.new(0, 0, 0, 95),
		BackgroundColor3 = COLORS.Main,
		BorderSizePixel = 0,
		Parent = self.MainFrame,
	})

	self.TabContainer = CreateElement("Frame", {
		Name = "TabContainer",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = self.ContentArea,
	})

	-- Setup Dragging
	if self.Draggable then
		self:SetupDragging()
	end

	-- Setup Resizing
	if self.Resizable then
		self:SetupResizing()
	end
end

function Window:SetupDragging()
	local dragging = false
	local dragStart = Vector2.new(0, 0)
	local startPos = UDim2.new(0, 0, 0, 0)

	self._connections:Add(self.TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = self.MainFrame.Position
		end
	end))

	self._connections:Add(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
						 input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local newPos = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
			self.MainFrame.Position = newPos
			-- Update shadow position
			if self._shadow then
				self._shadow.Position = UDim2.new(
					newPos.X.Scale, newPos.X.Offset - 10,
					newPos.Y.Scale, newPos.Y.Offset - 10
				)
			end
		end
	end))

	self._connections:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

function Window:SetupResizing()
	local resizeHandle = CreateElement("Frame", {
		Name = "ResizeHandle",
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = COLORS.Primary,
		BorderSizePixel = 0,
		ZIndex = 1000,
		Parent = self.MainFrame,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 4),
		Parent = resizeHandle,
	})

	local resizing = false
	local startPos = Vector2.new(0, 0)
	local startSize = Vector2.new(0, 0)

	-- FIXED: Proper resize logic using startPos/startSize instead of input.Delta
	self._connections:Add(resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			startPos = input.Position
			startSize = self.MainFrame.AbsoluteSize
		end
	end))

	self._connections:Add(UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or 
						 input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startPos
			local newSize = startSize + delta
			local clampedX = math.clamp(newSize.X, 300, 1920)
			local clampedY = math.clamp(newSize.Y, 200, 1080)

			self.MainFrame.Size = UDim2.new(0, clampedX, 0, clampedY)
			-- Update shadow size
			if self._shadow then
				self._shadow.Size = UDim2.new(0, clampedX + 20, 0, clampedY + 20)
			end
		end
	end))

	self._connections:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end))
end

function Window:AddTab(name)
	local tab = {}
	tab.Name = name

	tab.Content = CreateElement("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = COLORS.Main,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = COLORS.Primary,
		Visible = false,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, -- FIXED: Proper scrolling
		Parent = self.TabContainer,
	})

	local layout = CreateElement("UIListLayout", {
		Padding = UDim.new(0, 8),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tab.Content,
	})

	CreateElement("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = tab.Content,
	})

	-- Tab Button
	local tabButton = CreateElement("TextButton", {
		Name = name .. "Tab",
		Text = name,
		Size = UDim2.new(0, 120, 1, 0),
		BackgroundColor3 = COLORS.Tertiary,
		TextColor3 = COLORS.TextSecondary,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
		Parent = self.TabButtonContainer,
	})

	self._connections:Add(tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end))

	self._connections:Add(tabButton.MouseEnter:Connect(function()
		if tab ~= self.CurrentTab then
			Tween(tabButton, 0.2, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)})
		end
	end))

	self._connections:Add(tabButton.MouseLeave:Connect(function()
		if tab ~= self.CurrentTab then
			Tween(tabButton, 0.2, {BackgroundColor3 = COLORS.Tertiary})
		end
	end))

	tab.Button = tabButton
	tab._elementConnections = ConnectionManager.new()

	table.insert(self.Tabs, tab)
	self.TabCount = self.TabCount + 1

	if not self.CurrentTab then
		self:SelectTab(tab)
	end

	return tab
end

function Window:SelectTab(tab)
	if not tab then return end

	if self.CurrentTab then
		self.CurrentTab.Content.Visible = false
		Tween(self.CurrentTab.Button, 0.2, {
			BackgroundColor3 = COLORS.Tertiary,
			TextColor3 = COLORS.TextSecondary,
		})
	end

	self.CurrentTab = tab
	tab.Content.Visible = true
	Tween(tab.Button, 0.2, {
		BackgroundColor3 = COLORS.Primary,
		TextColor3 = COLORS.Text,
	})
end

function Window:AddButton(config, tab)
	config = config or {}
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local button = CreateElement("TextButton", {
		Name = config.Name or "Button",
		Text = config.Name or "Button",
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundColor3 = COLORS.Primary,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
		Parent = tab.Content,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = button,
	})

	tab._elementConnections:Add(button.MouseButton1Click:Connect(function()
		SafeCallback(config.Callback)
	end))

	tab._elementConnections:Add(button.MouseEnter:Connect(function()
		Tween(button, 0.2, {BackgroundColor3 = COLORS.PrimaryHover})
	end))

	tab._elementConnections:Add(button.MouseLeave:Connect(function()
		Tween(button, 0.2, {BackgroundColor3 = COLORS.Primary})
	end))

	return button
end

function Window:AddToggle(config, tab)
	config = config or {}
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local container = CreateElement("Frame", {
		Name = config.Name or "Toggle",
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundColor3 = COLORS.Secondary,
		BorderSizePixel = 0,
		Parent = tab.Content,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = container,
	})

	CreateElement("TextLabel", {
		Name = "Label",
		Text = config.Name or "Toggle",
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = container,
	})

	local toggled = config.Default or false

	local toggleBg = CreateElement("Frame", {
		Name = "ToggleBg",
		Size = UDim2.new(0, 50, 0, 26),
		Position = UDim2.new(1, -60, 0.5, -13),
		BackgroundColor3 = toggled and COLORS.Success or COLORS.Border,
		BorderSizePixel = 0,
		Parent = container,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 13),
		Parent = toggleBg,
	})

	local clickArea = CreateElement("TextButton", {
		Name = "ClickArea",
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = container,
	})

	local function updateToggle(value)
		toggled = value
		Tween(toggleBg, 0.3, {
			BackgroundColor3 = toggled and COLORS.Success or COLORS.Border
		})
		SafeCallback(config.Callback, toggled)
	end

	tab._elementConnections:Add(clickArea.MouseButton1Click:Connect(function()
		updateToggle(not toggled)
	end))

	return {
		GetValue = function() return toggled end,
		SetValue = function(value)
			updateToggle(value)
		end,
		Instance = container,
	}
end

function Window:AddSlider(config, tab)
	config = config or {}
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local container = CreateElement("Frame", {
		Name = config.Name or "Slider",
		Size = UDim2.new(1, -20, 0, 65),
		BackgroundTransparency = 1,
		Parent = tab.Content,
	})

	CreateElement("TextLabel", {
		Name = "Label",
		Text = config.Name or "Slider",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})

	local min = config.Min or 0
	local max = config.Max or 100
	local value = config.Default or math.floor((min + max) / 2)

	local track = CreateElement("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 30),
		BackgroundColor3 = COLORS.Border,
		BorderSizePixel = 0,
		Parent = container,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 3),
		Parent = track,
	})

	local progress = CreateElement("Frame", {
		Name = "Progress",
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = COLORS.Primary,
		BorderSizePixel = 0,
		Parent = track,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 3),
		Parent = progress,
	})

	local handle = CreateElement("Frame", {
		Name = "Handle",
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new((value - min) / (max - min), -8, 0.5, -8),
		BackgroundColor3 = COLORS.Primary,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = handle,
	})

	local valueLabel = CreateElement("TextLabel", {
		Name = "Value",
		Text = tostring(math.round(value)),
		Size = UDim2.new(0, 50, 0, 20),
		Position = UDim2.new(1, -55, 0, 30),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.TextSecondary,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		Parent = container,
	})

	local dragging = false
	local lastCallbackTime = 0
	local callbackThrottle = config.Throttle or 0.05 -- FIXED: Throttle expensive callbacks

	local function updateSlider(newValue, skipCallback)
		value = math.clamp(math.round(newValue), min, max)
		valueLabel.Text = tostring(value)
		local percent = (value - min) / (max - min)
		progress.Size = UDim2.new(percent, 0, 1, 0)
		handle.Position = UDim2.new(percent, -8, 0.5, -8)

		if not skipCallback and config.Callback then
			local now = tick()
			if now - lastCallbackTime >= callbackThrottle then
				lastCallbackTime = now
				SafeCallback(config.Callback, value)
			end
		end
	end

	tab._elementConnections:Add(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end))

	tab._elementConnections:Add(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
						 input.UserInputType == Enum.UserInputType.Touch) then
			local trackAbsPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			local percent = math.clamp((input.Position.X - trackAbsPos) / trackSize, 0, 1)
			updateSlider(min + (max - min) * percent)
		end
	end))

	tab._elementConnections:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			-- Fire final callback when drag ends (in case throttling skipped last value)
			SafeCallback(config.Callback, value)
		end
	end))

	return {
		GetValue = function() return value end,
		SetValue = function(newVal)
			updateSlider(newVal, true)
		end,
		Instance = container,
	}
end

function Window:AddTextbox(config, tab)
	config = config or {}
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local container = CreateElement("Frame", {
		Name = config.Name or "Textbox",
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundTransparency = 1,
		Parent = tab.Content,
	})

	CreateElement("TextLabel", {
		Name = "Label",
		Text = config.Name or "Textbox",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})

	local textbox = CreateElement("TextBox", {
		Name = "Input",
		Text = config.Default or "",
		PlaceholderText = config.PlaceHolder or "",
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundColor3 = COLORS.Secondary,
		TextColor3 = COLORS.Text,
		PlaceholderColor3 = COLORS.TextDisabled,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		BorderSizePixel = 0,
		ClearTextOnFocus = config.ClearOnFocus or false,
		Parent = container,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 6),
		Parent = textbox,
	})

	CreateElement("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = textbox,
	})

	tab._elementConnections:Add(textbox.FocusLost:Connect(function(enterPressed)
		SafeCallback(config.Callback, textbox.Text, enterPressed)
	end))

	return {
		GetValue = function() return textbox.Text end,
		SetValue = function(val) textbox.Text = tostring(val) end,
		Instance = container,
	}
end

function Window:AddDropdown(config, tab)
	config = config or {}
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local container = CreateElement("Frame", {
		Name = config.Name or "Dropdown",
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = tab.Content,
	})

	CreateElement("TextLabel", {
		Name = "Label",
		Text = config.Name or "Dropdown",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})

	local selectedValue = (config.Options and config.Options[1]) or "Select..."

	local dropdownBtn = CreateElement("TextButton", {
		Name = "DropdownBtn",
		Text = selectedValue,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundColor3 = COLORS.Secondary,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		BorderSizePixel = 0,
		Parent = container,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 6),
		Parent = dropdownBtn,
	})

	local isOpen = false

	local dropdownList = CreateElement("Frame", {
		Name = "DropdownList",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 5),
		BackgroundColor3 = COLORS.Secondary,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1000,
		Parent = container,
	})

	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 6),
		Parent = dropdownList,
	})

	CreateElement("UIListLayout", {
		Name = "ListLayout",
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = dropdownList,
	})

	CreateElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = dropdownList,
	})

	local function refreshOptions()
		-- FIXED: Only destroy option buttons, preserve layout
		for _, child in ipairs(dropdownList:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, option in ipairs(config.Options or {}) do
			local optionBtn = CreateElement("TextButton", {
				Name = option,
				Text = option,
				Size = UDim2.new(1, -8, 0, 26),
				BackgroundColor3 = COLORS.Tertiary,
				TextColor3 = COLORS.Text,
				TextSize = 14,
				Font = Enum.Font.Gotham,
				BorderSizePixel = 0,
				Parent = dropdownList,
			})

			CreateElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
				Parent = optionBtn,
			})

			tab._elementConnections:Add(optionBtn.MouseButton1Click:Connect(function()
				selectedValue = option
				dropdownBtn.Text = option
				isOpen = false
				Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, 0)})
				dropdownList.Visible = false
				SafeCallback(config.Callback, option)
			end))

			tab._elementConnections:Add(optionBtn.MouseEnter:Connect(function()
				Tween(optionBtn, 0.2, {BackgroundColor3 = Color3.fromRGB(45, 45, 45)})
			end))

			tab._elementConnections:Add(optionBtn.MouseLeave:Connect(function()
				Tween(optionBtn, 0.2, {BackgroundColor3 = COLORS.Tertiary})
			end))
		end
	end

	tab._elementConnections:Add(dropdownBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		if isOpen then
			refreshOptions()
			local itemCount = #(config.Options or {})
			local height = math.min((itemCount * 30) + 16, 200) -- Cap at 200px
			dropdownList.Visible = true
			Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, height)})
		else
			Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, 0)})
			dropdownList.Visible = false
		end
	end))

	return {
		GetValue = function() return selectedValue end,
		SetValue = function(val) 
			selectedValue = val
			dropdownBtn.Text = val
		end,
		Refresh = function(newOptions)
			config.Options = newOptions
			if isOpen then
				refreshOptions()
			end
		end,
		Instance = container,
	}
end

function Window:AddLabel(text, tab)
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local label = CreateElement("TextLabel", {
		Name = "Label",
		Text = tostring(text),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.TextSecondary,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		WordWrap = true,
		Parent = tab.Content,
	})

	return label
end

function Window:AddDivider(tab)
	tab = tab or self.CurrentTab
	if not tab then return nil end

	local divider = CreateElement("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -20, 0, 1),
		BackgroundColor3 = COLORS.Border,
		BorderSizePixel = 0,
		Parent = tab.Content,
	})

	return divider
end

function Window:Show()
	self.ScreenGui.Enabled = true
	return self
end

function Window:Hide()
	self.ScreenGui.Enabled = false
	return self
end

function Window:Close()
	if self._isDestroyed then return end
	self._isDestroyed = true

	-- Disconnect all connections
	self._connections:DisconnectAll()
	for _, tab in ipairs(self.Tabs) do
		if tab._elementConnections then
			tab._elementConnections:DisconnectAll()
		end
	end

	-- Destroy UI
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end

	-- Clear references
	self.Tabs = {}
	self.CurrentTab = nil
	self._elements = {}
end

function Window:IsDestroyed()
	return self._isDestroyed
end

-- Export
function Rayfield.CreateWindow(config)
	local window = Window.new(config)
	table.insert(Rayfield.LoadedFrameworks, window)
	return window
end

function Rayfield.GetLoadedWindows()
	return Rayfield.LoadedFrameworks
end

function Rayfield.CloseAllWindows()
	for _, window in ipairs(Rayfield.LoadedFrameworks) do
		if not window:IsDestroyed() then
			window:Close()
		end
	end
	Rayfield.LoadedFrameworks = {}
end

return Rayfield
