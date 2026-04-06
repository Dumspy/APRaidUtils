local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local function GetCurrentCharacterText()
    local currentCharacter = AP:GetPlayerCharacterInfo()
    if currentCharacter and currentCharacter.isMaxLevel then
        return "Current character: " .. AP:GetCharacterDisplayName(currentCharacter)
    end

    return "Current character is not max level and will not be stored."
end

local function GetRemindersModule()
    return AP:GetModule("Reminders", true)
end

local function GetAuraBuilderModule()
    return AP:GetModule("AuraBuilder", true)
end

local function GetM33kAurasStatusText()
    local Reminders = GetRemindersModule()
    if Reminders and Reminders.GetM33kAurasStatus then
        local status, msg = Reminders:GetM33kAurasStatus()
        if status == "missing" then
            return "|cffff4444M33kAuras is not installed. Reminders require M33kAuras.|r"
        elseif status == "missing_template" then
            return "|cffffaa44M33kAuras installed but reminder template is missing. Create it in the Reminders tab.|r"
        end
    end
    local AuraBuilder = GetAuraBuilderModule()
    if AuraBuilder and AuraBuilder:IsAvailable() then
        return "|cff44ff44M33kAuras is installed and ready.|r"
    end
    return "M33kAuras is not installed. Reminders require M33kAuras."
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
            id = "reminders",
            type = "group",
            name = "Reminders",
            order = 2,
            items = {
                {
                    id = "remindersIntro",
                    type = "description",
                    text = "Configure APRaidUtils reminder behavior. Reminders are imported as M33kAuras auras - customize their appearance via the APRaidUtils Reminder Template in M33kAuras.",
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
                    id = "m33kAurasStatus",
                    type = "description",
                    text = GetM33kAurasStatusText,
                    order = 2,
                },
            },
        },
        {
            id = "simc",
            type = "group",
            name = "SimulationCraft Exports",
            order = 10,
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
