local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Reminders = AP:NewModule("Reminders", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local bitBand = bit and bit.band

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

local function CreateRuleBucket()
    return {
        nextRuleId = 1,
        order = {},
        items = {},
    }
end

local function IsRuleBucket(value)
    return type(value) == "table" and type(value.items) == "table" and type(value.order) == "table"
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

local function GetPreciseNow()
    return GetTime and GetTime() or 0
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

function Reminders:OnInitialize()
    self.activeReminders = {}
    self.pendingReminders = {}
    self.runtimeEventMap = {}
    self.pullCounts = {}
    self.loadedRaidIds = {}
    self.currentStageByModule = {}
    self.bigWigsCallbacksRegistered = false
end

function Reminders:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "HandleAddonLoaded")
    self:RegisterEvent("ENCOUNTER_START", "HandleEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "HandleEncounterEnd")
    self:EnsureBigWigsCallbacksRegistered()
end

function Reminders:OnDisable()
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
    self:UnregisterBigWigsCallbacks()
end

function Reminders:GetStorage()
    if not AP.db or not AP.db.global then
        return nil
    end

    local globalStorage = AP.db.global.reminders
    local profileStorage = AP.db.profile and AP.db.profile.reminders

    globalStorage.rules = globalStorage.rules or {}
    globalStorage.definitions = globalStorage.definitions or {}
    globalStorage.observedTimers = globalStorage.observedTimers or {}

    if profileStorage then
        profileStorage.rules = profileStorage.rules or {}
        profileStorage.definitions = profileStorage.definitions or {}
        profileStorage.observedTimers = profileStorage.observedTimers or {}

        if next(profileStorage.definitions) ~= nil then
            for definitionId, definition in pairs(profileStorage.definitions) do
                if not globalStorage.definitions[definitionId] then
                    globalStorage.definitions[definitionId] = CopyTableDeep(definition)
                end
            end
        end

        if next(profileStorage.observedTimers) ~= nil then
            for timerKey, timerData in pairs(profileStorage.observedTimers) do
                if not globalStorage.observedTimers[timerKey] then
                    globalStorage.observedTimers[timerKey] = CopyTableDeep(timerData)
                end
            end
        end

        if next(profileStorage.rules) ~= nil then
            for ruleKey, ruleData in pairs(profileStorage.rules) do
                if not globalStorage.rules[ruleKey] then
                    globalStorage.rules[ruleKey] = CopyTableDeep(ruleData)
                end
            end
        end

        if globalStorage.enabled == nil and profileStorage.enabled ~= nil then
            globalStorage.enabled = profileStorage.enabled
        end
    end

    return globalStorage
end

function Reminders:RefreshUI()
    if AP.RefreshRemindersTab then
        AP:RefreshRemindersTab()
    end
end

function Reminders:HandleAddonLoaded(_, addonName)
    if addonName == "BigWigs" then
        self:EnsureBigWigsCallbacksRegistered()
        self:RefreshUI()
    end
end

function Reminders:HandleEncounterStart(_, encounterId)
    self.pullCounts = {}
    self.currentEncounterId = encounterId
end

function Reminders:HandleEncounterEnd(_, encounterId)
    if encounterId == self.currentEncounterId or self.currentEncounterId == nil then
        self.pullCounts = {}
        self.currentEncounterId = nil
    end
    self:ClearRuntimeState()
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

function Reminders:EnsureBigWigsCallbacksRegistered()
    if self.bigWigsCallbacksRegistered or not self:IsBigWigsAvailable() then
        return false
    end

    BigWigsLoader.RegisterMessage(self, "BigWigs_StartBar", "HandleBigWigsStartBar")
    BigWigsLoader.RegisterMessage(self, "BigWigs_StopBar", "HandleBigWigsStopBar")
    BigWigsLoader.RegisterMessage(self, "BigWigs_StopBars", "HandleBigWigsStopBars")
    BigWigsLoader.RegisterMessage(self, "BigWigs_PauseBar", "HandleBigWigsPauseBar")
    BigWigsLoader.RegisterMessage(self, "BigWigs_ResumeBar", "HandleBigWigsResumeBar")
    BigWigsLoader.RegisterMessage(self, "BigWigs_SetStage", "HandleBigWigsSetStage")
    BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossEngage", "HandleBigWigsBossEngage")
    BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossEngageMidEncounter", "HandleBigWigsBossEngage")
    BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossDisable", "HandleBigWigsBossDisable")
    self.bigWigsCallbacksRegistered = true
    return true
end

function Reminders:UnregisterBigWigsCallbacks()
    if not self.bigWigsCallbacksRegistered or not self:IsBigWigsAvailable() then
        return
    end

    BigWigsLoader.UnregisterMessage(self, "BigWigs_StartBar")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_StopBar")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_StopBars")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_PauseBar")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_ResumeBar")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_SetStage")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_OnBossEngage")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_OnBossEngageMidEncounter")
    BigWigsLoader.UnregisterMessage(self, "BigWigs_OnBossDisable")
    self.bigWigsCallbacksRegistered = false
end

function Reminders:GetDisplayModule()
    return AP:GetModule("ReminderDisplay", true)
end

function Reminders:IsPreviewMode()
    local display = self:GetDisplayModule()
    return display and display.IsPreviewMode and display:IsPreviewMode() or false
end

function Reminders:SetPreviewMode(enabled)
    local display = self:GetDisplayModule()
    if display and display.SetPreviewMode then
        display:SetPreviewMode(enabled)
    end
    AP:NotifyOptionsChanged()
end

function Reminders:BuildRuntimeInstanceKey(definitionId, ruleId)
    return string.format("%s|%s|%.3f", tostring(definitionId), tostring(ruleId or "rule"), GetPreciseNow())
end

function Reminders:BuildPendingInstanceKey(definitionId, ruleId)
    return string.format("pending|%s|%s|%.3f", tostring(definitionId), tostring(ruleId or "rule"), GetPreciseNow())
end

function Reminders:BuildRenderedText(rule, activeReminder)
    local countdownText = activeReminder.countdownText or ""
    local text = tostring(rule.text or "")
    text = text:gsub("{countdown}", countdownText)
    text = text:gsub("{spell}", tostring(activeReminder.label or rule.fullName or rule.label or ""))
    text = text:gsub("{boss}", tostring(activeReminder.bossName or rule.bossName or ""))
    return text
end

function Reminders:RefreshActiveReminderDisplay()
    local display = self:GetDisplayModule()
    if not display then
        return
    end

    local now = GetPreciseNow()
    local activeList = {}

    for pendingKey, reminder in pairs(self.pendingReminders) do
        if reminder.pausedAt then
            reminder.remaining = math.max(0, reminder.pauseRemaining or 0)
        else
            reminder.remaining = math.max(0, (reminder.endTime or now) - now)
        end

        if reminder.remaining <= (reminder.secondsBeforeEnd or 0) then
            self.pendingReminders[pendingKey] = nil
            self:StartActiveReminder(reminder.definitionId, reminder.ruleId, reminder.module, reminder.label, reminder.duration, reminder.endTime, reminder.occurrence, reminder.eventId)
        end
    end

    for runtimeKey, reminder in pairs(self.activeReminders) do
        if reminder.pausedAt then
            reminder.remaining = math.max(0, reminder.pauseRemaining or 0)
        else
            reminder.remaining = math.max(0, (reminder.endTime or now) - now)
        end

        reminder.countdownText = string.format("%d", math.max(0, math.ceil(reminder.remaining)))
        reminder.renderedText = self:BuildRenderedText(reminder.rule, reminder)

        if reminder.remaining <= 0 and not reminder.pausedAt then
            self.activeReminders[runtimeKey] = nil
        else
            activeList[#activeList + 1] = reminder
        end
    end

    table.sort(activeList, function(left, right)
        return (left.startedAt or 0) < (right.startedAt or 0)
    end)

    display:UpdateLayout(activeList)

    if next(self.activeReminders) == nil and next(self.pendingReminders) == nil then
        if self.displayUpdateTimer then
            self:CancelTimer(self.displayUpdateTimer)
            self.displayUpdateTimer = nil
        end
    elseif not self.displayUpdateTimer then
        self.displayUpdateTimer = self:ScheduleRepeatingTimer("RefreshActiveReminderDisplay", 0.1)
    end
end

function Reminders:StartReminderDisplayTimer()
    if self.displayUpdateTimer then
        return
    end

    self.displayUpdateTimer = self:ScheduleRepeatingTimer("RefreshActiveReminderDisplay", 0.1)
end

function Reminders:GetCurrentStageForModule(module)
    local moduleName = type(module) == "table" and module.moduleName or module
    if type(moduleName) ~= "string" or moduleName == "" then
        return nil
    end

    local currentStage = NormalizeStageValue(self.currentStageByModule[moduleName])
    if currentStage then
        return currentStage
    end

    if type(module) == "table" and module.GetStage then
        currentStage = NormalizeStageValue(module:GetStage())
        if currentStage then
            self.currentStageByModule[moduleName] = currentStage
            return currentStage
        end
    end

    return nil
end

function Reminders:SetCurrentStageForModule(module, stage)
    local moduleName = type(module) == "table" and module.moduleName or module
    local normalizedStage = NormalizeStageValue(stage)
    if type(moduleName) ~= "string" or moduleName == "" then
        return nil
    end

    if normalizedStage then
        self.currentStageByModule[moduleName] = normalizedStage
    else
        self.currentStageByModule[moduleName] = nil
    end

    return normalizedStage
end

function Reminders:GetRulePhaseFilterSet(rule)
    local phaseFilterSet = {}
    local hasFilters = false

    if type(rule) ~= "table" or type(rule.phaseFilters) ~= "table" then
        return phaseFilterSet, hasFilters
    end

    for _, phaseToken in ipairs(rule.phaseFilters) do
        if type(phaseToken) == "string" and phaseToken ~= "" then
            phaseFilterSet[phaseToken] = true
            hasFilters = true
        end
    end

    return phaseFilterSet, hasFilters
end

function Reminders:IsRuleAllowedInStage(rule, stage)
    local phaseFilterSet, hasFilters = self:GetRulePhaseFilterSet(rule)
    if not hasFilters then
        return true
    end

    local normalizedStage = NormalizeStageValue(stage)
    if not normalizedStage then
        return false
    end

    local phaseToken = BuildPhaseTokenFromStage(normalizedStage)
    if phaseToken and phaseFilterSet[phaseToken] then
        return true
    end

    if IsFractionalStage(normalizedStage) and phaseFilterSet["intermission:any"] == true then
        return true
    end

    return false
end

function Reminders:RecordDefinitionObservedStage(definitionId, stage)
    local definition = self:GetDefinitionById(definitionId)
    local normalizedStage = NormalizeStageValue(stage)
    if not definition or not normalizedStage then
        return
    end

    definition.observedStageValues = definition.observedStageValues or {}
    AddUniqueValue(definition.observedStageValues, normalizedStage)
end

function Reminders:GetDefinitionPhaseOptions(definitionId)
    local definition = self:GetDefinitionById(definitionId)
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

function Reminders:GetRulePhaseSummary(rule, definitionId)
    local phaseFilterSet, hasFilters = self:GetRulePhaseFilterSet(rule)
    if not hasFilters then
        return "All phases"
    end

    local labels = {}
    local options = self:GetDefinitionPhaseOptions(definitionId or (rule and rule.definitionId))
    for _, option in ipairs(options) do
        if phaseFilterSet[option.value] then
            labels[#labels + 1] = {
                label = option.label,
                sortOrder = option.sortOrder,
            }
            phaseFilterSet[option.value] = nil
        end
    end

    for phaseToken in pairs(phaseFilterSet) do
        labels[#labels + 1] = {
            label = BuildPhaseLabelFromToken(phaseToken) or phaseToken,
            sortOrder = GetPhaseTokenSortValue(phaseToken),
        }
    end

    table.sort(labels, function(left, right)
        if left.sortOrder ~= right.sortOrder then
            return left.sortOrder < right.sortOrder
        end

        return left.label < right.label
    end)

    local parts = {}
    for _, entry in ipairs(labels) do
        parts[#parts + 1] = entry.label
    end

    return table.concat(parts, ", ")
end

function Reminders:PruneActiveRemindersForStage(moduleName, stage)
    local removedAny = false

    for runtimeKey, reminder in pairs(self.activeReminders) do
        if reminder.moduleName == moduleName and not self:IsRuleAllowedInStage(reminder.rule, stage) then
            self.activeReminders[runtimeKey] = nil
            removedAny = true
        end
    end

    if removedAny then
        self:RefreshActiveReminderDisplay()
    end
end

function Reminders:ClearRuntimeState(moduleName)
    if not moduleName then
        self.activeReminders = {}
        self.pendingReminders = {}
        self.runtimeEventMap = {}
        self.currentStageByModule = {}
        self:RefreshActiveReminderDisplay()
        return
    end

    self.currentStageByModule[moduleName] = nil

    for runtimeKey, reminder in pairs(self.activeReminders) do
        if reminder.moduleName == moduleName then
            self.activeReminders[runtimeKey] = nil
        end
    end

    for pendingKey, reminder in pairs(self.pendingReminders) do
        if reminder.moduleName == moduleName then
            self.pendingReminders[pendingKey] = nil
        end
    end

    for eventKey, runtimeKeys in pairs(self.runtimeEventMap) do
        if type(runtimeKeys) == "table" then
            for index = #runtimeKeys, 1, -1 do
                local activeReminder = self.activeReminders[runtimeKeys[index]]
                if not activeReminder or activeReminder.moduleName == moduleName then
                    table.remove(runtimeKeys, index)
                end
            end

            if #runtimeKeys == 0 then
                self.runtimeEventMap[eventKey] = nil
            end
        else
            local activeReminder = self.activeReminders[runtimeKeys]
            if not activeReminder or activeReminder.moduleName == moduleName then
                self.runtimeEventMap[eventKey] = nil
            end
        end
    end

    self:RefreshActiveReminderDisplay()
end

function Reminders:IsEnabledForProfile()
    return self:GetStorage().enabled == true
end

function Reminders:SetEnabledForProfile(enabled)
    self:GetStorage().enabled = enabled == true
    AP:NotifyOptionsChanged()
end

function Reminders:IsInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

function Reminders:GetAllKnownRaidItems()
    if not self:IsBigWigsAvailable() or type(BigWigsLoader.zoneTbl) ~= "table" then
        return {
            {
                value = "ALL",
                label = "All loaded raids",
            },
        }
    end

    local items = {
        {
            value = "ALL",
            label = "All loaded raids",
        },
    }

    for zoneId, addonName in pairs(BigWigsLoader.zoneTbl) do
        if IsPositiveNumber(zoneId) and type(addonName) == "string" and addonName:find("BigWigs", 1, true) then
            items[#items + 1] = {
                value = tostring(zoneId),
                label = self:GetRaidDisplayName(zoneId, addonName),
            }
        end
    end

    table.sort(items, function(left, right)
        if left.value == "ALL" then
            return true
        end
        if right.value == "ALL" then
            return false
        end
        return tostring(left.label):lower() < tostring(right.label):lower()
    end)

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
        {
            value = "ALL",
            label = "Current expansion raids",
        },
    }

    for _, item in ipairs(self:GetAllKnownRaidItems()) do
        local zoneId = tonumber(item.value)
        if zoneId and self:IsCurrentExpansionRaidId(zoneId) then
            filtered[#filtered + 1] = item
        end
    end

    return filtered
end

function Reminders:GetCurrentRaidFilterDefault(onlyCurrentExpansion)
    local items = self:GetRaidFilterItems(onlyCurrentExpansion)
    if items[2] then
        return items[2].value
    end

    return "ALL"
end

function Reminders:EnsureRaidMetadataLoaded(filterValue)
    if filterValue == nil or filterValue == "" or filterValue == "ALL" then
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

function Reminders:GetDefinitionById(definitionId)
    if not definitionId or definitionId == "" then
        return nil
    end

    return self:GetStorage().definitions[definitionId]
end

function Reminders:UpdateLegacyObservedTimer(module, definitionId, label, duration, icon, eventId)
    if type(module) ~= "table" or not label or label == "" then
        return
    end

    local observedTimer = self:GetStorage().observedTimers[definitionId] or {}
    local currentTime = time()
    local raidId = GetPrimaryRaidId(module)
    local encounterId = module.GetEncounterID and module:GetEncounterID() or nil
    local journalId = module.GetJournalID and module:GetJournalID() or nil
    local instanceId, instanceName = GetEncounterInstanceName(encounterId)

    observedTimer.timerKey = definitionId
    observedTimer.bossName = module.displayName or module.moduleName or "Unknown"
    observedTimer.moduleName = module.moduleName
    observedTimer.raidId = raidId
    observedTimer.encounterId = encounterId
    observedTimer.journalId = journalId
    observedTimer.instanceId = instanceId or journalId
    observedTimer.instanceName = instanceName or observedTimer.instanceName or self:GetRaidDisplayName(raidId) or GetRealZoneText() or "Unknown Raid"
    observedTimer.spellId = self:GetDefinitionById(definitionId) and self:GetDefinitionById(definitionId).spellId or nil
    observedTimer.label = NormalizeText(label)
    observedTimer.icon = icon
    observedTimer.lastDuration = duration
    observedTimer.lastEventId = eventId
    observedTimer.lastSeenAt = currentTime
    observedTimer.firstSeenAt = observedTimer.firstSeenAt or currentTime
    observedTimer.confirmed = true

    self:GetStorage().observedTimers[definitionId] = observedTimer
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
    local definition = self:GetStorage().definitions[definitionId] or {}
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
    definition.confirmed = definition.confirmed == true
    definition.sortName = NormalizeText(definition.fullName ~= "" and definition.fullName or definition.easyName)
    definition.optionOrder = optionOrder or definition.optionOrder or 9999
    definition.bossOrder = bossOrder or definition.bossOrder or 9999

    self:GetStorage().definitions[definitionId] = definition
    return definition
end

function Reminders:RebuildDefinitionsForRaid(raidId)
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
    if filterValue and filterValue ~= "ALL" then
        self:EnsureRaidMetadataLoaded(filterValue)
    end

    local rows = {}
    for definitionId, definition in pairs(self:GetStorage().definitions or {}) do
        if filterValue == nil or filterValue == "ALL" or tostring(definition.raidId or definition.instanceId or "") == tostring(filterValue) then
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
        {
            value = "ALL",
            label = "All bosses",
        },
    }
    local seen = {}

    for _, definition in ipairs(self:GetDefinitionsForRaid(filterValue)) do
        local bossKey = tostring(definition.moduleName or definition.bossName or definition.definitionId)
        if not seen[bossKey] then
            seen[bossKey] = {
                bossOrder = tonumber(definition.bossOrder or 9999),
            }
            items[#items + 1] = {
                value = bossKey,
                label = tostring(definition.bossName or bossKey),
                bossOrder = tonumber(definition.bossOrder or 9999),
            }
        end
    end

    table.sort(items, function(left, right)
        if left.value == "ALL" then
            return true
        end
        if right.value == "ALL" then
            return false
        end
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
            local reminderCount = self:GetRuleCountForDefinition(definition.definitionId)

            groupedRows[#groupedRows + 1] = {
                kind = "timer",
                timerKey = definition.definitionId,
                bossName = bossName,
                label = definition.fullName or definition.definitionId,
                spellName = definition.easyName,
                spellText = definition.spellId and tostring(definition.spellId) or tostring(definition.optionKey or "Text"),
                reminderCount = tostring(reminderCount),
                lastSeenText = definition.confirmed and "Seen" or "Metadata",
            }
        end
    end

    return groupedRows
end

function Reminders:GetDefinitionDetailLines(definitionId)
    local definition = self:GetDefinitionById(definitionId)
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
            "State / Saved: %s / %d",
            definition.confirmed and "Seen" or "Metadata",
            self:GetRuleCountForDefinition(definitionId)
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

function Reminders:ResolveDefinitionId(module, key, label)
    local primaryId = self:GetDefinitionId(module, key, label)
    local legacyTextId = string.format(
        "enc:%s|mod:%s|text:%s",
        tostring(module and module.GetEncounterID and module:GetEncounterID() or 0),
        tostring(module and module.moduleName or "Unknown"),
        NormalizeLabelKey(label)
    )

    if self:GetStorage().rules[legacyTextId] and not self:GetStorage().rules[primaryId] then
        return legacyTextId
    end

    if self:GetDefinitionById(primaryId) then
        return primaryId
    end

    if type(key) == "string" then
        local fallbackId = self:GetDefinitionId(module, nil, key)
        if self:GetDefinitionById(fallbackId) then
            return fallbackId
        end
    end

    if self:GetStorage().rules[legacyTextId] then
        return legacyTextId
    end

    return primaryId
end

function Reminders:BuildRuleInstanceMatchKey(module, label, eventId)
    if eventId ~= nil then
        return string.format("event:%s", tostring(eventId))
    end

    return string.format(
        "mod:%s|label:%s",
        tostring(module and module.moduleName or "Unknown"),
        NormalizeLabelKey(label)
    )
end

function Reminders:GetRuleBucket(definitionId, createIfMissing)
    if not definitionId or definitionId == "" then
        return nil
    end

    local storage = self:GetStorage()
    local bucket = storage.rules[definitionId]
    if bucket and not IsRuleBucket(bucket) then
        bucket = nil
    end

    if not bucket and createIfMissing then
        bucket = CreateRuleBucket()
        storage.rules[definitionId] = bucket
    end

    return bucket
end

function Reminders:CreateRuleId(bucket)
    local nextRuleId = math.max(1, tonumber(bucket and bucket.nextRuleId) or 1)
    local ruleId = "r" .. tostring(nextRuleId)

    while bucket.items[ruleId] do
        nextRuleId = nextRuleId + 1
        ruleId = "r" .. tostring(nextRuleId)
    end

    bucket.nextRuleId = nextRuleId + 1
    return ruleId
end

function Reminders:GetOrderedRules(definitionId)
    local bucket = self:GetRuleBucket(definitionId)
    local rules = {}
    local seen = {}

    if not bucket then
        return rules
    end

    for _, ruleId in ipairs(bucket.order or {}) do
        local rule = bucket.items and bucket.items[ruleId]
        if type(rule) == "table" then
            rules[#rules + 1] = rule
            seen[ruleId] = true
        end
    end

    for ruleId, rule in pairs(bucket.items or {}) do
        if type(rule) == "table" and not seen[ruleId] then
            rules[#rules + 1] = rule
        end
    end

    return rules
end

function Reminders:GetRule(definitionId)
    local rules = self:GetOrderedRules(definitionId)
    return rules[1]
end

function Reminders:GetRuleById(definitionId, ruleId)
    if not definitionId or definitionId == "" or not ruleId or ruleId == "" then
        return nil
    end

    local bucket = self:GetRuleBucket(definitionId)
    return bucket and bucket.items and bucket.items[ruleId] or nil
end

function Reminders:GetRuleCountForDefinition(definitionId)
    local count = 0
    local bucket = self:GetRuleBucket(definitionId)

    for _ in pairs(bucket and bucket.items or {}) do
        count = count + 1
    end

    return count
end

function Reminders:GetRuleDisplayName(rule)
    local reminderName = NormalizeText(rule and rule.name or "")
    if reminderName ~= "" then
        return reminderName
    end

    local ruleText = NormalizeText(rule and rule.text or "")
    if ruleText ~= "" then
        return ruleText
    end

    return "New reminder"
end

function Reminders:BuildRuleListSummary(rule)
    local secondsBeforeEnd = math.max(0, tonumber(rule and rule.secondsBeforeEnd) or 0)
    local occurrenceNumber = math.max(0, math.floor((tonumber(rule and rule.occurrenceNumber) or 0) + 0.0001))
    local triggerText = secondsBeforeEnd > 0 and string.format("%ds", secondsBeforeEnd) or "Start"
    local occurrenceText = occurrenceNumber > 0 and string.format("Occ %d", occurrenceNumber) or "Every"
    local outputParts = {}

    if rule and rule.showBar == true then
        outputParts[#outputParts + 1] = "bar"
    end
    if rule and rule.showCountdown == true then
        outputParts[#outputParts + 1] = "countdown"
    end

    return string.format(
        "%s | %s | %s | %s",
        triggerText,
        occurrenceText,
        #outputParts > 0 and table.concat(outputParts, "+") or "text",
        self:GetRulePhaseSummary(rule, rule and rule.definitionId)
    )
end

function Reminders:GetRuleListRows(definitionId)
    local rows = {}

    for _, rule in ipairs(self:GetOrderedRules(definitionId)) do
        rows[#rows + 1] = {
            ruleId = rule.ruleId,
            name = self:GetRuleDisplayName(rule),
            summary = self:BuildRuleListSummary(rule),
        }
    end

    return rows
end

function Reminders:IsRuleOccurrenceMatch(rule, occurrenceNumber)
    local occurrenceValue = tonumber(rule and rule.occurrenceNumber)
    if not occurrenceValue or occurrenceValue <= 0 then
        return true
    end

    return occurrenceNumber == math.floor(occurrenceValue + 0.0001)
end

function Reminders:StartActiveReminder(definitionId, ruleId, module, label, duration, endTime, occurrenceNumber, eventId)
    local rule = self:GetRuleById(definitionId, ruleId)
    if not rule or rule.enabled ~= true then
        return
    end

    local currentStage = self:GetCurrentStageForModule(module)
    if not self:IsRuleAllowedInStage(rule, currentStage) then
        return
    end

    local definition = self:GetDefinitionById(definitionId)
    local now = GetPreciseNow()
    local runtimeKey = self:BuildRuntimeInstanceKey(definitionId, ruleId)
    local instanceMatchKey = self:BuildRuleInstanceMatchKey(module, label, eventId)
    local activeReminder = {
        runtimeKey = runtimeKey,
        definitionId = definitionId,
        ruleId = ruleId,
        timerKey = definitionId,
        moduleName = module and module.moduleName or rule.moduleName,
        bossName = definition and definition.bossName or rule.bossName,
        label = NormalizeText(label ~= "" and label or (definition and definition.fullName) or rule.label),
        icon = definition and definition.icon or nil,
        duration = duration or 0,
        remaining = math.max(0, (endTime or now) - now),
        startedAt = now,
        endTime = endTime or (now + (duration or 0)),
        showBar = rule.showBar == true,
        showCountdown = rule.showCountdown == true,
        occurrenceNumber = occurrenceNumber,
        eventId = eventId,
        stage = currentStage,
        instanceMatchKey = instanceMatchKey,
        rule = rule,
    }

    self.activeReminders[runtimeKey] = activeReminder

    if not self.runtimeEventMap[instanceMatchKey] then
        self.runtimeEventMap[instanceMatchKey] = {}
    end

    self.runtimeEventMap[instanceMatchKey][#self.runtimeEventMap[instanceMatchKey] + 1] = runtimeKey
end

function Reminders:ActivateRuleForTimer(definitionId, module, label, duration, eventId)
    if not self:IsEnabledForProfile() then
        return
    end

    local rules = self:GetOrderedRules(definitionId)
    if #rules == 0 then
        return
    end

    local hasEnabledRule = false
    for _, rule in ipairs(rules) do
        if rule.enabled == true then
            hasEnabledRule = true
            break
        end
    end

    if not hasEnabledRule then
        return
    end

    local occurrenceNumber = (self.pullCounts[definitionId] or 0) + 1
    self.pullCounts[definitionId] = occurrenceNumber

    local now = GetPreciseNow()
    local endTime = now + (duration or 0)
    local activatedAny = false
    local currentStage = self:GetCurrentStageForModule(module)

    for _, rule in ipairs(rules) do
        if rule.enabled == true and self:IsRuleOccurrenceMatch(rule, occurrenceNumber) then
            local secondsBeforeEnd = math.max(0, tonumber(rule.secondsBeforeEnd) or 0)

            if secondsBeforeEnd > 0 and duration and duration > secondsBeforeEnd then
                local pendingKey = self:BuildPendingInstanceKey(definitionId, rule.ruleId)
                self.pendingReminders[pendingKey] = {
                    pendingKey = pendingKey,
                    definitionId = definitionId,
                    ruleId = rule.ruleId,
                    timerKey = definitionId,
                    module = module,
                    moduleName = module and module.moduleName or rule.moduleName,
                    label = NormalizeText(label),
                    duration = duration or 0,
                    endTime = endTime,
                    eventId = eventId,
                    occurrence = occurrenceNumber,
                    stage = currentStage,
                    secondsBeforeEnd = secondsBeforeEnd,
                    instanceMatchKey = self:BuildRuleInstanceMatchKey(module, label, eventId),
                }
            else
                self:StartActiveReminder(definitionId, rule.ruleId, module, label, duration, endTime, occurrenceNumber, eventId)
            end

            activatedAny = true
        end
    end

    if activatedAny then
        self:StartReminderDisplayTimer()
        self:RefreshActiveReminderDisplay()
    end
end

function Reminders:GetMatchingReminderKeys(collection, module, text, eventId)
    local keys = {}
    local instanceMatchKey = self:BuildRuleInstanceMatchKey(module, text, eventId)
    local fallbackLabelKey = self:BuildRuleInstanceMatchKey(module, text)

    for entryKey, reminder in pairs(collection) do
        if reminder.instanceMatchKey == instanceMatchKey or reminder.instanceMatchKey == fallbackLabelKey then
            keys[#keys + 1] = entryKey
        end
    end

    return keys
end

function Reminders:HandleBigWigsStartBar(_, module, key, text, barTime, icon, isApprox, maxTime, eventId)
    if type(module) ~= "table" or not text or text == "" then
        return
    end

    local duration = maxTime or barTime or 0
    local definitionId = self:ResolveDefinitionId(module, key, text)
    local definition = self:GetDefinitionById(definitionId)

    if not definition and self:IsInRaidInstance() then
        local builtDefinition = self:BuildDefinitionFromOption(module, key)
        if builtDefinition then
            definitionId = builtDefinition.definitionId
            definition = builtDefinition
        end
    end

    if definition then
        definition.confirmed = true
        definition.lastSeenAt = _G.time()
        definition.lastDuration = duration
        definition.icon = icon or definition.icon
        self:RecordDefinitionObservedStage(definitionId, self:GetCurrentStageForModule(module))
    end

    self:UpdateLegacyObservedTimer(module, definitionId, text, duration, icon, eventId)
    self:ActivateRuleForTimer(definitionId, module, text, duration, eventId)
    self:RefreshUI()
end

function Reminders:HandleBigWigsBossEngage(_, module)
    if type(module) ~= "table" then
        return
    end

    self:SetCurrentStageForModule(module, module.GetStage and module:GetStage() or nil)
end

function Reminders:HandleBigWigsSetStage(_, module, stage)
    if type(module) ~= "table" then
        return
    end

    local currentStage = self:SetCurrentStageForModule(module, stage)
    if currentStage then
        self:PruneActiveRemindersForStage(module.moduleName, currentStage)
    end
end

function Reminders:HandleBigWigsStopBar(_, module, text, eventId)
    for _, runtimeKey in ipairs(self:GetMatchingReminderKeys(self.activeReminders, module, text, eventId)) do
        self.activeReminders[runtimeKey] = nil
    end
    for _, pendingKey in ipairs(self:GetMatchingReminderKeys(self.pendingReminders, module, text, eventId)) do
        self.pendingReminders[pendingKey] = nil
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:HandleBigWigsStopBars(_, module)
    if not module then
        return
    end

    self:ClearRuntimeState(module.moduleName)
end

function Reminders:HandleBigWigsBossDisable(_, module)
    self.pullCounts = {}
    self:SetCurrentStageForModule(module, nil)
    self:HandleBigWigsStopBars(nil, module)
end

function Reminders:HandleBigWigsPauseBar(_, module, text, eventId)
    local now = GetPreciseNow()
    for _, runtimeKey in ipairs(self:GetMatchingReminderKeys(self.activeReminders, module, text, eventId)) do
        local reminder = self.activeReminders[runtimeKey]
        if reminder and not reminder.pausedAt then
            reminder.pauseRemaining = math.max(0, (reminder.endTime or now) - now)
            reminder.pausedAt = now
        end
    end
    for _, pendingKey in ipairs(self:GetMatchingReminderKeys(self.pendingReminders, module, text, eventId)) do
        local reminder = self.pendingReminders[pendingKey]
        if reminder and not reminder.pausedAt then
            reminder.pauseRemaining = math.max(0, (reminder.endTime or now) - now)
            reminder.pausedAt = now
        end
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:HandleBigWigsResumeBar(_, module, text, eventId)
    local now = GetPreciseNow()
    for _, runtimeKey in ipairs(self:GetMatchingReminderKeys(self.activeReminders, module, text, eventId)) do
        local reminder = self.activeReminders[runtimeKey]
        if reminder and reminder.pausedAt then
            reminder.endTime = now + (reminder.pauseRemaining or 0)
            reminder.pausedAt = nil
            reminder.pauseRemaining = nil
        end
    end
    for _, pendingKey in ipairs(self:GetMatchingReminderKeys(self.pendingReminders, module, text, eventId)) do
        local reminder = self.pendingReminders[pendingKey]
        if reminder and reminder.pausedAt then
            reminder.endTime = now + (reminder.pauseRemaining or 0)
            reminder.pausedAt = nil
            reminder.pauseRemaining = nil
        end
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:GetRuleEditorState(definitionId, ruleId)
    local definition = self:GetDefinitionById(definitionId)
    local rules = self:GetOrderedRules(definitionId)
    local rule = ruleId and self:GetRuleById(definitionId, ruleId) or nil

    if not definition then
        return {
            hasTimer = false,
            hasSelectedRule = false,
            name = "",
            text = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            showBar = false,
            showCountdown = false,
            phaseOptions = {},
            phaseFilters = {},
            statusText = "Select a BigWigs timer definition to create a reminder.",
        }
    end

    if not rule then
        return {
            hasTimer = true,
            hasSelectedRule = false,
            name = "",
            text = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            showBar = false,
            showCountdown = false,
            phaseOptions = self:GetDefinitionPhaseOptions(definitionId),
            phaseFilters = {},
            statusText = #rules > 0 and "Configure a new reminder for this timer." or "No reminders saved for this timer yet. Click Add Reminder to create one.",
        }
    end

    return {
        hasTimer = true,
        hasSelectedRule = true,
        name = rule.name or "",
        text = rule.text or "",
        secondsBeforeEnd = tostring(rule.secondsBeforeEnd or 0),
        occurrenceNumber = tostring(rule.occurrenceNumber or 0),
        showBar = rule.showBar == true,
        showCountdown = rule.showCountdown == true,
        phaseOptions = self:GetDefinitionPhaseOptions(definitionId),
        phaseFilters = CopyTableDeep(rule.phaseFilters or {}),
        statusText = string.format("Reminder saved. Updated: %s", date("%Y-%m-%d %H:%M", rule.updatedAt or time())),
    }
end

function Reminders:SaveRule(definitionId, ruleId, data)
    if type(ruleId) == "table" and data == nil then
        data = ruleId
        ruleId = nil
    end

    local definition = self:GetDefinitionById(definitionId)
    if not definition then
        return false, "Select a BigWigs timer definition first."
    end

    local text = NormalizeText(data and data.text)
    if text == "" then
        return false, "Reminder text cannot be empty."
    end

    local name = NormalizeText(data and data.name)

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

    local bucket = self:GetRuleBucket(definitionId, true)
    local existingRule = ruleId and bucket.items[ruleId] or nil
    local enabled = true
    if ruleId and not existingRule then
        return false, "Select a saved reminder first."
    end

    if existingRule and existingRule.enabled == false then
        enabled = false
    end

    if not ruleId then
        ruleId = self:CreateRuleId(bucket)
        bucket.order[#bucket.order + 1] = ruleId
    end

    bucket.items[ruleId] = {
        ruleId = ruleId,
        definitionId = definitionId,
        timerKey = definitionId,
        name = name,
        text = text,
        secondsBeforeEnd = secondsBeforeEnd,
        occurrenceNumber = occurrenceNumber,
        showBar = data and data.showBar == true or false,
        showCountdown = data and data.showCountdown == true or false,
        phaseFilters = phaseFilters,
        enabled = enabled,
        createdAt = existingRule and existingRule.createdAt or time(),
        updatedAt = time(),
        encounterId = definition.encounterId,
        moduleName = definition.moduleName,
        bossName = definition.bossName,
        label = definition.fullName,
        fullName = definition.fullName,
        easyName = definition.easyName,
        spellId = definition.spellId,
        optionKey = definition.optionKey,
    }

    AP:NotifyOptionsChanged()
    return true, existingRule and "Reminder updated." or "Reminder saved.", ruleId
end

function Reminders:DeleteRule(definitionId, ruleId)
    if not definitionId or definitionId == "" then
        return false, "Select a BigWigs timer definition first."
    end

    local bucket = self:GetRuleBucket(definitionId)
    if not bucket or next(bucket.items or {}) == nil then
        return false, "No saved reminders exist for this timer."
    end

    if not ruleId or ruleId == "" then
        local defaultRule = self:GetRule(definitionId)
        ruleId = defaultRule and defaultRule.ruleId or nil
    end

    if not ruleId or not bucket.items[ruleId] then
        return false, "Select a saved reminder first."
    end

    bucket.items[ruleId] = nil
    for index = #bucket.order, 1, -1 do
        if bucket.order[index] == ruleId then
            table.remove(bucket.order, index)
        end
    end

    if next(bucket.items) == nil then
        self:GetStorage().rules[definitionId] = nil
    end

    AP:NotifyOptionsChanged()
    return true, "Reminder deleted."
end

function Reminders:GetRuleCount()
    local count = 0
    for _, bucket in pairs(self:GetStorage().rules or {}) do
        if IsRuleBucket(bucket) then
            for _ in pairs(bucket.items or {}) do
                count = count + 1
            end
        end
    end
    return count
end

function Reminders:PrimeReminderData(filterValue)
    self.debugLastRequestedRaidFilter = filterValue
    if filterValue and filterValue ~= "ALL" then
        self:EnsureRaidMetadataLoaded(filterValue)
    end
end

function Reminders:GetDefinitionCount()
    local count = 0
    for _ in pairs(self:GetStorage().definitions or {}) do
        count = count + 1
    end
    return count
end

function Reminders:GetStatusText()
    local bigWigsLoaded = self:IsBigWigsAvailable() and "available" or "not detected"
    local definitionCount = self:GetDefinitionCount()
    local ruleCount = self:GetRuleCount()
    local enabledText = self:IsEnabledForProfile() and "enabled" or "disabled"
    local listenerText = self.bigWigsCallbacksRegistered and "listening" or "idle"
    local debugText = ""

    if self.debugLastRaidLoad then
        debugText = string.format(
            " Selected=%s. Last load: raid=%s core=%s menu=%s modules=%d matched=%d built=%d reason=%s.",
            tostring(self.debugLastRequestedRaidFilter or "nil"),
            tostring(self.debugLastRaidLoad.raidId or "nil"),
            self.debugLastRaidLoad.coreLoaded and "yes" or "no",
            self.debugLastRaidLoad.usedMenuModules and "yes" or "no",
            tonumber(self.debugLastRaidLoad.modulesSeen or 0),
            tonumber(self.debugLastRaidLoad.matchedModules or 0),
            tonumber(self.debugLastRaidLoad.definitionsBuilt or 0),
            tostring(self.debugLastRaidLoad.reason or "ok")
        )
    elseif self.debugLastRequestedRaidFilter then
        debugText = string.format(" Selected=%s.", tostring(self.debugLastRequestedRaidFilter))
    end

    return string.format(
        "Reminders are %s. BigWigs is %s (%s). Indexed timer definitions: %d. Saved reminders: %d.%s",
        enabledText,
        bigWigsLoaded,
        listenerText,
        definitionCount,
        ruleCount,
        debugText
    )
end

function Reminders:GetPlaceholderLines()
    local lines = {
        "Metadata-first reminder setup is enabled.",
        "- Raid-only, BigWigs-only reminder support",
        "- Timer picker is built from BigWigs boss module metadata",
        "- Multiple reminders can be saved per timer",
        "- Live bars still drive reminder firing and confirmation",
        "- Occurrence counts reset on wipe/kill",
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
