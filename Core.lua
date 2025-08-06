-- SmartMisdirect Addon
local addonName = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
frame:RegisterEvent("PVP_WORLDSTATE_UPDATE")
frame:RegisterEvent("PVP_TIMER_UPDATE")

local auraBtn
local spellName
local updateRequired = true

-- Customizable Settings
local defaultUnit = "target"
local petFallback = true
local priorityTargetName = "Kovi"
local priorityTargetNameServer = "Area52"
local customMainTankStatus = {} -- e.g. { true, false }
local debugOn = false

-- Util
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
local interlopeName = GetSpellInfo(248518)
local tricksName = GetSpellInfo(57934)

local function setInterlopeOrMisdirect()
    local class = select(3, UnitClass("player"))
    if class == 4 then
        spellName = tricksName
        ButtonSetAttribute(auraBtn, "spell", 57934)
    else
        spellName = IsPlayerSpell(248518) and interlopeName or misdirectName
        ButtonSetAttribute(auraBtn, "spell", IsPlayerSpell(248518) and 248518 or 34477)
    end
end

-- Main logic
local function smart_find_target()
    local target_unit, backup_target
    local isInRaid = IsInRaid()

    if IsInGroup() then
        for i = 1, GetNumGroupMembers() do
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
        elseif petFallback and UnitExists("pet") then
            target_unit = IsPlayerSpell(248518) and "player" or "pet"
        else
            target_unit = defaultUnit
        end
    end

    if auraBtn:GetAttribute("unit") ~= target_unit then
        ButtonSetAttribute(auraBtn, "unit", target_unit)
        print(string.format("|cFFFFFF00%s|r target set to |cFF00FF00%s|r", spellName or "Spell", UnitName(target_unit) or target_unit))
    end
end

-- Frame creation (SecureActionButton)
if not SmartMisdirect then
    auraBtn = CreateFrame("Button", "SmartMisdirect", UIParent, "SecureActionButtonTemplate")
else
    auraBtn = SmartMisdirect
end

auraBtn:SetAttribute("type", "spell")
ButtonSetAttribute(auraBtn, "unit", defaultUnit)
setInterlopeOrMisdirect()

-- 5-second metronome
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
    elseif event == "PVP_WORLDSTATE_UPDATE" or event == "PLAYER_PVP_TALENT_UPDATE" or event == "PVP_TIMER_UPDATE" then
        setInterlopeOrMisdirect()
    end
end)
