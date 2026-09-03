local AP = {}
_G["APRaidUtils"] = AP
_G["AP"] = AP

local eventFrame = CreateFrame("Frame")
AP.eventFrame = eventFrame
eventFrame:SetAllPoints(UIParent)
eventFrame:SetFrameStrata("BACKGROUND")

local addonVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
local IsDevVersion = (addonVersion == "@project-version@")

local function EnsureSavedVariables()
    if type(APRaidUtilsDB) ~= "table" then
        APRaidUtilsDB = {}
    end

    if type(APRaidUtilsDB.profile) ~= "table" then
        APRaidUtilsDB.profile = {}
    end

    if type(APRaidUtilsDB.global) ~= "table" then
        APRaidUtilsDB.global = {}
    end

    if type(APRaidUtilsDB.profile.breaktimer) ~= "table" then
        APRaidUtilsDB.profile.breaktimer = {}
    end

    if type(APRaidUtilsDB.global.breaktimer) ~= "table" then
        APRaidUtilsDB.global.breaktimer = {}
    end

    if type(APRaidUtilsDB.profile.readycheck) ~= "table" then
        APRaidUtilsDB.profile.readycheck = {}
    end

    if type(APRaidUtilsDB.profile.team) ~= "table" then
        APRaidUtilsDB.profile.team = {}
    end
end

local function InitializeSavedVariables()
    EnsureSavedVariables()
end

function AP:Print(...)
    print("|cFFFFD100APRaidUtils|r:", ...)
end

function AP:OnAddonLoaded()
    InitializeSavedVariables()

    if not IsDevVersion and AP.Comms then
        AP.Comms:RegisterCallback("CHECK_UPDATE", function(event, sender, distribution, data)
            local theirVersion = data and data.versions and data.versions.APRaidUtils
            local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
            if theirVersion and myVersion and self:IsVersionNewer(theirVersion, myVersion) then
                self:Print("A newer version of APRaidUtils is available: " .. theirVersion)
            end
        end)
    end

    self:Print("Loaded")
end

function AP:OnPlayerLogin()
    self:NotifyOptionsChanged()

    -- Re-enable any feature the user previously opted into. Features build
    -- lazily and register their events only once enabled, so nothing runs for
    -- features that were left off.
    if self.LeadPassReminder and self.LeadPassReminder.Restore then
        self.LeadPassReminder:Restore()
    end

    if self.BreakTimer and self.BreakTimer.Restore then
        self.BreakTimer:Restore()
    end

    if self.Sszorak and self.Sszorak.Restore then
        self.Sszorak:Restore()
    end

    if self.ReadyCheck and self.ReadyCheck.Restore then
        self.ReadyCheck:Restore()
    end

    if self.Team and self.Team.Restore then
        self.Team:Restore()
    end

    if IsInGuild() and not IsDevVersion then
        local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
        if AP.Comms then
            AP.Comms:Broadcast("CHECK_UPDATE", "GUILD", { versions = { APRaidUtils = myVersion } })
        end
    end
end

function AP:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        self:NotifyOptionsChanged()
    end
end

function AP:NotifyOptionsChanged()
    if self.RefreshSettingsTab then
        self:RefreshSettingsTab()
    end

    if self.RefreshMultiboxTab then
        self:RefreshMultiboxTab()
    end
end

function AP:HandleChatCommand()
    if self.ToggleMainWindow then
        self:ToggleMainWindow()
        return
    end

    self:Print("APRaidUtils UI is unavailable.")
end

function AP:IsVersionNewer(their, mine)
    local maj1, min1, pat1 = tostring(their):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj1, min1, pat1 = tonumber(maj1) or 0, tonumber(min1) or 0, tonumber(pat1) or 0

    local maj2, min2, pat2 = tostring(mine):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj2, min2, pat2 = tonumber(maj2) or 0, tonumber(min2) or 0, tonumber(pat2) or 0

    if maj1 > maj2 then
        return true
    end
    if maj1 == maj2 and min1 > min2 then
        return true
    end
    if maj1 == maj2 and min1 == min2 and pat1 > pat2 then
        return true
    end
    return false
end

SlashCmdList["APRAIDUTILS"] = function(msg)
    AP:HandleChatCommand(msg)
end
SLASH_APRAIDUTILS1 = "/ap"
