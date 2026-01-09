local PLRS = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local LP = PLRS.LocalPlayer

local AprilFoolMode = false

local hasFiresignal = typeof(firesignal) == "function"
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local useClickMethod = AprilFoolMode and not isMobile or not AprilFoolMode and isMobile

local bgQueue = {}
local bgCounter = 0

local function log(msg)
    print(string.format("[Auto QTE] %.3f | %s", tick(), msg))
end

log("Platform: " .. (isMobile and "MOBILE" or "PC"))
log("firesignal: " .. (hasFiresignal and "AVAILABLE" or "NOT FOUND"))
if AprilFoolMode then log("AprilFoolMode: ENABLED") end
log("Using: " .. (useClickMethod and "CLICK METHOD (mobile)" or "KEY METHOD (pc)"))

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

local function cleanupBgQueue()
    local currentTime = tick()
    for i = #bgQueue, 1, -1 do
        local data = bgQueue[i]
        local isInvalid = not data.bg 
            or not data.bg.Parent 
            or (currentTime - data.timestamp) > 10
        
        if isInvalid then
            log("Cleanup: Removed stale BG #" .. data.id)
            table.remove(bgQueue, i)
        end
    end
end

local function pushBgToQueue(bg)
    bgCounter = bgCounter + 1
    local id = bgCounter
    local timestamp = tick()
    
    table.insert(bgQueue, {
        bg = bg,
        timestamp = timestamp,
        id = id
    })
    
    log(string.format("BG #%d added to queue | Queue size: %d", id, #bgQueue))
    
    local connection
    connection = bg.AncestryChanged:Connect(function(_, parent)
        if not parent then
            for i, data in ipairs(bgQueue) do
                if data.id == id then
                    table.remove(bgQueue, i)
                    log(string.format("BG #%d removed (destroyed) | Queue size: %d", id, #bgQueue))
                    break
                end
            end
            connection:Disconnect()
        end
    end)
end

local function popBgFromQueue()
    cleanupBgQueue()
    
    if #bgQueue > 0 then
        local data = table.remove(bgQueue, 1)
        log(string.format("BG #%d popped from queue | Remaining: %d", data.id, #bgQueue))
        return data.bg, data.id
    end
    
    return nil, nil
end

local function waitForBg(timeout)
    timeout = timeout or 0.5
    local waited = 0
    local interval = 0.03
    
    while waited < timeout do
        local bg, id = popBgFromQueue()
        if bg then
            log(string.format("BG found after waiting %.3fs", waited))
            return bg, id
        end
        task.wait(interval)
        waited = waited + interval
    end
    
    log("Timeout waiting for BG!")
    return nil, nil
end

local function clickButton(targetBg, bgId)
    if not hasFiresignal then
        log("firesignal not available - click skipped!")
        return false
    end
    
    if not targetBg or not targetBg.Parent then
        log(string.format("BG #%s already removed before click!", tostring(bgId or "?")))
        return false
    end
    
    log(string.format("Clicking BG #%s via firesignal", tostring(bgId or "?")))
    firesignal(targetBg.MouseButton1Down)
    
    return true
end

local function processQTE(keyboardKey, timingRange)
    if not timingRange or typeof(timingRange) ~= "NumberRange" then return end
    
    local minTime = timingRange.Min
    local maxTime = timingRange.Max
    local windowSize = maxTime - minTime
    local randomOffset = windowSize * (0.3 + math.random() * 0.3)
    local targetDelay = minTime + randomOffset
    
    log(string.format("QTE received: Key=%s | Window=[%.3f-%.3f] | Delay=%.3fs", 
        tostring(keyboardKey), minTime, maxTime, targetDelay))

    if useClickMethod then
        task.spawn(function()
            local targetBg, bgId = popBgFromQueue()
            
            if not targetBg then
                log("Queue empty, waiting for BG...")
                targetBg, bgId = waitForBg(0.5)
                
                if not targetBg then
                    log("ERROR: No BG found for this QTE!")
                    return
                end
            end
            
            log(string.format("QTE matched with BG #%d", bgId))
            
            task.delay(targetDelay, function()
                if not clickButton(targetBg, bgId) then
                    log("Failed to click BG #" .. tostring(bgId))
                end
            end)
        end)
    else
        task.delay(targetDelay, function()
            pressKey(keyboardKey)
        end)
    end
end

local function setupMobileWatcher()
    local playerGui = LP:WaitForChild("PlayerGui")
    local watchedPromptHolders = {}
    
    local function watchPromptHolder(promptHolder)
        if watchedPromptHolders[promptHolder] then return end
        watchedPromptHolders[promptHolder] = true
        
        log("Watching PromptHolder: " .. promptHolder:GetFullName())
        
        for _, child in pairs(promptHolder:GetChildren()) do
            if child.Name == "BG" then
                pushBgToQueue(child)
            end
        end
        
        promptHolder.ChildAdded:Connect(function(child)
            if child.Name == "BG" then
                pushBgToQueue(child)
            end
        end)
    end
    
    local function watchQuicktimeUI(quicktimeUI)
        log("Found QuicktimeUI: " .. quicktimeUI:GetFullName())
        
        local promptHolder = quicktimeUI:FindFirstChild("PromptHolder")
        if promptHolder then
            watchPromptHolder(promptHolder)
        end
        
        quicktimeUI.ChildAdded:Connect(function(child)
            if child.Name == "PromptHolder" then
                task.wait(0.02)
                watchPromptHolder(child)
            end
        end)
        
        quicktimeUI.DescendantAdded:Connect(function(desc)
            if desc.Name == "PromptHolder" then
                task.wait(0.02)
                watchPromptHolder(desc)
            end
        end)
    end
    
    local function scanExistingUI()
        local quicktimeUI = playerGui:FindFirstChild("QuicktimeUI")
        if quicktimeUI then
            watchQuicktimeUI(quicktimeUI)
        end
    end
    
    playerGui.ChildAdded:Connect(function(child)
        if child.Name == "QuicktimeUI" then
            task.wait(0.02)
            watchQuicktimeUI(child)
        end
    end)
    
    playerGui.DescendantAdded:Connect(function(desc)
        if desc.Name == "QuicktimeUI" then
            task.wait(0.02)
            watchQuicktimeUI(desc)
        end
    end)
    
    scanExistingUI()
    log("Mobile UI watcher enabled - tracking individual BG elements")
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
