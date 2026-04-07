local AP = {}
_G["APRaidUtils"] = AP
_G["AP"] = AP

local eventFrame = CreateFrame("Frame")
AP.eventFrame = eventFrame
eventFrame:SetAllPoints(UIParent)
eventFrame:SetFrameStrata("BACKGROUND")

local simcRequiredEquipmentSlots = {
    "head",
    "neck",
    "shoulder",
    "back",
    "chest",
    "wrist",
    "hands",
    "waist",
    "legs",
    "feet",
    "finger1",
    "finger2",
    "trinket1",
    "trinket2",
    "main_hand",
    "off_hand",
}

local function GetSimcLineValue(exportText, prefix)
    return exportText:match("\n" .. prefix .. "([^\n]*)") or exportText:match("^" .. prefix .. "([^\n]*)")
end

local function NormalizeRealmForKey(realmName)
    if not realmName or realmName == "" then
        return ""
    end

    return realmName:gsub("[%s%-']", ""):lower()
end

local function GetNormalizedRealmNameSafe()
    local realmName = nil
    if GetNormalizedRealmName then
        realmName = GetNormalizedRealmName()
        if realmName and realmName ~= "" then
            return NormalizeRealmForKey(realmName)
        end
    end

    realmName = GetRealmName() or ""
    return NormalizeRealmForKey(realmName)
end

local function WrapTextInClassColor(classFile, text)
    local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local classColor = colorTable and classFile and colorTable[classFile]
    if not classColor or not text or text == "" then
        return text
    end

    if classColor.colorStr and classColor.colorStr ~= "" then
        return "|c" .. classColor.colorStr .. text .. "|r"
    end

    if classColor.r and classColor.g and classColor.b then
        return string.format("|cff%02x%02x%02x%s|r", math.floor(classColor.r * 255), math.floor(classColor.g * 255), math.floor(classColor.b * 255), text)
    end

    return text
end

local function InitializeSavedVariables()
    APRaidUtilsDB = APRaidUtilsDB or {}
    APRaidUtilsDB.profile = APRaidUtilsDB.profile or {}
    APRaidUtilsDB.global = APRaidUtilsDB.global or {}
    APRaidUtilsDB.global.pendingReopenAction = nil
    APRaidUtilsDB.global.simc = APRaidUtilsDB.global.simc or {
        characters = {},
        exports = {},
    }
end

function AP:Print(...)
    print("|cFFFFD100APRaidUtils|r:", ...)
end

function AP:OnAddonLoaded()
    InitializeSavedVariables()
    self:CleanupSimcData()

    if AP.Comms then
        AP.Comms:RegisterCallback("CHECK_UPDATE", function(event, sender, distribution, data)
            local theirVersion = data and data.versions and data.versions.APRaidUtils
            local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
            if theirVersion and myVersion and self:IsVersionNewer(theirVersion, myVersion) then
                self:Print("A newer version of APRaidUtils is available: " .. theirVersion)
            end
        end)
    end

    self:Print("Loaded")
end

function AP:OnPlayerLogin()
    self:CleanupSimcData()
    self:RegisterCurrentCharacter()
    self:NotifyOptionsChanged()

    if IsInGuild() and AP.Comms then
        local myVersion = C_AddOns.GetAddOnMetadata("APRaidUtils", "Version")
        AP.Comms:Broadcast("CHECK_UPDATE", "GUILD", {versions = {APRaidUtils = myVersion}})
    end
end

function AP:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        self:CleanupSimcData()
        self:RegisterCurrentCharacter()
        self:NotifyOptionsChanged()
    end

    local pendingAction = APRaidUtilsDB and APRaidUtilsDB.global and APRaidUtilsDB.global.pendingReopenAction
    if pendingAction and self.OpenMainWindow then
        self:OpenMainWindow(pendingAction.tab or "SimC")
        APRaidUtilsDB.global.pendingReopenAction = nil
    end
end

function AP:GetEffectiveMaxLevel()
    if GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer then
        return GameRulesUtil.GetEffectiveMaxLevelForPlayer()
    end

    if GetMaxPlayerLevel then
        return GetMaxPlayerLevel()
    end

    if GetMaxLevelForPlayerExpansion then
        return GetMaxLevelForPlayerExpansion()
    end

    return 0
end

function AP:IsMaxLevel(level)
    local maxLevel = self:GetEffectiveMaxLevel()
    if maxLevel <= 0 then
        return false
    end

    return (level or 0) >= maxLevel
end

function AP:GetCharacterKey(name, realm)
    if not name or name == "" then
        return nil
    end

    local characterRealm = NormalizeRealmForKey(realm or GetNormalizedRealmNameSafe())
    if not characterRealm or characterRealm == "" then
        return name
    end

    return name .. "-" .. characterRealm
end

function AP:GetCharacterNameText(character)
    if not character or not character.name then
        return ""
    end

    if character.realm and character.realm ~= "" then
        return character.name .. "-" .. character.realm
    end

    return character.name
end

function AP:GetCharacterDisplayName(character)
    return WrapTextInClassColor(character and character.classFile, self:GetCharacterNameText(character))
end

function AP:GetCharacterClassText(character)
    if not character or not character.classFile then
        return ""
    end

    return LOCALIZED_CLASS_NAMES_MALE[character.classFile] or LOCALIZED_CLASS_NAMES_FEMALE[character.classFile] or character.classFile
end

function AP:GetCharacterSpecializationText(character, specName)
    local specialization = specName or (character and character.specName)
    if not specialization or specialization == "" then
        return ""
    end

    local classText = self:GetCharacterClassText(character)
    if classText ~= "" then
        return specialization .. " - " .. classText
    end

    return specialization
end

function AP:GetPlayerCharacterInfo()
    local name = UnitName("player")
    local realm = GetRealmName() or ""
    local normalizedRealm = GetNormalizedRealmNameSafe()
    local level = UnitLevel("player") or 0
    local _, classFile = UnitClassBase("player")

    local specIndex = nil
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        specIndex = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        specIndex = GetSpecialization()
    end

    local specName = nil
    if specIndex and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local _, localizedSpecName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        specName = localizedSpecName
    end

    return {
        key = self:GetCharacterKey(name, normalizedRealm),
        name = name,
        realm = realm,
        normalizedRealm = normalizedRealm,
        level = level,
        classFile = classFile,
        specName = specName,
        isMaxLevel = self:IsMaxLevel(level),
    }
end

function AP:GetSimcStorage()
    return APRaidUtilsDB and APRaidUtilsDB.global and APRaidUtilsDB.global.simc or { characters = {}, exports = {} }
end

function AP:IsSimcExportValid(exportText)
    if not exportText or exportText == "" then
        return false
    end

    local specialization = GetSimcLineValue(exportText, "spec=")
    if not specialization or specialization == "" or specialization == "unknown" then
        return false
    end

    local role = GetSimcLineValue(exportText, "role=")
    if not role or role == "" then
        return false
    end

    local lootSpec = GetSimcLineValue(exportText, "# loot_spec=")
    if not lootSpec or lootSpec == "" then
        return false
    end

    if not exportText:find("\ntalents=", 1, true) and not exportText:find("^talents=", 1, true) then
        return false
    end

    for _, slotName in ipairs(simcRequiredEquipmentSlots) do
        if exportText:find("\n" .. slotName .. "=", 1, true) or exportText:find("^" .. slotName .. "=") then
            return true
        end
    end

    return false
end

function AP:CleanupSimcData()
    if self._simcCleanupDone then return end
    self._simcCleanupDone = true

    local simc = self:GetSimcStorage()
    local maxLevel = self:GetEffectiveMaxLevel()

    for characterKey, character in pairs(simc.characters) do
        if type(character) ~= "table" or not character.name or (character.level or 0) < maxLevel then
            simc.characters[characterKey] = nil
            simc.exports[characterKey] = nil
        end
    end

    for characterKey, exportData in pairs(simc.exports) do
        if not simc.characters[characterKey] or type(exportData) ~= "table" or not exportData.text or exportData.text == "" then
            simc.exports[characterKey] = nil
        end
    end
end

function AP:RegisterCurrentCharacter()
    local characterInfo = self:GetPlayerCharacterInfo()
    if not characterInfo or not characterInfo.key then
        return nil
    end

    local simc = self:GetSimcStorage()
    if not characterInfo.isMaxLevel then
        simc.characters[characterInfo.key] = nil
        simc.exports[characterInfo.key] = nil
        return characterInfo
    end

    local existing = simc.characters[characterInfo.key] or {}
    simc.characters[characterInfo.key] = {
        name = characterInfo.name,
        realm = characterInfo.realm,
        classFile = characterInfo.classFile,
        specName = characterInfo.specName,
        level = characterInfo.level,
        enabled = existing.enabled == true,
        lastSeen = time(),
    }

    return characterInfo
end

function AP:GetSimcCharacter(characterKey)
    return self:GetSimcStorage().characters[characterKey]
end

function AP:GetSimcCharacters()
    local characters = {}
    for characterKey, character in pairs(self:GetSimcStorage().characters) do
        characters[#characters + 1] = {
            key = characterKey,
            name = character.name,
            realm = character.realm,
            classFile = character.classFile,
            specName = character.specName,
            level = character.level,
            enabled = character.enabled == true,
            lastSeen = character.lastSeen,
        }
    end

    table.sort(characters, function(left, right)
        return self:GetCharacterNameText(left) < self:GetCharacterNameText(right)
    end)

    return characters
end

function AP:GetSimcExport(characterKey)
    return self:GetSimcStorage().exports[characterKey]
end

function AP:GetSimcExportCharacters()
    local characters = {}
    local simc = self:GetSimcStorage()
    for _, character in ipairs(self:GetSimcCharacters()) do
        local exportData = simc.exports[character.key]
        if exportData and exportData.text and exportData.text ~= "" then
            characters[#characters + 1] = character
        end
    end

    return characters
end

function AP:IsSimcCharacterEnabled(characterKey)
    local character = self:GetSimcCharacter(characterKey)
    return character and character.enabled == true or false
end

function AP:SetSimcCharacterEnabled(characterKey, enabled)
    local character = self:GetSimcCharacter(characterKey)
    if not character then
        return
    end

    character.enabled = enabled == true
    self:NotifyOptionsChanged()
end

function AP:SaveSimcExport(characterInfo, exportText)
    if not characterInfo or not characterInfo.key or not exportText or exportText == "" then
        return false
    end

    local simc = self:GetSimcStorage()
    local character = simc.characters[characterInfo.key]
    if not character then
        return false
    end

    if not self:IsSimcExportValid(exportText) then
        return false
    end

    local updatedAt = time()
    character.specName = characterInfo.specName
    character.level = characterInfo.level
    character.lastSeen = updatedAt

    simc.exports[characterInfo.key] = {
        text = exportText,
        updatedAt = updatedAt,
        level = characterInfo.level,
        specName = characterInfo.specName,
    }

    self:NotifyOptionsChanged()
    return true
end

function AP:NotifyOptionsChanged()
    if self.RefreshSimcTab then
        self:RefreshSimcTab()
    end

    if self.RefreshSettingsTab then
        self:RefreshSettingsTab()
    end

    if self.RefreshRemindersTab then
        self:RefreshRemindersTab()
    end
end

function AP:HandleChatCommand()
    if self.ToggleMainWindow then
        self:ToggleMainWindow()
        return
    end

    self:Print("APRaidUtils UI is unavailable.")
end

function AP:IsVersionNewer(their, mine)
    local maj1, min1, pat1 = tostring(their):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj1, min1, pat1 = tonumber(maj1) or 0, tonumber(min1) or 0, tonumber(pat1) or 0

    local maj2, min2, pat2 = tostring(mine):match("^v?(%d+)%.?(%d*)%.?(%d*)$")
    maj2, min2, pat2 = tonumber(maj2) or 0, tonumber(min2) or 0, tonumber(pat2) or 0

    if maj1 > maj2 then return true end
    if maj1 == maj2 and min1 > min2 then return true end
    if maj1 == maj2 and min1 == min2 and pat1 > pat2 then return true end
    return false
end

function AP:ShowReloadDialog(options)
    if not options or not options.text then return end

    local popup = StaticPopup_Show("AP_RELOAD_DIALOG")
    if popup then
        popup.text:SetText(options.text)
        popup.data = options.action
    end
end

SlashCmdList["APRAIDUTILS"] = function(msg) AP:HandleChatCommand(msg) end
SLASH_APRAIDUTILS1 = "/ap"

StaticPopupDialogs["AP_RELOAD_DIALOG"] = {
    text = "%s",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}