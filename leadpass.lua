local AP = _G["APRaidUtils"]

local LeadPassReminder = {}
AP.LeadPassReminder = LeadPassReminder

local MYTHIC_DIFFICULTY_IDS = {
    [16] = true,
}

local DEFAULT_REMINDER_TEXT = "You're in group 5-8 on Mythic. Consider passing lead to someone in groups 1-4."

local anchorFrame = nil

local function GetSettings()
    if not APRaidUtilsDB or not APRaidUtilsDB.profile then
        return { enabled = false }
    end
    if not APRaidUtilsDB.profile.leadpass then
        APRaidUtilsDB.profile.leadpass = {}
    end
    return APRaidUtilsDB.profile.leadpass
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
    if not IsInRaid() then
        return 0
    end

    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit("raid" .. i, "player") then
            return select(3, GetRaidRosterInfo(i)) or 0
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

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return nil
    end

    anchorFrame = APAnchor:CreateAnchor("leadpass", {
        text = DEFAULT_REMINDER_TEXT,
        fontSize = 16,
        maxWidth = 400,
        maxHeight = 60,
        font = "Friz Quadrata TT",
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

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    if ShouldShowReminder() then
        APAnchor:SetAnchorVisible("leadpass", true)
    else
        APAnchor:SetAnchorVisible("leadpass", false)
    end
end

function LeadPassReminder:OnAddonLoaded()
    CreateAnchor()
end

function LeadPassReminder:IsEnabled()
    return IsEnabled()
end

function LeadPassReminder:SetEnabled(value)
    SetEnabled(value)
end

function LeadPassReminder:ToggleAnchors()
    CreateAnchor()

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    APAnchor:ToggleAllAnchors()
end
