APRaidUtils = LibStub("AceAddon-3.0"):NewAddon("APRaidUtils", "AceConsole-3.0", "AceEvent-3.0")

local Comms = nil

function APRaidUtils:OnInitialize()
    Comms = self:GetModule("Comms")

    self:Print("Loaded")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    
    Comms:RegisterCallback("CHECK_UPDATE", function(event, sender, distribution, data)
        local theirVersion = data and data.versions and data.versions.APRaidUtils
        local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
        if theirVersion and myVersion and IsVersionNewer(theirVersion, myVersion) then
            APRaidUtils:Print("A newer version of APRaidUtils is available: " .. theirVersion)
        end
    end)
end

function APRaidUtils:OnPlayerLogin()
    if IsInGuild() then
        local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
        Comms:Broadcast("CHECK_UPDATE", "GUILD", {versions = {APRaidUtils = myVersion}})
    end
end

function IsVersionNewer(their, mine)
    local maj1, min1, pat1 = tostring(their):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj1, min1, pat1 = tonumber(maj1) or 0, tonumber(min1) or 0, tonumber(pat1) or 0

    -- Parse "mine"
    local maj2, min2, pat2 = tostring(mine):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj2, min2, pat2 = tonumber(maj2) or 0, tonumber(min2) or 0, tonumber(pat2) or 0

    -- Compare
    if maj1 > maj2 then return true end
    if maj1 == maj2 and min1 > min2 then return true end
    if maj1 == maj2 and min1 == min2 and pat1 > pat2 then return true end
    return false
end
