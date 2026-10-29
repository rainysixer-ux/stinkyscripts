--[[
    Stamina Manipulator — Route 06
    UI library: ObsidianUI (https://github.com/deividcomsono/Obsidian)

    Features:
      • Infinite Stamina   — the stamina bar still drains as a visual indicator,
                             but hitting 0 will never lock/stop you from running.
      • Regen / Drain Rate — change how fast stamina comes back or drains.
      • Stamina Changer    — change the max stamina (up to 1,000).
      • Punishment Duration— shorten/remove the run-lock penalty after hitting 0.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Gui = PlayerGui:WaitForChild("gui")

-- Attribute carrier: PlayerGui.gui.stats  (holds isRunning, stamina, runActionLocked, canMove, canRun, ...)
local Stats = Gui:WaitForChild("stats")

-- survivorStats holds maxStamina / staminaGain / staminaLoss NumberValues
local SurvivorStats = Gui:FindFirstChild("survivorStats")
if not SurvivorStats then
    for _, d in ipairs(Gui:GetDescendants()) do
        if d.Name == "survivorStats" and d:FindFirstChild("maxStamina") and d:FindFirstChild("staminaGain") then
            SurvivorStats = d
            break
        end
    end
end
if not SurvivorStats then
    warn("Stamina Manipulator: survivorStats not found")
    return
end

local MaxStaminaVal = SurvivorStats:WaitForChild("maxStamina")
local StaminaGainVal = SurvivorStats:WaitForChild("staminaGain")   -- regen tick interval (lower = faster)
local StaminaLossVal = SurvivorStats:WaitForChild("staminaLoss")   -- drain tick interval (lower = slower)

-- Config state
local Cfg = {
    InfiniteStamina = false,
    RegenRate = 1,
    DrainRate = 1,
    MaxStamina = tonumber(MaxStaminaVal.Value) or 20,
    PunishDuration = 2,
}

-- Apply starting values to the game
MaxStaminaVal.Value = Cfg.MaxStamina
StaminaGainVal.Value = Cfg.RegenRate
StaminaLossVal.Value = Cfg.DrainRate

-- ObsidianUI
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "Stamina Manipulator",
    Footer = "Route 06",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab({ Name = "Main", Icon = "zap" }),
    UI = Window:AddTab({ Name = "UI Settings", Icon = "settings" }),
}

local gMain = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Stamina", Description = "Stamina manipulation" })

gMain:AddToggle("InfiniteStamina", {
    Text = "Infinite Stamina",
    Default = false,
    Tooltip = "Stamina bar still drains as an indicator, but hitting 0 will never stop you from running.",
    Callback = function(v)
        Cfg.InfiniteStamina = v
    end,
}):AddKeyPicker("InfiniteStaminaBind", {
    Default = "None",
    Mode = "Toggle",
    NoUI = true,
    Text = "Infinite Stamina",
})

gMain:AddSlider("MaxStamina", {
    Text = "Max Stamina (Stamina Changer)",
    Default = Cfg.MaxStamina,
    Min = 1,
    Max = 1000,
    Rounding = 0,
    Tooltip = "Set the maximum stamina amount (up to 1,000).",
    Callback = function(v)
        Cfg.MaxStamina = v
        MaxStaminaVal.Value = v
    end,
})

gMain:AddSlider("RegenRate", {
    Text = "Regen Rate",
    Default = Cfg.RegenRate,
    Min = 0.05,
    Max = 5,
    Rounding = 2,
    Tooltip = "Seconds per stamina tick while regenerating. Lower = faster regen.",
    Callback = function(v)
        Cfg.RegenRate = v
        StaminaGainVal.Value = v
    end,
})

gMain:AddSlider("DrainRate", {
    Text = "Drain Rate",
    Default = Cfg.DrainRate,
    Min = 0.05,
    Max = 5,
    Rounding = 2,
    Tooltip = "Seconds per stamina tick while draining. Lower = slower drain.",
    Callback = function(v)
        Cfg.DrainRate = v
        StaminaLossVal.Value = v
    end,
})

gMain:AddSlider("PunishDuration", {
    Text = "Punishment Duration",
    Default = Cfg.PunishDuration,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Tooltip = "How long the run-lock lasts after hitting 0 stamina (0 = instant). Ignored while Infinite Stamina is on.",
    Callback = function(v)
        Cfg.PunishDuration = v
    end,
})

-- UI Settings
local gUI = Tabs.UI:AddGroupbox({ Side = "Left", Name = "Menu", Description = "Interface settings" })

gUI:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

gUI:AddButton("Unload", function()
    Library:Unload()
end)

-- Core loop
local lockStart = nil
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local moving = hum and hum.MoveDirection.Magnitude > 0.1
    local notSeated = hum and hum:GetState() ~= Enum.HumanoidStateType.Seated
    local runKey = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL2)

    local locked = Stats:GetAttribute("runActionLocked") == true

    if Cfg.InfiniteStamina then
        -- Never allow the punishment lock to stick
        if locked then
            Stats:SetAttribute("runActionLocked", nil)
            lockStart = nil
        end
        -- Keep running at 0 stamina while the player is actively running
        if Stats:GetAttribute("stamina") <= 0
            and Stats:GetAttribute("canMove") == true
            and Stats:GetAttribute("canRun") == true
            and moving
            and notSeated
            and runKey then
            Stats:SetAttribute("isRunning", true)
        end
    else
        -- Punishment duration override
        if locked and not lockStart then
            lockStart = tick()
        elseif not locked then
            lockStart = nil
        end
        if lockStart and tick() - lockStart >= Cfg.PunishDuration then
            Stats:SetAttribute("runActionLocked", nil)
            lockStart = nil
        end
    end
end)

Library:Notify({
    Title = "Stamina Manipulator",
    Description = "Loaded. Open the menu with " .. tostring(Library.ToggleKeybind) .. ".",
    Time = 5,
})
