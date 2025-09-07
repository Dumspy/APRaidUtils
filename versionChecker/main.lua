local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Comms = AP:GetModule("Comms")
local VersionChecker = AP:NewModule("VersionChecker", "AceConsole-3.0")

function VersionChecker:OnInitialize()
    Comms:RegisterCallback("VERSION_INFO", function(event, sender, distribution, data)
        self:Print("Version info from " .. sender .. ":")
        for k, v in pairs(data.versions or {}) do
            if type(v) == "table" then
                for waName, waVer in pairs(v) do
                    self:Print("  WeakAura '" .. waName .. "': " .. tostring(waVer))
                end
            else
                self:Print("  " .. k .. ": " .. tostring(v))
            end
        end
    end)

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