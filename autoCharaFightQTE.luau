local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TOLERANCE = 0.02

local function setupUI(ui)
    local bar = ui:WaitForChild("Bar", 5)
    if not bar then return end
    
    local line = bar:WaitForChild("Line", 5)
    local hitbox = bar:WaitForChild("Hitbox", 5)
    if not line or not hitbox then return end
    
    local connection
    connection = line:GetPropertyChangedSignal("Position"):Connect(function()
        local posX = line.Position.X.Scale
        
        if math.abs(posX - 0.5) <= TOLERANCE then
            firesignal(hitbox.MouseButton1Click)
        end
    end)

    ui.AncestryChanged:Connect(function()
        if not ui:IsDescendantOf(game) then
            connection:Disconnect()
        end
    end)
end

PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "UI" then
        task.defer(setupUI, child)
    end
end)

local existingUI = PlayerGui:FindFirstChild("UI")
if existingUI then
    setupUI(existingUI)
end

print("[AutoCharaFightQTE] Injected sucessfully!")
