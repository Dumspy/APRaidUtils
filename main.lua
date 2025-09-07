APRaidUtils = LibStub("AceAddon-3.0"):NewAddon("APRaidUtils", "AceConsole-3.0", "AceEvent-3.0")

local Comms = nil

function APRaidUtils:OnInitialize()
    Comms = self:GetModule("Comms")

    self:Print("Loaded")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    
    Comms:RegisterCallback("CHECK_UPDATE", function(event, sender, distribution, data)
        local theirVersion = data and data[1] and data[1].versions and data[1].versions.APRaidUtils
        local myVersion = GetAddOnMetadata("APRaidUtils", "Version")
        if theirVersion and myVersion and IsVersionNewer(theirVersion, myVersion) then
            APRaidUtils:Print("A newer version of APRaidUtils is available: " .. theirVersion)
        end
    end)
end

function APRaidUtils:OnPlayerLogin()
    if IsInGuild() then
        local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
        if IsInGuild() and myVersion ~= "@project-version@" then
            Comms:Broadcast("CHECK_UPDATE", "GUILD", {versions = {APRaidUtils = myVersion}})
        end
    end
end

function IsVersionNewer(their, mine)
    local function parse(ver)
        local major, minor, patch = string.match(ver or "", "(%d+)%.(%d+)%.(%d+)")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end
    local maj1, min1, pat1 = parse(their)
    local maj2, min2, pat2 = parse(mine)
    if maj1 > maj2 then return true end
    if maj1 == maj2 and min1 > min2 then return true end
    if maj1 == maj2 and min1 == min2 and pat1 > pat2 then return true end
    return false
end