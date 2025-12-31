local PLRS = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LP = PLRS.LocalPlayer

local function log(msg)
    print(string.format("[Auto QTE JS] %.3f | %s", tick(), msg))
end

local function pressKey(keyCode)
    if not keyCode then
        log("Invalid keyCode: nil")
        return
    end
    
    if typeof(keyCode) == "string" then
        local success
        success, keyCode = pcall(function()
            return Enum.KeyCode[keyCode:upper()]
        end)
        if not success then
            log("Unknown key: " .. tostring(keyCode))
            return
        end
    end

    log("Pressed: " .. tostring(keyCode))
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.02)
    VIM:SendKeyEvent(false, keyCode, false, game)
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
        if keyboardKey and timingRange and typeof(timingRange) == "NumberRange" then
            local minTime = timingRange.Min
            local maxTime = timingRange.Max
            local windowSize = maxTime - minTime
            
            local randomOffset = windowSize * (0.3 + math.random() * 0.3)
            local targetDelay = minTime + randomOffset
            
            log(string.format(
                "QTE Detected: Key=%s | Window=[%.3f - %.3f] (%.0fms) | Pressing in %.3fs", 
                tostring(keyboardKey), 
                minTime, 
                maxTime, 
                windowSize * 1000,
                targetDelay
            ))

            task.delay(targetDelay, function()
                pressKey(keyboardKey)
            end)
        else
            log(string.format(
                "Unexpected args: key=%s (%s), gamepad=%s, range=%s (%s)", 
                tostring(keyboardKey), typeof(keyboardKey),
                tostring(gamepadKey), 
                tostring(timingRange), typeof(timingRange)
            ))
        end
    end)

    log("CreateQT event hooked successfully!")
end

hookQTE()
log("Script Injected.")
