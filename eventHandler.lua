local AP = _G["APRaidUtils"]
local eventFrame = AP.eventFrame

-- Core events are always needed for addon lifecycle.
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    AP:HandleEvent(event, ...)
end)

-- Feature events are registered lazily, only while their feature is enabled.
-- This is how we honour "zero cost unless enabled": a feature you never turn on
-- registers no events, builds no frames, and runs no handler work.
local featureEvents = {
    leadpass = { "GROUP_ROSTER_UPDATE" },
    breaktimer = { "CHAT_MSG_ADDON", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
}

local activeFeatures = {}

local function EventIsUsedElsewhere(feature, event)
    for other in pairs(activeFeatures) do
        if other ~= feature then
            for _, otherEvent in ipairs(featureEvents[other]) do
                if otherEvent == event then
                    return true
                end
            end
        end
    end
    return false
end

function AP:EnableFeatureEvents(feature)
    if activeFeatures[feature] then
        return
    end
    for _, event in ipairs(featureEvents[feature] or {}) do
        eventFrame:RegisterEvent(event)
    end
    activeFeatures[feature] = true
end

function AP:DisableFeatureEvents(feature)
    if not activeFeatures[feature] then
        return
    end
    for _, event in ipairs(featureEvents[feature] or {}) do
        if not EventIsUsedElsewhere(feature, event) then
            eventFrame:UnregisterEvent(event)
        end
    end
    activeFeatures[feature] = nil
end

function AP:HandleEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "APRaidUtils" then
            self:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        self:OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        self:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Only reachable while leadpass is enabled (event is gated).
        if self.LeadPassReminder and self.LeadPassReminder.CheckConditions then
            self.LeadPassReminder:CheckConditions()
        end
    elseif event == "CHAT_MSG_ADDON" then
        -- Only reachable while breaktimer is enabled (event is gated).
        if self.BreakTimer and self.BreakTimer.OnChatMsgAddon then
            self.BreakTimer:OnChatMsgAddon(...)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if self.BreakTimer and self.BreakTimer.OnPlayerRegenDisabled then
            self.BreakTimer:OnPlayerRegenDisabled()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.BreakTimer and self.BreakTimer.OnPlayerRegenEnabled then
            self.BreakTimer:OnPlayerRegenEnabled()
        end
    end
end
