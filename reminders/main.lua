local AP = _G["APRaidUtils"]

local Reminders = {}
AP.Reminders = Reminders

local bitBand = bit and bit.band
local CURRENT_EXPANSION_RAID_FILTER = "CURRENT_EXPANSION"

local function CopyTableShallow(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function CopyTableDeep(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTableDeep(value)
    end
    return copy
end

local function NormalizeText(value)
    if value == nil then
        value = ""
    elseif type(value) ~= "string" then
        value = tostring(value)
    end
    value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
    value = string.gsub(value, "|r", "")
    value = string.gsub(value, "%s+", " ")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function NormalizeLabelKey(value)
    value = NormalizeText(value)
    value = value:gsub("%s*%(%d+%)$", "")
    return value:lower()
end

local function IsPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function GetSpellNameSafe(spellId)
    if not IsPositiveNumber(spellId) then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
    if GetSpellInfo then
        return GetSpellInfo(spellId)
    end
    return nil
end

local function GetSpellIconSafe(spellId)
    if not IsPositiveNumber(spellId) then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellId)
    end
    if GetSpellTexture then
        return GetSpellTexture(spellId)
    end
    return nil
end

local function GetEncounterInstanceName(encounterId)
    if not IsPositiveNumber(encounterId) or not EJ_GetInstanceForEncounter then
        return nil, nil
    end
    local instanceId = EJ_GetInstanceForEncounter(encounterId)
    if not IsPositiveNumber(instanceId) then
        return nil, nil
    end
    if EJ_GetInstanceInfo then
        local instanceName = EJ_GetInstanceInfo(instanceId)
        return instanceId, instanceName
    end
    return instanceId, nil
end

local function GetJournalInstanceName(instanceId)
    if not IsPositiveNumber(instanceId) or not EJ_GetInstanceInfo then
        return nil
    end
    return EJ_GetInstanceInfo(instanceId)
end

local function GetMapName(mapId)
    if not IsPositiveNumber(mapId) or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local mapInfo = C_Map.GetMapInfo(mapId)
    return mapInfo and mapInfo.name or nil
end

local function GetZoneText(zoneId)
    if not IsPositiveNumber(zoneId) or not GetRealZoneText then
        return nil
    end
    return GetRealZoneText(zoneId)
end

local function CleanAddonName(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    addonName = addonName:gsub("^BigWigs_", "")
    addonName = addonName:gsub("^LittleWigs_", "")
    addonName = addonName:gsub("_", " ")
    return addonName
end

local function GetAddonTitle(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local title = C_AddOns.GetAddOnMetadata(addonName, "Title")
        if title and title ~= "" then
            title = title:gsub("^BigWigs:%s*", "")
            title = title:gsub("^LittleWigs:%s*", "")
            return title
        end
    end
    return nil
end

local function GetPrimaryRaidId(module)
    if type(module) ~= "table" then
        return nil
    end
    if type(module.instanceId) == "number" then
        return module.instanceId
    end
    if type(module.instanceId) == "table" then
        return module.instanceId[1]
    end
    if type(module.otherMenu) == "number" then
        return module.otherMenu
    end
    if type(module.otherMenu) == "table" then
        return module.otherMenu[1]
    end
    return nil
end

local function ModuleMatchesRaid(module, raidId)
    if not IsPositiveNumber(raidId) or type(module) ~= "table" then
        return false
    end
    if type(module.instanceId) == "number" and module.instanceId == raidId then
        return true
    end
    if type(module.instanceId) == "table" then
        for _, value in ipairs(module.instanceId) do
            if value == raidId then
                return true
            end
        end
    end
    if type(module.otherMenu) == "number" and module.otherMenu == raidId then
        return true
    end
    if type(module.otherMenu) == "table" then
        for _, value in ipairs(module.otherMenu) do
            if value == raidId then
                return true
            end
        end
    end
    return false
end

local function AppendOptionEntries(target, optionList)
    if type(optionList) ~= "table" then
        return
    end
    local indexed = {}
    for index, value in pairs(optionList) do
        if type(index) == "number" then
            indexed[#indexed + 1] = {
                index = index,
                value = value,
            }
        end
    end
    table.sort(indexed, function(left, right)
        return left.index < right.index
    end)
    for _, entry in ipairs(indexed) do
        target[#target + 1] = entry.value
    end
end

local function AppendOptionHeaderMap(target, headerData)
    if type(headerData) ~= "table" then
        return
    end
    for optionKey, headerValue in pairs(headerData) do
        if type(optionKey) == "number" and type(headerValue) == "table" and type(headerValue.tabName) == "string" and type(headerValue[1]) == "table" then
            for _, nestedOption in ipairs(headerValue[1]) do
                target[nestedOption] = headerValue.tabName
            end
        elseif type(optionKey) == "string" or type(optionKey) == "number" then
            if type(headerValue) == "string" or type(headerValue) == "number" then
                target[optionKey] = headerValue
            end
        end
    end
end

local function NormalizeHeaderText(headerValue)
    if type(headerValue) == "string" then
        return NormalizeText(headerValue)
    end
    if type(headerValue) == "number" then
        if headerValue < 0 and C_EncounterJournal_GetSectionInfo then
            local sectionInfo = C_EncounterJournal_GetSectionInfo(-headerValue)
            if sectionInfo and sectionInfo.title then
                return NormalizeText(sectionInfo.title)
            end
        end
        local spellName = GetSpellNameSafe(headerValue)
        if spellName then
            return NormalizeText(spellName)
        end
    end
    return nil
end

local function NormalizeStageValue(stage)
    local numericStage = tonumber(stage)
    if not numericStage or numericStage <= 0 then
        return nil
    end
    return math.floor((numericStage * 100) + 0.5) / 100
end

local function IsFractionalStage(stage)
    local normalizedStage = NormalizeStageValue(stage)
    if not normalizedStage then
        return false
    end
    local integerStage = math.floor(normalizedStage + 0.0001)
    return math.abs(normalizedStage - integerStage) > 0.001
end

local function BuildPhaseTokenFromStage(stage)
    local normalizedStage = NormalizeStageValue(stage)
    if not normalizedStage then
        return nil
    end
    if IsFractionalStage(normalizedStage) then
        return string.format("intermission:%d", math.max(1, math.floor(normalizedStage)))
    end
    return string.format("stage:%d", math.floor(normalizedStage + 0.0001))
end

local function BuildPhaseLabelFromToken(token)
    if type(token) ~= "string" or token == "" then
        return nil
    end
    local stageNumber = token:match("^stage:(%d+)$")
    if stageNumber then
        return string.format("Stage %d", tonumber(stageNumber) or 0)
    end
    local intermissionNumber = token:match("^intermission:(%d+)$")
    if intermissionNumber then
        return string.format("Intermission %d", tonumber(intermissionNumber) or 0)
    end
    if token == "intermission:any" then
        return "Intermission"
    end
    return token
end

local function GetPhaseTokenSortValue(token)
    if type(token) ~= "string" then
        return 9999
    end
    local stageNumber = tonumber(token:match("^stage:(%d+)$"))
    if stageNumber then
        return (stageNumber * 10)
    end
    local intermissionNumber = tonumber(token:match("^intermission:(%d+)$"))
    if intermissionNumber then
        return (intermissionNumber * 10) + 5
    end
    if token == "intermission:any" then
        return 9995
    end
    return 9999
end

local function GetBigWigsCommonLocale()
    if type(BigWigsAPI) ~= "table" or type(BigWigsAPI.GetLocale) ~= "function" then
        return nil
    end
    local success, locale = pcall(BigWigsAPI.GetLocale, BigWigsAPI, "BigWigs: Common")
    if success and type(locale) == "table" then
        return locale
    end
    return nil
end

local function MatchCountHeader(headerText, template)
    if type(headerText) ~= "string" or type(template) ~= "string" or template == "" then
        return nil
    end
    for index = 1, 10 do
        if headerText == string.format(template, index) then
            return index
        end
    end
    return nil
end

local function ParsePhaseHeaderValue(headerValue)
    local headerText = NormalizeHeaderText(headerValue)
    if not headerText or headerText == "" then
        return nil
    end
    local commonLocale = GetBigWigsCommonLocale()
    local stageNumber = MatchCountHeader(headerText, commonLocale and commonLocale.stage)
        or MatchCountHeader(headerText, commonLocale and commonLocale.phase)
        or MatchCountHeader(headerText, "Stage %d")
        or MatchCountHeader(headerText, "Phase %d")
    if stageNumber then
        return {
            headerText = headerText,
            stageValue = stageNumber,
            phaseToken = BuildPhaseTokenFromStage(stageNumber),
        }
    end
    local intermissionNumber = nil
    if commonLocale and type(commonLocale.count) == "string" and type(commonLocale.intermission) == "string" then
        for index = 1, 10 do
            if headerText == string.format(commonLocale.count, commonLocale.intermission, index) then
                intermissionNumber = index
                break
            end
        end
    end
    local lowerHeader = headerText:lower()
    stageNumber = tonumber(lowerHeader:match("^stage%s+(%d+)$") or lowerHeader:match("^phase%s+(%d+)$"))
    if stageNumber then
        return {
            headerText = headerText,
            stageValue = stageNumber,
            phaseToken = BuildPhaseTokenFromStage(stageNumber),
        }
    end
    intermissionNumber = intermissionNumber or tonumber(lowerHeader:match("^intermission%s+(%d+)$") or lowerHeader:match("^intermission%s*%((%d+)%)$"))
    if intermissionNumber then
        local stageValue = intermissionNumber + 0.5
        return {
            headerText = headerText,
            stageValue = stageValue,
            phaseToken = BuildPhaseTokenFromStage(stageValue),
        }
    end
    local intermissionLabel = commonLocale and NormalizeText(commonLocale.intermission):lower() or "intermission"
    if lowerHeader == intermissionLabel or lowerHeader == "intermission" then
        return {
            headerText = headerText,
            genericIntermission = true,
            phaseToken = "intermission:any",
        }
    end
    return {
        headerText = headerText,
    }
end

local function AddUniqueValue(target, value)
    if type(target) ~= "table" or value == nil then
        return false
    end
    for _, existingValue in ipairs(target) do
        if existingValue == value then
            return false
        end
    end
    target[#target + 1] = value
    return true
end

local function AddUniquePhaseMetadata(target, phaseData)
    if type(target) ~= "table" or type(phaseData) ~= "table" then
        return
    end
    target.headerTexts = target.headerTexts or {}
    target.stageValues = target.stageValues or {}
    target.phaseTokens = target.phaseTokens or {}
    if phaseData.headerText and phaseData.headerText ~= "" then
        AddUniqueValue(target.headerTexts, phaseData.headerText)
    end
    if phaseData.stageValue then
        AddUniqueValue(target.stageValues, NormalizeStageValue(phaseData.stageValue))
    end
    if phaseData.phaseToken then
        AddUniqueValue(target.phaseTokens, phaseData.phaseToken)
    end
    if phaseData.genericIntermission then
        target.genericIntermission = true
    end
end

local function BuildOptionPhaseMap(headerData)
    local optionPhaseMap = {}
    if type(headerData) ~= "table" then
        return optionPhaseMap
    end
    for optionKey, headerValue in pairs(headerData) do
        if type(optionKey) == "number" and type(headerValue) == "table" and type(headerValue.tabName) == "string" and type(headerValue[1]) == "table" then
            local phaseData = ParsePhaseHeaderValue(headerValue.tabName)
            for _, nestedOption in ipairs(headerValue[1]) do
                local nestedOptionKey = type(nestedOption) == "table" and nestedOption[1] or nestedOption
                optionPhaseMap[nestedOptionKey] = optionPhaseMap[nestedOptionKey] or {}
                AddUniquePhaseMetadata(optionPhaseMap[nestedOptionKey], phaseData)
            end
        elseif type(optionKey) == "string" or type(optionKey) == "number" then
            local phaseData = ParsePhaseHeaderValue(headerValue)
            if phaseData then
                optionPhaseMap[optionKey] = optionPhaseMap[optionKey] or {}
                AddUniquePhaseMetadata(optionPhaseMap[optionKey], phaseData)
            end
        end
    end
    return optionPhaseMap
end

local function IsM33kAurasAvailable()
    return type(M33kAuras) == "table" and type(M33kAuras.Add) == "function" and type(M33kAuras.Delete) == "function"
end

local function GetM33kAurasDB()
    return M33kAurasSaved and M33kAurasSaved.displays
end

local function GetDefinitionRaidId(definition)
    if type(definition) ~= "table" then
        return nil
    end

    local raidId = tonumber(definition.raidId)
    if IsPositiveNumber(raidId) then
        return raidId
    end

    local instanceId = tonumber(definition.instanceId)
    if IsPositiveNumber(instanceId) then
        return instanceId
    end

    return nil
end

local function EnsureRuntimeState(self)
    if type(self.loadedRaidIds) ~= "table" then
        self.loadedRaidIds = {}
    end

    if type(self.cachedDefinitions) ~= "table" then
        self.cachedDefinitions = {}
    end
end

function Reminders:GetKnownRaidIds(onlyCurrentExpansion)
    local raidIds = {}

    if not self:IsBigWigsAvailable() or type(BigWigsLoader.zoneTbl) ~= "table" then
        return raidIds
    end

    for zoneId, addonName in pairs(BigWigsLoader.zoneTbl) do
        if IsPositiveNumber(zoneId) and type(addonName) == "string" and addonName:find("BigWigs", 1, true) then
            if not onlyCurrentExpansion or self:IsCurrentExpansionRaidId(zoneId) then
                raidIds[#raidIds + 1] = zoneId
            end
        end
    end

    table.sort(raidIds, function(left, right)
        return tostring(self:GetRaidDisplayName(left)):lower() < tostring(self:GetRaidDisplayName(right)):lower()
    end)

    return raidIds
end

function Reminders:OnInitialize()
    EnsureRuntimeState(self)
    self.loadedRaidIds = {}
    self.discoveryComplete = false
    self.lastViewedTimerKey = nil
end

function Reminders:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "HandleAddonLoaded")
    self:RegisterEvent("ENCOUNTER_START", "HandleEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "HandleEncounterEnd")
end

function Reminders:OnDisable()
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
end

function Reminders:RefreshUI()
    if AP.RefreshRemindersTab then
        AP:RefreshRemindersTab()
    end
end

function Reminders:HandleAddonLoaded(_, addonName)
    if addonName == "BigWigs" then
        self:RefreshUI()
    end
end

function Reminders:HandleEncounterStart(_, encounterId)
    self.currentEncounterId = encounterId
end

function Reminders:HandleEncounterEnd(_, encounterId)
    if encounterId == self.currentEncounterId or self.currentEncounterId == nil then
        self.currentEncounterId = nil
    end
end

function Reminders:IsBigWigsAvailable()
    return type(BigWigsLoader) == "table" and type(BigWigsLoader.RegisterMessage) == "function"
end

function Reminders:GetBigWigsCore()
    return type(BigWigs) == "table" and BigWigs or nil
end

function Reminders:EnsureBigWigsCoreLoaded()
    if self:GetBigWigsCore() then
        return true
    end
    if C_AddOns and C_AddOns.LoadAddOn and C_AddOns.IsAddOnLoaded then
        if not C_AddOns.IsAddOnLoaded("BigWigs") then
            C_AddOns.LoadAddOn("BigWigs")
        end
        if not C_AddOns.IsAddOnLoaded("BigWigs_Core") then
            C_AddOns.LoadAddOn("BigWigs_Core")
        end
    end
    if BigWigsLoader and BigWigsLoader.LoadAndEnableCore then
        BigWigsLoader.LoadAndEnableCore()
    end
    local core = self:GetBigWigsCore()
    if core and core.Enable then
        core:Enable()
    end
    return self:GetBigWigsCore() ~= nil
end

function Reminders:GetBigWigsBARFlag()
    local core = self:GetBigWigsCore()
    if core and core.C and core.C.BAR then
        return core.C.BAR
    end
    return nil
end

function Reminders:IsInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

function Reminders:GetAllKnownRaidItems()
    local raidIds = self:GetKnownRaidIds(false)
    if #raidIds == 0 then
        return {
            { value = "ALL", label = "All loaded raids" },
        }
    end
    local items = {
        { value = "ALL", label = "All loaded raids" },
    }
    for _, zoneId in ipairs(raidIds) do
        items[#items + 1] = {
            value = tostring(zoneId),
            label = self:GetRaidDisplayName(zoneId),
        }
    end
    return items
end

function Reminders:GetRaidDisplayName(zoneId, addonName)
    local resolvedAddonName = addonName
    if type(BigWigsLoader) == "table" and type(BigWigsLoader.currentExpansion) == "table" and type(BigWigsLoader.currentExpansion.zones) == "table" then
        resolvedAddonName = BigWigsLoader.currentExpansion.zones[zoneId] or resolvedAddonName
    end
    return GetJournalInstanceName(zoneId)
        or GetZoneText(zoneId)
        or GetMapName(zoneId)
        or GetAddonTitle(resolvedAddonName)
        or CleanAddonName(resolvedAddonName)
        or string.format("Raid %d", zoneId)
end

function Reminders:IsCurrentExpansionRaidId(zoneId)
    return IsPositiveNumber(zoneId)
        and type(BigWigsLoader) == "table"
        and type(BigWigsLoader.currentExpansion) == "table"
        and type(BigWigsLoader.currentExpansion.zones) == "table"
        and BigWigsLoader.currentExpansion.zones[zoneId] ~= nil
end

function Reminders:GetRaidFilterItems(onlyCurrentExpansion)
    if not onlyCurrentExpansion then
        return self:GetAllKnownRaidItems()
    end

    local filtered = {
        { value = CURRENT_EXPANSION_RAID_FILTER, label = "Current expansion raids" },
    }

    for _, zoneId in ipairs(self:GetKnownRaidIds(true)) do
        filtered[#filtered + 1] = {
            value = tostring(zoneId),
            label = self:GetRaidDisplayName(zoneId),
        }
    end

    return filtered
end

function Reminders:GetCurrentRaidFilterDefault(onlyCurrentExpansion)
    if onlyCurrentExpansion then
        return CURRENT_EXPANSION_RAID_FILTER
    end

    return "ALL"
end

function Reminders:EnsureRaidMetadataLoaded(filterValue)
    EnsureRuntimeState(self)

    if filterValue == nil or filterValue == "" then
        self.debugLastRaidLoad = {
            raidId = filterValue,
            coreLoaded = self:GetBigWigsCore() ~= nil,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "all",
        }
        return false
    end

    if filterValue == "ALL" or filterValue == CURRENT_EXPANSION_RAID_FILTER then
        local raidIds = self:GetKnownRaidIds(filterValue == CURRENT_EXPANSION_RAID_FILTER)
        local didLoadAny = false

        for _, raidId in ipairs(raidIds) do
            if self:EnsureRaidMetadataLoaded(tostring(raidId)) then
                didLoadAny = true
            end
        end

        self.debugLastRaidLoad = {
            raidId = filterValue,
            coreLoaded = self:GetBigWigsCore() ~= nil,
            usedMenuModules = false,
            modulesSeen = #raidIds,
            matchedModules = #raidIds,
            definitionsBuilt = self:GetDefinitionCount(),
            reason = filterValue == CURRENT_EXPANSION_RAID_FILTER and "current-expansion" or "all-loaded",
        }
        return didLoadAny
    end

    local zoneId = tonumber(filterValue)
    if not IsPositiveNumber(zoneId) then
        self.debugLastRaidLoad = {
            raidId = filterValue,
            coreLoaded = self:GetBigWigsCore() ~= nil,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "invalid",
        }
        return false
    end
    if self.loadedRaidIds[zoneId] then
        self.debugLastRaidLoad = {
            raidId = zoneId,
            coreLoaded = self:GetBigWigsCore() ~= nil,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "cached",
        }
        return false
    end
    if not self:IsBigWigsAvailable() then
        self.debugLastRaidLoad = {
            raidId = zoneId,
            coreLoaded = false,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "loader-missing",
        }
        return false
    end
    if not self:EnsureBigWigsCoreLoaded() then
        self.debugLastRaidLoad = {
            raidId = zoneId,
            coreLoaded = false,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "core-missing",
        }
        return false
    end
    if BigWigsLoader.LoadAndEnableCore then
        BigWigsLoader.LoadAndEnableCore()
    end
    if BigWigsLoader.LoadZone then
        BigWigsLoader:LoadZone(zoneId)
    else
        self.debugLastRaidLoad = {
            raidId = zoneId,
            coreLoaded = self:GetBigWigsCore() ~= nil,
            usedMenuModules = false,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
            reason = "no-loadzone",
        }
        return false
    end
    local count = self:RebuildDefinitionsForRaid(zoneId)
    if count > 0 then
        self.loadedRaidIds[zoneId] = true
        return true
    end
    return false
end

function Reminders:GetDefinitionId(module, optionKey, label)
    local encounterId = module and module.GetEncounterID and module:GetEncounterID() or 0
    local moduleName = module and module.moduleName or "Unknown"
    if IsPositiveNumber(optionKey) then
        return string.format("enc:%s|mod:%s|spell:%d", tostring(encounterId or 0), moduleName, optionKey)
    end
    local optionText = NormalizeText(optionKey)
    if optionText ~= "" then
        return string.format("enc:%s|mod:%s|opt:%s", tostring(encounterId or 0), moduleName, optionText:lower())
    end
    return string.format("enc:%s|mod:%s|text:%s", tostring(encounterId or 0), moduleName, NormalizeLabelKey(label))
end

function Reminders:GetBigWigsOptionDetails(module, optionKey)
    local core = self:GetBigWigsCore()
    if core and core.GetBossOptionDetails then
        local _, title, description, icon, notes = core:GetBossOptionDetails(module, optionKey)
        return title, description, icon, notes
    end
    local spellId = type(optionKey) == "table" and optionKey[1] or optionKey
    local title = IsPositiveNumber(spellId) and GetSpellNameSafe(spellId) or NormalizeText(spellId)
    local icon = IsPositiveNumber(spellId) and GetSpellIconSafe(spellId) or nil
    return title, nil, icon, nil
end

function Reminders:IsTimerOptionSupported(module, optionKey)
    local barFlag = self:GetBigWigsBARFlag()
    if not barFlag or not module or not module.toggleDefaults then
        return true
    end
    local defaultFlags = module.toggleDefaults[optionKey]
    if type(defaultFlags) == "number" and bitBand then
        return bitBand(defaultFlags, barFlag) == barFlag
    end
    if type(defaultFlags) == "boolean" then
        return defaultFlags == true
    end
    return IsPositiveNumber(optionKey)
end

function Reminders:BuildDefinitionFromOption(module, optionEntry, phaseMetadata, easyNameOverride, optionOrder, bossOrder)
    local optionKey = type(optionEntry) == "table" and optionEntry[1] or optionEntry
    if type(optionKey) ~= "string" and type(optionKey) ~= "number" then
        return nil
    end
    if module.SetupOptions then
        module:SetupOptions()
    end
    if not self:IsTimerOptionSupported(module, optionKey) then
        return nil
    end
    local fullName, description, icon, easyName = self:GetBigWigsOptionDetails(module, optionKey)
    if NormalizeText(easyNameOverride) ~= "" then
        easyName = easyNameOverride
    end
    local spellId = IsPositiveNumber(optionKey) and optionKey or nil
    local raidId = GetPrimaryRaidId(module)
    local encounterId = module.GetEncounterID and module:GetEncounterID() or nil
    local journalId = module.GetJournalID and module:GetJournalID() or nil
    local instanceId, instanceName = GetEncounterInstanceName(encounterId)
    if not instanceId then
        instanceId = raidId or journalId
        instanceName = self:GetRaidDisplayName(instanceId)
    end
    local definitionId = self:GetDefinitionId(module, optionKey, fullName)
    local definition = self.cachedDefinitions and self.cachedDefinitions[definitionId] or {}
    definition.definitionId = definitionId
    definition.raidId = raidId
    definition.encounterId = encounterId
    definition.journalId = journalId
    definition.instanceId = instanceId
    definition.instanceName = instanceName or definition.instanceName or self:GetRaidDisplayName(raidId) or "Unknown Raid"
    definition.moduleName = module.moduleName
    definition.bossName = module.displayName or module.moduleName or "Unknown"
    definition.optionKey = optionKey
    definition.spellId = spellId
    definition.fullName = NormalizeText(fullName ~= nil and fullName or (spellId and GetSpellNameSafe(spellId) or optionKey))
    definition.easyName = NormalizeText(easyName)
    definition.headerText = phaseMetadata and phaseMetadata.headerTexts and phaseMetadata.headerTexts[1] or nil
    definition.phaseHeaders = phaseMetadata and CopyTableDeep(phaseMetadata.headerTexts) or {}
    definition.phaseStageValues = phaseMetadata and CopyTableDeep(phaseMetadata.stageValues) or {}
    definition.hasIntermissionHeader = phaseMetadata and phaseMetadata.genericIntermission == true or false
    definition.observedStageValues = definition.observedStageValues or {}
    definition.description = NormalizeText(description)
    definition.icon = icon
    definition.kind = spellId and "spell" or "option"
    definition.supported = true
    definition.sortName = NormalizeText(definition.fullName ~= "" and definition.fullName or definition.easyName)
    definition.optionOrder = optionOrder or definition.optionOrder or 9999
    definition.bossOrder = bossOrder or definition.bossOrder or 9999
    return definition
end

function Reminders:RebuildDefinitionsForRaid(raidId)
    EnsureRuntimeState(self)

    local core = self:GetBigWigsCore()
    if not core or not core.IterateBossModules then
        self.debugLastRaidLoad = {
            raidId = raidId,
            coreLoaded = core ~= nil,
            modulesSeen = 0,
            matchedModules = 0,
            definitionsBuilt = 0,
        }
        return 0
    end
    local menuModules = nil
    if BigWigsLoader and BigWigsLoader.GetZoneMenus then
        local menus = BigWigsLoader:GetZoneMenus()
        if type(menus) == "table" and type(menus[raidId]) == "table" then
            menuModules = menus[raidId]
        end
    end
    local modules = {}
    local matchedModules = 0
    if menuModules then
        for _, module in pairs(menuModules) do
            modules[#modules + 1] = module
            matchedModules = matchedModules + 1
        end
    else
        for _, module in core:IterateBossModules() do
            modules[#modules + 1] = module
            if ModuleMatchesRaid(module, raidId) then
                matchedModules = matchedModules + 1
            end
        end
    end
    local count = 0
    local bossOrder = 0
    for _, module in ipairs(modules) do
        if menuModules or raidId == nil or ModuleMatchesRaid(module, raidId) then
            bossOrder = bossOrder + 1
            if module.SetupOptions then
                module:SetupOptions()
            end
            local optionEntries = {}
            local optionPhases = {}
            local optionEasyNames = {}
            if type(module.optionHeaders) == "table" then
                optionPhases = BuildOptionPhaseMap(module.optionHeaders)
            end
            if type(module.toggleOptions) == "table" then
                AppendOptionEntries(optionEntries, module.toggleOptions)
            end
            if #optionEntries == 0 and module.GetOptions then
                local options = { module:GetOptions() }
                AppendOptionEntries(optionEntries, options[1])
                if type(options[2]) == "table" and next(optionPhases) == nil then
                    optionPhases = BuildOptionPhaseMap(options[2])
                end
                if type(options[3]) == "table" then
                    for optionKey, easyName in pairs(options[3]) do
                        optionEasyNames[optionKey] = easyName
                    end
                end
            end
            if type(module.notes) == "table" then
                for optionKey, easyName in pairs(module.notes) do
                    optionEasyNames[optionKey] = easyName
                end
            end
            local optionOrder = 0
            for _, optionEntry in ipairs(optionEntries) do
                optionOrder = optionOrder + 1
                local optionKey = type(optionEntry) == "table" and optionEntry[1] or optionEntry
                local definition = self:BuildDefinitionFromOption(module, optionEntry, optionPhases[optionKey], optionEasyNames[optionKey], optionOrder, bossOrder)
                if definition then
                    self.cachedDefinitions[definition.definitionId] = definition
                    count = count + 1
                end
            end
        end
    end
    self.debugLastRaidLoad = {
        raidId = raidId,
        coreLoaded = true,
        usedMenuModules = menuModules and true or false,
        modulesSeen = #modules,
        matchedModules = matchedModules,
        definitionsBuilt = count,
    }
    return count
end

function Reminders:GetDefinitionsForRaid(filterValue)
    if filterValue then
        self:EnsureRaidMetadataLoaded(filterValue)
    end
    local rows = {}
    for definitionId, definition in pairs(self.cachedDefinitions or {}) do
        local definitionRaidId = GetDefinitionRaidId(definition)
        local matchesFilter = filterValue == nil
            or filterValue == "ALL"
            or (filterValue == CURRENT_EXPANSION_RAID_FILTER and self:IsCurrentExpansionRaidId(definitionRaidId))
            or tostring(definitionRaidId or "") == tostring(filterValue)

        if matchesFilter then
            local row = CopyTableShallow(definition)
            row.timerKey = definitionId
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(left, right)
        local leftBossOrder = tonumber(left.bossOrder or 9999)
        local rightBossOrder = tonumber(right.bossOrder or 9999)
        if leftBossOrder ~= rightBossOrder then
            return leftBossOrder < rightBossOrder
        end
        local leftOptionOrder = tonumber(left.optionOrder or 9999)
        local rightOptionOrder = tonumber(right.optionOrder or 9999)
        if leftOptionOrder ~= rightOptionOrder then
            return leftOptionOrder < rightOptionOrder
        end
        local leftName = tostring(left.sortName or left.fullName or left.easyName or left.timerKey):lower()
        local rightName = tostring(right.sortName or right.fullName or right.easyName or right.timerKey):lower()
        return leftName < rightName
    end)
    return rows
end

function Reminders:GetBossFilterItems(filterValue)
    local items = {
        { value = "ALL", label = "All bosses" },
    }
    local seen = {}
    for _, definition in ipairs(self:GetDefinitionsForRaid(filterValue)) do
        local bossKey = tostring(definition.moduleName or definition.bossName or definition.definitionId)
        if not seen[bossKey] then
            seen[bossKey] = { bossOrder = tonumber(definition.bossOrder or 9999) }
            items[#items + 1] = {
                value = bossKey,
                label = tostring(definition.bossName or bossKey),
                bossOrder = tonumber(definition.bossOrder or 9999),
            }
        end
    end
    table.sort(items, function(left, right)
        if left.value == "ALL" then return true end
        if right.value == "ALL" then return false end
        local leftBossOrder = tonumber(left.bossOrder or 9999)
        local rightBossOrder = tonumber(right.bossOrder or 9999)
        if leftBossOrder ~= rightBossOrder then
            return leftBossOrder < rightBossOrder
        end
        return tostring(left.label):lower() < tostring(right.label):lower()
    end)
    return items
end

function Reminders:GetCurrentBossFilterDefault(filterValue)
    local items = self:GetBossFilterItems(filterValue)
    if items[2] then
        return items[2].value
    end
    return "ALL"
end

function Reminders:GetAuraCountForDefinition(definitionId)
    local count = 0
    local db = GetM33kAurasDB()
    if not db then
        return 0
    end
    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template and data.ap_definition_id == definitionId then
            count = count + 1
        end
    end
    return count
end

function Reminders:GetDefinitionDisplayRowsForRaid(filterValue, bossFilterValue, searchText)
    local groupedRows = {}
    local normalizedSearch = NormalizeLabelKey(searchText)
    for _, definition in ipairs(self:GetDefinitionsForRaid(filterValue)) do
        local bossKey = tostring(definition.moduleName or definition.bossName or definition.definitionId)
        local matchesBoss = bossFilterValue == nil or bossFilterValue == "ALL" or bossFilterValue == bossKey
        local searchableText = table.concat({
            tostring(definition.bossName or ""),
            tostring(definition.fullName or ""),
            tostring(definition.easyName or ""),
            tostring(definition.spellId or ""),
            tostring(definition.optionKey or ""),
        }, " ")
        local matchesSearch = normalizedSearch == "" or NormalizeLabelKey(searchableText):find(normalizedSearch, 1, true) ~= nil
        if matchesBoss and matchesSearch then
            local bossName = definition.bossName or "Unknown"
            local reminderCount = self:GetAuraCountForDefinition(definition.definitionId)
            groupedRows[#groupedRows + 1] = {
                kind = "timer",
                timerKey = definition.definitionId,
                bossName = bossName,
                label = definition.fullName or definition.definitionId,
                spellName = definition.easyName,
                spellText = definition.spellId and tostring(definition.spellId) or tostring(definition.optionKey or "Text"),
                reminderCount = tostring(reminderCount),
                lastSeenText = "M33kAuras",
            }
        end
    end
    return groupedRows
end

function Reminders:GetDefinitionDetailLines(definitionId)
    local definition = self.cachedDefinitions and self.cachedDefinitions[definitionId]
    if not definition then
        return {
            "Select a BigWigs timer definition to inspect it.",
            "The list is built from BigWigs boss module metadata, not observed bars.",
        }
    end
    local lines = {
        "Boss: " .. tostring(definition.bossName or "Unknown"),
        "Ability: " .. tostring(definition.fullName or "Unknown"),
        string.format(
            "Easy / Key: %s / %s",
            tostring(definition.easyName ~= "" and definition.easyName or "N/A"),
            tostring(definition.spellId or definition.optionKey or "N/A")
        ),
        string.format(
            "Module / Raid: %s / %s",
            tostring(definition.moduleName or "Unknown"),
            tostring(definition.instanceName or "Unknown")
        ),
        string.format(
            "Reminders in M33kAuras: %d",
            self:GetAuraCountForDefinition(definitionId)
        ),
    }
    local phaseOptions = self:GetDefinitionPhaseOptions(definitionId)
    if #phaseOptions > 0 then
        local labels = {}
        for _, option in ipairs(phaseOptions) do
            labels[#labels + 1] = option.label
        end
        lines[#lines + 1] = "Phases: " .. table.concat(labels, ", ")
    end
    return lines
end

function Reminders:GetDefinitionById(definitionId)
    if not definitionId or definitionId == "" then
        return nil
    end
    return self.cachedDefinitions and self.cachedDefinitions[definitionId]
end

function Reminders:GetDefinitionPhaseOptions(definitionId)
    local definition = self.cachedDefinitions and self.cachedDefinitions[definitionId]
    local seen = {}
    local options = {}
    if not definition then
        return options
    end
    local function addPhaseToken(token)
        if type(token) ~= "string" or token == "" or seen[token] then
            return
        end
        seen[token] = true
        options[#options + 1] = {
            value = token,
            label = BuildPhaseLabelFromToken(token) or token,
            sortOrder = GetPhaseTokenSortValue(token),
        }
    end
    for _, stageValue in ipairs(definition.phaseStageValues or {}) do
        addPhaseToken(BuildPhaseTokenFromStage(stageValue))
    end
    for _, stageValue in ipairs(definition.observedStageValues or {}) do
        addPhaseToken(BuildPhaseTokenFromStage(stageValue))
    end
    if definition.hasIntermissionHeader == true then
        local hasExactIntermission = false
        for token in pairs(seen) do
            if token:match("^intermission:%d+$") then
                hasExactIntermission = true
                break
            end
        end
        if not hasExactIntermission then
            addPhaseToken("intermission:any")
        end
    end
    table.sort(options, function(left, right)
        if left.sortOrder ~= right.sortOrder then
            return left.sortOrder < right.sortOrder
        end
        return tostring(left.label) < tostring(right.label)
    end)
    return options
end

function Reminders:GetRuleEditorState(definitionId, ruleId)
    local definition = self:GetDefinitionById(definitionId)
    if not definition then
        return {
            hasTimer = false,
            hasSelectedRule = false,
            name = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            phaseOptions = {},
            phaseFilters = {},
            statusText = "Select a BigWigs timer definition to create a reminder.",
        }
    end
    local auras = self:GetAurasForDefinition(definitionId)
    if not ruleId then
        return {
            hasTimer = true,
            hasSelectedRule = false,
            name = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            phaseOptions = self:GetDefinitionPhaseOptions(definitionId),
            phaseFilters = {},
            statusText = #auras > 0 and "Configure a new reminder for this timer." or "No reminders saved for this timer yet. Click Add Reminder to create one.",
        }
    end
    local aura = self:GetAuraByRuleId(ruleId)
    if not aura then
        return {
            hasTimer = true,
            hasSelectedRule = false,
            name = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            phaseOptions = self:GetDefinitionPhaseOptions(definitionId),
            phaseFilters = {},
            statusText = "Selected reminder not found in M33kAuras.",
        }
    end
    local trigger = aura.triggers and aura.triggers[1] and aura.triggers[1].trigger or {}
    local phaseFilters = {}
    if aura.ap_phase_filters then
        for _, t in ipairs(aura.ap_phase_filters) do
            phaseFilters[#phaseFilters + 1] = t
        end
    end
    return {
        hasTimer = true,
        hasSelectedRule = true,
        name = aura.name or "",
        secondsBeforeEnd = tostring(trigger.use_remaining and trigger.remaining or 0),
        occurrenceNumber = tostring(trigger.use_count and tonumber(trigger.count) or 0),
        phaseOptions = self:GetDefinitionPhaseOptions(definitionId),
        phaseFilters = phaseFilters,
        statusText = string.format("Reminder saved in M33kAuras. UID: %s", tostring(aura.uid or "unknown")),
    }
end

function Reminders:GetAurasForDefinition(definitionId)
    local auras = {}
    local db = GetM33kAurasDB()
    if not db then
        return auras
    end
    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template and data.ap_definition_id == definitionId then
            auras[#auras + 1] = data
        end
    end
    return auras
end

function Reminders:GetAuraByRuleId(ruleId)
    local db = GetM33kAurasDB()
    if not db then
        return nil
    end
    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template and data.ap_rule_id == ruleId then
            return data
        end
    end
    return nil
end

function Reminders:GetRuleListRows(definitionId)
    local rows = {}
    local auras = self:GetAurasForDefinition(definitionId)
    for _, aura in ipairs(auras) do
        local trigger = aura.triggers and aura.triggers[1] and aura.triggers[1].trigger or {}
        local secondsBeforeEnd = trigger.use_remaining and tonumber(trigger.remaining) or 0
        local occurrenceNumber = trigger.use_count and tonumber(trigger.count) or 0
        local triggerText = secondsBeforeEnd > 0 and string.format("%ds", secondsBeforeEnd) or "Start"
        local occurrenceText = occurrenceNumber > 0 and string.format("Occ %d", occurrenceNumber) or "Every"
        rows[#rows + 1] = {
            ruleId = aura.ap_rule_id,
            name = aura.name or "Unnamed",
            summary = string.format("%s | %s", triggerText, occurrenceText),
        }
    end
    return rows
end

function Reminders:SaveRule(definitionId, ruleId, data)
    local definition = self:GetDefinitionById(definitionId)
    if not definition then
        return false, "Select a BigWigs timer definition first."
    end
    local AuraBuilder = AP.AuraBuilder
    if not AuraBuilder then
        return false, "AuraBuilder module not found."
    end
    if not AuraBuilder:IsAvailable() then
        return false, "M33kAuras is not available."
    end
    local template = AuraBuilder:FindTemplate()
    if not template then
        return false, "Reminder template not found. Create it first."
    end
    local secondsBeforeEnd = tonumber(data and data.secondsBeforeEnd)
    if secondsBeforeEnd == nil or secondsBeforeEnd < 0 then
        return false, "Seconds remaining must be 0 or higher."
    end
    secondsBeforeEnd = math.floor(secondsBeforeEnd + 0.0001)
    local occurrenceNumber = tonumber(data and data.occurrenceNumber)
    if occurrenceNumber == nil then
        occurrenceNumber = 0
    end
    if occurrenceNumber < 0 then
        return false, "Occurrence must be 0 or higher."
    end
    occurrenceNumber = math.floor(occurrenceNumber + 0.0001)
    local phaseFilters = {}
    local phaseFilterSeen = {}
    if type(data and data.phaseFilters) == "table" then
        for _, phaseToken in ipairs(data.phaseFilters) do
            if type(phaseToken) == "string" and phaseToken ~= "" and not phaseFilterSeen[phaseToken] then
                phaseFilterSeen[phaseToken] = true
                phaseFilters[#phaseFilters + 1] = phaseToken
            end
        end
    end
    table.sort(phaseFilters, function(left, right)
        local leftSort = GetPhaseTokenSortValue(left)
        local rightSort = GetPhaseTokenSortValue(right)
        if leftSort ~= rightSort then
            return leftSort < rightSort
        end
        return left < right
    end)
    if not ruleId then
        ruleId = string.format("rule_%s_%d", definitionId, time())
    end
    local ruleData = {
        name = NormalizeText(data and data.name) or "",
        text = definition.fullName or "",
        secondsBeforeEnd = secondsBeforeEnd,
        occurrenceNumber = occurrenceNumber,
        phaseFilters = phaseFilters,
        ruleId = ruleId,
        definitionId = definitionId,
        timerKey = definitionId,
        encounterId = definition.encounterId,
        moduleName = definition.moduleName,
        bossName = definition.bossName,
        label = definition.fullName,
        fullName = definition.fullName,
        easyName = definition.easyName,
        spellId = definition.spellId,
        optionKey = definition.optionKey,
    }
    if ruleId then
        local existing = self:GetAuraByRuleId(ruleId)
        if existing then
            ruleData.m33k_uid = existing.uid
        end
    end
    local ok, err = AuraBuilder:ImportOrUpdate(ruleData, definition)
    if not ok then
        return false, err or "Failed to create reminder in M33kAuras."
    end
    AP:NotifyOptionsChanged()
    return true, ruleId and "Reminder updated." or "Reminder saved.", ruleId
end

function Reminders:DeleteRule(definitionId, ruleId)
    if not definitionId or definitionId == "" then
        return false, "Select a BigWigs timer definition first."
    end
    if not ruleId or ruleId == "" then
        return false, "Select a saved reminder first."
    end
    local AuraBuilder = AP.AuraBuilder
    if AuraBuilder then
        AuraBuilder:RemoveByRuleId(ruleId)
    end
    AP:NotifyOptionsChanged()
    return true, "Reminder deleted."
end

function Reminders:GetRuleCount()
    local count = 0
    local db = GetM33kAurasDB()
    if not db then
        return 0
    end
    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template then
            count = count + 1
        end
    end
    return count
end

function Reminders:PrimeReminderData(filterValue)
    self.debugLastRequestedRaidFilter = filterValue
    if filterValue then
        self:EnsureRaidMetadataLoaded(filterValue)
    end
end

function Reminders:GetDefinitionCount()
    local count = 0
    for _ in pairs(self.cachedDefinitions or {}) do
        count = count + 1
    end
    return count
end

function Reminders:GetM33kAurasStatus()
    local AuraBuilder = AP.AuraBuilder
    if not AuraBuilder then
        return "missing", "AuraBuilder module not found."
    end
    if not AuraBuilder:IsAvailable() then
        return "missing", "M33kAuras is not installed."
    end
    local template = AuraBuilder:FindTemplate()
    if not template then
        return "missing_template", "M33kAuras is installed but the reminder template is missing."
    end
    return "ok", nil
end

function Reminders:GetStatusText()
    local bigWigsLoaded = self:IsBigWigsAvailable() and "available" or "not detected"
    local definitionCount = self:GetDefinitionCount()
    local ruleCount = self:GetRuleCount()
    local AuraBuilder = AP.AuraBuilder
    local m33kStatus = AuraBuilder and AuraBuilder:IsAvailable() and "available" or "not installed"
    return string.format(
        "BigWigs is %s. M33kAuras is %s. Indexed timer definitions: %d. Saved reminders: %d.",
        bigWigsLoaded,
        m33kStatus,
        definitionCount,
        ruleCount
    )
end

function Reminders:GetPlaceholderLines()
    local lines = {
        "Reminders are stored in M33kAuras.",
        "- Raid-only, BigWigs-only reminder support",
        "- Timer picker is built from BigWigs boss module metadata",
        "- Multiple reminders can be saved per timer",
        "- Reminders are M33kAuras auras with BigWigs Timer triggers",
        "- Customize appearance via the APRaidUtils Reminder Template in M33kAuras",
    }
    if self.debugLastRaidLoad then
        lines[#lines + 1] = string.format(
            "- Debug: raid=%s core=%s menu=%s modules=%d matched=%d built=%d reason=%s",
            tostring(self.debugLastRaidLoad.raidId or "nil"),
            self.debugLastRaidLoad.coreLoaded and "yes" or "no",
            self.debugLastRaidLoad.usedMenuModules and "yes" or "no",
            tonumber(self.debugLastRaidLoad.modulesSeen or 0),
            tonumber(self.debugLastRaidLoad.matchedModules or 0),
            tonumber(self.debugLastRaidLoad.definitionsBuilt or 0),
            tostring(self.debugLastRaidLoad.reason or "ok")
        )
    end
    return lines
end

function Reminders:SetLastViewedTimerKey(timerKey)
    self.lastViewedTimerKey = timerKey
end

function Reminders:GetLastViewedTimerKey()
    return self.lastViewedTimerKey
end
