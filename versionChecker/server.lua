local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Comms = AP:GetModule("Comms")
local VersionChecker = AP:GetModule("VersionChecker")

function VersionChecker:OnEnable()
    self:RegisterChatCommand("apcheck", function(input)
        local waNames = {}
        for wa in string.gmatch(input or "", "[^,]+") do
            wa = wa:match("^%s*(.-)%s*$") -- trim
            if wa ~= "" then
                table.insert(waNames, wa)
            end
        end
        if #waNames == 0 then
            waNames = {"Liquid - Manaforge Omega", "Liquid Anchors (don't rename these)", "LiquidWeakAuras"}
        end
        self:RequestVersionCheck(waNames)
    end)

    self:Print("VersionChecker server module enabled. Use /apcheck [WeakAura1,WeakAura2,...] to request versions.")
end

-- Simple server: chat command to request version info from party/raid
function VersionChecker:RequestVersionCheck(waNames)
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

function VersionChecker:OnCommReceived(prefix, message, distribution, sender)
    if prefix == APVersionChecker_ACE_PREFIX then
        local AceSerializer = LibStub("AceSerializer-3.0")
        local success, payload = AceSerializer:Deserialize(message)
        if success and type(payload) == "table" and payload.response == "VERSION_INFO" then
            self:Print("Version info from " .. sender .. ":")
            for k, v in pairs(payload.versions or {}) do
                if type(v) == "table" then
                    for waName, waVer in pairs(v) do
                        self:Print("  WeakAura '" .. waName .. "': " .. tostring(waVer))
                    end
                else
                    self:Print("  " .. k .. ": " .. tostring(v))
                end
            end
        end
    end
end