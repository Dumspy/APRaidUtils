local AP = _G["APRaidUtils"]

local APAnchor = {}
AP.APAnchor = APAnchor

local DF = LibStub("DetailsFramework-1.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local anchors = {}
local anchorFrames = {}
local rightClickMenus = {}
local allAnchorsVisible = false

local function MigrateFont(font)
    return font
end

local defaultAnchorDefaults = {
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 1.0,
    fontSize = 14,
    maxWidth = 300,
    maxHeight = 60,
    font = "Friz Quadrata TT",
    colorR = 1.0,
    colorG = 0.82,
    colorB = 0,
    opacity = 1.0,
    outline = false,
    locked = false,
}

local DEFAULT_LABEL_FONT_OBJECT = "GameFontNormal"

local function GetAnchorsDB()
    if not APRaidUtilsDB or type(APRaidUtilsDB.profile) ~= "table" then
        return nil
    end

    if type(APRaidUtilsDB.profile.anchors) ~= "table" then
        APRaidUtilsDB.profile.anchors = {}
    end

    return APRaidUtilsDB.profile.anchors
end

local function GetAnchorDB(key)
    local anchorsDB = GetAnchorsDB()
    if not anchorsDB then
        return nil
    end

    if type(anchorsDB[key]) ~= "table" then
        anchorsDB[key] = {}
    end

    return anchorsDB[key]
end

local function GetMergedSettings(key, userDefaults)
    local db = GetAnchorDB(key)
    local settings = {}
    for k, v in pairs(defaultAnchorDefaults) do
        settings[k] = v
    end
    if userDefaults then
        for k, v in pairs(userDefaults) do
            settings[k] = v
        end
    end
    if db then
        for k, v in pairs(db) do
            settings[k] = v
        end
    end
    if settings.font then
        settings.font = MigrateFont(settings.font)
    end
    return settings
end

local function SaveAnchorSetting(key, setting, value)
    local db = GetAnchorDB(key)
    if db then
        db[setting] = value
    end
end

local function ResolveAnchorFont(fontValue, fontString)
    if fontValue and fontValue ~= "" then
        local sharedMediaFont = SharedMedia:Fetch("font", fontValue, true)
        if sharedMediaFont then
            local _, _, currentFlags = fontString:GetFont()
            return sharedMediaFont, currentFlags or ""
        end

        local fontObject = _G[fontValue]
        if fontObject and fontObject.GetFont then
            local fontFile, _, fontFlags = fontObject:GetFont()
            if fontFile then
                return fontFile, fontFlags or ""
            end
        end
    end

    local currentFontFile, _, currentFlags = fontString:GetFont()
    if currentFontFile then
        return currentFontFile, currentFlags or ""
    end

    local defaultFontObject = _G[defaultAnchorDefaults.font]
    if defaultFontObject and defaultFontObject.GetFont then
        local defaultFontFile, _, defaultFontFlags = defaultFontObject:GetFont()
        if defaultFontFile then
            return defaultFontFile, defaultFontFlags or ""
        end
    end

    local sharedMediaDefault = SharedMedia:GetDefault("font")
    if sharedMediaDefault then
        local defaultSharedMediaFont = SharedMedia:Fetch("font", sharedMediaDefault, true)
        if defaultSharedMediaFont then
            return defaultSharedMediaFont, ""
        end
    end
end

local function ApplyAnchorOutline(fontFlags, outlineEnabled)
    local flags = {}

    for flag in string.gmatch(fontFlags or "", "[^,]+") do
        if flag ~= "" and flag ~= "OUTLINE" and flag ~= "THICKOUTLINE" then
            flags[#flags + 1] = flag
        end
    end

    if outlineEnabled then
        flags[#flags + 1] = "OUTLINE"
    end

    return table.concat(flags, ",")
end

local function GetFontDropdownValue(fontValue)
    if fontValue and fontValue ~= "" and SharedMedia:Fetch("font", fontValue, true) then
        return fontValue
    end

    return "DEFAULT"
end

local function RoundAnchorValue(value)
    return math.floor((value or 0) + 0.5)
end

local function HideSettingsPanel(frame)
    if frame.SettingsPanel and frame.SettingsPanel:IsShown() then
        frame.SettingsPanel:Hide()
    end
end

local function SetAnchorFrameShown(frame, shown)
    frame.APInternalVisibilityChange = true
    frame:SetShown(shown)
    frame.APInternalVisibilityChange = false
end

local function UpdateAnchorFrameEditState(frame, settings)
    if not allAnchorsVisible then
        frame:EnableMouse(false)
        frame.UnlockOverlay:Hide()
        frame.DragTexture:Hide()
        frame:SetBackdropBorderColor(0, 0, 0, 0)
        HideSettingsPanel(frame)
        return
    end

    frame:EnableMouse(true)

    if settings.locked then
        frame.UnlockOverlay:Hide()
        frame.DragTexture:Hide()
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        return
    end

    frame.UnlockOverlay:Show()
    frame.DragTexture:Show()

    if frame.APIsMouseOver then
        frame:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    else
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
    end
end

local function RefreshAnchorFrameVisibility(frame)
    local shouldShow = (allAnchorsVisible or frame.APFeatureVisible) and not frame.APTemporaryHidden

    if frame:IsShown() ~= shouldShow then
        SetAnchorFrameShown(frame, shouldShow)
    end

    if shouldShow then
        local settings = GetMergedSettings(frame.AnchorKey, frame.UserDefaults)
        UpdateAnchorFrameEditState(frame, settings)
    else
        HideSettingsPanel(frame)
    end
end

local function ApplySettingsToFrame(frame, settings)
    local relativeTo = settings.relativeTo and _G[settings.relativeTo] or UIParent
    frame:ClearAllPoints()
    frame:SetPoint(
        settings.point or "CENTER",
        relativeTo,
        settings.relativePoint or "CENTER",
        settings.x or 0,
        settings.y or 0
    )
    frame:SetScale(settings.scale or 1.0)
    frame:SetSize(settings.maxWidth or 300, settings.maxHeight or 60)

    if frame.Text then
        local fontSize = math.min(settings.fontSize or 14, 72)
        local fontFile, fontFlags = ResolveAnchorFont(settings.font, frame.Text)
        if fontFile then
            frame.Text:SetFont(fontFile, fontSize, ApplyAnchorOutline(fontFlags, settings.outline == true))
        end
        frame.Text:SetTextColor(
            settings.colorR or 1.0,
            settings.colorG or 0.82,
            settings.colorB or 0,
            settings.opacity or 1.0
        )
        frame.Text:SetWidth((settings.maxWidth or 300) - 10)
        frame.Text:SetWordWrap(true)
    end

    UpdateAnchorFrameEditState(frame, settings)
end

local function PositionSettingsPanel(panel, anchorFrame, key)
    panel:ClearAllPoints()

    local db = GetAnchorDB(key)
    if
        db
        and db.settingsPanelDetached
        and type(db.settingsPanelPosition) == "table"
        and db.settingsPanelPosition.x ~= nil
        and db.settingsPanelPosition.y ~= nil
    then
        DF:RestoreFramePosition(panel)
        return
    end

    local screenWidth = UIParent:GetWidth() or 1920
    local screenHeight = UIParent:GetHeight() or 1080
    local panelWidth = panel:GetWidth() or 280
    local panelHeight = panel:GetHeight() or 400
    local anchorLeft = anchorFrame:GetLeft() or 0
    local anchorRight = anchorFrame:GetRight() or 0
    local anchorTop = anchorFrame:GetTop() or screenHeight

    local x
    if anchorRight > (screenWidth * 0.5) then
        x = anchorRight - panelWidth - 20
    else
        x = anchorLeft + 20
    end

    local y = math.min(anchorTop, screenHeight - 20)

    x = math.max(20, math.min(x, screenWidth - panelWidth - 20))
    y = math.max(panelHeight + 20, y)

    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function BuildSettingsPanel(frame, key)
    if frame.SettingsPanel then
        return frame.SettingsPanel
    end

    local settings = GetMergedSettings(key, frame.UserDefaults)

    local panel = DF:CreateSimplePanel(UIParent, 280, 400, "Anchor Settings", nil, {
        UseStatusBar = false,
        DontRightClickClose = true,
        Strata = "DIALOG",
    })
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:Hide()

    local db = GetAnchorDB(key)
    if db then
        if type(db.settingsPanelPosition) ~= "table" then
            db.settingsPanelPosition = {}
        end

        panel.db = {
            position = db.settingsPanelPosition,
        }
    end

    panel:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local x, y = DF:GetPositionOnScreen(self)
        self.APMouseDownX = x
        self.APMouseDownY = y
    end)

    panel:HookScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not db or not db.settingsPanelPosition then
            return
        end

        local x, y = DF:GetPositionOnScreen(self)
        if not x or not y then
            return
        end

        db.settingsPanelPosition.x = x
        db.settingsPanelPosition.y = y

        if
            self.APMouseDownX
            and self.APMouseDownY
            and (math.abs(x - self.APMouseDownX) > 1 or math.abs(y - self.APMouseDownY) > 1)
        then
            db.settingsPanelDetached = true
        end
    end)

    local yOffset = -10

    local sizeLabel = DF:CreateLabel(panel, "Text Size", 10, "orange")
    sizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local sizeSlider =
        DF:CreateSlider(panel, 200, 16, 10, 72, 1, settings.fontSize, false, nil, "$parentSizeSlider", "Size:")
    sizeSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    sizeSlider:SetValue(math.min(settings.fontSize or 14, 72))
    sizeSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = RoundAnchorValue(value or settings.fontSize or 14)
        SaveAnchorSetting(key, "fontSize", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local widthLabel = DF:CreateLabel(panel, "Max Width", 10, "orange")
    widthLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local widthSlider = DF:CreateSlider(
        panel,
        200,
        16,
        100,
        2000,
        10,
        settings.maxWidth or 300,
        false,
        nil,
        "$parentWidthSlider",
        "Width:"
    )
    widthSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    widthSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    widthSlider:SetValue(settings.maxWidth or 300)
    widthSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = RoundAnchorValue(value or settings.maxWidth or 300)
        SaveAnchorSetting(key, "maxWidth", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local heightLabel = DF:CreateLabel(panel, "Max Height", 10, "orange")
    heightLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local heightSlider = DF:CreateSlider(
        panel,
        200,
        16,
        20,
        1000,
        10,
        settings.maxHeight or 60,
        false,
        nil,
        "$parentHeightSlider",
        "Height:"
    )
    heightSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    heightSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    heightSlider:SetValue(settings.maxHeight or 60)
    heightSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = RoundAnchorValue(value or settings.maxHeight or 60)
        SaveAnchorSetting(key, "maxHeight", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local fontLabel = DF:CreateLabel(panel, "Font", 10, "orange")
    fontLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local fontDropdown = DF:CreateFontDropDown(
        panel,
        function(_, _, value)
            if value == "DEFAULT" then
                SaveAnchorSetting(key, "font", nil)
            else
                SaveAnchorSetting(key, "font", value)
            end

            local currentSettings = GetMergedSettings(key, frame.UserDefaults)
            ApplySettingsToFrame(frame, currentSettings)
        end,
        GetFontDropdownValue(settings.font),
        240,
        20,
        nil,
        "$parentFontDropdown",
        DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"),
        true
    )
    fontDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    frame.fontDropdown = fontDropdown
    yOffset = yOffset - 30

    local colorLabel = DF:CreateLabel(panel, "Color", 10, "orange")
    colorLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local colorButton = DF:CreateButton(panel, function()
        local r, g, b = settings.colorR or 1.0, settings.colorG or 0.82, settings.colorB or 0
        local opacity = settings.opacity or 1.0

        local info = {
            swatchFunc = function()
                local cr, cg, cb = ColorPickerFrame:GetColorRGB()
                SaveAnchorSetting(key, "colorR", cr)
                SaveAnchorSetting(key, "colorG", cg)
                SaveAnchorSetting(key, "colorB", cb)
                local currentSettings = GetMergedSettings(key, frame.UserDefaults)
                ApplySettingsToFrame(frame, currentSettings)
            end,
            hasOpacity = true,
            opacityFunc = function()
                local o = ColorPickerFrame:GetColorAlpha()
                SaveAnchorSetting(key, "opacity", o)
                local currentSettings = GetMergedSettings(key, frame.UserDefaults)
                ApplySettingsToFrame(frame, currentSettings)
            end,
            opacity = opacity,
            cancelFunc = function()
                SaveAnchorSetting(key, "colorR", r)
                SaveAnchorSetting(key, "colorG", g)
                SaveAnchorSetting(key, "colorB", b)
                SaveAnchorSetting(key, "opacity", opacity)
                local currentSettings = GetMergedSettings(key, frame.UserDefaults)
                ApplySettingsToFrame(frame, currentSettings)
            end,
            r = r,
            g = g,
            b = b,
            extraInfo = key,
        }

        ColorPickerFrame:Hide()
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end, 240, 22, "Pick Color")
    colorButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    colorButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
    yOffset = yOffset - 32
    local opacityLabel = DF:CreateLabel(panel, "Opacity", 10, "orange")
    opacityLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local opacitySlider =
        DF:CreateSlider(panel, 240, 16, 0.1, 1.0, 0.05, settings.opacity, true, nil, "$parentOpacitySlider", "Opacity:")
    opacitySlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    opacitySlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    opacitySlider:SetValue(settings.opacity or 1.0)
    opacitySlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        SaveAnchorSetting(key, "opacity", value)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local outlineSwitch = DF:CreateSwitch(panel, function(_, _, value)
        SaveAnchorSetting(key, "outline", value)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end, settings.outline or false, 20, 20, nil, nil, nil, "$parentOutlineSwitch")
    outlineSwitch:SetAsCheckBox()
    outlineSwitch:SetTemplate(DF:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
    outlineSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    local outlineLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    outlineLabel:SetPoint("LEFT", outlineSwitch.widget, "RIGHT", 6, 0)
    outlineLabel:SetText("Text Outline")
    outlineLabel:SetTextColor(0.9, 0.9, 0.9, 1)
    yOffset = yOffset - 30

    local lockSwitch = DF:CreateSwitch(panel, function(_, _, value)
        SaveAnchorSetting(key, "locked", value)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end, settings.locked or false, 20, 20, nil, nil, nil, "$parentLockSwitch")
    lockSwitch:SetAsCheckBox()
    lockSwitch:SetTemplate(DF:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
    lockSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    local lockLabelManual = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lockLabelManual:SetPoint("LEFT", lockSwitch.widget, "RIGHT", 6, 0)
    lockLabelManual:SetText("Lock Position")
    lockLabelManual:SetTextColor(0.9, 0.9, 0.9, 1)
    yOffset = yOffset - 30

    local hideButton = DF:CreateButton(panel, function()
        frame.APTemporaryHidden = true
        panel:Hide()
        RefreshAnchorFrameVisibility(frame)
    end, 240, 22, "Hide Anchor")
    hideButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    hideButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    local menuBuilder = rightClickMenus[key]
    if menuBuilder then
        yOffset = yOffset - 40
        menuBuilder(panel, frame, key, settings, function()
            ApplySettingsToFrame(frame, settings)
        end, function(newSettings)
            settings = newSettings
        end, yOffset)
    end

    frame.SettingsPanel = panel
    return panel
end

local function CreateAnchorFrame(key, userDefaults)
    if anchorFrames[key] then
        return anchorFrames[key]
    end

    local settings = GetMergedSettings(key, userDefaults)

    local frame = CreateFrame("Frame", "APRaidUtilsAnchor_" .. key, UIParent, "BackdropTemplate")
    frame:SetSize(300, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tileSize = 64,
        tile = true,
    })
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)

    local text = DF:CreateLabel(
        frame,
        settings.text or "",
        math.min(settings.fontSize or 14, 72),
        { settings.colorR or 1.0, settings.colorG or 0.82, settings.colorB or 0, settings.opacity or 1.0 },
        DEFAULT_LABEL_FONT_OBJECT,
        "Text",
        "$parentText",
        "OVERLAY"
    )
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWidth((settings.maxWidth or 300) - 10)
    text:SetWordWrap(true)
    frame.Text = text

    local unlockOverlay = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockOverlay:SetPoint("BOTTOM", frame, "BOTTOM", 0, -12)
    unlockOverlay:SetText("[UNLOCKED - Drag to move]")
    unlockOverlay:SetTextColor(1, 0.5, 0, 0.8)
    unlockOverlay:Hide()
    frame.UnlockOverlay = unlockOverlay

    local dragTexture = frame:CreateTexture(nil, "ARTWORK")
    dragTexture:SetAllPoints(frame)
    dragTexture:SetColorTexture(0.3, 0.2, 0.05, 0.15)
    dragTexture:Hide()
    frame.DragTexture = dragTexture
    frame.APFeatureVisible = false
    frame.APTemporaryHidden = false
    frame.APIsMouseOver = false

    frame:SetScript("OnDragStart", function()
        if not allAnchorsVisible then
            return
        end
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        if currentSettings.locked then
            return
        end
        frame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = frame:GetPoint()
        local relativeToName = relativeTo and relativeTo:GetName()
        SaveAnchorSetting(key, "point", point or "CENTER")
        SaveAnchorSetting(key, "relativeTo", relativeToName or "UIParent")
        SaveAnchorSetting(key, "relativePoint", relativePoint or "CENTER")
        SaveAnchorSetting(key, "x", x or 0)
        SaveAnchorSetting(key, "y", y or 0)
    end)

    frame:SetScript("OnEnter", function()
        frame.APIsMouseOver = true
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        UpdateAnchorFrameEditState(frame, currentSettings)
    end)

    frame:SetScript("OnLeave", function()
        frame.APIsMouseOver = false
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        UpdateAnchorFrameEditState(frame, currentSettings)
    end)

    frame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and allAnchorsVisible then
            local panel = BuildSettingsPanel(frame, key)
            if panel:IsShown() then
                panel:Hide()
            else
                PositionSettingsPanel(panel, frame, key)
                panel:Show()
            end
        end
    end)

    frame.UserDefaults = userDefaults or {}
    frame.AnchorKey = key

    frame:HookScript("OnShow", function()
        if frame.APInternalVisibilityChange then
            return
        end

        frame.APFeatureVisible = true
        frame.APTemporaryHidden = false
        RefreshAnchorFrameVisibility(frame)
    end)

    frame:HookScript("OnHide", function()
        if frame.APInternalVisibilityChange then
            return
        end

        frame.APFeatureVisible = false
        RefreshAnchorFrameVisibility(frame)
    end)

    ApplySettingsToFrame(frame, settings)

    anchorFrames[key] = frame
    return frame
end

function APAnchor:CreateAnchor(key, userDefaults)
    if anchors[key] then
        return anchorFrames[key]
    end

    anchors[key] = true

    local frame = CreateAnchorFrame(key, userDefaults)
    RefreshAnchorFrameVisibility(frame)

    return frame
end

function APAnchor:GetAnchorData(key)
    return GetMergedSettings(key, nil)
end

function APAnchor:UpdateAnchorText(key, text)
    local frame = anchorFrames[key]
    if frame and frame.Text then
        frame.Text:SetText(text or "")
    end
end

function APAnchor:SetAnchorVisible(key, visible)
    local frame = anchorFrames[key]
    if not frame then
        return
    end

    frame.APFeatureVisible = visible == true
    if not frame.APFeatureVisible then
        frame.APTemporaryHidden = false
    end

    RefreshAnchorFrameVisibility(frame)
end

function APAnchor:ShowAllAnchors()
    allAnchorsVisible = true
    for key in pairs(anchors) do
        local frame = anchorFrames[key]
        if frame then
            frame.APTemporaryHidden = false
            RefreshAnchorFrameVisibility(frame)
        end
    end
end

function APAnchor:HideAllAnchors()
    allAnchorsVisible = false
    for key in pairs(anchors) do
        local frame = anchorFrames[key]
        if frame then
            frame.APTemporaryHidden = false
            RefreshAnchorFrameVisibility(frame)
        end
    end
end

function APAnchor:IsAnchorsVisible()
    return allAnchorsVisible
end

function APAnchor:ToggleAllAnchors()
    if allAnchorsVisible then
        self:HideAllAnchors()
    else
        self:ShowAllAnchors()
    end
    return allAnchorsVisible
end

function APAnchor:RegisterRightClickMenu(key, buildMenuFunc)
    rightClickMenus[key] = buildMenuFunc
end

AP.APAnchor = APAnchor
