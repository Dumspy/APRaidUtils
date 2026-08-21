local AP = _G["APRaidUtils"]

local BreakTimer = {}
AP.BreakTimer = BreakTimer

local BIGWIGS_PREFIX = "BigWigs"
local DEFAULT_DBM_PREFIX = "D5"
local BIGWIGS_MODE = "bigwigs"
local RAW_MODE = "raw"
local DEFAULT_PLACEHOLDER_TEXT = "Break - 5:00\n\nEnds at 17:30:00"
local date = _G.date
local time = _G.time
local strsplit = _G.strsplit
local RegisterAddonMessagePrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix)
    or _G.RegisterAddonMessagePrefix

local anchorFrame = nil
local activeBreak = nil
local updateTicker = nil
local receiveMode = nil
local bigWigsRegistered = false
local hiddenForCombat = false

local bigWigsCallbacks = {}

local function GetDBMPrefix()
    if
        type(BigWigsLoader) == "table"
        and type(BigWigsLoader.dbmPrefix) == "string"
        and BigWigsLoader.dbmPrefix ~= ""
    then
        return BigWigsLoader.dbmPrefix
    end

    return DEFAULT_DBM_PREFIX
end

local function GetSettings()
    if not APRaidUtilsDB or not APRaidUtilsDB.profile then
        return {
            enabled = false,
            showCountdown = true,
            showEndTime = true,
        }
    end

    local settings = APRaidUtilsDB.profile.breaktimer
    if type(settings) ~= "table" then
        return {
            enabled = false,
            showCountdown = true,
            showEndTime = true,
        }
    end

    return {
        enabled = settings.enabled == true,
        showCountdown = settings.showCountdown ~= false,
        showEndTime = settings.showEndTime ~= false,
    }
end

local function GetMutableSettings()
    if not APRaidUtilsDB or not APRaidUtilsDB.profile then
        return nil
    end

    return APRaidUtilsDB.profile.breaktimer
end

local function GetMutableGlobalState()
    if not APRaidUtilsDB or not APRaidUtilsDB.global then
        return nil
    end

    return APRaidUtilsDB.global.breaktimer
end

local function SaveActiveBreak()
    local state = GetMutableGlobalState()
    if not state then
        return
    end

    if not activeBreak then
        state.active = nil
        return
    end

    state.active = {
        source = activeBreak.source,
        startedAt = activeBreak.startedAt,
        duration = activeBreak.duration,
        endsAt = activeBreak.endsAt,
        startedBy = activeBreak.startedBy,
        isDBM = activeBreak.isDBM == true,
    }
end

local function RestoreActiveBreak()
    local state = GetMutableGlobalState()
    local savedBreak = state and state.active
    if type(savedBreak) ~= "table" then
        return
    end

    local endsAt = tonumber(savedBreak.endsAt)
    local duration = tonumber(savedBreak.duration)
    local startedAt = tonumber(savedBreak.startedAt)
    if not endsAt or not duration or not startedAt or endsAt <= time() then
        state.active = nil
        return
    end

    activeBreak = {
        source = savedBreak.source,
        startedAt = startedAt,
        duration = duration,
        endsAt = endsAt,
        startedBy = savedBreak.startedBy,
        isDBM = savedBreak.isDBM == true,
    }
end

local function HasVisibleTextEnabled()
    local settings = GetSettings()
    return settings.showCountdown == true or settings.showEndTime == true
end

local function FormatCountdown(seconds)
    local safeSeconds = math.max(0, math.floor(seconds or 0))
    local minutes = math.floor(safeSeconds / 60)
    local remainder = safeSeconds % 60
    return string.format("%d:%02d", minutes, remainder)
end

local function FormatEndTime(timestamp)
    return date("%H:%M:%S", timestamp or time())
end

local function BuildDisplayText()
    local settings = GetSettings()
    if not activeBreak or settings.enabled ~= true or not HasVisibleTextEnabled() or hiddenForCombat then
        return nil
    end

    local remainingSeconds = math.max(0, (activeBreak.endsAt or time()) - time())
    local lines = {}

    if settings.showCountdown == true then
        lines[#lines + 1] = "Break - " .. FormatCountdown(remainingSeconds)
    end

    if settings.showEndTime == true then
        lines[#lines + 1] = "Ends at " .. FormatEndTime(activeBreak.endsAt)
    end

    if #lines == 2 then
        return lines[1] .. "\n\n" .. lines[2]
    end

    return lines[1]
end

local function CreateAnchor()
    if anchorFrame then
        return anchorFrame
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return nil
    end

    anchorFrame = APAnchor:CreateAnchor("breaktimer", {
        text = DEFAULT_PLACEHOLDER_TEXT,
        fontSize = 18,
        maxWidth = 220,
        maxHeight = 90,
        font = "Friz Quadrata TT",
        colorR = 1.0,
        colorG = 0.82,
        colorB = 0,
        opacity = 1.0,
        locked = false,
    })

    return anchorFrame
end

local function StopTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

local function RefreshAnchor()
    if not BreakTimer:IsEnabled() then
        return
    end

    local frame = CreateAnchor()
    if not frame then
        return
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    local text = BuildDisplayText()
    APAnchor:UpdateAnchorText("breaktimer", text or DEFAULT_PLACEHOLDER_TEXT)

    if text then
        APAnchor:SetAnchorVisible("breaktimer", true)
    else
        APAnchor:SetAnchorVisible("breaktimer", false)
    end
end

local function StopBreak()
    activeBreak = nil
    SaveActiveBreak()
    StopTicker()
    RefreshAnchor()
end

local function StartTicker()
    if updateTicker then
        return
    end

    updateTicker = C_Timer.NewTicker(1, function()
        if not activeBreak then
            StopBreak()
            return
        end

        if (activeBreak.endsAt or 0) <= time() then
            StopBreak()
            return
        end

        RefreshAnchor()
    end)
end

local function StartBreak(source, seconds, startedBy, isDBM)
    if not BreakTimer:IsEnabled() then
        return
    end

    local duration = tonumber(seconds)
    if not duration then
        return
    end

    if duration <= 0 then
        StopBreak()
        return
    end

    if duration > 3600 then
        return
    end

    activeBreak = {
        source = source,
        startedAt = time(),
        duration = duration,
        endsAt = time() + duration,
        startedBy = startedBy,
        isDBM = isDBM == true,
    }

    SaveActiveBreak()
    StopTicker()
    RefreshAnchor()
    StartTicker()
end

local function CanUseBigWigsEvents()
    return type(BigWigsLoader) == "table" and type(BigWigsLoader.RegisterMessage) == "function"
end

local function UpdateReceiveMode()
    if CanUseBigWigsEvents() then
        receiveMode = BIGWIGS_MODE
    else
        receiveMode = RAW_MODE
    end
end

local function RegisterBigWigsMessages()
    if bigWigsRegistered or not CanUseBigWigsEvents() then
        return
    end

    bigWigsCallbacks.BigWigs_StartBreak = function(_, _, _, seconds, nick, isDBM)
        StartBreak(isDBM and "DBM" or "BigWigs", seconds, nick, isDBM)
    end

    bigWigsCallbacks.BigWigs_StopBreak = function(_, _, _, seconds)
        if tonumber(seconds) == 0 then
            StopBreak()
        end
    end

    BigWigsLoader.RegisterMessage(bigWigsCallbacks, "BigWigs_StartBreak")
    BigWigsLoader.RegisterMessage(bigWigsCallbacks, "BigWigs_StopBreak")
    bigWigsRegistered = true
end

local function RegisterAddonPrefixes()
    RegisterAddonMessagePrefix(BIGWIGS_PREFIX)
    RegisterAddonMessagePrefix(GetDBMPrefix())
end

local function UnregisterBigWigsMessages()
    if not bigWigsRegistered then
        return
    end

    if CanUseBigWigsEvents() and BigWigsLoader.UnregisterMessage then
        BigWigsLoader.UnregisterMessage(bigWigsCallbacks, "BigWigs_StartBreak")
        BigWigsLoader.UnregisterMessage(bigWigsCallbacks, "BigWigs_StopBreak")
    end

    bigWigsRegistered = false
end

local function HideAnchor()
    local APAnchor = AP.APAnchor
    if anchorFrame and APAnchor then
        APAnchor:SetAnchorVisible("breaktimer", false)
    end
end

function BreakTimer:Enable()
    if not self:IsEnabled() then
        return
    end

    UpdateReceiveMode()
    RegisterAddonPrefixes()
    RegisterBigWigsMessages()
    AP:EnableFeatureEvents("breaktimer")
    CreateAnchor()
    RestoreActiveBreak()

    if activeBreak and (activeBreak.endsAt or 0) > time() then
        StartTicker()
    end

    RefreshAnchor()
end

function BreakTimer:Disable()
    AP:DisableFeatureEvents("breaktimer")
    UnregisterBigWigsMessages()
    StopTicker()
    HideAnchor()
end

function BreakTimer:Restore()
    if self:IsEnabled() then
        self:Enable()
        return
    end

    StopTicker()
end

function BreakTimer:OnChatMsgAddon(prefix, message, channel, sender)
    if not self:IsEnabled() then
        return
    end

    if receiveMode ~= RAW_MODE then
        return
    end

    if channel ~= "RAID" and channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" then
        return
    end

    if prefix == BIGWIGS_PREFIX then
        local bwPrefix, bwMsg, extra = strsplit("^", message or "")
        if bwPrefix == "P" and bwMsg == "Break" then
            StartBreak("BigWigs", extra, sender, false)
        end
    elseif prefix == GetDBMPrefix() then
        local _, _, subPrefix, arg1 = strsplit("\t", message or "")
        if subPrefix == "BT" then
            StartBreak("DBM", arg1, sender, true)
        end
    end
end

function BreakTimer:OnPlayerRegenDisabled()
    if not self:IsEnabled() then
        return
    end

    hiddenForCombat = true
    RefreshAnchor()
end

function BreakTimer:OnPlayerRegenEnabled()
    if not self:IsEnabled() then
        return
    end

    hiddenForCombat = false

    if activeBreak and (activeBreak.endsAt or 0) <= time() then
        StopBreak()
        return
    end

    RefreshAnchor()
end

function BreakTimer:IsEnabled()
    return GetSettings().enabled == true
end

function BreakTimer:SetEnabled(value)
    local settings = GetMutableSettings()
    if settings then
        settings.enabled = value == true
    end

    if value == true then
        self:Enable()
    else
        self:Disable()
    end
end

function BreakTimer:GetShowCountdown()
    return GetSettings().showCountdown == true
end

function BreakTimer:SetShowCountdown(value)
    local settings = GetMutableSettings()
    if settings then
        settings.showCountdown = value == true
    end
    RefreshAnchor()
end

function BreakTimer:GetShowEndTime()
    return GetSettings().showEndTime == true
end

function BreakTimer:SetShowEndTime(value)
    local settings = GetMutableSettings()
    if settings then
        settings.showEndTime = value == true
    end
    RefreshAnchor()
end

function BreakTimer:ToggleAnchors()
    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    APAnchor:ToggleAllAnchors()
end
