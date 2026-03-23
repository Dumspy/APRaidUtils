local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Reminders = AP:NewModule("Reminders", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

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

local function IsPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function GetPreciseNow()
    return GetTime and GetTime() or 0
end

local function GetSpellName(spellId)
    if not IsPositiveNumber(spellId) or not C_Spell or not C_Spell.GetSpellName then
        return nil
    end

    return C_Spell.GetSpellName(spellId)
end

local function GetDisplayLabel(label)
    label = NormalizeText(label)
    label = label:gsub("%s*%(%d+%)$", "")
    return label
end

function Reminders:OnInitialize()
    self.activeReminders = {}
    self.pendingReminders = {}
    self.bigWigsCallbacksRegistered = false
end

function Reminders:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "HandleAddonLoaded")
    self:EnsureBigWigsCallbacksRegistered()
end

function Reminders:OnDisable()
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterBigWigsCallbacks()
end

function Reminders:GetStorage()
    if not AP.db or not AP.db.global then
        return nil
    end

    local globalStorage = AP.db.global.reminders
    local profileStorage = AP.db.profile and AP.db.profile.reminders

    if globalStorage and profileStorage then
        local hasGlobalObserved = next(globalStorage.observedTimers or {}) ~= nil
        local hasGlobalRules = next(globalStorage.rules or {}) ~= nil
        local hasProfileObserved = next(profileStorage.observedTimers or {}) ~= nil
        local hasProfileRules = next(profileStorage.rules or {}) ~= nil

        if not hasGlobalObserved and hasProfileObserved then
            for timerKey, timerData in pairs(profileStorage.observedTimers) do
                globalStorage.observedTimers[timerKey] = CopyTableShallow(timerData)
            end
        end

        if not hasGlobalRules and hasProfileRules then
            for timerKey, ruleData in pairs(profileStorage.rules) do
                globalStorage.rules[timerKey] = CopyTableShallow(ruleData)
            end
        end

        if globalStorage.enabled == nil and profileStorage.enabled ~= nil then
            globalStorage.enabled = profileStorage.enabled
        end
    end

    return globalStorage
end

function Reminders:HandleAddonLoaded(_, addonName)
    if addonName == "BigWigs" then
        self:EnsureBigWigsCallbacksRegistered()
        self:RefreshUI()
    end
end

function Reminders:IsBigWigsAvailable()
    return type(BigWigsLoader) == "table" and type(BigWigsLoader.RegisterMessage) == "function"
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

function Reminders:BuildRuntimeInstanceKey(timerKey)
    return string.format("%s|%.3f", tostring(timerKey), GetPreciseNow())
end

function Reminders:BuildPendingInstanceKey(timerKey)
    return string.format("pending|%s|%.3f", tostring(timerKey), GetPreciseNow())
end

function Reminders:BuildRenderedText(rule, activeReminder)
    local countdownText = activeReminder.countdownText or ""
    local text = tostring(rule.text or "")
    text = text:gsub("{countdown}", countdownText)
    text = text:gsub("{spell}", tostring(activeReminder.label or rule.label or ""))
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
            self:StartActiveReminder(reminder.timerKey, reminder.module, reminder.label, reminder.duration, reminder.endTime)
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

function Reminders:FindMatchingRuntimeKeys(module, text)
    local runtimeKeys = {}
    local moduleName = module and module.moduleName or nil
    local normalizedLabel = NormalizeText(text):lower()

    for runtimeKey, reminder in pairs(self.activeReminders) do
        if reminder.moduleName == moduleName and NormalizeText(reminder.label):lower() == normalizedLabel then
            runtimeKeys[#runtimeKeys + 1] = runtimeKey
        end
    end

    return runtimeKeys
end

function Reminders:FindMatchingPendingKeys(module, text)
    local pendingKeys = {}
    local moduleName = module and module.moduleName or nil
    local normalizedLabel = NormalizeText(text):lower()

    for pendingKey, reminder in pairs(self.pendingReminders) do
        if reminder.moduleName == moduleName and NormalizeText(reminder.label):lower() == normalizedLabel then
            pendingKeys[#pendingKeys + 1] = pendingKey
        end
    end

    return pendingKeys
end

function Reminders:StartActiveReminder(timerKey, module, label, duration, endTime)
    local rule = self:GetRule(timerKey)
    if not rule or rule.enabled ~= true then
        return
    end

    local observedTimer = self:GetObservedTimerByKey(timerKey)
    local now = GetPreciseNow()
    local runtimeKey = self:BuildRuntimeInstanceKey(timerKey)
    local activeReminder = {
        runtimeKey = runtimeKey,
        timerKey = timerKey,
        moduleName = module.moduleName,
        bossName = observedTimer and observedTimer.bossName or rule.bossName,
        label = NormalizeText(label),
        icon = observedTimer and observedTimer.icon or nil,
        duration = duration or 0,
        remaining = math.max(0, (endTime or now) - now),
        startedAt = now,
        endTime = endTime or (now + (duration or 0)),
        showBar = rule.showBar == true,
        showCountdown = rule.showCountdown == true,
        rule = rule,
    }

    self.activeReminders[runtimeKey] = activeReminder
end

function Reminders:ActivateRuleForTimer(timerKey, module, label, duration)
    if not self:IsEnabledForProfile() then
        return
    end

    local rule = self:GetRule(timerKey)
    if not rule or rule.enabled ~= true then
        return
    end

    local now = GetPreciseNow()
    local secondsBeforeEnd = math.max(0, tonumber(rule.secondsBeforeEnd) or 0)
    local endTime = now + (duration or 0)

    if secondsBeforeEnd > 0 and duration and duration > secondsBeforeEnd then
        local pendingKey = self:BuildPendingInstanceKey(timerKey)
        self.pendingReminders[pendingKey] = {
            pendingKey = pendingKey,
            timerKey = timerKey,
            module = module,
            moduleName = module.moduleName,
            label = NormalizeText(label),
            duration = duration or 0,
            endTime = endTime,
            secondsBeforeEnd = secondsBeforeEnd,
        }
    else
        self:StartActiveReminder(timerKey, module, label, duration, endTime)
    end

    self:StartReminderDisplayTimer()
    self:RefreshActiveReminderDisplay()
end

function Reminders:IsInRaidInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

function Reminders:BuildObservedTimerKey(module, key, label)
    local encounterId = module and module.GetEncounterID and module:GetEncounterID() or 0
    local moduleName = module and module.moduleName or "Unknown"
    local normalizedLabel = NormalizeText(label)

    if IsPositiveNumber(key) then
        return string.format("enc:%s|mod:%s|spell:%d", tostring(encounterId or 0), moduleName, key)
    end

    return string.format("enc:%s|mod:%s|text:%s", tostring(encounterId or 0), moduleName, normalizedLabel:lower())
end

function Reminders:ObserveBigWigsTimer(module, key, label, duration, icon, eventId)
    if not self:IsEnabledForProfile() or not self:IsInRaidInstance() then
        return
    end

    if type(module) ~= "table" or not label or label == "" then
        return
    end

    local timerKey = self:BuildObservedTimerKey(module, key, label)
    local observedTimer = self:GetStorage().observedTimers[timerKey] or {}
    local currentTime = time()
    local encounterId = module.GetEncounterID and module:GetEncounterID() or nil
    local journalId = module.GetJournalID and module:GetJournalID() or nil
    local instanceName = GetRealZoneText and GetRealZoneText() or nil

    observedTimer.timerKey = timerKey
    observedTimer.bossName = module.displayName or module.moduleName or "Unknown"
    observedTimer.moduleName = module.moduleName
    observedTimer.encounterId = encounterId
    observedTimer.journalId = journalId
    observedTimer.instanceName = instanceName or observedTimer.instanceName or "Unknown Raid"
    observedTimer.spellId = IsPositiveNumber(key) and key or nil
    observedTimer.label = NormalizeText(label)
    observedTimer.icon = icon
    observedTimer.lastDuration = duration
    observedTimer.lastEventId = eventId
    observedTimer.lastSeenAt = currentTime
    observedTimer.firstSeenAt = observedTimer.firstSeenAt or currentTime
    observedTimer.confirmed = true

    self:GetStorage().observedTimers[timerKey] = observedTimer
    self:RefreshUI()
end

function Reminders:HandleBigWigsStartBar(_, module, key, text, time, icon, isApprox, maxTime, eventId)
    local duration = maxTime or time or 0
    self:ObserveBigWigsTimer(module, key, text, duration, icon, eventId)

    local timerKey = self:BuildObservedTimerKey(module, key, text)
    self:ActivateRuleForTimer(timerKey, module, text, duration)
end

function Reminders:HandleBigWigsStopBar(_, module, text)
    for _, runtimeKey in ipairs(self:FindMatchingRuntimeKeys(module, text)) do
        self.activeReminders[runtimeKey] = nil
    end
    for _, pendingKey in ipairs(self:FindMatchingPendingKeys(module, text)) do
        self.pendingReminders[pendingKey] = nil
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:HandleBigWigsStopBars(_, module)
    if not module then
        return
    end

    for runtimeKey, reminder in pairs(self.activeReminders) do
        if reminder.moduleName == module.moduleName then
            self.activeReminders[runtimeKey] = nil
        end
    end
    for pendingKey, reminder in pairs(self.pendingReminders) do
        if reminder.moduleName == module.moduleName then
            self.pendingReminders[pendingKey] = nil
        end
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:HandleBigWigsBossDisable(_, module)
    self:HandleBigWigsStopBars(nil, module)
end

function Reminders:HandleBigWigsPauseBar(_, module, text)
    local now = GetPreciseNow()
    for _, runtimeKey in ipairs(self:FindMatchingRuntimeKeys(module, text)) do
        local reminder = self.activeReminders[runtimeKey]
        if reminder and not reminder.pausedAt then
            reminder.pauseRemaining = math.max(0, (reminder.endTime or now) - now)
            reminder.pausedAt = now
        end
    end
    for _, pendingKey in ipairs(self:FindMatchingPendingKeys(module, text)) do
        local reminder = self.pendingReminders[pendingKey]
        if reminder and not reminder.pausedAt then
            reminder.pauseRemaining = math.max(0, (reminder.endTime or now) - now)
            reminder.pausedAt = now
        end
    end
    self:RefreshActiveReminderDisplay()
end

function Reminders:HandleBigWigsResumeBar(_, module, text)
    local now = GetPreciseNow()
    for _, runtimeKey in ipairs(self:FindMatchingRuntimeKeys(module, text)) do
        local reminder = self.activeReminders[runtimeKey]
        if reminder and reminder.pausedAt then
            reminder.endTime = now + (reminder.pauseRemaining or 0)
            reminder.pausedAt = nil
            reminder.pauseRemaining = nil
        end
    end
    for _, pendingKey in ipairs(self:FindMatchingPendingKeys(module, text)) do
        local reminder = self.pendingReminders[pendingKey]
        if reminder and reminder.pausedAt then
            reminder.endTime = now + (reminder.pauseRemaining or 0)
            reminder.pausedAt = nil
            reminder.pauseRemaining = nil
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

function Reminders:GetObservedTimers()
    local observedTimers = {}
    for timerKey, timerData in pairs(self:GetStorage().observedTimers or {}) do
        local row = CopyTableShallow(timerData)
        row.timerKey = timerKey
        observedTimers[#observedTimers + 1] = row
    end

    table.sort(observedTimers, function(left, right)
        local leftBoss = tostring(left.bossName or left.label or left.timerKey):lower()
        local rightBoss = tostring(right.bossName or right.label or right.timerKey):lower()
        if leftBoss ~= rightBoss then
            return leftBoss < rightBoss
        end

        local leftLabel = tostring(left.label or left.timerKey):lower()
        local rightLabel = tostring(right.label or right.timerKey):lower()
        return leftLabel < rightLabel
    end)

    return observedTimers
end

function Reminders:GetObservedTimerByKey(timerKey)
    if not timerKey or timerKey == "" then
        return nil
    end

    return self:GetStorage().observedTimers[timerKey]
end

function Reminders:GetObservedTimerDisplayRows()
    local groupedRows = {}
    local lastGroupKey = nil

    for _, timer in ipairs(self:GetObservedTimers()) do
        local encounterText = timer.encounterId and string.format("Encounter %s", tostring(timer.encounterId)) or "Unknown Encounter"
        local bossName = timer.bossName or "Unknown"
        local groupKey = string.format("%s|%s", encounterText, bossName)

        if groupKey ~= lastGroupKey then
            groupedRows[#groupedRows + 1] = {
                kind = "section",
                bossName = bossName,
                label = encounterText,
                spellText = "",
                lastSeenText = "",
            }
            lastGroupKey = groupKey
        end

        groupedRows[#groupedRows + 1] = {
            kind = "timer",
            timerKey = timer.timerKey,
            bossName = "",
            label = timer.label or timer.timerKey,
            spellText = timer.spellId and tostring(timer.spellId) or "Text",
            lastSeenText = date("%m-%d %H:%M", timer.lastSeenAt or time()),
        }
    end

    return groupedRows
end

function Reminders:GetObservedRaidFilterItems()
    local raidMap = {}
    local items = {
        {
            value = "ALL",
            label = "All raids",
        },
    }

    for _, timer in ipairs(self:GetObservedTimers()) do
        local instanceName = timer.instanceName or "Unknown Raid"
        if not raidMap[instanceName] then
            raidMap[instanceName] = true
            items[#items + 1] = {
                value = instanceName,
                label = instanceName,
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

function Reminders:GetObservedTimerDisplayRowsForRaid(instanceName)
    local groupedRows = {}
    local lastGroupKey = nil

    for _, timer in ipairs(self:GetObservedTimers()) do
        local timerInstanceName = timer.instanceName or "Unknown Raid"
        if not instanceName or instanceName == "ALL" or timerInstanceName == instanceName then
            local encounterText = timer.encounterId and string.format("Encounter %s", tostring(timer.encounterId)) or timerInstanceName
            local bossName = timer.bossName or "Unknown"
            local groupKey = string.format("%s|%s", timerInstanceName, bossName)

            if groupKey ~= lastGroupKey then
                groupedRows[#groupedRows + 1] = {
                    kind = "section",
                    bossName = bossName,
                    label = timerInstanceName,
                    spellText = "",
                    lastSeenText = "",
                    encounterText = encounterText,
                }
                lastGroupKey = groupKey
            end

            groupedRows[#groupedRows + 1] = {
                kind = "timer",
                timerKey = timer.timerKey,
                bossName = encounterText,
                label = GetDisplayLabel(timer.label or timer.timerKey),
                spellName = GetSpellName(timer.spellId),
                spellText = timer.spellId and tostring(timer.spellId) or "Text",
                lastSeenText = date("%m-%d %H:%M", timer.lastSeenAt or time()),
            }
        end
    end

    return groupedRows
end

function Reminders:GetObservedTimerDetailLines(timerKey)
    local timer = self:GetObservedTimerByKey(timerKey)
    if not timer then
        return {
            "Select an observed timer to inspect its details.",
            "Once the picker is in place, this panel will feed directly into reminder creation.",
        }
    end

    return {
        "Boss: " .. tostring(timer.bossName or "Unknown"),
        "Label: " .. tostring(timer.label or "Unknown"),
        "Spell ID: " .. tostring(timer.spellId or "N/A"),
        "Encounter ID: " .. tostring(timer.encounterId or "N/A"),
        "Module: " .. tostring(timer.moduleName or "Unknown"),
        "Last Duration: " .. tostring(timer.lastDuration or "N/A"),
        "First Seen: " .. date("%Y-%m-%d %H:%M", timer.firstSeenAt or time()),
        "Last Seen: " .. date("%Y-%m-%d %H:%M", timer.lastSeenAt or time()),
    }
end

function Reminders:GetRule(timerKey)
    if not timerKey or timerKey == "" then
        return nil
    end

    return self:GetStorage().rules[timerKey]
end

function Reminders:GetRuleEditorState(timerKey)
    local timer = self:GetObservedTimerByKey(timerKey)
    local rule = self:GetRule(timerKey)

    if not timer then
        return {
            hasTimer = false,
            text = "",
            secondsBeforeEnd = "0",
            showBar = false,
            showCountdown = false,
            statusText = "Select an observed timer to create a reminder.",
        }
    end

    if not rule then
        return {
            hasTimer = true,
            text = "",
            secondsBeforeEnd = "0",
            showBar = false,
            showCountdown = false,
            statusText = "No reminder saved for this timer yet.",
        }
    end

    return {
        hasTimer = true,
        text = rule.text or "",
        secondsBeforeEnd = tostring(rule.secondsBeforeEnd or 0),
        showBar = rule.showBar == true,
        showCountdown = rule.showCountdown == true,
        statusText = string.format("Reminder saved. Updated: %s", date("%Y-%m-%d %H:%M", rule.updatedAt or time())),
    }
end

function Reminders:SaveRule(timerKey, data)
    local timer = self:GetObservedTimerByKey(timerKey)
    if not timer then
        return false, "Select an observed timer first."
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

    self:GetStorage().rules[timerKey] = {
        timerKey = timerKey,
        text = text,
        secondsBeforeEnd = secondsBeforeEnd,
        showBar = data and data.showBar == true or false,
        showCountdown = data and data.showCountdown == true or false,
        enabled = true,
        updatedAt = time(),
        encounterId = timer.encounterId,
        moduleName = timer.moduleName,
        bossName = timer.bossName,
        label = timer.label,
        spellId = timer.spellId,
    }

    AP:NotifyOptionsChanged()
    return true, "Reminder saved."
end

function Reminders:DeleteRule(timerKey)
    if not timerKey or timerKey == "" then
        return false, "Select an observed timer first."
    end

    if not self:GetStorage().rules[timerKey] then
        return false, "No saved reminder exists for this timer."
    end

    self:GetStorage().rules[timerKey] = nil
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

function Reminders:GetStatusText()
    local bigWigsLoaded = self:IsBigWigsAvailable() and "available" or "not detected"
    local observedCount = #self:GetObservedTimers()
    local ruleCount = self:GetRuleCount()
    local enabledText = self:IsEnabledForProfile() and "enabled" or "disabled"
    local listenerText = self.bigWigsCallbacksRegistered and "listening" or "idle"

    return string.format(
        "Reminders are %s. BigWigs is %s (%s). Observed timers: %d. Saved reminders: %d.",
        enabledText,
        bigWigsLoaded,
        listenerText,
        observedCount,
        ruleCount
    )
end

function Reminders:GetPlaceholderLines()
    return {
        "V1 is being built in small steps.",
        "- Raid-only, BigWigs-only reminder support",
        "- Shared across your characters through the active AceDB profile",
        "- Live BigWigs timer observation and reminder firing are wired in",
        "- Use preview mode to place the active reminder anchor",
    }
end
