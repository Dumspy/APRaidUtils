local AP = _G["APRaidUtils"]

local Sszorak = {}
AP.Sszorak = Sszorak

-- The 8 classic world markers (raid target icons), id = texture strip index.
local MARKERS = {
    { id = 1, name = "Star" },
    { id = 2, name = "Circle" },
    { id = 3, name = "Diamond" },
    { id = 4, name = "Triangle" },
    { id = 5, name = "Moon" },
    { id = 6, name = "Square" },
    { id = 7, name = "Cross" },
    { id = 8, name = "Skull" },
}

-- The 6 configurable cells. Top/Bottom are decorative and never clickable.
local CLICKABLE_SLOTS = { "tl", "tr", "l", "r", "bl", "br" }

-- Opposite cell for each clickable slot.
local OPPOSITES = {
    tl = "br",
    tr = "bl",
    l = "r",
    r = "l",
    bl = "tr",
    br = "tl",
}

-- 3x3 grid layout: row 0 is the top row, col 0 is the left column.
local GRID_LAYOUT = {
    { "tl", "t", "tr" },
    { "l", "c", "r" },
    { "bl", "b", "br" },
}

local CELL_SIZE = 46
local CELL_GAP = 6
local PADDING = 8
local RESET_BUTTON_HEIGHT = 22
local RESET_BUTTON_MARGIN = 8
local CALLBAR_SLOT_SIZE = 26
local CALLBAR_SLOT_GAP = 8
local CALLBAR_MARGIN = 6
local GRID_SIZE = CELL_SIZE * 3 + CELL_GAP * 2
local FRAME_WIDTH = GRID_SIZE + PADDING * 2
local FRAME_HEIGHT = GRID_SIZE + PADDING * 2 + CALLBAR_MARGIN + CALLBAR_SLOT_SIZE
    + RESET_BUTTON_MARGIN + RESET_BUTTON_HEIGHT

local MAX_SELECTED_SLOTS = 3

local ANCHOR_KEY = "sszorak"
-- Current-season raid encounter id for Sszorak (matches BigWigs/NSRT boss data).
local SSZORAK_ENCOUNTER_ID = 3420

local anchorFrame = nil
local cells = {}
local callBarSlots = {}
local selectedSlots = {}
local inCombat = false
local inEncounter = false
local configVisible = false
local configMenu = nil
local configMenuTargetSlot = nil

local function GetSettingsTable()
    if type(APRaidUtilsDB) ~= "table" or type(APRaidUtilsDB.profile) ~= "table" then
        return nil
    end

    if type(APRaidUtilsDB.profile.sszorak) ~= "table" then
        APRaidUtilsDB.profile.sszorak = {}
    end

    return APRaidUtilsDB.profile.sszorak
end

local function GetAssignments()
    local settings = GetSettingsTable()
    if not settings then
        return {}
    end

    if type(settings.assignments) ~= "table" then
        settings.assignments = {}
    end

    return settings.assignments
end

local function IsEnabled()
    local settings = GetSettingsTable()
    return settings and settings.enabled == true or false
end

local function SetMarkerIcon(texture, markerId)
    if not markerId then
        texture:SetTexture(nil)
        return
    end

    -- Individual icon files are the reliable path on the current client
    -- (the shared UI-RaidTargetingIcons atlas has an inconsistent layout).
    texture:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_]] .. markerId)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function CloseConfigMenu()
    if configMenu and configMenu:IsShown() then
        configMenu:Hide()
    end
    configMenuTargetSlot = nil
end

local UpdateIcons
local RefreshCallBar

local function AssignMarker(slot, markerId)
    local assignments = GetAssignments()
    if markerId then
        assignments[slot] = markerId
    else
        assignments[slot] = nil
    end
    CloseConfigMenu()
    UpdateIcons()
end

UpdateIcons = function()
    local assignments = GetAssignments()
    for _, slot in ipairs(CLICKABLE_SLOTS) do
        local cell = cells[slot]
        if cell then
            SetMarkerIcon(cell.Icon, assignments[slot])
        end
    end
    RefreshCallBar()
end

-- Call bar: one slot per queued call, showing the marker assigned to
-- the OPPOSITE of the clicked direction (i.e. what actually gets called out).
RefreshCallBar = function()
    local assignments = GetAssignments()

    for index = 1, MAX_SELECTED_SLOTS do
        local slotFrame = callBarSlots[index]
        if slotFrame then
            local pickedSlot = selectedSlots[index]
            local oppositeSlot = pickedSlot and OPPOSITES[pickedSlot]
            local markerId = oppositeSlot and assignments[oppositeSlot]

            if pickedSlot then
                slotFrame:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)
                slotFrame:SetBackdropColor(0.12, 0.1, 0.04, 0.85)
            else
                slotFrame:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)
                slotFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.7)
            end

            if markerId then
                SetMarkerIcon(slotFrame.Icon, markerId)
            else
                slotFrame.Icon:SetTexture(nil)
            end
        end
    end
end

local function IsSlotSelected(slot)
    for _, selected in ipairs(selectedSlots) do
        if selected == slot then
            return true
        end
    end
    return false
end

-- Highlight styles: selected cell -> blue border / dark blue fill. That is all:
-- the actual call targets (opposites, in order) live in the call bar below.
local function RefreshHighlight()
    for _, slot in ipairs(CLICKABLE_SLOTS) do
        local cell = cells[slot]
        if cell then
            if IsSlotSelected(slot) then
                cell:SetBackdropBorderColor(0.25, 0.55, 1, 1)
                cell:SetBackdropColor(0.1, 0.16, 0.26, 0.95)
            else
                cell:SetBackdropBorderColor(0.3, 0.3, 0.36, 0.9)
                cell:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
            end
        end
    end
end

local function HandleSlotClick(slot)
    CloseConfigMenu()

    for index, selected in ipairs(selectedSlots) do
        if selected == slot then
            table.remove(selectedSlots, index)
            RefreshHighlight()
            RefreshCallBar()
            return
        end
    end

    selectedSlots[#selectedSlots + 1] = slot
    while #selectedSlots > MAX_SELECTED_SLOTS do
        table.remove(selectedSlots, 1)
    end
    RefreshHighlight()
    RefreshCallBar()
end

local function ShowConfigMenu(slot, cell)
    if not cell then
        return
    end

    -- Right-clicking the same cell again toggles the picker closed.
    if configMenu and configMenu:IsShown() and configMenuTargetSlot == slot then
        CloseConfigMenu()
        return
    end

    configMenuTargetSlot = slot
    if not configMenu then
        configMenu = CreateFrame("Frame", "APRaidUtilsSszorakConfigMenu", UIParent, "BackdropTemplate")
        configMenu:SetFrameStrata("DIALOG")
        configMenu:SetWidth(160)
        configMenu:SetBackdrop({
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            edgeFile = [[Interface\Buttons\WHITE8X8]],
            edgeSize = 1,
            tile = true,
            tileSize = 64,
        })
        configMenu:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
        configMenu:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
        configMenu:SetClampedToScreen(true)
    end

    -- Rebuild menu rows for the passed-in slot.
    for _, child in ipairs(configMenu.children or {}) do
        child:Hide()
    end

    local usedMarkerIds = {}
    local assignments = GetAssignments()
    for otherSlot, markerId in pairs(assignments) do
        if otherSlot ~= slot and markerId then
            usedMarkerIds[markerId] = true
        end
    end

    local children = {}
    local yOffset = -6

    local ROW_HEIGHT = 24
    local ROW_WIDTH = 148

    local function CreateRow(label, iconId, onClick)
        local row = CreateFrame("Button", nil, configMenu, "BackdropTemplate")
        row:SetSize(ROW_WIDTH, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", configMenu, "TOPLEFT", 6, yOffset)
        row:SetBackdrop({
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            tile = true,
            tileSize = 32,
        })
        row:SetBackdropColor(0.1, 0.1, 0.12, 0.6)
        row:SetScript("OnClick", function()
            if onClick then
                onClick()
            end
        end)

        local iconTexture = row:CreateTexture(nil, "ARTWORK")
        iconTexture:SetSize(18, 18)
        iconTexture:SetPoint("LEFT", row, "LEFT", 8, 0)
        if iconId then
            SetMarkerIcon(iconTexture, iconId)
        else
            iconTexture:Hide()
        end
        row.Icon = iconTexture

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowLabel:SetPoint("LEFT", iconTexture, "RIGHT", 8, 0)
        rowLabel:SetText(label)
        rowLabel:SetTextColor(0.9, 0.9, 0.9, 1)
        row.Label = rowLabel

        yOffset = yOffset - ROW_HEIGHT
        children[#children + 1] = row
        return row
    end

    local clearRow = CreateRow("Unassigned", nil, function()
        AssignMarker(configMenuTargetSlot, nil)
    end)
    clearRow:RegisterForClicks("LeftButtonUp")

    for _, marker in ipairs(MARKERS) do
        local used = usedMarkerIds[marker.id] == true
        local row = CreateRow(marker.name, marker.id, function()
            if not used then
                AssignMarker(configMenuTargetSlot, marker.id)
            end
        end)
        row:RegisterForClicks("LeftButtonUp")
        if used then
            row.Label:SetTextColor(0.4, 0.4, 0.45, 1)
            row:SetScript("OnClick", nil)
        end
    end

    local closeRow = CreateRow("Close", nil, CloseConfigMenu)
    closeRow:RegisterForClicks("LeftButtonUp")

    configMenu.children = children
    configMenu:SetHeight(#children * ROW_HEIGHT + 12)

    local left, bottom = cell:GetLeft(), cell:GetBottom()
    configMenu:ClearAllPoints()
    configMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - 6, bottom + CELL_SIZE + 6)
    configMenu:Show()
end

local function CreateCell(parent, slot, col, row)
    local cell = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cell:SetSize(CELL_SIZE, CELL_SIZE)
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING + col * (CELL_SIZE + CELL_GAP), -(PADDING + row * (CELL_SIZE + CELL_GAP)))
    cell:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
        tile = true,
        tileSize = 32,
    })
    cell:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
    cell:SetBackdropBorderColor(0.3, 0.3, 0.36, 0.9)

    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CELL_SIZE - 16, CELL_SIZE - 16)
    icon:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.Icon = icon

    return cell
end

-- Call bar below the octagon: slots showing what to call out.
local function BuildCallBar(parent)
    local totalWidth = CALLBAR_SLOT_SIZE * 3 + CALLBAR_SLOT_GAP * 2
    local startX = (FRAME_WIDTH - totalWidth) / 2
    local yPos = -(PADDING + GRID_SIZE + CALLBAR_MARGIN)

    for index = 1, MAX_SELECTED_SLOTS do
        local slotFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        slotFrame:SetSize(CALLBAR_SLOT_SIZE, CALLBAR_SLOT_SIZE)
        slotFrame:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            startX + (index - 1) * (CALLBAR_SLOT_SIZE + CALLBAR_SLOT_GAP),
            yPos
        )
        slotFrame:SetBackdrop({
            bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
            edgeFile = [[Interface\Buttons\WHITE8X8]],
            edgeSize = 1,
            tile = true,
            tileSize = 32,
        })
        slotFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.7)
        slotFrame:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)

        local icon = slotFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(CALLBAR_SLOT_SIZE - 8, CALLBAR_SLOT_SIZE - 8)
        icon:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
        slotFrame.Icon = icon

        callBarSlots[index] = slotFrame
    end
end

local function CreateResetButton(parent)
    local resetButton = CreateFrame("Button", nil, parent, "BackdropTemplate")
    resetButton:SetSize(90, RESET_BUTTON_HEIGHT)
    resetButton:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        (FRAME_WIDTH - 90) / 2,
        -(PADDING + GRID_SIZE + CALLBAR_MARGIN + CALLBAR_SLOT_SIZE + RESET_BUTTON_MARGIN)
    )
    resetButton:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 1,
    })
    resetButton:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
    resetButton:SetBackdropBorderColor(0.3, 0.3, 0.36, 0.9)

    local label = resetButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", resetButton, "CENTER", 0, 0)
    label:SetText("Reset")
    label:SetTextColor(0.9, 0.9, 0.9, 1)

    resetButton:SetScript("OnClick", function()
        wipe(selectedSlots)
        RefreshHighlight()
        RefreshCallBar()
    end)
    resetButton:RegisterForClicks("LeftButtonUp")

    return resetButton
end

-- Populates the content-anchor frame with the octagon grid, call bar and
-- reset button. Called once by APAnchor:CreateContentAnchor().
local function BuildWidget(frame)
    for rowIndex = 1, 3 do
        for colIndex = 1, 3 do
            local slot = GRID_LAYOUT[rowIndex][colIndex]
            local cell = CreateCell(frame, slot, colIndex - 1, rowIndex - 1)
            cells[slot] = cell

            if slot == "c" then
                local centerLabel = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                centerLabel:SetPoint("CENTER", cell, "CENTER", 0, 0)
                centerLabel:SetText("SSZ")
                centerLabel:SetTextColor(0.6, 0.6, 0.65, 1)
            elseif OPPOSITES[slot] == nil then
                -- Top and bottom cells are decorative.
                cell:SetBackdropColor(0.06, 0.06, 0.08, 0.6)
                cell:SetBackdropBorderColor(0.2, 0.2, 0.22, 0.5)
            else
                local function BindCellClick(c, s)
                    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    c:SetScript("OnClick", function(_, button)
                        if button == "LeftButton" then
                            HandleSlotClick(s)
                        elseif button == "RightButton" and not inCombat then
                            ShowConfigMenu(s, c)
                        end
                    end)
                end
                BindCellClick(cell, slot)
            end
        end
    end

    BuildCallBar(frame)
    CreateResetButton(frame)
end

-- Anchor edit mode disables cell input so the whole surface drags; normal
-- mode re-enables only the interactive cells (decorative cells stay inert so
-- they never swallow clicks meant for the anchor backdrop).
local function SetCellsInteractive(enabled)
    for _, slot in ipairs(CLICKABLE_SLOTS) do
        local cell = cells[slot]
        if cell then
            cell:EnableMouse(enabled == true)
        end
    end
end

local function EnsureAnchor()
    local APAnchor = AP.APAnchor
    if not APAnchor then
        return nil
    end

    if anchorFrame then
        return anchorFrame
    end

    -- One-time migration from pre-anchor persistence (profile.sszorak.*).
    local settings = GetSettingsTable()
    if settings and (settings.point or settings.x or settings.y) then
        local anchorsDB = APRaidUtilsDB.profile and APRaidUtilsDB.profile.anchors
        local target = anchorsDB and anchorsDB[ANCHOR_KEY]
        if target and target.x == nil then
            target.point = settings.point or "CENTER"
            target.relativeTo = settings.relativeTo or "UIParent"
            target.relativePoint = settings.relativePoint or "CENTER"
            target.x = settings.x or 0
            target.y = settings.y or 0
        end
        settings.point = nil
        settings.relativeTo = nil
        settings.relativePoint = nil
        settings.x = nil
        settings.y = nil
    end

    anchorFrame = APAnchor:CreateContentAnchor(ANCHOR_KEY, {
        relativeTo = "UIParent",
        x = 0,
        y = 220,
        scale = 1.0,
        maxWidth = FRAME_WIDTH,
        maxHeight = FRAME_HEIGHT,
        locked = false,
    }, BuildWidget)

    if APAnchor.RegisterVisibilityHook then
        APAnchor:RegisterVisibilityHook(ANCHOR_KEY, function(editMode)
            SetCellsInteractive(editMode ~= true)
            if editMode then
                CloseConfigMenu()
            end
        end)
    end

    local editMode = APAnchor.IsAnchorsVisible and APAnchor:IsAnchorsVisible() or false
    SetCellsInteractive(not editMode)

    return anchorFrame
end

local function ResetForCombat()
    wipe(selectedSlots)
    CloseConfigMenu()
    RefreshHighlight()
    RefreshCallBar()
end

-- The widget is visible while: inside the Sszorak encounter, during explicit
-- out-of-combat config mode, or whenever anchor edit mode is active (the
-- anchor subsystem ORs allAnchorsVisible into its own visibility check).
local function UpdateVisibility()
    if not AP.APAnchor then
        return
    end

    AP.APAnchor:SetAnchorVisible(ANCHOR_KEY, inEncounter or configVisible)
end

function Sszorak:Enable()
    if not IsEnabled() then
        return
    end

    AP:EnableFeatureEvents("sszorak")
    inCombat = InCombatLockdown and InCombatLockdown() or false

    if not EnsureAnchor() then
        return
    end

    UpdateIcons()
    ResetForCombat()
    UpdateVisibility()
end

function Sszorak:Disable()
    AP:DisableFeatureEvents("sszorak")
    wipe(selectedSlots)
    inEncounter = false
    configVisible = false
    inCombat = false
    CloseConfigMenu()

    if AP.APAnchor then
        AP.APAnchor:SetAnchorVisible(ANCHOR_KEY, false)
    end
end

function Sszorak:Restore()
    if IsEnabled() then
        self:Enable()
    end
end

function Sszorak:OnPlayerRegenDisabled()
    inCombat = true
    ResetForCombat()
end

function Sszorak:OnPlayerRegenEnabled()
    inCombat = false
    ResetForCombat()
end

function Sszorak:OnEncounterStart(encounterId)
    if tonumber(encounterId) ~= SSZORAK_ENCOUNTER_ID then
        return
    end

    inEncounter = true
    inCombat = true
    ResetForCombat()
    UpdateVisibility()
end

function Sszorak:OnEncounterEnd()
    if not inEncounter then
        return
    end

    inEncounter = false
    inCombat = false
    ResetForCombat()
    UpdateVisibility()
end

---Ephemeral out-of-combat config mode; never persisted.
function Sszorak:ToggleConfig()
    configVisible = not configVisible

    if configVisible and not EnsureAnchor() then
        configVisible = false
        return false
    end

    UpdateVisibility()
    return configVisible
end

function Sszorak:IsEnabled()
    return IsEnabled()
end

function Sszorak:GetAssignments()
    return GetAssignments()
end

function Sszorak:SetEnabled(value)
    local settings = GetSettingsTable()
    if settings then
        settings.enabled = value == true
    end

    if value == true then
        self:Enable()
    else
        self:Disable()
    end
end
