-- FXA CANNON v4.0 | Survive The Killer | Delta Executor
-- Perfect circular logo | 420x400 | Working close | Premium My Self dashboard
-- Auto-Kill -> Knife.OnHit | Auto-Become -> StartRoulette/LoadPropKiller | Auto-Save -> fireproximityprompt

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

local SESSION_START = tick()

-- ═══════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════
local CONFIG = {
    BackgroundURL = "https://files.catbox.moe/0oc9zi.jpeg",
    LogoOverride  = "",
    Theme = {
        Bg=Color3.fromRGB(10,10,12), Panel=Color3.fromRGB(18,18,22), PanelLight=Color3.fromRGB(26,26,32),
        Border=Color3.fromRGB(42,42,52), Accent=Color3.fromRGB(230,30,40),
        Text=Color3.fromRGB(235,235,240), TextDim=Color3.fromRGB(130,130,145),
        Success=Color3.fromRGB(70,220,120), Info=Color3.fromRGB(80,160,255),
    },
    LockerNames={"locker","closet","cabinet","wardrobe","hide"},
    TrapNames={"trap","beartrap","spike","mousetrap"},
    ExitNames={"exit","escape","escapedoor","exitdoor"},
    DownedTags={"helpme","help me","downed","wounded","revive"},
    TimerNames={"timer","roundtime","timeleft","countdown","roundtimer"},
    KillReach=6, KillCooldown=0.3, ExitFrontOffset=5,
    WindowW=420, WindowH=400,
}

local function loadAsset(url, fn)
    if not (writefile and isfile and getcustomasset) then return nil end
    local ok = pcall(function() if not isfile(fn) then writefile(fn, game:HttpGet(url)) end end)
    if not ok then return nil end
    local ok2, a = pcall(getcustomasset, fn)
    return ok2 and a or nil
end
local BG_ASSET = loadAsset(CONFIG.BackgroundURL, "fxa_bg.png")
local LOGO_ASSET = CONFIG.LogoOverride ~= "" and CONFIG.LogoOverride or BG_ASSET

-- ═══════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════
local State = {
    AutoBecomeKiller=false, AutoKill=false, AutoEscape=false,
    AutoBreakFree=true, AutoSavePlayer=false, TPOnDowned=false,
    Speed=16, Jump=50, Noclip=false,
    Godmode=false, InfiniteStamina=false, AntiAFK=false,
    ESP_Survivor=false, ESP_Killer=false, ESP_Downed=false,
    ESP_Lockers=false, ESP_Traps=false, ESP_Exits=false, ESP_Distance=true,
}

local CONNECTIONS = {}
local LOOPS = {}
local function track(c) table.insert(CONNECTIONS, c); return c end
local function trackLoop(t) table.insert(LOOPS, t); return t end

-- ═══════════════════════════════════════════════════════════
-- UTIL
-- ═══════════════════════════════════════════════════════════
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
    if h and h.DisplayName:lower():find("killer") then return true end
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

local function isGrabbed(plr)
    plr = plr or LocalPlayer
    local c = plr.Character; if not c then return false end
    local h = c:FindFirstChild("HumanoidRootPart")
    if h then
        for _,w in ipairs(h:GetChildren()) do
            if w:IsA("Weld") or w:IsA("WeldConstraint") then
                if w.Part1 and w.Part1:IsDescendantOf(Workspace) then
                    local owner = Players:GetPlayerFromCharacter(w.Part1:FindFirstAncestorOfClass("Model"))
                    if owner and owner ~= plr then return true end
                end
            end
        end
    end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum and hum.PlatformStand then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════
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

local function getMyKnife() local c=char(); if not c then return nil end return c:FindFirstChild("Knife") end
local function getKnifeHitRemote()
    local k = getMyKnife()
    if k then local h = k:FindFirstChild("OnHit"); if h then return h end end
    return Remotes.KnifeOnHit
end
local function getKnifeSwingRemote()
    local k = getMyKnife()
    if k then local s = k:FindFirstChild("SwingKnife"); if s then return s end end
    return Remotes.KnifeSwing
end

-- ═══════════════════════════════════════════════════════════
-- AUTO-BECOME-KILLER
-- ═══════════════════════════════════════════════════════════
local lastRoundSignal = 0
track(Workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") and c.Name:lower():find("map") then lastRoundSignal = os.clock() end
end))
track(LocalPlayer.CharacterAdded:Connect(function() lastRoundSignal = os.clock() end))

trackLoop(task.spawn(function()
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
        else
            task.wait(0.5)
        end
    end
end))

-- ═══════════════════════════════════════════════════════════
-- AUTO-KILL
-- ═══════════════════════════════════════════════════════════
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

trackLoop(task.spawn(function()
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
end))

-- ═══════════════════════════════════════════════════════════
-- AUTO-SAVE
-- ═══════════════════════════════════════════════════════════
local function findProximityPrompt(c)
    if not c then return nil end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function tryRevive(target)
    local tchar = target.Parent
    if not tchar then return false end
    local pp = findProximityPrompt(tchar)
    if pp and fireproximityprompt then pcall(fireproximityprompt, pp); return true end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local n = d.Name:lower()
            if n:find("revive") or n:find("help") or n:find("save") then
                pcall(function() d:FireServer(tchar) end)
                pcall(function() d:FireServer(tchar.Humanoid) end)
            end
        end
    end
    return false
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

trackLoop(task.spawn(function()
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
end))

-- ═══════════════════════════════════════════════════════════
-- AUTO BREAK FREE
-- ═══════════════════════════════════════════════════════════
trackLoop(task.spawn(function()
    while true do
        if State.AutoBreakFree and isGrabbed(LocalPlayer) then
            pcall(function()
                if Remotes.BreakFree then
                    Remotes.BreakFree:FireServer()
                    Remotes.BreakFree:FireServer(LocalPlayer)
                end
            end)
        end
        task.wait(0.2)
    end
end))

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT: movement + godmode
-- ═══════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════
-- AUTO-ESCAPE
-- ═══════════════════════════════════════════════════════════
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

trackLoop(task.spawn(function()
    while true do
        if State.AutoEscape and not isKiller(LocalPlayer) then
            local d = findExitDoor()
            local myHrp = hrp()
            if d and myHrp and isEscapeOpen(d) then
                local look = d.CFrame.LookVector
                local f = d.Position - look * CONFIG.ExitFrontOffset
                myHrp.CFrame = CFrame.new(f, f + look)
            end
        end
        task.wait(0.25)
    end
end))

-- ═══════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════
local playerData = {}
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
trackLoop(task.spawn(function()
    while true do
        if State.ESP_Lockers then lockerESP() end
        if State.ESP_Traps then trapESP() end
        if State.ESP_Exits then exitESP() end
        task.wait(1)
    end
end))

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
    gui.Name="FXA_CANNON"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=LocalPlayer:WaitForChild("PlayerGui")
end

local W, H = CONFIG.WindowW, CONFIG.WindowH
local Main = mk("Frame", {
    Name="Main", Size=UDim2.fromOffset(W,H),
    Position=UDim2.new(0.5,-W/2,0.5,-H/2),
    BackgroundColor3=T.Bg, BorderSizePixel=0, ClipsDescendants=true, Active=true,
}, gui)
corner(Main, UDim.new(0,14)); stroke(Main, T.Border, 1)

if BG_ASSET then
    mk("ImageLabel", {
        Name="BG", Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1, Image=BG_ASSET,
        ScaleType=Enum.ScaleType.Crop,
        ImageTransparency=0.25, ZIndex=1,
    }, Main)
end
local BGDim = mk("Frame", {
    Size=UDim2.fromScale(1,1),
    BackgroundColor3=Color3.fromRGB(6,6,8),
    BackgroundTransparency=BG_ASSET and 0.55 or 0.05,
    BorderSizePixel=0, ZIndex=2,
}, Main)
mk("UIGradient", {
    Rotation=90,
    Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,0.1),
        NumberSequenceKeypoint.new(1,0.75)}),
}, BGDim)

-- Top bar
local TopBar = mk("Frame", {Size=UDim2.new(1,0,0,50), BackgroundTransparency=1, ZIndex=10}, Main)

-- ═══════════════════════════════════════════════════════════
-- PERFECT CIRCULAR LOGO — pure ImageLabel + UICorner(1,0) + Crop
-- No background frame, no rectangle stroke. The UICorner clips
-- the square image into a perfect circle.
-- ═══════════════════════════════════════════════════════════
local LOGO_SIZE = 36
local Logo = mk("ImageLabel", {
    Name="Logo",
    Size=UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
    Position=UDim2.fromOffset(12, 7),
    BackgroundTransparency=1,
    Image=LOGO_ASSET or "rbxassetid://0",
    ImageColor3=Color3.new(1,1,1),
    ScaleType=Enum.ScaleType.Crop,
    BorderSizePixel=0,
    ZIndex=11,
    ClipsDescendants=true,
}, TopBar)
corner(Logo, UDim.new(1, 0))                    -- perfect circle clip
-- thin red ring follows the circle shape (UIStroke respects UICorner)
mk("UIStroke", {Color=T.Accent, Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, Logo)

mk("TextLabel", {
    Size=UDim2.fromOffset(220,18), Position=UDim2.fromOffset(56,7),
    BackgroundTransparency=1, Text="FXA CANNON",
    TextColor3=T.Text, Font=Enum.Font.GothamBold, TextSize=14,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=11,
}, TopBar)
mk("TextLabel", {
    Size=UDim2.fromOffset(220,12), Position=UDim2.fromOffset(56,24),
    BackgroundTransparency=1, Text="SURVIVE THE KILLER · v4.0",
    TextColor3=T.Accent, Font=Enum.Font.GothamMedium, TextSize=9,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=11,
}, TopBar)

-- Close button (uses Activated — most reliable across executors)
local CloseBtn = mk("TextButton", {
    Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-32,0,12),
    BackgroundColor3=Color3.fromRGB(60,20,24),
    Text="×", TextColor3=T.Text,
    Font=Enum.Font.GothamBold, TextSize=15,
    BorderSizePixel=0, ZIndex=100, AutoButtonColor=false,
    Active=true,
}, TopBar)
corner(CloseBtn, UDim.new(0,7))
stroke(CloseBtn, T.Accent, 1)

-- Minimize
local MinBtn = mk("TextButton", {
    Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-60,0,12),
    BackgroundColor3=T.PanelLight,
    Text="—", TextColor3=T.Text,
    Font=Enum.Font.GothamBold, TextSize=13,
    BorderSizePixel=0, ZIndex=100, AutoButtonColor=false,
    Active=true,
}, TopBar)
corner(MinBtn, UDim.new(0,7))

-- Sidebar
local Sidebar = mk("Frame", {
    Size=UDim2.new(0,110,1,-60), Position=UDim2.fromOffset(12,54),
    BackgroundColor3=T.Panel, BackgroundTransparency=0.2,
    BorderSizePixel=0, ZIndex=10,
}, Main)
corner(Sidebar, UDim.new(0,10)); pad(Sidebar, 6)
mk("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, Sidebar)

-- Content
local Content = mk("ScrollingFrame", {
    Size=UDim2.new(1,-110-12-8,1,-60), Position=UDim2.fromOffset(12+110+8,54),
    BackgroundColor3=T.Panel, BackgroundTransparency=0.2,
    BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.Accent,
    CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
    ZIndex=10,
}, Main)
corner(Content, UDim.new(0,10)); pad(Content, 7)
mk("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, Content)

-- Drag
do
    local dragging, dragStart, startPos
    track(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
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

-- Tabs
local tabs, currentTab = {}, nil
local function switchTab(n) for _,f in pairs(tabs) do f.Visible=false end if tabs[n] then tabs[n].Visible=true; currentTab=n end end

local function createTabButton(title, key)
    local btn = mk("TextButton", {
        Size=UDim2.new(1,0,0,28),
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.3,
        Text="  "..title, TextColor3=T.Text,
        Font=Enum.Font.GothamMedium, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        BorderSizePixel=0, AutoButtonColor=false,
    }, Sidebar)
    corner(btn, UDim.new(0,7))
    local accent = mk("Frame", {
        Size=UDim2.new(0,3,0,0), Position=UDim2.new(0,0,0.5,0),
        BackgroundColor3=T.Accent, BorderSizePixel=0,
    }, btn)
    corner(accent, UDim.new(1,0))
    local page = mk("Frame", {Name=key, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false}, Content)
    mk("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, page)
    tabs[key]=page
    btn.MouseEnter:Connect(function() btn.BackgroundTransparency=0.05 end)
    btn.MouseLeave:Connect(function() if currentTab~=key then btn.BackgroundTransparency=0.3 end end)
    btn.MouseButton1Click:Connect(function()
        for _,b in ipairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundTransparency=0.3; b.TextColor3=T.Text
                local a = b:FindFirstChildOfClass("Frame")
                if a then TweenService:Create(a, TweenInfo.new(0.15), {Size=UDim2.new(0,3,0,0)}):Play() end
            end
        end
        btn.BackgroundTransparency=0.05; btn.TextColor3=T.Accent
        TweenService:Create(accent, TweenInfo.new(0.15), {Size=UDim2.new(0,3,0,16)}):Play()
        switchTab(key)
    end)
    return page
end

local function sectionHeader(parent, title)
    return mk("TextLabel", {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Text=title:upper(),
        TextColor3=T.Accent, Font=Enum.Font.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, parent)
end

local function toggle(parent, title, desc, default, cb)
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0, desc and 38 or 30),
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.35, BorderSizePixel=0,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    mk("TextLabel", {
        Size=UDim2.new(1,-46,0, desc and 14 or 30),
        BackgroundTransparency=1, Text=title, TextColor3=T.Text,
        Font=Enum.Font.GothamMedium, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment= desc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    }, row)
    if desc then
        mk("TextLabel", {
            Size=UDim2.new(1,-46,0,10), Position=UDim2.fromOffset(0,14),
            BackgroundTransparency=1, Text=desc, TextColor3=T.TextDim,
            Font=Enum.Font.Gotham, TextSize=8,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, row)
    end
    local st = default or false
    local sw = mk("TextButton", {
        Size=UDim2.fromOffset(32,16), Position=UDim2.new(1,-32,0.5,-8),
        BackgroundColor3=st and T.Accent or T.Border, Text="",
        BorderSizePixel=0, AutoButtonColor=false,
    }, row)
    corner(sw, UDim.new(0.5,0))
    local knob = mk("Frame", {
        Size=UDim2.fromOffset(12,12),
        Position=st and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
    }, sw)
    corner(knob, UDim.new(1,0))
    row.MouseEnter:Connect(function() row.BackgroundTransparency=0.15 end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency=0.35 end)
    sw.MouseButton1Click:Connect(function()
        st = not st
        if st then sw.BackgroundColor3=T.Accent
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(1,-14,0.5,-6)}):Play()
        else sw.BackgroundColor3=T.Border
            TweenService:Create(knob, TweenInfo.new(0.12), {Position=UDim2.new(0,2,0.5,-6)}):Play() end
        if cb then pcall(cb, st) end
    end)
end

local function slider(parent, title, min, max, default, cb)
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0,40),
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.35, BorderSizePixel=0,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    mk("TextLabel", {
        Size=UDim2.new(1,-55,0,12), BackgroundTransparency=1, Text=title,
        TextColor3=T.Text, Font=Enum.Font.GothamMedium, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, row)
    local vl = mk("TextLabel", {
        Size=UDim2.fromOffset(55,12), Position=UDim2.new(1,-55,0,0),
        BackgroundTransparency=1, Text=tostring(default),
        TextColor3=T.Accent, Font=Enum.Font.GothamBold, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right,
    }, row)
    local track = mk("Frame", {
        Size=UDim2.new(1,0,0,4), Position=UDim2.fromOffset(0,23),
        BackgroundColor3=T.Border, BorderSizePixel=0,
    }, row)
    corner(track, UDim.new(1,0))
    local fill = mk("Frame", {
        Size=UDim2.new((default-min)/(max-min),0,1,0),
        BackgroundColor3=T.Accent, BorderSizePixel=0,
    }, track)
    corner(fill, UDim.new(1,0))
    local knob = mk("Frame", {
        Size=UDim2.fromOffset(10,10),
        Position=UDim2.new((default-min)/(max-min),-5,0.5,-5),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=2,
    }, track)
    corner(knob, UDim.new(1,0))
    local dragging = false
    local function upd(input)
        local r = math.clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*r + 0.5)
        fill.Size = UDim2.new(r,0,1,0)
        knob.Position = UDim2.new(r,-5,0.5,-5)
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
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.35,
        Text="", BorderSizePixel=0, AutoButtonColor=false,
    }, parent)
    corner(row, UDim.new(0,8)); pad(row, 9)
    mk("TextLabel", {
        Size=UDim2.new(1,0,0, desc and 14 or 28),
        BackgroundTransparency=1, Text=title, TextColor3=T.Text,
        Font=Enum.Font.GothamMedium, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment= desc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    }, row)
    if desc then
        mk("TextLabel", {
            Size=UDim2.new(1,0,0,10), Position=UDim2.fromOffset(0,14),
            BackgroundTransparency=1, Text=desc, TextColor3=T.TextDim,
            Font=Enum.Font.Gotham, TextSize=8,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, row)
    end
    row.MouseEnter:Connect(function() row.BackgroundTransparency=0.15 end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency=0.35 end)
    row.MouseButton1Click:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {BackgroundTransparency=0.5}):Play()
        task.delay(0.1, function() TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency=0.15}):Play() end)
        if cb then pcall(cb) end
    end)
end

-- Notifications
local notifHolder = mk("Frame", {
    Size=UDim2.fromOffset(220,260), Position=UDim2.new(1,-236,1,-280),
    BackgroundTransparency=1, ZIndex=100,
}, gui)
mk("UIListLayout", {
    Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder,
    VerticalAlignment=Enum.VerticalAlignment.Bottom,
    HorizontalAlignment=Enum.HorizontalAlignment.Right,
}, notifHolder)

local function notify(title, text, kind)
    local color = kind=="error" and T.Accent or kind=="success" and T.Success or T.Info
    local h = mk("Frame", {
        Size=UDim2.fromOffset(210,44),
        BackgroundColor3=T.Panel, BackgroundTransparency=0.05,
        BorderSizePixel=0, ZIndex=101,
    }, notifHolder)
    corner(h, UDim.new(0,9)); stroke(h, color, 1.5)
    mk("Frame", {
        Size=UDim2.new(0,3,1,-14), Position=UDim2.fromOffset(6,7),
        BackgroundColor3=color, BorderSizePixel=0,
    }, h)
    mk("TextLabel", {
        Size=UDim2.new(1,-18,0,13), Position=UDim2.fromOffset(14,6),
        BackgroundTransparency=1, Text=title, TextColor3=color,
        Font=Enum.Font.GothamBold, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, h)
    mk("TextLabel", {
        Size=UDim2.new(1,-18,0,20), Position=UDim2.fromOffset(14,20),
        BackgroundTransparency=1, Text=text, TextColor3=T.TextDim,
        Font=Enum.Font.Gotham, TextSize=8,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
    }, h)
    h.Position = UDim2.new(1,300,0,0)
    TweenService:Create(h, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Position=UDim2.new(0,0,0,0)}):Play()
    task.delay(3, function()
        TweenService:Create(h, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Position=UDim2.new(1,300,0,0)}):Play()
        task.wait(0.3); h:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════════
-- BUILD TABS
-- ═══════════════════════════════════════════════════════════

-- ─── MAIN ────────────────────────────────────────────────
local MainPage = createTabButton("Main", "main")
sectionHeader(MainPage, "Killer")
toggle(MainPage, "Auto Become Killer", "Fires StartRoulette + LoadPropKiller", false, function(v)
    State.AutoBecomeKiller = v
    if v then notify("Auto Killer","Burst-firing role remotes.","info") end
end)
toggle(MainPage, "Auto Kill", "Fires live Knife.OnHit at nearest", false, function(v)
    State.AutoKill = v
    if v then notify("Auto Kill","Active when you're killer.","info") end
end)
button(MainPage, "Force Kill Nearest (once)", nil, function()
    local t = nearestSurvivor()
    if t then fireKillOn(t); notify("Kill","Fired on nearest.","success")
    else notify("Kill","No survivor in range.","error") end
end)

sectionHeader(MainPage, "Escape")
toggle(MainPage, "Auto Escape", "TP to front when door opens", false, function(v)
    State.AutoEscape = v
    if v then notify("Auto Escape","Watching door state.","info") end
end)
button(MainPage, "TP to Exit Front (once)", nil, function()
    local d = findExitDoor(); local myHrp = hrp()
    if d and myHrp then
        local look = d.CFrame.LookVector
        local f = d.Position - look * CONFIG.ExitFrontOffset
        myHrp.CFrame = CFrame.new(f, f + look)
        notify("Escape","TP'd to front of door.","success")
    else notify("Escape","No exit found.","error") end
end)

sectionHeader(MainPage, "Survival")
toggle(MainPage, "Auto Break Free", "Fires BreakFree when grabbed", true, function(v)
    State.AutoBreakFree = v
    if v then notify("Anti-Grab","Enabled.","success") end
end)
toggle(MainPage, "Auto Save Player", "TP + fire revive on downed", false, function(v)
    State.AutoSavePlayer = v
    if v then notify("Auto Save","Active.","info") end
end)
button(MainPage, "Save Nearest Downed (once)", nil, function()
    local t = nearestDowned(); local myHrp = hrp()
    if t and myHrp then
        myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0))
        task.wait(0.1); tryRevive(t)
        notify("Save","Attempted revive.","success")
    else notify("Save","No downed player.","error") end
end)

-- ─── ESP ─────────────────────────────────────────────────
local ESPPage = createTabButton("ESP", "esp")
sectionHeader(ESPPage, "Player ESP")
toggle(ESPPage, "Survivor ESP (Blue)", nil, false, function(v) State.ESP_Survivor=v end)
toggle(ESPPage, "Killer ESP (Red)", nil, false, function(v) State.ESP_Killer=v end)
toggle(ESPPage, "Downed ESP (Gold)", nil, false, function(v) State.ESP_Downed=v end)
toggle(ESPPage, "Distance + Role Tag", nil, true, function(v) State.ESP_Distance=v end)
sectionHeader(ESPPage, "Object ESP")
toggle(ESPPage, "Locker ESP", "Red = occupied", false, function(v) State.ESP_Lockers=v end)
toggle(ESPPage, "Trap ESP", nil, false, function(v) State.ESP_Traps=v end)
toggle(ESPPage, "Exit ESP", nil, false, function(v) State.ESP_Exits=v end)

-- ─── MOVEMENT ────────────────────────────────────────────
local MovePage = createTabButton("Move", "move")
sectionHeader(MovePage, "Character")
slider(MovePage, "Walk Speed", 16, 250, 16, function(v) State.Speed=v end)
slider(MovePage, "Jump Power", 50, 400, 50, function(v) State.Jump=v end)
toggle(MovePage, "Noclip", nil, false, function(v) State.Noclip=v end)
toggle(MovePage, "Godmode", "Health lock + strip TouchTransmitter", false, function(v)
    State.Godmode=v
    if v then notify("Godmode","Active.","success") end
end)
toggle(MovePage, "Infinite Stamina", nil, false, function(v) State.InfiniteStamina=v end)
toggle(MovePage, "Anti-AFK", nil, false, function(v)
    State.AntiAFK=v
    if v then
        track(LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
        end))
    end
end)

-- ─── PLAYERS ─────────────────────────────────────────────
local PlayerPage = createTabButton("Players", "players")
sectionHeader(PlayerPage, "Player List (click to TP)")

local playerListHolder = mk("Frame", {
    Size=UDim2.new(1,0,0,170),
    BackgroundColor3=T.PanelLight, BackgroundTransparency=0.5,
    BorderSizePixel=0,
}, PlayerPage)
corner(playerListHolder, UDim.new(0,8)); pad(playerListHolder, 5)
mk("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, playerListHolder)

local function refreshPlayerList()
    for _, c in ipairs(playerListHolder:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local killer = isKiller(plr)
            local downed = isDowned(plr)
            local role = killer and "KILLER" or downed and "DOWNED" or "SURVIVOR"
            local roleColor = killer and Color3.fromRGB(255,60,60)
                          or downed and Color3.fromRGB(255,200,0)
                          or Color3.fromRGB(70,160,255)
            local b = mk("TextButton", {
                Size=UDim2.new(1,0,0,22),
                BackgroundColor3=T.Panel, BackgroundTransparency=0.3,
                Text="", BorderSizePixel=0, AutoButtonColor=false,
            }, playerListHolder)
            corner(b, UDim.new(0,6))
            mk("TextLabel", {
                Size=UDim2.new(0.6,0,1,0), Position=UDim2.fromOffset(7,0),
                BackgroundTransparency=1, Text=plr.Name,
                TextColor3=T.Text, Font=Enum.Font.GothamMedium,
                TextSize=10, TextXAlignment=Enum.TextXAlignment.Left,
            }, b)
            mk("TextLabel", {
                Size=UDim2.new(0.4,-7,1,0), Position=UDim2.new(0.6,0,0,0),
                BackgroundTransparency=1, Text=role,
                TextColor3=roleColor, Font=Enum.Font.GothamBold,
                TextSize=9, TextXAlignment=Enum.TextXAlignment.Right,
            }, b)
            b.MouseEnter:Connect(function() b.BackgroundTransparency=0.1 end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency=0.3 end)
            b.MouseButton1Click:Connect(function()
                local t = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local myHrp = hrp()
                if t and myHrp then
                    myHrp.CFrame = CFrame.new(t.Position + Vector3.new(0,3,0))
                    notify("Teleport","TP'd to "..plr.Name,"success")
                end
            end)
        end
    end
end
refreshPlayerList()
track(Players.PlayerAdded:Connect(function() task.wait(0.5) refreshPlayerList() end))
track(Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerList() end))

sectionHeader(PlayerPage, "Downed")
toggle(PlayerPage, "Auto TP to Downed", "Continuous TP to nearest", false, function(v) State.TPOnDowned = v end)

-- ═══════════════════════════════════════════════════════════
-- ─── MY SELF (premium dashboard) ─────────────────────────
-- ═══════════════════════════════════════════════════════════
local SelfPage = createTabButton("My Self", "self")
sectionHeader(SelfPage, "Live Dashboard")

local function dataRow(parent, label, initVal)
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0,22),
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.4,
        BorderSizePixel=0,
    }, parent)
    corner(row, UDim.new(0,6)); pad(row, 8)
    mk("TextLabel", {
        Size=UDim2.new(0.45,0,1,0),
        BackgroundTransparency=1, Text=label,
        TextColor3=T.TextDim, Font=Enum.Font.GothamMedium,
        TextSize=9, TextXAlignment=Enum.TextXAlignment.Left,
    }, row)
    local v = mk("TextLabel", {
        Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0.45,0,0,0),
        BackgroundTransparency=1, Text=tostring(initVal),
        TextColor3=T.Text, Font=Enum.Font.Code,
        TextSize=9, TextXAlignment=Enum.TextXAlignment.Right,
    }, row)
    return row, v
end

-- Time left resolver
local function getTimeLeft()
    for _, o in ipairs(ReplicatedStorage:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then
            return o.Value
        end
    end
    local plr = LocalPlayer
    for _, o in ipairs(plr:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then
            return o.Value
        end
    end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("NumberValue") and nameMatches(o.Name, CONFIG.TimerNames) then
            return o.Value
        end
    end
    return nil
end

-- FPS sample
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
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
    if ok and ping then return math.floor(ping) end
    local ok2, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok2 and v then return math.floor(v) end
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
        if m:IsA("Model") then return m.Name end
    end
    return "—"
end

local function getKillerName()
    for _, plr in ipairs(Players:GetPlayers()) do
        if isKiller(plr) then return plr.Name end
    end
    return "—"
end

local function getRole()
    if isKiller(LocalPlayer) then return "KILLER" end
    if isDowned(LocalPlayer) then return "DOWNED" end
    if hum() and hum().Health <= 0 then return "DEAD" end
    return "SURVIVOR"
end

local function fmtTime(sec)
    if not sec or sec == "—" then return "—" end
    sec = math.floor(tonumber(sec) or 0)
    return string.format("%02d:%02d", math.floor(sec/60), sec%60)
end

local function fmtDuration(sec)
    sec = math.floor(sec)
    local h = math.floor(sec/3600)
    local m = math.floor((sec%3600)/60)
    local s = sec%60
    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    return string.format("%dm %ds", m, s)
end

-- Build rows
local R = {}
local function add(label, fn)
    local row, val = dataRow(SelfPage, label, fn())
    table.insert(R, {val = val, fn = fn})
end

add("Real Time", function()
    return os.date("%H:%M:%S")
end)
add("Date", function()
    return os.date("%d %b %Y")
end)
add("Session", function()
    return fmtDuration(tick() - SESSION_START)
end)
add("Time Left", function()
    local t = getTimeLeft()
    return t and fmtTime(t) or "—"
end)
add("Role (this round)", function()
    return getRole()
end)
add("Killer", function()
    return getKillerName()
end)
add("Map", function()
    return getCurrentMap()
end)
add("Players", function()
    return #Players:GetPlayers() .. "/" .. Players.MaxPlayers
end)
add("FPS", function()
    return getFPS()
end)
add("Ping", function()
    return getPing() .. " ms"
end)
add("Memory", function()
    return getMemMB() .. " MB"
end)

sectionHeader(SelfPage, "Account")
add("Username", function() return LocalPlayer.Name end)
add("Display Name", function() return LocalPlayer.DisplayName end)
add("User ID", function() return LocalPlayer.UserId end)
add("Account Age", function() return LocalPlayer.AccountAge .. " days" end)
add("Membership", function()
    local ok, v = pcall(function() return LocalPlayer.MembershipType.Name end)
    return ok and v or "—"
end)
add("Place ID", function() return game.PlaceId end)
add("Job ID", function()
    return tostring(game.JobId):sub(1, 16) .. "…"
end)

sectionHeader(SelfPage, "Character")
add("Health", function()
    local h = hum(); return h and (math.floor(h.Health).." / "..math.floor(h.MaxHealth)) or "—"
end)
add("Walk Speed", function()
    local h = hum(); return h and math.floor(h.WalkSpeed) or "—"
end)
add("Position", function()
    local p = hrp(); if not p then return "—" end
    return string.format("%.0f, %.0f, %.0f", p.Position.X, p.Position.Y, p.Position.Z)
end)
add("Executor", function()
    return (identifyexecutor and select(1, identifyexecutor())) or "—"
end)

button(SelfPage, "Copy Full Dashboard to Clipboard", nil, function()
    local buf = {"── FXA CANNON · MY SELF ──"}
    for _, entry in ipairs(R) do
        local label = entry.val.Parent:GetChildren()[1].Text
        table.insert(buf, label .. ": " .. entry.val.Text)
    end
    if setclipboard then
        setclipboard(table.concat(buf, "\n"))
        notify("Copied","Dashboard on clipboard.","success")
    end
end)

-- Live refresh
trackLoop(task.spawn(function()
    while true do
        for _, entry in ipairs(R) do
            if entry.val and entry.val.Parent then
                local ok, v = pcall(entry.fn)
                if ok then entry.val.Text = tostring(v) end
            end
        end
        task.wait(0.5)
    end
end))

-- ─── REMOTES ─────────────────────────────────────────────
local RemotePage = createTabButton("Remotes", "remotes")
sectionHeader(RemotePage, "Bound Remotes")
local boundList = {
    {"StartRoulette", Remotes.StartRoulette},
    {"Preload", Remotes.Preload},
    {"LoadPropKiller", Remotes.LoadPropKiller},
    {"StartCutscene", Remotes.StartCutscene},
    {"StartCountdown", Remotes.StartCountdown},
    {"StopCountdown", Remotes.StopCountdown},
    {"BreakFree", Remotes.BreakFree},
    {"Knife.OnHit (tpl)", Remotes.KnifeOnHit},
    {"Knife.SwingKnife (tpl)", Remotes.KnifeSwing},
}
for _, pair in ipairs(boundList) do
    local name, rem = pair[1], pair[2]
    local row = mk("Frame", {
        Size=UDim2.new(1,0,0,20),
        BackgroundColor3=T.PanelLight, BackgroundTransparency=0.4,
        BorderSizePixel=0,
    }, RemotePage)
    corner(row, UDim.new(0,6)); pad(row, 8)
    mk("TextLabel", {
        Size=UDim2.new(0.5,0,1,0), BackgroundTransparency=1, Text=name,
        TextColor3=T.Text, Font=Enum.Font.Code, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, row)
    local status = rem and "BOUND" or "MISSING"
    local statusColor = rem and T.Success or T.Accent
    local sbtn = mk("TextButton", {
        Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0.5,0,0,0),
        BackgroundTransparency=1, Text=status,
        TextColor3=statusColor, Font=Enum.Font.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Right, AutoButtonColor=false,
    }, row)
    sbtn.MouseButton1Click:Connect(function()
        if rem and setclipboard then
            setclipboard(rem:GetFullName())
            notify("Copied", name, "success")
        end
    end)
end

button(RemotePage, "Show Current Knife Instance", nil, function()
    local k = getMyKnife()
    if k then
        notify("Knife","Path copied: "..k.Name,"info")
        if setclipboard then setclipboard(k:GetFullName()) end
    else notify("Knife","Not holding one.","error") end
end)

-- ═══════════════════════════════════════════════════════════
-- CLOSE / MINIMIZE / KEYBIND
-- ═══════════════════════════════════════════════════════════
local function shutdown()
    for _, c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end
    CONNECTIONS = {}
    for _, d in pairs(playerData) do
        if d.hl then d.hl:Destroy() end
        if d.bb then d.bb:Destroy() end
    end
    for _, h in pairs(lockerHL) do h:Destroy() end
    for _, h in pairs(trapHL) do h:Destroy() end
    for _, h in pairs(exitHL) do h:Destroy() end
    pcall(function() fpsConn:Disconnect() end)
    pcall(function() gui:Destroy() end)
    State.AutoKill = false
    State.AutoBecomeKiller = false
    State.AutoEscape = false
    State.AutoSavePlayer = false
    State.TPOnDowned = false
    State.AutoBreakFree = false
end

-- Close: bind BOTH Activated and MouseButton1Click, whichever fires
local closeFired = false
local function doClose()
    if closeFired then return end
    closeFired = true
    shutdown()
end
CloseBtn.Activated:Connect(doClose)
CloseBtn.MouseButton1Click:Connect(doClose)

local minimized = false
local function doMin()
    minimized = not minimized
    if minimized then
        Main:TweenSize(UDim2.fromOffset(W,50), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        Sidebar.Visible=false; Content.Visible=false
    else
        Main:TweenSize(UDim2.fromOffset(W,H), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        Sidebar.Visible=true; Content.Visible=true
    end
end
MinBtn.Activated:Connect(doMin)
MinBtn.MouseButton1Click:Connect(doMin)

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end))

switchTab("main")
for _, b in ipairs(Sidebar:GetChildren()) do
    if b:IsA("TextButton") and b.Text:find("Main") then
        b.BackgroundTransparency=0.05; b.TextColor3=T.Accent
        local a = b:FindFirstChildOfClass("Frame")
        if a then a.Size = UDim2.new(0,3,0,16) end
    end
end

task.wait(0.4)
notify("FXA CANNON","v4.0 loaded. RightCtrl to toggle.","success")
if not BG_ASSET then
    notify("Assets","No custom asset — fallback theme.","error")
end
