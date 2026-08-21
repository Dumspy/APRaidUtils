local AP = _G["APRaidUtils"]

local mainWindow
local mainTabs
local rosterInputEditor
local rosterStatusLabel
local rosterPreviewScrollBox
local versionsTab
local versionsStatusLabel
local versionsResultsScrollBox
local settingsTab
local settingsTabRefreshBase

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
    local versionChecker = AP.VersionChecker
    if versionChecker and versionChecker.RequestVersionCheck then
        versionChecker:RequestVersionCheck()
        return
    end

    AP:Print("Version checker is unavailable.")
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

    local function RefreshSettingsOptions()
        parent.RefreshOptions = settingsTabRefreshBase or function()
        end

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

