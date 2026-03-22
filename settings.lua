local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function GetCharacterToggleOptions()
    local args = {}
    local order = 1

    for _, character in ipairs(AP:GetSimcCharacters()) do
        local characterKey = character.key
        args[characterKey] = {
            type = "toggle",
            name = AP:GetCharacterDisplayName(character),
            desc = "Refresh this character's latest SimulationCraft export on login or reload.",
            width = "full",
            order = order,
            get = function()
                return AP:IsSimcCharacterEnabled(characterKey)
            end,
            set = function(_, value)
                AP:SetSimcCharacterEnabled(characterKey, value)
            end,
        }
        order = order + 1
    end

    if order == 1 then
        args.none = {
            type = "description",
            name = "No max-level characters have been discovered yet.",
            order = order,
        }
    end

    return args
end

function APRaidUtils:BuildOptionsTable()
    local currentCharacter = self:GetPlayerCharacterInfo()
    local currentCharacterText = "Current character is not max level and will not be stored."

    if currentCharacter and currentCharacter.isMaxLevel then
        currentCharacterText = "Current character: " .. self:GetCharacterDisplayName(currentCharacter)
    end

    return {
        type = "group",
        name = "APRaidUtils",
        childGroups = "tree",
        args = {
            simc = {
                type = "group",
                name = "SimulationCraft Exports",
                order = 1,
                args = {
                    intro = {
                        type = "description",
                        name = "Enable max-level characters here to refresh their latest SimulationCraft export on login or reload. Requires the Simulationcraft addon to be installed and enabled.",
                        order = 1,
                        fontSize = "medium",
                    },
                    currentCharacter = {
                        type = "description",
                        name = currentCharacterText,
                        order = 2,
                    },
                    openBrowser = {
                        type = "execute",
                        name = "Open Saved Exports",
                        order = 3,
                        func = function()
                            local simcExport = AP:GetModule("SimcExport", true)
                            if simcExport and simcExport.ShowUI then
                                simcExport:ShowUI()
                            end
                        end,
                    },
                    captureCurrent = {
                        type = "execute",
                        name = "Capture Current Character",
                        order = 4,
                        disabled = function()
                            local character = AP:GetPlayerCharacterInfo()
                            return not character or not character.isMaxLevel
                        end,
                        func = function()
                            local simcExport = AP:GetModule("SimcExport", true)
                            if simcExport and simcExport.ManualCapture then
                                simcExport:ManualCapture()
                            end
                        end,
                    },
                    characters = {
                        type = "group",
                        name = "Max-Level Characters",
                        inline = true,
                        order = 10,
                        args = GetCharacterToggleOptions(),
                    },
                },
            },
        },
    }
end

function APRaidUtils:SetupOptions()
    AceConfig:RegisterOptionsTable("APRaidUtils", function()
        return self:BuildOptionsTable()
    end)

    self.optionsFrame, self.optionsCategory = AceConfigDialog:AddToBlizOptions("APRaidUtils", "APRaidUtils")
end

function APRaidUtils:OpenSettings()
    if self.optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.optionsCategory)
        return
    end

    if self.optionsFrame and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
end
