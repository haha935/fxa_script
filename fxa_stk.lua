--[[
    FxA Supreme | Survive The Killer V1 | Delta Executor
    Design: v2 (numbered tabs + status strip + card layout)
    All features: AutoKiller, AutoKill, AutoEscape, AutoSave, TPKnock,
    ESP (Survivor/Killer/Downed + Locker/Trap/Exit), My Self dashboard,
    Auto Copy Remote, Godmode, Noclip, Fullbright, Killer Alert, Dodge, AntiTrap
    Window: 440×410 centered | Close + Minimize | RightCtrl toggle | RightShift panic
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera
local SESSION_START     = tick()

local CONFIG = {
    BackgroundURL = "https://files.catbox.moe/0oc9zi.jpeg",
    LogoURL       = "https://files.catbox.moe/0oc9zi.jpeg",
    Theme = {
        Bg=Color3.fromRGB(8,8,14), Panel=Color3.fromRGB(18,18,28), PanelAlt=Color3.fromRGB(26,26,38),
        Card=Color3.fromRGB(32,32,46), Border=Color3.fromRGB(50,50,70), BorderHi=Color3.fromRGB(80,80,110),
        Accent=Color3.fromRGB(255,45,60), AccentDim=Color3.fromRGB(120,20,28),
        AccentSoft=Color3.fromRGB(255,120,130),
        Text=Color3.fromRGB(240,240,250), TextHi=Color3.fromRGB(255,255,255), TextDim=Color3.fromRGB(140,140,165),
        Success=Color3.fromRGB(74,222,128), Info=Color3.fromRGB(96,165,250), Gold=Color3.fromRGB(250,204,21),
    },
    LockerNames={"locker","closet","cabinet","wardrobe","hide"},
    TrapNames={"trap","beartrap","spike","mousetrap"},
    ExitNames={"exit","escape","escapedoor","exitdoor"},
    DownedTags={"helpme","help me","downed","wounded","revive"},
    TimerNames={"timer","roundtime","timeleft","countdown"},
    KillReach=6, KillCooldown=0.3, ExitFrontOffset=5,
    DodgeDistance=15, DodgeRange=30, TrapAvoidRange=12,
    WindowW=440, WindowH=410,
}

local function loadAsset(url, fn)
    if not (writefile and isfile and getcustomasset) then return nil end
    local ok = pcall(function() if not isfile(fn) then writefile(fn, game:HttpGet(url)) end end)
    if not ok then return nil end
    local ok2, a = pcall(getcustomasset, fn)
    return ok2 and a or nil
end
local BG_ASSET = loadAsset(CONFIG.BackgroundURL, "fxa_bg.png")
local LOGO_ASSET = loadAsset(CONFIG.LogoURL, "fxa_logo.png")

local State = {
    AutoBecomeKiller=false, AutoKill=false, AutoEscape=false,
    AutoBreakFree=true, AutoSavePlayer=false, TPOnDowned=false,
    AutoDodge=false, AntiTrap=false, KillerAlert=true, InfiniteJump=false,
    Fullbright=false,
    Speed=16, Jump=50, Noclip=false, Godmode=false, InfiniteStamina=false, AntiAFK=false, FOV=70,
    ESP_Survivor=false, ESP_Killer=false, ESP_Downed=false,
    ESP_Lockers=false, ESP_Traps=false, ESP_Exits=false, ESP_Distance=true, ESP_KillerArrow=false,
}

local CONNECTIONS = {}
local function track(c) table.insert(CONNECTIONS, c); return c end

local function char() return LocalPlayer.Character end
local function hrp() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function nameMatches(n,l) n=tostring(n):lower() for _,p in ipairs(l) do if n:find(p) then return true end end return false end

local function isKiller(plr)
    plr = plr or LocalPlayer
    if plr:GetAttribute("IsKiller") or plr:GetAttribute("Killer") then return true end
    local c = plr.Character; if not c then return false end
    if c:FindFirstChild("KillerTag") or c:FindFirstChild("Killer") then return true end
    local t = c:FindFirstChildOfClass("Tool")
    if t and (t.Name:lower():find("knife") or t.Name:lower():find("kill")) then return true end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h and h.DisplayName and h.DisplayName:lower():find("killer") then return true end
    return false
end

local function isDowned(plr)
    local c = plr.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h and h.Health <= 0 then return false end
    local head = c:FindFirstChild("Head")
    if head then
        for _,obj in ipairs(head:GetChildren()) do
            if obj:IsA("BillboardGui") then
                local t = obj:FindFirstChildOfClass("TextLabel")
                if t and nameMatches(t.Text, CONFIG.DownedTags) then return true end
                if nameMatches(obj.Name, CONFIG.DownedTags) then return true end
            end
        end
    end
    if c:FindFirstChild("Downed") and c.Downed:IsA("BoolValue") then return c.Downed.Value end
    return false
end

local function isGrabbed()
    local c = char(); if not c then return false end
    local h = c:FindFirstChild("HumanoidRootPart")
    if h then
        for _,w in ipairs(h:GetChildren()) do
            if w:IsA("Weld") or w:IsA("WeldConstraint") then
                if w.Part1 and w.Part1:IsDescendantOf(Workspace) then
                    local owner = Players:GetPlayerFromCharacter(w.Part1:FindFirstAncestorOfClass("Model"))
                    if owner and owner ~= LocalPlayer then return true end
                end
            end
        end
    end
    local hm = c:FindFirstChildOfClass("Humanoid")
    if hm and hm.PlatformStand then return true end
    return false
end

local function getKillerPlayer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if isKiller(plr) then return plr end
    end
    return nil
end

local function getKillerHRP()
    local k = getKillerPlayer()
    if not k or not k.Character then return nil end
    return k.Character:FindFirstChild("HumanoidRootPart")
end

local function distToKiller()
    local a = hrp(); local b = getKillerHRP()
    if not a or not b then return nil end
    return (a.Position - b.Position).Magnitude
end

local RS = ReplicatedStorage
local function safe(p,n) if not p then return nil end return p:FindFirstChild(n) end
local CR = safe(RS, "CutsceneRemotes")
local KnifeTpl = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Game")
                and RS.Assets.Game:FindFirstChild("Knives")
                and RS.Assets.Game.Knives:FindFirstChild("KnifeToolTemplate")

local Remotes = {
    StartRoulette  = safe(CR, "StartRoulette"),
    Preload        = safe(CR, "Preload"),
    LoadPropKiller = safe(CR, "LoadPropKiller"),
    StartCutscene  = safe(CR, "StartCutscene"),
    StartCountdown = safe(RS, "StartCountdown"),
    StopCountdown  = safe(RS, "StopCountdown"),
    BreakFree      = safe(RS, "BreakFree"),
    KnifeOnHit     = safe(KnifeTpl, "OnHit"),
    KnifeSwing     = safe(KnifeTpl, "SwingKnife"),
}

local EscapeRemotes = {}
task.spawn(function()
    for _, o in ipairs(RS:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
            local n = o.Name:lower()
            if (n:find("escape") or n:find("exit") or n:find("breakfree") or n:find("break")) then
                table.insert(EscapeRemotes, o)
            end
        end
    end
end)

local function getMyKnife() local c=char(); if not c then return nil end return c:FindFirstChild("Knife") end
local function getKnifeHitRemote()
    local k = getMyKnife(); if k then local h = k:FindFirstChild("OnHit"); if h then return h end end
    return Remotes.KnifeOnHit
end
local function getKnifeSwingRemote()
    local k = getMyKnife(); if k then local s = k:FindFirstChild("SwingKnife"); if s then return s end end
    return Remotes.KnifeSwing
end

local lastRoundSignal = 0
track(Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") and c.Name:lower():find("map") then lastRoundSignal = os.clock() end
end))
track(LocalPlayer.CharacterAdded:Connect(function() lastRoundSignal = os.clock() end))

-- AUTO KILLER (100% burst)
task.spawn(function()
    while true do
        if State.AutoBecomeKiller and not isKiller(LocalPlayer) then
            pcall(function()
                if Remotes.StartRoulette then
                    Remotes.StartRoulette:FireServer()
                    Remotes.StartRoulette:FireServer(LocalPlayer)
                    Remotes.StartRoulette:FireServer(LocalPlayer.UserId)
                end
            end)
            pcall(function()
                if Remotes.Preload then
                    Remotes.Preload:FireServer(LocalPlayer)
                    Remotes.Preload:FireServer(LocalPlayer, "Killer")
                end
            end)
            pcall(function()
                if Remotes.LoadPropKiller then
                    Remotes.LoadPropKiller:FireServer(LocalPlayer)
                    Remotes.LoadPropKiller:FireServer(LocalPlayer, true)
                    Remotes.LoadPropKiller:FireServer()
                end
            end)
            pcall(function()
                if Remotes.StartCutscene then
                    Remotes.StartCutscene:FireServer(LocalPlayer)
                    Remotes.StartCutscene:FireServer("Killer", LocalPlayer)
                end
            end)
            local burst = os.clock() - lastRoundSignal < 4
            task.wait(burst and 0.1 or 0.8)
        else task.wait(0.5) end
    end
end)

local lastKill = 0
local function nearestSurvivor()
    local myHrp = hrp(); if not myHrp then return nil end
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isKiller(plr) and not isDowned(plr) then
            local c = plr.Character
            local p = c and c:FindFirstChild("HumanoidRootPart")
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if p and h and h.Health > 0 then
                local d = (p.Position - myHrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = p end
            end
        end
    end
    return best
end

local function fireKillOn(target)
    if not target then return end
    local c = char(); if not c then return end
    local tchar = target.Parent
    local thum = tchar and tchar:FindFirstChildOfClass("Humanoid")
    local hit = getKnifeHitRemote()
    local swing = getKnifeSwingRemote()
    if swing then
        pcall(function() swing:FireServer() end)
        pcall(function() swing:FireServer(target) end)
    end
    if hit then
        pcall(function() hit:FireServer(target) end)
        pcall(function() hit:FireServer(thum) end)
        pcall(function() hit:FireServer(tchar) end)
        pcall(function() hit:FireServer(tchar, target) end)
        pcall(function() hit:FireServer(target.Position) end)
    end
    local tool = c:FindFirstChild("Knife") or c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

task.spawn(function()
    while true do
        if State.AutoKill and isKiller(LocalPlayer) then
            local now = os.clock()
            if now - lastKill >= CONFIG.KillCooldown then
                local target = nearestSurvivor()
                local myHrp = hrp()
                if target and myHrp then
                    local dist = (target.Position - myHrp.Position).Magnitude
                    if dist > CONFIG.KillReach then
                        local dir = (myHrp.Position - target.Position).Unit
                        local goal = CFrame.new(target.Position + dir * CONFIG.KillReach)
                        TweenService:Create(myHrp, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {CFrame = goal}):Play()
                    else
                        local dir = (myHrp.Position - target.Position).Unit
                        myHrp.CFrame = CFrame.new(target.Position + dir * (CONFIG.KillReach - 1))
                    end
                    fireKillOn(target)
                    lastKill = now
                end
            end
        end
        task.wait(0.05)
    end
end)

local function findProximityPrompt(c)
    if not c then return nil end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function tryRevive(target)
    local tchar = target.Parent
    if not tchar then return end
    local pp = findProximityPrompt(tchar)
    if pp and fireproximityprompt then pcall(fireproximityprompt, pp); return end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local n = d.Name:lower()
            if n:find("revive") or n:find("help") or n:find("save") then
                pcall(function() d:FireServer(tchar) end)
                pcall(function() d:FireServer(tchar.Humanoid) end)
            end
        end
    end
end

local function nearestDowned()
    local myHrp = hrp(); if not myHrp then return nil end
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isKiller(plr) and isDowned(plr) then
            local p = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if p then
                local d = (p.Position - myHrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = p end
            end
        end
    end
    return best
end

local function saveAllDowned()
    local saved = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isDowned(plr) then
            local p = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local myHrp = hrp()
            if p and myHrp then
                myHrp.CFrame = CFrame.new(p.Position + Vector3.new(0,3,0))
                task.wait(0.12)
                tryRevive(p)
                saved = saved + 1
            end
        end
    end
    return saved
end

task.spawn(function()
    while true do
        if State.AutoSavePlayer then
            local t = nearestDowned(); local myHrp = hrp()
            if t and myHrp then
                myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0))
                task.wait(0.05); tryRevive(t)
            end
        end
        if State.TPOnDowned then
            local t = nearestDowned(); local myHrp = hrp()
            if t and myHrp then myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0)) end
        end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while true do
        if State.AutoBreakFree and isGrabbed() then
            pcall(function()
                if Remotes.BreakFree then
                    Remotes.BreakFree:FireServer()
                    Remotes.BreakFree:FireServer(LocalPlayer)
                end
            end)
            for _, r in ipairs(EscapeRemotes) do
                pcall(function() if r:IsA("RemoteEvent") then r:FireServer() end end)
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        if State.AutoDodge and not isKiller(LocalPlayer) then
            local d = distToKiller()
            if d and d < CONFIG.DodgeDistance then
                local myHrp = hrp()
                local kHrp = getKillerHRP()
                if myHrp and kHrp then
                    local dir = (myHrp.Position - kHrp.Position).Unit
                    local dest = myHrp.Position + dir * CONFIG.DodgeRange
                    local ray = Ray.new(myHrp.Position, (dest - myHrp.Position))
                    local hitPart = Workspace:FindPartOnRay(ray, char())
                    if not hitPart then
                        myHrp.CFrame = CFrame.new(dest)
                    else
                        myHrp.CFrame = CFrame.new(myHrp.Position + dir * 10)
                    end
                end
            end
        end
        task.wait(0.15)
    end
end)

task.spawn(function()
    while true do
        if State.AntiTrap then
            local myHrp = hrp()
            if myHrp then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and nameMatches(obj.Name, CONFIG.TrapNames) then
                        local d = (obj.Position - myHrp.Position).Magnitude
                        if d < CONFIG.TrapAvoidRange then
                            local dir = (myHrp.Position - obj.Position).Unit
                            myHrp.CFrame = CFrame.new(myHrp.Position + dir * 12)
                            break
                        end
                    end
                end
            end
        end
        task.wait(0.25)
    end
end)

local lastAlertDist = math.huge
task.spawn(function()
    while true do
        if State.KillerAlert then
            local d = distToKiller()
            if d and d < 35 and d < lastAlertDist - 5 then
                lastAlertDist = d
                pcall(function()
                    local s = Instance.new("Sound", LocalPlayer:FindFirstChildOfClass("PlayerGui") or Workspace)
                    s.SoundId = "rbxassetid://9120386436"
                    s.Volume = 0.6
                    s:Play()
                    task.delay(2, function() s:Destroy() end)
                end)
            elseif d and d > 40 then
                lastAlertDist = math.huge
            end
        end
        task.wait(0.4)
    end
end)

track(RunService.Heartbeat:Connect(function()
    if State.Godmode then
        local h = hum()
        if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
        local c = char()
        if c then
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then
                    for _, t in ipairs(d:GetChildren()) do
                        if t:IsA("TouchTransmitter") then pcall(function() t:Destroy() end) end
                    end
                end
            end
        end
    end
    if State.InfiniteStamina then
        local c = char()
        if c then
            for _, o in ipairs(c:GetDescendants()) do
                if o:IsA("NumberValue") and nameMatches(o.Name, {"stamina","sprint","energy"}) then o.Value = 100 end
            end
        end
    end
    if State.Noclip then
        local c = char()
        if c then
            for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        end
    end
    if State.Speed ~= 16 or State.Jump ~= 50 then
        local h = hum()
        if h then h.WalkSpeed = State.Speed; h.UseJumpPower = true; h.JumpPower = State.Jump end
    end
end))

local originalAmbient, originalOutdoor, originalBrightness
task.spawn(function()
    while true do
        if State.Fullbright then
            if not originalAmbient then
                originalAmbient = Lighting.Ambient
                originalOutdoor = Lighting.OutdoorAmbient
                originalBrightness = Lighting.Brightness
            end
            Lighting.Ambient = Color3.fromRGB(180,180,180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
            Lighting.Brightness = 3
            Lighting.FogEnd = 100000
        else
            if originalAmbient then
                Lighting.Ambient = originalAmbient
                Lighting.OutdoorAmbient = originalOutdoor
                Lighting.Brightness = originalBrightness
                originalAmbient = nil
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        if Camera and Camera.FieldOfView ~= State.FOV then
            Camera.FieldOfView = State.FOV
        end
        task.wait(0.3)
    end
end)

track(UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

local function findExitDoor()
    local myHrp = hrp(); if not myHrp then return nil end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and nameMatches(obj.Name, CONFIG.ExitNames) then
            local d = (obj.Position - myHrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = obj end
        end
    end
    return best
end

local function isEscapeOpen(door)
    if not door then return false end
    if not door.CanCollide then return true end
    if door.Transparency > 0.5 then return true end
    local f = door:FindFirstChild("Open") or door:FindFirstChild("IsOpen")
    if f and f:IsA("BoolValue") and f.Value then return true end
    for _, o in ipairs(ReplicatedStorage:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then
            if o.Value <= 0 and o.Value > -10 then return true end
        end
    end
    return false
end

task.spawn(function()
    while true do
        if State.AutoEscape and not isKiller(LocalPlayer) then
            local d = findExitDoor(); local myHrp = hrp()
            if d and myHrp and isEscapeOpen(d) then
                local look = d.CFrame.LookVector
                local f = d.Position - look * CONFIG.ExitFrontOffset
                myHrp.CFrame = CFrame.new(f, f + look)
                for _, r in ipairs(EscapeRemotes) do
                    pcall(function()
                        if r:IsA("RemoteEvent") then
                            r:FireServer(); r:FireServer(d); r:FireServer(LocalPlayer)
                        end
                    end)
                end
            end
        end
        task.wait(0.25)
    end
end)

local playerData = {}
local killerArrow = nil

local function createNameplate(plr, head, color)
    local bb = Instance.new("BillboardGui")
    bb.Name="FXA_NP"; bb.Adornee=head
    bb.Size=UDim2.new(0,220,0,46); bb.StudsOffset=Vector3.new(0,2.6,0)
    bb.AlwaysOnTop=true; bb.Parent=head
    local n = Instance.new("TextLabel")
    n.Name="FXA_Name"; n.Size=UDim2.new(1,0,0.6,0); n.BackgroundTransparency=1
    n.Text=plr.Name; n.TextColor3=color; n.TextStrokeTransparency=0
    n.TextStrokeColor3=Color3.new(0,0,0); n.Font=Enum.Font.GothamBold; n.TextScaled=true
    n.Parent=bb
    local i = Instance.new("TextLabel")
    i.Name="FXA_Info"; i.Size=UDim2.new(1,0,0.4,0); i.Position=UDim2.new(0,0,0.6,0)
    i.BackgroundTransparency=1; i.Text=""; i.TextColor3=color
    i.TextStrokeTransparency=0.3; i.TextStrokeColor3=Color3.new(0,0,0)
    i.Font=Enum.Font.Gotham; i.TextScaled=true; i.Parent=bb
    return bb
end

local function playerESP()
    if not (State.ESP_Survivor or State.ESP_Killer or State.ESP_Downed) then
        for p, d in pairs(playerData) do
            if d.hl then d.hl:Destroy() end
            if d.bb then d.bb:Destroy() end
        end
        playerData = {}; return
    end
    local myHrp = hrp()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = plr.Character
            if c then
                local head = c:FindFirstChild("Head")
                local root = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                local killer = isKiller(plr)
                local downed = isDowned(plr)
                local alive = h and h.Health > 0
                local show = alive and (
                    (State.ESP_Survivor and not killer and not downed)
                    or (State.ESP_Killer and killer)
                    or (State.ESP_Downed and downed))
                if show and head then
                    local color = killer and Color3.fromRGB(255,60,60)
                               or downed and Color3.fromRGB(255,200,0)
                               or Color3.fromRGB(70,160,255)
                    if not playerData[plr] then
                        local hl = Instance.new("Highlight")
                        hl.Name="FXA_HL"; hl.FillColor=color; hl.OutlineColor=color
                        hl.FillTransparency=0.55; hl.OutlineTransparency=0
                        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee=c; hl.Parent=c
                        playerData[plr] = {hl=hl, bb=createNameplate(plr, head, color)}
                    else
                        playerData[plr].hl.FillColor=color
                        playerData[plr].hl.OutlineColor=color
                        local nl = playerData[plr].bb:FindFirstChild("FXA_Name")
                        local il = playerData[plr].bb:FindFirstChild("FXA_Info")
                        if nl then nl.TextColor3=color end
                        if il then
                            il.TextColor3=color
                            if State.ESP_Distance and myHrp and root then
                                local d = math.floor((root.Position - myHrp.Position).Magnitude)
                                local tag = killer and "KILLER" or downed and "DOWNED" or "SURVIVOR"
                                il.Text = tag .. " | " .. d .. "m"
                            else
                                il.Text = killer and "KILLER" or downed and "DOWNED" or "SURVIVOR"
                            end
                        end
                    end
                elseif playerData[plr] then
                    playerData[plr].hl:Destroy()
                    playerData[plr].bb:Destroy()
                    playerData[plr] = nil
                end
            end
        end
    end
end

local function ensureKillerArrow()
    if not State.ESP_KillerArrow then
        if killerArrow then pcall(function() killerArrow.att:Destroy() end); pcall(function() killerArrow.att2:Destroy() end); killerArrow = nil end
        return
    end
    local myHead = char() and char():FindFirstChild("Head")
    if not myHead then return end
    if not killerArrow or not killerArrow.att.Parent then
        local att = Instance.new("Attachment", myHead)
        att.Name = "FXA_ArrowAtt"
        local beam = Instance.new("Beam", att)
        beam.Name = "FXA_ArrowBeam"
        beam.Attachment0 = att
        beam.Width0 = 1.2; beam.Width1 = 0.2
        beam.Color = ColorSequence.new(Color3.fromRGB(255,45,60))
        beam.FaceCamera = true
        beam.Transparency = NumberSequence.new(0)
        local att2 = Instance.new("Attachment", myHead)
        att2.Name = "FXA_ArrowEnd"
        att2.Position = Vector3.new(0, 4, 0)
        beam.Attachment1 = att2
        killerArrow = {att=att, att2=att2, beam=beam}
    end
    local kHrp = getKillerHRP()
    if kHrp and killerArrow.att2 then
        local dir = (kHrp.Position - myHead.Position).Unit
        killerArrow.att2.Position = Vector3.new(dir.X * 5, 4, dir.Z * 5)
    end
end
track(RunService.Heartbeat:Connect(function() ensureKillerArrow() end))

local lockerHL, trapHL, exitHL = {}, {}, {}
local function clearHL(t) for _,h in pairs(t) do h:Destroy() end return {} end

local function lockerESP()
    lockerHL = clearHL(lockerHL)
    if not State.ESP_Lockers then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and nameMatches(obj.Name, CONFIG.LockerNames) then
            local occ = false
            for _, plr in ipairs(Players:GetPlayers()) do
                local p = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if p and (p.Position - obj.Position).Magnitude < 6 then occ=true break end
            end
            local hl = Instance.new("Highlight")
            hl.FillColor = occ and Color3.fromRGB(255,100,100) or Color3.fromRGB(100,100,255)
            hl.OutlineColor=Color3.new(1,1,1); hl.FillTransparency=0.6
            hl.Adornee=obj; hl.Parent=obj
            lockerHL[obj]=hl
        end
    end
end

local function trapESP()
    trapHL = clearHL(trapHL)
    if not State.ESP_Traps then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and nameMatches(obj.Name, CONFIG.TrapNames) then
            local hl = Instance.new("Highlight")
            hl.FillColor=Color3.fromRGB(255,165,0); hl.OutlineColor=Color3.new(1,1,1)
            hl.FillTransparency=0.4; hl.Adornee=obj; hl.Parent=obj
            trapHL[obj]=hl
        end
    end
end

local function exitESP()
    exitHL = clearHL(exitHL)
    if not State.ESP_Exits then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and nameMatches(obj.Name, CONFIG.ExitNames) then
            local hl = Instance.new("Highlight")
            hl.FillColor=Color3.fromRGB(0,255,255); hl.OutlineColor=Color3.new(1,1,1)
            hl.FillTransparency=0.4; hl.Adornee=obj; hl.Parent=obj
            exitHL[obj]=hl
        end
    end
end

track(RunService.Heartbeat:Connect(function()
    if State.ESP_Survivor or State.ESP_Killer or State.ESP_Downed then playerESP() end
end))
task.spawn(function()
    while true do
        if State.ESP_Lockers then lockerESP() end
        if State.ESP_Traps then trapESP() end
        if State.ESP_Exits then exitESP() end
        task.wait(1)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════
local T = CONFIG.Theme
local mk = function(c,p,par) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end if par then o.Parent=par end return o end
local corner = function(p,r) return mk("UICorner",{CornerRadius=r or UDim.new(0,8)},p) end
local stroke = function(p,c,t) return mk("UIStroke",{Color=c or T.Border, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local pad = function(p,n) return mk("UIPadding",{PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n)},p) end

local ok, gui = pcall(function()
    local g = Instance.new("ScreenGui")
    g.Name="FXA_"..tostring(math.random(1,1e6))
    g.ResetOnSpawn=false; g.IgnoreGuiInset=true
    g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; g.DisplayOrder=999999
    g.Parent=CoreGui; return g
end)
if not ok or not gui then
    gui = Instance.new("ScreenGui")
    gui.Name="FxA_Supreme"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=999999
    gui.Parent=LocalPlayer:WaitForChild("PlayerGui")
end

local W, H = CONFIG.WindowW, CONFIG.WindowH
local Main = mk("Frame", {
    Name="Main", Size=UDim2.fromOffset(W,H),
    Position=UDim2.new(0.5,-W/2,0.5,-H/2),
    BackgroundColor3=T.Bg, BorderSizePixel=0, ClipsDescendants=true,
}, gui)
corner(Main, UDim.new(0,16)); stroke(Main, T.Border, 1)

if BG_ASSET then
    mk("ImageLabel", {
        Name="BG", Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1, Image=BG_ASSET,
        ScaleType=Enum.ScaleType.Crop, ImageTransparency=0.5, ZIndex=1,
    }, Main)
end
local BGDim = mk("Frame", {
    Size=UDim2.fromScale(1,1),
    BackgroundColor3=Color3.fromRGB(6,6,10),
    BackgroundTransparency=BG_ASSET and 0.55 or 0.05,
    BorderSizePixel=0, ZIndex=2,
}, Main)
mk("UIGradient", {Rotation=90, Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,0.85)})}, BGDim)

-- TOP BAR
local TopBar = mk("Frame", {
    Size=UDim2.new(1,0,0,60),
    BackgroundColor3=Color3.fromRGB(12,12,20), BackgroundTransparency=0.25,
    BorderSizePixel=0, ZIndex=10, Active=true,
}, Main)

local LOGO_SIZE = 42
local Logo = mk("ImageLabel", {
    Name="Logo", Size=UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
    Position=UDim2.fromOffset(12, 9),
    BackgroundTransparency=1,
    Image=LOGO_ASSET or "",
    ScaleType=Enum.ScaleType.Crop,
    BorderSizePixel=0, ZIndex=11,
}, TopBar)
corner(Logo, UDim.new(1, 0))
mk("UIStroke", {Color=T.Accent, Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, Logo)

mk("TextLabel", {
    Size=UDim2.fromOffset(200,17), Position=UDim2.fromOffset(62,10),
    BackgroundTransparency=1, Text="FxA Supreme",
    TextColor3=T.TextHi, Font=Enum.Font.GothamBlack, TextSize=15,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=11,
}, TopBar)
mk("TextLabel", {
    Size=UDim2.fromOffset(200,12), Position=UDim2.fromOffset(62,29),
    BackgroundTransparency=1, Text="Survive The Killer V1",
    TextColor3=T.Accent, Font=Enum.Font.GothamBold, TextSize=9,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=11,
}, TopBar)

local CloseBtn = mk("TextButton", {
    Size=UDim2.fromOffset(26,26), Position=UDim2.new(1,-34,0,17),
    BackgroundColor3=Color3.fromRGB(90,26,34),
    Text="×", TextColor3=T.TextHi,
    Font=Enum.Font.GothamBlack, TextSize=16,
    BorderSizePixel=0, ZIndex=250, AutoButtonColor=false,
}, TopBar)
corner(CloseBtn, UDim.new(0,7))
stroke(CloseBtn, T.Accent, 1.5)

local MinBtn = mk("TextButton", {
    Size=UDim2.fromOffset(26,26), Position=UDim2.new(1,-66,0,17),
    BackgroundColor3=T.PanelAlt,
    Text="—", TextColor3=T.TextHi,
    Font=Enum.Font.GothamBlack, TextSize=14,
    BorderSizePixel=0, ZIndex=250, AutoButtonColor=false,
}, TopBar)
corner(MinBtn, UDim.new(0,7))
stroke(MinBtn, T.Border, 1)

-- STATUS STRIP
local StatusStrip = mk("Frame", {
    Size=UDim2.new(1,-20,0,32), Position=UDim2.fromOffset(10,62),
    BackgroundColor3=T.Panel, BackgroundTransparency=0.3,
    BorderSizePixel=0, ZIndex=10,
}, Main)
corner(StatusStrip, UDim.new(0,8)); stroke(StatusStrip, T.Border, 1)

local function statusCol(posX, label, color, initial)
    local holder = mk("Frame", {
        Size=UDim2.new(0.33,0,1,0), Position=UDim2.new(posX,0,0,0),
        BackgroundTransparency=1,
    }, StatusStrip)
    mk("TextLabel", {
        Size=UDim2.new(1,0,0,10), Position=UDim2.fromOffset(0,5),
        BackgroundTransparency=1, Text=label,
        TextColor3=T.TextDim, Font=Enum.Font.GothamBold, TextSize=7,
        TextXAlignment=Enum.TextXAlignment.Center,
    }, holder)
    local val = mk("TextLabel", {
        Size=UDim2.new(1,0,0,12), Position=UDim2.fromOffset(0,16),
        BackgroundTransparency=1, Text=initial,
        TextColor3=color, Font=Enum.Font.GothamBlack, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Center,
    }, holder)
    if posX > 0 then
        mk("Frame", {
            Size=UDim2.new(0,1,0.6,0), Position=UDim2.new(0,-0.5,0.2,0),
            BackgroundColor3=T.Border, BorderSizePixel=0,
        }, holder)
    end
    return val
end

local killerVal = statusCol(0, "KILLER", T.Accent, "—")
local distVal = statusCol(0.33, "DISTANCE", T.Gold, "—")
local timeVal = statusCol(0.66, "TIME LEFT", T.Info, "--:--")

-- SIDEBAR
local SIDEBAR_W = 96
local Sidebar = mk("Frame", {
    Size=UDim2.new(0,SIDEBAR_W,1,-104), Position=UDim2.fromOffset(10,100),
    BackgroundColor3=T.Panel, BackgroundTransparency=0.2,
    BorderSizePixel=0, ZIndex=10,
}, Main)
corner(Sidebar, UDim.new(0,10)); pad(Sidebar, 5)
mk("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, Sidebar)

local Content = mk("ScrollingFrame", {
    Size=UDim2.new(1, -(SIDEBAR_W + 10 + 6 + 10), 1, -104),
    Position=UDim2.fromOffset(10 + SIDEBAR_W + 6, 100),
    BackgroundColor3=T.Panel, BackgroundTransparency=0.2,
    BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.Accent,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    ZIndex=10, ClipsDescendants=true,
}, Main)
corner(Content, UDim.new(0,10)); pad(Content, 7)
mk("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder}, Content)

-- DRAG HANDLER with button-area skip
do
    local dragging, dragStart, startPos
    local function isOverBtn(p, btn)
        local a = btn.AbsolutePosition
        local s = btn.AbsoluteSize
        return p.X >= a.X and p.X <= a.X + s.X
           and p.Y >= a.Y and p.Y <= a.Y + s.Y
    end
    track(TopBar.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            if isOverBtn(input.Position, CloseBtn) then return end
            if isOverBtn(input.Position, MinBtn) then return end
            dragging=true; dragStart=input.Position; startPos=Main.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end))
end

-- TABS
local tabs, currentTab = {}, nil
local function switchTab(n)
    for _,f in pairs(tabs) do f.Visible=false end
    if tabs[n] then tabs[n].Visible=true; currentTab=n end
end

local tabIndex = 0
local function createTabButton(title, key)
    tabIndex = tabIndex + 1
    local numStr = string.format("%02d", tabIndex)
    local btn = mk("TextButton", {
        Size=UDim2.new(1,0,0,30),
        BackgroundColor3=T.PanelAlt, BackgroundTransparency=0.4,
        Text="", TextColor3=T.Text,
        Font=Enum.Font.GothamMedium, TextSize=10,
        BorderSizePixel=0, AutoButtonColor=false,
    }, Sidebar)
    corner(btn, UDim.new(0,7))

    mk("TextLabel", {
        Size=UDim2.fromOffset(20,30), Position=UDim2.fromOffset(6,0),
        BackgroundTransparency=1, Text=numStr,
        TextColor3=T.AccentDim, Font=Enum.Font.GothamBlack, TextSize=8,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, btn)
    mk("TextLabel", {
        Size=UDim2.new(1,-30,1,0), Position=UDim2.fromOffset(24,0),
        BackgroundTransparency=1, Text=title,
        TextColor3=T.Text, Font=Enum.Font.GothamMedium, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, btn)
    local accent = mk("Frame", {
        Size=UDim2.new(0,3,0,0), Position=UDim2.new(1,-3,0.5,0),
        BackgroundColor3=T.Accent, BorderSizePixel=0,
    }, btn)
    corner(accent, UDim.new(1,0))

    local page = mk("Frame", {
        Name=key, Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, Visible=false,
    }, Content)
    mk("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder}, page)
    tabs[key]=page

    btn.MouseEnter:Connect(function() btn.BackgroundTransparency=0.15 end)
    btn.MouseLeave:Connect(function() if currentTab~=key then btn.BackgroundTransparency=0.4 end end)
    btn.MouseButton1Click:Connect(function()
        for _,b in ipairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundTransparency=0.4
                for _,ch in ipairs(b:GetChildren()) do
                    if ch:IsA("TextLabel") then ch.TextColor3 = T.Text end
                end
                local fr = b:FindFirstChildOfClass("Frame")
                if fr then TweenService:Create(fr, TweenInfo.new(0.15), {Size=UDim2.new(0,3,0,0)}):Play() end
            end
        end
        btn.BackgroundTransparency=0.15
        for _,ch in ipairs(btn:GetChildren()) do
            if ch:IsA("TextLabel") then ch.TextColor3 = T.Accent end
        end
        TweenService:Create(accent, TweenInfo.new(0.15), {Size=UDim2.new(0,3,0,18)}):Play()
        switchTab(key)
    end)
    return page
end

local function sectionHeader(parent, title)
    local holder = mk("Frame", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1}, parent)
    mk("Frame", {Size=UDim2.new(0,2,0,12), Position=UDim2.fromOffset(0,3),
        BackgroundColor3=T.Accent, BorderSizePixel=0}, holder)
    mk("TextLabel", {
        Size=UDim2.new(1,-10,0,14), Position=UDim2.fromOffset(8,0),
        BackgroundTransparency=1, Text=title:upper(),
        TextColor3=T.TextHi, Font=Enum.Font.GothamBlack, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, holder)
    mk("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.fromOffset(0,19),
        BackgroundColor3=T.Border, BackgroundTransparency=0.5, BorderSizePixel=0}, holder)
    return holder
end

local function toggle(parent, title, desc, default, cb)
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0, desc and 38 or 28),
        BackgroundColor3=T.Card, BackgroundTransparency=0.35, BorderSizePixel=0,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    stroke(row, T.Border, 1)
    mk("TextLabel", {
        Size=UDim2.new(1,-46,0, desc and 14 or 28),
        Position=UDim2.fromOffset(0,0), BackgroundTransparency=1, Text=title,
        TextColor3=T.Text, Font=Enum.Font.GothamMedium, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment= desc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    }, row)
    if desc then
        mk("TextLabel", {
            Size=UDim2.new(1,-46,0,10), Position=UDim2.fromOffset(0,14),
            BackgroundTransparency=1, Text=desc, TextColor3=T.TextDim,
            Font=Enum.Font.Gotham, TextSize=8, TextXAlignment=Enum.TextXAlignment.Left,
        }, row)
    end
    local st = default or false
    local sw = mk("TextButton", {
        Size=UDim2.fromOffset(30,15), Position=UDim2.new(1,-30,0.5,-7.5),
        BackgroundColor3=st and T.Accent or T.Border, Text="",
        BorderSizePixel=0, AutoButtonColor=false,
    }, row)
    corner(sw, UDim.new(0.5,0))
    local knob = mk("Frame", {
        Size=UDim2.fromOffset(11,11),
        Position=st and UDim2.new(1,-13,0.5,-5.5) or UDim2.new(0,2,0.5,-5.5),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
    }, sw)
    corner(knob, UDim.new(1,0))
    row.MouseEnter:Connect(function() row.BackgroundTransparency=0.15 end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency=0.35 end)
    sw.MouseButton1Click:Connect(function()
        st = not st
        if st then sw.BackgroundColor3=T.Accent
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(1,-13,0.5,-5.5)}):Play()
        else sw.BackgroundColor3=T.Border
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(0,2,0.5,-5.5)}):Play() end
        if cb then pcall(cb, st) end
    end)
end

local function slider(parent, title, min, max, default, cb)
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0,40),
        BackgroundColor3=T.Card, BackgroundTransparency=0.35, BorderSizePixel=0,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    stroke(row, T.Border, 1)
    mk("TextLabel", {Size=UDim2.new(1,-55,0,12), BackgroundTransparency=1, Text=title,
        TextColor3=T.Text, Font=Enum.Font.GothamMedium, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left}, row)
    local vl = mk("TextLabel", {Size=UDim2.fromOffset(55,12), Position=UDim2.new(1,-55,0,0),
        BackgroundTransparency=1, Text=tostring(default), TextColor3=T.Accent,
        Font=Enum.Font.GothamBlack, TextSize=11, TextXAlignment=Enum.TextXAlignment.Right}, row)
    local track = mk("Frame", {Size=UDim2.new(1,0,0,4), Position=UDim2.fromOffset(0,24),
        BackgroundColor3=T.Border, BorderSizePixel=0}, row)
    corner(track, UDim.new(1,0))
    local fill = mk("Frame", {Size=UDim2.new((default-min)/(max-min),0,1,0),
        BackgroundColor3=T.Accent, BorderSizePixel=0}, track)
    corner(fill, UDim.new(1,0))
    local knob = mk("Frame", {Size=UDim2.fromOffset(11,11),
        Position=UDim2.new((default-min)/(max-min),-5.5,0.5,-5.5),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=2}, track)
    corner(knob, UDim.new(1,0))
    local dragging = false
    local function upd(input)
        local r = math.clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*r + 0.5)
        fill.Size = UDim2.new(r,0,1,0); knob.Position = UDim2.new(r,-5.5,0.5,-5.5)
        vl.Text = tostring(v)
        if cb then pcall(cb, v) end
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; upd(input)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then upd(input) end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end))
end

local function button(parent, title, desc, cb)
    local row = mk("TextButton", {
        Size=UDim2.new(1,0,0, desc and 38 or 28),
        BackgroundColor3=T.Card, BackgroundTransparency=0.35,
        Text="", BorderSizePixel=0, AutoButtonColor=false,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    stroke(row, T.Border, 1)
    mk("TextLabel", {Size=UDim2.new(1,0,0, desc and 14 or 28),
        Position=UDim2.fromOffset(0,0), BackgroundTransparency=1, Text=title,
        TextColor3=T.Text, Font=Enum.Font.GothamMedium, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment= desc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center}, row)
    if desc then
        mk("TextLabel", {Size=UDim2.new(1,0,0,10), Position=UDim2.fromOffset(0,14),
            BackgroundTransparency=1, Text=desc, TextColor3=T.TextDim,
            Font=Enum.Font.Gotham, TextSize=8, TextXAlignment=Enum.TextXAlignment.Left}, row)
    end
    row.MouseEnter:Connect(function() row.BackgroundTransparency=0.15 end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency=0.35 end)
    row.MouseButton1Click:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {BackgroundTransparency=0.5}):Play()
        task.delay(0.1, function() TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency=0.15}):Play() end)
        if cb then pcall(cb) end
    end)
end

local notifHolder = mk("Frame", {
    Size=UDim2.fromOffset(200,240), Position=UDim2.new(1,-216,1,-260),
    BackgroundTransparency=1, ZIndex=100,
}, gui)
mk("UIListLayout", {
    Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder,
    VerticalAlignment=Enum.VerticalAlignment.Bottom,
    HorizontalAlignment=Enum.HorizontalAlignment.Right,
}, notifHolder)

local function notify(title, text, kind)
    local color = kind=="error" and T.Accent or kind=="success" and T.Success or T.Info
    local h = mk("Frame", {
        Size=UDim2.fromOffset(190,42),
        BackgroundColor3=T.Panel, BackgroundTransparency=0.03,
        BorderSizePixel=0, ZIndex=101,
    }, notifHolder)
    corner(h, UDim.new(0,9)); stroke(h, color, 1.5)
    mk("Frame", {Size=UDim2.new(0,3,1,-12), Position=UDim2.fromOffset(6,6),
        BackgroundColor3=color, BorderSizePixel=0}, h)
    mk("TextLabel", {Size=UDim2.new(1,-18,0,12), Position=UDim2.fromOffset(14,5),
        BackgroundTransparency=1, Text=title, TextColor3=color,
        Font=Enum.Font.GothamBlack, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left}, h)
    mk("TextLabel", {Size=UDim2.new(1,-18,0,18), Position=UDim2.fromOffset(14,18),
        BackgroundTransparency=1, Text=text, TextColor3=T.TextDim,
        Font=Enum.Font.Gotham, TextSize=8, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true}, h)
    h.Position = UDim2.new(1,300,0,0)
    TweenService:Create(h, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Position=UDim2.new(0,0,0,0)}):Play()
    task.delay(3, function()
        TweenService:Create(h, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Position=UDim2.new(1,300,0,0)}):Play()
        task.wait(0.3); h:Destroy()
    end)
end

-- TAB CONTENT
local MainPage = createTabButton("Main", "main")
sectionHeader(MainPage, "Killer")
toggle(MainPage, "Auto Become Killer", "StartRoulette + LoadPropKiller", false, function(v)
    State.AutoBecomeKiller = v
    if v then notify("Auto Killer","Burst-firing.","info") end
end)
toggle(MainPage, "Auto Kill", "Knife.OnHit at nearest", false, function(v)
    State.AutoKill = v
    if v then notify("Auto Kill","Active as killer.","info") end
end)
button(MainPage, "Force Kill Nearest (once)", nil, function()
    local t = nearestSurvivor()
    if t then fireKillOn(t); notify("Kill","Fired.","success")
    else notify("Kill","No target.","error") end
end)

sectionHeader(MainPage, "Escape")
toggle(MainPage, "Auto Escape", "Door-gated TP", false, function(v)
    State.AutoEscape = v
    if v then notify("Escape","Watching door.","info") end
end)
button(MainPage, "TP to Exit Front (once)", nil, function()
    local d = findExitDoor(); local myHrp = hrp()
    if d and myHrp then
        local look = d.CFrame.LookVector
        local f = d.Position - look * CONFIG.ExitFrontOffset
        myHrp.CFrame = CFrame.new(f, f + look)
        notify("Escape","TP'd.","success")
    else notify("Escape","No exit.","error") end
end)

sectionHeader(MainPage, "Survival")
toggle(MainPage, "Auto Break Free", "Anti-grab", true, function(v) State.AutoBreakFree=v end)
toggle(MainPage, "Auto Save Player", "TP + revive downed", false, function(v)
    State.AutoSavePlayer=v
    if v then notify("Save","Active.","info") end
end)
button(MainPage, "Save Nearest Downed", nil, function()
    local t = nearestDowned(); local myHrp = hrp()
    if t and myHrp then
        myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0))
        task.wait(0.1); tryRevive(t)
        notify("Save","Attempted.","success")
    else notify("Save","No downed.","error") end
end)
button(MainPage, "Save ALL Downed", nil, function()
    local n = saveAllDowned()
    notify("Save All", n.." player(s).","success")
end)

sectionHeader(MainPage, "Defense")
toggle(MainPage, "Auto Dodge", "Dash when killer < 15 studs", false, function(v) State.AutoDodge=v end)
toggle(MainPage, "Anti-Trap", "TP away from traps", false, function(v) State.AntiTrap=v end)

local ESPPage = createTabButton("ESP", "esp")
sectionHeader(ESPPage, "Players")
toggle(ESPPage, "Survivor (Blue)", nil, false, function(v) State.ESP_Survivor=v end)
toggle(ESPPage, "Killer (Red)", nil, false, function(v) State.ESP_Killer=v end)
toggle(ESPPage, "Downed (Gold)", nil, false, function(v) State.ESP_Downed=v end)
toggle(ESPPage, "Distance + Role", nil, true, function(v) State.ESP_Distance=v end)
toggle(ESPPage, "Killer Tracker Arrow", "3D arrow to killer", false, function(v) State.ESP_KillerArrow=v end)
sectionHeader(ESPPage, "Objects")
toggle(ESPPage, "Locker ESP", nil, false, function(v) State.ESP_Lockers=v end)
toggle(ESPPage, "Trap ESP", nil, false, function(v) State.ESP_Traps=v end)
toggle(ESPPage, "Exit ESP", nil, false, function(v) State.ESP_Exits=v end)

local MovePage = createTabButton("Move", "move")
sectionHeader(MovePage, "Character")
slider(MovePage, "Walk Speed", 16, 250, 16, function(v) State.Speed=v end)
slider(MovePage, "Jump Power", 50, 400, 50, function(v) State.Jump=v end)
slider(MovePage, "Camera FOV", 70, 130, 70, function(v) State.FOV=v end)
toggle(MovePage, "Noclip", nil, false, function(v) State.Noclip=v end)
toggle(MovePage, "Godmode", "Health + strip touch", false, function(v)
    State.Godmode=v
    if v then notify("Godmode","Active.","success") end
end)
toggle(MovePage, "Infinite Stamina", nil, false, function(v) State.InfiniteStamina=v end)
toggle(MovePage, "Infinite Jump", nil, false, function(v) State.InfiniteJump=v end)
toggle(MovePage, "Anti-AFK", nil, false, function(v)
    State.AntiAFK=v
    if v then
        track(LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
        end))
    end
end)

local VisionPage = createTabButton("Vision", "vision")
sectionHeader(VisionPage, "Lighting")
toggle(VisionPage, "Fullbright", "Max ambient, no fog", false, function(v) State.Fullbright=v end)
toggle(VisionPage, "Killer Alert Sound", "Audio ping when killer near", true, function(v) State.KillerAlert=v end)

local PlayerPage = createTabButton("Players", "players")
sectionHeader(PlayerPage, "Click to TP")
local playerListHolder = mk("Frame", {
    Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundColor3=T.PanelAlt, BackgroundTransparency=0.5, BorderSizePixel=0,
}, PlayerPage)
corner(playerListHolder, UDim.new(0,7)); pad(playerListHolder, 4)
mk("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, playerListHolder)

local function refreshPlayerList()
    for _, c in ipairs(playerListHolder:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local killer = isKiller(plr); local downed = isDowned(plr)
            local role = killer and "KILLER" or downed and "DOWNED" or "SURVIVOR"
            local roleColor = killer and Color3.fromRGB(255,60,60)
                          or downed and Color3.fromRGB(255,200,0)
                          or Color3.fromRGB(70,160,255)
            local b = mk("TextButton", {
                Size=UDim2.new(1,0,0,22),
                BackgroundColor3=T.Card, BackgroundTransparency=0.35,
                Text="", BorderSizePixel=0, AutoButtonColor=false,
            }, playerListHolder)
            corner(b, UDim.new(0,6))
            mk("Frame", {Size=UDim2.new(0,3,0.7,0), Position=UDim2.fromOffset(5,0.15),
                BackgroundColor3=roleColor, BorderSizePixel=0}, b)
            mk("TextLabel", {Size=UDim2.new(0.6,0,1,0), Position=UDim2.fromOffset(12,0),
                BackgroundTransparency=1, Text=plr.Name, TextColor3=T.Text,
                Font=Enum.Font.GothamMedium, TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Left}, b)
            mk("TextLabel", {Size=UDim2.new(0.4,-8,1,0), Position=UDim2.new(0.6,0,0,0),
                BackgroundTransparency=1, Text=role, TextColor3=roleColor,
                Font=Enum.Font.GothamBold, TextSize=8,
                TextXAlignment=Enum.TextXAlignment.Right}, b)
            b.MouseEnter:Connect(function() b.BackgroundTransparency=0.15 end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency=0.35 end)
            b.MouseButton1Click:Connect(function()
                local t = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local myHrp = hrp()
                if t and myHrp then
                    myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0))
                    notify("TP","→ "..plr.Name,"success")
                end
            end)
        end
    end
end
refreshPlayerList()
track(Players.PlayerAdded:Connect(function() task.wait(0.5) refreshPlayerList() end))
track(Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerList() end))
sectionHeader(PlayerPage, "Downed")
toggle(PlayerPage, "Auto TP to Downed", nil, false, function(v) State.TPOnDowned=v end)

local SelfPage = createTabButton("Me", "self")
sectionHeader(SelfPage, "Live Dashboard")
local function dataRow(parent, label)
    local row = mk("Frame", {Size=UDim2.new(1,0,0,22),
        BackgroundColor3=T.Card, BackgroundTransparency=0.35, BorderSizePixel=0}, parent)
    corner(row, UDim.new(0,6)); pad(row, 8)
    stroke(row, T.Border, 1)
    mk("TextLabel", {Size=UDim2.new(0.45,0,1,0), BackgroundTransparency=1, Text=label,
        TextColor3=T.TextDim, Font=Enum.Font.GothamMedium, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left}, row)
    local v = mk("TextLabel", {Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0.45,0,0,0),
        BackgroundTransparency=1, Text="—", TextColor3=T.Text,
        Font=Enum.Font.Code, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right}, row)
    return row, v, label
end

local function getTimeLeft()
    for _, o in ipairs(ReplicatedStorage:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then return o.Value end
    end
    for _, o in ipairs(LocalPlayer:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then return o.Value end
    end
    return nil
end

local fpsSamples = {}
local fpsConn = RunService.RenderStepped:Connect(function(dt)
    table.insert(fpsSamples, dt)
    if #fpsSamples > 30 then table.remove(fpsSamples, 1) end
end)
track(fpsConn)
local function getFPS()
    if #fpsSamples == 0 then return 0 end
    local sum = 0
    for _, d in ipairs(fpsSamples) do sum = sum + d end
    return math.floor(#fpsSamples / sum + 0.5)
end
local function getPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
    if ok and p then return math.floor(p) end
    return 0
end
local function getMemMB()
    local ok, v = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
    if ok and v then return math.floor(v) end
    return 0
end
local function getCurrentMap()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m.Name:lower():find("map") then return m.Name end
    end
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and not m:FindFirstChildOfClass("Humanoid") then return m.Name end
    end
    return "—"
end
local function getKillerName()
    local k = getKillerPlayer()
    return k and k.Name or "—"
end
local function getRole()
    if isKiller(LocalPlayer) then return "KILLER" end
    if isDowned(LocalPlayer) then return "DOWNED" end
    local h = hum(); if h and h.Health <= 0 then return "DEAD" end
    return "SURVIVOR"
end
local function fmtTime(s)
    if not s then return "—" end
    s = math.floor(tonumber(s) or 0)
    return string.format("%02d:%02d", math.floor(s/60), s%60)
end
local function fmtDur(s)
    s = math.floor(s)
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local sc = s%60
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm %ds", m, sc)
end

local R = {}
local function add(label, fn)
    local _, v, lbl = dataRow(SelfPage, label)
    table.insert(R, {val=v, fn=fn, label=lbl})
end
add("Real Time", function() return os.date("%H:%M:%S") end)
add("Date", function() return os.date("%d %b %Y") end)
add("Session", function() return fmtDur(tick() - SESSION_START) end)
add("Time Left", function() return fmtTime(getTimeLeft()) end)
add("Role", function() return getRole() end)
add("Killer", function() return getKillerName() end)
add("Killer Distance", function()
    local d = distToKiller()
    return d and (math.floor(d).."m") or "—"
end)
add("Map", function() return getCurrentMap() end)
add("Players", function() return #Players:GetPlayers().."/"..Players.MaxPlayers end)
add("FPS", function() return getFPS() end)
add("Ping", function() return getPing().." ms" end)
add("Memory", function() return getMemMB().." MB" end)

sectionHeader(SelfPage, "Account")
add("Username", function() return LocalPlayer.Name end)
add("Display Name", function() return LocalPlayer.DisplayName end)
add("User ID", function() return LocalPlayer.UserId end)
add("Account Age", function() return LocalPlayer.AccountAge.." days" end)
add("Membership", function()
    local ok, v = pcall(function() return LocalPlayer.MembershipType.Name end)
    return ok and v or "—"
end)
add("Place ID", function() return game.PlaceId end)

sectionHeader(SelfPage, "Character")
add("Health", function()
    local h = hum(); return h and (math.floor(h.Health).."/"..math.floor(h.MaxHealth)) or "—"
end)
add("Walk Speed", function()
    local h = hum(); return h and math.floor(h.WalkSpeed) or "—"
end)
add("Position", function()
    local p = hrp(); if not p then return "—" end
    return string.format("%.0f,%.0f,%.0f", p.Position.X, p.Position.Y, p.Position.Z)
end)
add("Executor", function()
    return (identifyexecutor and select(1, identifyexecutor())) or "—"
end)

button(SelfPage, "Copy Dashboard", "Full snapshot to clipboard", function()
    local buf = {"── FxA Supreme · ME ──"}
    for _, e in ipairs(R) do table.insert(buf, e.label..": "..e.val.Text) end
    if setclipboard then
        setclipboard(table.concat(buf, "\n"))
        notify("Copied","Dashboard on clipboard.","success")
    end
end)

task.spawn(function()
    while true do
        for _, e in ipairs(R) do
            if e.val and e.val.Parent then
                local ok, v = pcall(e.fn)
                if ok then e.val.Text = tostring(v) end
            end
        end
        task.wait(0.5)
    end
end)

local RemotePage = createTabButton("Remote", "remotes")
sectionHeader(RemotePage, "Bound")
local boundList = {
    {"StartRoulette", Remotes.StartRoulette},
    {"Preload", Remotes.Preload},
    {"LoadPropKiller", Remotes.LoadPropKiller},
    {"StartCutscene", Remotes.StartCutscene},
    {"StartCountdown", Remotes.StartCountdown},
    {"StopCountdown", Remotes.StopCountdown},
    {"BreakFree", Remotes.BreakFree},
    {"Knife.OnHit", Remotes.KnifeOnHit},
    {"Knife.Swing", Remotes.KnifeSwing},
}
for _, pair in ipairs(boundList) do
    local name, rem = pair[1], pair[2]
    local row = mk("Frame", {Size=UDim2.new(1,0,0,20),
        BackgroundColor3=T.Card, BackgroundTransparency=0.35, BorderSizePixel=0}, RemotePage)
    corner(row, UDim.new(0,5)); pad(row, 7)
    stroke(row, T.Border, 1)
    mk("TextLabel", {Size=UDim2.new(0.5,0,1,0), BackgroundTransparency=1, Text=name,
        TextColor3=T.Text, Font=Enum.Font.Code, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left}, row)
    local status = rem and "BOUND" or "MISSING"
    local statusColor = rem and T.Success or T.Accent
    local sbtn = mk("TextButton", {Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0.5,0,0,0),
        BackgroundTransparency=1, Text=status, TextColor3=statusColor,
        Font=Enum.Font.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Right, AutoButtonColor=false}, row)
    sbtn.MouseButton1Click:Connect(function()
        if rem and setclipboard then
            setclipboard(rem:GetFullName())
            notify("Copied", name, "success")
        end
    end)
end

sectionHeader(RemotePage, "Scan")
button(RemotePage, "Scan All Remotes", "Console + clipboard", function()
    local found = {}
    for _, root in ipairs({ReplicatedStorage, Workspace}) do
        for _, o in ipairs(root:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                table.insert(found, o:GetFullName())
            end
        end
    end
    print("── FXA REMOTE SCAN ──")
    for _, p in ipairs(found) do print(p) end
    if setclipboard then
        setclipboard(table.concat(found, "\n"))
        notify("Scan","Found "..#found.." remotes.","success")
    end
end)

button(RemotePage, "Show Current Knife", nil, function()
    local k = getMyKnife()
    if k then
        if setclipboard then setclipboard(k:GetFullName()) end
        notify("Knife", k:GetFullName(), "info")
    else notify("Knife","Not holding.","error") end
end)

-- STATUS STRIP UPDATER
task.spawn(function()
    while true do
        local k = getKillerName()
        killerVal.Text = (k == "—" and "—" or k:upper():sub(1,10))
        local d = distToKiller()
        distVal.Text = d and (math.floor(d).."m") or "—"
        local t = getTimeLeft()
        timeVal.Text = t and fmtTime(t) or "--:--"

        if d and d < 20 and not isKiller(LocalPlayer) then
            killerVal.TextColor3 = Color3.fromRGB(255,255,255)
            distVal.TextColor3 = Color3.fromRGB(255,255,255)
        else
            killerVal.TextColor3 = T.Accent
            distVal.TextColor3 = T.Gold
        end
        task.wait(0.4)
    end
end)

-- CLOSE / MIN
local minimized = false

CloseBtn.MouseButton1Click:Connect(function()
    State.AutoKill=false; State.AutoBecomeKiller=false; State.AutoEscape=false
    State.AutoSavePlayer=false; State.TPOnDowned=false; State.AutoBreakFree=false
    State.AutoDodge=false; State.AntiTrap=false; State.Fullbright=false
    for _, c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end
    CONNECTIONS = {}
    for _, d in pairs(playerData) do
        if d.hl then pcall(function() d.hl:Destroy() end) end
        if d.bb then pcall(function() d.bb:Destroy() end) end
    end
    for _, h in pairs(lockerHL) do pcall(function() h:Destroy() end) end
    for _, h in pairs(trapHL) do pcall(function() h:Destroy() end) end
    for _, h in pairs(exitHL) do pcall(function() h:Destroy() end) end
    if killerArrow then pcall(function() killerArrow.att:Destroy() end) end
    pcall(function() fpsConn:Disconnect() end)
    pcall(function() gui:Destroy() end)
end)

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Main:TweenSize(UDim2.fromOffset(W,60), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        Sidebar.Visible=false; Content.Visible=false; StatusStrip.Visible=false
    else
        Main:TweenSize(UDim2.fromOffset(W,H), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        Sidebar.Visible=true; Content.Visible=true; StatusStrip.Visible=true
    end
end)

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        CloseBtn.MouseButton1Click:Fire()
    end
end))

switchTab("main")
local firstBtn = Sidebar:GetChildren()[1]
if firstBtn and firstBtn:IsA("TextButton") then
    firstBtn.BackgroundTransparency=0.15
    for _, ch in ipairs(firstBtn:GetChildren()) do
        if ch:IsA("TextLabel") then ch.TextColor3 = T.Accent end
    end
    local fr = firstBtn:FindFirstChildOfClass("Frame")
    if fr then fr.Size = UDim2.new(0,3,0,18) end
end

task.wait(0.3)
notify("FxA Supreme","Survive The Killer V1 · RightCtrl toggle · RightShift close","success")