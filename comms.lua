-- APRaidUtils Comms Module
-- Centralized AceComm-3.0 communication handling

local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local Comms = AP:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")

local COMM_PREFIX = "AP_MSG"
local callbacks = {}

function Comms:RegisterCallback(event, func)
    callbacks[event] = func
end

function Comms:Broadcast(event, channel, ...)
    local args = {...}
    local payload = self:Serialize({event = event, data = args})
    self:SendCommMessage(COMM_PREFIX, payload, channel or "GUILD")
end

function Comms:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end
    local success, payload = self:Deserialize(message)
    if success and payload and payload.event and callbacks[payload.event] then
        callbacks[payload.event](payload.event, sender, distribution, payload.data)
    end
end

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX)
end
