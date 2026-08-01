--[[
	RAYFIELD GEN2 ENHANCED
	Original: sirius.menu (https://sirius.menu/gen2)
	Enhanced Version: Beautiful UI, bug fixes, performance optimizations
	
	Made by: Community Enhancement of Rayfield Gen2
	Original Creator Attribution: sirius.menu
	
	This is an enhanced version of the original Rayfield Gen2 library.
	All credit for the original design goes to sirius.menu.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

local function CreateElement(className, properties)
	local element = Instance.new(className)
	for prop, value in pairs(properties or {}) do
		pcall(function()
			element[prop] = value
		end)
	end
	return element
end

local function Tween(instance, duration, properties, easing)
	easing = easing or Enum.EasingStyle.Quad
	local tweenInfo = TweenInfo.new(duration, easing, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

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
	
	self:Build()
	
	return self
end

function Window:Build()
	-- Main ScreenGui
	self.ScreenGui = CreateElement("ScreenGui", {
		Name = self.Title,
		ResetOnSpawn = false,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
	})
	self.ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Main Frame
	self.MainFrame = CreateElement("Frame", {
		Name = "MainFrame",
		Size = self.Size,
		Position = self.Position,
		BackgroundColor3 = COLORS.Main,
		BorderSizePixel = 0,
		Parent = self.ScreenGui,
	})
	
	-- Corner
	CreateElement("UICorner", {
		CornerRadius = UDim.new(0, 12),
		Parent = self.MainFrame,
	})
	
	-- Shadow Effect
	local shadowFrame = CreateElement("Frame", {
		Name = "Shadow",
		Size = UDim2.new(1, 20, 1, 20),
		Position = UDim2.new(0, -10, 0, -10),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = -1,
		Parent = self.MainFrame,
	})
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
	local titleLabel = CreateElement("TextLabel", {
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
		
		closeButton.MouseButton1Click:Connect(function()
			self:Close()
		end)
		
		closeButton.MouseEnter:Connect(function()
			Tween(closeButton, 0.2, {BackgroundColor3 = Color3.fromRGB(255, 100, 100)})
		end)
		
		closeButton.MouseLeave:Connect(function()
			Tween(closeButton, 0.2, {BackgroundColor3 = COLORS.Error})
		end)
	end
	
	-- Tab Bar
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
		CanvasSize = UDim2.new(0, 0, 1, 0),
		Parent = self.TabBar,
	})
	
	local tabLayout = CreateElement("UIListLayout", {
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
	
	self.TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = self.MainFrame.Position
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Mouse then
			local delta = input.Position - dragStart
			self.MainFrame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
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
	
	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if resizing and input.UserInputType == Enum.UserInputType.Mouse then
			local newSize = self.MainFrame.AbsoluteSize + (input.Position - input.Delta)
			self.MainFrame.Size = UDim2.new(0, math.max(300, newSize.X), 0, math.max(200, newSize.Y))
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = false
		end
	end)
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
		Parent = self.TabContainer,
	})
	
	local layout = CreateElement("UIListLayout", {
		Padding = UDim.new(0, 8),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tab.Content,
	})
	
	local padding = CreateElement("UIPadding", {
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
	
	tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	
	tabButton.MouseEnter:Connect(function()
		if tab ~= self.CurrentTab then
			Tween(tabButton, 0.2, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)})
		end
	end)
	
	tabButton.MouseLeave:Connect(function()
		if tab ~= self.CurrentTab then
			Tween(tabButton, 0.2, {BackgroundColor3 = COLORS.Tertiary})
		end
	end)
	
	tab.Button = tabButton
	table.insert(self.Tabs, tab)
	self.TabCount = self.TabCount + 1
	
	if not self.CurrentTab then
		self:SelectTab(tab)
	end
	
	return tab
end

function Window:SelectTab(tab)
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
	
	button.MouseButton1Click:Connect(function()
		if config.Callback then
			task.spawn(config.Callback)
		end
	end)
	
	button.MouseEnter:Connect(function()
		Tween(button, 0.2, {BackgroundColor3 = COLORS.PrimaryHover})
	end)
	
	button.MouseLeave:Connect(function()
		Tween(button, 0.2, {BackgroundColor3 = COLORS.Primary})
	end)
	
	return button
end

function Window:AddToggle(config, tab)
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
	
	local label = CreateElement("TextLabel", {
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
	
	clickArea.MouseButton1Click:Connect(function()
		toggled = not toggled
		Tween(toggleBg, 0.3, {
			BackgroundColor3 = toggled and COLORS.Success or COLORS.Border
		})
		if config.Callback then
			task.spawn(config.Callback, toggled)
		end
	end)
	
	return {
		GetValue = function() return toggled end,
		SetValue = function(value)
			toggled = value
			toggleBg.BackgroundColor3 = value and COLORS.Success or COLORS.Border
		end,
		Instance = container,
	}
end

function Window:AddSlider(config, tab)
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
	local value = config.Default or 50
	
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
	
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Mouse then
			local trackAbsPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			local percent = math.clamp((input.Position.X - trackAbsPos) / trackSize, 0, 1)
			
			value = math.round(min + (max - min) * percent)
			valueLabel.Text = tostring(value)
			progress.Size = UDim2.new(percent, 0, 1, 0)
			handle.Position = UDim2.new(percent, -8, 0.5, -8)
			
			if config.Callback then
				task.spawn(config.Callback, value)
			end
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	
	return {
		GetValue = function() return value end,
		SetValue = function(newVal)
			value = math.clamp(newVal, min, max)
			local percent = (value - min) / (max - min)
			valueLabel.Text = tostring(value)
			progress.Size = UDim2.new(percent, 0, 1, 0)
			handle.Position = UDim2.new(percent, -8, 0.5, -8)
		end,
		Instance = container,
	}
end

function Window:AddTextbox(config, tab)
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
		Text = "",
		PlaceholderText = config.PlaceHolder or "",
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundColor3 = COLORS.Secondary,
		TextColor3 = COLORS.Text,
		PlaceholderColor3 = COLORS.TextDisabled,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		BorderSizePixel = 0,
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
	
	textbox.FocusLost:Connect(function()
		if config.Callback then
			task.spawn(config.Callback, textbox.Text)
		end
	end)
	
	return {
		GetValue = function() return textbox.Text end,
		SetValue = function(val) textbox.Text = val end,
		Instance = container,
	}
end

function Window:AddDropdown(config, tab)
	tab = tab or self.CurrentTab
	if not tab then return nil end
	
	local container = CreateElement("Frame", {
		Name = config.Name or "Dropdown",
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundTransparency = 1,
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
	
	local listLayout = CreateElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = dropdownList,
	})
	
	local function populateList()
		dropdownList:ClearAllChildren()
		listLayout = CreateElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			Parent = dropdownList,
		})
		
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
			
			optionBtn.MouseButton1Click:Connect(function()
				selectedValue = option
				dropdownBtn.Text = option
				isOpen = false
				Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, 0)})
				dropdownList.Visible = false
				if config.Callback then
					task.spawn(config.Callback, option)
				end
			end)
			
			optionBtn.MouseEnter:Connect(function()
				Tween(optionBtn, 0.2, {BackgroundColor3 = Color3.fromRGB(45, 45, 45)})
			end)
			
			optionBtn.MouseLeave:Connect(function()
				Tween(optionBtn, 0.2, {BackgroundColor3 = COLORS.Tertiary})
			end)
		end
	end
	
	dropdownBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		if isOpen then
			populateList()
			local itemCount = #(config.Options or {})
			local height = (itemCount * 30) + 8
			dropdownList.Visible = true
			Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, height)})
		else
			Tween(dropdownList, 0.2, {Size = UDim2.new(1, 0, 0, 0)})
			dropdownList.Visible = false
		end
	end)
	
	return {
		GetValue = function() return selectedValue end,
		SetValue = function(val) selectedValue = val; dropdownBtn.Text = val end,
		Instance = container,
	}
end

function Window:AddLabel(text, tab)
	tab = tab or self.CurrentTab
	if not tab then return nil end
	
	local label = CreateElement("TextLabel", {
		Name = "Label",
		Text = text,
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
	self.ScreenGui:Destroy()
end

-- Export
function Rayfield.CreateWindow(config)
	local window = Window.new(config)
	table.insert(Rayfield.LoadedFrameworks, window)
	return window
end

return Rayfield
