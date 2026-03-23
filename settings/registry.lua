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

local function IsReminderPreviewModeEnabled()
    local reminders = GetRemindersModule()
    return reminders and reminders.IsPreviewMode and reminders:IsPreviewMode() or false
end

local function SetReminderPreviewMode(enabled)
    local reminders = GetRemindersModule()
    if reminders and reminders.SetPreviewMode then
        reminders:SetPreviewMode(enabled)
    end
end

local function ToggleReminderPreviewMode()
    SetReminderPreviewMode(not IsReminderPreviewModeEnabled())
end

local function IsRemindersEnabled()
    local reminders = GetRemindersModule()
    return reminders and reminders.IsEnabledForProfile and reminders:IsEnabledForProfile() or false
end

local function SetRemindersEnabled(value)
    local reminders = GetRemindersModule()
    if reminders and reminders.SetEnabledForProfile then
        reminders:SetEnabledForProfile(value)
    end
end

local function GetReminderTextSizeValue()
    local reminders = GetRemindersModule()
    local storage = reminders and reminders.GetStorage and reminders:GetStorage() or nil
    return storage and storage.display and storage.display.textSize or 28
end

local function SetReminderTextSizeValue(value)
    local reminders = GetRemindersModule()
    local storage = reminders and reminders.GetStorage and reminders:GetStorage() or nil
    if storage and storage.display then
        storage.display.textSize = value
        if reminders.RefreshActiveReminderDisplay then
            reminders:RefreshActiveReminderDisplay()
        end
        if reminders.IsPreviewMode and reminders:IsPreviewMode() and reminders.SetPreviewMode then
            reminders:SetPreviewMode(true)
        end
        AP:NotifyOptionsChanged()
    end
end

local function GetReminderMaxVisibleValue()
    local reminders = GetRemindersModule()
    local storage = reminders and reminders.GetStorage and reminders:GetStorage() or nil
    return storage and storage.display and storage.display.maxVisible or 3
end

local function SetReminderMaxVisibleValue(value)
    local reminders = GetRemindersModule()
    local storage = reminders and reminders.GetStorage and reminders:GetStorage() or nil
    if storage and storage.display then
        storage.display.maxVisible = value
        if reminders.RefreshActiveReminderDisplay then
            reminders:RefreshActiveReminderDisplay()
        end
        if reminders.IsPreviewMode and reminders:IsPreviewMode() and reminders.SetPreviewMode then
            reminders:SetPreviewMode(true)
        end
        AP:NotifyOptionsChanged()
    end
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
                    text = "Configure APRaidUtils reminder behavior and use preview mode to position the runtime reminder anchor.",
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
                    id = "remindersEnabled",
                    type = "toggle",
                    name = "Enable reminders",
                    desc = "Turn APRaidUtils timer reminders on or off.",
                    get = IsRemindersEnabled,
                    set = SetRemindersEnabled,
                    order = 2,
                    ace = {
                        width = "full",
                    },
                    df = {
                        boxfirst = true,
                    },
                },
                {
                    id = "remindersPreviewDescription",
                    type = "description",
                    text = function()
                        return IsReminderPreviewModeEnabled() and "Preview mode is active. Drag the on-screen anchor, then hide preview when finished." or "Preview mode is off."
                    end,
                    order = 3,
                },
                {
                    id = "remindersPreviewToggle",
                    type = "execute",
                    name = function()
                        return IsReminderPreviewModeEnabled() and "Hide Preview" or "Show Preview"
                    end,
                    desc = "Show example reminder rows so you can position the reminder anchor.",
                    func = ToggleReminderPreviewMode,
                    order = 4,
                    df = {
                        width = 180,
                    },
                },
                {
                    id = "remindersTextSizeSlider",
                    type = "range",
                    name = "Text size",
                    desc = "Adjust reminder text size.",
                    min = 12,
                    max = 48,
                    step = 1,
                    get = GetReminderTextSizeValue,
                    set = SetReminderTextSizeValue,
                    order = 5,
                    ace = {
                        width = "double",
                    },
                    df = {
                        usedecimals = false,
                        width = 280,
                    },
                },
                {
                    id = "remindersTextSizeSpacer",
                    type = "description",
                    text = "",
                    order = 6,
                },
                {
                    id = "remindersMaxVisibleSlider",
                    type = "range",
                    name = "Max visible reminders",
                    desc = "Limit how many reminders can be shown at once.",
                    min = 1,
                    max = 10,
                    step = 1,
                    get = GetReminderMaxVisibleValue,
                    set = SetReminderMaxVisibleValue,
                    order = 8,
                    ace = {
                        width = "double",
                    },
                    df = {
                        usedecimals = false,
                        width = 280,
                    },
                },
                {
                    id = "remindersMaxVisibleSpacer1",
                    type = "description",
                    text = "",
                    order = 8,
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
