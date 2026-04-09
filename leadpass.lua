local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local LeadPassReminder = AP:NewModule("LeadPassReminder", "AceEvent-3.0")

local MYTHIC_DIFFICULTY_IDS = {
    [16] = true,
}

local DEFAULT_REMINDER_TEXT = "You're in group 5-8 on Mythic. Consider passing lead to someone in groups 1-4."

local anchorFrame = nil

local function GetSettings()
    if not AP.db or not AP.db.profile then
        return { enabled = false }
    end
    if not AP.db.profile.leadpass then
        AP.db.profile.leadpass = {}
    end
    return AP.db.profile.leadpass
end

local function IsEnabled()
    return GetSettings().enabled == true
end

local function SetEnabled(value)
    local settings = GetSettings()
    settings.enabled = value == true
    LeadPassReminder:CheckConditions()
end

local function GetPlayerRaidSubgroup()
    local raidSize = GetNumGroupMembers()
    if raidSize == 0 then
        return 0
    end

    local playerName = UnitName("player")
    for i = 1, raidSize do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name == playerName then
            return subgroup or 0
        end
    end
    return 0
end

local function ShouldShowReminder()
    if not IsEnabled() then
        return false
    end

    if not IsInRaid() then
        return false
    end

    if not UnitIsGroupLeader("player") then
        return false
    end

    local difficultyID = GetRaidDifficultyID()
    if not MYTHIC_DIFFICULTY_IDS[difficultyID] then
        return false
    end

    local subgroup = GetPlayerRaidSubgroup()
    if subgroup < 5 or subgroup > 8 then
        return false
    end

    return true
end

local function CreateAnchor()
    if anchorFrame then
        return anchorFrame
    end

    local APAnchor = AP:GetModule("APAnchor", true)
    if not APAnchor then
        return nil
    end

    anchorFrame = APAnchor:CreateAnchor("leadpass", {
        text = DEFAULT_REMINDER_TEXT,
        fontSize = 16,
        maxWidth = 400,
        maxHeight = 60,
        font = "GameFontNormal",
        colorR = 1.0,
        colorG = 0.82,
        colorB = 0,
        opacity = 1.0,
        locked = false,
    })

    return anchorFrame
end

function LeadPassReminder:CheckConditions()
    local frame = CreateAnchor()
    if not frame then
        return
    end

    if ShouldShowReminder() then
        frame:Show()
    else
        frame:Hide()
    end
end

function LeadPassReminder:OnInitialize()
end

function LeadPassReminder:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "CheckConditions")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckConditions")
    self:CheckConditions()
end

function LeadPassReminder:OnDisable()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    if anchorFrame then
        anchorFrame:Hide()
    end
end

function LeadPassReminder:IsEnabled()
    return IsEnabled()
end

function LeadPassReminder:SetEnabled(value)
    SetEnabled(value)
end

function LeadPassReminder:ToggleAnchors()
    local APAnchor = AP:GetModule("APAnchor", true)
    if not APAnchor then
        return
    end

    APAnchor:ToggleAllAnchors()
end
