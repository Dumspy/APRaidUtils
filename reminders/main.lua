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

function Reminders:OnInitialize()
    self.activeReminders = {}
    self.pendingReminders = {}
    self.runtimeEventMap = {}
    self.pullCounts = {}
    self.loadedRaidIds = {}
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
                    globalStorage.definitions[definitionId] = CopyTableShallow(definition)
                end
            end
        end

        if next(profileStorage.observedTimers) ~= nil then
            for timerKey, timerData in pairs(profileStorage.observedTimers) do
                if not globalStorage.observedTimers[timerKey] then
                    globalStorage.observedTimers[timerKey] = CopyTableShallow(timerData)
                end
            end
        end

        if next(profileStorage.rules) ~= nil then
            for ruleKey, ruleData in pairs(profileStorage.rules) do
                if not globalStorage.rules[ruleKey] then
                    globalStorage.rules[ruleKey] = CopyTableShallow(ruleData)
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

function Reminders:BuildRuntimeInstanceKey(definitionId)
    return string.format("%s|%.3f", tostring(definitionId), GetPreciseNow())
end

function Reminders:BuildPendingInstanceKey(definitionId)
    return string.format("pending|%s|%.3f", tostring(definitionId), GetPreciseNow())
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
            self:StartActiveReminder(reminder.definitionId, reminder.module, reminder.label, reminder.duration, reminder.endTime, reminder.occurrence, reminder.eventId)
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

function Reminders:ClearRuntimeState(moduleName)
    if not moduleName then
        self.activeReminders = {}
        self.pendingReminders = {}
        self.runtimeEventMap = {}
        self:RefreshActiveReminderDisplay()
        return
    end

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

    for eventKey, runtimeKey in pairs(self.runtimeEventMap) do
        local activeReminder = self.activeReminders[runtimeKey]
        if not activeReminder or activeReminder.moduleName == moduleName then
            self.runtimeEventMap[eventKey] = nil
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

function Reminders:BuildDefinitionFromOption(module, optionEntry, headerValue, easyNameOverride, optionOrder, bossOrder)
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
    definition.headerText = NormalizeHeaderText(headerValue)
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
            local optionHeaders = {}
            local optionEasyNames = {}

            if module.GetOptions then
                local options = { module:GetOptions() }
                AppendOptionEntries(optionEntries, options[1])
                AppendOptionHeaderMap(optionHeaders, options[2])
                if type(options[3]) == "table" then
                    for optionKey, easyName in pairs(options[3]) do
                        optionEasyNames[optionKey] = easyName
                    end
                end
            end

            if #optionEntries == 0 then
                AppendOptionEntries(optionEntries, module.toggleOptions)
            end

            local currentHeaderValue = nil
            local optionOrder = 0
            for _, optionEntry in ipairs(optionEntries) do
                optionOrder = optionOrder + 1
                local optionKey = type(optionEntry) == "table" and optionEntry[1] or optionEntry
                if optionHeaders[optionKey] ~= nil then
                    currentHeaderValue = optionHeaders[optionKey]
                end

                local definition = self:BuildDefinitionFromOption(module, optionEntry, currentHeaderValue, optionEasyNames[optionKey], optionOrder, bossOrder)
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

            groupedRows[#groupedRows + 1] = {
                kind = "timer",
                timerKey = definition.definitionId,
                bossName = bossName,
                label = definition.fullName or definition.definitionId,
                spellName = definition.easyName,
                spellText = definition.spellId and tostring(definition.spellId) or tostring(definition.optionKey or "Text"),
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

    return {
        "Boss: " .. tostring(definition.bossName or "Unknown"),
        "Ability: " .. tostring(definition.fullName or "Unknown"),
        "Easy Name: " .. tostring(definition.easyName ~= "" and definition.easyName or "N/A"),
        "Spell ID: " .. tostring(definition.spellId or "N/A"),
        "Encounter ID: " .. tostring(definition.encounterId or "N/A"),
        "Module: " .. tostring(definition.moduleName or "Unknown"),
        "Raid: " .. tostring(definition.instanceName or "Unknown"),
        "Description: " .. tostring(definition.description ~= "" and definition.description or "N/A"),
        "Confirmed Live: " .. (definition.confirmed and "Yes" or "No"),
    }
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

function Reminders:GetRule(definitionId)
    if not definitionId or definitionId == "" then
        return nil
    end

    return self:GetStorage().rules[definitionId]
end

function Reminders:IsRuleOccurrenceMatch(rule, occurrenceNumber)
    local occurrenceValue = tonumber(rule and rule.occurrenceNumber)
    if not occurrenceValue or occurrenceValue <= 0 then
        return true
    end

    return occurrenceNumber == math.floor(occurrenceValue + 0.0001)
end

function Reminders:StartActiveReminder(definitionId, module, label, duration, endTime, occurrenceNumber, eventId)
    local rule = self:GetRule(definitionId)
    if not rule or rule.enabled ~= true then
        return
    end

    local definition = self:GetDefinitionById(definitionId)
    local now = GetPreciseNow()
    local runtimeKey = self:BuildRuntimeInstanceKey(definitionId)
    local instanceMatchKey = self:BuildRuleInstanceMatchKey(module, label, eventId)
    local activeReminder = {
        runtimeKey = runtimeKey,
        definitionId = definitionId,
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
        instanceMatchKey = instanceMatchKey,
        rule = rule,
    }

    self.activeReminders[runtimeKey] = activeReminder
    self.runtimeEventMap[instanceMatchKey] = runtimeKey
end

function Reminders:ActivateRuleForTimer(definitionId, module, label, duration, eventId)
    if not self:IsEnabledForProfile() then
        return
    end

    local rule = self:GetRule(definitionId)
    if not rule or rule.enabled ~= true then
        return
    end

    local occurrenceNumber = (self.pullCounts[definitionId] or 0) + 1
    self.pullCounts[definitionId] = occurrenceNumber

    if not self:IsRuleOccurrenceMatch(rule, occurrenceNumber) then
        return
    end

    local now = GetPreciseNow()
    local secondsBeforeEnd = math.max(0, tonumber(rule.secondsBeforeEnd) or 0)
    local endTime = now + (duration or 0)

    if secondsBeforeEnd > 0 and duration and duration > secondsBeforeEnd then
        local pendingKey = self:BuildPendingInstanceKey(definitionId)
        self.pendingReminders[pendingKey] = {
            pendingKey = pendingKey,
            definitionId = definitionId,
            timerKey = definitionId,
            module = module,
            moduleName = module and module.moduleName or rule.moduleName,
            label = NormalizeText(label),
            duration = duration or 0,
            endTime = endTime,
            eventId = eventId,
            occurrence = occurrenceNumber,
            secondsBeforeEnd = secondsBeforeEnd,
            instanceMatchKey = self:BuildRuleInstanceMatchKey(module, label, eventId),
        }
    else
        self:StartActiveReminder(definitionId, module, label, duration, endTime, occurrenceNumber, eventId)
    end

    self:StartReminderDisplayTimer()
    self:RefreshActiveReminderDisplay()
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
    end

    self:UpdateLegacyObservedTimer(module, definitionId, text, duration, icon, eventId)
    self:ActivateRuleForTimer(definitionId, module, text, duration, eventId)
    self:RefreshUI()
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

function Reminders:GetRuleEditorState(definitionId)
    local definition = self:GetDefinitionById(definitionId)
    local rule = self:GetRule(definitionId)

    if not definition then
        return {
            hasTimer = false,
            text = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            showBar = false,
            showCountdown = false,
            statusText = "Select a BigWigs timer definition to create a reminder.",
        }
    end

    if not rule then
        return {
            hasTimer = true,
            text = "",
            secondsBeforeEnd = "0",
            occurrenceNumber = "0",
            showBar = false,
            showCountdown = false,
            statusText = "No reminder saved for this timer yet.",
        }
    end

    return {
        hasTimer = true,
        text = rule.text or "",
        secondsBeforeEnd = tostring(rule.secondsBeforeEnd or 0),
        occurrenceNumber = tostring(rule.occurrenceNumber or 0),
        showBar = rule.showBar == true,
        showCountdown = rule.showCountdown == true,
        statusText = string.format("Reminder saved. Updated: %s", date("%Y-%m-%d %H:%M", rule.updatedAt or time())),
    }
end

function Reminders:SaveRule(definitionId, data)
    local definition = self:GetDefinitionById(definitionId)
    if not definition then
        return false, "Select a BigWigs timer definition first."
    end

    local text = NormalizeText(data and data.text)
    if text == "" then
        return false, "Reminder text cannot be empty."
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

    self:GetStorage().rules[definitionId] = {
        definitionId = definitionId,
        timerKey = definitionId,
        text = text,
        secondsBeforeEnd = secondsBeforeEnd,
        occurrenceNumber = occurrenceNumber,
        showBar = data and data.showBar == true or false,
        showCountdown = data and data.showCountdown == true or false,
        enabled = true,
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
    return true, "Reminder saved."
end

function Reminders:DeleteRule(definitionId)
    if not definitionId or definitionId == "" then
        return false, "Select a BigWigs timer definition first."
    end

    if not self:GetStorage().rules[definitionId] then
        return false, "No saved reminder exists for this timer."
    end

    self:GetStorage().rules[definitionId] = nil
    AP:NotifyOptionsChanged()
    return true, "Reminder deleted."
end

function Reminders:GetRuleCount()
    local count = 0
    for _ in pairs(self:GetStorage().rules or {}) do
        count = count + 1
    end
    return count
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

function Reminders:MigrateLegacyRules()
    local storage = self:GetStorage()
    if storage.legacyRuleMigrationComplete then
        return
    end

    local migrations = {}
    for ruleKey, rule in pairs(storage.rules or {}) do
        if type(ruleKey) == "string" and ruleKey:find("|text:", 1, true) then
            local observed = storage.observedTimers[ruleKey]
            if observed then
                local optionKey = observed.spellId or nil
                local targetId = self:GetDefinitionId({
                    moduleName = observed.moduleName,
                    GetEncounterID = function()
                        return observed.encounterId
                    end,
                }, optionKey, observed.label)
                if targetId ~= ruleKey then
                    migrations[#migrations + 1] = {
                        from = ruleKey,
                        to = targetId,
                        rule = rule,
                    }
                end
            end
        end
    end

    for _, migration in ipairs(migrations) do
        storage.rules[migration.to] = CopyTableShallow(migration.rule)
        storage.rules[migration.to].definitionId = migration.to
        storage.rules[migration.to].timerKey = migration.to
        storage.rules[migration.from] = nil
    end

    storage.legacyRuleMigrationComplete = true
end

function Reminders:PrimeReminderData(filterValue)
    self.debugLastRequestedRaidFilter = filterValue
    self:MigrateLegacyRules()
    if filterValue and filterValue ~= "ALL" then
        self:EnsureRaidMetadataLoaded(filterValue)
    end
end
