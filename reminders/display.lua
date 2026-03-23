local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local ReminderDisplay = AP:NewModule("ReminderDisplay", "AceEvent-3.0")

local activeRows = {}
local anchorFrame
local previewMode = false
local previewRows = {}

local FONT_PATH = [[Fonts\FRIZQT__.TTF]]

local function GetFramework()
    return LibStub("DetailsFramework-1.0", true) or _G.DetailsFramework
end

local function GetStorage()
    local reminders = AP:GetModule("Reminders", true)
    if reminders and reminders.GetStorage then
        return reminders:GetStorage()
    end
    return nil
end

local function GetDisplaySettings()
    local storage = GetStorage()
    return storage and storage.display or {}
end

local function GetReminderTextSize()
    local textSize = tonumber(GetDisplaySettings().textSize)
    if not textSize or textSize < 12 then
        return 28
    end

    return textSize
end

local function GetMaxVisibleReminders()
    local maxVisible = tonumber(GetDisplaySettings().maxVisible)
    if not maxVisible or maxVisible < 1 then
        return 3
    end

    return math.floor(maxVisible)
end

local function GetTextRowHeight()
    return GetReminderTextSize() + 12
end

local function GetBarRowHeight()
    return math.max(34, GetReminderTextSize() + 12)
end

local function GetAnchorBackdropColor(isPreview)
    if isPreview then
        return 0.08, 0.08, 0.12, 0.85
    end

    return 0, 0, 0, 0
end

local function GetAnchorBorderColor(isPreview)
    if isPreview then
        return 1, 0.82, 0, 0.9
    end

    return 0, 0, 0, 0
end

local function EnsureAnchor()
    if anchorFrame then
        return anchorFrame
    end

    anchorFrame = CreateFrame("Frame", "APRaidUtilsReminderAnchor", UIParent, "BackdropTemplate")
    anchorFrame:SetSize(320, 40)
    anchorFrame:SetFrameStrata("HIGH")
    anchorFrame:SetClampedToScreen(true)
    anchorFrame:SetMovable(true)
    anchorFrame:EnableMouse(true)
    anchorFrame:RegisterForDrag("LeftButton")
    anchorFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    anchorFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local storage = GetStorage()
        if not storage then
            return
        end

        local point, _, relativePoint, x, y = self:GetPoint(1)
        storage.display.point = point
        storage.display.relativePoint = relativePoint
        storage.display.x = x
        storage.display.y = y
    end)
    anchorFrame:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    anchorFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.2)
    anchorFrame:SetBackdropBorderColor(0.2, 0.2, 0.24, 0.5)

    local title = anchorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    title:SetText("APRaidUtils Reminders")
    title:SetTextColor(1, 0.82, 0, 0.8)
    anchorFrame.Title = title
    anchorFrame:Hide()

    return anchorFrame
end

local function UpdateAnchorAppearance(isPreview, hasRows)
    local frame = EnsureAnchor()
    local r, g, b, a = GetAnchorBackdropColor(isPreview)
    frame:SetBackdropColor(r, g, b, a)
    r, g, b, a = GetAnchorBorderColor(isPreview)
    frame:SetBackdropBorderColor(r, g, b, a)
    frame.Title:SetShown(isPreview)
    frame.Title:SetText(isPreview and "Drag to position reminders" or "APRaidUtils Reminders")
    frame:EnableMouse(isPreview)
    frame:SetSize(320, isPreview and 40 or 1)
end

local function ApplyAnchorPosition()
    local storage = GetStorage()
    local frame = EnsureAnchor()
    frame:ClearAllPoints()

    if storage and storage.display then
        frame:SetPoint(storage.display.point or "CENTER", UIParent, storage.display.relativePoint or "CENTER", storage.display.x or 0, storage.display.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function CreateRow(index)
    local parent = EnsureAnchor()
    local row = CreateFrame("Frame", "APRaidUtilsReminderRow" .. index, parent)
    row:SetSize(420, GetBarRowHeight())

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Icon:SetSize(28, 28)
    row.Icon:SetTexture([[Interface\Icons\INV_Misc_PocketWatch_01]])
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.Text:SetJustifyH("CENTER")
    row.Text:SetJustifyV("MIDDLE")
    row.Text:SetWordWrap(false)
    row.Text:SetShadowOffset(1, -1)

    row.Countdown = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.Countdown:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.Countdown:SetTextColor(1, 0.82, 0, 1)
    row.Countdown:SetShadowOffset(1, -1)

    row.Bar = CreateFrame("StatusBar", nil, row, "BackdropTemplate")
    row.Bar:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, 0)
    row.Bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.Bar:SetHeight(GetBarRowHeight())
    if row.Bar.SetStatusBarTexture then
        row.Bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
    end
    row.Bar:SetMinMaxValues(0, 1)
    row.Bar:SetValue(1)
    row.Bar:SetStatusBarColor(0.2, 0.7, 1, 1)
    row.Bar:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 64,
    })
    row.Bar:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
    row.Bar:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)
    row.Bar.Background = row.Bar:CreateTexture(nil, "BACKGROUND")
    row.Bar.Background:SetAllPoints()
    row.Bar.Background:SetColorTexture(0.1, 0.1, 0.12, 0.85)
    row.Bar.TimeText = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Bar.TimeText:SetPoint("RIGHT", row.Bar, "RIGHT", -10, 0)
    row.Bar.TimeText:SetTextColor(0.9, 0.95, 1, 1)
    row.Bar.TimeText:SetShadowOffset(1, -1)

    row.BarText = row.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.BarText:SetPoint("LEFT", row.Bar, "LEFT", 12, 0)
    row.BarText:SetPoint("RIGHT", row.Bar.TimeText, "LEFT", -10, 0)
    row.BarText:SetJustifyH("LEFT")
    row.BarText:SetJustifyV("MIDDLE")
    row.BarText:SetShadowOffset(1, -1)

    row:Hide()
    activeRows[index] = row
    return row
end

local function GetRow(index)
    return activeRows[index] or CreateRow(index)
end

function ReminderDisplay:OnInitialize()
    ApplyAnchorPosition()
    UpdateAnchorAppearance(false, false)
end

function ReminderDisplay:IsPreviewMode()
    return previewMode
end

function ReminderDisplay:SetPreviewMode(enabled)
    previewMode = enabled == true
    if previewMode then
        previewRows = {
            {
                renderedText = "Preview reminder 6",
                countdownText = "6",
                showCountdown = true,
                showBar = true,
                duration = 8,
                remaining = 6,
                icon = 136116,
            },
            {
                renderedText = "Centered text reminder",
                countdownText = "3",
                showCountdown = true,
                showBar = false,
                duration = 4,
                remaining = 3,
                icon = 135826,
            },
            {
                renderedText = "Second stacked reminder",
                countdownText = "2",
                showCountdown = false,
                showBar = true,
                duration = 4,
                remaining = 2,
                icon = 135826,
            },
        }
        self:UpdateLayout(previewRows)
        return
    end

    previewRows = {}
    self:UpdateLayout({})
end

function ReminderDisplay:UpdateLayout(reminders)
    ApplyAnchorPosition()

    local storage = GetStorage()
    local spacing = storage and storage.display and storage.display.spacing or 8
    local textSize = GetReminderTextSize()
    local maxVisible = GetMaxVisibleReminders()
    local count = 0

    if previewMode and #reminders == 0 then
        reminders = previewRows
    end

    for index, reminder in ipairs(reminders) do
        if index > maxVisible then
            break
        end

        count = count + 1
        local row = GetRow(count)
        row:ClearAllPoints()
        local isBar = reminder.showBar == true
        local rowHeight = isBar and GetBarRowHeight() or GetTextRowHeight()
        row:SetHeight(rowHeight)
        row.Icon:SetSize(rowHeight, rowHeight)
        row.Text:SetFont(FONT_PATH, textSize, "OUTLINE")
        row.Countdown:SetFont(FONT_PATH, math.max(16, textSize - 4), "OUTLINE")
        row.BarText:SetFont(FONT_PATH, math.max(14, textSize - 8), "OUTLINE")
        row.Bar.TimeText:SetFont(FONT_PATH, math.max(12, textSize - 10), "OUTLINE")
        if count == 1 then
            row:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -spacing)
        else
            row:SetPoint("TOP", activeRows[count - 1], "BOTTOM", 0, -spacing)
        end
        row:SetShown(true)
        row.Icon:SetTexture(reminder.icon or [[Interface\Icons\INV_Misc_PocketWatch_01]])
        row.Countdown:SetShown(reminder.showCountdown == true)
        row.Countdown:SetText(reminder.countdownText or "")
        row.Bar:SetShown(reminder.showBar == true)
        row.Icon:SetShown(reminder.showBar == true)
        if reminder.showBar then
            row.Text:SetShown(false)
            row.BarText:SetShown(true)
            row.BarText:SetText(reminder.renderedText or "")
            row.Bar:SetHeight(rowHeight)
            row.Bar:SetMinMaxValues(0, reminder.duration > 0 and reminder.duration or 1)
            row.Bar:SetValue(reminder.remaining > 0 and reminder.remaining or 0)
            row.Bar.TimeText:SetText(string.format("%.1fs", math.max(0, reminder.remaining or 0)))
            row.Bar.TimeText:SetShown(true)
        else
            row.Text:SetShown(true)
            row.Text:SetText(reminder.renderedText or "")
            row.Text:ClearAllPoints()
            if reminder.showCountdown then
                row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.Text:SetPoint("RIGHT", row.Countdown, "LEFT", -12, 0)
            else
                row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.Text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            end
            row.BarText:SetShown(false)
            row.Bar.TimeText:SetShown(false)
        end

        if isBar then
            row:SetWidth(420)
        else
            row:SetWidth(math.max(220, row.Text:GetStringWidth() + (reminder.showCountdown and 90 or 20)))
        end
    end

    for index = count + 1, #activeRows do
        activeRows[index]:Hide()
    end

    anchorFrame:SetShown(previewMode or count > 0)
    UpdateAnchorAppearance(previewMode, count > 0)
end
