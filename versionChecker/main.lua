local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local VersionChecker = AP:NewModule("VersionChecker", "AceSerializer-3.0", "AceComm-3.0", "AceConsole-3.0")

-- Shared AceComm prefix for version checker
APVersionChecker_ACE_PREFIX = "APVersionChecker"

function VersionChecker:OnEnable()
    self:RegisterComm(APVersionChecker_ACE_PREFIX)
    self:Print("VersionChecker module initialized!")
    local waNames = {"Liquid - Manaforge Omega", "Liquid Anchors (don't rename these)", "LiquidWeakAuras"}
    local versions = self:GetAllVersions(waNames)
    for k, v in pairs(versions) do
        if type(v) == "table" then
            for waName, waVer in pairs(v) do
                self:Print("WeakAura '", waName, "' version: ", waVer)
            end
        else
            self:Print(k .. ": " .. tostring(v))
        end
    end
end

function VersionChecker:OnCommReceived(prefix, message, distribution, sender)
    if prefix == APVersionChecker_ACE_PREFIX then
        local success, payload = self:Deserialize(message)
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