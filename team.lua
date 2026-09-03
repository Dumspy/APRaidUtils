local AP = _G["APRaidUtils"]

local Team = {}
AP.Team = Team

local FOLLOW_BUTTON_NAME = "APTeamFollowButton"
local STATUS_STALE_SECONDS = 45
local STATUS_ROW_HEIGHT = 16
local MAX_STATUS_ROWS = 10 -- up to 8 boxes + Main and Alt headers

local GREEN = { 0.2, 0.9, 0.15 }
local RED = { 1.0, 0.25, 0.2 }
local ORANGE = { 1.0, 0.82, 0.0 }
local GRAY = { 0.7, 0.7, 0.7 }

local anchorFrame = nil
local warningAnchorFrame = nil
local followAnchorFrame = nil
local followButton = nil

-- name -> { mounted, following, dead, class, updatedAt }
local teamStatus = {}
-- sender full name -> announced main name (runtime only; re-announced on join)
local claimedMains = {}
local lastSentStatus = nil
local following = false
local lastMounted = nil
local lastDead = nil
local pendingFollowTarget = nil
local mountCheckPending = false

-- Anchor visibility changes hit protected frame APIs (EnableMouse) in the
-- shell, so skip them mid-combat; PLAYER_REGEN_ENABLED re-applies the right
-- state once combat ends.
local function SetAnchorVisibleSafe(key, visible)
    if InCombatLockdown() then
        return
    end

    if AP.APAnchor then
        AP.APAnchor:SetAnchorVisible(key, visible)
    end
end

local function NormalizeRealmForKey(realmName)
    if not realmName or realmName == "" then
        return ""
    end

    return realmName:gsub("[%s%-']", ""):lower()
end

local function ShortName(fullName)
    if not fullName then
        return nil
    end

    return (fullName:match("^([^%-]+)") or fullName)
end

local function OwnFullName()
    local name = UnitName("player")
    if not name or name == "" then
        return nil
    end

    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function NormalizeName(name)
    if AP.RosterManager and AP.RosterManager.NormalizePlayerName then
        return AP.RosterManager:NormalizePlayerName(name)
    end

    if not name then
        return nil
    end

    local short = ShortName(name)
    local realm = name:match("%-(.+)$")
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or ""
    end

    return short:lower() .. "-" .. NormalizeRealmForKey(realm)
end

local function GetSettings()
    if type(APRaidUtilsDB) ~= "table" or type(APRaidUtilsDB.profile) ~= "table" then
        return { enabled = false, isMain = false }
    end

    local settings = APRaidUtilsDB.profile.team
    if type(settings) ~= "table" then
        return { enabled = false, isMain = false }
    end

    return {
        enabled = settings.enabled == true,
        isMain = settings.isMain == true,
    }
end

local function GetMutableSettings()
    if type(APRaidUtilsDB) ~= "table" or type(APRaidUtilsDB.profile) ~= "table" then
        return nil
    end

    if type(APRaidUtilsDB.profile.team) ~= "table" then
        APRaidUtilsDB.profile.team = {}
    end

    return APRaidUtilsDB.profile.team
end

local function GetStatusChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function GetGroupLeaderName()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and rank == 0 then
                return name
            end
        end

        return nil
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return OwnFullName()
        end

        for i = 1, GetNumSubgroupMembers() do
            if UnitIsGroupLeader("party" .. i) then
                local name = UnitFullName("party" .. i)
                if not name then
                    name = UnitName("party" .. i)
                end

                return name
            end
        end
    end

    return nil
end

local function GetDetectedMainNames()
    -- Returns { [normalizedName] = displayName } for every box claiming to be
    -- the main: ourselves (when opted in) plus every claim received via the
    -- senders' status messages.
    local mains = {}

    if GetSettings().isMain then
        local own = OwnFullName()
        mains[NormalizeName(own)] = own
    end

    for _, mainName in pairs(claimedMains) do
        mains[NormalizeName(mainName)] = mainName
    end

    return mains
end

local function GetConfiguredMain()
    if GetSettings().isMain then
        return OwnFullName()
    end

    -- Unambiguous announcement wins over the leader fallback.
    local mains = GetDetectedMainNames()
    local count = 0
    local single
    for _, mainName in pairs(mains) do
        count = count + 1
        single = mainName
    end

    if count == 1 then
        return single
    end

    return GetGroupLeaderName()
end

local function IsTrustedSender(sender)
    if not sender then
        return false
    end

    local senderKey = NormalizeName(sender)

    local main = GetConfiguredMain()
    if main and senderKey == NormalizeName(main) then
        return true
    end

    local leader = GetGroupLeaderName()
    if leader and senderKey == NormalizeName(leader) then
        return true
    end

    return false
end

local function OwnStatus()
    local _, classToken = UnitClass("player")

    return {
        mounted = IsMounted() == true,
        following = following == true,
        dead = UnitIsDeadOrGhost("player") == true,
        class = classToken,
        -- Main claim rides the status message: one message instead of a
        -- separate announcement, so it cannot be independently throttled away.
        main = GetSettings().isMain and OwnFullName() or nil,
    }
end

local function GetClassColor(classToken)
    if not classToken then
        return unpack(GRAY)
    end

    local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not colors then
        return unpack(GRAY)
    end

    return colors.r, colors.g, colors.b
end

-- Status board display settings (right-click menu on the board anchor) ----

local DISPLAY_DEFAULTS = { fontSize = 12, rowHeight = 18 }

local function GetDisplaySettings()
    local settings = GetMutableSettings()
    if not settings or type(settings.display) ~= "table" then
        return DISPLAY_DEFAULTS
    end

    local display = settings.display
    return {
        fontSize = type(display.fontSize) == "number" and display.fontSize or DISPLAY_DEFAULTS.fontSize,
        rowHeight = type(display.rowHeight) == "number" and display.rowHeight or DISPLAY_DEFAULTS.rowHeight,
    }
end

local function GetMutableDisplaySettings()
    local settings = GetMutableSettings()
    if not settings then
        return nil
    end

    if type(settings.display) ~= "table" then
        settings.display = {}
    end

    local display = settings.display
    if type(display.fontSize) ~= "number" then
        display.fontSize = DISPLAY_DEFAULTS.fontSize
    end
    if type(display.rowHeight) ~= "number" then
        display.rowHeight = DISPLAY_DEFAULTS.rowHeight
    end

    return display
end

local function ApplyDisplaySettings()
    if not anchorFrame or not anchorFrame.rows then
        return
    end

    local display = GetDisplaySettings()

    for index, row in ipairs(anchorFrame.rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, -((index - 1) * display.rowHeight))
        row:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", 0, -((index - 1) * display.rowHeight))
        row:SetHeight(display.rowHeight)

        for _, fontString in ipairs({ row.HeaderText, row.NameText, row.MountText, row.FollowText, row.DeadText }) do
            local fontFile, _, fontFlags = fontString:GetFont()
            if fontFile then
                fontString:SetFont(fontFile, display.fontSize, fontFlags)
            end
        end
    end
end

local function CreateAnchorIfNeeded()
    if anchorFrame then
        return anchorFrame
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return nil
    end

    local function BuildStatusRow(frame, index)
        local row = CreateFrame("Frame", "$parentRow" .. index, frame, "BackdropTemplate")
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -((index - 1) * STATUS_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -((index - 1) * STATUS_ROW_HEIGHT))
        row:SetHeight(STATUS_ROW_HEIGHT)
        row:SetBackdrop({
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            tileSize = 64,
            tile = true,
        })
        row:SetBackdropColor(0, 0, 0, 0)
        row:Hide()

        local headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerText:SetPoint("LEFT", row, "LEFT", 6, 0)
        headerText:SetJustifyH("LEFT")
        row.HeaderText = headerText

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 16, 0)
        nameText:SetWidth(120)
        nameText:SetJustifyH("LEFT")
        row.NameText = nameText

        local mountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mountText:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
        mountText:SetJustifyH("LEFT")
        row.MountText = mountText

        local followText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        followText:SetPoint("LEFT", mountText, "RIGHT", 8, 0)
        followText:SetJustifyH("LEFT")
        row.FollowText = followText

        local deadText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        deadText:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
        deadText:SetJustifyH("LEFT")
        row.DeadText = deadText

        return row
    end

    anchorFrame = APAnchor:CreateContentAnchor("team", {
        scale = 1.0,
        maxWidth = 340,
        maxHeight = MAX_STATUS_ROWS * STATUS_ROW_HEIGHT,
        locked = false,
    }, function(frame)
        frame.rows = {}
        for i = 1, MAX_STATUS_ROWS do
            frame.rows[i] = BuildStatusRow(frame, i)
        end

        function frame:TeamUpdate(rows)
            for index, row in ipairs(self.rows) do
                local data = rows[index]
                if not data then
                    row:Hide()
                elseif data.type == "header" then
                    row:Show()
                    row:SetBackdropColor(0.14, 0.12, 0.05, 0.4)

                    row.HeaderText:Show()
                    row.HeaderText:SetText(data.text)
                    row.HeaderText:SetTextColor(unpack(ORANGE))

                    row.NameText:Hide()
                    row.MountText:Hide()
                    row.FollowText:Hide()
                    row.DeadText:Hide()
                else
                    row:Show()
                    row.HeaderText:Hide()

                    local cr, cg, cb = GetClassColor(data.class)

                    if data.fresh == false then
                        -- Lost contact: gray the row instead of dropping it.
                        row:SetBackdropColor(0.1, 0.1, 0.1, 0.35)
                        row.NameText:Show()
                        row.NameText:SetText(data.name)
                        row.NameText:SetTextColor(unpack(GRAY))
                        row.MountText:Hide()
                        row.FollowText:Hide()
                        row.DeadText:Show()
                        row.DeadText:SetText("Lost")
                        row.DeadText:SetTextColor(unpack(GRAY))
                    else
                        row:SetBackdropColor(cr * 0.35, cg * 0.35, cb * 0.35, 0.5)
                        row.NameText:Show()
                        row.NameText:SetText(data.name)
                        row.NameText:SetTextColor(cr, cg, cb, 1)

                        if data.dead then
                            row.MountText:Hide()
                            row.FollowText:Hide()
                            row.DeadText:Show()
                            row.DeadText:SetText("Dead")
                            row.DeadText:SetTextColor(unpack(RED))
                        else
                            row.DeadText:Hide()
                            row.MountText:Show()
                            row.MountText:SetText("Mounted")
                            row.MountText:SetTextColor(unpack(data.mounted and GREEN or RED))
                            row.FollowText:Show()
                            row.FollowText:SetText("Following")
                            row.FollowText:SetTextColor(unpack(data.following and GREEN or RED))
                        end
                    end
                end
            end
        end
    end)

    if not warningAnchorFrame then
        warningAnchorFrame = APAnchor:CreateAnchor("teamWarning", {
            text = "Multiple team mains detected!",
            fontSize = 16,
            maxWidth = 320,
            maxHeight = 90,
            font = "Friz Quadrata TT",
            colorR = 1.0,
            colorG = 0.25,
            colorB = 0.15,
            opacity = 1.0,
            locked = false,
        })
    end

    ApplyDisplaySettings()

    -- Right-click extras on the board anchor: text size and row height.
    APAnchor:RegisterRightClickMenu("team", function(panel, frame, key, settings, applySettings, setSettings, yOffset)
        local DF = LibStub("DetailsFramework-1.0", true) or _G.DetailsFramework
        if not DF then
            return
        end

        -- Make room below the built-in content-panel controls.
        panel:SetHeight(panel:GetHeight() + 130)

        local display = GetMutableDisplaySettings()

        local sizeLabel = DF:CreateLabel(panel, "Text Size", 10, "orange")
        sizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 18

        local sizeSlider = DF:CreateSlider(
            panel,
            200,
            16,
            8,
            24,
            1,
            display.fontSize,
            false,
            nil,
            "$parentTeamFontSizeSlider",
            "Size:"
        )
        sizeSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
        sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        sizeSlider:SetValue(display.fontSize)
        sizeSlider:SetValueChangedFunction(function(self)
            local mutable = GetMutableDisplaySettings()
            if mutable then
                mutable.fontSize = math.floor(self:GetValue() + 0.5)
                ApplyDisplaySettings()
            end
        end)
        yOffset = yOffset - 40

        local rowLabel = DF:CreateLabel(panel, "Row Height", 10, "orange")
        rowLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 18

        local rowSlider = DF:CreateSlider(
            panel,
            200,
            16,
            12,
            32,
            1,
            display.rowHeight,
            false,
            nil,
            "$parentTeamRowHeightSlider",
            "Height:"
        )
        rowSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
        rowSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        rowSlider:SetValue(display.rowHeight)
        rowSlider:SetValueChangedFunction(function(self)
            local mutable = GetMutableDisplaySettings()
            if mutable then
                mutable.rowHeight = math.floor(self:GetValue() + 0.5)
                ApplyDisplaySettings()
            end
        end)
    end)

    return anchorFrame
end

local function BuildRowData()
    local mainKey = nil

    local main = GetConfiguredMain()
    if main then
        mainKey = NormalizeName(main)
    end

    local function AddCharRow(rows, fullName, status)
        local key = NormalizeName(fullName)
        rows[#rows + 1] = {
            type = "char",
            name = ShortName(fullName) or "?",
            key = key,
            isMain = mainKey ~= nil and key == mainKey,
            class = status.class,
            mounted = status.mounted == true,
            following = status.following == true,
            dead = status.dead == true,
        }
    end

    local charRows = {}

    local selfFullName = OwnFullName()
    local selfKey = NormalizeName(selfFullName)
    AddCharRow(charRows, selfFullName, OwnStatus())

    local now = GetTime()
    for fullName, status in pairs(teamStatus) do
        if NormalizeName(fullName) ~= selfKey then
            AddCharRow(charRows, fullName, status)
            -- Mark stale entries; they stay on the board (grayed) instead of
            -- vanishing, since statuses are only broadcast on change.
            charRows[#charRows].fresh = (now - (status.updatedAt or 0)) < STATUS_STALE_SECONDS
        end
    end

    -- Main row first, then alphabetical.
    table.sort(charRows, function(a, b)
        if mainKey then
            if a.isMain and not b.isMain then
                return true
            elseif b.isMain and not a.isMain then
                return false
            end
        end

        return a.name:lower() < b.name:lower()
    end)

    -- Single header at the top with THIS box's role, so a quick glance
    -- tells you whether you are on the main or an alt.
    local rows = {}
    rows[#rows + 1] = { type = "header", text = GetSettings().isMain and "Main" or "Alt" }
    for _, row in ipairs(charRows) do
        rows[#rows + 1] = row
    end

    return rows
end

local function BuildMultiMainWarningText(mainNames)
    local display = {}
    for _, mainName in pairs(mainNames) do
        display[#display + 1] = ShortName(mainName)
    end

    table.sort(display, function(a, b)
        return a:lower() < b:lower()
    end)

    return "Multiple team mains detected!\n" .. table.concat(display, "\n")
end

local function RefreshAnchor()
    if not Team:IsEnabled() then
        return
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    CreateAnchorIfNeeded()

    if anchorFrame and anchorFrame.TeamUpdate then
        anchorFrame:TeamUpdate(BuildRowData())
    end

    SetAnchorVisibleSafe("team", IsInGroup() or IsInRaid())

    -- The follow button only exists on follower boxes; mains follow nobody.
    SetAnchorVisibleSafe("teamFollow", not GetSettings().isMain)

    -- Screen warning while more than one box claims to be the main.
    local mainNames = GetDetectedMainNames()
    local mainCount = 0
    for _ in pairs(mainNames) do
        mainCount = mainCount + 1
    end

    if mainCount > 1 then
        APAnchor:UpdateAnchorText("teamWarning", BuildMultiMainWarningText(mainNames))
        SetAnchorVisibleSafe("teamWarning", true)
    else
        SetAnchorVisibleSafe("teamWarning", false)
    end
end

local function BroadcastStatus(force)
    if not Team:IsEnabled() then
        return
    end

    local status = OwnStatus()

    if
        not force
        and lastSentStatus
        and lastSentStatus.mounted == status.mounted
        and lastSentStatus.following == status.following
        and lastSentStatus.dead == status.dead
    then
        return
    end

    local channel = GetStatusChannel()
    if not channel then
        return -- nothing sent; do not cache so the next change still sends
    end

    lastSentStatus = status

    AP.Comms:Broadcast("TEAM_STATUS", channel, status)
end

-- Re-check helper: mount state settles slightly after the events that
-- announce it, so re-compare once via a short one-shot timer (event-driven,
-- never a polling loop).
local function QueueMountCheck()
    if mountCheckPending then
        return
    end

    mountCheckPending = true
    C_Timer.After(0.5, function()
        mountCheckPending = false

        if not Team:IsEnabled() then
            return
        end

        local mounted = IsMounted()
        if mounted ~= lastMounted then
            lastMounted = mounted
            BroadcastStatus()
            RefreshAnchor()
        end
    end)
end

-- Follow button --------------------------------------------------------

-- A big clickable icon ("teamFollow" content anchor) that follows the main.
-- The click itself is the hardware event /follow requires, so the inner
-- secure button's macrotext simply points at the main and is kept up to date
-- automatically. /click APTeamFollowButton also works for keyboard users.

local FOLLOW_ICON = "Interface\\Icons\\Ability_Tracking"
local FOLLOW_BUTTON_SIZE = 72
local FOLLOW_LABEL_HEIGHT = 16

local function GetFollowCommandText(target)
    if not target or target == "" then
        return "/follow "
    end

    -- Same-realm mains follow by short name (most compatible); cross-realm
    -- teams need the full Name-Realm form.
    local short = ShortName(target)
    local realm = target:match("%-(.+)$")
    local ownRealm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()

    if realm and NormalizeRealmForKey(realm) ~= NormalizeRealmForKey(ownRealm or "") then
        return "/follow " .. target
    end

    return "/follow " .. short
end

local function ApplyFollowAttributes(target)
    local text = GetFollowCommandText(target)

    if InCombatLockdown() then
        pendingFollowTarget = target
        return
    end

    if not followButton then
        return
    end

    if followButton:GetAttribute("macrotext") ~= text then
        followButton:SetAttribute("macrotext", text)
        AP:Print("Follow button now targets: " .. (target and ShortName(target) or "(unknown - no main detected yet)"))
    end
end

local function UpdateFollowButton()
    if not Team:IsEnabled() then
        return
    end

    ApplyFollowAttributes(GetConfiguredMain())
end

local function CreateFollowAnchorIfNeeded()
    if followAnchorFrame then
        return followAnchorFrame
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return nil
    end

    followAnchorFrame = APAnchor:CreateContentAnchor("teamFollow", {
        scale = 1.0,
        maxWidth = FOLLOW_BUTTON_SIZE,
        maxHeight = FOLLOW_BUTTON_SIZE + FOLLOW_LABEL_HEIGHT,
        locked = false,
    }, function(frame)
        frame:SetSize(FOLLOW_BUTTON_SIZE, FOLLOW_BUTTON_SIZE + FOLLOW_LABEL_HEIGHT)

        followButton = CreateFrame("Button", FOLLOW_BUTTON_NAME, frame, "SecureActionButtonTemplate")
        followButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        followButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        followButton:SetHeight(FOLLOW_BUTTON_SIZE)
        followButton:RegisterForClicks("LeftButtonDown")
        followButton:SetAttribute("type", "macro")
        followButton:SetAttribute("macrotext", "/follow ")

        local icon = followButton:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints(followButton)
        icon:SetTexture(FOLLOW_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        followButton:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Team Follow", 1, 0.82, 0)
            GameTooltip:AddLine("Click to follow the team main.", 0.9, 0.9, 0.9)
            GameTooltip:AddLine("Target: " .. tostring(btn:GetAttribute("macrotext") or "?"), 0.6, 0.9, 0.6)
            GameTooltip:Show()
        end)
        followButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", followButton, "BOTTOMLEFT", 0, 2)
        label:SetPoint("TOPRIGHT", followButton, "BOTTOMRIGHT", 0, 2)
        label:SetHeight(FOLLOW_LABEL_HEIGHT)
        label:SetJustifyH("CENTER")
        label:SetText("Follow")
        label:SetTextColor(1, 0.82, 0, 1)

        -- In anchor edit mode the shell must receive the drag, so make the
        -- button non-interactive (same pattern sszorak uses for its cells).
        if APAnchor.RegisterVisibilityHook then
            APAnchor:RegisterVisibilityHook("teamFollow", function(editMode)
                if followButton then
                    followButton:EnableMouse(not editMode)
                end
            end)
        end
    end)

    return followAnchorFrame
end

-- Announce --------------------------------------------------------------

local function RequestTeamSync()
    if not Team:IsEnabled() then
        return
    end

    local channel = GetStatusChannel()
    if not channel then
        return
    end

    AP.Comms:Broadcast("TEAM_SYNC", channel, {})
end

-- Mount action ----------------------------------------------------------

local function ApplyMountAction(action)
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return
    end

    if action == "mount" then
        if not IsMounted() and C_MountJournal and C_MountJournal.SummonByID then
            C_MountJournal.SummonByID(0)
        end
    elseif action == "dismount" then
        if IsMounted() then
            Dismount()
        end
    end
end

-- Comm handlers ---------------------------------------------------------

function Team.OnCommStatus(sender, status)
    if not Team:IsEnabled() or type(status) ~= "table" then
        return
    end

    teamStatus[sender] = {
        mounted = status.mounted == true,
        following = status.following == true,
        dead = status.dead == true,
        class = status.class,
        updatedAt = GetTime(),
    }

    -- The sender's main claim rides its status message; every claim is
    -- recorded so all boxes can warn about conflicting mains.
    if type(status.main) == "string" and status.main ~= "" then
        if claimedMains[sender] ~= status.main then
            claimedMains[sender] = status.main
            UpdateFollowButton()
        end
    end

    RefreshAnchor()
end

function Team.OnCommSync(sender)
    if not Team:IsEnabled() then
        return
    end

    -- Stagger replies so a whole team answering at once does not flood comms.
    C_Timer.After(0.3 + math.random() * 0.6, function()
        BroadcastStatus(true)
    end)
end

function Team.OnCommMount(sender, data)
    if not Team:IsEnabled() or type(data) ~= "table" then
        return
    end

    if not IsTrustedSender(sender) then
        return
    end

    ApplyMountAction(data.action)
end

-- Event handlers --------------------------------------------------------

-- Coalesces bursts of GROUP_ROSTER_UPDATE (group formation fires it several
-- times) into one round of work so we stay well inside the comm throttle.
local rosterDebounceTimer = nil

function Team:OnRosterUpdate()
    if not self:IsEnabled() then
        return
    end

    if rosterDebounceTimer then
        return
    end

    rosterDebounceTimer = C_Timer.After(0.5, function()
        rosterDebounceTimer = nil
        Team:ProcessRosterUpdate()
    end)
end

function Team:ProcessRosterUpdate()
    if not self:IsEnabled() then
        return
    end

    -- Drop statuses of players who left the group.
    local present = {}
    local function MarkPresent(unit)
        if not UnitExists(unit) then
            return
        end

        local name = UnitFullName(unit) or UnitName(unit)
        if name then
            present[ShortName(name)] = true
        end
    end

    MarkPresent("player")

    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            MarkPresent("party" .. i)
        end

        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                MarkPresent("raid" .. i)
            end
        end
    end

    for fullName in pairs(teamStatus) do
        if not present[ShortName(fullName)] then
            teamStatus[fullName] = nil
        end
    end

    for sender in pairs(claimedMains) do
        if not present[ShortName(sender)] then
            claimedMains[sender] = nil
        end
    end

    UpdateFollowButton()
    BroadcastStatus(true)
    RefreshAnchor()
end

function Team:OnUnitFlags(unit)
    if not self:IsEnabled() or unit ~= "player" then
        return
    end

    QueueMountCheck()
end

function Team:OnSpellcastSucceeded(unit)
    if not self:IsEnabled() or unit ~= "player" then
        return
    end

    -- Mount and dismount are player spells; re-check once the state settles.
    QueueMountCheck()
end

function Team:OnCompanionUpdate()
    if not self:IsEnabled() then
        return
    end

    QueueMountCheck()
end

function Team:SetFollowing(value)
    if not self:IsEnabled() then
        return
    end

    value = value == true
    if following == value then
        return
    end

    following = value
    BroadcastStatus()
    RefreshAnchor()
end

function Team:OnChatMsgSystem(message)
    if not self:IsEnabled() or type(message) ~= "string" then
        return
    end

    if message:find("^You are now following") then
        self:SetFollowing(true)
    elseif message:find("^You are no longer following") or message:find("^You have lost") then
        self:SetFollowing(false)
    end
end

function Team:OnLifeStateChanged()
    if not self:IsEnabled() then
        return
    end

    local dead = UnitIsDeadOrGhost("player")
    if dead ~= lastDead then
        lastDead = dead
        BroadcastStatus()
        RefreshAnchor()
    end
end

function Team:OnPlayerRegenEnabled()
    if not self:IsEnabled() then
        return
    end

    if pendingFollowTarget then
        local target = pendingFollowTarget
        pendingFollowTarget = nil
        ApplyFollowAttributes(target)
    end

    BroadcastStatus(true)
    RefreshAnchor()
end

function Team:OnPlayerEnteringWorld()
    if not self:IsEnabled() then
        return
    end

    -- Re-sync after login/reload/zone change so late starters catch up.
    BroadcastStatus(true)
    RequestTeamSync()
    RefreshAnchor()
end

-- Team commands ---------------------------------------------------------

function Team:TeamMount(action)
    if not self:IsEnabled() then
        AP:Print("Enable the Multiboxing Team feature first.")
        return
    end

    action = action == "dismount" and "dismount" or "mount"

    -- Apply locally first, then tell the team. On the receiving side the
    -- command is only honored from the group leader or the main, so followers
    -- issuing this themselves still apply it here.
    ApplyMountAction(action)

    local channel = GetStatusChannel()
    if channel then
        AP.Comms:Broadcast("TEAM_MOUNT", channel, { action = action })
    end
end

-- Lifecycle -------------------------------------------------------------

-- Deferred so a toggle callback finishes before the tab rebuilds its
-- volatile menu widgets.
local function DeferOptionsRefresh()
    C_Timer.After(0, function()
        if AP.NotifyOptionsChanged then
            AP:NotifyOptionsChanged()
        end
    end)
end

function Team:IsEnabled()
    return GetSettings().enabled == true
end

function Team:SetEnabled(value)
    local settings = GetMutableSettings()
    if settings then
        settings.enabled = value == true
    end

    if value == true then
        self:Enable()
    else
        self:Disable()
    end

    DeferOptionsRefresh()
end

function Team:GetIsMain()
    return GetSettings().isMain == true
end

-- UI-facing accessors for the Multibox tab ------------------------------

function Team:GetFollowTarget()
    if not self:IsEnabled() then
        return nil
    end

    local target = GetConfiguredMain()
    if target and target ~= "" then
        return target
    end

    return nil
end

function Team:HasMultiMainConflict()
    if not self:IsEnabled() then
        return false
    end

    local mainCount = 0
    for _ in pairs(GetDetectedMainNames()) do
        mainCount = mainCount + 1
    end

    return mainCount > 1
end

function Team:SetIsMain(value)
    local settings = GetMutableSettings()
    if not settings then
        return
    end

    settings.isMain = value == true

    UpdateFollowButton()
    BroadcastStatus(true) -- claim rides the status message
    RefreshAnchor()

    -- Toggling between main and follower adds/removes the follow button.
    if value then
        SetAnchorVisibleSafe("teamFollow", false)
    else
        CreateFollowAnchorIfNeeded()
        SetAnchorVisibleSafe("teamFollow", true)
    end

    DeferOptionsRefresh()
end

function Team:Enable()
    if not self:IsEnabled() then
        return
    end

    if AP.Comms then
        AP.Comms:RegisterCallback("TEAM_STATUS", function(_, sender, _, data)
            Team.OnCommStatus(sender, data)
        end)
        AP.Comms:RegisterCallback("TEAM_SYNC", function(_, sender)
            Team.OnCommSync(sender)
        end)
        AP.Comms:RegisterCallback("TEAM_MOUNT", function(_, sender, _, data)
            Team.OnCommMount(sender, data)
        end)
    end

    AP:EnableFeatureEvents("team")

    lastMounted = IsMounted()
    lastDead = UnitIsDeadOrGhost("player")

    CreateAnchorIfNeeded()

    -- The follow button only makes sense on followers; mains follow nobody.
    if not GetSettings().isMain then
        CreateFollowAnchorIfNeeded()
        UpdateFollowButton()
    end

    -- Ask the team for their current statuses so late enablers catch up.
    BroadcastStatus(true)
    RequestTeamSync()
    RefreshAnchor()
end

function Team:Disable()
    AP:DisableFeatureEvents("team")

    if AP.APAnchor then
        SetAnchorVisibleSafe("team", false)
        SetAnchorVisibleSafe("teamWarning", false)
        SetAnchorVisibleSafe("teamFollow", false)
    end

    following = false
    lastSentStatus = nil
    pendingFollowTarget = nil
    teamStatus = {}
    claimedMains = {}
end

function Team:Restore()
    if self:IsEnabled() then
        self:Enable()
        return
    end
end

function Team:ToggleAnchors()
    if not self:IsEnabled() then
        return
    end

    local APAnchor = AP.APAnchor
    if not APAnchor then
        return
    end

    APAnchor:ToggleAllAnchors()
end

SlashCmdList["APTEAM"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "mount" or msg == "" then
        Team:TeamMount("mount")
    elseif msg == "dismount" then
        Team:TeamMount("dismount")
    elseif msg == "follow" then
        AP:Print("Follow target: " .. (Team:GetFollowTarget() or "none"))
        if followButton then
            AP:Print(
                "Follow button macro (click the button, or /click "
                    .. FOLLOW_BUTTON_NAME
                    .. "): "
                    .. tostring(followButton:GetAttribute("macrotext"))
            )
        end
    else
        AP:Print("Usage: /apteam [mount|dismount|follow]")
    end
end
SLASH_APTEAM1 = "/apteam"
