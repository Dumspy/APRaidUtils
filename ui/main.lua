local AP = _G["APRaidUtils"]

local mainWindow
local mainTabs
local rosterInputEditor
local bossTeamDropdown
local selectedRosterSetId -- pending dropdown choice (runtime only)
local rosterStatusLabel
local rosterPreviewScrollBox
local versionsTab
local versionsStatusLabel
local versionsResultsScrollBox
local settingsTab
local settingsTabRefreshBase
local multiboxTab
local multiboxStatusLabel

local CONTENT_WIDTH = 1020
local BODY_TOP_OFFSET = -90
local FULL_CONTENT_WIDTH = 1156
local ROSTER_INPUT_HEIGHT = 126
local ROSTER_PREVIEW_ROW_HEIGHT = 20
local VERSION_ROW_HEIGHT = 22

local versionColumns = {
    { key = "name", label = "Name", width = 240, align = "LEFT" },
    { key = "BigWigs", label = "BigWigs", width = 149, align = "CENTER" },
    { key = "DBM", label = "DBM", width = 149, align = "CENTER" },
    { key = "MRT", label = "MRT", width = 149, align = "CENTER" },
    { key = "NS", label = "NS", width = 149, align = "CENTER" },
}

local tabList = {
    { name = "Roster", text = "Roster" },
    { name = "Versions", text = "Versions" },
    { name = "Multibox", text = "Multibox" },
    { name = "Settings", text = "Settings" },
}

local function GetFramework()
    return LibStub("DetailsFramework-1.0", true) or _G.DetailsFramework
end

local function UpdateWrappedLabel(label, text, width)
    local widget = label.widget or label.label or label
    widget:SetWidth(width)
    if widget.SetWordWrap then
        widget:SetWordWrap(true)
    end
    widget:SetText(text)
    widget:SetHeight(widget:GetStringHeight() + 4)
end

local function CreateWrappedText(parent, text, anchor, offsetY, width, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -12)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetTextColor(r or 0.85, g or 0.85, b or 0.85, 1)
    UpdateWrappedLabel(label, text, width or CONTENT_WIDTH)
    return label
end

local function StyleCodeEditor(framework, editor)
    editor:SetBackdrop({
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })
    editor:SetBackdropBorderColor(0, 0, 0, 1)
    editor:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    if editor.Center then
        editor.Center:SetColorTexture(0.1, 0.1, 0.1, 0.834)
    end

    if editor.editbox then
        editor.editbox:SetBackdrop(nil)
        editor.editbox:SetTextInsets(8, 8, 8, 8)
    end

    if editor.scroll then
        framework:ReskinSlider(editor.scroll)
    end
end

local function StyleInputEditor(framework, editor)
    StyleCodeEditor(framework, editor)

    editor:SetScript("OnMouseDown", function()
        editor:SetFocus()
    end)

    if editor.editbox then
        editor.editbox:SetFontObject("ChatFontNormal")
        editor.editbox:SetTextColor(1, 1, 1, 1)
        editor.editbox:SetCountInvisibleLetters(false)

        if editor.editbox.SetCursorColor then
            editor.editbox:SetCursorColor(1, 0.82, 0, 1)
        end

        if editor.editbox.SetHighlightColor then
            editor.editbox:SetHighlightColor(1, 0.82, 0, 0.35)
        end

        editor.editbox:HookScript("OnMouseDown", function(self)
            self:SetFocus()
        end)
    end

    if editor.scroll then
        editor.scroll:HookScript("OnMouseUp", function()
            editor:SetFocus()
        end)
    end

    editor:Enable()
end

local function CreateBodyAnchor(parent)
    local anchor = CreateFrame("Frame", nil, parent)
    anchor:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, BODY_TOP_OFFSET)
    anchor:SetSize(1, 1)
    return anchor
end

local function CreateSectionLabel(parent, anchor, text, offsetY)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, offsetY or 0)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0, 1)
    return label
end

local function GetRosterManager()
    return AP.RosterManager
end

local function GetRosterInputText()
    if not rosterInputEditor then
        return ""
    end

    return strtrim(rosterInputEditor:GetText() or "")
end

local function SetRosterStatus(text, r, g, b)
    if not rosterStatusLabel then
        return
    end

    UpdateWrappedLabel(rosterStatusLabel, text or "", FULL_CONTENT_WIDTH)
    rosterStatusLabel:SetTextColor(r or 0.85, g or 0.85, b or 0.85, 1)
end

-- DF scrollboxes can end up with LineAmount > #Frames (line creation inside
-- OnSizeChanged is xpcall'd and its failure swallowed, leaving the desync
-- unhealable). Frames is append-only, so a missing index is always #Frames + 1;
-- create it on demand and re-fetch via GetLine so it is marked _InUse.
local function GetOrCreateScrollLine(scrollBox, lineIndex, createLineFunc)
    local line = scrollBox:GetLine(lineIndex)
    if not line and lineIndex == scrollBox:GetNumFramesCreated() + 1 then
        scrollBox:CreateLine(createLineFunc)
        line = scrollBox:GetLine(lineIndex)
    end
    return line
end

local function CreateRosterPreviewLine(self, index)
    local line = CreateFrame("Frame", "$parentLine" .. index, self, "BackdropTemplate")
    line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * ROSTER_PREVIEW_ROW_HEIGHT) - 1)
    line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -18, -((index - 1) * ROSTER_PREVIEW_ROW_HEIGHT) - 1)
    line:SetHeight(ROSTER_PREVIEW_ROW_HEIGHT)
    line:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })

    line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.Text:SetPoint("LEFT", line, "LEFT", 8, 0)
    line.Text:SetPoint("RIGHT", line, "RIGHT", -8, 0)
    line.Text:SetJustifyH("LEFT")
    line.Text:SetJustifyV("MIDDLE")

    return line
end

local function RefreshRosterPreviewLines(scrollBox, data, offset, totalLines)
    for lineIndex = 1, totalLines do
        local row = data[lineIndex + offset]
        if row then
            local line = GetOrCreateScrollLine(scrollBox, lineIndex, CreateRosterPreviewLine)
            if not line then
                return
            end
            line.Text:SetText(row.text or "")

            if row.kind == "section" then
                line.Text:SetFontObject("GameFontNormalSmall")
                line.Text:SetTextColor(1, 0.82, 0, 1)
                line:SetBackdropColor(0.14, 0.12, 0.05, 0.45)
            elseif row.kind == "success" then
                line.Text:SetFontObject("GameFontHighlightSmall")
                line.Text:SetTextColor(0.35, 1, 0.35, 1)
                line:SetBackdropColor(0.05, 0.12, 0.05, 0.25)
            elseif row.kind == "spacer" then
                line.Text:SetFontObject("GameFontHighlightSmall")
                line.Text:SetTextColor(1, 1, 1, 0)
                line:SetBackdropColor(0, 0, 0, 0)
            else
                line.Text:SetFontObject("GameFontHighlightSmall")
                line.Text:SetTextColor(0.9, 0.9, 0.9, 1)
                line:SetBackdropColor(0.08, 0.08, 0.1, 0.2)
            end
        end
    end
end

local function SetRosterPreviewRows(rows)
    if not rosterPreviewScrollBox then
        return
    end

    rosterPreviewScrollBox:SetData(rows or {})
    rosterPreviewScrollBox:Refresh()
end

local function SetDefaultRosterPreviewRows(text)
    SetRosterPreviewRows({
        { text = "  " .. (text or "Pick a saved boss team to preview invites and moves."), kind = "success" },
    })
end

local function BuildRosterPreviewRows(preview)
    local rows = {}

    local function AddSection(text)
        rows[#rows + 1] = { text = text, kind = "section" }
    end

    local function AddSpacer()
        rows[#rows + 1] = { text = "", kind = "spacer" }
    end

    local function AddEntries(items, emptyText)
        if #items == 0 then
            rows[#rows + 1] = { text = "  " .. emptyText, kind = "success" }
            return
        end

        for _, item in ipairs(items) do
            rows[#rows + 1] = { text = "  • " .. item, kind = "entry" }
        end
    end

    AddSection("Missing Players (Will Invite)")
    AddEntries(preview.missing or {}, "All roster members are in the raid")
    AddSpacer()

    AddSection("Roster Members to Move Back (7/8 -> 1-4)")
    AddEntries(preview.toMoveIn or {}, "All roster members are in correct groups")
    AddSpacer()

    AddSection("Non-Roster Members to Move Out (1-4 -> 7/8)")
    AddEntries(preview.toMoveOut or {}, "No extra players to move")

    return rows
end

local function UpdateRosterPreview(updateStatus)
    local rosterManager = GetRosterManager()
    if not rosterManager then
        AP:Print("Roster manager is unavailable.")
        return false
    end

    local preview, errorMessage = rosterManager:GetRosterPreview(GetRosterInputText())
    if not preview then
        SetDefaultRosterPreviewRows("Preview will appear here after you pick a saved boss team.")
        if updateStatus then
            SetRosterStatus(errorMessage or "Error: No roster provided", 1, 0, 0)
        end
        return false
    end

    SetRosterPreviewRows(BuildRosterPreviewRows(preview))

    if updateStatus then
        SetRosterStatus(
            string.format(
                "Preview: %d to invite, %d to move in, %d to move out",
                #preview.missing,
                #preview.toMoveIn,
                #preview.toMoveOut
            ),
            0.8,
            0.8,
            1
        )
    end

    return true, preview
end

local function PreviewRosterFromTab()
    UpdateRosterPreview(true)
end

local function ProcessRosterFromTab()
    local rosterManager = GetRosterManager()
    if not rosterManager then
        AP:Print("Roster manager is unavailable.")
        return
    end

    local result, success = rosterManager:ProcessRoster(GetRosterInputText())
    SetRosterStatus(result, success and 0 or 1, success and 1 or 0, 0)
    UpdateRosterPreview(false)
end

local function InviteRosterFromTab()
    local rosterManager = GetRosterManager()
    if not rosterManager then
        AP:Print("Roster manager is unavailable.")
        return
    end

    local result, success = rosterManager:InviteOnly(GetRosterInputText())
    SetRosterStatus(result, success and 0 or 1, success and 1 or 0, 0)
    UpdateRosterPreview(false)
end

local function MoveRosterFromTab()
    local rosterManager = GetRosterManager()
    if not rosterManager then
        AP:Print("Roster manager is unavailable.")
        return
    end

    local result, success = rosterManager:MoveOnly(GetRosterInputText())
    SetRosterStatus(result, success and 0 or 1, success and 1 or 0, 0)
    UpdateRosterPreview(false)
end

local function CreateVersionColumnText(parent, column, offset, fontObject, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    local horizontalPadding = column.align == "LEFT" and 8 or 0
    text:SetPoint("LEFT", parent, "LEFT", offset + horizontalPadding, 0)
    text:SetWidth(column.width - horizontalPadding)
    text:SetJustifyH(column.align)
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(r or 1, g or 1, b or 1, 1)
    return text
end

local function CreateVersionsLine(self, index)
    local line = CreateFrame("Button", "$parentLine" .. index, self, "BackdropTemplate")
    line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * VERSION_ROW_HEIGHT) - 1)
    line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -18, -((index - 1) * VERSION_ROW_HEIGHT) - 1)
    line:SetHeight(VERSION_ROW_HEIGHT)
    line:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })

    line.Columns = {}

    local offset = 0
    for _, column in ipairs(versionColumns) do
        line.Columns[column.key] = CreateVersionColumnText(line, column, offset)
        offset = offset + column.width
    end

    return line
end

local function RefreshVersionsLines(scrollBox, data, offset, totalLines)
    local playerName = UnitName("player") or "Player"

    for lineIndex = 1, totalLines do
        local dataIndex = lineIndex + offset
        local row = data[dataIndex]
        if row then
            local line = GetOrCreateScrollLine(scrollBox, lineIndex, CreateVersionsLine)
            if not line then
                return
            end
            local isPlayer = row.name == playerName

            line:SetBackdropColor(
                isPlayer and 0.12 or 0.08,
                isPlayer and 0.16 or 0.08,
                isPlayer and 0.1 or 0.1,
                isPlayer and 0.55 or 0.35
            )

            local nameText = isPlayer and (row.name .. " (You)") or row.name
            line.Columns.name:SetText(nameText)
            line.Columns.name:SetTextColor(isPlayer and 0 or 1, isPlayer and 1 or 1, isPlayer and 0 or 1, 1)

            for _, column in ipairs(versionColumns) do
                if column.key ~= "name" then
                    line.Columns[column.key]:SetText(tostring((row.versions and row.versions[column.key]) or "-"))
                    line.Columns[column.key]:SetTextColor(1, 1, 1, 1)
                end
            end
        end
    end
end

local function RequestVersionCheckFromTab()
    local versionChecker = AP.VersionChecker
    if versionChecker and versionChecker.RequestVersionCheck then
        versionChecker:RequestVersionCheck()
        return
    end

    AP:Print("Version checker is unavailable.")
end
local function BuildRosterTab(framework, parent)
    local anchor = CreateBodyAnchor(parent)

    -- Saved boss teams: imported from multi-boss exports (EncounterID blocks)
    -- and persisted in APRaidUtilsDB.profile.rosterSets across sessions. The
    -- dropdown only picks a team; the Load Team button activates it.
    local teamsLabel = CreateSectionLabel(parent, anchor, "Saved Boss Teams")

    local rosterManager = GetRosterManager()
    local activeSet = rosterManager and rosterManager.GetActiveRosterSet and rosterManager:GetActiveRosterSet()
    selectedRosterSetId = activeSet and activeSet.encounterId or nil

    bossTeamDropdown = framework:CreateDropDown(
        parent,
        function()
            local saved = rosterManager and rosterManager.GetSavedRosterSets and rosterManager:GetSavedRosterSets()
                or {}

            if #saved == 0 then
                return {
                    {
                        value = "empty",
                        label = "No saved teams - paste an export and click Import",
                        color = { 0.6, 0.6, 0.6, 1 },
                    },
                }
            end

            local options = {}
            for _, set in ipairs(saved) do
                local encounterId = set.encounterId
                options[#options + 1] = {
                    value = encounterId,
                    label = string.format("%s (%s)", set.name, set.difficulty),
                    selected = encounterId == selectedRosterSetId,
                    onclick = function()
                        selectedRosterSetId = encounterId
                    end,
                }
            end
            return options
        end,
        selectedRosterSetId,
        300,
        20,
        nil,
        "$parentBossTeamDropdown",
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    bossTeamDropdown:SetPoint("TOPLEFT", teamsLabel, "BOTTOMLEFT", 0, -6)

    local loadTeamButton = framework:CreateButton(parent, function()
        local currentManager = GetRosterManager()
        if not currentManager then
            AP:Print("Roster manager is unavailable.")
            return
        end

        if not selectedRosterSetId then
            SetRosterStatus("Pick a team in the dropdown first.", 1, 0.82, 0)
            return
        end

        for _, set in ipairs(currentManager:GetSavedRosterSets()) do
            if set.encounterId == selectedRosterSetId then
                if currentManager.SetActiveRosterSet then
                    currentManager:SetActiveRosterSet(set.encounterId)
                end
                UpdateRosterPreview(true)
                local playerCount = select(2, set.players:gsub("%S+", "")) + 1
                SetRosterStatus(
                    string.format("Loaded team: %s (%s, %d players)", set.name, set.difficulty, playerCount),
                    0.4,
                    1,
                    0.4
                )
                return
            end
        end

        SetRosterStatus("Error: Selected team no longer exists - re-import the export.", 1, 0, 0)
    end, 110, 20, "Load Team")
    loadTeamButton:SetPoint("TOPLEFT", bossTeamDropdown.widget, "BOTTOMLEFT", 0, -8)
    loadTeamButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local clearTeamButton = framework:CreateButton(parent, function()
        local currentManager = GetRosterManager()
        if currentManager and currentManager.SetActiveRosterSet then
            currentManager:SetActiveRosterSet(nil)
        end
        SetDefaultRosterPreviewRows()
        SetRosterStatus("Loaded team cleared.", 0.8, 0.8, 1)
    end, 140, 20, "Clear Loaded Team")
    clearTeamButton:SetPoint("LEFT", loadTeamButton.widget, "RIGHT", 10, 0)
    clearTeamButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local importButton = framework:CreateButton(parent, function()
        local currentManager = GetRosterManager()
        if not currentManager or not currentManager.ImportRosterSets then
            AP:Print("Roster manager is unavailable.")
            return
        end

        local saved, added, updated = currentManager:ImportRosterSets(GetRosterInputText())
        if not saved then
            SetRosterStatus(added or "Error: Import failed", 1, 0, 0)
            return
        end

        SetRosterStatus(
            string.format("Imported %d boss team(s): %d new, %d updated.", #saved, added, updated),
            0.4,
            1,
            0.4
        )
        if bossTeamDropdown then
            bossTeamDropdown:Refresh()
        end
    end, 150, 20, "Import From Editor")
    importButton:SetPoint("LEFT", clearTeamButton.widget, "RIGHT", 10, 0)
    importButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local inputLabel = CreateSectionLabel(parent, loadTeamButton.widget, "Boss Team Export (paste here to import)", -28)

    rosterInputEditor = framework:NewSpecialLuaEditorEntry(
        parent,
        FULL_CONTENT_WIDTH,
        ROSTER_INPUT_HEIGHT,
        nil,
        "$parentRosterInputEditor",
        true,
        false
    )
    StyleInputEditor(framework, rosterInputEditor)
    rosterInputEditor:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -6)
    rosterInputEditor:SetText("")

    local previewButton = framework:CreateButton(parent, PreviewRosterFromTab, 100, 22, "Preview")
    previewButton:SetPoint("TOPLEFT", rosterInputEditor, "BOTTOMLEFT", 0, -10)
    previewButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local processButton = framework:CreateButton(parent, ProcessRosterFromTab, 130, 22, "Process Roster")
    processButton:SetPoint("LEFT", previewButton.widget, "RIGHT", 10, 0)
    processButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local inviteButton = framework:CreateButton(parent, InviteRosterFromTab, 100, 22, "Invite Only")
    inviteButton:SetPoint("LEFT", processButton.widget, "RIGHT", 10, 0)
    inviteButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local moveButton = framework:CreateButton(parent, MoveRosterFromTab, 110, 22, "Move Extras")
    moveButton:SetPoint("LEFT", inviteButton.widget, "RIGHT", 10, 0)
    moveButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    rosterStatusLabel = CreateWrappedText(
        parent,
        "Paste a boss team export above, click Import, then pick a team in the dropdown.",
        previewButton.widget,
        -12,
        FULL_CONTENT_WIDTH,
        0.8,
        0.8,
        1
    )

    local previewHeader = CreateSectionLabel(parent, rosterStatusLabel, "Preview", -12)

    rosterPreviewScrollBox = framework:CreateScrollBox(
        parent,
        "$parentRosterPreviewScrollBox",
        RefreshRosterPreviewLines,
        {},
        1,
        1,
        1,
        ROSTER_PREVIEW_ROW_HEIGHT,
        CreateRosterPreviewLine,
        true
    )
    rosterPreviewScrollBox:SetPoint("TOPLEFT", previewHeader, "BOTTOMLEFT", 0, -6)
    rosterPreviewScrollBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    framework:ReskinSlider(rosterPreviewScrollBox)
    rosterPreviewScrollBox:OnSizeChanged()

    SetDefaultRosterPreviewRows()
end

local function BuildVersionsTab(framework, parent)
    versionsTab = parent

    local anchor = CreateBodyAnchor(parent)
    local checkButton = framework:CreateButton(parent, RequestVersionCheckFromTab, 180, 22, "Check Versions")
    checkButton:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    checkButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    versionsStatusLabel = CreateWrappedText(parent, "", checkButton.widget, -12, FULL_CONTENT_WIDTH, 0.8, 0.8, 1)

    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetPoint("TOPLEFT", versionsStatusLabel, "BOTTOMLEFT", 0, -12)
    headerFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, 0)
    headerFrame:SetHeight(18)

    local offset = 0
    for _, column in ipairs(versionColumns) do
        local headerText = CreateVersionColumnText(headerFrame, column, offset, "GameFontNormalSmall", 0, 1, 0)
        headerText:SetText(column.label)
        offset = offset + column.width
    end

    versionsResultsScrollBox = framework:CreateScrollBox(
        parent,
        "$parentVersionsScrollBox",
        RefreshVersionsLines,
        {},
        1,
        1,
        1,
        VERSION_ROW_HEIGHT,
        CreateVersionsLine,
        true
    )
    versionsResultsScrollBox:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -6)
    versionsResultsScrollBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    framework:ReskinSlider(versionsResultsScrollBox)
    versionsResultsScrollBox:OnSizeChanged()

    parent.RefreshOptions = function()
        AP:RefreshVersionsTab()
    end

    parent:RefreshOptions()
end

local function SetMultiboxStatus(text, r, g, b)
    if not multiboxStatusLabel then
        return
    end

    UpdateWrappedLabel(multiboxStatusLabel, text or "", FULL_CONTENT_WIDTH)
    multiboxStatusLabel:SetTextColor(r or 0.85, g or 0.85, b or 0.85, 1)
end

local function BuildMultiboxStatusText()
    local team = AP.Team
    if not team or not team:IsEnabled() then
        return "Multiboxing Team is disabled."
    end

    local lines = {}

    if team:GetIsMain() then
        lines[#lines + 1] = "This box is the main."
    end

    local followTarget = team.GetFollowTarget and team:GetFollowTarget()
    if followTarget then
        lines[#lines + 1] = "Follow target: " .. followTarget
    else
        lines[#lines + 1] = "Follow target: none (not in a group)"
    end

    if team.HasMultiMainConflict and team:HasMultiMainConflict() then
        lines[#lines + 1] =
            "WARNING: More than one box claims to be the main! Check 'This box is the main' on exactly one client."
        return table.concat(lines, "\n"), 1, 0.3, 0.2
    end

    return table.concat(lines, "\n"), 0.8, 0.8, 1
end

local function BuildMultiboxTab(framework, parent)
    multiboxTab = parent

    local anchor = CreateBodyAnchor(parent)

    -- Body anchor sits at -90 from the tab top; the status label goes right
    -- below it and the menu must start clear of the (up to 3 line) label.
    multiboxStatusLabel = CreateWrappedText(parent, "", anchor, 0, FULL_CONTENT_WIDTH, 0.8, 0.8, 1)

    CreateWrappedText(
        parent,
        "/apteam mounts (or /apteam dismount) the whole team. Followers follow the main with the "
            .. "APFollow macro that this feature keeps pointed at the main automatically; bind a key "
            .. "to it on each follower. Without a main, followers fall back to the group leader.",
        anchor,
        -170,
        FULL_CONTENT_WIDTH,
        0.85,
        0.85,
        0.85
    )

    local function RefreshMultiboxOptions()
        local text, r, g, b = BuildMultiboxStatusText()
        SetMultiboxStatus(text, r, g, b)

        parent.RefreshOptions = function()
            AP:RefreshMultiboxTab()
        end

        if AP.SettingsDFRenderer and AP.SettingsRegistry then
            AP.SettingsDFRenderer:BuildMenu(parent, framework, {
                xOffset = 20,
                yOffset = -160,
                height = parent:GetHeight() - 60,
            }, AP.SettingsRegistry:GetMultiboxItems())
        end
    end

    parent.RefreshOptions = RefreshMultiboxOptions
    parent:RefreshOptions()
end

local function BuildSettingsTab(framework, parent)
    settingsTab = parent

    local function RefreshSettingsOptions()
        parent.RefreshOptions = settingsTabRefreshBase or function() end

        local menuYOffset = BODY_TOP_OFFSET - 16

        if AP.SettingsDFRenderer then
            AP.SettingsDFRenderer:BuildMenu(parent, framework, {
                xOffset = 20,
                yOffset = menuYOffset,
                height = parent:GetHeight() - 20,
            })
        end

        settingsTabRefreshBase = parent.RefreshOptions
        parent.RefreshOptions = RefreshSettingsOptions
    end

    parent.RefreshOptions = RefreshSettingsOptions
    parent:RefreshOptions()
end

local function BuildMainWindow()
    local framework = GetFramework()
    if not framework then
        AP:Print("DetailsFramework failed to load.")
        return nil
    end

    if mainWindow then
        return mainWindow
    end

    mainWindow = framework:CreateSimplePanel(UIParent, 1220, 780, "APRaidUtils", "APRaidUtilsMainWindow", {
        UseStatusBar = true,
        DontRightClickClose = true,
    })
    mainWindow:SetPoint("CENTER")
    mainWindow:SetFrameStrata("HIGH")
    mainWindow:HookScript("OnHide", function()
        local anchorModule = AP.APAnchor
        if anchorModule and anchorModule.IsAnchorsVisible and anchorModule:IsAnchorsVisible() then
            anchorModule:HideAllAnchors()
        end
    end)

    mainTabs = framework:CreateTabContainer(mainWindow, "APRaidUtils", "APRaidUtilsMainTabs", tabList, {
        width = 1196,
        height = 740,
        backdrop_color = { 0.06, 0.06, 0.08, 0.94 },
        backdrop_border_color = { 0.2, 0.2, 0.24, 0.9 },
        hide_click_label = true,
        button_width = 110,
        button_height = 20,
        button_x = 190,
        button_y = 0,
        button_text_size = 11,
    })
    mainTabs:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 12, -26)

    BuildRosterTab(framework, mainTabs:GetTabFrameByName("Roster"))
    BuildVersionsTab(framework, mainTabs:GetTabFrameByName("Versions"))
    BuildMultiboxTab(framework, mainTabs:GetTabFrameByName("Multibox"))
    BuildSettingsTab(framework, mainTabs:GetTabFrameByName("Settings"))

    if mainTabs.SelectTabByName then
        mainTabs:SelectTabByName("Roster")
    end

    mainWindow:Hide()

    return mainWindow
end

function AP:OpenMainWindow(tabName)
    local window = BuildMainWindow()
    if not window then
        return
    end

    window:Show()

    if tabName and mainTabs and mainTabs.SelectTabByName then
        mainTabs:SelectTabByName(tabName)
    end
end

function AP:ToggleMainWindow(tabName)
    local window = BuildMainWindow()
    if not window then
        return
    end

    if window:IsShown() then
        window:Hide()
        return
    end

    window:Show()

    if mainTabs and mainTabs.SelectTabByName then
        mainTabs:SelectTabByName(tabName or "Roster")
    end
end

function AP:RefreshSettingsTab()
    if settingsTab and settingsTab.RefreshOptions then
        settingsTab:RefreshOptions()
    end
end

function AP:RefreshMultiboxTab()
    if multiboxTab and multiboxTab.RefreshOptions then
        multiboxTab:RefreshOptions()
    end
end

function AP:RefreshVersionsTab()
    if not versionsTab or not versionsResultsScrollBox then
        return
    end

    local versionChecker = self.VersionChecker
    if not versionChecker then
        return
    end

    if versionsStatusLabel and versionChecker.GetVersionStatusText then
        UpdateWrappedLabel(versionsStatusLabel, versionChecker:GetVersionStatusText(), FULL_CONTENT_WIDTH)
    end

    if versionChecker.GetVersionRows then
        versionsResultsScrollBox:SetData(versionChecker:GetVersionRows())
        versionsResultsScrollBox:Refresh()
    end
end
