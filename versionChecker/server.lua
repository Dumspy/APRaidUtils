local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Comms = AP:GetModule("Comms")
local VersionChecker = AP:GetModule("VersionChecker")

function VersionChecker:OnEnable()
    Comms:RegisterCallback("VERSION_INFO", function(event, sender, distribution, data)
        self:AppendUIResultRow(sender, data.versions or {})
    end)

    self:RegisterChatCommand("apvc", function()
        if self.ShowUI then self:ShowUI() end
    end)
end

function VersionChecker:RequestVersionCheck(waNames)
    print("Requesting versions for WeakAuras:", table.concat(waNames, ", "))
    if self.ClearUIResults then self:ClearUIResults() end
    local channel
    if IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    else
        self:Print("Not in a group!")
        return
    end
    Comms:Broadcast("QUERY_VERSION", channel, {waNames = waNames})
    self:Print("Requested version info from " .. channel .. " members.")
end

