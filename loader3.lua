local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

setthreadidentity(2)
for i, v in pairs(getgc(true)) do
    if typeof(v) == "table" then
        local DetectFunc = rawget(v, "Detected")
        local KillFunc = rawget(v, "Kill")
        if type(DetectFunc) == "function" then
            hookfunction(DetectFunc, function() return true end)
        end
        if type(KillFunc) == "function" then
            hookfunction(KillFunc, function() return nil end)
        end
    end
end
setthreadidentity(7)

task.spawn(function()
    while task.wait(0.2) do
        if player:FindFirstChild("Recoil") then
            player.Recoil:Destroy()
        end
    end
end)

local infAmmoEnabled = true
local ammoConnections = {}

local function FindWeaponInWorkspace(tool)
    if not tool then return nil end
    local playerFolder = workspace:FindFirstChild(player.Name)
    if not playerFolder then return nil end
    return playerFolder:FindFirstChild(tool.Name, true)
end

local function IsWeaponReady(weapon)
    if not weapon then return false end
    if not weapon:FindFirstChild("GunScript") then return false end
    if not weapon.GunScript:FindFirstChild("ClientAmmo") then return false end
    return true
end

local function freezeAmmo(weapon)
    if weapon and weapon:FindFirstChild("GunScript") then
        local gunScript = weapon.GunScript
        if gunScript:FindFirstChild("ClientAmmo") then
            local ammo = gunScript.ClientAmmo
            local orig = ammo.Value
            local conn = ammo.Changed:Connect(function()
                if ammo.Value ~= orig then ammo.Value = orig end
            end)
            table.insert(ammoConnections, conn)
        end
    end
end

local function forceReload(character)
    if not character then return end
    for _, tool in ipairs(character:GetDescendants()) do
        if tool:IsA("Tool") then
            local weapon = FindWeaponInWorkspace(tool)
            if not weapon then continue end
            local reloadEvent = weapon:FindFirstChild("ReloadEvent")
            if not reloadEvent then continue end
            local function fireReload(args)
                reloadEvent:FireServer(unpack(args, 1, table.maxn(args)))
            end
            fireReload({[11] = "startReload"})
            fireReload({[14] = 0, [11] = "magMath"})
            fireReload({[14] = 3, [11] = "insertMag"})
            fireReload({[14] = 3, [11] = "stopReload"})
        end
    end
end

local function processWeapons(character)
    if not character then return end
    for _, tool in ipairs(character:GetDescendants()) do
        if tool:IsA("Tool") then
            local weapon = FindWeaponInWorkspace(tool)
            if not weapon then continue end
            if IsWeaponReady(weapon) and infAmmoEnabled then
                freezeAmmo(weapon)
            end
        end
    end
    if infAmmoEnabled then forceReload(character) end
end

local function ammoLoop()
    while infAmmoEnabled do
        local character = player.Character or player.CharacterAdded:Wait()
        processWeapons(character)
        task.wait(0.1)
    end
end

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    if infAmmoEnabled then processWeapons(character) end
end)
task.spawn(ammoLoop)

-- Gun Mods Config
local MOD_CONFIG = {


PerfectAccuracy = {params = {"scatter"}, active_value = 999, default_value = 1},
    InstantEquip = {params = {"EquipSpeed"}, active_value = 0.0000001, default_value = 1},
    PerfectFirerate = {params = {"waittime"}, active_value = 0.00001, default_value = 1},
    ReloadSpeed = {params = {"ReloadSpeed", "ReloadSpeed2"}, active_value = 0.00001, default_value = 1},
    NoAimSway = {params = {"AimSway"}, active_value = 0.00001, default_value = 1},
    FastAiming = {params = {"AimSpeed"}, active_value = 0.00001, default_value = 1}
}

local ModStates = {}
local OriginalValues = {}
local TrackedTools = {}

for modName in pairs(MOD_CONFIG) do
    ModStates[modName] = false 
end

local function SetupToolStructure(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local attachmentFolder = tool:FindFirstChild("AttachmentFolder")
    if not attachmentFolder then return false end
    local innerTool = attachmentFolder:FindFirstChild("Tool") or Instance.new("Tool")
    innerTool.Name = "Tool"
    innerTool.Parent = attachmentFolder
    if not innerTool:FindFirstChild("IsAttachment") then
        local isAttachment = Instance.new("StringValue")
        isAttachment.Name = "IsAttachment"
        isAttachment.Value = "Gripp"
        isAttachment.Parent = innerTool
    end
    local statsFolder = innerTool:FindFirstChild("Stats") or Instance.new("Folder")
    statsFolder.Name = "Stats"
    statsFolder.Parent = innerTool
    return true
end

local function ProcessWeapon(tool)
    if not SetupToolStructure(tool) then return end
    local innerTool = tool.AttachmentFolder:FindFirstChild("Tool")
    if not innerTool then return end
    local statsFolder = innerTool:FindFirstChild("Stats")
    if not statsFolder then return end
    
    for modName, config in pairs(MOD_CONFIG) do
        for _, paramName in ipairs(config.params) do
            if not OriginalValues[tool] then OriginalValues[tool] = {} end
            if OriginalValues[tool][paramName] == nil then
                local currentValue = statsFolder:FindFirstChild(paramName)
                OriginalValues[tool][paramName] = currentValue and currentValue.Value or config.default_value
            end
            local valueToSet = ModStates[modName] and config.active_value or OriginalValues[tool][paramName]
            local param = statsFolder:FindFirstChild(paramName) or Instance.new("NumberValue")
            param.Name = paramName
            param.Value = valueToSet
            param.Parent = statsFolder
        end
    end
end

local function GetValidPlayerTools()
    local tools = {}
    if player.Character then
        for _, item in ipairs(player.Character:GetDescendants()) do
            if item:IsA("Tool") and item:FindFirstChild("AttachmentFolder") then
                table.insert(tools, item)
            end
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item:FindFirstChild("AttachmentFolder") then
                table.insert(tools, item)
            end
        end
    end
    return tools
end

local function ApplyModifications()
    for _, tool in ipairs(GetValidPlayerTools()) do
        ProcessWeapon(tool)
    end
end

local function CheckForNewTools()
    local currentTools = GetValidPlayerTools()
    for _, tool in ipairs(currentTools) do
        if not TrackedTools[tool] then
            TrackedTools[tool] = true
            ProcessWeapon(tool)
        end
    end
    for tool in pairs(TrackedTools) do
        if not tool:IsDescendantOf(game) then
            TrackedTools[tool] = nil
        end
    end
end

task.spawn(function()
    while task.wait(1) do
        CheckForNewTools()
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    ApplyModifications()
end)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "M5WARE TOWN",
    LoadingTitle = "M5WAR3",
    LoadingSubtitle = "by pavel betto",
    ConfigurationSaving = {
       Enabled = false,
       FolderName = nil,
       FileName = "TownCheat"
    },
    Discord = {
       Enabled = false,
       Invite = "noinvitelink",
       RememberJoins = true
    },
    KeySystem = false
})

local CombatTab = Window:CreateTab("Combat", nil)
local GunTab = Window:CreateTab("Gun", nil)
local VisualTab = Window:CreateTab("Visual", nil)
local MiscTab = Window:CreateTab("Misc", nil)

local silentAimEnabled = false
local originalIndex

local function FindSilentTarget()
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = 150
    local bestPos = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            local pos, on = camera:WorldToViewportPoint(head.Position)
            if on then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPos = head.Position
                end
            end
        end
    end
    return bestPos
end

CombatTab:CreateSection("Combat Settings")

CombatTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Flag = "SilentAim",
    Callback = function(state)
        silentAimEnabled = state
        if not originalIndex then
            originalIndex = hookmetamethod(game, "__index", function(self, key)
                if silentAimEnabled and self:IsA("Mouse") and key == "Hit" then
                    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("GunScript") then
                        local target = FindSilentTarget()
                        if target then return CFrame.new(target) end
                    end
                end
                return originalIndex(self, key)
            end)
        end
    end,
})

GunTab:CreateSection("Weapon Modifications")

GunTab:CreateToggle({
    Name = "Perfect Accuracy",
    CurrentValue = false,
    Callback = function(state)
        ModStates.PerfectAccuracy = state
        ApplyModifications()
    end,
})

GunTab:CreateToggle({
    Name = "Instant Equip",
    CurrentValue = false,
    Callback = function(state)
        ModStates.InstantEquip = state
        ApplyModifications()
    end,
})

GunTab:CreateToggle({
    Name = "Perfect Firerate",
    CurrentValue = false,
    Callback = function(state)
        ModStates.PerfectFirerate = state
        ApplyModifications()
    end,
})

GunTab:CreateToggle({
    Name = "Fast Reload",
    CurrentValue = false,
    Callback = function(state)
        ModStates.ReloadSpeed = state
        ApplyModifications()
    end,
})

GunTab:CreateToggle({
    Name = "No Aim Sway",
    CurrentValue = false,
    Callback = function(state)
        ModStates.NoAimSway = state
        ApplyModifications()
    end,
})

GunTab:CreateToggle({
    Name = "Fast Aiming",
    CurrentValue = false,
    Callback = function(state)
        ModStates.FastAiming = state
        ApplyModifications()
    end,
})

GunTab:CreateSection("Ammo")

GunTab:CreateToggle({
    Name = "Infinite Ammo",
    CurrentValue = true, 
    Callback = function(state)
        infAmmoEnabled = state
        if not state then
            for _, conn in ipairs(ammoConnections) do

conn:Disconnect()
            end
            ammoConnections = {}
        else
            task.spawn(ammoLoop)
            if player.Character then processWeapons(player.Character) end
        end
    end,
})

local autoModeEnabled = false
local autoModeConnection = nil

GunTab:CreateToggle({
    Name = "Auto Mode",
    CurrentValue = false,
    Callback = function(state)
        autoModeEnabled = state
        local function setAutoMode(tool)
            if not tool or not tool:IsA("Tool") then return end
            local settingsModule = tool:FindFirstChild("Settings")
            if settingsModule and settingsModule:IsA("ModuleScript") then
                local success, settings = pcall(function() return require(settingsModule) end)
                if success and type(settings) == "table" then
                    settings.auto = state
                end
            end
        end
        local function updateTools(character)
            if not character then return end
            for _, tool in ipairs(character:GetChildren()) do
                setAutoMode(tool)
            end
        end
        if player.Character then updateTools(player.Character) end
        if autoModeConnection then autoModeConnection:Disconnect() end
        autoModeConnection = player.CharacterAdded:Connect(updateTools)
    end,
})

VisualTab:CreateSection("ESP")

local espEnabled = false
local espCache = {}

local function createHighlight(char)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(171, 0, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.3
    highlight.Adornee = char
    highlight.Parent = CoreGui
    return highlight
end

VisualTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Callback = function(state)
        espEnabled = state
        if state then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    espCache[p] = createHighlight(p.Character)
                end
            end
        else
            for _, h in pairs(espCache) do
                h:Destroy()
            end
            espCache = {}
        end
    end,
})

Players.PlayerAdded:Connect(function(p)
    if espEnabled then
        task.wait(1)
        if p ~= player and p.Character then
            espCache[p] = createHighlight(p.Character)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if espCache[p] then
        espCache[p]:Destroy()
        espCache[p] = nil
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function(char)
        if espEnabled and p ~= player then
            task.wait(0.5)
            if espCache[p] then espCache[p]:Destroy() end
            espCache[p] = createHighlight(char)
        end
    end)
end

VisualTab:CreateSection("World")

local fullBrightEnabled = false
VisualTab:CreateToggle({
    Name = "Full Bright",
    CurrentValue = false,
    Callback = function(state)
        fullBrightEnabled = state
        if state then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
        end
    end,
})

local purpleLightEnabled = false
VisualTab:CreateToggle({
    Name = "Purple Lighting",
    CurrentValue = false,
    Callback = function(state)
        purpleLightEnabled = state
        local cc = Lighting:FindFirstChild("ColorCorrection")
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Parent = Lighting
        end
        cc.TintColor = state and Color3.fromRGB(171, 0, 255) or Color3.new(1, 1, 1)
    end,
})

local skinToneEnabled = false
local originalMaterials = {}

VisualTab:CreateToggle({
    Name = "Skin Tone",
    CurrentValue = false,
    Callback = function(state)
        skinToneEnabled = state
        if state and player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    originalMaterials[part] = part.Material
                    part.Material = Enum.Material.ForceField
                    part.Color = Color3.fromRGB(171, 0, 255)
                end
            end
        else
            for part, mat in pairs(originalMaterials) do
                if part and part.Parent then part.Material = mat end
            end
            originalMaterials = {}
        end
    end,
})

player.CharacterAdded:Connect(function()
    if skinToneEnabled then 
        task.wait(1)
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                originalMaterials[part] = part.Material
                part.Material = Enum.Material.ForceField
                part.Color = Color3.fromRGB(171, 0, 255)
            end
        end
    end
end)

MiscTab:CreateSection("Healing")

local instaHealEnabled = false
local healCoroutine = nil

MiscTab:CreateToggle({
    Name = "Insta Heal",
    CurrentValue = false,
    Callback = function(state)
        instaHealEnabled = state
        if healCoroutine then coroutine.close(healCoroutine) end
        if state then
            healCoroutine = coroutine.create(function()
                while instaHealEnabled do
                    if player.Character and player.Character:FindFirstChild("Medkit") then
                        pcall(function()
                            player.Character.Medkit.ActionMain:FireServer("heal", player.Character)
                        end)
                    end
                    task.wait(0.0001)
                end
            end)
            coroutine.resume(healCoroutine)
        end
    end,
})

local instaWrenchEnabled = false
local wrenchCoroutine = nil

MiscTab:CreateToggle({
    Name = "Insta Wrench",
    CurrentValue = false,
    Callback = function(state)
        instaWrenchEnabled = state
        if wrenchCoroutine then coroutine.close(wrenchCoroutine) end
        if state then
            wrenchCoroutine = coroutine.create(function()
                while instaWrenchEnabled do
                    if player.Character and player.Character:FindFirstChild("Wrench") then
                        pcall(function()
                            player.Character.Wrench.ActionMain:FireServer("heal", player.Character)
                        end)
                    end
                    task.wait(0.0001)
                end
            end)
            coroutine.resume(wrenchCoroutine)
        end
    end,
})

local wallBangEnabled = false
local wallbangObjects = {}
local movedFolder = nil

MiscTab:CreateToggle({
    Name = "WallBang",
    CurrentValue = false,
    Callback = function(state)
        wallBangEnabled = state
        if state then
            if movedFolder then movedFolder:Destroy() end
            movedFolder = Instance.new("Folder")
            movedFolder.Name = "WallBangObjects"
            movedFolder.Parent = camera
            
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsDescendantOf(player.Character) then
                    obj.Parent = movedFolder
                    table.insert(wallbangObjects, obj)
                end
            end
        else
            for _, obj in ipairs(wallbangObjects) do
                if obj and obj.Parent then
                    obj.Parent = workspace
                end
            end
            wallbangObjects = {}
            if movedFolder then movedFolder:Destroy() end

movedFolder = nil
        end
    end,
})

MiscTab:CreateSection("Movement")

local flyEnabled = false
local flyBodyVelocity = nil
local flyConnection = nil

MiscTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Callback = function(state)
        flyEnabled = state
        if state then
            if flyConnection then flyConnection:Disconnect() end
            flyConnection = RunService.RenderStepped:Connect(function()
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = player.Character.HumanoidRootPart
                    if not flyBodyVelocity then
                        flyBodyVelocity = Instance.new("BodyVelocity")
                        flyBodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)
                    end
                    local direction = Vector3.new()
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end
                    
                    flyBodyVelocity.Velocity = direction * 50
                    flyBodyVelocity.Parent = hrp
                    
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    if humanoid then humanoid.PlatformStand = true end
                end
            end)
        else
            if flyConnection then flyConnection:Disconnect() end
            flyConnection = nil
            if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then humanoid.PlatformStand = false end
            end
        end
    end,
})

local noclipEnabled = false

MiscTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(state)
        noclipEnabled = state
        if state then
            task.spawn(function()
                while noclipEnabled do
                    if player.Character then
                        for _, part in ipairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            if player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end,
})

MiscTab:CreateSection("Utilities")

MiscTab:CreateButton({
    Name = "Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end,
})

MiscTab:CreateButton({
    Name = "No Fall Damage",
    Callback = function()
        local freefall = ReplicatedStorage:FindFirstChild("Freefall")
        if freefall then freefall:Destroy() end
        local acsEngine = ReplicatedStorage:FindFirstChild("ACS_Engine")
        if acsEngine then
            local events = acsEngine:FindFirstChild("Events")
            if events then

local fdmq = events:FindFirstChild("FDMG")
                if fdmq then fdmq:Destroy() end
            end
        end
    end,
})

MiscTab:CreateButton({
    Name = "CMD-X",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/CMD-X/CMD-X/master/Source"))()
    end,
})

Rayfield:LoadConfiguration()
