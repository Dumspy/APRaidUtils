local AP = _G["APRaidUtils"]
local eventFrame = AP.eventFrame

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")

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
    elseif event == "START_LOOT_ROLL" then
        if self.HousingRoll and self.HousingRoll.OnStartLootRoll then
            self.HousingRoll:OnStartLootRoll(...)
        end
    elseif event == "CONFIRM_LOOT_ROLL" then
        if self.HousingRoll and self.HousingRoll.OnConfirmLootRoll then
            self.HousingRoll:OnConfirmLootRoll(...)
        end
    end
end
