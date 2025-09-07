-- APRaidUtils VersionChecker UI
local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local VersionChecker = AP:GetModule("VersionChecker")
local AceGUI = LibStub("AceGUI-3.0")

local uiFrame


function VersionChecker:ShowUI()
    if uiFrame then
        uiFrame:Release()
    end
    uiFrame = AceGUI:Create("Frame")
    uiFrame:SetTitle("APRaidUtils Version Checker")
    uiFrame:SetWidth(600)
    uiFrame:SetHeight(350)
    uiFrame:SetLayout("List")

    -- Horizontal group for controls
    local controlRow = AceGUI:Create("SimpleGroup")
    controlRow:SetLayout("Flow")
    controlRow:SetFullWidth(true)

    -- Hardcoded WeakAura names
    local waNamesList = {
        "Liquid - Manaforge Omega",
        "Liquid Anchors (don't rename these)",
        "LiquidWeakAuras"
    }
    local fixedColumns = {"BigWigs", "DBM", "MRT", "NS", "WeakAuras"}
    VersionChecker.uiRequestedWANames = waNamesList

    -- Button to check versions
    local checkBtn = AceGUI:Create("Button")
    checkBtn:SetText("Check Versions")
    checkBtn:SetWidth(200)
    checkBtn:SetCallback("OnClick", function()
        VersionChecker:ClearUIResults()
        -- Update header
        local headerRow = VersionChecker.uiHeaderRow
        headerRow:ReleaseChildren()
        local widths = {120}
        for i = 1, #fixedColumns do widths[i+1] = 80 end
        for i = 1, #waNamesList do widths[#fixedColumns+1+i] = 120 end
        local nameLbl = AceGUI:Create("Label")
        nameLbl:SetText("|cff00ff00Name|r")
        nameLbl:SetWidth(widths[1])
        headerRow:AddChild(nameLbl)
        for i, col in ipairs(fixedColumns) do
            local lbl = AceGUI:Create("Label")
            lbl:SetText("|cff00ff00" .. col .. "|r")
            lbl:SetWidth(widths[i+1])
            headerRow:AddChild(lbl)
        end
        for i, waName in ipairs(waNamesList) do
            local lbl = AceGUI:Create("Label")
            lbl:SetText("|cff00ff00" .. waName .. "|r")
            lbl:SetWidth(widths[#fixedColumns+1+i])
            headerRow:AddChild(lbl)
        end
        VersionChecker:RequestVersionCheck(waNamesList)
    end)

    controlRow:AddChild(checkBtn)
    uiFrame:AddChild(controlRow)

    -- Table header (use horizontal group for proper alignment)
    local headerRow = AceGUI:Create("SimpleGroup")
    headerRow:SetLayout("Flow")
    headerRow:SetFullWidth(true)
    VersionChecker.uiRequestedWANames = nil -- will be set on check
    VersionChecker.uiHeaderRow = headerRow -- for later update
    uiFrame:AddChild(headerRow)

    -- ScrollFrame for results
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("List")
    uiFrame:AddChild(scroll)

    VersionChecker.uiResultScroll = scroll
    VersionChecker.uiFrame = uiFrame
end

function VersionChecker:ClearUIResults()
    if self.uiResultScroll then
        self.uiResultScroll:ReleaseChildren()
    end
end

function VersionChecker:AppendUIResultRow(name, versions)
    local fixedColumns = {"BigWigs", "DBM", "MRT", "NS", "WeakAuras"}
    local waPluginsList = {
        "Liquid - Manaforge Omega",
        "Liquid Anchors (don't rename these)",
        "LiquidWeakAuras"
    }
    local rowGroup = AceGUI:Create("SimpleGroup")
    rowGroup:SetLayout("Flow")
    rowGroup:SetFullWidth(true)
    local widths = {120}
    for i = 1, #fixedColumns do widths[i+1] = 80 end
    for i = 1, #waPluginsList do widths[#fixedColumns+1+i] = 120 end
    -- Name column
    local nameLbl = AceGUI:Create("Label")
    nameLbl:SetText(tostring(name))
    nameLbl:SetWidth(widths[1])
    rowGroup:AddChild(nameLbl)
    -- Fixed columns
    for i, col in ipairs(fixedColumns) do
        local val = versions[col] or "-"
        -- Only show WeakAuras addon version, not WA table
        if col == "WeakAuras" and type(val) == "table" then
            val = val.version or "-" -- try to get .version field if present
        end
        local lbl = AceGUI:Create("Label")
        lbl:SetText(tostring(val))
        lbl:SetWidth(widths[i+1])
        rowGroup:AddChild(lbl)
    end
    -- Dynamic WA plugin columns
    local waVersions = {}
    for k, v in pairs(versions) do
        if type(v) == "table" then
            for waName, waVer in pairs(v) do
                waVersions[waName] = waVer
            end
        end
    end
    for i, waName in ipairs(waPluginsList) do
        local val = waVersions[waName]
        if val == nil then val = versions[waName] or "-" end
        local lbl = AceGUI:Create("Label")
        lbl:SetText(tostring(val))
        lbl:SetWidth(widths[#fixedColumns+1+i])
        rowGroup:AddChild(lbl)
    end
    self.uiResultScroll:AddChild(rowGroup)
end

function VersionChecker:AppendUIResult(msg)
    if self.uiResultBox then
        local prev = self.uiResultBox:GetText() or ""
        self.uiResultBox:SetText(prev .. "\n" .. msg)
    end
end