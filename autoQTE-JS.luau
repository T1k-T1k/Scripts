local PLRS = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local VU = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local LP = PLRS.LocalPlayer

local AprilFoolMode = false

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local useClickMethod = AprilFoolMode and not isMobile or not AprilFoolMode and isMobile

local function log(msg)
    print(string.format("[Auto QTE] %.3f | %s", tick(), msg))
end

log("Platform: " .. (isMobile and "MOBILE" or "PC"))
if AprilFoolMode then
    log("AprilFoolMode: ENABLED (methods swapped!)")
end
log("Using: " .. (useClickMethod and "CLICK METHOD" or "KEY METHOD"))

local function pressKey(keyCode)
    if not keyCode then return end
    
    if typeof(keyCode) == "string" then
        local success
        success, keyCode = pcall(function()
            return Enum.KeyCode[keyCode:upper()]
        end)
        if not success then return end
    end

    log("Key pressed: " .. tostring(keyCode))
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.02)
    VIM:SendKeyEvent(false, keyCode, false, game)
end

local function getButtonCenter(button)
    local pos = button.AbsolutePosition
    local size = button.AbsoluteSize
    local centerX = pos.X + (size.X / 2)
    local centerY = pos.Y + (size.Y / 2)
    return Vector2.new(centerX, centerY)
end

local function clickButton()
    local playerGui = LP:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    local quicktimeUI = playerGui:FindFirstChild("QuicktimeUI")
    if not quicktimeUI then return false end
    
    local promptHolder = quicktimeUI:FindFirstChild("PromptHolder")
    if not promptHolder then return false end
    
    local bg = promptHolder:FindFirstChild("BG")
    if not bg then return false end
    
    local center = getButtonCenter(bg)
    log(string.format("Clicking at center: (%.1f, %.1f)", center.X, center.Y))
    
    VU:Button1Down(center)
    task.wait(0.02)
    VU:Button1Up(center)
    
    return true
end

local function processQTE(keyboardKey, timingRange)
    if not timingRange or typeof(timingRange) ~= "NumberRange" then return end
    
    local minTime = timingRange.Min
    local maxTime = timingRange.Max
    local windowSize = maxTime - minTime
    local randomOffset = windowSize * (0.3 + math.random() * 0.3)
    local targetDelay = minTime + randomOffset
    
    log(string.format("QTE: Key=%s | Window=[%.3f-%.3f] | Delay=%.3fs", 
        tostring(keyboardKey), minTime, maxTime, targetDelay))

    task.delay(targetDelay, function()
        if useClickMethod then
            if not clickButton() then
                log("Button not found!")
            end
        else
            pressKey(keyboardKey)
        end
    end)
end

local function setupMobileWatcher()
    local playerGui = LP:WaitForChild("PlayerGui")
    
    local function watchForUI()
        local quicktimeUI = playerGui:FindFirstChild("QuicktimeUI")
        if quicktimeUI then
            local promptHolder = quicktimeUI:FindFirstChild("PromptHolder")
            if promptHolder then
                promptHolder.ChildAdded:Connect(function(child)
                    if child.Name == "BG" then
                        log("Button appeared: " .. child.Name)
                    end
                end)
            end
        end
    end
    
    playerGui.ChildAdded:Connect(function(child)
        if child.Name == "QuicktimeUI" then
            task.wait(0.1)
            watchForUI()
        end
    end)
    
    watchForUI()
    log("UI watcher enabled")
end

local function hookQTE()
    local remotesFolder = RS:WaitForChild("Remotes", 15)
    if not remotesFolder then
        log("ERROR: Remotes folder not found!")
        return
    end
    
    local remote = remotesFolder:WaitForChild("CreateQT", 15)
    if not remote then
        log("ERROR: CreateQT remote not found!")
        return
    end

    remote.OnClientEvent:Connect(function(keyboardKey, gamepadKey, timingRange)
        processQTE(keyboardKey, timingRange)
    end)

    log("CreateQT hooked!")
end

if useClickMethod then
    setupMobileWatcher()
end

hookQTE()
log("Script Injected!")
