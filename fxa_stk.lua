-- FxA Supreme | Survive The Killer V1 | Delta Executor
-- Design v2: numbered tabs + status strip + card layout
-- Close fix: drag handler skip di area tombol

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
    if h and h.DisplayName:lower():find("killer") then return true end
    return false
end