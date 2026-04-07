local AP = _G["APRaidUtils"]
local Reminders = AP.Reminders

function Reminders:RefreshUI()
    if AP.RefreshRemindersTab then
        AP:RefreshRemindersTab()
    end
end

function Reminders:ShowUI()
    if AP.OpenMainWindow then
        AP:OpenMainWindow("Reminders")
        return
    end

    self:Print("APRaidUtils UI is unavailable.")
end
