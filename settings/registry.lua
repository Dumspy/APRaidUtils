local AP = _G["APRaidUtils"]

local function GetLeadPassModule()
    return AP.LeadPassReminder
end

local function GetBreakTimerModule()
    return AP.BreakTimer
end

local function GetReadyCheckModule()
    return AP.ReadyCheck
end

local function GetTeamModule()
    return AP.Team
end

-- Items for the dedicated Multibox tab (ui/main.lua); not part of the
-- Settings tab surface.
local function GetMultiboxItems()
    return {
        {
            id = "teamEnabled",
            type = "toggle",
            name = "Enable Multiboxing Team",
            desc = "Team status anchor, team mount command and an auto-maintained follow macro. Install and enable this addon on every client of your team.",
            get = function()
                local module = GetTeamModule()
                return module and module:IsEnabled() or false
            end,
            set = function(value)
                local module = GetTeamModule()
                if module then
                    module:SetEnabled(value)
                end
            end,
            order = 1,
        },
        {
            id = "teamIsMain",
            type = "toggle",
            name = "This box is the main",
            desc = "Check this on exactly one client - the character your followers follow and whose mount commands the team obeys. If two boxes claim to be the main, a red warning appears on screen.",
            get = function()
                local module = GetTeamModule()
                return module and module:GetIsMain() or false
            end,
            set = function(value)
                local module = GetTeamModule()
                if module then
                    module:SetIsMain(value)
                end
            end,
            order = 2,
        },
    }
end

local function ToggleAllAnchors()
    if AP.APAnchor then
        AP.APAnchor:ToggleAllAnchors()
    end
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
                    name = "Enable Break Timer",
                    desc = "Track BigWigs and DBM breaks and show a countdown anchor, even when only group addon messages are available.",
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
            id = "readycheck",
            type = "group",
            name = "Ready Check",
            order = 4,
            items = {
                {
                    id = "readycheckEnabled",
                    type = "toggle",
                    name = "Enable Ready Check UI",
                    desc = "Pop up a panel during ready checks showing every raider's food, flask, Vantus rune, augment rune and raid buff status. The raid counts as ready when everyone in groups 1-4 (Mythic) or 1-6 (other difficulties) confirms; the result is printed to chat.",
                    get = function()
                        local module = GetReadyCheckModule()
                        return module and module:IsEnabled() or false
                    end,
                    set = function(value)
                        local module = GetReadyCheckModule()
                        if module then
                            module:SetEnabled(value)
                        end
                    end,
                    order = 1,
                },
                {
                    id = "readycheckCustomBuffIds",
                    type = "input",
                    name = "Custom Buff Spell IDs",
                    desc = "Comma or space separated spell IDs to check as an extra column on the ready check panel, e.g. 444257, 451366.",
                    get = function()
                        local module = GetReadyCheckModule()
                        return module and module:GetCustomBuffIds() or ""
                    end,
                    set = function(value)
                        local module = GetReadyCheckModule()
                        if module then
                            module:SetCustomBuffIds(value)
                        end
                    end,
                    order = 2,
                    df = {
                        width = 200,
                    },
                },
                {
                    id = "readycheckInfo",
                    type = "description",
                    text = "Raiders outside the counted groups (5-8 on Mythic) are shown greyed under a divider at the bottom of the panel. Hover a row for details on which buffs matched.",
                    order = 3,
                },
            },
        },
        {
            id = "sszorak",
            type = "group",
            name = "Sszorak Caller Helper",
            order = 5,
            items = {
                {
                    id = "sszorakEnabled",
                    type = "toggle",
                    name = "Enable Sszorak Caller Helper",
                    desc = "Show the octagon directional helper. Right-click a direction out of combat to assign its world marker; left-click up to three directions to queue calls - the bar below shows the opposite markers in call order.",
                    get = function()
                        local module = AP.Sszorak
                        return module and module:IsEnabled() or false
                    end,
                    set = function(value)
                        local module = AP.Sszorak
                        if module then
                            module:SetEnabled(value)
                        end
                    end,
                    order = 1,
                },
                {
                    id = "sszorakToggleConfig",
                    type = "execute",
                    name = "Toggle Marker Config",
                    desc = "Show or hide the octagon out of combat so you can assign world markers. It also appears automatically inside the Sszorak encounter and during anchor edit mode.",
                    func = function()
                        local module = AP.Sszorak
                        if module then
                            module:ToggleConfig()
                        end
                    end,
                    order = 2,
                },
            },
        },
    }
end

AP.SettingsRegistry = {
    GetSections = GetSections,
    GetMultiboxItems = GetMultiboxItems,
}
