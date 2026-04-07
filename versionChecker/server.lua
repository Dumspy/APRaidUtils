local AP = _G["APRaidUtils"]
local Comms = AP.Comms
local VersionChecker = AP.VersionChecker

if Comms then
    Comms:RegisterCallback("VERSION_INFO", function(event, sender, distribution, data)
        VersionChecker:AppendUIResultRow(sender, data.versions or {})
    end)
end

function VersionChecker:RequestVersionCheck(waNames)
    if self.ClearUIResults then self:ClearUIResults() end

    local channel
    if IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    else
        if self.SetVersionStatusText then
            self:SetVersionStatusText("Not in a group.")
        end
        AP:Print("Not in a group!")
        return false
    end

    if self.SetVersionStatusText then
        self:SetVersionStatusText("Requested version info from " .. channel .. " members. Waiting for replies...")
    end

    Comms:Broadcast("QUERY_VERSION", channel, {waNames = waNames})
    AP:Print("Requested version info from " .. channel .. " members.")
    return true
end