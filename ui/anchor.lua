local AP = _G["APRaidUtils"]

local APAnchor = {}
AP.APAnchor = APAnchor

local DF = LibStub("DetailsFramework-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

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
    locked = false,
}

local function GetAnchorDB(key)
    if not AP.db or not AP.db.profile then
        return nil
    end
    if not AP.db.profile.anchors then
        AP.db.profile.anchors = {}
    end
    if not AP.db.profile.anchors[key] then
        AP.db.profile.anchors[key] = {}
    end
    return AP.db.profile.anchors[key]
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

local function ApplySettingsToFrame(frame, settings)
    local relativeTo = settings.relativeTo and _G[settings.relativeTo] or UIParent
    frame:ClearAllPoints()
    frame:SetPoint(settings.point or "CENTER", relativeTo, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame:SetScale(settings.scale or 1.0)
    frame:SetSize(settings.maxWidth or 300, settings.maxHeight or 60)

    if frame.Text then
        local fontSize = settings.fontSize or 14
        local fontName = settings.font or "Friz Quadrata TT"
        if not LSM:IsValid("font", fontName) then
            fontName = "Friz Quadrata TT"
        end
        local fontPath = LSM:Fetch("font", fontName)
        frame.Text:SetFont(fontPath, fontSize, "")
        frame.Text:SetTextColor(settings.colorR or 1.0, settings.colorG or 0.82, settings.colorB or 0, settings.opacity or 1.0)
        frame.Text:SetWidth((settings.maxWidth or 300) - 10)
        frame.Text:SetWordWrap(true)
    end

    if settings.locked then
        frame.UnlockOverlay:Hide()
        frame.DragTexture:Hide()
    else
        frame.UnlockOverlay:Show()
        frame.DragTexture:Show()
    end
end

local function HideSettingsPanel(frame)
    if frame.SettingsPanel and frame.SettingsPanel:IsShown() then
        frame.SettingsPanel:Hide()
    end
end

local function PositionSettingsPanel(panel, anchorFrame)
    panel:ClearAllPoints()
    
    local anchorRight = anchorFrame:GetRight() or 0
    local screenWidth = UIParent:GetWidth() or 1920
    local anchorFrameRight = anchorRight / screenWidth
    
    if anchorFrameRight > 0.5 then
        panel:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", 20, 0)
    else
        panel:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", -20, 0)
    end
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
    panel:Hide()

    PositionSettingsPanel(panel, frame)

    local yOffset = -10

    local sizeLabel = DF:CreateLabel(panel, "Text Size", 10, "orange")
    sizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local sizeSlider = DF:CreateSlider(panel, 200, 16, 10, 32, 1, settings.fontSize, false, nil, "$parentSizeSlider", "Size:")
    sizeSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    sizeSlider:SetValue(settings.fontSize or 14)
    sizeSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = math.floor((value or settings.fontSize or 14) + 0.5)
        SaveAnchorSetting(key, "fontSize", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local widthLabel = DF:CreateLabel(panel, "Max Width", 10, "orange")
    widthLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local widthSlider = DF:CreateSlider(panel, 200, 16, 100, 1000, 10, settings.maxWidth or 300, false, nil, "$parentWidthSlider", "Width:")
    widthSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    widthSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    widthSlider:SetValue(settings.maxWidth or 300)
    widthSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = math.floor((value or settings.maxWidth or 300) + 0.5)
        SaveAnchorSetting(key, "maxWidth", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local heightLabel = DF:CreateLabel(panel, "Max Height", 10, "orange")
    heightLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local heightSlider = DF:CreateSlider(panel, 200, 16, 20, 400, 10, settings.maxHeight or 60, false, nil, "$parentHeightSlider", "Height:")
    heightSlider:SetTemplate(DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"))
    heightSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    heightSlider:SetValue(settings.maxHeight or 60)
    heightSlider:SetValueChangedFunction(function(self)
        local value = self:GetValue()
        local fixedValue = math.floor((value or settings.maxHeight or 60) + 0.5)
        SaveAnchorSetting(key, "maxHeight", fixedValue)
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        ApplySettingsToFrame(frame, currentSettings)
    end)
    yOffset = yOffset - 40

    local fontLabel = DF:CreateLabel(panel, "Font", 10, "orange")
    fontLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 18

    local fontDropdown = DF:CreateDropDown(panel, function()
        local options = {}
        for _, fontName in ipairs(LSM:List("font")) do
            options[#options + 1] = {
                value = fontName,
                label = fontName,
                onclick = function()
                    SaveAnchorSetting(key, "font", fontName)
                    local currentSettings = GetMergedSettings(key, frame.UserDefaults)
                    ApplySettingsToFrame(frame, currentSettings)
                    if frame.fontDropdown then
                        frame.fontDropdown:Select(fontName, false, false, false)
                    end
                end,
            }
        end
        return options
    end, settings.font or "Friz Quadrata TT", 240, 20, nil, "$parentFontDropdown", DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
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

    local opacitySlider = DF:CreateSlider(panel, 240, 16, 0.1, 1.0, 0.05, settings.opacity, true, nil, "$parentOpacitySlider", "Opacity:")
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

    local lockSwitch, lockLabel = DF:CreateSwitch(panel, function(_, _, value)
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
        panel:Hide()
        frame:Hide()
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

    local text = DF:CreateLabel(frame, settings.text or "", settings.fontSize or 14, {settings.colorR or 1.0, settings.colorG or 0.82, settings.colorB or 0, settings.opacity or 1.0}, "Friz Quadrata TT", "Text", "$parentText", "OVERLAY")
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
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        if not currentSettings.locked then
            frame:SetBackdropBorderColor(1, 0.82, 0, 0.8)
        end
    end)

    frame:SetScript("OnLeave", function()
        local currentSettings = GetMergedSettings(key, frame.UserDefaults)
        if not currentSettings.locked then
            frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        end
    end)

    frame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and allAnchorsVisible then
            local panel = BuildSettingsPanel(frame, key)
            if panel:IsShown() then
                panel:Hide()
            else
                panel:Show()
            end
        end
    end)

    frame.UserDefaults = userDefaults or {}
    frame.AnchorKey = key

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

    if allAnchorsVisible then
        frame:Show()
    else
        frame:Hide()
    end

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

function APAnchor:ShowAllAnchors()
    allAnchorsVisible = true
    for key in pairs(anchors) do
        local frame = anchorFrames[key]
        if frame then
            frame:Show()
        end
    end
end

function APAnchor:HideAllAnchors()
    allAnchorsVisible = false
    for key in pairs(anchors) do
        local frame = anchorFrames[key]
        if frame then
            frame:Hide()
            HideSettingsPanel(frame)
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
