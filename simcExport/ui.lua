local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local SimcExport = AP:GetModule("SimcExport")

function SimcExport:RefreshUI()
    if AP.RefreshSimcTab then
        AP:RefreshSimcTab()
    end
end

function SimcExport:ShowUI()
    if AP.OpenMainWindow then
        AP:OpenMainWindow("SimC")
        return
    end

    self:Print("APRaidUtils UI is unavailable.")
end
