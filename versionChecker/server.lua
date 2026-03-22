local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Comms = AP:GetModule("Comms")
local VersionChecker = AP:GetModule("VersionChecker")

function VersionChecker:OnEnable()
    Comms:RegisterCallback("VERSION_INFO", function(event, sender, distribution, data)
        self:AppendUIResultRow(sender, data.versions or {})
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
        self:Print("Not in a group!")
        return false
    end

    if self.SetVersionStatusText then
        self:SetVersionStatusText("Requested version info from " .. channel .. " members. Waiting for replies...")
    end

    Comms:Broadcast("QUERY_VERSION", channel, {waNames = waNames})
    self:Print("Requested version info from " .. channel .. " members.")
    return true
end

