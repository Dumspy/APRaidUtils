local AP = _G["APRaidUtils"]

local function GetCurrentCharacterText()
    local currentCharacter = AP:GetPlayerCharacterInfo()
    if currentCharacter and currentCharacter.isMaxLevel then
        return "Current character: " .. AP:GetCharacterDisplayName(currentCharacter)
    end

    return "Current character is not max level and will not be stored."
end

local function GetRemindersModule()
    return AP.Reminders
end

local function GetAuraBuilderModule()
    return AP.AuraBuilder
end

local function GetLeadPassModule()
    return AP.LeadPassReminder
end

local function GetBreakTimerModule()
    return AP.BreakTimer
end

local function ToggleAllAnchors()
    if AP.LeadPassReminder and AP.LeadPassReminder.OnAddonLoaded then
        AP.LeadPassReminder:OnAddonLoaded()
    end

    if AP.BreakTimer and AP.BreakTimer.OnAddonLoaded then
        AP.BreakTimer:OnAddonLoaded()
    end

    if AP.APAnchor then
        AP.APAnchor:ToggleAllAnchors()
    end
end

local function GetM33kAurasStatusText()
    local Reminders = GetRemindersModule()
    if Reminders and Reminders.GetM33kAurasStatus then
        local status = Reminders:GetM33kAurasStatus()
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
            desc = "Refresh this character's latest SimulationCraft export on login, reload, equipped gear changes, and applied talent changes.",
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
            id = "leadpass",
            type = "group",
            name = "Mythic Lead Pass",
            order = 1,
            items = {
                {
                    id = "leadpassEnabled",
                    type = "toggle",
                    name = "Enable Mythic Lead Pass Reminder",
                    desc = "Show a reminder when you are the raid leader in group 5-8 on Mythic difficulty.",
                    get = function()
                        local module = GetLeadPassModule()
                        return module and module:IsEnabled() or false
                    end,
                    set = function(value)
                        local module = GetLeadPassModule()
                        if module then
                            module:SetEnabled(value)
                        end
                    end,
                    order = 1,
                },
                {
                    id = "leadpassInfo",
                    type = "description",
                    text = "Use the shared Anchors button below to move and style all APRaidUtils anchors.",
                    order = 2,
                },
            },
        },
        {
            id = "breaktimer",
            type = "group",
            name = "Break Timer",
            order = 2,
            items = {
                {
                    id = "breaktimerEnabled",
                    type = "toggle",
                    name = "Enable Break Timer Anchor",
                    desc = "Show a break timer anchor for BigWigs and DBM breaks, even when only group addon messages are available.",
                    get = function()
                        local module = GetBreakTimerModule()
                        return module and module:IsEnabled() or false
                    end,
                    set = function(value)
                        local module = GetBreakTimerModule()
                        if module then
                            module:SetEnabled(value)
                        end
                    end,
                    order = 1,
                },
                {
                    id = "breaktimerShowCountdown",
                    type = "toggle",
                    name = "Show Countdown",
                    desc = "Show the remaining break duration as a countdown.",
                    get = function()
                        local module = GetBreakTimerModule()
                        return module and module:GetShowCountdown() or false
                    end,
                    set = function(value)
                        local module = GetBreakTimerModule()
                        if module then
                            module:SetShowCountdown(value)
                        end
                    end,
                    order = 2,
                },
                {
                    id = "breaktimerShowEndTime",
                    type = "toggle",
                    name = "Show End Time",
                    desc = "Show the exact time when the break ends in HH:MM:SS format.",
                    get = function()
                        local module = GetBreakTimerModule()
                        return module and module:GetShowEndTime() or false
                    end,
                    set = function(value)
                        local module = GetBreakTimerModule()
                        if module then
                            module:SetShowEndTime(value)
                        end
                    end,
                    order = 3,
                },
                {
                    id = "breaktimerInfo",
                    type = "description",
                    text = "Use the shared Anchors button below to move and style all APRaidUtils anchors.",
                    order = 4,
                },
            },
        },
        {
            id = "anchors",
            type = "group",
            name = "Anchors",
            order = 3,
            items = {
                {
                    id = "toggleAllAnchors",
                    type = "execute",
                    name = "Toggle Anchor Position",
                    desc = "Show or hide movable anchors for all APRaidUtils features. Right-click an anchor for settings.",
                    func = ToggleAllAnchors,
                    order = 1,
                    df = {
                        width = 200,
                    },
                },
            },
        },
        {
            id = "reminders",
            type = "group",
            name = "Reminders",
            order = 4,
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
                    text = "Enable max-level characters here to refresh their latest SimulationCraft export on login, reload, equipped gear changes, and applied talent changes. Requires the Simulationcraft addon to be installed and enabled.",
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
