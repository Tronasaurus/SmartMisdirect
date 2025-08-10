-- SmartMisdirect Addon (MoP Classic Version)
local addonName = ...

-- ==== CLASS GATE ============================================================
local classID = select(3, UnitClass("player"))
local IS_HUNTER = (classID == 3)
local IS_ROGUE  = (classID == 4)
if not (IS_HUNTER or IS_ROGUE) then
    -- Not a Hunter or Rogue: do nothing (no frames, no events, no timers)
    return
end
-- ============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

local auraBtn
local spellName
local updateRequired = true

-- User Settings (you can move this to Config.lua if you want later)
local defaultUnit = "target"
local petFallback = true
local priorityTargetName = "Kovi"
local priorityTargetNameServer = "Area52"
local debugOn = false

-- Utility
local function DebugPrint(msg)
    if debugOn then print("|cFFFFCC00[SmartMisdirect DEBUG]:|r " .. msg) end
end

local function TableContains(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

-- Button setup
local function ButtonSetAttribute(button, attribute, value)
    button:SetAttribute(attribute, value)
    DebugPrint("Set " .. attribute .. " to " .. tostring(value))
end

-- Determine correct spell
local misdirectName = GetSpellInfo(34477)
local tricksName = GetSpellInfo(57934)

local function setMisdirectOrTricks()
    if classID == 4 then -- Rogue
        spellName = tricksName
        ButtonSetAttribute(auraBtn, "spell", 57934)
    else                -- Hunter
        spellName = misdirectName
        ButtonSetAttribute(auraBtn, "spell", 34477)
    end
end

-- Main logic
local function smart_find_target()
    local target_unit, backup_target
    local isInRaid = IsInRaid()

    if IsInGroup() then
        local count = GetNumGroupMembers()
        for i = 1, count do
            local unit = isInRaid and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                local name, realm = UnitName(unit)
                realm = realm or GetNormalizedRealmName()

                if priorityTargetName == name and (priorityTargetNameServer == "" or realm == priorityTargetNameServer) then
                    target_unit = unit
                    break
                elseif not backup_target then
                    backup_target = unit
                end
            end
        end
    end

    if not target_unit then
        if backup_target then
            target_unit = backup_target
        elseif petFallback and UnitExists("pet") and IS_HUNTER then
            target_unit = "pet"
        else
            target_unit = defaultUnit
        end
    end

    if auraBtn:GetAttribute("unit") ~= target_unit then
        ButtonSetAttribute(auraBtn, "unit", target_unit)
        print(string.format("|cFFFFFF00%s|r target set to |cFF00FF00%s|r", spellName or "Spell", UnitName(target_unit) or target_unit))
    end
end

-- Create the secure button
if not SmartMisdirect then
    auraBtn = CreateFrame("Button", "SmartMisdirect", UIParent, "SecureActionButtonTemplate")
else
    auraBtn = SmartMisdirect
end

auraBtn:SetAttribute("type", "spell")
ButtonSetAttribute(auraBtn, "unit", defaultUnit)
setMisdirectOrTricks()

-- Run the targeting logic every 5 seconds when out of combat
C_Timer.NewTicker(5, function()
    if not InCombatLockdown() and updateRequired then
        smart_find_target()
        updateRequired = false
    end
end)

-- Events
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET"
        or event == "PET_BAR_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        updateRequired = true
    end
end)
