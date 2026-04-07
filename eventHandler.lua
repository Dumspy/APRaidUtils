local AP = _G["APRaidUtils"]
local eventFrame = AP.eventFrame

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

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
    elseif event == "GROUP_ROSTER_UPDATE" then
        if self.LeadPassReminder then
            self.LeadPassReminder:CheckConditions()
        end
    end
end