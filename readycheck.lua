local issecretvalue = issecretvalue or function()
    return false
end

local AP = _G["APRaidUtils"]

local ReadyCheck = {}
AP.ReadyCheck = ReadyCheck

-- ---------------------------------------------------------------------------
-- Buff matching
--
-- The built-in columns match auras by case-insensitive name pattern so they
-- keep working across raid tiers without per-tier ID updates. The pattern
-- fallbacks are not hardcoded: they are resolved at first scan from the
-- NSRT-sourced spell IDs (localized spell names), so a re-ID'd buff with the
-- same name still matches and locale correctness comes for free. The custom
-- column (settings) matches spell IDs, which is locale independent and good
-- for tier-specific consumables the patterns miss.
-- ---------------------------------------------------------------------------

-- Midnight (12.x) consumable spell IDs, sourced from Northern Sky Raid Tools.
-- Update these per raid tier; the name patterns remain as fallback.
local MIDNIGHT_VANTUS_SPELL_ID = 1276691
local MIDNIGHT_FLASK_SPELL_IDS = { 1235111, 1235108, 1235110, 1235057 }
local MIDNIGHT_AUGMENT_SPELL_ID = 1264426

-- One column per buff. Match precedence: bySpellId (custom columns) >
-- spellIds (current-tier IDs) > buffIcons (icon fileDataID, catches any rank
-- of a buff regardless of spell ID) > dynamicVantus (localized rune prefix) >
-- patterns > names. All matchers are OR'd per column. To support a new rank
-- of a buff, add its spell ID to `spellIds` (or its icon to `buffIcons`).
-- "iconFile"/"iconSpellId" only resolve the column icon.
local BUFF_COLUMNS = {
    {
        key = "food",
        label = "Food",
        -- NSRT matches food by the localized "Well Fed" aura name; the
        -- generic Well Fed icon (136000) no longer covers Midnight food auras.
        nameLookups = { "Well Fed" },
        buffIcons = { [136000] = true },
        iconFile = 136000,
    },
    {
        key = "flask",
        label = "Flask",
        spellIds = MIDNIGHT_FLASK_SPELL_IDS,
        patternSpellIds = MIDNIGHT_FLASK_SPELL_IDS,
        iconSpellId = 1235111,
    },
    {
        key = "vantus",
        label = "Vantus",
        dynamicVantus = true,
        iconSpellId = MIDNIGHT_VANTUS_SPELL_ID,
    },
    {
        key = "augment",
        label = "Aug",
        spellIds = { MIDNIGHT_AUGMENT_SPELL_ID },
        -- Exact-name fallback (not substring): variant consumables whose aura
        -- names merely CONTAIN the rune's name (e.g. Void-touched orbs) must
        -- not light this column up.
        exactSpellIds = { MIDNIGHT_AUGMENT_SPELL_ID },
        iconSpellId = MIDNIGHT_AUGMENT_SPELL_ID,
    },
    {
        -- Soulstone: only meaningful on healers; non-healer cells stay blank.
        key = "soul",
        label = "Soul",
        spellIds = { 20707 },
        iconSpellId = 20707,
        roleOnly = "HEALER",
    },
    {
        key = "fort",
        label = "Fort",
        names = { "power word: fortitude", "blood pact" },
        spellIds = { 21562, 109773 },
        iconSpellId = 21562,
    },
    { key = "motw", label = "MotW", names = { "mark of the wild" }, spellIds = { 1126 }, iconSpellId = 1126 },
    { key = "shout", label = "Shout", names = { "battle shout" }, spellIds = { 6673 }, iconSpellId = 6673 },
    { key = "brill", label = "Brill", names = { "arcane intellect" }, spellIds = { 1459 }, iconSpellId = 1459 },
    { key = "skyfury", label = "Skyfury", names = { "skyfury" }, spellIds = { 462854 }, iconSpellId = 462854 },
    {
        -- Evoker buff: one spell ID per RECEIVING class (see NSRT's table).
        key = "bronze",
        label = "Bronze",
        names = { "blessing of the bronze" },
        spellIds = {
            381741,
            381757,
            381756,
            381732,
            381752,
            381748,
            381750,
            381749,
            381746,
            381751,
            381753,
            381754,
            381758,
        },
        iconSpellId = 381741,
    },
}

local ICON_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_NOT_READY = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_WAITING = "Interface\\RaidFrame\\ReadyCheck-Waiting"

local MYTHIC_DIFFICULTY_ID = 16
local MYTHIC_COUNTED_SUBGROUPS = 4
local DEFAULT_COUNTED_SUBGROUPS = 6

-- Popup layout. Matches the look of ui/main.lua: DF simple panel, scrollbox
-- lines with tooltip backgrounds, orange section labels, class colored names.
local PANEL_HEIGHT = 650
local ROW_HEIGHT = 18
local NAME_WIDTH = 130
local CELL_WIDTH = 40
local READY_FIRST_WIDTH = 24
local PAD_X = 12
local SLIDER_WIDTH = 18
local VISIBLE_LINES = 30
local ICON_SIZE = 16
local HIDE_DELAY = 10
local MAX_MISSING_IN_CHAT = 15

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local popup
local rowScrollBox
local subtitleLabel
local summaryLabel
local headerName
local headerCells = {}

local currentColumns = {}
local displayRows = {}

-- checkActive is only true between READY_CHECK and READY_CHECK_FINISHED.
local checkActive = false
local finishTimer

local snapshot = {} -- array of row info, sorted counted first then subgroup/name
local rowByName = {} -- row info by full unit name
local readyState = {} -- name -> true/false/nil (nil = unanswered)
local auraCache = {} -- name -> { [category] = { auraName, ... } }

local customIds = {}

-- UNIT_AURA fires very densely during a ready check (food/flask/rune buff
-- waves across the raid). Rather than rescanning auras and repainting the
-- scrollbox per event, mark units dirty and flush them on this debounce:
-- a burst of aura events becomes one rescan + one repaint.
local AURA_REFRESH_DEBOUNCE = 0.25 -- seconds
local dirtyUnits = {} -- unit -> row info, pending debounced aura rescan
local auraRefreshTimer

-- Temporary diagnostics: enable with /run APRaidUtils.ReadyCheck:SetDebug(true)
local debugEnabled = false

local function DebugPrint(...)
    if debugEnabled then
        AP:Print("[ReadyCheck debug]", ...)
    end
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local function GetSettings()
    if not APRaidUtilsDB or type(APRaidUtilsDB.profile) ~= "table" then
        return { enabled = false }
    end

    if type(APRaidUtilsDB.profile.readycheck) ~= "table" then
        APRaidUtilsDB.profile.readycheck = {}
    end

    return APRaidUtilsDB.profile.readycheck
end

local function IsEnabled()
    return GetSettings().enabled == true
end

local function LoadCustomIds()
    wipe(customIds)
    local text = GetSettings().customBuffIds
    if type(text) ~= "string" then
        return
    end

    for idText in text:gmatch("%d+") do
        local id = tonumber(idText)
        if id and id > 0 then
            customIds[#customIds + 1] = id
        end
    end
end

-- ---------------------------------------------------------------------------
-- Readiness rule: Mythic counts groups 1-4, every other difficulty (and
-- parties) counts groups 1-6.
-- ---------------------------------------------------------------------------

local function GetCountedSubgroups()
    if IsInRaid() and GetRaidDifficultyID() == MYTHIC_DIFFICULTY_ID then
        return MYTHIC_COUNTED_SUBGROUPS
    end
    return DEFAULT_COUNTED_SUBGROUPS
end

-- ---------------------------------------------------------------------------
-- Aura scanning
-- ---------------------------------------------------------------------------

local function NameMatchesAny(auraName, patterns)
    for _, pattern in ipairs(patterns) do
        -- plain-text find: spell names may contain Lua pattern magic chars
        if strfind(auraName, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- The Vantus rune buff is named "<Prefix>: <Boss>"; resolve the localized
-- prefix from the current tier's rune spell (same trick NSRT uses).
local vantusPrefix

local function GetVantusPrefix()
    if vantusPrefix == nil then
        vantusPrefix = false
        if C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(MIDNIGHT_VANTUS_SPELL_ID)
            if spellInfo and spellInfo.name and spellInfo.name ~= "" then
                vantusPrefix = strsplit(":", spellInfo.name)
            end
        end
    end
    return vantusPrefix or nil
end

-- Resolve the name fallbacks (column.patterns = substring match,
-- column.names = exact match) from the NSRT-sourced spell IDs on first use.
-- Retries until every fallback column has resolved, in case spell info is not
-- yet available when the popup is first built.
local NAME_FALLBACK_KINDS = {
    { source = "patternSpellIds", target = "patterns" },
    { source = "exactSpellIds", target = "names" },
    -- nameLookups: English spell names to resolve to their localized aura
    -- names (NSRT-style: C_Spell.GetSpellInfo("Well Fed")); falls back to the
    -- literal if the lookup fails on an untranslated client.
    { source = "nameLookups", target = "names", byName = true },
}

local function ResolvePatternFallbacks()
    local pending = false
    for _, column in ipairs(BUFF_COLUMNS) do
        for _, kind in ipairs(NAME_FALLBACK_KINDS) do
            if column[kind.source] and not column[kind.target] then
                local built = {}
                for _, key in ipairs(column[kind.source]) do
                    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(key)
                    local name = info and info.name
                    if not name or name == "" or issecretvalue(name) then
                        name = kind.byName and key or nil -- literal English fallback for name lookups
                    end
                    if name then
                        built[#built + 1] = strlower(name)
                    end
                end
                if #built > 0 then
                    column[kind.target] = built
                    -- keep already-built layout copies in sync
                    for _, active in ipairs(currentColumns) do
                        if active.key == column.key then
                            active[kind.target] = built
                        end
                    end
                else
                    pending = true
                end
            end
        end
    end
    return not pending
end

local function ScanUnitAuras(unit)
    if not unit or not UnitExists(unit) then
        return
    end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return
    end

    local name = GetUnitName(unit, true)
    local row = name and rowByName[name]
    if not row then
        return
    end

    local cache = auraCache[name]
    if not cache then
        cache = {}
        auraCache[name] = cache
    end
    for _, column in ipairs(currentColumns) do
        if type(cache[column.key]) ~= "table" then
            cache[column.key] = {}
        else
            wipe(cache[column.key])
        end
    end

    local localizedVantusPrefix = GetVantusPrefix()

    ResolvePatternFallbacks()

    -- Iterate the unit's auras by index (the approach NSRT uses on Midnight;
    -- AuraUtil.ForEachAura does not return auras on this client).
    for auraIndex = 1, 100 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, "HELPFUL")
        if not auraData then
            break
        end

        local auraName = auraData.name
        local spellId = auraData.spellId
        local icon = auraData.icon
        local instanceID = auraData.auraInstanceID

        -- Midnight redacts some auras as secret values; any comparison or
        -- read of a secret field hard-errors while addon code executes, so
        -- issecretvalue must run BEFORE any other use of these fields
        -- (including a simple `== ""` check). Skip redacted auras entirely.
        local redacted = issecretvalue(auraName)
            or issecretvalue(spellId)
            or issecretvalue(icon)
            or issecretvalue(instanceID)
        if not redacted and auraName and auraName ~= "" then
            local lower = strlower(auraName)
            for _, column in ipairs(currentColumns) do
                local matched = false
                if column.bySpellId then
                    matched = spellId == column.spellId
                elseif column.spellIds then
                    for _, id in ipairs(column.spellIds) do
                        if spellId == id then
                            matched = true
                            break
                        end
                    end
                end
                if not matched and column.buffIcons and icon and column.buffIcons[icon] then
                    matched = true
                end
                if not matched and column.dynamicVantus and localizedVantusPrefix then
                    matched = strfind(auraName, localizedVantusPrefix, 1, true) ~= nil
                end
                if not matched and column.patterns then
                    matched = NameMatchesAny(lower, column.patterns)
                end
                if not matched and column.names then
                    for _, buffName in ipairs(column.names) do
                        if lower == buffName then
                            matched = true
                            break
                        end
                    end
                end
                if matched then
                    local list = cache[column.key]
                    list[#list + 1] = {
                        name = auraName,
                        spellId = spellId,
                        instanceID = instanceID,
                        icon = icon,
                    }
                end
            end
        end
    end
end

local function ScanAllAuras()
    for _, row in ipairs(snapshot) do
        ScanUnitAuras(row.unit)
    end
end

-- ---------------------------------------------------------------------------
-- Roster snapshot
-- ---------------------------------------------------------------------------

local function BuildSnapshot()
    wipe(snapshot)
    wipe(rowByName)

    local inRaid = IsInRaid()
    local num = GetNumGroupMembers()
    if num == 0 then
        return
    end

    local countedSubgroups = GetCountedSubgroups()

    for i = 1, num do
        local unit, name, subgroup, classFileName, online
        if inRaid then
            unit = "raid" .. i
            local info = { GetRaidRosterInfo(i) }
            name, subgroup, classFileName, online = info[1], info[3], info[6], info[8]
        else
            unit = (i == 1) and "player" or ("party" .. (i - 1))
            name = GetUnitName(unit, true)
            classFileName = select(2, UnitClass(unit))
            online = UnitIsConnected(unit)
            subgroup = 1
        end

        if name and name ~= "" then
            local row = {
                name = name,
                unit = unit,
                subgroup = subgroup or 1,
                classFileName = classFileName or "",
                online = online ~= false,
                role = UnitGroupRolesAssigned(unit),
            }
            row.counted = (not inRaid) or (row.subgroup <= countedSubgroups)
            snapshot[#snapshot + 1] = row
            rowByName[name] = row
        end
    end

    table.sort(snapshot, function(a, b)
        if a.counted ~= b.counted then
            return a.counted
        end
        if a.subgroup ~= b.subgroup then
            return a.subgroup < b.subgroup
        end
        return a.name < b.name
    end)
end

-- Ready check confirmations and the READY_CHECK initiator name can disagree on
-- realm suffixes (cross realm raids); match with or without the suffix.
local function FindRowByNameFlexible(fullName)
    if not fullName then
        return nil
    end

    local row = rowByName[fullName]
    if row then
        return row
    end

    local shortName = strsplit("-", fullName)
    if not shortName then
        return nil
    end

    for name, candidate in pairs(rowByName) do
        if strsplit("-", name) == shortName then
            return candidate
        end
    end

    return nil
end

local function ComputeSummary()
    local counted, ready = 0, 0
    local missing = {}

    for _, row in ipairs(snapshot) do
        if row.counted then
            counted = counted + 1
            if row.online and readyState[row.name] == true then
                ready = ready + 1
            elseif not row.online then
                missing[#missing + 1] = row.name .. " (offline)"
            else
                missing[#missing + 1] = row.name
            end
        end
    end

    return counted, ready, missing
end

-- ---------------------------------------------------------------------------
-- Popup frame (DetailsFramework panel + scrollbox, styled like ui/main.lua)
-- ---------------------------------------------------------------------------

local function GetFramework()
    return LibStub("DetailsFramework-1.0", true) or _G.DetailsFramework
end

local function SavePopupPosition()
    if not popup then
        return
    end
    local settings = GetSettings()
    local point, _, relativePoint, x, y = popup:GetPoint(1)
    settings.popupPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function ApplySavedPosition()
    popup:ClearAllPoints()
    local saved = GetSettings().popupPoint
    if saved and saved.point and saved.x and saved.y then
        popup:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
end

local function GetColumnLayout()
    ResolvePatternFallbacks()
    local columns = {}
    for _, definition in ipairs(BUFF_COLUMNS) do
        columns[#columns + 1] = {
            key = definition.key,
            label = definition.label,
            patterns = definition.patterns,
            names = definition.names,
            iconSpellId = definition.iconSpellId,
        }
    end
    for index, id in ipairs(customIds) do
        columns[#columns + 1] = {
            key = "custom:" .. id,
            label = "C" .. index,
            spellId = id,
            iconSpellId = id,
            bySpellId = true,
        }
    end
    return columns
end

-- Widths are derived from the active column list so custom buff columns
-- widen the panel instead of overflowing it.
local function GetContentWidth()
    return READY_FIRST_WIDTH + NAME_WIDTH + #currentColumns * CELL_WIDTH
end

local function GetScrollWidth()
    return GetContentWidth() + SLIDER_WIDTH
end

local function GetPanelWidth()
    return PAD_X * 2 + GetScrollWidth() + SLIDER_WIDTH
end

local function GetColumnIcon(column)
    if column.icon then
        return column.icon
    end

    local texture
    if column.iconFile then
        texture = column.iconFile
    elseif column.iconSpellId then
        if C_Spell and C_Spell.GetSpellTexture then
            texture = C_Spell.GetSpellTexture(column.iconSpellId)
        end
    end
    column.icon = texture or FALLBACK_ICON
    return column.icon
end

local function ShowRowTooltip(line)
    local data = line.rowData
    if not data or data.kind ~= "row" then
        return
    end

    local info = data.info
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    local color = RAID_CLASS_COLORS[info.classFileName]
    if color then
        GameTooltip:AddLine(info.name, color.r, color.g, color.b)
    else
        GameTooltip:AddLine(info.name)
    end

    if IsInRaid() then
        local countedSubgroups = GetCountedSubgroups()
        GameTooltip:AddLine(
            ("Group %d%s"):format(
                info.subgroup,
                info.counted and "" or (" (outside groups 1-" .. countedSubgroups .. ")")
            ),
            0.8,
            0.8,
            0.8
        )
    else
        GameTooltip:AddLine("Party", 0.8, 0.8, 0.8)
    end
    if not info.online then
        GameTooltip:AddLine("Offline", 1, 0.3, 0.3)
    end

    local cache = auraCache[info.name]
    for _, column in ipairs(currentColumns) do
        local matches = cache and cache[column.key]
        local names = {}
        if matches then
            for _, match in ipairs(matches) do
                names[#names + 1] = match.name
            end
        end
        if column.roleOnly and info.role ~= column.roleOnly then
            GameTooltip:AddLine(("%s: n/a"):format(column.label), 0.6, 0.6, 0.6)
        elseif #names > 0 then
            GameTooltip:AddLine(("%s: %s"):format(column.label, table.concat(names, ", ")), 0.5, 1, 0.5)
        else
            GameTooltip:AddLine(("%s: none"):format(column.label), 1, 0.3, 0.3)
        end
    end

    GameTooltip:Show()
end

-- Texture markup for fontstrings; works with fileDataIDs where
-- GameTooltip:AddTexture does not.
local function GetIconMarkup(icon, size)
    if not icon then
        return ""
    end
    return ("|T%s:%d:%d|t"):format(tostring(icon), size or 14, size or 14)
end

local function ShowCellTooltip(hit)
    local line = hit:GetParent()
    local column = currentColumns[hit.slot]
    local data = line.rowData
    if not column or not data or data.kind ~= "row" then
        return
    end

    local info = data.info
    local cache = auraCache[info.name]
    local matches = cache and cache[column.key]
    local match = matches and matches[1]

    GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")

    if column.roleOnly and info.role ~= column.roleOnly then
        GameTooltip:AddLine(column.label)
        GameTooltip:AddLine("Not a healer", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end

    if match and not column.buffIcons then
        -- Active buff: show the real aura tooltip from the player's unit.
        -- Icon-matched columns (e.g. food) skip this: the specific aura the
        -- player has doesn't matter, so they get the expected tooltip instead.
        local shown = false
        if match.instanceID and C_TooltipInfo and C_TooltipInfo.GetUnitAura then
            local okay, tooltipInfo = pcall(C_TooltipInfo.GetUnitAura, info.unit, match.instanceID)
            if okay and tooltipInfo then
                GameTooltip:ProcessInfo(tooltipInfo)
                shown = true
            end
        end

        if not shown then
            GameTooltip:AddLine(column.label)
            GameTooltip:AddTexture(GetColumnIcon(column))
            for _, entry in ipairs(matches) do
                GameTooltip:AddLine(entry.name, 0.5, 1, 0.5)
            end
        end
    else
        -- Expected state. For columns checking several spell IDs (flasks,
        -- bronze, vantus) list every spell the column looks for so it's
        -- obvious the check is not tied to one specific flask/rune.
        GameTooltip:AddLine(("%s %s"):format(GetIconMarkup(GetColumnIcon(column), 16), column.label))

        local ids = column.spellIds or (column.iconSpellId and { column.iconSpellId }) or {}
        for _, id in ipairs(ids) do
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
            if spellInfo and spellInfo.name then
                local texture = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
                GameTooltip:AddLine(("%s %s"):format(GetIconMarkup(texture), spellInfo.name))
            end
        end

        if match then
            GameTooltip:AddLine("Active", 0.5, 1, 0.5)
        else
            GameTooltip:AddLine("Missing", 1, 0.3, 0.3)
        end
    end

    if not info.online then
        GameTooltip:AddLine("Offline", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

-- Flat display list: counted players, then a section divider, then the
-- remaining players (greyed, "not counted").
local function BuildDisplayRows()
    wipe(displayRows)

    local hasNotCounted = false
    for _, info in ipairs(snapshot) do
        if not info.counted then
            hasNotCounted = true
            break
        end
    end

    for _, info in ipairs(snapshot) do
        if info.counted then
            displayRows[#displayRows + 1] = { kind = "row", info = info }
        end
    end

    if hasNotCounted then
        displayRows[#displayRows + 1] =
            { kind = "section", text = "Not counted (groups " .. (GetCountedSubgroups() + 1) .. "-8)" }
    end

    for _, info in ipairs(snapshot) do
        if not info.counted then
            displayRows[#displayRows + 1] = { kind = "row", info = info }
        end
    end
end

local function CreateRowLine(self, index)
    local line = CreateFrame("Button", "$parentLine" .. index, self, "BackdropTemplate")
    line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * ROW_HEIGHT) - 1)
    line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -18, -((index - 1) * ROW_HEIGHT) - 1)
    line:SetHeight(ROW_HEIGHT)
    line:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tileSize = 64,
        tile = true,
    })

    line.NameText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.NameText:SetPoint("LEFT", line, "LEFT", 8, 0)
    line.NameText:SetSize(NAME_WIDTH - 8, ROW_HEIGHT)
    line.NameText:SetJustifyH("LEFT")
    line.NameText:SetJustifyV("MIDDLE")

    -- Ready state leads the row, MRT style: check / question / cross icon.
    line.ReadyIcon = line:CreateTexture(nil, "OVERLAY")
    line.ReadyIcon:SetSize(ICON_SIZE, ICON_SIZE)
    line.ReadyIcon:SetPoint("LEFT", line, "LEFT", (READY_FIRST_WIDTH - ICON_SIZE) / 2, 0)

    line.NameText:SetPoint("LEFT", line, "LEFT", READY_FIRST_WIDTH + 4, 0)
    line.NameText:SetSize(NAME_WIDTH - 4, ROW_HEIGHT)

    line.CellIcons = {}
    line.CellHits = {}
    for slot = 1, #currentColumns do
        -- Invisible hover target per buff column: hovering a cell shows that
        -- buff's own tooltip instead of one row-wide tooltip.
        local hit = CreateFrame("Frame", nil, line)
        hit:SetSize(CELL_WIDTH, ROW_HEIGHT)
        hit:SetPoint("LEFT", line, "LEFT", READY_FIRST_WIDTH + NAME_WIDTH + (slot - 1) * CELL_WIDTH, 0)
        hit:EnableMouse(true)
        hit.slot = slot
        hit:SetScript("OnEnter", function(hoverHit)
            ShowCellTooltip(hoverHit)
        end)
        hit:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        hit:Hide()
        line.CellHits[slot] = hit

        local cell = line:CreateTexture(nil, "OVERLAY")
        cell:SetSize(ICON_SIZE, ICON_SIZE)
        cell:SetPoint("CENTER", hit, "CENTER", 0, 0)
        cell:Hide()
        line.CellIcons[slot] = cell
    end

    line:SetScript("OnEnter", function(hoverLine)
        ShowRowTooltip(hoverLine)
    end)
    line:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return line
end

local function RefreshRowLine(line, data)
    line.rowData = data

    if data.kind == "section" then
        line:SetBackdropColor(0.14, 0.12, 0.05, 0.45)
        line.NameText:SetFontObject("GameFontNormalSmall")
        line.NameText:SetTextColor(1, 0.82, 0, 1)
        line.NameText:SetText("  " .. data.text)
        for slot = 1, #line.CellIcons do
            line.CellIcons[slot]:Hide()
        end
        for slot = 1, #line.CellHits do
            line.CellHits[slot]:Hide()
        end
        line.ReadyIcon:Hide()
        return
    end

    local info = data.info
    local cache = auraCache[info.name]

    line.NameText:SetFontObject("GameFontHighlightSmall")
    line.NameText:SetText(info.name)

    -- MRT style: tint the row backdrop with the player's class color.
    local classColor = RAID_CLASS_COLORS[info.classFileName]
    if info.online and classColor then
        line.NameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        line:SetBackdropColor(0.06 + classColor.r * 0.2, 0.06 + classColor.g * 0.2, 0.06 + classColor.b * 0.2, 0.55)
    else
        line.NameText:SetTextColor(0.6, 0.6, 0.6, 1)
        line:SetBackdropColor(0.08, 0.08, 0.1, 0.4)
    end

    for slot, column in ipairs(currentColumns) do
        local cell = line.CellIcons[slot]
        if column.roleOnly and info.role ~= column.roleOnly then
            -- Role-gated column (e.g. soulstone): blank for everyone else.
            cell:Hide()
        else
            local matches = cache and cache[column.key]
            local count = matches and #matches or 0
            cell:Show()
            -- Active buffs show their own icon (e.g. which flask the player
            -- actually used); missing buffs show the column's generic icon.
            if count > 0 and matches[1].icon then
                cell:SetTexture(matches[1].icon)
            else
                cell:SetTexture(GetColumnIcon(column))
            end
            if count > 0 then
                cell:SetDesaturated(false)
                cell:SetAlpha(info.online and 1 or 0.6)
            else
                -- Missing buffs stay visible as their spell icon, greyed out.
                cell:SetDesaturated(true)
                cell:SetAlpha(0.3)
            end
        end
    end
    for slot = 1, #line.CellHits do
        line.CellHits[slot]:SetShown(slot <= #currentColumns)
    end

    local readyIcon = line.ReadyIcon
    readyIcon:Show()
    readyIcon:SetDesaturated(false)
    readyIcon:SetAlpha(1)
    if not info.online then
        readyIcon:SetTexture(ICON_NOT_READY)
        readyIcon:SetDesaturated(true)
        readyIcon:SetAlpha(0.6)
    elseif info.counted then
        local state = readyState[info.name]
        if state == true then
            readyIcon:SetTexture(ICON_READY)
        elseif state == false then
            readyIcon:SetTexture(ICON_NOT_READY)
        else
            readyIcon:SetTexture(ICON_WAITING)
        end
    else
        readyIcon:SetTexture(ICON_WAITING)
        readyIcon:SetDesaturated(true)
        readyIcon:SetAlpha(0.55)
    end
end

local function RefreshRowLines(scrollBox, data, offset, totalLines)
    for lineIndex = 1, totalLines do
        local entry = data[lineIndex + offset]
        if entry then
            local line = scrollBox:GetLine(lineIndex)
            if line then
                RefreshRowLine(line, entry)
            end
        end
    end
end

local function RefreshHeader()
    headerName:SetText("Name")
    for slot, column in ipairs(currentColumns) do
        local header = headerCells[slot]
        if header then
            header:SetText(column.label)
            header:Show()
        end
    end
end

local function RefreshSummary()
    if not popup then
        return
    end

    local counted, ready = ComputeSummary()
    local who = IsInRaid() and "Raid" or "Party"
    if not checkActive and counted > 0 and ready == counted then
        summaryLabel:SetText(("%s is ready: %d/%d"):format(who, ready, counted))
        summaryLabel:SetTextColor(0.35, 1, 0.35, 1)
    elseif ready == counted then
        summaryLabel:SetText(("%d/%d ready"):format(ready, counted))
        summaryLabel:SetTextColor(0.35, 1, 0.35, 1)
    else
        summaryLabel:SetText(("%d/%d ready"):format(ready, counted))
        summaryLabel:SetTextColor(1, 0.82, 0, 1)
    end
end

local function RefreshDisplay()
    if not popup then
        return
    end

    currentColumns = GetColumnLayout()
    RefreshHeader()
    BuildDisplayRows()

    if rowScrollBox then
        rowScrollBox:SetData(displayRows)
        rowScrollBox:Refresh()
    end

    RefreshSummary()
end

local function RefreshRowByRow(row)
    if not rowScrollBox or not row then
        return
    end

    for _, data in ipairs(displayRows) do
        if data.info == row then
            rowScrollBox:Refresh()
            return
        end
    end
end

local function IsRowDisplayed(row)
    for _, data in ipairs(displayRows) do
        if data.info == row then
            return true
        end
    end
    return false
end

-- Debounced flush for UNIT_AURA bursts: rescan each dirty unit once, then
-- repaint the scrollbox (and summary) at most one time for the whole batch.
local function FlushDirtyAuras()
    auraRefreshTimer = nil
    if not checkActive then
        wipe(dirtyUnits)
        return
    end

    local anyVisible = false
    for unit, row in pairs(dirtyUnits) do
        dirtyUnits[unit] = nil
        ScanUnitAuras(unit)
        if not anyVisible and IsRowDisplayed(row) then
            anyVisible = true
        end
    end

    if anyVisible and rowScrollBox then
        rowScrollBox:Refresh()
    end
    RefreshSummary()
end

local function EnsurePopup()
    if popup then
        return popup
    end

    local framework = GetFramework()
    if not framework then
        AP:Print("DetailsFramework is unavailable.")
        return nil
    end

    currentColumns = GetColumnLayout()

    -- Fixed-size scrollbox: explicit dimensions keep the slider inside the
    -- panel instead of overflowing it.
    local scrollWidth = GetScrollWidth()
    local scrollHeight = VISIBLE_LINES * ROW_HEIGHT

    popup = framework:CreateSimplePanel(
        UIParent,
        GetPanelWidth(),
        PANEL_HEIGHT,
        "APRaidUtils Ready Check",
        "APRaidUtilsReadyCheckPopup",
        {
            DontRightClickClose = true,
        }
    )
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:Hide()
    popup:HookScript("OnMouseUp", SavePopupPosition)

    subtitleLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitleLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD_X, -34)
    subtitleLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    subtitleLabel:SetText("")

    local headerFrame = CreateFrame("Frame", nil, popup)
    headerFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD_X, -52)
    headerFrame:SetSize(scrollWidth - SLIDER_WIDTH, 18)

    headerName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerName:SetPoint("LEFT", headerFrame, "LEFT", READY_FIRST_WIDTH + 4, 0)
    headerName:SetSize(NAME_WIDTH - 4, 18)
    headerName:SetJustifyH("LEFT")
    headerName:SetJustifyV("MIDDLE")
    headerName:SetTextColor(0, 1, 0, 1)
    headerName:SetText("Name")

    for slot, column in ipairs(currentColumns) do
        local header = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("LEFT", headerFrame, "LEFT", READY_FIRST_WIDTH + NAME_WIDTH + (slot - 1) * CELL_WIDTH, 0)
        header:SetSize(CELL_WIDTH, 18)
        header:SetJustifyH("CENTER")
        header:SetJustifyV("MIDDLE")
        header:SetTextColor(0, 1, 0, 1)
        header:SetText(column.label)
        headerCells[slot] = header
    end

    rowScrollBox = framework:CreateScrollBox(
        popup,
        "$parentRowsScrollBox",
        RefreshRowLines,
        {},
        scrollWidth,
        scrollHeight,
        VISIBLE_LINES,
        ROW_HEIGHT,
        CreateRowLine,
        true
    )
    rowScrollBox:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    framework:ReskinSlider(rowScrollBox)

    -- DF 753's OnSizeChanged never pre-creates frames (GetNumFramesShown always
    -- equals LineAmount), so create the line frames explicitly here.
    rowScrollBox:CreateLines(CreateRowLine, VISIBLE_LINES)

    if debugEnabled then
        DebugPrint("framesCreated: " .. tostring(rowScrollBox:GetNumFramesCreated()))
    end

    summaryLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryLabel:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", PAD_X, 10)

    ApplySavedPosition()

    return popup
end

-- ---------------------------------------------------------------------------
-- Ready check flow
-- ---------------------------------------------------------------------------

local function CancelFinishTimer()
    if finishTimer then
        finishTimer:Cancel()
        finishTimer = nil
    end
end

function ReadyCheck:OnReadyCheck(initiatorName)
    if not IsEnabled() then
        return
    end
    if not IsInGroup() then
        return
    end

    checkActive = true
    CancelFinishTimer()
    wipe(readyState)

    BuildSnapshot()

    -- The ready check initiator is implicitly ready on the client but never
    -- receives a READY_CHECK_CONFIRM of their own; flag them here.
    local initiatorRow = FindRowByNameFlexible(initiatorName)
    if initiatorRow then
        readyState[initiatorRow.name] = true
    end

    EnsurePopup()
    ApplySavedPosition()

    -- A new ready check always starts scrolled to the top: the scroll offset
    -- persists on the scroll frame between checks and would otherwise keep
    -- the first rows hidden. Reset via the scrollbar so the thumb matches.
    if rowScrollBox then
        local scrollName = rowScrollBox:GetName()
        local scrollBar = scrollName and _G[scrollName .. "ScrollBar"]
        if scrollBar then
            scrollBar:SetValue(0)
        end
        rowScrollBox.offset = 0
    end

    RefreshDisplay()
    ScanAllAuras()
    RefreshDisplay()

    DebugPrint(
        ("readycheck: raiders=%d rows=%d columns=%d framesCreated=%s panelShown=%s"):format(
            #snapshot,
            #displayRows,
            #currentColumns,
            rowScrollBox and tostring(rowScrollBox.GetNumFramesCreated and rowScrollBox:GetNumFramesCreated() or "n/a")
                or "none",
            popup:IsShown() and "yes" or "no"
        )
    )

    subtitleLabel:SetText(("Ready check started by %s"):format(initiatorName or UNKNOWN))
    popup:Show()
end

function ReadyCheck:OnReadyCheckConfirm(unitTarget, isReady)
    if not checkActive then
        return
    end

    local name = unitTarget and GetUnitName(unitTarget, true)
    local row = FindRowByNameFlexible(name)
    if not row then
        return
    end

    readyState[row.name] = isReady and true or false
    ScanUnitAuras(row.unit)
    RefreshRowByRow(row)
    RefreshSummary()
end

function ReadyCheck:OnUnitAura(unitTarget)
    if not checkActive then
        return
    end

    local name = unitTarget and GetUnitName(unitTarget, true)
    local row = name and rowByName[name]
    if not row then
        return
    end

    -- Coalesce: mark dirty and let the debounce timer do one rescan + one
    -- repaint for the whole burst instead of paying it per event.
    dirtyUnits[row.unit] = row
    if not auraRefreshTimer then
        auraRefreshTimer = C_Timer.NewTimer(AURA_REFRESH_DEBOUNCE, FlushDirtyAuras)
    end
end

function ReadyCheck:OnRosterUpdate()
    if not checkActive then
        return
    end

    BuildSnapshot()
    ScanAllAuras()
    RefreshDisplay()
end

function ReadyCheck:OnReadyCheckFinished()
    if not checkActive then
        return
    end
    checkActive = false

    ScanAllAuras()
    RefreshDisplay()

    local counted, ready, missing = ComputeSummary()
    local countedSubgroups = GetCountedSubgroups()

    if counted > 0 and ready == counted then
        if IsInRaid() then
            AP:Print(("Raid is ready: %d/%d confirmed (groups 1-%d)."):format(ready, counted, countedSubgroups))
        else
            AP:Print(("Party is ready: %d/%d confirmed."):format(ready, counted))
        end
    else
        local shown = {}
        for i = 1, math.min(#missing, MAX_MISSING_IN_CHAT) do
            shown[i] = missing[i]
        end
        local list = table.concat(shown, ", ")
        if #missing > MAX_MISSING_IN_CHAT then
            list = list .. (" (+%d more, see the panel)"):format(#missing - MAX_MISSING_IN_CHAT)
        end
        if list == "" then
            list = "none"
        end
        AP:Print(("Ready check incomplete: %d/%d ready. Not ready: %s"):format(ready, counted, list))
    end

    CancelFinishTimer()
    finishTimer = C_Timer.NewTimer(HIDE_DELAY, function()
        finishTimer = nil
        if popup then
            popup:Hide()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function ReadyCheck:Enable()
    LoadCustomIds()
    AP:EnableFeatureEvents("readycheck")
    EnsurePopup()
end

function ReadyCheck:Disable()
    AP:DisableFeatureEvents("readycheck")
    checkActive = false
    CancelFinishTimer()
    if auraRefreshTimer then
        auraRefreshTimer:Cancel()
        auraRefreshTimer = nil
    end
    wipe(dirtyUnits)
    if popup then
        popup:Hide()
    end
end

function ReadyCheck:Restore()
    if IsEnabled() then
        self:Enable()
    else
        LoadCustomIds()
    end
end

-- ---------------------------------------------------------------------------
-- Settings surface
-- ---------------------------------------------------------------------------

function ReadyCheck:IsEnabled()
    return IsEnabled()
end

function ReadyCheck:SetEnabled(value)
    local settings = GetSettings()
    settings.enabled = value == true

    if settings.enabled then
        self:Enable()
    else
        self:Disable()
    end
end

function ReadyCheck:GetCustomBuffIds()
    return GetSettings().customBuffIds or ""
end

function ReadyCheck:SetDebug(value)
    debugEnabled = value == true
    DebugPrint("debug output", debugEnabled and "enabled" or "disabled")
end

function ReadyCheck:SetCustomBuffIds(text)
    GetSettings().customBuffIds = type(text) == "string" and text or ""
    LoadCustomIds()

    -- Column layout depends on the custom id list; drop the panel so the next
    -- ready check rebuilds it with the new width and columns.
    if popup then
        popup:Hide()
        popup = nil
        rowScrollBox = nil
        subtitleLabel = nil
        summaryLabel = nil
        headerName = nil
        wipe(headerCells)
    end
end
