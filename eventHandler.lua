local AP = _G["APRaidUtils"]
local eventFrame = AP.eventFrame

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    AP:HandleEvent(event, ...)
end)

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

        if self.SimcExport and self.SimcExport.OnPlayerEnteringWorld then
            self.SimcExport:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if self.SimcExport and self.SimcExport.OnPlayerEquipmentChanged then
            self.SimcExport:OnPlayerEquipmentChanged(...)
        end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if self.SimcExport and self.SimcExport.OnTraitConfigUpdated then
            self.SimcExport:OnTraitConfigUpdated(...)
        end
    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        if self.SimcExport and self.SimcExport.OnActivePlayerSpecializationChanged then
            self.SimcExport:OnActivePlayerSpecializationChanged(...)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if self.LeadPassReminder then
            self.LeadPassReminder:CheckConditions()
        end
    elseif event == "CHAT_MSG_ADDON" then
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
