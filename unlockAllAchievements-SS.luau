-- this script is visual and was made just for fun
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local menuHolder = playerGui:WaitForChild("MenuHolder")
local menu = menuHolder:WaitForChild("Menu")
local menuBG = menu:WaitForChild("MenuBG")
local achievements = menuBG:WaitForChild("Achievements")
local holder = achievements:WaitForChild("Holder")

local dataFolder = LocalPlayer:WaitForChild("Data")
local achievementsData = dataFolder:WaitForChild("Achievements")
local appliedACM = dataFolder:WaitForChild("AppliedACM")

for _, frame in ipairs(holder:GetChildren()) do
    if frame:IsA("Frame") then
        local existingValue = achievementsData:FindFirstChild(frame.Name)
        if not existingValue then
            local stringValue = Instance.new("StringValue")
            stringValue.Name = frame.Name
            stringValue.Value = frame.Name
            stringValue.Parent = achievementsData
        else
            existingValue.Value = frame.Name
        end

        local progress = frame:FindFirstChild("Progress")
        if progress then
            local bar = progress:FindFirstChild("Bar")
            local current = progress:FindFirstChild("Current")
            if bar and current and current:IsA("TextLabel") then
                bar.Size = UDim2.new(1, 0, 1, 0)

                local text = current.Text
                local lastDigit = string.match(text, "%d$")
                if lastDigit then
                    current.Text = lastDigit .. text:sub(2)
                end
            end
        end
    end
end

print("Data.Achievements updated!")

local changeCounter = 0
local lastChangeTime = 0
local cooldownActive = false
local COOLDOWN_DURATION = 15
local CHANGE_WINDOW = 6
local MAX_CHANGES = 3

local allButtons = {}
local buttonTextLabels = {}

local function showCooldownNotification()
    local notif = LocalPlayer.PlayerGui:FindFirstChild("Notification")
    if notif then
        local textLabel = notif.Text
        textLabel.Text = "On Cooldown"
        textLabel.TextTransparency = 0
        TweenService:Create(textLabel, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 2.5), {
            TextTransparency = 1;
        }):Play()
    end
end

local function setButtonsActive(state)
    for _, btn in ipairs(allButtons) do
        btn.Active = state
    end
end

local function startCooldown()
    cooldownActive = true
    setButtonsActive(false)
    showCooldownNotification()
    task.delay(COOLDOWN_DURATION, function()
        cooldownActive = false
        changeCounter = 0
        setButtonsActive(true)
    end)
end

local function updateFrames(selectedName)
    if cooldownActive then
        showCooldownNotification()
        return
    end

    local currentTime = tick()
    if currentTime - lastChangeTime <= CHANGE_WINDOW then
        changeCounter = changeCounter + 1
    else
        changeCounter = 1
    end
    lastChangeTime = currentTime

    if changeCounter >= MAX_CHANGES then
        startCooldown()
    end

    for _, frame in ipairs(holder:GetChildren()) do
        if frame:IsA("Frame") then
            local applyButton = frame:WaitForChild("Apply")
            local objectiveName = applyButton:WaitForChild("ObjectiveName")
            local acmName = frame:WaitForChild("ACMName")

            if acmName.Text == selectedName then
                if appliedACM.Value == selectedName then
                    objectiveName.Text = "Apply"
                    applyButton.ImageColor3 = Color3.new(1,1,1)
                    appliedACM.Value = "None"
                    ReplicatedStorage.GlobalUsedRemotes.ApplyAchievement:FireServer("none")
                else
                    objectiveName.Text = "Unequip"
                    applyButton.ImageColor3 = Color3.fromRGB(50,50,50)
                    appliedACM.Value = selectedName
                    ReplicatedStorage.GlobalUsedRemotes.ApplyAchievement:FireServer(selectedName)
                end
            else
                objectiveName.Text = "Apply"
                applyButton.ImageColor3 = Color3.new(1,1,1)
            end
        end
    end
end

local function handleTextClick(acmName)
    if cooldownActive then
        showCooldownNotification()
        return true
    end
    return false
end

for _, frame in ipairs(holder:GetChildren()) do
    if frame:IsA("Frame") then
        local applyButton = frame:WaitForChild("Apply")
        local objectiveName = applyButton:WaitForChild("ObjectiveName")
        local acmName = frame:WaitForChild("ACMName")
        
        table.insert(allButtons, applyButton)
        
        applyButton.Activated:Connect(function()
            if cooldownActive then
                showCooldownNotification()
                return
            end
            updateFrames(acmName.Text)
        end)

        objectiveName.Active = true
        
        objectiveName.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                handleTextClick(acmName.Text)
            end
        end)
    end
end
