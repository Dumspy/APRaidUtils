local AP = _G["APRaidUtils"]
local ConfirmLootRoll = _G.ConfirmLootRoll
local GetItemInfo = _G.GetItemInfo
local GetItemInfoInstant = _G.GetItemInfoInstant
local GetLootRollItemInfo = _G.GetLootRollItemInfo
local GetLootRollItemLink = _G.GetLootRollItemLink
local RollOnLoot = _G.RollOnLoot

local HousingRoll = {}
AP.HousingRoll = HousingRoll

local MODE_DISABLED = "disabled"
local MODE_NEED = "need"
local MODE_GREED = "greed"
local MODE_PASS = "pass"

local ROLL_TYPES_BY_MODE = {
    [MODE_NEED] = 1,
    [MODE_GREED] = 2,
    [MODE_PASS] = 0,
}

local VALID_MODES = {
    [MODE_DISABLED] = true,
    [MODE_NEED] = true,
    [MODE_GREED] = true,
    [MODE_PASS] = true,
}

local MODE_OPTIONS = {
    { value = MODE_DISABLED, label = "Disabled" },
    { value = MODE_NEED, label = "Need" },
    { value = MODE_GREED, label = "Greed" },
    { value = MODE_PASS, label = "Pass" },
}

local pendingConfirmations = {}

local function GetSettings()
    if not APRaidUtilsDB or type(APRaidUtilsDB.profile) ~= "table" then
        return { mode = MODE_DISABLED }
    end

    if type(APRaidUtilsDB.profile.housingRoll) ~= "table" then
        rawset(APRaidUtilsDB.profile, "housingRoll", {
            mode = MODE_DISABLED,
        })
    end

    return APRaidUtilsDB.profile.housingRoll
end

local function NormalizeMode(mode)
    if VALID_MODES[mode] then
        return mode
    end

    return MODE_DISABLED
end

local function GetMode()
    return NormalizeMode(GetSettings().mode)
end

local function SetMode(mode)
    local settings = GetSettings()
    settings.mode = NormalizeMode(mode)
    AP:NotifyOptionsChanged()
end

local function GetRollTypeForMode(mode)
    return ROLL_TYPES_BY_MODE[NormalizeMode(mode)]
end

local function GetHousingClassID(itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    if GetItemInfoInstant then
        local _, _, _, _, _, itemClassID = GetItemInfoInstant(itemLink)
        if itemClassID ~= nil then
            return itemClassID
        end
    end

    local _, _, _, _, _, _, _, _, _, _, _, itemClassID = GetItemInfo(itemLink)
    return itemClassID
end

local function IsHousingRoll(rollID)
    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink then
        return false
    end

    return GetHousingClassID(itemLink) == Enum.ItemClass.Housing
end

local function IsRollTypeAvailable(rollID, rollType)
    if rollType == 0 then
        return true
    end

    local _, _, _, _, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
    if rollType == 1 then
        return canNeed == true
    end

    if rollType == 2 then
        return canGreed == true
    end

    return false
end

function HousingRoll:IsHousingRoll(rollID)
    return IsHousingRoll(rollID)
end

function HousingRoll:GetMode()
    return GetMode()
end

function HousingRoll:SetMode(mode)
    SetMode(mode)
end

function HousingRoll:GetModeOptions()
    return MODE_OPTIONS
end

function HousingRoll:OnStartLootRoll(rollID)
    pendingConfirmations[rollID] = nil

    local rollType = GetRollTypeForMode(GetMode())
    if rollType == nil then
        return
    end

    if not IsHousingRoll(rollID) then
        return
    end

    if not IsRollTypeAvailable(rollID, rollType) then
        return
    end

    pendingConfirmations[rollID] = rollType
    RollOnLoot(rollID, rollType)
end

function HousingRoll:OnConfirmLootRoll(rollID, rollType)
    if pendingConfirmations[rollID] ~= rollType then
        return
    end

    pendingConfirmations[rollID] = nil

    if not IsHousingRoll(rollID) then
        return
    end

    ConfirmLootRoll(rollID, rollType)
end
