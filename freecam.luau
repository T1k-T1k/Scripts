-- FreeCam Script for roblox
local pi    = math.pi
local abs   = math.abs
local clamp = math.clamp
local exp   = math.exp
local rad   = math.rad
local sign  = math.sign
local sqrt  = math.sqrt
local tan   = math.tan

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Settings = UserSettings()
local GameSettings = Settings.GameSettings

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

local FFlagUserExitFreecamBreaksWithShiftlock
do
    local success, result = pcall(function()
        return UserSettings():IsUserFeatureEnabled("UserExitFreecamBreaksWithShiftlock")
    end)
    FFlagUserExitFreecamBreaksWithShiftlock = success and result
end

------------------------------------------------------------------------

-- GUI Configuration
local GUI_CONFIG = {
    speedMultiplier = 1,
    keyboardShortcutEnabled = true,
    guiVisible = true,
    disableCursor = true
}

local TOGGLE_INPUT_PRIORITY = Enum.ContextActionPriority.Low.Value
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value
local FREECAM_MACRO_KB = {Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift, Enum.KeyCode.P}

local NAV_GAIN = Vector3.new(1, 1, 1)*64
local PAN_GAIN = Vector2.new(0.75, 1)*8
local FOV_GAIN = 300

local PITCH_LIMIT = rad(90)

local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = 1.0
local FOV_STIFFNESS = 4.0

------------------------------------------------------------------------

local Spring = {} do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos*0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f*2*pi
		local p0 = self.p
		local v0 = self.v

		local offset = goal - p0
		local decay = exp(-f*dt)

		local p1 = goal + (v0*dt - offset*(f*dt + 1))*decay
		local v1 = (f*dt*(offset*f - v0) + v0)*decay

		self.p = p1
		self.v = v1

		return p1
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos*0
	end
end

------------------------------------------------------------------------

local cameraPos = Vector3.new()
local cameraRot = Vector2.new()
local cameraFov = 0

local velSpring = Spring.new(VEL_STIFFNESS, Vector3.new())
local panSpring = Spring.new(PAN_STIFFNESS, Vector2.new())
local fovSpring = Spring.new(FOV_STIFFNESS, 0)

-- Function to update cursor visibility based on FreeCam state and settings
local function UpdateCursorVisibility()
	local enabled = getgenv().freecamEnabled or false
	if enabled then
		-- If FreeCam is enabled, respect the disableCursor setting
		UserInputService.MouseIconEnabled = not GUI_CONFIG.disableCursor
	else
		-- If FreeCam is disabled, always show cursor
		UserInputService.MouseIconEnabled = true
	end
end

------------------------------------------------------------------------

-- GUI Creation
local function CreateGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FreeCamGUI"
	screenGui.DisplayOrder = 100
	screenGui.ResetOnSpawn = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Main Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 300, 0, 230)
	mainFrame.Position = UDim2.new(0, 20, 0, 20)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleBar

	-- Fix corner overlap
	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 8)
	titleFix.Position = UDim2.new(0, 0, 1, -8)
	titleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	-- Title text
	local titleText = Instance.new("TextLabel")
	titleText.Name = "TitleText"
	titleText.Size = UDim2.new(1, -60, 1, 0)
	titleText.Position = UDim2.new(0, 10, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "FreeCam Settings"
	titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleText.TextScaled = true
	titleText.Font = Enum.Font.SourceSansBold
	titleText.Parent = titleBar

	-- Minimize button
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Name = "MinimizeButton"
	minimizeButton.Size = UDim2.new(0, 25, 0, 25)
	minimizeButton.Position = UDim2.new(1, -35, 0, 2.5)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	minimizeButton.BorderSizePixel = 0
	minimizeButton.Text = "_"
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.TextScaled = true
	minimizeButton.Font = Enum.Font.SourceSansBold
	minimizeButton.Parent = titleBar

	local minimizeCorner = Instance.new("UICorner")
	minimizeCorner.CornerRadius = UDim.new(0, 4)
	minimizeCorner.Parent = minimizeButton

	-- Content frame
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -40)
	contentFrame.Position = UDim2.new(0, 10, 0, 35)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	-- Speed label
	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedLabel"
	speedLabel.Size = UDim2.new(1, 0, 0, 25)
	speedLabel.Position = UDim2.new(0, 0, 0, 10)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "FreeCam Speed: 1.0x"
	speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedLabel.TextScaled = true
	speedLabel.Font = Enum.Font.SourceSans
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = contentFrame

	-- Speed slider background
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderBg"
	sliderBg.Size = UDim2.new(0.95, 0, 0, 20)
	sliderBg.Position = UDim2.new(0, 8, 0, 40)
	sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = contentFrame

	local sliderBgCorner = Instance.new("UICorner")
	sliderBgCorner.CornerRadius = UDim.new(0, 10)
	sliderBgCorner.Parent = sliderBg

	-- Speed slider fill
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "SliderFill"
	sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
	sliderFill.Position = UDim2.new(0, 0, 0, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg

	local sliderFillCorner = Instance.new("UICorner")
	sliderFillCorner.CornerRadius = UDim.new(0, 10)
	sliderFillCorner.Parent = sliderFill

	-- Speed slider handle
	local sliderHandle = Instance.new("TextButton")
	sliderHandle.Name = "SliderHandle"
	sliderHandle.Size = UDim2.new(0, 28, 0, 28)
	sliderHandle.Position = UDim2.new(0.5, -15, 0.5, -15)
	sliderHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderHandle.BorderSizePixel = 0
	sliderHandle.Text = ""
	sliderHandle.Parent = sliderBg

	local sliderHandleCorner = Instance.new("UICorner")
	sliderHandleCorner.CornerRadius = UDim.new(0, 15)
	sliderHandleCorner.Parent = sliderHandle

	-- Shortcut toggle
	local shortcutLabel = Instance.new("TextLabel")
	shortcutLabel.Name = "ShortcutLabel"
	shortcutLabel.Size = UDim2.new(1, -60, 0, 25)
	shortcutLabel.Position = UDim2.new(0, 0, 0, 80)
	shortcutLabel.BackgroundTransparency = 1
	shortcutLabel.Text = "Keyboard Shortcut (Ctrl+Shift+P):"
	shortcutLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	shortcutLabel.TextScaled = true
	shortcutLabel.Font = Enum.Font.SourceSans
	shortcutLabel.TextXAlignment = Enum.TextXAlignment.Left
	shortcutLabel.Parent = contentFrame

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Size = UDim2.new(0, 50, 0, 25)
	toggleButton.Position = UDim2.new(1, -50, 0, 80)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = "ON"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.SourceSansBold
	toggleButton.Parent = contentFrame

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggleButton

	-- Cursor toggle
	local cursorLabel = Instance.new("TextLabel")
	cursorLabel.Name = "CursorLabel"
	cursorLabel.Size = UDim2.new(1, -60, 0, 25)
	cursorLabel.Position = UDim2.new(0, 0, 0, 110)
	cursorLabel.BackgroundTransparency = 1
	cursorLabel.Text = "Disable Cursor:"
	cursorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cursorLabel.TextScaled = true
	cursorLabel.Font = Enum.Font.SourceSans
	cursorLabel.TextXAlignment = Enum.TextXAlignment.Left
	cursorLabel.Parent = contentFrame

	local cursorToggleButton = Instance.new("TextButton")
	cursorToggleButton.Name = "CursorToggleButton"
	cursorToggleButton.Size = UDim2.new(0, 50, 0, 25)
	cursorToggleButton.Position = UDim2.new(1, -50, 0, 110)
	cursorToggleButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	cursorToggleButton.BorderSizePixel = 0
	cursorToggleButton.Text = "ON"
	cursorToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cursorToggleButton.TextScaled = true
	cursorToggleButton.Font = Enum.Font.SourceSansBold
	cursorToggleButton.Parent = contentFrame

	local cursorToggleCorner = Instance.new("UICorner")
	cursorToggleCorner.CornerRadius = UDim.new(0, 12)
	cursorToggleCorner.Parent = cursorToggleButton

	-- FreeCam toggle button
	local freecamToggle = Instance.new("TextButton")
	freecamToggle.Name = "FreeCamToggle"
	freecamToggle.Size = UDim2.new(1, 0, 0, 35)
	freecamToggle.Position = UDim2.new(0, 0, 0, 150)
	freecamToggle.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	freecamToggle.BorderSizePixel = 0
	freecamToggle.Text = "Enable FreeCam"
	freecamToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	freecamToggle.TextScaled = true
	freecamToggle.Font = Enum.Font.SourceSansBold
	freecamToggle.Parent = contentFrame

	local freecamCorner = Instance.new("UICorner")
	freecamCorner.CornerRadius = UDim.new(0, 6)
	freecamCorner.Parent = freecamToggle

	-- Make frame draggable
	local dragging = false
	local dragStart = nil
	local startPos = nil

	local function updateDrag(input)
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	titleBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				updateDrag(input)
			end
		end
	end)

	-- Slider functionality
	local sliderDragging = false

	local function updateSlider(input)
		local relativePos = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
		relativePos = math.clamp(relativePos, 0, 1)
		
		GUI_CONFIG.speedMultiplier = 0.1 + (relativePos * 4.9) -- 0.1x to 5.0x
		
		sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
		sliderHandle.Position = UDim2.new(relativePos, -15, 0.5, -15)
		
		speedLabel.Text = string.format("FreeCam Speed: %.1fx", GUI_CONFIG.speedMultiplier)
	end

	local function startSliderDrag(input)
		sliderDragging = true
		updateSlider(input)
		
		local connection1, connection2
		
		connection1 = UserInputService.InputChanged:Connect(function(changedInput)
			if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
				if sliderDragging then
					updateSlider(changedInput)
				end
			end
		end)
		
		connection2 = UserInputService.InputEnded:Connect(function(endedInput)
			if (endedInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) or
			   (endedInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch) then
				sliderDragging = false
				connection1:Disconnect()
				connection2:Disconnect()
			end
		end)
	end

	-- Make entire slider area clickable and draggable
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startSliderDrag(input)
		end
	end)

	-- Make slider handle draggable too
	sliderHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startSliderDrag(input)
		end
	end)

	-- Toggle button functionality
	toggleButton.MouseButton1Click:Connect(function()
		GUI_CONFIG.keyboardShortcutEnabled = not GUI_CONFIG.keyboardShortcutEnabled
		
		if GUI_CONFIG.keyboardShortcutEnabled then
			toggleButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
			toggleButton.Text = "ON"
		else
			toggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			toggleButton.Text = "OFF"
		end
	end)

	-- Cursor toggle functionality - FIXED VERSION
	cursorToggleButton.MouseButton1Click:Connect(function()
		GUI_CONFIG.disableCursor = not GUI_CONFIG.disableCursor
		
		-- Update button appearance
		if GUI_CONFIG.disableCursor then
			cursorToggleButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
			cursorToggleButton.Text = "ON"
		else
			cursorToggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			cursorToggleButton.Text = "OFF"
		end
		
		-- Immediately update cursor visibility
		UpdateCursorVisibility()
	end)

	-- Minimize functionality
	local isMinimized = false
	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		
		local targetSize = isMinimized and UDim2.new(0, 300, 0, 30) or UDim2.new(0, 300, 0, 230)
		
		TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
			{Size = targetSize}):Play()
		
		contentFrame.Visible = not isMinimized
		minimizeButton.Text = isMinimized and "+" or "_"
	end)

	return screenGui, freecamToggle
end

------------------------------------------------------------------------

local Input = {} do
	local thumbstickCurve do
		local K_CURVATURE = 2.0
		local K_DEADZONE = 0.15

		local function fCurve(x)
			return (exp(K_CURVATURE*x) - 1)/(exp(K_CURVATURE) - 1)
		end

		local function fDeadzone(x)
			return fCurve((x - K_DEADZONE)/(1 - K_DEADZONE))
		end

		function thumbstickCurve(x)
			return sign(x)*clamp(fDeadzone(abs(x)), 0, 1)
		end
	end

	local gamepad = {
		ButtonX = 0,
		ButtonY = 0,
		DPadDown = 0,
		DPadUp = 0,
		ButtonL2 = 0,
		ButtonR2 = 0,
		Thumbstick1 = Vector2.new(),
		Thumbstick2 = Vector2.new(),
	}

	local keyboard = {
		W = 0,
		A = 0,
		S = 0,
		D = 0,
		E = 0,
		Q = 0,
		U = 0,
		H = 0,
		J = 0,
		K = 0,
		I = 0,
		Y = 0,
		Up = 0,
		Down = 0,
		LeftShift = 0,
		RightShift = 0,
	}

	local mouse = {
		Delta = Vector2.new(),
		MouseWheel = 0,
	}

	local NAV_GAMEPAD_SPEED  = Vector3.new(1, 1, 1)
	local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
	local PAN_MOUSE_SPEED    = Vector2.new(1, 1)*(pi/64)
	local PAN_GAMEPAD_SPEED  = Vector2.new(1, 1)*(pi/8)
	local FOV_WHEEL_SPEED    = 1.0
	local FOV_GAMEPAD_SPEED  = 0.25
	local NAV_ADJ_SPEED      = 0.75
	local NAV_SHIFT_MUL      = 0.25

	local navSpeed = 1

	function Input.Vel(dt)
		navSpeed = clamp(navSpeed + dt*(keyboard.Up - keyboard.Down)*NAV_ADJ_SPEED, 0.01, 4)

		local kGamepad = Vector3.new(
			thumbstickCurve(gamepad.Thumbstick1.X),
			thumbstickCurve(gamepad.ButtonR2) - thumbstickCurve(gamepad.ButtonL2),
			thumbstickCurve(-gamepad.Thumbstick1.Y)
		)*NAV_GAMEPAD_SPEED

		local kKeyboard = Vector3.new(
			keyboard.D - keyboard.A + keyboard.K - keyboard.H,
			keyboard.E - keyboard.Q + keyboard.I - keyboard.Y,
			keyboard.S - keyboard.W + keyboard.J - keyboard.U
		)*NAV_KEYBOARD_SPEED

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		-- Apply GUI speed multiplier
		local finalSpeed = navSpeed * GUI_CONFIG.speedMultiplier * (shift and NAV_SHIFT_MUL or 1)

		return (kGamepad + kKeyboard) * finalSpeed
	end

	function Input.Pan(dt)
		local kGamepad = Vector2.new(
			thumbstickCurve(gamepad.Thumbstick2.Y),
			thumbstickCurve(-gamepad.Thumbstick2.X)
		)*PAN_GAMEPAD_SPEED
		local kMouse = mouse.Delta*PAN_MOUSE_SPEED
		mouse.Delta = Vector2.new()
		return kGamepad + kMouse
	end

	function Input.Fov(dt)
		local kGamepad = (gamepad.ButtonX - gamepad.ButtonY)*FOV_GAMEPAD_SPEED
		local kMouse = mouse.MouseWheel*FOV_WHEEL_SPEED
		mouse.MouseWheel = 0
		return kGamepad + kMouse
	end

	do
		local function Keypress(action, state, input)
			keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function GpButton(action, state, input)
			gamepad[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function MousePan(action, state, input)
			local delta = input.Delta
			mouse.Delta = Vector2.new(-delta.y, -delta.x)
			return Enum.ContextActionResult.Sink
		end

		local function Thumb(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position
			return Enum.ContextActionResult.Sink
		end

		local function Trigger(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function MouseWheel(action, state, input)
			mouse[input.UserInputType.Name] = -input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function Zero(t)
			for k, v in pairs(t) do
				t[k] = v*0
			end
		end

		function Input.StartCapture()
			ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
				Enum.KeyCode.W, Enum.KeyCode.U,
				Enum.KeyCode.A, Enum.KeyCode.H,
				Enum.KeyCode.S, Enum.KeyCode.J,
				Enum.KeyCode.D, Enum.KeyCode.K,
				Enum.KeyCode.E, Enum.KeyCode.I,
				Enum.KeyCode.Q, Enum.KeyCode.Y,
				Enum.KeyCode.Up, Enum.KeyCode.Down
			)
			ContextActionService:BindActionAtPriority("FreecamMousePan",          MousePan,   false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
			ContextActionService:BindActionAtPriority("FreecamMouseWheel",        MouseWheel, false, INPUT_PRIORITY, Enum.UserInputType.MouseWheel)
			ContextActionService:BindActionAtPriority("FreecamGamepadButton",     GpButton,   false, INPUT_PRIORITY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
			ContextActionService:BindActionAtPriority("FreecamGamepadTrigger",    Trigger,    false, INPUT_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
			ContextActionService:BindActionAtPriority("FreecamGamepadThumbstick", Thumb,      false, INPUT_PRIORITY, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
		end

		function Input.StopCapture()
			navSpeed = 1
			Zero(gamepad)
			Zero(keyboard)
			Zero(mouse)
			ContextActionService:UnbindAction("FreecamKeyboard")
			ContextActionService:UnbindAction("FreecamMousePan")
			ContextActionService:UnbindAction("FreecamMouseWheel")
			ContextActionService:UnbindAction("FreecamGamepadButton")
			ContextActionService:UnbindAction("FreecamGamepadTrigger")
			ContextActionService:UnbindAction("FreecamGamepadThumbstick")
		end
	end
end

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2*tan(cameraFov/2)
	local projx = viewport.x/viewport.y*projy
	local fx = cameraFrame.rightVector
	local fy = cameraFrame.upVector
	local fz = cameraFrame.lookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5)*projx
			local cy = (y - 0.5)*projy
			local offset = fx*cx - fy*cy + fz
			local origin = cameraFrame.p + offset*znear
			local _, hit = Workspace:FindPartOnRay(Ray.new(origin, offset.unit*minDist))
			local dist = (hit - origin).magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.unit
			end
		end
	end

	return fz:Dot(minVect)*minDist
end

------------------------------------------------------------------------

local function StepFreecam(dt)
	local vel = velSpring:Update(dt, Input.Vel(dt))
	local pan = panSpring:Update(dt, Input.Pan(dt))
	local fov = fovSpring:Update(dt, Input.Fov(dt))

	local zoomFactor = sqrt(tan(rad(70/2))/tan(rad(cameraFov/2)))

	cameraFov = clamp(cameraFov + fov*FOV_GAIN*(dt/zoomFactor), 1, 120)
	cameraRot = cameraRot + pan*PAN_GAIN*(dt/zoomFactor)
	cameraRot = Vector2.new(clamp(cameraRot.x, -PITCH_LIMIT, PITCH_LIMIT), cameraRot.y%(2*pi))

	local cameraCFrame = CFrame.new(cameraPos)*CFrame.fromOrientation(cameraRot.x, cameraRot.y, 0)*CFrame.new(vel*NAV_GAIN*dt)
	cameraPos = cameraCFrame.p

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame*CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
	Camera.FieldOfView = cameraFov
end

local function CheckMouseLockAvailability()
	local devAllowsMouseLock = Players.LocalPlayer.DevEnableMouseLock
	local devMovementModeIsScriptable = Players.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local userHasClickToMoveEnabled =  GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = devAllowsMouseLock and userHasMouseLockModeEnabled and not userHasClickToMoveEnabled and not devMovementModeIsScriptable

	return MouseLockAvailable
end

------------------------------------------------------------------------

local PlayerState = {} do
	local mouseBehavior
	local mouseIconEnabled
	local cameraType
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {
		Backpack = true,
		Chat = true,
		Health = true,
		PlayerList = true,
	}
	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	-- Save state and set up for freecam
	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
		end
		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			StarterGui:SetCore(name, false)
		end
		local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "FreeCamGUI" then
					screenGuis[#screenGuis + 1] = gui
					gui.Enabled = false
				end
			end
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70

		cameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom

		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		-- Save original mouse icon state but DON'T set it here
		-- The UpdateCursorVisibility function will handle it
		mouseIconEnabled = UserInputService.MouseIconEnabled

		if FFlagUserExitFreecamBreaksWithShiftlock and CheckMouseLockAvailability() then
			mouseBehavior = Enum.MouseBehavior.Default
		else
			mouseBehavior = UserInputService.MouseBehavior
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Restore state
	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
		end
		for name, isEnabled in pairs(setCores) do
			StarterGui:SetCore(name, isEnabled)
		end
		for _, gui in pairs(screenGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil

		Camera.CameraType = cameraType
		cameraType = nil

		Camera.CFrame = cameraCFrame
		cameraCFrame = nil

		Camera.Focus = cameraFocus
		cameraFocus = nil

		-- Restore original mouse icon state
		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil

		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end
end

-- Initialize FreeCam system
local screenGui, freecamToggleButton

-- Set up global state tracking
getgenv().freecamEnabled = false

local function StartFreecam()
	local cameraCFrame = Camera.CFrame
	cameraRot = Vector2.new(cameraCFrame:toEulerAnglesYXZ())
	cameraPos = cameraCFrame.p
	cameraFov = Camera.FieldOfView

	velSpring:Reset(Vector3.new())
	panSpring:Reset(Vector2.new())
	fovSpring:Reset(0)

	PlayerState.Push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	Input.StartCapture()
	
	-- Update global state and cursor
	getgenv().freecamEnabled = true
	UpdateCursorVisibility()
end

local function StopFreecam()
	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	PlayerState.Pop()
	
	-- Update global state and cursor
	getgenv().freecamEnabled = false
	UpdateCursorVisibility()
end

local function ToggleFreecam()
	if getgenv().freecamEnabled then
		StopFreecam()
		freecamToggleButton.Text = "Enable FreeCam"
		freecamToggleButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	else
		StartFreecam()
		freecamToggleButton.Text = "Disable FreeCam"
		freecamToggleButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	end
end

-- Create GUI on script start
screenGui, freecamToggleButton = CreateGUI()

-- Connect GUI button
freecamToggleButton.MouseButton1Click:Connect(ToggleFreecam)

-- Keyboard shortcut handling
do
	local function CheckMacro()
		if not GUI_CONFIG.keyboardShortcutEnabled then
			return
		end
		
		-- Check if Ctrl+Shift+P is pressed
		if (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) and
		   (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
			ToggleFreecam()
		end
	end

	local function HandleActivationInput(action, state, input)
		if state == Enum.UserInputState.Begin then
			if input.KeyCode == Enum.KeyCode.P then
				CheckMacro()
			end
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority("FreecamToggle", HandleActivationInput, false, TOGGLE_INPUT_PRIORITY, Enum.KeyCode.P)
end

-- Mobile touch controls (if on mobile)
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	-- Create mobile-specific touch controls
	local mobileFrame = Instance.new("Frame")
	mobileFrame.Name = "MobileControls"
	mobileFrame.Size = UDim2.new(0, 200, 0, 100)
	mobileFrame.Position = UDim2.new(1, -220, 1, -120)
	mobileFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	mobileFrame.BackgroundTransparency = 0.3
	mobileFrame.BorderSizePixel = 0
	mobileFrame.Parent = screenGui

	local mobileCorner = Instance.new("UICorner")
	mobileCorner.CornerRadius = UDim.new(0, 8)
	mobileCorner.Parent = mobileFrame

	-- Mobile speed up/down buttons
	local speedUpBtn = Instance.new("TextButton")
	speedUpBtn.Size = UDim2.new(0, 40, 0, 40)
	speedUpBtn.Position = UDim2.new(0, 10, 0, 10)
	speedUpBtn.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	speedUpBtn.Text = "+"
	speedUpBtn.TextColor3 = Color3.white
	speedUpBtn.TextScaled = true
	speedUpBtn.Font = Enum.Font.SourceSansBold
	speedUpBtn.Parent = mobileFrame

	local speedUpCorner = Instance.new("UICorner")
	speedUpCorner.CornerRadius = UDim.new(0, 4)
	speedUpCorner.Parent = speedUpBtn

	local speedDownBtn = Instance.new("TextButton")
	speedDownBtn.Size = UDim2.new(0, 40, 0, 40)
	speedDownBtn.Position = UDim2.new(0, 60, 0, 10)
	speedDownBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	speedDownBtn.Text = "-"
	speedDownBtn.TextColor3 = Color3.white
	speedDownBtn.TextScaled = true
	speedDownBtn.Font = Enum.Font.SourceSansBold
	speedDownBtn.Parent = mobileFrame

	local speedDownCorner = Instance.new("UICorner")
	speedDownCorner.CornerRadius = UDim.new(0, 4)
	speedDownCorner.Parent = speedDownBtn

	-- Mobile toggle button
	local mobileToggle = Instance.new("TextButton")
	mobileToggle.Size = UDim2.new(1, -20, 0, 40)
	mobileToggle.Position = UDim2.new(0, 10, 0, 50)
	mobileToggle.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	mobileToggle.Text = "Toggle FreeCam"
	mobileToggle.TextColor3 = Color3.white
	mobileToggle.TextScaled = true
	mobileToggle.Font = Enum.Font.SourceSansBold
	mobileToggle.Parent = mobileFrame

	local mobileToggleCorner = Instance.new("UICorner")
	mobileToggleCorner.CornerRadius = UDim.new(0, 4)
	mobileToggleCorner.Parent = mobileToggle

	-- Mobile button connections
	speedUpBtn.MouseButton1Click:Connect(function()
		GUI_CONFIG.speedMultiplier = math.min(GUI_CONFIG.speedMultiplier + 0.5, 5.0)
		
		-- Update main slider
		local relativePos = (GUI_CONFIG.speedMultiplier - 0.1) / 4.9
		local sliderFill = screenGui.MainFrame.ContentFrame.SliderBg.SliderFill
		local sliderHandle = screenGui.MainFrame.ContentFrame.SliderBg.SliderHandle
		local speedLabel = screenGui.MainFrame.ContentFrame.SpeedLabel
		
		sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
		sliderHandle.Position = UDim2.new(relativePos, -15, 0.5, -15)
		speedLabel.Text = string.format("FreeCam Speed: %.1fx", GUI_CONFIG.speedMultiplier)
	end)

	speedDownBtn.MouseButton1Click:Connect(function()
		GUI_CONFIG.speedMultiplier = math.max(GUI_CONFIG.speedMultiplier - 0.5, 0.1)
		
		-- Update main slider
		local relativePos = (GUI_CONFIG.speedMultiplier - 0.1) / 4.9
		local sliderFill = screenGui.MainFrame.ContentFrame.SliderBg.SliderFill
		local sliderHandle = screenGui.MainFrame.ContentFrame.SliderBg.SliderHandle
		local speedLabel = screenGui.MainFrame.ContentFrame.SpeedLabel
		
		sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
		sliderHandle.Position = UDim2.new(relativePos, -15, 0.5, -15)
		speedLabel.Text = string.format("FreeCam Speed: %.1fx", GUI_CONFIG.speedMultiplier)
	end)

	mobileToggle.MouseButton1Click:Connect(ToggleFreecam)
end

-- Clean up on player leaving
game.Players.PlayerRemoving:Connect(function(player)
	if player == LocalPlayer then
		if getgenv().freecamEnabled then
			StopFreecam()
		end
		if screenGui then
			screenGui:Destroy()
		end
	end
end)

print('FreeCam Script Loaded!')
