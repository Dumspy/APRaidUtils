local AP = _G["APRaidUtils"]
local SimcExport = AP.SimcExport

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
