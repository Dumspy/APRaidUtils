local AP = _G["APRaidUtils"]

local function GetLeadPassModule()
    return AP.LeadPassReminder
end

local function GetBreakTimerModule()
    return AP.BreakTimer
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
            id = "sszorak",
            type = "group",
            name = "Sszorak Caller Helper",
            order = 4,
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
}
