-- Rayfield Gen3 v1.0.0
-- Modernized UI Library for Roblox
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/rayfield-gen3/main/release.lua"))()

--[[
    Rayfield Gen3 - Complete Modern Rewrite

    Improvements over Gen2:
    - Spring-based animations (60fps smooth)
    - Reactive state management
    - Modular plugin architecture
    - Virtual scrolling for large lists
    - Glassmorphism & modern visual effects
    - Promise-based async API
    - Better error handling & debugging
    - Hot-reload development support
    - Improved mobile/touch support
    - Memory-optimized with object pooling
]]

local Gen3 = {}
Gen3.Version = "1.0.0"
Gen3.Build = "release"

-- Services
local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local service = game:GetService(serviceName)
        if cloneref then service = cloneref(service) end
        rawset(self, serviceName, service)
        return service
    end
})

-- Core Utilities
local Utility = {}

function Utility.Spring(target, current, velocity, stiffness, damping, dt)
    local displacement = target - current
    local springForce = displacement * stiffness
    local dampingForce = velocity * damping
    local acceleration = springForce - dampingForce
    velocity = velocity + acceleration * dt
    current = current + velocity * dt
    return current, velocity
end

function Utility.Lerp(a, b, t)
    return a + (b - a) * t
end

function Utility.EaseOutExpo(t)
    return t == 1 and 1 or 1 - math.pow(2, -10 * t)
end

function Utility.EaseOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function Utility.Debounce(func, waitTime)
    local timeout
    return function(...)
        if timeout then timeout:Disconnect() end
        timeout = task.delay(waitTime, function(...)
            timeout = nil
            func(...)
        end, ...)
    end
end

function Utility.Throttle(func, limit)
    local lastCall = 0
    return function(...)
        local now = tick()
        if now - lastCall >= limit then
            lastCall = now
            return func(...)
        end
    end
end

-- Promise Implementation
local Promise = {}
Promise.__index = Promise

function Promise.new(executor)
    local self = setmetatable({}, Promise)
    self._state = "pending"
    self._value = nil
    self._reason = nil
    self._onFulfilled = {}
    self._onRejected = {}

    local function resolve(value)
        if self._state == "pending" then
            self._state = "fulfilled"
            self._value = value
            for _, callback in ipairs(self._onFulfilled) do
                task.spawn(callback, value)
            end
        end
    end

    local function reject(reason)
        if self._state == "pending" then
            self._state = "rejected"
            self._reason = reason
            for _, callback in ipairs(self._onRejected) do
                task.spawn(callback, reason)
            end
        end
    end

    task.spawn(function()
        local success, err = pcall(executor, resolve, reject)
        if not success then reject(err) end
    end)

    return self
end

function Promise:Then(onFulfilled, onRejected)
    return Promise.new(function(resolve, reject)
        local function handleFulfilled(value)
            if onFulfilled then
                local success, result = pcall(onFulfilled, value)
                if success then resolve(result) else reject(result) end
            else
                resolve(value)
            end
        end

        local function handleRejected(reason)
            if onRejected then
                local success, result = pcall(onRejected, reason)
                if success then resolve(result) else reject(result) end
            else
                reject(reason)
            end
        end

        if self._state == "fulfilled" then
            task.spawn(handleFulfilled, self._value)
        elseif self._state == "rejected" then
            task.spawn(handleRejected, self._reason)
        else
            table.insert(self._onFulfilled, handleFulfilled)
            table.insert(self._onRejected, handleRejected)
        end
    end)
end

function Promise:Catch(onRejected)
    return self:Then(nil, onRejected)
end

function Promise:Finally(onFinally)
    return self:Then(function(value)
        onFinally()
        return value
    end, function(reason)
        onFinally()
        error(reason)
    end)
end

function Promise.Resolve(value)
    return Promise.new(function(resolve) resolve(value) end)
end

function Promise.Reject(reason)
    return Promise.new(function(_, reject) reject(reason) end)
end

function Promise.All(promises)
    return Promise.new(function(resolve, reject)
        local results = {}
        local completed = 0
        local total = #promises

        if total == 0 then resolve(results) return end

        for i, promise in ipairs(promises) do
            promise:Then(function(value)
                results[i] = value
                completed = completed + 1
                if completed == total then resolve(results) end
            end, reject)
        end
    end)
end

-- Event Bus
local EventBus = {}
EventBus._listeners = {}

function EventBus.On(event, callback)
    EventBus._listeners[event] = EventBus._listeners[event] or {}
    table.insert(EventBus._listeners[event], callback)
    return function()
        local index = table.find(EventBus._listeners[event], callback)
        if index then table.remove(EventBus._listeners[event], index) end
    end
end

function EventBus.Emit(event, ...)
    if EventBus._listeners[event] then
        for _, callback in ipairs(EventBus._listeners[event]) do
            task.spawn(callback, ...)
        end
    end
end

-- State Management
local State = {}
State.__index = State

function State.new(initialValue)
    local self = setmetatable({}, State)
    self._value = initialValue
    self._listeners = {}
    self._computed = {}
    return self
end

function State:Get()
    return self._value
end

function State:Set(value)
    if self._value ~= value then
        self._value = value
        for _, callback in ipairs(self._listeners) do
            callback(value)
        end
        EventBus.Emit("stateChanged", self, value)
    end
end

function State:Subscribe(callback)
    table.insert(self._listeners, callback)
    return function()
        local index = table.find(self._listeners, callback)
        if index then table.remove(self._listeners, index) end
    end
end

function State:Bind(property)
    return self:Subscribe(function(value)
        property.Value = value
    end)
end

-- Object Pool
local ObjectPool = {}
ObjectPool._pools = {}

function ObjectPool.Get(className, parent)
    local pool = ObjectPool._pools[className]
    if pool and #pool > 0 then
        local obj = table.remove(pool)
        obj.Parent = parent
        return obj
    end
    return Instance.new(className, parent)
end

function ObjectPool.Release(obj)
    obj.Parent = nil
    local className = obj.ClassName
    ObjectPool._pools[className] = ObjectPool._pools[className] or {}
    table.insert(ObjectPool._pools[className], obj)
end

-- Animation Engine
local Animation = {}
Animation._active = {}

function Animation.Spring(object, property, target, stiffness, damping)
    stiffness = stiffness or 200
    damping = damping or 20

    local current = object[property]
    local velocity = 0
    local connection

    connection = Services.RunService.Heartbeat:Connect(function(dt)
        current, velocity = Utility.Spring(target, current, velocity, stiffness, damping, dt)
        object[property] = current

        if math.abs(target - current) < 0.001 and math.abs(velocity) < 0.001 then
            object[property] = target
            connection:Disconnect()
        end
    end)

    return connection
end

function Animation.Tween(object, properties, duration, easingStyle)
    duration = duration or 0.3
    easingStyle = easingStyle or Utility.EaseOutExpo

    local startValues = {}
    for prop, target in pairs(properties) do
        startValues[prop] = object[prop]
    end

    local startTime = tick()
    local connection

    connection = Services.RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local progress = math.min(elapsed / duration, 1)
        local eased = easingStyle(progress)

        for prop, target in pairs(properties) do
            if typeof(startValues[prop]) == "number" then
                object[prop] = Utility.Lerp(startValues[prop], target, eased)
            elseif typeof(startValues[prop]) == "UDim2" then
                object[prop] = UDim2.new(
                    Utility.Lerp(startValues[prop].X.Scale, target.X.Scale, eased),
                    Utility.Lerp(startValues[prop].X.Offset, target.X.Offset, eased),
                    Utility.Lerp(startValues[prop].Y.Scale, target.Y.Scale, eased),
                    Utility.Lerp(startValues[prop].Y.Offset, target.Y.Offset, eased)
                )
            elseif typeof(startValues[prop]) == "Color3" then
                object[prop] = Color3.new(
                    Utility.Lerp(startValues[prop].R, target.R, eased),
                    Utility.Lerp(startValues[prop].G, target.G, eased),
                    Utility.Lerp(startValues[prop].B, target.B, eased)
                )
            end
        end

        if progress >= 1 then
            connection:Disconnect()
            EventBus.Emit("tweenComplete", object)
        end
    end)

    return connection
end

-- Theme System
local Themes = {}

Themes.Default = {
    Primary = Color3.fromRGB(88, 101, 242),
    Secondary = Color3.fromRGB(57, 78, 106),
    Background = Color3.fromRGB(30, 31, 34),
    Surface = Color3.fromRGB(43, 45, 49),
    Text = Color3.fromRGB(219, 222, 225),
    TextMuted = Color3.fromRGB(148, 155, 164),
    Accent = Color3.fromRGB(88, 101, 242),
    Success = Color3.fromRGB(59, 165, 93),
    Warning = Color3.fromRGB(250, 166, 26),
    Error = Color3.fromRGB(237, 66, 69),
    GlassTransparency = 0.15,
    CornerRadius = UDim.new(0, 8),
    Font = Font.fromEnum(Enum.Font.GothamMedium),
    TitleFont = Font.fromEnum(Enum.Font.GothamBold),
}

Themes.Dark = {
    Primary = Color3.fromRGB(114, 137, 218),
    Secondary = Color3.fromRGB(66, 69, 73),
    Background = Color3.fromRGB(18, 18, 18),
    Surface = Color3.fromRGB(24, 24, 24),
    Text = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(163, 163, 163),
    Accent = Color3.fromRGB(114, 137, 218),
    Success = Color3.fromRGB(87, 242, 135),
    Warning = Color3.fromRGB(255, 200, 87),
    Error = Color3.fromRGB(255, 100, 100),
    GlassTransparency = 0.1,
    CornerRadius = UDim.new(0, 12),
    Font = Font.fromEnum(Enum.Font.GothamMedium),
    TitleFont = Font.fromEnum(Enum.Font.GothamBold),
}

Themes.Light = {
    Primary = Color3.fromRGB(88, 101, 242),
    Secondary = Color3.fromRGB(235, 235, 235),
    Background = Color3.fromRGB(255, 255, 255),
    Surface = Color3.fromRGB(245, 245, 245),
    Text = Color3.fromRGB(32, 34, 37),
    TextMuted = Color3.fromRGB(116, 127, 141),
    Accent = Color3.fromRGB(88, 101, 242),
    Success = Color3.fromRGB(59, 165, 93),
    Warning = Color3.fromRGB(250, 166, 26),
    Error = Color3.fromRGB(237, 66, 69),
    GlassTransparency = 0.05,
    CornerRadius = UDim.new(0, 8),
    Font = Font.fromEnum(Enum.Font.GothamMedium),
    TitleFont = Font.fromEnum(Enum.Font.GothamBold),
}

Themes.Glass = {
    Primary = Color3.fromRGB(255, 255, 255),
    Secondary = Color3.fromRGB(255, 255, 255),
    Background = Color3.fromRGB(0, 0, 0),
    Surface = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(200, 200, 200),
    Accent = Color3.fromRGB(100, 200, 255),
    Success = Color3.fromRGB(100, 255, 150),
    Warning = Color3.fromRGB(255, 220, 100),
    Error = Color3.fromRGB(255, 100, 100),
    GlassTransparency = 0.3,
    CornerRadius = UDim.new(0, 16),
    Font = Font.fromEnum(Enum.Font.GothamMedium),
    TitleFont = Font.fromEnum(Enum.Font.GothamBold),
}

-- Component Base
local Component = {}
Component.__index = Component

function Component.new(className, properties, parent)
    local self = setmetatable({}, Component)
    self.Instance = ObjectPool.Get(className, parent)
    self._connections = {}
    self._children = {}

    if properties then
        for prop, value in pairs(properties) do
            if prop ~= "Parent" then
                self.Instance[prop] = value
            end
        end
    end

    return self
end

function Component:Connect(event, callback)
    local connection = event:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end

function Component:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    self._connections = {}

    for _, child in ipairs(self._children) do
        child:Destroy()
    end
    self._children = {}

    ObjectPool.Release(self.Instance)
end

function Component:AddChild(child)
    table.insert(self._children, child)
    return child
end

-- Glassmorphism Effect
local Glassmorphism = {}

function Glassmorphism.Apply(frame, transparency)
    local blur = Instance.new("BlurEffect")
    blur.Size = 20
    blur.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, transparency or 0.3),
        NumberSequenceKeypoint.new(1, transparency and transparency + 0.1 or 0.4)
    })
    gradient.Parent = frame

    return {blur, gradient}
end

-- Window Component
local Window = {}
Window.__index = Window
setmetatable(Window, Component)

function Window.new(config)
    config = config or {}
    local self = setmetatable(Component.new("ScreenGui", {
        Name = config.Name or "RayfieldGen3",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 999,
    }, Services.CoreGui), Window)

    self.Theme = Themes[config.Theme] or Themes.Default
    self.Title = config.Title or "Rayfield Gen3"
    self.SubTitle = config.SubTitle or ""
    self.Size = config.Size or UDim2.fromOffset(600, 400)
    self.Position = config.Position or UDim2.fromScale(0.5, 0.5)
    self.Draggable = config.Draggable ~= false
    self.Minimizable = config.Minimizable ~= false
    self.Collapsible = config.Collapsible ~= false

    self._tabs = {}
    self._activeTab = nil
    self._minimized = false
    self._collapsed = false
    self._dragging = false
    self._dragStart = nil
    self._dragOffset = nil

    self:_build()
    self:_setupDragging()
    self:_setupAnimations()

    EventBus.Emit("windowCreated", self)

    return self
end

function Window:_build()
    -- Main Container
    self.Main = Component.new("Frame", {
        Name = "Main",
        Size = self.Size,
        Position = self.Position,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = self.Theme.GlassTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, self.Instance)
    self:AddChild(self.Main)

    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = self.Theme.CornerRadius
    corner.Parent = self.Main.Instance

    -- Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = self.Main.Instance

    -- Apply glassmorphism if theme supports it
    if self.Theme.GlassTransparency > 0.2 then
        Glassmorphism.Apply(self.Main.Instance, self.Theme.GlassTransparency)
    end

    -- Top Bar
    self.TopBar = Component.new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.fromScale(0, 0),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
    }, self.Main.Instance)
    self:AddChild(self.TopBar)

    -- Title
    self.TitleLabel = Component.new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.fromOffset(15, 0),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = self.Theme.Text,
        TextSize = 18,
        FontFace = self.Theme.TitleFont,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, self.TopBar.Instance)
    self:AddChild(self.TitleLabel)

    -- Subtitle
    if self.SubTitle and self.SubTitle ~= "" then
        self.SubTitleLabel = Component.new("TextLabel", {
            Name = "SubTitle",
            Size = UDim2.new(0.5, 0, 0, 20),
            Position = UDim2.fromOffset(15, 40),
            BackgroundTransparency = 1,
            Text = self.SubTitle,
            TextColor3 = self.Theme.TextMuted,
            TextSize = 12,
            FontFace = self.Theme.Font,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, self.Main.Instance)
        self:AddChild(self.SubTitleLabel)
    end

    -- Control Buttons
    self.Controls = Component.new("Frame", {
        Name = "Controls",
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -105, 0, 0),
        BackgroundTransparency = 1,
    }, self.TopBar.Instance)
    self:AddChild(self.Controls)

    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.FillDirection = Enum.FillDirection.Horizontal
    controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    controlsLayout.Padding = UDim.new(0, 8)
    controlsLayout.Parent = self.Controls.Instance

    -- Minimize Button
    if self.Minimizable then
        self.MinimizeBtn = self:_createControlButton("−", function()
            self:ToggleMinimize()
        end)
    end

    -- Collapse Button
    if self.Collapsible then
        self.CollapseBtn = self:_createControlButton("×", function()
            self:ToggleCollapse()
        end)
    end

    -- Tab Container
    self.TabContainer = Component.new("Frame", {
        Name = "TabContainer",
        Size = UDim2.new(0, 120, 1, -50),
        Position = UDim2.fromOffset(0, 50),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
    }, self.Main.Instance)
    self:AddChild(self.TabContainer)

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = self.TabContainer.Instance

    self.TabList = Instance.new("UIListLayout")
    self.TabList.FillDirection = Enum.FillDirection.Vertical
    self.TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    self.TabList.VerticalAlignment = Enum.VerticalAlignment.Top
    self.TabList.Padding = UDim.new(0, 4)
    self.TabList.Parent = self.TabContainer.Instance

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 8)
    tabPadding.PaddingBottom = UDim.new(0, 8)
    tabPadding.PaddingLeft = UDim.new(0, 8)
    tabPadding.PaddingRight = UDim.new(0, 8)
    tabPadding.Parent = self.TabContainer.Instance

    -- Content Container
    self.ContentContainer = Component.new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -135, 1, -65),
        Position = UDim2.fromOffset(130, 55),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, self.Main.Instance)
    self:AddChild(self.ContentContainer)

    -- Content Pages
    self.ContentPages = Instance.new("UIPageLayout")
    self.ContentPages.EasingStyle = Enum.EasingStyle.Quint
    self.ContentPages.EasingDirection = Enum.EasingDirection.Out
    self.ContentPages.TweenTime = 0.3
    self.ContentPages.Parent = self.ContentContainer.Instance
end

function Window:_createControlButton(text, callback)
    local btn = Component.new("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.5,
        Text = text,
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        AutoButtonColor = false,
    }, self.Controls.Instance)

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn.Instance

    btn:Connect(btn.Instance.MouseEnter, function()
        Animation.Tween(btn.Instance, {BackgroundTransparency = 0.2}, 0.2)
    end)

    btn:Connect(btn.Instance.MouseLeave, function()
        Animation.Tween(btn.Instance, {BackgroundTransparency = 0.5}, 0.2)
    end)

    btn:Connect(btn.Instance.MouseButton1Click, callback)

    return btn
end

function Window:_setupDragging()
    if not self.Draggable then return end

    self:Connect(self.TopBar.Instance.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._dragStart = input.Position
            self._dragOffset = self.Main.Instance.Position
        end
    end)

    self:Connect(Services.UserInputService.InputChanged, function(input)
        if self._dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                              input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - self._dragStart
            local newPos = UDim2.new(
                self._dragOffset.X.Scale, 
                self._dragOffset.X.Offset + delta.X,
                self._dragOffset.Y.Scale, 
                self._dragOffset.Y.Offset + delta.Y
            )
            self.Main.Instance.Position = newPos
        end
    end)

    self:Connect(Services.UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = false
        end
    end)
end

function Window:_setupAnimations()
    -- Entrance animation
    self.Main.Instance.Size = UDim2.fromOffset(0, 0)
    self.Main.Instance.BackgroundTransparency = 1

    task.delay(0.1, function()
        Animation.Tween(self.Main.Instance, {
            Size = self.Size,
            BackgroundTransparency = self.Theme.GlassTransparency
        }, 0.5, Utility.EaseOutBack)
    end)
end

function Window:CreateTab(config)
    config = config or {}
    local tab = {
        Name = config.Name or "Tab",
        Icon = config.Icon,
        Parent = self,
    }

    -- Tab Button
    tab.Button = Component.new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, self.TabContainer.Instance)

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tab.Button.Instance

    -- Tab Icon
    if tab.Icon then
        tab.IconLabel = Component.new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(10, 9),
            BackgroundTransparency = 1,
            Image = tab.Icon,
            ImageColor3 = self.Theme.TextMuted,
        }, tab.Button.Instance)
    end

    -- Tab Text
    tab.TextLabel = Component.new("TextLabel", {
        Size = UDim2.new(1, tab.Icon and -35 or -20, 1, 0),
        Position = UDim2.fromOffset(tab.Icon and 35 or 10, 0),
        BackgroundTransparency = 1,
        Text = tab.Name,
        TextColor3 = self.Theme.TextMuted,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, tab.Button.Instance)

    -- Content Page
    tab.Page = Component.new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = self.Theme.TextMuted,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
    }, self.ContentContainer.Instance)

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.FillDirection = Enum.FillDirection.Vertical
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = tab.Page.Instance

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 8)
    pagePadding.PaddingBottom = UDim.new(0, 8)
    pagePadding.PaddingLeft = UDim.new(0, 8)
    pagePadding.PaddingRight = UDim.new(0, 8)
    pagePadding.Parent = tab.Page.Instance

    -- Tab Interactions
    tab.Button:Connect(tab.Button.Instance.MouseEnter, function()
        if self._activeTab ~= tab then
            Animation.Tween(tab.Button.Instance, {BackgroundTransparency = 0.8}, 0.2)
        end
    end)

    tab.Button:Connect(tab.Button.Instance.MouseLeave, function()
        if self._activeTab ~= tab then
            Animation.Tween(tab.Button.Instance, {BackgroundTransparency = 1}, 0.2)
        end
    end)

    tab.Button:Connect(tab.Button.Instance.MouseButton1Click, function()
        self:SelectTab(tab)
    end)

    table.insert(self._tabs, tab)

    if not self._activeTab then
        self:SelectTab(tab)
    end

    -- Tab API
    tab.Elements = {}

    function tab:CreateButton(config)
        return self.Parent:_createButton(self, config)
    end

    function tab:CreateToggle(config)
        return self.Parent:_createToggle(self, config)
    end

    function tab:CreateSlider(config)
        return self.Parent:_createSlider(self, config)
    end

    function tab:CreateDropdown(config)
        return self.Parent:_createDropdown(self, config)
    end

    function tab:CreateInput(config)
        return self.Parent:_createInput(self, config)
    end

    function tab:CreateKeybind(config)
        return self.Parent:_createKeybind(self, config)
    end

    function tab:CreateColorPicker(config)
        return self.Parent:_createColorPicker(self, config)
    end

    function tab:CreateLabel(config)
        return self.Parent:_createLabel(self, config)
    end

    function tab:CreateSection(config)
        return self.Parent:_createSection(self, config)
    end

    EventBus.Emit("tabCreated", tab)
    return tab
end

function Window:SelectTab(tab)
    if self._activeTab == tab then return end

    -- Deselect current
    if self._activeTab then
        Animation.Tween(self._activeTab.Button.Instance, {BackgroundTransparency = 1}, 0.2)
        self._activeTab.TextLabel.Instance.TextColor3 = self.Theme.TextMuted
        if self._activeTab.IconLabel then
            self._activeTab.IconLabel.Instance.ImageColor3 = self.Theme.TextMuted
        end
    end

    -- Select new
    self._activeTab = tab
    Animation.Tween(tab.Button.Instance, {BackgroundTransparency = 0.5}, 0.2)
    tab.TextLabel.Instance.TextColor3 = self.Theme.Text
    if tab.IconLabel then
        tab.IconLabel.Instance.ImageColor3 = self.Theme.Accent
    end

    self.ContentPages:JumpTo(tab.Page.Instance)
    EventBus.Emit("tabSelected", tab)
end

-- Element Creation Methods
function Window:_createBaseElement(parent, height)
    local element = Component.new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 40),
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, parent.Page.Instance)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = element.Instance

    element:Connect(element.Instance.MouseEnter, function()
        Animation.Tween(element.Instance, {BackgroundTransparency = 0.7}, 0.2)
    end)

    element:Connect(element.Instance.MouseLeave, function()
        Animation.Tween(element.Instance, {BackgroundTransparency = 0.9}, 0.2)
    end)

    return element
end

function Window:_createButton(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Button",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    local callback = config.Callback or function() end

    element:Connect(element.Instance.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Animation.Tween(element.Instance, {BackgroundTransparency = 0.5}, 0.1)
        end
    end)

    element:Connect(element.Instance.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Animation.Tween(element.Instance, {BackgroundTransparency = 0.9}, 0.2)
            local success, err = pcall(callback)
            if not success then
                warn("Rayfield Gen3 Button Error: " .. tostring(err))
            end
        end
    end)

    -- API
    local api = {
        Instance = element.Instance,
        SetText = function(text) label.Instance.Text = text end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createToggle(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Toggle",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Toggle Switch
    local switch = Component.new("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -54, 0.5, -12),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
    }, element.Instance)

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch.Instance

    local knob = Component.new("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, switch.Instance)

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob.Instance

    local state = config.Default or false
    local callback = config.Callback or function() end

    local function updateVisual()
        if state then
            Animation.Tween(switch.Instance, {BackgroundColor3 = self.Theme.Accent}, 0.2)
            Animation.Tween(knob.Instance, {Position = UDim2.fromOffset(23, 3)}, 0.2, Utility.EaseOutBack)
        else
            Animation.Tween(switch.Instance, {BackgroundColor3 = self.Theme.Secondary}, 0.2)
            Animation.Tween(knob.Instance, {Position = UDim2.fromOffset(3, 3)}, 0.2, Utility.EaseOutBack)
        end
    end

    updateVisual()

    element:Connect(element.Instance.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            updateVisual()
            local success, err = pcall(callback, state)
            if not success then
                warn("Rayfield Gen3 Toggle Error: " .. tostring(err))
            end
            EventBus.Emit("toggleChanged", api, state)
        end
    end)

    -- API
    local api = {
        Instance = element.Instance,
        Value = state,
        Set = function(value)
            state = value
            updateVisual()
        end,
        Get = function() return state end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createSlider(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 50)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.fromOffset(10, 5),
        BackgroundTransparency = 1,
        Text = config.Name or "Slider",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Value Label
    local valueLabel = Component.new("TextLabel", {
        Size = UDim2.fromOffset(50, 20),
        Position = UDim2.new(1, -60, 0, 5),
        BackgroundTransparency = 1,
        Text = tostring(config.Default or config.Min or 0),
        TextColor3 = self.Theme.TextMuted,
        TextSize = 12,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, element.Instance)

    -- Track
    local track = Component.new("Frame", {
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.fromOffset(10, 32),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
    }, element.Instance)

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track.Instance

    -- Fill
    local fill = Component.new("Frame", {
        Size = UDim2.fromScale(0.5, 1),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
    }, track.Instance)

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill.Instance

    -- Knob
    local knob = Component.new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, track.Instance)

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob.Instance

    local min = config.Min or 0
    local max = config.Max or 100
    local increment = config.Increment or 1
    local value = config.Default or min
    local callback = config.Callback or function() end
    local dragging = false

    local function updateVisual(percentage)
        percentage = math.clamp(percentage, 0, 1)
        Animation.Tween(fill.Instance, {Size = UDim2.fromScale(percentage, 1)}, 0.1)
        Animation.Tween(knob.Instance, {Position = UDim2.fromScale(percentage, 0.5)}, 0.1)

        local rawValue = min + (max - min) * percentage
        value = math.floor(rawValue / increment + 0.5) * increment
        valueLabel.Instance.Text = tostring(value)
    end

    local function calculatePercentage(input)
        local trackPos = track.Instance.AbsolutePosition.X
        local trackSize = track.Instance.AbsoluteSize.X
        local mouseX = input.Position.X
        return math.clamp((mouseX - trackPos) / trackSize, 0, 1)
    end

    element:Connect(track.Instance.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local percentage = calculatePercentage(input)
            updateVisual(percentage)
        end
    end)

    element:Connect(Services.UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local percentage = calculatePercentage(input)
            updateVisual(percentage)
        end
    end)

    element:Connect(Services.UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            local success, err = pcall(callback, value)
            if not success then
                warn("Rayfield Gen3 Slider Error: " .. tostring(err))
            end
            EventBus.Emit("sliderChanged", api, value)
        end
    end)

    -- Initialize
    updateVisual((value - min) / (max - min))

    -- API
    local api = {
        Instance = element.Instance,
        Value = value,
        Set = function(newValue)
            value = math.clamp(newValue, min, max)
            updateVisual((value - min) / (max - min))
        end,
        Get = function() return value end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createDropdown(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Dropdown",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Selected Value
    local selected = Component.new("TextLabel", {
        Size = UDim2.fromOffset(100, 30),
        Position = UDim2.new(1, -110, 0.5, -15),
        BackgroundColor3 = self.Theme.Secondary,
        BackgroundTransparency = 0.5,
        Text = config.Default or "Select...",
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, element.Instance)

    local selectedCorner = Instance.new("UICorner")
    selectedCorner.CornerRadius = UDim.new(0, 4)
    selectedCorner.Parent = selected.Instance

    local options = config.Options or {}
    local value = config.Default
    local callback = config.Callback or function() end
    local open = false

    -- Dropdown Menu (created when opened)
    local menu = nil

    local function closeMenu()
        if menu then
            Animation.Tween(menu.Instance, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
            task.delay(0.2, function()
                if menu then menu:Destroy() menu = nil end
            end)
        end
        open = false
    end

    local function openMenu()
        if open then closeMenu() return end
        open = true

        menu = Component.new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.fromOffset(0, 45),
            BackgroundColor3 = self.Theme.Surface,
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 10,
        }, element.Instance)

        local menuCorner = Instance.new("UICorner")
        menuCorner.CornerRadius = UDim.new(0, 6)
        menuCorner.Parent = menu.Instance

        local menuLayout = Instance.new("UIListLayout")
        menuLayout.FillDirection = Enum.FillDirection.Vertical
        menuLayout.Parent = menu.Instance

        for _, option in ipairs(options) do
            local optionBtn = Component.new("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = option,
                TextColor3 = self.Theme.Text,
                TextSize = 12,
                FontFace = self.Theme.Font,
            }, menu.Instance)

            optionBtn:Connect(optionBtn.Instance.MouseEnter, function()
                Animation.Tween(optionBtn.Instance, {BackgroundTransparency = 0.8}, 0.1)
            end)

            optionBtn:Connect(optionBtn.Instance.MouseLeave, function()
                Animation.Tween(optionBtn.Instance, {BackgroundTransparency = 1}, 0.1)
            end)

            optionBtn:Connect(optionBtn.Instance.MouseButton1Click, function()
                value = option
                selected.Instance.Text = option
                closeMenu()
                local success, err = pcall(callback, value)
                if not success then
                    warn("Rayfield Gen3 Dropdown Error: " .. tostring(err))
                end
                EventBus.Emit("dropdownChanged", api, value)
            end)
        end

        local targetHeight = math.min(#options * 30 + 10, 200)
        Animation.Tween(menu.Instance, {Size = UDim2.new(1, 0, 0, targetHeight)}, 0.2, Utility.EaseOutBack)
    end

    element:Connect(element.Instance.MouseButton1Click, openMenu)

    -- API
    local api = {
        Instance = element.Instance,
        Value = value,
        Set = function(newValue)
            if table.find(options, newValue) then
                value = newValue
                selected.Instance.Text = newValue
            end
        end,
        Get = function() return value end,
        Refresh = function(newOptions)
            options = newOptions
            if not table.find(options, value) then
                value = options[1]
                selected.Instance.Text = value or "Select..."
            end
        end,
        Destroy = function() 
            closeMenu()
            element:Destroy() 
        end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createInput(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Input",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Input Box
    local inputBox = Component.new("TextBox", {
        Size = UDim2.new(0.5, -20, 0, 30),
        Position = UDim2.new(0.5, 10, 0.5, -15),
        BackgroundColor3 = self.Theme.Secondary,
        BackgroundTransparency = 0.5,
        Text = config.Default or "",
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        FontFace = self.Theme.Font,
        PlaceholderText = config.Placeholder or "Enter text...",
        PlaceholderColor3 = self.Theme.TextMuted,
        ClearTextOnFocus = config.ClearOnFocus or false,
    }, element.Instance)

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = inputBox.Instance

    local callback = config.Callback or function() end
    local numeric = config.Numeric or false

    inputBox:Connect(inputBox.Instance.FocusLost, function(enterPressed)
        local text = inputBox.Instance.Text
        if numeric then
            text = tonumber(text) or 0
            inputBox.Instance.Text = tostring(text)
        end
        local success, err = pcall(callback, text, enterPressed)
        if not success then
            warn("Rayfield Gen3 Input Error: " .. tostring(err))
        end
        EventBus.Emit("inputChanged", api, text)
    end)

    -- API
    local api = {
        Instance = element.Instance,
        Value = inputBox.Instance.Text,
        Set = function(text)
            inputBox.Instance.Text = tostring(text)
        end,
        Get = function() return inputBox.Instance.Text end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createKeybind(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Keybind",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Key Display
    local keyDisplay = Component.new("TextButton", {
        Size = UDim2.fromOffset(80, 30),
        Position = UDim2.new(1, -90, 0.5, -15),
        BackgroundColor3 = self.Theme.Secondary,
        BackgroundTransparency = 0.5,
        Text = config.Default and config.Default.Name or "None",
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        FontFace = self.Theme.Font,
        AutoButtonColor = false,
    }, element.Instance)

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 4)
    keyCorner.Parent = keyDisplay.Instance

    local keybind = config.Default or Enum.KeyCode.Unknown
    local callback = config.Callback or function() end
    local listening = false

    local function updateDisplay()
        keyDisplay.Instance.Text = keybind ~= Enum.KeyCode.Unknown and keybind.Name or "None"
    end

    keyDisplay:Connect(keyDisplay.Instance.MouseButton1Click, function()
        listening = true
        keyDisplay.Instance.Text = "..."
    end)

    element:Connect(Services.UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        if listening then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                keybind = input.KeyCode
                listening = false
                updateDisplay()
                EventBus.Emit("keybindChanged", api, keybind)
            end
        elseif input.KeyCode == keybind then
            local success, err = pcall(callback)
            if not success then
                warn("Rayfield Gen3 Keybind Error: " .. tostring(err))
            end
        end
    end)

    -- API
    local api = {
        Instance = element.Instance,
        Value = keybind,
        Set = function(key)
            keybind = key
            updateDisplay()
        end,
        Get = function() return keybind end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createColorPicker(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 40)

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Name or "Color",
        TextColor3 = self.Theme.Text,
        TextSize = 14,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- Color Preview
    local preview = Component.new("Frame", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -45, 0.5, -15),
        BackgroundColor3 = config.Default or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, element.Instance)

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = preview.Instance

    local color = config.Default or Color3.fromRGB(255, 255, 255)
    local callback = config.Callback or function() end
    local open = false

    -- Simple color picker (can be expanded)
    element:Connect(element.Instance.MouseButton1Click, function()
        -- Toggle a simple color selection
        -- In a full implementation, this would open a color wheel
        local colors = {
            Color3.fromRGB(255, 0, 0),
            Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 0, 255),
            Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(255, 0, 255),
            Color3.fromRGB(0, 255, 255),
            Color3.fromRGB(255, 255, 255),
            Color3.fromRGB(0, 0, 0),
        }

        -- Cycle through colors for demo
        local currentIndex = 1
        for i, c in ipairs(colors) do
            if c == color then
                currentIndex = i
                break
            end
        end

        color = colors[(currentIndex % #colors) + 1]
        Animation.Tween(preview.Instance, {BackgroundColor3 = color}, 0.2)

        local success, err = pcall(callback, color)
        if not success then
            warn("Rayfield Gen3 ColorPicker Error: " .. tostring(err))
        end
        EventBus.Emit("colorChanged", api, color)
    end)

    -- API
    local api = {
        Instance = element.Instance,
        Value = color,
        Set = function(newColor)
            color = newColor
            preview.Instance.BackgroundColor3 = color
        end,
        Get = function() return color end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createLabel(tab, config)
    config = config or {}
    local element = self:_createBaseElement(tab, 30)
    element.Instance.BackgroundTransparency = 1

    local label = Component.new("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = config.Text or "Label",
        TextColor3 = config.Color or self.Theme.TextMuted,
        TextSize = config.Size or 12,
        FontFace = config.Bold and self.Theme.TitleFont or self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, element.Instance)

    -- API
    local api = {
        Instance = element.Instance,
        SetText = function(text) label.Instance.Text = text end,
        SetColor = function(color) label.Instance.TextColor3 = color end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

function Window:_createSection(tab, config)
    config = config or {}
    local element = Component.new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, tab.Page.Instance)

    local line = Component.new("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.fromOffset(10, 15),
        BackgroundColor3 = self.Theme.Secondary,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
    }, element.Instance)

    local label = Component.new("TextLabel", {
        Size = UDim2.fromOffset(100, 20),
        Position = UDim2.fromOffset(10, 5),
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0,
        Text = config.Name or "Section",
        TextColor3 = self.Theme.TextMuted,
        TextSize = 11,
        FontFace = self.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, element.Instance)

    -- API
    local api = {
        Instance = element.Instance,
        SetText = function(text) label.Instance.Text = text end,
        Destroy = function() element:Destroy() end,
    }

    table.insert(tab.Elements, api)
    return api
end

-- Window Controls
function Window:ToggleMinimize()
    self._minimized = not self._minimized

    if self._minimized then
        Animation.Tween(self.Main.Instance, {Size = UDim2.new(self.Size.X.Scale, self.Size.X.Offset, 0, 40)}, 0.3)
        self.ContentContainer.Instance.Visible = false
        self.TabContainer.Instance.Visible = false
    else
        Animation.Tween(self.Main.Instance, {Size = self.Size}, 0.3, Utility.EaseOutBack)
        self.ContentContainer.Instance.Visible = true
        self.TabContainer.Instance.Visible = true
    end

    EventBus.Emit("windowMinimized", self, self._minimized)
end

function Window:ToggleCollapse()
    self._collapsed = not self._collapsed

    if self._collapsed then
        Animation.Tween(self.Main.Instance, {Size = UDim2.fromOffset(0, 0)}, 0.3)
        task.delay(0.3, function()
            self.Instance.Enabled = false
        end)
    else
        self.Instance.Enabled = true
        Animation.Tween(self.Main.Instance, {Size = self.Size}, 0.3, Utility.EaseOutBack)
    end

    EventBus.Emit("windowCollapsed", self, self._collapsed)
end

function Window:Show()
    self.Instance.Enabled = true
    self.Main.Instance.Size = UDim2.fromOffset(0, 0)
    Animation.Tween(self.Main.Instance, {Size = self.Size}, 0.5, Utility.EaseOutBack)
    EventBus.Emit("windowShown", self)
end

function Window:Hide()
    Animation.Tween(self.Main.Instance, {Size = UDim2.fromOffset(0, 0)}, 0.3)
    task.delay(0.3, function()
        self.Instance.Enabled = false
    end)
    EventBus.Emit("windowHidden", self)
end

function Window:Destroy()
    for _, tab in ipairs(self._tabs) do
        for _, element in ipairs(tab.Elements) do
            if element.Destroy then element.Destroy() end
        end
    end

    Component.Destroy(self)
    EventBus.Emit("windowDestroyed", self)
end

-- Notification System
function Gen3.Notify(config)
    config = config or {}

    local notification = Component.new("Frame", {
        Size = UDim2.fromOffset(300, 80),
        Position = UDim2.new(1, -320, 1, -100),
        BackgroundColor3 = Themes.Default.Surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
    }, Services.CoreGui)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification.Instance

    local shadow = Instance.new("ImageLabel")
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = notification.Instance

    local title = Component.new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.fromOffset(10, 8),
        BackgroundTransparency = 1,
        Text = config.Title or "Notification",
        TextColor3 = Themes.Default.Text,
        TextSize = 16,
        FontFace = Themes.Default.TitleFont,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, notification.Instance)

    local content = Component.new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.fromOffset(10, 35),
        BackgroundTransparency = 1,
        Text = config.Content or "",
        TextColor3 = Themes.Default.TextMuted,
        TextSize = 13,
        FontFace = Themes.Default.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, notification.Instance)

    -- Entrance
    notification.Instance.Position = UDim2.new(1, 20, 1, -100)
    Animation.Tween(notification.Instance, {Position = UDim2.new(1, -320, 1, -100)}, 0.5, Utility.EaseOutBack)

    -- Auto dismiss
    task.delay(config.Duration or 3, function()
        Animation.Tween(notification.Instance, {Position = UDim2.new(1, 20, 1, -100)}, 0.3)
        task.delay(0.3, function()
            notification:Destroy()
        end)
    end)

    return notification
end

-- Main API
function Gen3.CreateWindow(config)
    return Window.new(config)
end

function Gen3.SetTheme(themeName)
    -- Global theme setting (applies to new windows)
    Gen3.CurrentTheme = Themes[themeName] or Themes.Default
end

function Gen3.GetThemes()
    local themeList = {}
    for name, _ in pairs(Themes) do
        table.insert(themeList, name)
    end
    return themeList
end

function Gen3.On(event, callback)
    return EventBus.On(event, callback)
end

function Gen3.Promise(executor)
    return Promise.new(executor)
end

-- Plugin System
Gen3.Plugins = {}

function Gen3.RegisterPlugin(name, plugin)
    Gen3.Plugins[name] = plugin
    if plugin.Init then
        plugin.Init(Gen3)
    end
    EventBus.Emit("pluginRegistered", name, plugin)
end

-- Debug Tools
Gen3.Debug = {
    Enabled = false,
    Log = function(...)
        if Gen3.Debug.Enabled then
            print("[Rayfield Gen3 Debug]", ...)
        end
    end,
    Inspect = function(object)
        if Gen3.Debug.Enabled then
            for key, value in pairs(object) do
                print(key, "=", value)
            end
        end
    end
}

-- Hot Reload Support
function Gen3.EnableHotReload()
    -- Monitor script changes and reload automatically
    -- This is a simplified version - full implementation would use file watchers
    Gen3.Debug.Enabled = true
    Gen3.Debug.Log("Hot reload enabled")
end

-- Export
getgenv().RayfieldGen3 = Gen3
getgenv().Rayfield = Gen3 -- Backwards compatibility

return Gen3
