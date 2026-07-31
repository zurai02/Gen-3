-- Enhanced Rayfield Gen2 - Modern UI Library
-- Version: 2.1.0-Enhanced
-- Improvements: Animations, Accessibility, Performance, Modern Components

local EnhancedRayfield = {}
EnhancedRayfield.__version = "2.1.0-Enhanced"
EnhancedRayfield.__author = "Enhanced Community Edition"

-- =============================================================================
-- CORE ENHANCEMENTS MODULE
-- =============================================================================

local CoreEnhancements = {}

-- 1. ANIMATION SYSTEM OVERHAUL
CoreEnhancements.AnimationSystem = {
    _activeTweens = {},
    _easingFunctions = {
        -- Custom easing curves for modern feel
        spring = function(t, damping, stiffness)
            damping = damping or 0.8
            stiffness = stiffness or 300
            local omega = math.sqrt(stiffness)
            local zeta = damping / (2 * math.sqrt(stiffness))
            if zeta < 1 then
                local omegaD = omega * math.sqrt(1 - zeta * zeta)
                local theta = math.atan(omegaD / (zeta * omega))
                return 1 - math.exp(-zeta * omega * t) * math.cos(omegaD * t - theta) / math.cos(theta)
            else
                return 1 - math.exp(-omega * t) * (1 + omega * t)
            end
        end,

        elastic = function(t, amplitude, period)
            amplitude = amplitude or 1
            period = period or 0.3
            if t == 0 then return 0 end
            if t == 1 then return 1 end
            local s = period / 4
            return amplitude * math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / period) + 1
        end,

        bounce = function(t)
            local n1, d1 = 7.5625, 2.75
            if t < 1 / d1 then
                return n1 * t * t
            elseif t < 2 / d1 then
                t = t - 1.5 / d1
                return n1 * t * t + 0.75
            elseif t < 2.5 / d1 then
                t = t - 2.25 / d1
                return n1 * t * t + 0.9375
            else
                t = t - 2.625 / d1
                return n1 * t * t + 0.984375
            end
        end,

        smoothStep = function(t)
            return t * t * (3 - 2 * t)
        end,

        smootherStep = function(t)
            return t * t * t * (t * (t * 6 - 15) + 10)
        end
    },

    -- Spring-based tween for natural motion
    SpringTween = function(self, object, properties, targetValues, config)
        config = config or {}
        local damping = config.damping or 0.8
        local stiffness = config.stiffness or 300
        local mass = config.mass or 1
        local callback = config.callback

        local startTime = tick()
        local startValues = {}

        for prop, target in pairs(targetValues) do
            startValues[prop] = object[prop]
        end

        local connection
        connection = game:GetService("RunService").RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            local t = math.clamp(elapsed / (mass * 2), 0, 1)
            local eased = self._easingFunctions.spring(t, damping, stiffness)

            for prop, target in pairs(targetValues) do
                local start = startValues[prop]
                if typeof(start) == "UDim2" then
                    object[prop] = UDim2.new(
                        start.X.Scale + (target.X.Scale - start.X.Scale) * eased,
                        start.X.Offset + (target.X.Offset - start.X.Offset) * eased,
                        start.Y.Scale + (target.Y.Scale - start.Y.Scale) * eased,
                        start.Y.Offset + (target.Y.Offset - start.Y.Offset) * eased
                    )
                elseif typeof(start) == "Color3" then
                    object[prop] = start:Lerp(target, eased)
                elseif typeof(start) == "number" then
                    object[prop] = start + (target - start) * eased
                elseif typeof(start) == "Vector2" then
                    object[prop] = start:Lerp(target, eased)
                end
            end

            if t >= 1 then
                connection:Disconnect()
                if callback then callback() end
            end
        end)

        table.insert(self._activeTweens, connection)
        return connection
    end,

    -- Stagger animation for lists
    Stagger = function(self, objects, animationFunc, staggerDelay)
        staggerDelay = staggerDelay or 0.05
        for i, obj in ipairs(objects) do
            task.delay((i - 1) * staggerDelay, function()
                animationFunc(obj, i)
            end)
        end
    end,

    -- Parallax effect for backgrounds
    Parallax = function(self, layer, intensity, mousePos)
        intensity = intensity or 0.1
        local center = Vector2.new(0.5, 0.5)
        local offset = (mousePos - center) * intensity
        layer.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
    end
}

-- 2. ACCESSIBILITY SYSTEM
CoreEnhancements.Accessibility = {
    _enabled = true,
    _highContrast = false,
    _reducedMotion = false,
    _screenReader = false,
    _fontScale = 1,

    -- High contrast theme override
    HighContrastTheme = {
        WindowColor = Color3.fromRGB(0, 0, 0),
        ElementBackground = Color3.fromRGB(255, 255, 255),
        ElementStroke = Color3.fromRGB(255, 255, 0),
        ContentColor = Color3.fromRGB(255, 255, 255),
        AccentColor = Color3.fromRGB(0, 255, 255),
        TitlingColor = Color3.fromRGB(255, 255, 0),
    },

    -- Focus indicators
    CreateFocusIndicator = function(self, element)
        local indicator = Instance.new("UIStroke")
        indicator.Name = "FocusIndicator"
        indicator.Thickness = 3
        indicator.Color = Color3.fromRGB(0, 150, 255)
        indicator.Transparency = 0
        indicator.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        element.Focused:Connect(function()
            indicator.Parent = element
            indicator.Transparency = 0
        end)

        element.FocusLost:Connect(function()
            indicator.Transparency = 1
            task.delay(0.3, function()
                if indicator then indicator:Destroy() end
            end)
        end)

        return indicator
    end,

    -- ARIA-like labels for screen readers
    SetAriaLabel = function(self, element, label)
        element:SetAttribute("aria-label", label)
        element:SetAttribute("role", self:_getRole(element))
    end,

    _getRole = function(self, element)
        if element:IsA("TextButton") or element:IsA("ImageButton") then
            return "button"
        elseif element:IsA("TextBox") then
            return "textbox"
        elseif element:IsA("Frame") and element:GetAttribute("slider") then
            return "slider"
        else
            return "generic"
        end
    end,

    -- Keyboard navigation
    EnableKeyboardNavigation = function(self, window)
        local focusIndex = 1
        local focusableElements = {}

        local function updateFocusable()
            focusableElements = {}
            for _, child in ipairs(window:GetDescendants()) do
                if child:IsA("GuiButton") or child:IsA("TextBox") then
                    table.insert(focusableElements, child)
                end
            end
        end

        game:GetService("UserInputService").InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.Tab then
                updateFocusable()
                if #focusableElements > 0 then
                    if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
                        focusIndex = focusIndex - 1
                        if focusIndex < 1 then focusIndex = #focusableElements end
                    else
                        focusIndex = focusIndex + 1
                        if focusIndex > #focusableElements then focusIndex = 1 end
                    end

                    local target = focusableElements[focusIndex]
                    if target:IsA("TextBox") then
                        target:CaptureFocus()
                    end
                end
            end
        end)
    end
}

-- 3. PERFORMANCE OPTIMIZATIONS
CoreEnhancements.Performance = {
    _objectPool = {},
    _maxPoolSize = 50,
    _frameBudget = 16, -- ms per frame (60fps)
    _lastFrameTime = 0,

    -- Object pooling for frequently created/destroyed elements
    Acquire = function(self, className, properties)
        local pool = self._objectPool[className]
        if pool and #pool > 0 then
            local obj = table.remove(pool)
            for prop, val in pairs(properties or {}) do
                obj[prop] = val
            end
            obj.Visible = true
            return obj
        end
        return Instance.new(className)
    end,

    Release = function(self, object)
        local className = object.ClassName
        local pool = self._objectPool[className]
        if not pool then
            pool = {}
            self._objectPool[className] = pool
        end

        if #pool < self._maxPoolSize then
            object.Parent = nil
            object.Visible = false
            table.insert(pool, object)
        else
            object:Destroy()
        end
    end,

    -- Virtual scrolling for long lists
    VirtualScroll = function(self, scrollingFrame, itemHeight, totalItems, renderCallback)
        local visibleCount = math.ceil(scrollingFrame.AbsoluteSize.Y / itemHeight) + 2
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, totalItems * itemHeight)
        container.BackgroundTransparency = 1
        container.Parent = scrollingFrame

        local items = {}
        local function updateVisible()
            local scrollPos = scrollingFrame.CanvasPosition.Y
            local startIndex = math.floor(scrollPos / itemHeight)
            local endIndex = math.min(startIndex + visibleCount, totalItems - 1)

            -- Recycle items
            for i, item in pairs(items) do
                if i < startIndex or i > endIndex then
                    item.Visible = false
                end
            end

            for i = startIndex, endIndex do
                if not items[i] then
                    items[i] = renderCallback(i, container)
                end
                items[i].Visible = true
                items[i].Position = UDim2.new(0, 0, 0, i * itemHeight)
            end
        end

        scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisible)
        updateVisible()
    end,

    -- Frame time budgeting
    ShouldYield = function(self)
        return (tick() - self._lastFrameTime) * 1000 > self._frameBudget
    end,

    MarkFrame = function(self)
        self._lastFrameTime = tick()
    end
}

-- 4. MODERN COMPONENT ENHANCEMENTS
CoreEnhancements.ModernComponents = {

    -- Chip/Tag component with removable chips
    CreateChip = function(self, parent, config)
        config = config or {}
        local chip = Instance.new("Frame")
        chip.Name = config.name or "Chip"
        chip.Size = UDim2.new(0, 0, 0, 32)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = config.backgroundColor or Color3.fromRGB(45, 45, 45)
        chip.BorderSizePixel = 0
        chip.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = chip

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 12)
        padding.Parent = chip

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 6)
        layout.Parent = chip

        if config.icon then
            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.fromOffset(16, 16)
            icon.BackgroundTransparency = 1
            icon.Image = config.icon
            icon.ImageColor3 = config.iconColor or Color3.fromRGB(255, 255, 255)
            icon.Parent = chip
        end

        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromOffset(0, 20)
        text.AutomaticSize = Enum.AutomaticSize.X
        text.BackgroundTransparency = 1
        text.Text = config.text or "Chip"
        text.TextColor3 = config.textColor or Color3.fromRGB(255, 255, 255)
        text.TextSize = 14
        text.Font = Enum.Font.GothamMedium
        text.Parent = chip

        if config.removable then
            local removeBtn = Instance.new("TextButton")
            removeBtn.Size = UDim2.fromOffset(16, 16)
            removeBtn.BackgroundTransparency = 1
            removeBtn.Text = "✕"
            removeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            removeBtn.TextSize = 12
            removeBtn.Parent = chip

            removeBtn.MouseEnter:Connect(function()
                removeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
            end)
            removeBtn.MouseLeave:Connect(function()
                removeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            end)

            removeBtn.MouseButton1Click:Connect(function()
                if config.onRemove then
                    config.onRemove(chip)
                end
                chip:Destroy()
            end)
        end

        -- Hover effect
        chip.MouseEnter:Connect(function()
            chip.BackgroundColor3 = config.hoverColor or Color3.fromRGB(60, 60, 60)
        end)
        chip.MouseLeave:Connect(function()
            chip.BackgroundColor3 = config.backgroundColor or Color3.fromRGB(45, 45, 45)
        end)

        return chip
    end,

    -- Skeleton loader for async content
    CreateSkeleton = function(self, parent, config)
        config = config or {}
        local skeleton = Instance.new("Frame")
        skeleton.Name = "Skeleton"
        skeleton.Size = config.size or UDim2.new(1, 0, 0, 60)
        skeleton.BackgroundTransparency = 1
        skeleton.Parent = parent

        local shimmer = Instance.new("Frame")
        shimmer.Name = "Shimmer"
        shimmer.Size = UDim2.new(0.3, 0, 1, 0)
        shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
        shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        shimmer.BackgroundTransparency = 0.8
        shimmer.Parent = skeleton

        local gradient = Instance.new("UIGradient")
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.5),
            NumberSequenceKeypoint.new(1, 1)
        })
        gradient.Rotation = 15
        gradient.Parent = shimmer

        -- Shimmer animation
        local tweenService = game:GetService("TweenService")
        local function animate()
            shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
            local tween = tweenService:Create(shimmer, TweenInfo.new(1.5, Enum.EasingStyle.Quart), {
                Position = UDim2.new(1, 0, 0, 0)
            })
            tween:Play()
            tween.Completed:Wait()
            if skeleton and skeleton.Parent then
                task.wait(0.5)
                animate()
            end
        end
        task.spawn(animate)

        skeleton.Destroying:Connect(function()
            shimmer = nil
        end)

        return skeleton
    end,

    -- Tooltip system
    CreateTooltip = function(self, parent, config)
        config = config or {}
        local tooltip = Instance.new("Frame")
        tooltip.Name = "Tooltip"
        tooltip.Size = UDim2.new(0, 0, 0, 28)
        tooltip.AutomaticSize = Enum.AutomaticSize.X
        tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        tooltip.BorderSizePixel = 0
        tooltip.ZIndex = 1000
        tooltip.Visible = false
        tooltip.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = tooltip

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
        padding.Parent = tooltip

        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromOffset(0, 28)
        text.AutomaticSize = Enum.AutomaticSize.X
        text.BackgroundTransparency = 1
        text.Text = config.text or "Tooltip"
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextSize = 13
        text.Font = Enum.Font.GothamMedium
        text.Parent = tooltip

        local arrow = Instance.new("Frame")
        arrow.Size = UDim2.fromOffset(8, 8)
        arrow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        arrow.BorderSizePixel = 0
        arrow.Rotation = 45
        arrow.Parent = tooltip

        return tooltip
    end,

    -- Progress ring/circular progress
    CreateCircularProgress = function(self, parent, config)
        config = config or {}
        local size = config.size or 60
        local progress = config.progress or 0

        local container = Instance.new("Frame")
        container.Size = UDim2.fromOffset(size, size)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local bg = Instance.new("Frame")
        bg.Name = "Background"
        bg.Size = UDim2.fromScale(1, 1)
        bg.BackgroundTransparency = 1
        bg.Parent = container

        -- Create circular progress using image or custom drawing
        local progressLabel = Instance.new("TextLabel")
        progressLabel.Name = "ProgressText"
        progressLabel.Size = UDim2.fromScale(1, 1)
        progressLabel.BackgroundTransparency = 1
        progressLabel.Text = tostring(math.floor(progress * 100)) .. "%"
        progressLabel.TextColor3 = config.textColor or Color3.fromRGB(255, 255, 255)
        progressLabel.TextSize = 16
        progressLabel.Font = Enum.Font.GothamBold
        progressLabel.Parent = container

        local function setProgress(value)
            progress = math.clamp(value, 0, 1)
            progressLabel.Text = tostring(math.floor(progress * 100)) .. "%"
            -- Update visual ring here
        end

        return {
            Instance = container,
            SetProgress = setProgress,
            GetProgress = function() return progress end
        }
    end,

    -- Segmented control (iOS-style)
    CreateSegmentedControl = function(self, parent, config)
        config = config or {}
        local options = config.options or {"Option 1", "Option 2"}
        local selectedIndex = config.selectedIndex or 1
        local callback = config.callback or function() end

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 36)
        container.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        container.BorderSizePixel = 0
        container.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 2)
        layout.Parent = container

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 2)
        padding.PaddingRight = UDim.new(0, 2)
        padding.Parent = container

        local buttons = {}
        local indicator = Instance.new("Frame")
        indicator.Name = "Indicator"
        indicator.BackgroundColor3 = config.indicatorColor or Color3.fromRGB(60, 60, 60)
        indicator.BorderSizePixel = 0
        indicator.ZIndex = 2
        indicator.Parent = container

        local indicatorCorner = Instance.new("UICorner")
        indicatorCorner.CornerRadius = UDim.new(0, 6)
        indicatorCorner.Parent = indicator

        for i, option in ipairs(options) do
            local btn = Instance.new("TextButton")
            btn.Name = option
            btn.Size = UDim2.new(1 / #options, -2, 1, -4)
            btn.BackgroundTransparency = 1
            btn.Text = option
            btn.TextColor3 = i == selectedIndex and (config.activeTextColor or Color3.fromRGB(255, 255, 255)) or (config.inactiveTextColor or Color3.fromRGB(150, 150, 150))
            btn.TextSize = 14
            btn.Font = Enum.Font.GothamMedium
            btn.ZIndex = 3
            btn.Parent = container

            table.insert(buttons, btn)

            btn.MouseButton1Click:Connect(function()
                selectedIndex = i
                callback(option, i)

                for j, b in ipairs(buttons) do
                    b.TextColor3 = j == selectedIndex and (config.activeTextColor or Color3.fromRGB(255, 255, 255)) or (config.inactiveTextColor or Color3.fromRGB(150, 150, 150))
                end

                local tweenService = game:GetService("TweenService")
                tweenService:Create(indicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                    Position = btn.Position,
                    Size = btn.Size
                }):Play()
            end)
        end

        -- Position indicator initially
        task.delay(0.1, function()
            if buttons[selectedIndex] then
                indicator.Position = buttons[selectedIndex].Position
                indicator.Size = buttons[selectedIndex].Size
            end
        end)

        return {
            Instance = container,
            GetSelected = function() return options[selectedIndex], selectedIndex end,
            SetSelected = function(index)
                if buttons[index] then
                    buttons[index].MouseButton1Click:Fire()
                end
            end
        }
    end,

    -- Floating action button (FAB)
    CreateFAB = function(self, parent, config)
        config = config or {}
        local fab = Instance.new("ImageButton")
        fab.Name = "FAB"
        fab.Size = UDim2.fromOffset(56, 56)
        fab.Position = config.position or UDim2.new(1, -76, 1, -76)
        fab.AnchorPoint = Vector2.new(0, 0)
        fab.BackgroundColor3 = config.backgroundColor or Color3.fromRGB(0, 150, 255)
        fab.Image = config.icon or ""
        fab.ImageColor3 = config.iconColor or Color3.fromRGB(255, 255, 255)
        fab.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = fab

        local shadow = Instance.new("ImageLabel")
        shadow.Name = "Shadow"
        shadow.Size = UDim2.new(1, 8, 1, 8)
        shadow.Position = UDim2.new(0, -4, 0, -4)
        shadow.BackgroundTransparency = 1
        shadow.Image = "rbxassetid://1316045217" -- shadow image
        shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
        shadow.ImageTransparency = 0.6
        shadow.ZIndex = -1
        shadow.Parent = fab

        -- Ripple effect
        fab.MouseButton1Down:Connect(function()
            local ripple = Instance.new("Frame")
            ripple.Size = UDim2.fromOffset(0, 0)
            ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
            ripple.AnchorPoint = Vector2.new(0.5, 0.5)
            ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ripple.BackgroundTransparency = 0.7
            ripple.BorderSizePixel = 0
            ripple.ZIndex = 2
            ripple.Parent = fab

            local rippleCorner = Instance.new("UICorner")
            rippleCorner.CornerRadius = UDim.new(1, 0)
            rippleCorner.Parent = ripple

            local tweenService = game:GetService("TweenService")
            tweenService:Create(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {
                Size = UDim2.new(1.5, 0, 1.5, 0),
                BackgroundTransparency = 1
            }):Play()

            task.delay(0.5, function()
                ripple:Destroy()
            end)
        end)

        -- Hover scale
        fab.MouseEnter:Connect(function()
            local tweenService = game:GetService("TweenService")
            tweenService:Create(fab, TweenInfo.new(0.2), {
                Size = UDim2.fromOffset(60, 60)
            }):Play()
        end)

        fab.MouseLeave:Connect(function()
            local tweenService = game:GetService("TweenService")
            tweenService:Create(fab, TweenInfo.new(0.2), {
                Size = UDim2.fromOffset(56, 56)
            }):Play()
        end)

        return fab
    end,

    -- Timeline component
    CreateTimeline = function(self, parent, config)
        config = config or {}
        local items = config.items or {}

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, #items * 60)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 0)
        layout.Parent = container

        for i, item in ipairs(items) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 60)
            row.BackgroundTransparency = 1
            row.Parent = container

            -- Timeline line
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0, 2, 1, 0)
            line.Position = UDim2.new(0, 20, 0, 0)
            line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            line.BorderSizePixel = 0
            line.Parent = row

            if i == #items then
                line.Size = UDim2.new(0, 2, 0, 30)
            end

            -- Dot
            local dot = Instance.new("Frame")
            dot.Size = UDim2.fromOffset(12, 12)
            dot.Position = UDim2.new(0, 15, 0, 14)
            dot.BackgroundColor3 = item.completed and (config.completedColor or Color3.fromRGB(0, 200, 100)) or (config.pendingColor or Color3.fromRGB(150, 150, 150))
            dot.BorderSizePixel = 0
            dot.Parent = row

            local dotCorner = Instance.new("UICorner")
            dotCorner.CornerRadius = UDim.new(1, 0)
            dotCorner.Parent = dot

            -- Content
            local content = Instance.new("Frame")
            content.Size = UDim2.new(1, -50, 1, 0)
            content.Position = UDim2.new(0, 40, 0, 0)
            content.BackgroundTransparency = 1
            content.Parent = row

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 20)
            title.Position = UDim2.new(0, 0, 0, 10)
            title.BackgroundTransparency = 1
            title.Text = item.title or "Step " .. i
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.TextSize = 14
            title.Font = Enum.Font.GothamMedium
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = content

            if item.description then
                local desc = Instance.new("TextLabel")
                desc.Size = UDim2.new(1, 0, 0, 16)
                desc.Position = UDim2.new(0, 0, 0, 30)
                desc.BackgroundTransparency = 1
                desc.Text = item.description
                desc.TextColor3 = Color3.fromRGB(180, 180, 180)
                desc.TextSize = 12
                desc.Font = Enum.Font.Gotham
                desc.TextXAlignment = Enum.TextXAlignment.Left
                desc.Parent = content
            end
        end

        return container
    end
}

-- 5. THEME SYSTEM ENHANCEMENTS
CoreEnhancements.ThemeSystem = {
    _currentTheme = "default",
    _themes = {},
    _listeners = {},

    -- Glassmorphism theme
    GlassTheme = {
        name = "Glass",
        WindowColor = Color3.fromRGB(20, 20, 30),
        WindowTransparency = 0.3,
        ElementBackground = Color3.fromRGB(255, 255, 255),
        ElementTransparency = 0.85,
        ElementStroke = Color3.fromRGB(255, 255, 255),
        ElementStrokeTransparency = 0.9,
        ContentColor = Color3.fromRGB(255, 255, 255),
        AccentColor = Color3.fromRGB(100, 150, 255),
        TitlingColor = Color3.fromRGB(255, 255, 255),
        BlurEnabled = true,
        BlurIntensity = 15,
        CornerRadius = 12,
    },

    -- Neon/Cyberpunk theme
    NeonTheme = {
        name = "Neon",
        WindowColor = Color3.fromRGB(10, 10, 20),
        ElementBackground = Color3.fromRGB(20, 20, 40),
        ElementStroke = Color3.fromRGB(0, 255, 255),
        ContentColor = Color3.fromRGB(0, 255, 255),
        AccentColor = Color3.fromRGB(255, 0, 255),
        TitlingColor = Color3.fromRGB(0, 255, 255),
        GlowEnabled = true,
        GlowColor = Color3.fromRGB(0, 255, 255),
        CornerRadius = 4,
    },

    -- Minimal/Apple-style theme
    MinimalTheme = {
        name = "Minimal",
        WindowColor = Color3.fromRGB(245, 245, 247),
        ElementBackground = Color3.fromRGB(255, 255, 255),
        ElementStroke = Color3.fromRGB(200, 200, 200),
        ContentColor = Color3.fromRGB(30, 30, 30),
        AccentColor = Color3.fromRGB(0, 122, 255),
        TitlingColor = Color3.fromRGB(0, 0, 0),
        Font = Enum.Font.SFPro,
        CornerRadius = 10,
        ShadowEnabled = true,
    },

    RegisterTheme = function(self, name, theme)
        self._themes[name] = theme
    end,

    ApplyTheme = function(self, name, window)
        local theme = self._themes[name] or self._themes["default"]
        self._currentTheme = name

        -- Apply to window
        if window then
            if theme.BlurEnabled then
                -- Add blur effect
                local blur = Instance.new("BlurEffect")
                blur.Size = theme.BlurIntensity or 10
                blur.Parent = game:GetService("Lighting")
            end

            -- Notify listeners
            for _, listener in ipairs(self._listeners) do
                listener(theme)
            end
        end

        return theme
    end,

    OnThemeChange = function(self, callback)
        table.insert(self._listeners, callback)
    end
}

-- Register built-in themes
CoreEnhancements.ThemeSystem:RegisterTheme("glass", CoreEnhancements.ThemeSystem.GlassTheme)
CoreEnhancements.ThemeSystem:RegisterTheme("neon", CoreEnhancements.ThemeSystem.NeonTheme)
CoreEnhancements.ThemeSystem:RegisterTheme("minimal", CoreEnhancements.ThemeSystem.MinimalTheme)

-- 6. DATA BINDING SYSTEM
CoreEnhancements.DataBinding = {
    _bindings = {},

    CreateBinding = function(self, initialValue)
        local binding = {
            _value = initialValue,
            _listeners = {},

            Get = function(this)
                return this._value
            end,

            Set = function(this, newValue)
                if this._value ~= newValue then
                    this._value = newValue
                    for _, listener in ipairs(this._listeners) do
                        listener(newValue)
                    end
                end
            end,

            Connect = function(this, callback)
                table.insert(this._listeners, callback)
                callback(this._value) -- Initial call
                return function()
                    for i, l in ipairs(this._listeners) do
                        if l == callback then
                            table.remove(this._listeners, i)
                            break
                        end
                    end
                end
            end
        }

        return binding
    end,

    -- Two-way binding for input elements
    BindToTextBox = function(self, textBox, binding)
        local connection = binding:Connect(function(value)
            if textBox.Text ~= tostring(value) then
                textBox.Text = tostring(value)
            end
        end)

        textBox.FocusLost:Connect(function()
            binding:Set(textBox.Text)
        end)

        return connection
    end,

    BindToToggle = function(self, toggle, binding)
        local connection = binding:Connect(function(value)
            -- Update toggle visual state
            if toggle.Set then
                toggle:Set(value)
            end
        end)

        -- Assuming toggle has a callback
        if toggle.callback then
            local originalCallback = toggle.callback
            toggle.callback = function(value)
                binding:Set(value)
                if originalCallback then
                    originalCallback(value)
                end
            end
        end

        return connection
    end
}

-- 7. NOTIFICATION ENHANCEMENTS
CoreEnhancements.NotificationSystem = {
    _queue = {},
    _maxVisible = 3,
    _currentNotifications = {},

    -- Rich notification with actions
    ShowRichNotification = function(self, config)
        config = config or {}
        local notification = {
            title = config.title or "Notification",
            message = config.message or "",
            type = config.type or "info", -- info, success, warning, error
            duration = config.duration or 5,
            actions = config.actions or {},
            icon = config.icon,
            progress = config.progress, -- Optional progress bar
        }

        table.insert(self._queue, notification)
        self:_processQueue()

        return notification
    end,

    _processQueue = function(self)
        while #self._queue > 0 and #self._currentNotifications < self._maxVisible do
            local notif = table.remove(self._queue, 1)
            self:_displayNotification(notif)
        end
    end,

    _displayNotification = function(self, notif)
        -- Create notification UI
        local colors = {
            info = Color3.fromRGB(0, 150, 255),
            success = Color3.fromRGB(0, 200, 100),
            warning = Color3.fromRGB(255, 180, 0),
            error = Color3.fromRGB(255, 80, 80)
        }

        -- Implementation would create the actual UI here
        -- This is a simplified version
        print(string.format("[Notification] %s: %s", notif.title, notif.message))
    end
}

-- 8. DRAG AND DROP SYSTEM
CoreEnhancements.DragDrop = {
    _draggableItems = {},
    _dropZones = {},

    MakeDraggable = function(self, element, config)
        config = config or {}
        local dragData = {
            element = element,
            dragStarted = config.onDragStart,
            dragEnded = config.onDragEnd,
            dragPreview = config.preview,
            isDragging = false,
            startPos = nil,
            offset = nil
        }

        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragData.isDragging = true
                dragData.startPos = element.Position
                dragData.offset = Vector2.new(input.Position.X, input.Position.Y) - 
                                  Vector2.new(element.AbsolutePosition.X, element.AbsolutePosition.Y)

                if dragData.dragStarted then
                    dragData.dragStarted(element)
                end
            end
        end)

        game:GetService("UserInputService").InputChanged:Connect(function(input)
            if dragData.isDragging and 
               (input.UserInputType == Enum.UserInputType.MouseMovement or 
                input.UserInputType == Enum.UserInputType.Touch) then
                local newPos = Vector2.new(input.Position.X, input.Position.Y) - dragData.offset
                element.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
            end
        end)

        game:GetService("UserInputService").InputEnded:Connect(function(input)
            if dragData.isDragging and 
               (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                input.UserInputType == Enum.UserInputType.Touch) then
                dragData.isDragging = false

                -- Check drop zones
                for _, zone in ipairs(self._dropZones) do
                    if self:_isInZone(element, zone) then
                        if zone.onDrop then
                            zone.onDrop(element, zone.element)
                        end
                    end
                end

                if dragData.dragEnded then
                    dragData.dragEnded(element)
                end
            end
        end)

        table.insert(self._draggableItems, dragData)
        return dragData
    end,

    CreateDropZone = function(self, element, config)
        config = config or {}
        local zone = {
            element = element,
            onDrop = config.onDrop,
            onEnter = config.onEnter,
            onLeave = config.onLeave,
            highlightColor = config.highlightColor or Color3.fromRGB(0, 150, 255)
        }
        table.insert(self._dropZones, zone)
        return zone
    end,

    _isInZone = function(self, item, zone)
        local itemCenter = Vector2.new(
            item.AbsolutePosition.X + item.AbsoluteSize.X / 2,
            item.AbsolutePosition.Y + item.AbsoluteSize.Y / 2
        )
        local zonePos = zone.element.AbsolutePosition
        local zoneSize = zone.element.AbsoluteSize

        return itemCenter.X >= zonePos.X and itemCenter.X <= zonePos.X + zoneSize.X and
               itemCenter.Y >= zonePos.Y and itemCenter.Y <= zonePos.Y + zoneSize.Y
    end
}

-- 9. GESTURE SUPPORT
CoreEnhancements.Gestures = {
    _gestureListeners = {},

    -- Swipe detection
    DetectSwipe = function(self, element, config)
        config = config or {}
        local threshold = config.threshold or 50
        local onSwipeLeft = config.onSwipeLeft
        local onSwipeRight = config.onSwipeRight
        local onSwipeUp = config.onSwipeUp
        local onSwipeDown = config.onSwipeDown

        local startPos = nil
        local startTime = nil

        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or 
               input.UserInputType == Enum.UserInputType.MouseButton1 then
                startPos = Vector2.new(input.Position.X, input.Position.Y)
                startTime = tick()
            end
        end)

        element.InputEnded:Connect(function(input)
            if startPos and (input.UserInputType == Enum.UserInputType.Touch or 
                            input.UserInputType == Enum.UserInputType.MouseButton1) then
                local endPos = Vector2.new(input.Position.X, input.Position.Y)
                local delta = endPos - startPos
                local elapsed = tick() - startTime

                -- Check velocity
                local velocity = delta.Magnitude / elapsed

                if delta.Magnitude > threshold and velocity > 500 then
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        if delta.X > 0 and onSwipeRight then
                            onSwipeRight()
                        elseif delta.X < 0 and onSwipeLeft then
                            onSwipeLeft()
                        end
                    else
                        if delta.Y > 0 and onSwipeDown then
                            onSwipeDown()
                        elseif delta.Y < 0 and onSwipeUp then
                            onSwipeUp()
                        end
                    end
                end

                startPos = nil
            end
        end)
    end,

    -- Pinch to zoom
    DetectPinch = function(self, element, config)
        config = config or {}
        local onPinch = config.onPinch or function() end

        local initialDistance = nil
        local initialScale = element.Size

        -- Simplified pinch detection (would need multi-touch handling)
        -- This is a placeholder for the concept
    end
}

-- 10. INTERNATIONALIZATION (i18n)
CoreEnhancements.I18n = {
    _currentLocale = "en",
    _translations = {},
    _fallbackLocale = "en",

    LoadTranslations = function(self, locale, translations)
        self._translations[locale] = translations
    end,

    SetLocale = function(self, locale)
        self._currentLocale = locale
    end,

    T = function(self, key, params)
        local translations = self._translations[self._currentLocale] or 
                          self._translations[self._fallbackLocale] or {}
        local text = translations[key] or key

        if params then
            for k, v in pairs(params) do
                text = text:gsub("{{" .. k .. "}}", tostring(v))
            end
        end

        return text
    end,

    -- RTL support detection
    IsRTL = function(self, locale)
        local rtlLocales = {ar = true, he = true, fa = true, ur = true}
        return rtlLocales[locale or self._currentLocale] or false
    end
}

-- =============================================================================
-- ENHANCED RAYFIELD API
-- =============================================================================

function EnhancedRayfield:CreateWindow(config)
    config = config or {}

    -- Apply enhancements to base config
    config.enhanced = true
    config.animationSystem = CoreEnhancements.AnimationSystem
    config.accessibility = CoreEnhancements.Accessibility
    config.performance = CoreEnhancements.Performance

    -- Create enhanced window (would integrate with base Rayfield)
    local window = {
        _config = config,
        _tabs = {},
        _enhancements = CoreEnhancements,

        -- Enhanced methods
        CreateTab = function(self, tabConfig)
            tabConfig = tabConfig or {}
            local tab = {
                _elements = {},
                _window = self,

                CreateButton = function(t, btnConfig)
                    btnConfig = btnConfig or {}
                    -- Add enhanced button with ripple, better animations
                    print(string.format("[Enhanced] Created button: %s", btnConfig.name or "Unnamed"))
                    return {type = "Button", config = btnConfig}
                end,

                CreateToggle = function(t, toggleConfig)
                    toggleConfig = toggleConfig or {}
                    print(string.format("[Enhanced] Created toggle: %s", toggleConfig.name or "Unnamed"))
                    return {type = "Toggle", config = toggleConfig}
                end,

                CreateSlider = function(t, sliderConfig)
                    sliderConfig = sliderConfig or {}
                    print(string.format("[Enhanced] Created slider: %s", sliderConfig.name or "Unnamed"))
                    return {type = "Slider", config = sliderConfig}
                end,

                CreateDropdown = function(t, dropdownConfig)
                    dropdownConfig = dropdownConfig or {}
                    print(string.format("[Enhanced] Created dropdown: %s", dropdownConfig.name or "Unnamed"))
                    return {type = "Dropdown", config = dropdownConfig}
                end,

                CreateInput = function(t, inputConfig)
                    inputConfig = inputConfig or {}
                    print(string.format("[Enhanced] Created input: %s", inputConfig.name or "Unnamed"))
                    return {type = "Input", config = inputConfig}
                end,

                CreateKeybind = function(t, keybindConfig)
                    keybindConfig = keybindConfig or {}
                    print(string.format("[Enhanced] Created keybind: %s", keybindConfig.name or "Unnamed"))
                    return {type = "Keybind", config = keybindConfig}
                end,

                CreateColorPicker = function(t, colorConfig)
                    colorConfig = colorConfig or {}
                    print(string.format("[Enhanced] Created color picker: %s", colorConfig.name or "Unnamed"))
                    return {type = "ColorPicker", config = colorConfig}
                end,

                CreateStat = function(t, statConfig)
                    statConfig = statConfig or {}
                    print(string.format("[Enhanced] Created stat: %s", statConfig.name or "Unnamed"))
                    return {type = "Stat", config = statConfig}
                end,

                -- NEW: Enhanced components
                CreateChip = function(t, chipConfig)
                    return CoreEnhancements.ModernComponents:CreateChip(nil, chipConfig)
                end,

                CreateSegmentedControl = function(t, segConfig)
                    return CoreEnhancements.ModernComponents:CreateSegmentedControl(nil, segConfig)
                end,

                CreateTimeline = function(t, timelineConfig)
                    return CoreEnhancements.ModernComponents:CreateTimeline(nil, timelineConfig)
                end,

                CreateFAB = function(t, fabConfig)
                    return CoreEnhancements.ModernComponents:CreateFAB(nil, fabConfig)
                end
            }

            table.insert(self._tabs, tab)
            return tab
        end,

        -- Theme management
        SetTheme = function(self, themeName)
            return CoreEnhancements.ThemeSystem:ApplyTheme(themeName, self)
        end,

        -- Notification system
        Notify = function(self, notifConfig)
            return CoreEnhancements.NotificationSystem:ShowRichNotification(notifConfig)
        end,

        -- Data binding
        CreateBinding = function(self, initialValue)
            return CoreEnhancements.DataBinding:CreateBinding(initialValue)
        end,

        -- Accessibility
        EnableAccessibility = function(self)
            CoreEnhancements.Accessibility:EnableKeyboardNavigation(self)
        end,

        -- Performance
        EnableVirtualScroll = function(self, scrollingFrame, itemHeight, totalItems, renderCallback)
            CoreEnhancements.Performance:VirtualScroll(scrollingFrame, itemHeight, totalItems, renderCallback)
        end
    }

    print(string.format("[Enhanced Rayfield] Created window: %s v%s", 
        config.name or "Unnamed", EnhancedRayfield.__version))

    return window
end

-- Export enhancements for advanced usage
EnhancedRayfield.Core = CoreEnhancements
EnhancedRayfield.Animation = CoreEnhancements.AnimationSystem
EnhancedRayfield.Accessibility = CoreEnhancements.Accessibility
EnhancedRayfield.Performance = CoreEnhancements.Performance
EnhancedRayfield.Theme = CoreEnhancements.ThemeSystem
EnhancedRayfield.Binding = CoreEnhancements.DataBinding
EnhancedRayfield.Notification = CoreEnhancements.NotificationSystem
EnhancedRayfield.DragDrop = CoreEnhancements.DragDrop
EnhancedRayfield.Gestures = CoreEnhancements.Gestures
EnhancedRayfield.I18n = CoreEnhancements.I18n
EnhancedRayfield.Components = CoreEnhancements.ModernComponents

return EnhancedRayfield
