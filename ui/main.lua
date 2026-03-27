local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local mainWindow
local mainTabs
local simcTab
local simcCharacterDropdown
local simcStatusLabel
local simcMetadataLabel
local simcExportEditor
local simcSelectedCharacterKey
local rosterInputEditor
local rosterStatusLabel
local rosterPreviewScrollBox
local versionsTab
local versionsStatusLabel
local versionsResultsScrollBox
local settingsTab
local settingsTabRefreshBase
local settingsCurrentCharacterLabel
local remindersTab
local remindersStatusLabel
local remindersPlaceholderLabel
local remindersBrowserFrame
local remindersObservedScrollBox
local remindersRaidDropdown
local remindersBossDropdown
local remindersTimerSearchTextBox
local remindersTimerSearchClearButton
local remindersCurrentExpansionCheckbox
local remindersSelectedTimerKey
local remindersSelectedRuleId
local remindersCreatingNewRule
local remindersActivePage = "browser"
local remindersDetailsLabel
local remindersDetailsFrame
local remindersEditorHeaderLabel
local remindersEditorBackButton
local remindersRuleListHeaderLabel
local remindersRuleListScrollBox
local remindersRuleStatusLabel
local remindersRuleNameTextBox
local remindersRuleTextBox
local remindersTriggerSecondsTextBox
local remindersOccurrenceTextBox
local remindersShowBarCheckbox
local remindersShowCountdownCheckbox
local remindersAddRuleButton
local remindersDeleteRuleButton
local remindersFormHeaderLabel

local CONTENT_WIDTH = 1020
local BODY_TOP_OFFSET = -90
local FULL_CONTENT_WIDTH = 1156
local REMINDER_FORM_WIDTH = 520
local REMINDER_LIST_PANEL_WIDTH = 320
local ROSTER_INPUT_HEIGHT = 126
local ROSTER_PREVIEW_ROW_HEIGHT = 20
local VERSION_ROW_HEIGHT = 22
local REMINDER_TIMER_ROW_HEIGHT = 22
local REMINDER_RULE_ROW_HEIGHT = 34
local REMINDER_DRAFT_RULE_ID = "__draft__"

local versionColumns = {
    { key = "name", label = "Name", width = 240, align = "LEFT" },
    { key = "BigWigs", label = "BigWigs", width = 149, align = "CENTER" },
    { key = "DBM", label = "DBM", width = 149, align = "CENTER" },
    { key = "MRT", label = "MRT", width = 149, align = "CENTER" },
    { key = "NS", label = "NS", width = 149, align = "CENTER" },
}

local reminderColumns = {
    { key = "bossName", label = "Boss", width = 180, align = "LEFT" },
    { key = "label", label = "Ability", width = 360, align = "LEFT" },
    { key = "spellName", label = "Easy", width = 180, align = "LEFT" },
    { key = "spellText", label = "Key", width = 90, align = "CENTER" },
    { key = "reminderCount", label = "Rem", width = 55, align = "CENTER" },
    { key = "lastSeenText", label = "State", width = 70, align = "CENTER" },
}

local remindersSelectedRaidFilter = "ALL"
local remindersSelectedBossFilter = "ALL"
local remindersTimerSearchText = ""
local remindersOnlyCurrentExpansion = true

local tabList = {
    { name = "SimC", text = "SimC" },
    { name = "Roster", text = "Roster" },
    { name = "Versions", text = "Versions" },
    { name = "Reminders", text = "Reminders" },
    { name = "Settings", text = "Settings" },
}

local function GetFramework()
    return LibStub("DetailsFramework-1.0", true) or _G.DetailsFramework
end

local function FormatSavedTime(timestamp)
    if not timestamp then
        return "Unknown"
    end

    return date("%Y-%m-%d %H:%M", timestamp)
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

local function GetLabelHeight(label, fallback)
    if not label then
        return fallback or 0
    end

    local height = label:GetStringHeight()
    if not height or height <= 0 then
        height = label:GetHeight()
    end

    return height or fallback or 0
end

local function CreateActionButton(framework, parent, text, anchor, offsetY, callback)
    local button = framework:CreateButton(parent, callback, 220, 22, text)
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    button:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
    return button
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

local function CaptureCurrentCharacter()
    local simcExport = AP:GetModule("SimcExport", true)
    if simcExport and simcExport.ManualCapture then
        simcExport:ManualCapture()
        return
    end

    AP:Print("SimulationCraft capture is unavailable.")
end

local function SetSimcStatus(text, r, g, b)
    if not simcStatusLabel then
        return
    end

    UpdateWrappedLabel(simcStatusLabel, text or "", FULL_CONTENT_WIDTH)
    simcStatusLabel:SetTextColor(r or 0.85, g or 0.85, b or 0.85, 1)
end

local function SetSimcMetadata(text)
    if not simcMetadataLabel then
        return
    end

    UpdateWrappedLabel(simcMetadataLabel, text or "", FULL_CONTENT_WIDTH)
end

local function SelectSimcCharacter(characterKey)
    simcSelectedCharacterKey = characterKey

    if not simcExportEditor then
        return
    end

    if not characterKey then
        SetSimcStatus("No saved SimulationCraft exports found. Capture the current character to create one.", 1, 0.82, 0)
        SetSimcMetadata("")
        simcExportEditor:SetText("")
        return
    end

    local character = AP:GetSimcCharacter(characterKey)
    local exportData = AP:GetSimcExport(characterKey)
    if not character or not exportData or not exportData.text or exportData.text == "" then
        SetSimcStatus("No saved SimulationCraft exports found. Capture the current character to create one.", 1, 0.82, 0)
        SetSimcMetadata("")
        simcExportEditor:SetText("")
        return
    end

    SetSimcStatus("Select the text below and copy it into SimulationCraft.", 0.8, 0.8, 1)
    SetSimcMetadata("Last updated: " .. FormatSavedTime(exportData.updatedAt))
    simcExportEditor:SetText(exportData.text)
    simcExportEditor:HighlightText()
end

local function GetSimcDropdownOptions()
    local options = {}

    for _, character in ipairs(AP:GetSimcExportCharacters()) do
        local characterKey = character.key
        local label = AP:GetCharacterDisplayName(character)
        local exportData = AP:GetSimcExport(characterKey)
        local specializationText = AP:GetCharacterSpecializationText(character, exportData and exportData.specName)
        if specializationText ~= "" then
            label = label .. " (" .. specializationText .. ")"
        end

        options[#options + 1] = {
            value = characterKey,
            label = label,
            onclick = function()
                SelectSimcCharacter(characterKey)
            end,
        }
    end

    return options
end

local function CaptureCurrentCharacterFromTab()
    local characterInfo = AP:GetPlayerCharacterInfo()
    if characterInfo and characterInfo.key then
        simcSelectedCharacterKey = characterInfo.key
    end

    SetSimcStatus("Generating a new SimulationCraft export...", 1, 0.82, 0)
    CaptureCurrentCharacter()
end

local function GetRosterManager()
    return AP:GetModule("RosterManager", true)
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
            local line = scrollBox:GetLine(lineIndex)
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
        { text = "  " .. (text or "Paste a roster and click Preview to see invites and moves."), kind = "success" },
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
        SetDefaultRosterPreviewRows("Preview will appear here after you paste a roster.")
        if updateStatus then
            SetRosterStatus(errorMessage or "Error: No roster provided", 1, 0, 0)
        end
        return false
    end

    SetRosterPreviewRows(BuildRosterPreviewRows(preview))

    if updateStatus then
        SetRosterStatus(string.format("Preview: %d to invite, %d to move in, %d to move out", #preview.missing, #preview.toMoveIn, #preview.toMoveOut), 0.8, 0.8, 1)
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
            local line = scrollBox:GetLine(lineIndex)
            local isPlayer = row.name == playerName

            line:SetBackdropColor(isPlayer and 0.12 or 0.08, isPlayer and 0.16 or 0.08, isPlayer and 0.1 or 0.1, isPlayer and 0.55 or 0.35)

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
    local versionChecker = AP:GetModule("VersionChecker", true)
    if versionChecker and versionChecker.RequestVersionCheck then
        versionChecker:RequestVersionCheck()
        return
    end

    AP:Print("Version checker is unavailable.")
end

local function SelectObservedReminderTimer(timerKey)
    remindersSelectedTimerKey = timerKey
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    AP:RefreshRemindersTab()
end

local function SelectReminderRule(ruleId)
    remindersSelectedRuleId = ruleId
    remindersCreatingNewRule = ruleId == REMINDER_DRAFT_RULE_ID
    AP:RefreshRemindersTab()
end

local function StartNewReminderRule()
    remindersSelectedRuleId = REMINDER_DRAFT_RULE_ID
    remindersCreatingNewRule = true
    AP:RefreshRemindersTab()
end

local function OpenReminderEditorForTimer(timerKey)
    if not timerKey then
        return
    end

    remindersSelectedTimerKey = timerKey
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    remindersActivePage = "editor"
    AP:RefreshRemindersTab()
end

local function ReturnToReminderBrowserPage()
    remindersActivePage = "browser"
    remindersCreatingNewRule = false
    AP:RefreshRemindersTab()
end

local function SelectObservedReminderRaid(instanceName)
    remindersActivePage = "browser"
    remindersSelectedRaidFilter = instanceName or "ALL"
    remindersSelectedBossFilter = "ALL"
    remindersTimerSearchText = ""
    remindersSelectedTimerKey = nil
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    local reminders = AP:GetModule("Reminders", true)
    if reminders and reminders.PrimeReminderData then
        reminders:PrimeReminderData(remindersSelectedRaidFilter)
    end
    AP:RefreshRemindersTab()
end

local function SelectObservedReminderBoss(bossKey)
    remindersActivePage = "browser"
    remindersSelectedBossFilter = bossKey or "ALL"
    remindersTimerSearchText = ""
    remindersSelectedTimerKey = nil
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    AP:RefreshRemindersTab()
end

local function SetRemindersCurrentExpansionOnly(_, _, value)
    remindersOnlyCurrentExpansion = value == true
    remindersActivePage = "browser"
    remindersSelectedRaidFilter = "ALL"
    remindersSelectedBossFilter = "ALL"
    remindersTimerSearchText = ""
    remindersSelectedTimerKey = nil
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    AP:RefreshRemindersTab()
end

local function UpdateReminderSearchFromUI()
    remindersActivePage = "browser"
    remindersTimerSearchText = remindersTimerSearchTextBox and remindersTimerSearchTextBox:GetText() or ""
    remindersSelectedTimerKey = nil
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    AP:RefreshRemindersTab()
end

local function ClearReminderSearchFromUI()
    remindersActivePage = "browser"
    remindersTimerSearchText = ""
    remindersSelectedTimerKey = nil
    remindersSelectedRuleId = nil
    remindersCreatingNewRule = false
    if remindersTimerSearchTextBox then
        remindersTimerSearchTextBox:SetText("")
    end
    AP:RefreshRemindersTab()
end

local function SetReminderRuleStatus(text, r, g, b)
    if not remindersRuleStatusLabel then
        return
    end

    remindersRuleStatusLabel:SetText(text or "")
    remindersRuleStatusLabel:SetTextColor(r or 0.85, g or 0.85, b or 0.85, 1)
end

local function HandleReminderOutputToggle()
end

local function EnsureReminderRuleSelectionVisible(ruleRows)
    if not remindersRuleListScrollBox or not remindersSelectedRuleId then
        return
    end

    local selectedIndex = nil
    for index, row in ipairs(ruleRows or {}) do
        if row.ruleId == remindersSelectedRuleId then
            selectedIndex = index
            break
        end
    end

    if not selectedIndex then
        return
    end

    local visibleLines = remindersRuleListScrollBox.GetNumFramesShown and remindersRuleListScrollBox:GetNumFramesShown() or 0
    if visibleLines <= 0 then
        return
    end

    local currentOffset = remindersRuleListScrollBox.GetOffsetFaux and remindersRuleListScrollBox:GetOffsetFaux() or 0
    local firstVisible = currentOffset + 1
    local lastVisible = currentOffset + visibleLines
    local desiredOffset = nil

    if selectedIndex < firstVisible then
        desiredOffset = selectedIndex - 1
    elseif selectedIndex > lastVisible then
        desiredOffset = selectedIndex - visibleLines
    end

    if desiredOffset and desiredOffset ~= currentOffset then
        remindersRuleListScrollBox:OnVerticalScrollFaux(desiredOffset * REMINDER_RULE_ROW_HEIGHT, REMINDER_RULE_ROW_HEIGHT, remindersRuleListScrollBox.Refresh)
    end
end

local function SaveReminderRuleFromUI()
    local reminders = AP:GetModule("Reminders", true)
    if not reminders then
        return
    end

    local targetRuleId = remindersSelectedRuleId
    if targetRuleId == REMINDER_DRAFT_RULE_ID then
        targetRuleId = nil
    end

    local success, message, ruleId = reminders:SaveRule(remindersSelectedTimerKey, targetRuleId, {
        name = remindersRuleNameTextBox and remindersRuleNameTextBox:GetText() or "",
        text = remindersRuleTextBox and remindersRuleTextBox:GetText() or "",
        secondsBeforeEnd = remindersTriggerSecondsTextBox and remindersTriggerSecondsTextBox:GetText() or "0",
        occurrenceNumber = remindersOccurrenceTextBox and remindersOccurrenceTextBox:GetText() or "0",
        showBar = remindersShowBarCheckbox and remindersShowBarCheckbox:GetChecked() or false,
        showCountdown = remindersShowCountdownCheckbox and remindersShowCountdownCheckbox:GetChecked() or false,
    })

    if success then
        remindersSelectedRuleId = ruleId
        remindersCreatingNewRule = false
        AP:RefreshRemindersTab()
    end

    SetReminderRuleStatus(message, success and 0.2 or 1, success and 1 or 0.2, success and 0.2 or 0.2)
end

local function DeleteReminderRuleFromUI()
    local reminders = AP:GetModule("Reminders", true)
    if not reminders then
        return
    end

    if remindersSelectedRuleId == REMINDER_DRAFT_RULE_ID then
        remindersSelectedRuleId = nil
        remindersCreatingNewRule = false
        AP:RefreshRemindersTab()
        return
    end

    local success, message = reminders:DeleteRule(remindersSelectedTimerKey, remindersSelectedRuleId)

    if success then
        remindersSelectedRuleId = nil
        remindersCreatingNewRule = false
        AP:RefreshRemindersTab()
    end

    SetReminderRuleStatus(message, success and 0.2 or 1, success and 1 or 0.2, success and 0.2 or 0.2)
end

local function CreateReminderObservedLine(self, index)
    local framework = GetFramework()
    local line = CreateFrame("Button", "$parentLine" .. index, self, "BackdropTemplate")
    line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * REMINDER_TIMER_ROW_HEIGHT) - 1)
    line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -18, -((index - 1) * REMINDER_TIMER_ROW_HEIGHT) - 1)
    line:SetHeight(REMINDER_TIMER_ROW_HEIGHT)
    line:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })

    line.Columns = {}

    local offset = 0
    for _, column in ipairs(reminderColumns) do
        line.Columns[column.key] = CreateVersionColumnText(line, column, offset)
        offset = offset + column.width
    end

    if framework then
        line.OpenButton = framework:CreateButton(line, function(_, _, timerKey)
            OpenReminderEditorForTimer(timerKey)
        end, 64, 18, "Go To")
        line.OpenButton:SetPoint("RIGHT", line, "RIGHT", -8, 0)
        line.OpenButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
    end

    return line
end

local function RefreshReminderObservedLines(scrollBox, data, offset, totalLines)
    for lineIndex = 1, totalLines do
        local row = data[lineIndex + offset]
        if row then
            local line = scrollBox:GetLine(lineIndex)
            if not line then
                return
            end
            local isSection = row.kind == "section"
            local isSelected = not isSection and row.timerKey == remindersSelectedTimerKey

            if isSection then
                line:SetBackdropColor(0.14, 0.12, 0.05, 0.5)
                line:SetScript("OnClick", nil)
                if line.OpenButton then
                    line.OpenButton:Hide()
                end
            else
                line:SetBackdropColor(isSelected and 0.12 or 0.08, isSelected and 0.16 or 0.08, isSelected and 0.1 or 0.1, isSelected and 0.55 or 0.35)
                line:SetScript("OnClick", function()
                    SelectObservedReminderTimer(row.timerKey)
                end)
                if line.OpenButton then
                    line.OpenButton:SetClickFunction(function(_, _, timerKey)
                        OpenReminderEditorForTimer(timerKey)
                    end, row.timerKey)
                    line.OpenButton:Show()
                end
            end

            for _, column in ipairs(reminderColumns) do
                local value = row[column.key] or ""
                if not isSection and column.key == "label" then
                    value = "  " .. tostring(value)
                elseif not isSection and column.key == "spellName" then
                    value = row.spellName ~= "" and row.spellName or "-"
                end

                line.Columns[column.key]:SetText(tostring(value))
                if isSection then
                    if column.key == "bossName" or column.key == "label" then
                        line.Columns[column.key]:SetTextColor(1, 0.82, 0, 1)
                        line.Columns[column.key]:SetFontObject(column.key == "bossName" and "GameFontNormalSmall" or "GameFontHighlightSmall")
                    else
                        line.Columns[column.key]:SetTextColor(1, 1, 1, 0)
                        line.Columns[column.key]:SetFontObject("GameFontHighlightSmall")
                    end
                elseif column.key == "bossName" then
                    line.Columns[column.key]:SetTextColor(0.72, 0.72, 0.78, 1)
                    line.Columns[column.key]:SetFontObject("GameFontHighlightSmall")
                elseif column.key == "label" then
                    line.Columns[column.key]:SetTextColor(isSelected and 0 or 1, isSelected and 1 or 1, isSelected and 0 or 1, 1)
                    line.Columns[column.key]:SetFontObject("GameFontHighlightSmall")
                else
                    line.Columns[column.key]:SetTextColor(1, 1, 1, 1)
                    line.Columns[column.key]:SetFontObject("GameFontHighlightSmall")
                end
            end
        end
    end
end

local function CreateReminderRuleLine(self, index)
    local line = CreateFrame("Button", "$parentRuleLine" .. index, self, "BackdropTemplate")
    line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * REMINDER_RULE_ROW_HEIGHT) - 1)
    line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -18, -((index - 1) * REMINDER_RULE_ROW_HEIGHT) - 1)
    line:SetHeight(REMINDER_RULE_ROW_HEIGHT)
    line:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })

    line.Title = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.Title:SetPoint("TOPLEFT", line, "TOPLEFT", 8, -4)
    line.Title:SetPoint("TOPRIGHT", line, "TOPRIGHT", -8, -4)
    line.Title:SetJustifyH("LEFT")
    line.Title:SetJustifyV("TOP")

    line.Summary = line:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line.Summary:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 8, 4)
    line.Summary:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -8, 4)
    line.Summary:SetJustifyH("LEFT")
    line.Summary:SetJustifyV("BOTTOM")

    return line
end

local function RefreshReminderRuleLines(scrollBox, data, offset, totalLines)
    for lineIndex = 1, totalLines do
        local row = data[lineIndex + offset]
        if row then
            local line = scrollBox:GetLine(lineIndex)
            if not line then
                return
            end
            local isSelected = row.ruleId == remindersSelectedRuleId

            line:SetBackdropColor(isSelected and 0.12 or 0.08, isSelected and 0.16 or 0.08, isSelected and 0.1 or 0.1, isSelected and 0.55 or 0.35)
            line:SetScript("OnClick", function()
                SelectReminderRule(row.ruleId)
            end)
            line.Title:SetText(row.name or row.summary or "")
            line.Title:SetTextColor(isSelected and 0 or 1, isSelected and 1 or 1, isSelected and 0 or 1, 1)
            line.Summary:SetText(row.summary or "")
            line.Summary:SetTextColor(isSelected and 0.15 or 0.65, isSelected and 0.3 or 0.65, isSelected and 0.15 or 0.72, 1)
        end
    end
end

local function BuildSimCTab(framework, parent)
    simcTab = parent

    local anchor = CreateBodyAnchor(parent)
    local characterLabel = CreateSectionLabel(parent, anchor, "Saved Export")

    simcCharacterDropdown = framework:CreateDropDown(
        parent,
        GetSimcDropdownOptions,
        nil,
        634,
        20,
        nil,
        "$parentSimcCharacterDropdown",
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    simcCharacterDropdown:SetPoint("TOPLEFT", characterLabel, "BOTTOMLEFT", 0, -6)
    simcCharacterDropdown:SetEmptyTextAndIcon("No saved exports", [[Interface\COMMON\UI-ModelControlPanel]])

    local captureButton = framework:CreateButton(parent, CaptureCurrentCharacterFromTab, 190, 22, "Capture Current Character")
    captureButton:SetPoint("LEFT", simcCharacterDropdown.widget, "RIGHT", 12, 0)
    captureButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    simcStatusLabel = CreateWrappedText(parent, "", simcCharacterDropdown.widget, -12, FULL_CONTENT_WIDTH, 0.8, 0.8, 1)
    simcMetadataLabel = CreateWrappedText(parent, "", simcStatusLabel, -6, FULL_CONTENT_WIDTH, 1, 0.82, 0)

    simcExportEditor = framework:NewSpecialLuaEditorEntry(parent, 1, 1, nil, "$parentSimcExportEditor", true, false)
    StyleCodeEditor(framework, simcExportEditor)
    simcExportEditor:SetPoint("TOPLEFT", simcMetadataLabel, "BOTTOMLEFT", 0, -12)
    simcExportEditor:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)

    parent.RefreshOptions = function()
        AP:RefreshSimcTab()
    end

    parent:RefreshOptions()
end

local function BuildRosterTab(framework, parent)
    local anchor = CreateBodyAnchor(parent)
    local inputLabel = CreateSectionLabel(parent, anchor, "Roster String")

    rosterInputEditor = framework:NewSpecialLuaEditorEntry(parent, FULL_CONTENT_WIDTH, ROSTER_INPUT_HEIGHT, nil, "$parentRosterInputEditor", true, false)
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

    rosterStatusLabel = CreateWrappedText(parent, "Paste a semicolon-separated roster and click Preview.", previewButton.widget, -12, FULL_CONTENT_WIDTH, 0.8, 0.8, 1)

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

local function BuildSettingsTab(framework, parent)
    settingsTab = parent

    local anchor = CreateBodyAnchor(parent)
    settingsCurrentCharacterLabel = settingsCurrentCharacterLabel or CreateWrappedText(parent, "", anchor, 0, CONTENT_WIDTH, 1, 0.82, 0)

    local function RefreshSettingsOptions()
        parent.RefreshOptions = settingsTabRefreshBase or function()
        end

        if AP.SettingsRegistry and AP.SettingsRegistry.GetCurrentCharacterText then
            UpdateWrappedLabel(settingsCurrentCharacterLabel, AP.SettingsRegistry:GetCurrentCharacterText(), CONTENT_WIDTH)
        end

        local menuYOffset = BODY_TOP_OFFSET
            - GetLabelHeight(settingsCurrentCharacterLabel, 18)
            - 16

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

local function BuildRemindersTab(framework, parent)
    remindersTab = parent

    local anchor = CreateBodyAnchor(parent)
    local titleLabel = CreateSectionLabel(parent, anchor, "BigWigs Reminders")

    remindersStatusLabel = CreateWrappedText(parent, "", titleLabel, -10, FULL_CONTENT_WIDTH, 0.8, 0.8, 1)
    remindersPlaceholderLabel = CreateWrappedText(parent, "", remindersStatusLabel, -10, FULL_CONTENT_WIDTH, 1, 0.82, 0)

    local contentAnchor = CreateFrame("Frame", "$parentRemindersContentAnchor", parent)
    contentAnchor:SetPoint("TOPLEFT", remindersPlaceholderLabel, "BOTTOMLEFT", 0, -18)
    contentAnchor:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, 0)
    contentAnchor:SetHeight(1)

    remindersBrowserFrame = CreateFrame("Frame", "$parentObservedPanel", parent, "BackdropTemplate")
    remindersBrowserFrame:SetPoint("TOPLEFT", contentAnchor, "TOPLEFT", 0, 0)
    remindersBrowserFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    remindersBrowserFrame:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    remindersBrowserFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.35)
    remindersBrowserFrame:SetBackdropBorderColor(0.2, 0.2, 0.24, 0.9)

    local observedHeader = remindersBrowserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    observedHeader:SetPoint("TOPLEFT", remindersBrowserFrame, "TOPLEFT", 10, -10)
    observedHeader:SetText("BigWigs Timers")
    observedHeader:SetTextColor(1, 0.82, 0, 1)

    local observedSubtitle = remindersBrowserFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    observedSubtitle:SetPoint("TOPLEFT", observedHeader, "BOTTOMLEFT", 0, -4)
    observedSubtitle:SetPoint("TOPRIGHT", remindersBrowserFrame, "TOPRIGHT", -12, -14)
    observedSubtitle:SetJustifyH("LEFT")
    observedSubtitle:SetText("Load a raid, then use Go To on any timer row to open its dedicated reminder page.")
    observedSubtitle:SetTextColor(0.72, 0.72, 0.78, 1)

    remindersRaidDropdown = framework:CreateDropDown(
        remindersBrowserFrame,
        function()
            local reminders = AP:GetModule("Reminders", true)
            local options = {}
            if not reminders or not reminders.GetRaidFilterItems then
                return options
            end

            for _, item in ipairs(reminders:GetRaidFilterItems(remindersOnlyCurrentExpansion)) do
                options[#options + 1] = {
                    value = item.value,
                    label = item.label,
                    onclick = function()
                        SelectObservedReminderRaid(item.value)
                    end,
                }
            end

            return options
        end,
        remindersSelectedRaidFilter,
        300,
        20,
        nil,
        "$parentRemindersRaidDropdown",
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersRaidDropdown:SetPoint("TOPLEFT", observedSubtitle, "BOTTOMLEFT", 0, -10)
    remindersRaidDropdown:SetEmptyTextAndIcon("No BigWigs raids", [[Interface\MINIMAP\TRACKING\Target]])

    remindersBossDropdown = framework:CreateDropDown(
        remindersBrowserFrame,
        function()
            local reminders = AP:GetModule("Reminders", true)
            local options = {}
            if not reminders or not reminders.GetBossFilterItems then
                return options
            end

            for _, item in ipairs(reminders:GetBossFilterItems(remindersSelectedRaidFilter)) do
                options[#options + 1] = {
                    value = item.value,
                    label = item.label,
                    onclick = function()
                        SelectObservedReminderBoss(item.value)
                    end,
                }
            end

            return options
        end,
        remindersSelectedBossFilter,
        220,
        20,
        nil,
        "$parentRemindersBossDropdown",
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersBossDropdown:SetPoint("TOPLEFT", remindersRaidDropdown.widget, "BOTTOMLEFT", 0, -10)
    remindersBossDropdown:SetEmptyTextAndIcon("No bosses", [[Interface\MINIMAP\TRACKING\Target]])

    local searchLabel = remindersBrowserFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("LEFT", remindersBossDropdown.widget, "RIGHT", 14, 0)
    searchLabel:SetText("Search")
    searchLabel:SetTextColor(0.82, 0.82, 0.88, 1)

    remindersTimerSearchTextBox = framework:CreateTextEntry(
        remindersBrowserFrame,
        function()
            UpdateReminderSearchFromUI()
        end,
        170,
        20,
        nil,
        "$parentRemindersTimerSearchTextBox",
        nil,
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersTimerSearchTextBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    remindersTimerSearchTextBox:SetAutoFocus(false)
    remindersTimerSearchTextBox:SetText(remindersTimerSearchText or "")

    remindersTimerSearchClearButton = framework:CreateButton(remindersBrowserFrame, ClearReminderSearchFromUI, 22, 20, "X")
    remindersTimerSearchClearButton:SetPoint("LEFT", remindersTimerSearchTextBox.widget, "RIGHT", 6, 0)
    remindersTimerSearchClearButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    remindersCurrentExpansionCheckbox, _ = framework:CreateSwitch(
        remindersBrowserFrame,
        SetRemindersCurrentExpansionOnly,
        remindersOnlyCurrentExpansion,
        20,
        20,
        nil,
        nil,
        nil,
        "$parentRemindersCurrentExpansionCheckbox"
    )
    remindersCurrentExpansionCheckbox:SetAsCheckBox()
    remindersCurrentExpansionCheckbox:SetPoint("LEFT", remindersRaidDropdown.widget, "RIGHT", 14, 0)
    remindersCurrentExpansionCheckbox:SetTemplate(framework:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
    local remindersCurrentExpansionLabel = remindersBrowserFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    remindersCurrentExpansionLabel:SetPoint("LEFT", remindersCurrentExpansionCheckbox.widget, "RIGHT", 6, 0)
    remindersCurrentExpansionLabel:SetText("Current expansion only")
    remindersCurrentExpansionCheckbox:CreateExtraSpaceToClick(remindersCurrentExpansionLabel, 170)

    local headerFrame = CreateFrame("Frame", nil, remindersBrowserFrame)
    headerFrame:SetPoint("TOPLEFT", remindersBossDropdown.widget, "BOTTOMLEFT", -2, -14)
    headerFrame:SetPoint("TOPRIGHT", remindersBrowserFrame, "TOPRIGHT", -8, -8)
    headerFrame:SetHeight(18)

    local offset = 0
    for _, column in ipairs(reminderColumns) do
        local headerText = CreateVersionColumnText(headerFrame, column, offset, "GameFontNormalSmall", 0, 1, 0)
        headerText:SetText(column.label)
        offset = offset + column.width
    end

    remindersObservedScrollBox = framework:CreateScrollBox(
        remindersBrowserFrame,
        "$parentRemindersObservedScrollBox",
        RefreshReminderObservedLines,
        {},
        1,
        1,
        1,
        REMINDER_TIMER_ROW_HEIGHT,
        CreateReminderObservedLine,
        true
    )
    remindersObservedScrollBox:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -6)
    remindersObservedScrollBox:SetPoint("BOTTOMRIGHT", remindersBrowserFrame, "BOTTOMRIGHT", -8, 8)
    framework:ReskinSlider(remindersObservedScrollBox)
    if remindersObservedScrollBox.ScrollBar then
        remindersObservedScrollBox.ScrollBar:ClearAllPoints()
        remindersObservedScrollBox.ScrollBar:SetPoint("TOPRIGHT", remindersObservedScrollBox, "TOPRIGHT", -4, -8)
        remindersObservedScrollBox.ScrollBar:SetPoint("BOTTOMRIGHT", remindersObservedScrollBox, "BOTTOMRIGHT", -4, 8)
    end
    remindersObservedScrollBox:OnSizeChanged()

    remindersDetailsFrame = CreateFrame("Frame", "$parentReminderEditorPanel", parent, "BackdropTemplate")
    remindersDetailsFrame:SetPoint("TOPLEFT", contentAnchor, "TOPLEFT", 0, 0)
    remindersDetailsFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    remindersDetailsFrame:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    remindersDetailsFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.35)
    remindersDetailsFrame:SetBackdropBorderColor(0.2, 0.2, 0.24, 0.9)
    remindersDetailsFrame:Hide()

    remindersEditorBackButton = framework:CreateButton(remindersDetailsFrame, ReturnToReminderBrowserPage, 100, 22, "Back")
    remindersEditorBackButton:SetPoint("TOPLEFT", remindersDetailsFrame, "TOPLEFT", 10, -10)
    remindersEditorBackButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    remindersEditorHeaderLabel = remindersDetailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    remindersEditorHeaderLabel:SetPoint("LEFT", remindersEditorBackButton.widget, "RIGHT", 12, 0)
    remindersEditorHeaderLabel:SetText("Timer Reminders")
    remindersEditorHeaderLabel:SetTextColor(1, 0.82, 0, 1)

    remindersDetailsLabel = remindersDetailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    remindersDetailsLabel:SetPoint("TOPLEFT", remindersEditorBackButton.widget, "BOTTOMLEFT", 0, -12)
    remindersDetailsLabel:SetPoint("TOPRIGHT", remindersDetailsFrame, "TOPRIGHT", -12, -22)
    remindersDetailsLabel:SetJustifyH("LEFT")
    remindersDetailsLabel:SetJustifyV("TOP")
    remindersDetailsLabel:SetTextColor(0.85, 0.85, 0.85, 1)
    remindersDetailsLabel:SetWidth(FULL_CONTENT_WIDTH - 20)
    remindersDetailsLabel:SetWordWrap(true)

    local listPanel = CreateFrame("Frame", nil, remindersDetailsFrame, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", remindersDetailsLabel, "BOTTOMLEFT", 0, -12)
    listPanel:SetPoint("BOTTOMLEFT", remindersDetailsFrame, "BOTTOMLEFT", 12, 12)
    listPanel:SetWidth(REMINDER_LIST_PANEL_WIDTH)
    listPanel:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    listPanel:SetBackdropColor(0.05, 0.05, 0.07, 0.55)
    listPanel:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.9)

    local reminderListHeaderFrame = CreateFrame("Frame", nil, listPanel)
    reminderListHeaderFrame:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    reminderListHeaderFrame:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    reminderListHeaderFrame:SetHeight(22)

    remindersRuleListHeaderLabel = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    remindersRuleListHeaderLabel:SetPoint("LEFT", reminderListHeaderFrame, "LEFT", 0, 0)
    remindersRuleListHeaderLabel:SetText("Saved Reminders")
    remindersRuleListHeaderLabel:SetTextColor(1, 0.82, 0, 1)

    remindersAddRuleButton = framework:CreateButton(listPanel, StartNewReminderRule, 110, 22, "Add Reminder")
    remindersAddRuleButton:SetPoint("RIGHT", reminderListHeaderFrame, "RIGHT", 0, 0)
    remindersAddRuleButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    remindersRuleListScrollBox = framework:CreateScrollBox(
        listPanel,
        "$parentRemindersRuleListScrollBox",
        RefreshReminderRuleLines,
        {},
        1,
        1,
        1,
        REMINDER_RULE_ROW_HEIGHT,
        CreateReminderRuleLine,
        true
    )
    remindersRuleListScrollBox:SetPoint("TOPLEFT", reminderListHeaderFrame, "BOTTOMLEFT", 0, -8)
    remindersRuleListScrollBox:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -10, 10)
    framework:ReskinSlider(remindersRuleListScrollBox)
    if remindersRuleListScrollBox.ScrollBar then
        remindersRuleListScrollBox.ScrollBar:ClearAllPoints()
        remindersRuleListScrollBox.ScrollBar:SetPoint("TOPRIGHT", remindersRuleListScrollBox, "TOPRIGHT", -4, -8)
        remindersRuleListScrollBox.ScrollBar:SetPoint("BOTTOMRIGHT", remindersRuleListScrollBox, "BOTTOMRIGHT", -4, 8)
    end
    remindersRuleListScrollBox:OnSizeChanged()

    local formPanel = CreateFrame("Frame", nil, remindersDetailsFrame, "BackdropTemplate")
    formPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 16, 0)
    formPanel:SetPoint("BOTTOMRIGHT", remindersDetailsFrame, "BOTTOMRIGHT", -12, 12)
    formPanel:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    formPanel:SetBackdropColor(0.05, 0.05, 0.07, 0.55)
    formPanel:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.9)

    remindersFormHeaderLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    remindersFormHeaderLabel:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 12, -10)
    remindersFormHeaderLabel:SetText("Reminder Settings")
    remindersFormHeaderLabel:SetTextColor(1, 0.82, 0, 1)

    local reminderNameLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reminderNameLabel:SetPoint("TOPLEFT", remindersFormHeaderLabel, "BOTTOMLEFT", 0, -12)
    reminderNameLabel:SetText("Reminder Name")
    reminderNameLabel:SetTextColor(1, 0.82, 0, 1)

    remindersRuleNameTextBox = framework:CreateTextEntry(
        formPanel,
        function() end,
        REMINDER_FORM_WIDTH,
        28,
        nil,
        "APRaidUtilsReminderRuleNameTextBox",
        nil,
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersRuleNameTextBox:SetPoint("TOPLEFT", reminderNameLabel, "BOTTOMLEFT", 0, -8)
    remindersRuleNameTextBox:SetAutoFocus(false)
    remindersRuleNameTextBox:SetText("")

    local reminderTextLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reminderTextLabel:SetPoint("TOPLEFT", remindersRuleNameTextBox.widget, "BOTTOMLEFT", 0, -12)
    reminderTextLabel:SetText("Reminder Text")
    reminderTextLabel:SetTextColor(1, 0.82, 0, 1)

    remindersRuleTextBox = framework:CreateTextEntry(
        formPanel,
        function() end,
        REMINDER_FORM_WIDTH,
        28,
        nil,
        "APRaidUtilsReminderRuleTextBox",
        nil,
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersRuleTextBox:SetPoint("TOPLEFT", reminderTextLabel, "BOTTOMLEFT", 0, -8)
    remindersRuleTextBox:SetAutoFocus(false)
    remindersRuleTextBox:SetText("")

    local reminderHelpLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reminderHelpLabel:SetPoint("TOPLEFT", remindersRuleTextBox.widget, "BOTTOMLEFT", -6, -6)
    reminderHelpLabel:SetPoint("TOPRIGHT", formPanel, "TOPRIGHT", -12, 0)
    reminderHelpLabel:SetJustifyH("LEFT")
    reminderHelpLabel:SetWidth(REMINDER_FORM_WIDTH)
    reminderHelpLabel:SetWordWrap(true)
    reminderHelpLabel:SetText("Placeholders: {countdown}, {spell}, {boss}")
    reminderHelpLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    local timingLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timingLabel:SetPoint("TOPLEFT", reminderHelpLabel, "BOTTOMLEFT", 0, -12)
    timingLabel:SetText("Trigger Settings")
    timingLabel:SetTextColor(1, 0.82, 0, 1)

    local timingRow = CreateFrame("Frame", nil, formPanel)
    timingRow:SetPoint("TOPLEFT", timingLabel, "BOTTOMLEFT", 0, -8)
    timingRow:SetSize(REMINDER_FORM_WIDTH, 58)

    local triggerFieldLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    triggerFieldLabel:SetPoint("TOPLEFT", timingRow, "TOPLEFT", 0, 0)
    triggerFieldLabel:SetText("Seconds Left")
    triggerFieldLabel:SetTextColor(0.9, 0.9, 0.9, 1)

    remindersTriggerSecondsTextBox = framework:CreateTextEntry(
        formPanel,
        function() end,
        78,
        28,
        nil,
        "APRaidUtilsReminderTriggerSecondsTextBox",
        nil,
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersTriggerSecondsTextBox:SetPoint("TOPLEFT", triggerFieldLabel, "BOTTOMLEFT", 0, -6)
    remindersTriggerSecondsTextBox:SetAutoFocus(false)
    remindersTriggerSecondsTextBox:SetText("0")

    local triggerSecondsSuffix = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    triggerSecondsSuffix:SetPoint("TOPLEFT", remindersTriggerSecondsTextBox.widget, "BOTTOMLEFT", 0, -4)
    triggerSecondsSuffix:SetText("0 = on start")
    triggerSecondsSuffix:SetTextColor(0.65, 0.65, 0.7, 1)

    local occurrenceFieldLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    occurrenceFieldLabel:SetPoint("TOPLEFT", timingRow, "TOPLEFT", 182, 0)
    occurrenceFieldLabel:SetText("Occurrence")
    occurrenceFieldLabel:SetTextColor(0.9, 0.9, 0.9, 1)

    remindersOccurrenceTextBox = framework:CreateTextEntry(
        formPanel,
        function() end,
        78,
        28,
        nil,
        "APRaidUtilsReminderOccurrenceTextBox",
        nil,
        framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    )
    remindersOccurrenceTextBox:SetPoint("TOPLEFT", occurrenceFieldLabel, "BOTTOMLEFT", 0, -6)
    remindersOccurrenceTextBox:SetAutoFocus(false)
    remindersOccurrenceTextBox:SetText("0")

    local occurrenceSuffix = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    occurrenceSuffix:SetPoint("TOPLEFT", remindersOccurrenceTextBox.widget, "BOTTOMLEFT", 0, -4)
    occurrenceSuffix:SetText("0 = every time")
    occurrenceSuffix:SetTextColor(0.65, 0.65, 0.7, 1)

    local outputsLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    outputsLabel:SetPoint("TOPLEFT", timingRow, "BOTTOMLEFT", 0, -8)
    outputsLabel:SetText("Outputs")
    outputsLabel:SetTextColor(1, 0.82, 0, 1)

    remindersShowBarCheckbox, _ = framework:CreateSwitch(
        formPanel,
        HandleReminderOutputToggle,
        false,
        20,
        20,
        nil,
        nil,
        nil,
        "$parentShowBarCheckbox"
    )
    remindersShowBarCheckbox:SetAsCheckBox()
    remindersShowBarCheckbox:SetPoint("TOPLEFT", outputsLabel, "BOTTOMLEFT", 0, -8)
    remindersShowBarCheckbox:SetTemplate(framework:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
    local remindersShowBarLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    remindersShowBarLabel:SetPoint("LEFT", remindersShowBarCheckbox.widget, "RIGHT", 6, 0)
    remindersShowBarLabel:SetText("Show custom bar")
    remindersShowBarCheckbox:CreateExtraSpaceToClick(remindersShowBarLabel, 100)

    remindersShowCountdownCheckbox, _ = framework:CreateSwitch(
        formPanel,
        HandleReminderOutputToggle,
        false,
        20,
        20,
        nil,
        nil,
        nil,
        "$parentShowCountdownCheckbox"
    )
    remindersShowCountdownCheckbox:SetAsCheckBox()
    remindersShowCountdownCheckbox:SetPoint("LEFT", remindersShowBarLabel, "RIGHT", 26, 0)
    remindersShowCountdownCheckbox:SetTemplate(framework:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
    local remindersShowCountdownLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    remindersShowCountdownLabel:SetPoint("LEFT", remindersShowCountdownCheckbox.widget, "RIGHT", 6, 0)
    remindersShowCountdownLabel:SetText("Show countdown")
    remindersShowCountdownCheckbox:CreateExtraSpaceToClick(remindersShowCountdownLabel, 110)

    local saveButton = framework:CreateButton(formPanel, SaveReminderRuleFromUI, 120, 22, "Save Reminder")
    saveButton:SetPoint("TOPLEFT", remindersShowBarCheckbox, "BOTTOMLEFT", 0, -12)
    saveButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    remindersDeleteRuleButton = framework:CreateButton(formPanel, DeleteReminderRuleFromUI, 120, 22, "Delete Reminder")
    remindersDeleteRuleButton:SetPoint("LEFT", saveButton.widget, "RIGHT", 10, 0)
    remindersDeleteRuleButton:SetTemplate(framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    remindersRuleStatusLabel = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    remindersRuleStatusLabel:SetPoint("TOPLEFT", saveButton.widget, "BOTTOMLEFT", 0, -10)
    remindersRuleStatusLabel:SetPoint("TOPRIGHT", formPanel, "TOPRIGHT", -12, 0)
    remindersRuleStatusLabel:SetWidth(REMINDER_FORM_WIDTH)
    remindersRuleStatusLabel:SetJustifyH("LEFT")
    remindersRuleStatusLabel:SetJustifyV("TOP")
    remindersRuleStatusLabel:SetWordWrap(true)
    remindersRuleStatusLabel:SetTextColor(0.85, 0.85, 0.85, 1)

    parent.RefreshOptions = function()
        AP:RefreshRemindersTab()
    end

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

    mainWindow = framework:CreateSimplePanel(UIParent, 1220, 700, "APRaidUtils", "APRaidUtilsMainWindow", {
        UseStatusBar = true,
        DontRightClickClose = true,
    })
    mainWindow:SetPoint("CENTER")
    mainWindow:SetFrameStrata("HIGH")

    mainTabs = framework:CreateTabContainer(mainWindow, "APRaidUtils", "APRaidUtilsMainTabs", tabList, {
        width = 1196,
        height = 660,
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

    BuildSimCTab(framework, mainTabs:GetTabFrameByName("SimC"))
    BuildRosterTab(framework, mainTabs:GetTabFrameByName("Roster"))
    BuildVersionsTab(framework, mainTabs:GetTabFrameByName("Versions"))
    BuildRemindersTab(framework, mainTabs:GetTabFrameByName("Reminders"))
    BuildSettingsTab(framework, mainTabs:GetTabFrameByName("Settings"))

    if mainTabs.SelectTabByName then
        mainTabs:SelectTabByName("SimC")
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
        mainTabs:SelectTabByName(tabName or "SimC")
    end
end

function AP:RefreshSettingsTab()
    if settingsTab and settingsTab.RefreshOptions then
        settingsTab:RefreshOptions()
    end
end

function AP:RefreshVersionsTab()
    if not versionsTab or not versionsResultsScrollBox then
        return
    end

    local versionChecker = self:GetModule("VersionChecker", true)
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

function AP:RefreshRemindersTab()
    if not remindersTab then
        return
    end

    local reminders = self:GetModule("Reminders", true)
    if not reminders then
        return
    end

    if reminders.PrimeReminderData then
        reminders:PrimeReminderData(remindersSelectedRaidFilter)
    end

    if remindersStatusLabel and reminders.GetStatusText then
        UpdateWrappedLabel(remindersStatusLabel, reminders:GetStatusText(), FULL_CONTENT_WIDTH)
    end

    if remindersPlaceholderLabel and reminders.GetPlaceholderLines then
        UpdateWrappedLabel(remindersPlaceholderLabel, table.concat(reminders:GetPlaceholderLines(), "\n"), FULL_CONTENT_WIDTH)
    end

    if remindersRaidDropdown and reminders.GetRaidFilterItems then
        local raidItems = reminders:GetRaidFilterItems(remindersOnlyCurrentExpansion)
        local hasSelectedRaid = remindersSelectedRaidFilter == "ALL"
        for _, item in ipairs(raidItems) do
            if item.value == remindersSelectedRaidFilter then
                hasSelectedRaid = true
                break
            end
        end
        if not hasSelectedRaid and reminders.GetCurrentRaidFilterDefault then
            remindersSelectedRaidFilter = reminders:GetCurrentRaidFilterDefault(remindersOnlyCurrentExpansion)
        end
        remindersRaidDropdown:Refresh()
        remindersRaidDropdown:Select(remindersSelectedRaidFilter, false, false, false)
    end

    if remindersBossDropdown and reminders.GetBossFilterItems then
        local bossItems = reminders:GetBossFilterItems(remindersSelectedRaidFilter)
        local hasSelectedBoss = remindersSelectedBossFilter == "ALL"
        for _, item in ipairs(bossItems) do
            if item.value == remindersSelectedBossFilter then
                hasSelectedBoss = true
                break
            end
        end
        if not hasSelectedBoss and reminders.GetCurrentBossFilterDefault then
            remindersSelectedBossFilter = reminders:GetCurrentBossFilterDefault(remindersSelectedRaidFilter)
        end
        remindersBossDropdown:Refresh()
        remindersBossDropdown:Select(remindersSelectedBossFilter, false, false, false)
    end

    if remindersTimerSearchTextBox then
        remindersTimerSearchTextBox:SetText(remindersTimerSearchText or "")
    end

    if remindersCurrentExpansionCheckbox then
        remindersCurrentExpansionCheckbox:SetChecked(remindersOnlyCurrentExpansion == true)
    end

    local selectedTimerRow = nil

    if remindersObservedScrollBox and reminders.GetDefinitionDisplayRowsForRaid then
        local rows = reminders:GetDefinitionDisplayRowsForRaid(remindersSelectedRaidFilter, remindersSelectedBossFilter, remindersTimerSearchText)

        if remindersSelectedTimerKey then
            local stillExists = false
            for _, row in ipairs(rows) do
                if row.timerKey == remindersSelectedTimerKey then
                    stillExists = true
                    selectedTimerRow = row
                    break
                end
            end
            if not stillExists then
                remindersSelectedTimerKey = nil
                remindersSelectedRuleId = nil
                remindersCreatingNewRule = false
            end
        end

        if not remindersSelectedTimerKey and rows[1] then
            for _, row in ipairs(rows) do
                if row.kind ~= "section" and row.timerKey then
                    remindersSelectedTimerKey = row.timerKey
                    selectedTimerRow = row
                    break
                end
            end
        end

        if remindersSelectedTimerKey and not selectedTimerRow then
            for _, row in ipairs(rows) do
                if row.timerKey == remindersSelectedTimerKey then
                    selectedTimerRow = row
                    break
                end
            end
        end

        remindersObservedScrollBox:SetData(rows)
        remindersObservedScrollBox:Refresh()
    end

    if not remindersSelectedTimerKey then
        remindersActivePage = "browser"
        remindersSelectedRuleId = nil
        remindersCreatingNewRule = false
    end

    if remindersBrowserFrame and remindersDetailsFrame then
        if remindersActivePage == "editor" and remindersSelectedTimerKey then
            remindersBrowserFrame:Hide()
            remindersDetailsFrame:Show()
        else
            remindersBrowserFrame:Show()
            remindersDetailsFrame:Hide()
        end
    end

    local ruleRows = {}
    if reminders.GetRuleListRows then
        ruleRows = reminders:GetRuleListRows(remindersSelectedTimerKey)
    end

    if remindersCreatingNewRule == true and remindersSelectedTimerKey then
        ruleRows[#ruleRows + 1] = {
            ruleId = REMINDER_DRAFT_RULE_ID,
            name = "New Reminder",
            summary = "Unsaved draft",
        }
        if remindersSelectedRuleId ~= REMINDER_DRAFT_RULE_ID then
            remindersSelectedRuleId = REMINDER_DRAFT_RULE_ID
        end
    end

    local selectedRuleRow = nil

    if remindersSelectedRuleId then
        local selectedRuleStillExists = false
        for _, row in ipairs(ruleRows) do
            if row.ruleId == remindersSelectedRuleId then
                selectedRuleStillExists = true
                selectedRuleRow = row
                break
            end
        end

        if not selectedRuleStillExists then
            remindersSelectedRuleId = nil
        end
    end

    if remindersCreatingNewRule ~= true and not remindersSelectedRuleId and ruleRows[1] then
        remindersSelectedRuleId = ruleRows[1].ruleId
    end

    if remindersSelectedRuleId and not selectedRuleRow then
        for _, row in ipairs(ruleRows) do
            if row.ruleId == remindersSelectedRuleId then
                selectedRuleRow = row
                break
            end
        end
    end

    if remindersRuleListHeaderLabel then
        remindersRuleListHeaderLabel:SetText(string.format("Saved Reminders (%d)", #ruleRows))
    end

    if remindersEditorHeaderLabel then
        if selectedTimerRow then
            remindersEditorHeaderLabel:SetText(string.format("%s - %s", tostring(selectedTimerRow.bossName or "Unknown"), tostring(selectedTimerRow.label or "Timer")))
        else
            remindersEditorHeaderLabel:SetText("Timer Reminders")
        end
    end

    if remindersFormHeaderLabel then
        if selectedRuleRow and selectedRuleRow.name then
            remindersFormHeaderLabel:SetText(selectedRuleRow.name)
        elseif remindersCreatingNewRule == true then
            remindersFormHeaderLabel:SetText("New Reminder")
        elseif remindersSelectedRuleId then
            remindersFormHeaderLabel:SetText("Edit Reminder")
        else
            remindersFormHeaderLabel:SetText("Reminder Settings")
        end
    end

    if remindersRuleListScrollBox then
        remindersRuleListScrollBox:SetData(ruleRows)
        remindersRuleListScrollBox:Refresh()
        EnsureReminderRuleSelectionVisible(ruleRows)
    end

    if remindersDetailsLabel and reminders.GetDefinitionDetailLines then
        UpdateWrappedLabel(remindersDetailsLabel, table.concat(reminders:GetDefinitionDetailLines(remindersSelectedTimerKey), "\n"), FULL_CONTENT_WIDTH - 20)
    end

    if reminders.GetRuleEditorState then
        local editorRuleId = remindersSelectedRuleId ~= REMINDER_DRAFT_RULE_ID and remindersSelectedRuleId or nil
        local editorState = reminders:GetRuleEditorState(remindersSelectedTimerKey, editorRuleId)

        if remindersRuleNameTextBox then
            remindersRuleNameTextBox:SetText(editorState.name or "")
            if editorState.hasTimer then
                remindersRuleNameTextBox:Enable()
            else
                remindersRuleNameTextBox:Disable()
            end
        end

        if remindersRuleTextBox then
            remindersRuleTextBox:SetText(editorState.text or "")
            if editorState.hasTimer then
                remindersRuleTextBox:Enable()
            else
                remindersRuleTextBox:Disable()
            end
        end

        if remindersTriggerSecondsTextBox then
            remindersTriggerSecondsTextBox:SetText(editorState.secondsBeforeEnd or "0")
            if editorState.hasTimer then
                remindersTriggerSecondsTextBox:Enable()
            else
                remindersTriggerSecondsTextBox:Disable()
            end
        end

        if remindersOccurrenceTextBox then
            remindersOccurrenceTextBox:SetText(editorState.occurrenceNumber or "0")
            if editorState.hasTimer then
                remindersOccurrenceTextBox:Enable()
            else
                remindersOccurrenceTextBox:Disable()
            end
        end

        if remindersShowBarCheckbox then
            remindersShowBarCheckbox:SetChecked(editorState.showBar == true)
            remindersShowBarCheckbox:SetEnabled(editorState.hasTimer == true)
        end

        if remindersShowCountdownCheckbox then
            remindersShowCountdownCheckbox:SetChecked(editorState.showCountdown == true)
            remindersShowCountdownCheckbox:SetEnabled(editorState.hasTimer == true)
        end

        if remindersAddRuleButton then
            if editorState.hasTimer then
                remindersAddRuleButton:Enable()
            else
                remindersAddRuleButton:Disable()
            end
        end

        if remindersDeleteRuleButton then
            if editorState.hasSelectedRule and remindersSelectedRuleId ~= REMINDER_DRAFT_RULE_ID then
                remindersDeleteRuleButton:Enable()
            else
                remindersDeleteRuleButton:Disable()
            end
        end

        SetReminderRuleStatus(editorState.statusText, 0.85, 0.85, 0.85)
    end

end

function AP:RefreshSimcTab()
    if not simcTab or not simcCharacterDropdown then
        return
    end

    local exportCharacters = AP:GetSimcExportCharacters()
    if #exportCharacters == 0 then
        simcCharacterDropdown:Disable()
        simcCharacterDropdown:Select(false)
        SelectSimcCharacter(nil)
        return
    end

    simcCharacterDropdown:Enable()
    simcCharacterDropdown:Refresh()

    local hasSelectedCharacter = false
    for _, character in ipairs(exportCharacters) do
        if character.key == simcSelectedCharacterKey then
            hasSelectedCharacter = true
            break
        end
    end

    if not hasSelectedCharacter then
        local currentCharacter = AP:GetPlayerCharacterInfo()
        if currentCharacter and currentCharacter.key then
            for _, character in ipairs(exportCharacters) do
                if character.key == currentCharacter.key then
                    simcSelectedCharacterKey = currentCharacter.key
                    hasSelectedCharacter = true
                    break
                end
            end
        end
    end

    if not hasSelectedCharacter then
        simcSelectedCharacterKey = exportCharacters[1].key
    end

    simcCharacterDropdown:Select(simcSelectedCharacterKey, false, false, false)
    SelectSimcCharacter(simcSelectedCharacterKey)
end
