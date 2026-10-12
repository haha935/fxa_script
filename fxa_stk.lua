--[[
    FxA Supreme | Survive The Killer V1
    Delta Executor | Dark Premium Hub
    Background: catbox.moe/0oc9zi.jpeg
    Logo: Death Note (circular)
    Features: AutoKiller, AutoKill, AutoEscape, AutoSave, TP Knock, ESP, My Self, God Mode, Auto Copy Remote
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
--  REMOTE DUMP (from user's provided list + common STK remotes)
-- ============================================================
local Remotes = {}
local function scanRemotes()
    local function recurse(obj, path)
        for _, v in ipairs(obj:GetChildren()) do
            local fullPath = path .. "." .. v.Name
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                Remotes[v.Name] = v
                Remotes[fullPath] = v
            end
            recurse(v, fullPath)
        end
    end
    recurse(ReplicatedStorage, "ReplicatedStorage")
    recurse(game:GetService("ServerScriptService"), "ServerScriptService")
end
scanRemotes()

-- Specific remotes from user
local CutsceneRemotes = Remotes["CutsceneRemotes"]
local StartRoulette = Remotes["StartRoulette"] or (CutsceneRemotes and CutsceneRemotes:FindFirstChild("StartRoulette"))
local LoadPropKiller = Remotes["LoadPropKiller"]
local KnifeOnHit = Remotes["OnHit"] or (Remotes["KnifeToolTemplate"] and Remotes["KnifeToolTemplate"]:FindFirstChild("OnHit"))
local BreakFree = Remotes["BreakFree"]

-- ============================================================
--  CONFIG
-- ============================================================
local Config = {
    AutoKiller = false,
    AutoKill = false,
    AutoEscape = false,
    AutoSave = false,
    TPKnock = false,
    ESP_Survivor = false,
    ESP_Killer = false,
    ESP_Names = true,
    ESP_Distance = true,
    GodMode = false,
    AutoCopyRemote = false,
    Minimized = false,
}

-- ============================================================
--  GUI CREATION
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FxA_Supreme_STK"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- Main Frame (400x400 centered)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 400)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainUICorner = Instance.new("UICorner")
MainUICorner.CornerRadius = UDim.new(0, 12)
MainUICorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(180, 0, 0)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Background Image
local BgImage = Instance.new("ImageLabel")
BgImage.Name = "Background"
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.Image = "rbxassetid://0" -- placeholder, will use catbox URL via direct image
BgImage.ImageTransparency = 0.85
BgImage.ZIndex = 0
BgImage.Parent = MainFrame

-- Use catbox URL as Image
local success, err = pcall(function()
    BgImage.Image = "https://files.catbox.moe/0oc9zi.jpeg"
end)
if not success then
    BgImage.Image = "rbxassetid://0"
end

-- Logo (circular Death Note)
local LogoFrame = Instance.new("Frame")
LogoFrame.Name = "LogoFrame"
LogoFrame.Size = UDim2.new(0, 64, 0, 64)
LogoFrame.Position = UDim2.new(0, 12, 0, 8)
LogoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
LogoFrame.BorderSizePixel = 0
LogoFrame.ZIndex = 2
LogoFrame.Parent = MainFrame

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0) -- perfect circle
LogoCorner.Parent = LogoFrame

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = Color3.fromRGB(180, 0, 0)
LogoStroke.Thickness = 2
LogoStroke.Parent = LogoFrame

-- Logo image (placeholder until user uploads Death Note image)
local LogoImage = Instance.new("ImageLabel")
LogoImage.Name = "LogoImg"
LogoImage.Size = UDim2.new(1, -4, 1, -4)
LogoImage.Position = UDim2.new(0, 2, 0, 2)
LogoImage.BackgroundTransparency = 1
LogoImage.Image = "rbxassetid://0" -- user must set this to their Death Note image asset ID
LogoImage.ZIndex = 3
LogoImage.Parent = LogoFrame

local LogoImageCorner = Instance.new("UICorner")
LogoImageCorner.CornerRadius = UDim.new(1, 0)
LogoImageCorner.Parent = LogoImage

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, -90, 0, 24)
TitleLabel.Position = UDim2.new(0, 84, 0, 10)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "FxA Supreme"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 2
TitleLabel.Parent = MainFrame

local SubTitle = Instance.new("TextLabel")
SubTitle.Name = "SubTitle"
SubTitle.Size = UDim2.new(1, -90, 0, 14)
SubTitle.Position = UDim2.new(0, 84, 0, 34)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "Survive The Killer V1"
SubTitle.TextColor3 = Color3.fromRGB(180, 0, 0)
SubTitle.TextSize = 11
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.ZIndex = 2
SubTitle.Parent = MainFrame

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex = 5
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -62, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.ZIndex = 5
MinBtn.Parent = MainFrame

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local Minimized = false
MinBtn.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    if Minimized then
        MainFrame.Size = UDim2.new(0, 400, 0, 40)
        for _, v in ipairs(MainFrame:GetChildren()) do
            if v:IsA("ScrollingFrame") or v:IsA("Frame") and v.Name ~= "LogoFrame" and v.Name ~= "Title" and v.Name ~= "SubTitle" then
                if v.Name ~= "LogoFrame" and v.Name ~= "CloseBtn" and v.Name ~= "MinBtn" and v.Name ~= "Background" then
                    v.Visible = false
                end
            end
        end
    else
        MainFrame.Size = UDim2.new(0, 400, 0, 400)
        for _, v in ipairs(MainFrame:GetChildren()) do
            if v:IsA("ScrollingFrame") or (v:IsA("Frame") and v.Name ~= "LogoFrame" and v.Name ~= "CloseBtn" and v.Name ~= "MinBtn") then
                v.Visible = true
            end
        end
    end
end)

-- Scroll Frame for features
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "Features"
ScrollFrame.Size = UDim2.new(1, -20, 1, -90)
ScrollFrame.Position = UDim2.new(0, 10, 0, 80)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(180, 0, 0)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
ScrollFrame.ZIndex = 2
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = ScrollFrame

-- ============================================================
--  TOGGLE BUTTON FACTORY
-- ============================================================
local function createToggle(name, order, callback)
    local Btn = Instance.new("TextButton")
    Btn.Name = name .. "_Btn"
    Btn.Size = UDim2.new(1, -4, 0, 34)
    Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Btn.LayoutOrder = order
    Btn.Parent = ScrollFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Btn

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(60, 60, 70)
    Stroke.Thickness = 1
    Stroke.Parent = Btn

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 12
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Btn

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(0, 50, 1, 0)
    Status.Position = UDim2.new(1, -55, 0, 0)
    Status.BackgroundTransparency = 1
    Status.Text = "OFF"
    Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    Status.TextSize = 11
    Status.Font = Enum.Font.GothamBold
    Status.Parent = Btn

    local toggled = false
    Btn.MouseButton1Click:Connect(function()
        toggled = not toggled
        if toggled then
            Status.Text = "ON"
            Status.TextColor3 = Color3.fromRGB(180, 0, 0)
            Stroke.Color = Color3.fromRGB(180, 0, 0)
            Btn.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
        else
            Status.Text = "OFF"
            Status.TextColor3 = Color3.fromRGB(150, 150, 150)
            Stroke.Color = Color3.fromRGB(60, 60, 70)
            Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        end
        callback(toggled)
    end)

    return Btn
end

-- ============================================================
--  FEATURE IMPLEMENTATIONS
-- ============================================================

-- 1. ESP
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "FxA_ESP"
ESPFolder.Parent = CoreGui

local function createESP(player, color, isKiller)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. player.Name
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name .. (isKiller and " [KILLER]" or " [SURVIVOR]")
    nameLabel.TextColor3 = color
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0"
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextSize = 12
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextStrokeTransparency = 0
    distLabel.Parent = billboard

    return billboard, distLabel
end

local ESPObjects = {}

local function updateESP()
    for _, v in pairs(ESPFolder:GetChildren()) do
        v:Destroy()
    end
    ESPObjects = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local isKiller = false
                -- check if player is killer (game-specific)
                if char:FindFirstChild("KillerTag") or char:FindFirstChild("IsKiller") then
                    isKiller = true
                end
                local color = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 150, 255)
                if (isKiller and Config.ESP_Killer) or (not isKiller and Config.ESP_Survivor) then
                    local bb, dist = createESP(player, color, isKiller)
                    if bb then
                        table.insert(ESPObjects, {player = player, billboard = bb, distLabel = dist})
                    end
                end
            end
        end
    end
end

-- 2. Auto Killer
local function autoKiller()
    if not Config.AutoKiller then return end
    if StartRoulette then
        pcall(function()
            StartRoulette:FireServer()
        end)
    end
    if LoadPropKiller then
        pcall(function()
            LoadPropKiller:FireServer()
        end)
    end
end

-- 3. Auto Kill (when local player is killer)
local function autoKill()
    if not Config.AutoKill then return end
    if not KnifeOnHit then return end
    local char = LocalPlayer.Character
    if not char then return end
    -- check if we have knife
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hasKnife = backpack and backpack:FindFirstChild("Knife")
    if not hasKnife then
        local tool = char:FindFirstChild("Knife")
        hasKnife = tool ~= nil
    end
    if hasKnife then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local targetChar = player.Character
                if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                    local dist = (char.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude
                    if dist < 10 then
                        pcall(function()
                            KnifeOnHit:FireServer(targetChar)
                        end)
                    end
                end
            end
        end
    end
end

-- 4. Auto Escape
local function autoEscape()
    if not Config.AutoEscape then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    -- find exit gate
    local exit = workspace:FindFirstChild("Exit") or workspace:FindFirstChild("ExitGate")
    if exit then
        char.HumanoidRootPart.CFrame = exit.CFrame + Vector3.new(0, 3, 0)
    end
end

-- 5. Auto Save (downed players)
local function autoSave()
    if not Config.AutoSave then return end
    if not BreakFree then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character
            if targetChar then
                local humanoid = targetChar:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health <= 0 then
                    -- find proximity prompt
                    for _, v in ipairs(targetChar:GetDescendants()) do
                        if v:IsA("ProximityPrompt") then
                            pcall(function()
                                fireproximityprompt(v)
                            end)
                            pcall(function()
                                BreakFree:FireServer(player)
                            end)
                        end
                    end
                end
            end
        end
    end
end

-- 6. TP to knocked player
local function tpKnock()
    if not Config.TPKnock then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local humanoid = targetChar:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health <= 0 then
                    char.HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                    break
                end
            end
        end
    end
end

-- 7. God Mode
local function godMode()
    if not Config.GodMode then return end
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        end
    end
end

-- 8. Auto Copy Remote
local function autoCopyRemote()
    if not Config.AutoCopyRemote then return end
    local remoteList = {}
    for name, remote in pairs(Remotes) do
        if remote:IsA("RemoteEvent") then
            table.insert(remoteList, name)
        end
    end
    local text = table.concat(remoteList, "\n")
    pcall(function()
        setclipboard(text)
    end)
end

-- ============================================================
--  MY SELF PANEL
-- ============================================================
local function getGameData()
    local data = {}
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    data.Name = LocalPlayer.Name
    data.DisplayName = LocalPlayer.DisplayName
    data.UserId = LocalPlayer.UserId
    data.Health = humanoid and humanoid.Health or 0
    data.MaxHealth = humanoid and humanoid.MaxHealth or 0
    data.WalkSpeed = humanoid and humanoid.WalkSpeed or 0
    data.JumpPower = humanoid and humanoid.JumpPower or 0
    -- game data
    local gameTime = workspace:FindFirstChild("TimeLeft") or workspace:FindFirstChild("Timer")
    data.TimeLeft = gameTime and gameTime.Value or "N/A"
    data.Map = workspace:FindFirstChild("MapName") and workspace.MapName.Value or "Unknown"
    data.Killer = "Unknown"
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        if c and (c:FindFirstChild("KillerTag") or c:FindFirstChild("IsKiller")) then
            data.Killer = player.Name
        end
    end
    return data
end

local function showMySelf()
    local data = getGameData()
    local info = "Name: " .. data.Name .. "\nDisplay: " .. data.DisplayName .. "\nUserId: " .. tostring(data.UserId) ..
        "\nHealth: " .. tostring(data.Health) .. "/" .. tostring(data.MaxHealth) ..
        "\nWalkSpeed: " .. tostring(data.WalkSpeed) .. "\nJumpPower: " .. tostring(data.JumpPower) ..
        "\n\nTime Left: " .. tostring(data.TimeLeft) .. "\nMap: " .. data.Map .. "\nKiller: " .. data.Killer
    local msg = Instance.new("Message")
    msg.Text = info
    msg.Parent = CoreGui
    task.wait(5)
    msg:Destroy()
end

-- ============================================================
--  CREATE TOGGLES
-- ============================================================
createToggle("Auto Killer", 1, function(v) Config.AutoKiller = v end)
createToggle("Auto Kill", 2, function(v) Config.AutoKill = v end)
createToggle("Auto Escape", 3, function(v) Config.AutoEscape = v end)
createToggle("Auto Save", 4, function(v) Config.AutoSave = v end)
createToggle("TP to Knock", 5, function(v) Config.TPKnock = v end)
createToggle("ESP Survivor (Blue)", 6, function(v) Config.ESP_Survivor = v; updateESP() end)
createToggle("ESP Killer (Red)", 7, function(v) Config.ESP_Killer = v; updateESP() end)
createToggle("God Mode", 8, function(v) Config.GodMode = v end)
createToggle("Auto Copy Remote", 9, function(v) Config.AutoCopyRemote = v; autoCopyRemote() end)

local MySelfBtn = Instance.new("TextButton")
MySelfBtn.Name = "MySelfBtn"
MySelfBtn.Size = UDim2.new(1, -4, 0, 34)
MySelfBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
MySelfBtn.Text = "My Self (Account + Game Data)"
MySelfBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MySelfBtn.TextSize = 12
MySelfBtn.Font = Enum.Font.GothamBold
MySelfBtn.BorderSizePixel = 0
MySelfBtn.LayoutOrder = 10
MySelfBtn.Parent = ScrollFrame

local MySelfCorner = Instance.new("UICorner")
MySelfCorner.CornerRadius = UDim.new(0, 6)
MySelfCorner.Parent = MySelfBtn

MySelfBtn.MouseButton1Click:Connect(showMySelf)

-- ============================================================
--  MAIN LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()
    -- update ESP
    if Config.ESP_Survivor or Config.ESP_Killer then
        for _, obj in ipairs(ESPObjects) do
            if obj.player.Character and obj.player.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (Camera.CFrame.Position - obj.player.Character.HumanoidRootPart.Position).Magnitude
                obj.distLabel.Text = string.format("%.0f studs", dist)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Config.ESP_Survivor or Config.ESP_Killer then
            updateESP()
        end
        autoKiller()
        autoKill()
        autoEscape()
        autoSave()
        tpKnock()
        godMode()
    end
end)

-- Initial ESP
updateESP()

print("[FxA Supreme] Survive The Killer V1 loaded.")
