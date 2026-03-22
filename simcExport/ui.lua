local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local SimcExport = AP:GetModule("SimcExport")
local AceGUI = LibStub("AceGUI-3.0")

local browserFrame = nil
local characterDropdown = nil
local statusLabel = nil
local metadataLabel = nil
local exportBox = nil
local selectedCharacterKey = nil

local function FormatSavedTime(timestamp)
    if not timestamp then
        return "Unknown"
    end

    return date("%Y-%m-%d %H:%M", timestamp)
end

local function ResetFrameReferences()
    browserFrame = nil
    characterDropdown = nil
    statusLabel = nil
    metadataLabel = nil
    exportBox = nil
    selectedCharacterKey = nil
end

local function HideBrowserFrame()
    if browserFrame then
        browserFrame:Hide()
    end
end

function SimcExport:SelectCharacter(characterKey)
    selectedCharacterKey = characterKey

    if not characterKey then
        statusLabel:SetText("No saved SimulationCraft exports found.")
        statusLabel:SetColor(1, 0.82, 0)
        metadataLabel:SetText("")
        exportBox:SetText("")
        return
    end

    local character = AP:GetSimcCharacter(characterKey)
    local exportData = AP:GetSimcExport(characterKey)
    if not character or not exportData or not exportData.text or exportData.text == "" then
        statusLabel:SetText("No saved SimulationCraft exports found.")
        statusLabel:SetColor(1, 0.82, 0)
        metadataLabel:SetText("")
        exportBox:SetText("")
        return
    end

    local metadata = AP:GetCharacterDisplayName(character)
    local specializationText = AP:GetCharacterSpecializationText(character, exportData.specName)
    if specializationText ~= "" then
        metadata = metadata .. " - " .. specializationText
    end
    metadata = metadata .. " - Saved " .. FormatSavedTime(exportData.updatedAt)

    statusLabel:SetText("Select the text below and copy it into SimulationCraft.")
    statusLabel:SetColor(0.8, 0.8, 1)
    metadataLabel:SetText(metadata)
    exportBox:SetText(exportData.text)
    exportBox:HighlightText()
end

function SimcExport:RefreshUI()
    if not browserFrame then
        return
    end

    local dropdownValues = {}
    local exportCharacters = AP:GetSimcExportCharacters()
    for _, character in ipairs(exportCharacters) do
        local label = AP:GetCharacterDisplayName(character)
        local exportData = AP:GetSimcExport(character.key)
        local specializationText = AP:GetCharacterSpecializationText(character, exportData and exportData.specName)
        if specializationText ~= "" then
            label = label .. " (" .. specializationText .. ")"
        end
        dropdownValues[character.key] = label
    end

    characterDropdown:SetList(dropdownValues)

    if #exportCharacters == 0 then
        characterDropdown:SetDisabled(true)
        characterDropdown:SetValue(nil)
        self:SelectCharacter(nil)
        return
    end

    characterDropdown:SetDisabled(false)

    if not selectedCharacterKey or not dropdownValues[selectedCharacterKey] then
        local currentCharacter = AP:GetPlayerCharacterInfo()
        if currentCharacter and currentCharacter.key and dropdownValues[currentCharacter.key] then
            selectedCharacterKey = currentCharacter.key
        else
            selectedCharacterKey = exportCharacters[1].key
        end
    end

    characterDropdown:SetValue(selectedCharacterKey)
    self:SelectCharacter(selectedCharacterKey)
end

function SimcExport:ShowUI()
    if browserFrame then
        browserFrame:Release()
        ResetFrameReferences()
    end

    browserFrame = AceGUI:Create("Frame")
    browserFrame:SetTitle("APRaidUtils SimulationCraft Exports")
    browserFrame:SetWidth(850)
    browserFrame:SetHeight(620)
    browserFrame:SetLayout("List")
    browserFrame:SetCallback("OnClose", function(widget)
        ResetFrameReferences()
        AceGUI:Release(widget)
    end)
    browserFrame.frame:EnableKeyboard(true)
    if browserFrame.frame.SetPropagateKeyboardInput then
        browserFrame.frame:SetPropagateKeyboardInput(false)
    end
    browserFrame.frame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            HideBrowserFrame()
        end
    end)

    local introLabel = AceGUI:Create("Label")
    introLabel:SetText("Browse the latest saved SimulationCraft export for each enabled max-level character.")
    introLabel:SetFullWidth(true)
    browserFrame:AddChild(introLabel)

    characterDropdown = AceGUI:Create("Dropdown")
    characterDropdown:SetLabel("Character")
    characterDropdown:SetFullWidth(true)
    characterDropdown:SetCallback("OnValueChanged", function(_, _, value)
        SimcExport:SelectCharacter(value)
    end)
    browserFrame:AddChild(characterDropdown)

    statusLabel = AceGUI:Create("Label")
    statusLabel:SetText("")
    statusLabel:SetFullWidth(true)
    browserFrame:AddChild(statusLabel)

    metadataLabel = AceGUI:Create("Label")
    metadataLabel:SetText("")
    metadataLabel:SetFullWidth(true)
    browserFrame:AddChild(metadataLabel)

    exportBox = AceGUI:Create("MultiLineEditBox")
    exportBox:SetLabel("Saved Export")
    exportBox:SetNumLines(24)
    exportBox:SetFullWidth(true)
    exportBox:DisableButton(true)
    exportBox.editBox:SetScript("OnEscapePressed", HideBrowserFrame)
    browserFrame:AddChild(exportBox)

    self:RefreshUI()
end
