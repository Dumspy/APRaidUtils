local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local function GetCurrentCharacterText()
    local currentCharacter = AP:GetPlayerCharacterInfo()
    if currentCharacter and currentCharacter.isMaxLevel then
        return "Current character: " .. AP:GetCharacterDisplayName(currentCharacter)
    end

    return "Current character is not max level and will not be stored."
end

local function BuildCharacterItems()
    local items = {}

    for _, character in ipairs(AP:GetSimcCharacters()) do
        local characterKey = character.key
        items[#items + 1] = {
            id = "simcCharacter_" .. characterKey,
            type = "toggle",
            name = function()
                return AP:GetCharacterDisplayName(character)
            end,
            desc = "Refresh this character's latest SimulationCraft export on login or reload.",
            get = function()
                return AP:IsSimcCharacterEnabled(characterKey)
            end,
            set = function(value)
                AP:SetSimcCharacterEnabled(characterKey, value)
            end,
            order = #items + 1,
            ace = {
                width = "full",
            },
            df = {
                boxfirst = true,
            },
        }
    end

    if #items == 0 then
        items[1] = {
            id = "simcCharactersEmpty",
            type = "description",
            text = "No max-level characters have been discovered yet.",
            order = 1,
        }
    end

    return items
end

local function GetSections()
    return {
        {
            id = "simc",
            type = "group",
            name = "SimulationCraft Exports",
            order = 1,
            items = {
                {
                    id = "intro",
                    type = "description",
                    text = "Enable max-level characters here to refresh their latest SimulationCraft export on login or reload. Requires the Simulationcraft addon to be installed and enabled.",
                    order = 1,
                    surfaces = {
                        ace = true,
                        df = false,
                    },
                    ace = {
                        fontSize = "medium",
                    },
                },
                {
                    id = "currentCharacter",
                    type = "description",
                    text = GetCurrentCharacterText,
                    order = 2,
                    surfaces = {
                        ace = true,
                        df = false,
                    },
                },
                {
                    id = "characters",
                    type = "group",
                    name = "Max-Level Characters",
                    order = 10,
                    inline = true,
                    items = BuildCharacterItems,
                },
            },
        },
    }
end

AP.SettingsRegistry = {
    GetSections = GetSections,
    GetCurrentCharacterText = GetCurrentCharacterText,
}
