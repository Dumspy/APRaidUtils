local AP = _G["APRaidUtils"]

local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

local Comms = {}
AP.Comms = Comms

local COMM_PREFIX = "AP_MSG"
local callbacks = {}

local commRateLimits = {}
local COMM_RATE_LIMIT_WINDOW = 2
local COMM_RATE_LIMIT_MAX = 5

local function CheckRateLimit(sender, event)
    local key = sender .. ":" .. event
    local now = GetTime()
    local limits = commRateLimits[key]

    if not limits then
        limits = { count = 0, resetTime = now + COMM_RATE_LIMIT_WINDOW }
        commRateLimits[key] = limits
    end

    if now > limits.resetTime then
        limits.count = 0
        limits.resetTime = now + COMM_RATE_LIMIT_WINDOW
    end

    limits.count = limits.count + 1
    return limits.count <= COMM_RATE_LIMIT_MAX
end

function Comms:RegisterCallback(event, func)
    callbacks[event] = func
end

function Comms:Broadcast(event, channel, ...)
    local args = {...}
    local payload = AceSerializer:Serialize({event = event, data = args})
    AceComm:SendCommMessage(COMM_PREFIX, payload, channel or "GUILD")
end

function Comms:Whisper(event, target, ...)
    local args = {...}
    local payload = AceSerializer:Serialize({event = event, data = args})
    AceComm:SendCommMessage(COMM_PREFIX, payload, "WHISPER", target)
end

function Comms:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end

    if not UnitInRaid(sender) and not UnitInParty(sender) then return end

    if not CheckRateLimit(sender, prefix) then return end

    local success, payload = AceSerializer:Deserialize(message)
    if not success or not payload or type(payload.event) ~= "string" then return end
    if type(payload.data) ~= "table" then return end

    local callback = callbacks[payload.event]
    if callback then
        local cbSuccess, err = pcall(callback, payload.event, sender, distribution, payload.data)
        if not cbSuccess then
            AP:Print("Error handling comm event " .. payload.event .. ": " .. tostring(err))
        end
    end
end

AceComm:RegisterComm(COMM_PREFIX, function(prefix, message, distribution, sender)
    Comms:OnCommReceived(prefix, message, distribution, sender)
end)