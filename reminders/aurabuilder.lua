local AP = _G["APRaidUtils"]

local AuraBuilder = {}
AP.AuraBuilder = AuraBuilder

local TEMPLATE_ID = "APRaidUtils_Template"
local ROOT_GROUP_ID = "APReminders"

local function MakeSafeId(text)
    if type(text) ~= "string" or text == "" then
        return "unknown"
    end
    text = text:gsub("[^%w]+", "_")
    text = text:lower()
    return text
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

local function IsM33kAurasAvailable()
    return type(M33kAuras) == "table" and type(M33kAuras.Add) == "function" and type(M33kAuras.Delete) == "function"
end

local function GetM33kAurasDB()
    return M33kAurasSaved and M33kAurasSaved.displays
end

local function GetSpellNameSafe(spellId)
    if type(spellId) ~= "number" or spellId <= 0 then
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

local function PhaseTokenToStageNumber(token)
    if type(token) ~= "string" or token == "" then
        return nil
    end
    local stage = token:match("^stage:(%d+)$")
    if stage then
        return tonumber(stage)
    end
    local intermission = token:match("^intermission:(%d+)$")
    if intermission then
        return tonumber(intermission) + 0.5
    end
    return nil
end

function AuraBuilder:OnEnable()
end

function AuraBuilder:IsAvailable()
    return IsM33kAurasAvailable()
end

function AuraBuilder:ResolveEncounterName(encounterId)
    if type(encounterId) ~= "number" or encounterId <= 0 then
        return nil
    end
    if EJ_GetInstanceForEncounter and EJ_GetInstanceInfo then
        local instanceId = EJ_GetInstanceForEncounter(encounterId)
        if type(instanceId) == "number" and instanceId > 0 then
            local instanceName = EJ_GetInstanceInfo(instanceId)
            if instanceName and instanceName ~= "" then
                return instanceName
            end
        end
    end
    if C_EncounterJournal and C_EncounterJournal.GetEncounterInfo then
        local info = C_EncounterJournal.GetEncounterInfo(encounterId)
        if info and info.instanceName and info.instanceName ~= "" then
            return info.instanceName
        end
    end
    return nil
end

function AuraBuilder:FindTemplate()
    if not IsM33kAurasAvailable() then
        return nil
    end
    local db = GetM33kAurasDB()
    if not db then
        return nil
    end
    return db[TEMPLATE_ID]
end

function AuraBuilder:CreateTemplate()
    if not IsM33kAurasAvailable() then
        return false, "M33kAuras is not installed."
    end
    if M33kAuras.IsLoginFinished and not M33kAuras:IsLoginFinished() then
        return false, "M33kAuras is still loading. Try again in a moment."
    end
    return self:CreateDefaultTemplate()
end

function AuraBuilder:CreateDefaultTemplate()
    if not IsM33kAurasAvailable() then
        return false, "M33kAuras is not installed."
    end
    if M33kAuras.IsLoginFinished and not M33kAuras:IsLoginFinished() then
        return false, "M33kAuras is still loading. Try again in a moment."
    end
    local db = GetM33kAurasDB()
    if not db then
        return false, "M33kAuras saved variables not initialized."
    end

    if db[TEMPLATE_ID] then
        local existing = db[TEMPLATE_ID]
        if existing and existing.ap_is_template then
            local needsRecreate = false
            if existing.internalVersion and existing.internalVersion < 50 then
                needsRecreate = true
            elseif existing.displayText == "Reminder Text Here" then
                needsRecreate = true
            end
            if needsRecreate then
                M33kAuras.Delete(existing)
            else
                return true
            end
        else
            return true
        end
    end

    local template = {
        id = TEMPLATE_ID,
        name = "APRaidUtils Reminder Template",
        regionType = "text",
        internalVersion = 89,
        parent = ROOT_GROUP_ID,
        x = 0,
        y = 200,
        fontSize = 22,
        font = "Friz Quadrata TT",
        justify = "CENTER",
        color = { 1, 0.9, 0.2, 1 },
        shadowColor = { 0, 0, 0, 1 },
        shadowXOffset = 1,
        shadowYOffset = -1,
        displayText = "%n (%p remaining)",
        triggers = {
            {
                trigger = {
                    type = "addons",
                    event = "Boss Mod Timer",
                    use_spellId = false,
                    spellId = "",
                    use_message = true,
                    message = "",
                    message_operator = "find('%s')",
                    use_count = false,
                    count = "",
                    use_remaining = false,
                    remaining = 0,
                    remaining_operator = "<",
                },
                untrigger = {},
            },
        },
        actions = {
            init = {},
            start = {
                do_sound = true,
                sound = { type = "SoundFile", path = 567496 },
                do_message = true,
                message = "Watch out for %n!",
                message_type = "Custom",
            },
            finish = {},
        },
        load = {
            use_never = true,
            size = { multi = {} },
            spec = { multi = {} },
            class = { multi = {} },
        },
        ap_is_template = true,
    }

    self:EnsureRootGroup()

    M33kAuras.Add(template)

    db = GetM33kAurasDB()
    local rootGroup = db[ROOT_GROUP_ID]
    if rootGroup and rootGroup.controlledChildren then
        if not tContains(rootGroup.controlledChildren, TEMPLATE_ID) then
            tinsert(rootGroup.controlledChildren, TEMPLATE_ID)
        end
    end

    if AP.ShowReloadDialog then
        AP:ShowReloadDialog({
            text = "The APRaidUtils Reminder Template has been created in M33kAuras. Please reload your UI to see it in the M33kAuras list.",
            action = "template_creation",
        })
    end

    return true
end

function AuraBuilder:EnsureRootGroup()
    local db = GetM33kAurasDB()
    if not db then
        return nil
    end
    if db[ROOT_GROUP_ID] then
        return db[ROOT_GROUP_ID]
    end

    local group = {
        id = ROOT_GROUP_ID,
        name = "AP Reminders",
        regionType = "group",
        controlledChildren = {},
        anchorPoint = "CENTER",
        xOffset = 0,
        yOffset = 0,
        grow = "DOWN",
        sort = "none",
        space = 10,
        border = false,
        ap_is_group = true,
        triggers = {
            {
                trigger = {
                    type = "status",
                    event = "Health",
                    unit = "player",
                },
                untrigger = {},
            },
        },
        actions = {
            init = {},
            start = {},
            finish = {},
        },
        load = {
            use_never = true,
            size = { multi = {} },
            spec = { multi = {} },
            class = { multi = {} },
        },
    }

    M33kAuras.Add(group)
    db = GetM33kAurasDB()
    return db[ROOT_GROUP_ID]
end

function AuraBuilder:GetOrCreateRaidGroup(encounterId, encounterName)
    local db = GetM33kAurasDB()
    if not db then
        return nil
    end

    self:EnsureRootGroup()

    local resolvedName = encounterName
    if not resolvedName or resolvedName == "" then
        resolvedName = definition.instanceName
    end
    if not resolvedName or resolvedName == "" then
        if type(EJ_GetInstanceForEncounter) == "function" and type(EJ_GetInstanceInfo) == "function" then
            local instanceId = EJ_GetInstanceForEncounter(encounterId)
            if type(instanceId) == "number" and instanceId > 0 then
                local name = EJ_GetInstanceInfo(instanceId)
                if type(name) == "string" and name ~= "" then
                    resolvedName = name
                end
            end
        end
    end
    if not resolvedName or resolvedName == "" then
        resolvedName = self:ResolveEncounterName(encounterId)
    end
    if not resolvedName or resolvedName == "" then
        local reminders = AP.Reminders
        if reminders and type(reminders.GetRaidDisplayName) == "function" then
            local raidId = definition.raidId or definition.instanceId or encounterId
            resolvedName = reminders:GetRaidDisplayName(raidId)
        end
    end
    if not resolvedName or resolvedName == "" then
        resolvedName = string.format("Raid %d", encounterId or 0)
    end
    local raidGroupId = resolvedName

    if db[raidGroupId] then
        return db[raidGroupId]
    end

    local raidGroup = {
        id = raidGroupId,
        name = raidGroupId,
        regionType = "group",
        parent = ROOT_GROUP_ID,
        controlledChildren = {},
        anchorPoint = "CENTER",
        xOffset = 0,
        yOffset = 0,
        grow = "DOWN",
        sort = "none",
        space = 5,
        border = false,
        ap_is_group = true,
        ap_encounter_id = encounterId,
        triggers = {
            {
                trigger = {
                    type = "status",
                    event = "Health",
                    unit = "player",
                },
                untrigger = {},
            },
        },
        actions = {
            init = {},
            start = {},
            finish = {},
        },
        load = {
            use_never = true,
            size = { multi = {} },
            spec = { multi = {} },
            class = { multi = {} },
        },
    }

    M33kAuras.Add(raidGroup)

    db = GetM33kAurasDB()
    local rootGroup = db[ROOT_GROUP_ID]
    if rootGroup and rootGroup.controlledChildren then
        if not tContains(rootGroup.controlledChildren, raidGroupId) then
            tinsert(rootGroup.controlledChildren, raidGroupId)
        end
    end

    return db[raidGroupId]
end

function AuraBuilder:GetOrCreateBossGroup(encounterId, bossName, moduleName, definition)
    local db = GetM33kAurasDB()
    if not db then
        return nil
    end

    local resolvedName = nil
    if definition and type(definition.instanceName) == "string" and definition.instanceName ~= "" then
        resolvedName = definition.instanceName
    end
    if not resolvedName or resolvedName == "" then
        if type(EJ_GetInstanceForEncounter) == "function" and type(EJ_GetInstanceInfo) == "function" then
            local instanceId = EJ_GetInstanceForEncounter(encounterId)
            if type(instanceId) == "number" and instanceId > 0 then
                local name = EJ_GetInstanceInfo(instanceId)
                if type(name) == "string" and name ~= "" then
                    resolvedName = name
                end
            end
        end
    end
    if not resolvedName or resolvedName == "" then
        resolvedName = self:ResolveEncounterName(encounterId)
    end
    if not resolvedName or resolvedName == "" then
        local reminders = AP.Reminders
        if reminders and type(reminders.GetRaidDisplayName) == "function" then
            local raidId = definition and (definition.raidId or definition.instanceId) or encounterId
            resolvedName = reminders:GetRaidDisplayName(raidId)
        end
    end
    if not resolvedName or resolvedName == "" then
        resolvedName = string.format("Raid %d", encounterId or 0)
    end

    local raidGroup = self:GetOrCreateRaidGroup(encounterId, resolvedName)
    if not raidGroup then
        return nil
    end

    db = GetM33kAurasDB()
    raidGroup = db[raidGroup.id] or raidGroup

    local bossGroupId = bossName or moduleName or "Unknown Boss"
    if db[bossGroupId] then
        return db[bossGroupId]
    end

    local bossGroup = {
        id = bossGroupId,
        name = bossGroupId,
        regionType = "group",
        parent = raidGroup.id,
        controlledChildren = {},
        anchorPoint = "CENTER",
        xOffset = 0,
        yOffset = 0,
        grow = "DOWN",
        sort = "none",
        space = 5,
        border = false,
        ap_is_group = true,
        triggers = {
            {
                trigger = {
                    type = "status",
                    event = "Health",
                    unit = "player",
                },
                untrigger = {},
            },
        },
        actions = {
            init = {},
            start = {},
            finish = {},
        },
        load = {
            encounter = { multi = { [encounterId] = true } },
            use_never = true,
            size = { multi = {} },
            spec = { multi = {} },
            class = { multi = {} },
        },
    }

    M33kAuras.Add(bossGroup)

    db = GetM33kAurasDB()
    local raidGroupRef = db[raidGroup.id]
    if raidGroupRef and raidGroupRef.controlledChildren then
        if not tContains(raidGroupRef.controlledChildren, bossGroupId) then
            tinsert(raidGroupRef.controlledChildren, bossGroupId)
        end
    end

    return db[bossGroupId]
end

function AuraBuilder:AddToBossGroup(auraId, encounterId, bossName, moduleName)
    local db = GetM33kAurasDB()
    if not db then
        return
    end

    local bossGroupId = bossName or moduleName or "Unknown Boss"
    local bossGroup = db[bossGroupId]
    if bossGroup and bossGroup.controlledChildren then
        if not tContains(bossGroup.controlledChildren, auraId) then
            tinsert(bossGroup.controlledChildren, auraId)
        end
    end
end

function AuraBuilder:BuildAuraData(rule, definition)
    if not IsM33kAurasAvailable() then
        return nil, "M33kAuras is not available"
    end

    local template = self:FindTemplate()
    if not template then
        return nil, "Reminder template not found."
    end

    local aura = CopyTableDeep(template)

    local encounterId = definition.encounterId or rule.encounterId or 0
    local spellId = definition.spellId or rule.spellId
    local ruleId = rule.ruleId
    local definitionId = definition.definitionId

    local spellName = GetSpellNameSafe(spellId)
    local baseName = nil
    if spellName and spellName ~= "" then
        baseName = MakeSafeId(spellName) .. "-" .. tostring(spellId)
    else
        local optName = definition.fullName or rule.fullName or "reminder"
        baseName = MakeSafeId(optName) .. "-opt"
    end

    local ruleIdSuffix = nil
    if rule.ruleId then
        local _, suffix = rule.ruleId:match("^(.+)_(%d+)$")
        ruleIdSuffix = suffix or rule.ruleId:sub(-8)
    end
    aura.id = baseName .. "-" .. (ruleIdSuffix or "unknown")
    aura.name = string.format("AP: %s - %s",
        definition.bossName or rule.bossName or "Unknown",
        rule.name or definition.fullName or GetSpellNameSafe(spellId) or "Reminder"
    )
    aura.uid = nil

    aura.ap_source = "APRaidUtils"
    aura.ap_encounter_id = encounterId
    aura.ap_raid_id = definition.instanceId or 0
    aura.ap_raid_name = definition.instanceName or ""
    aura.ap_rule_id = ruleId
    aura.ap_definition_id = definitionId
    aura.ap_is_template = nil
    aura.ap_module_name = definition.moduleName or rule.moduleName or "unknown"
    aura.ap_boss_name = definition.bossName or rule.bossName or "Unknown"
    aura.ap_phase_filters = rule.phaseFilters and CopyTableDeep(rule.phaseFilters) or {}

    aura.parent = definition.bossName or rule.bossName or "Unknown Boss"

    local stageNumbers = {}
    if rule.phaseFilters and #rule.phaseFilters > 0 then
        for _, token in ipairs(rule.phaseFilters) do
            local stageNum = PhaseTokenToStageNumber(token)
            if stageNum and stageNum <= 5.5 then
                stageNumbers[stageNum] = true
            elseif token == "intermission:any" then
                for im = 1, 5 do
                    stageNumbers[im + 0.5] = true
                end
            end
        end
    end

    local triggers = {
        {
            trigger = {
                type = "addons",
                event = "Boss Mod Timer",
                use_spellId = spellId ~= nil,
                spellId = spellId and tonumber(spellId) or "",
                use_message = spellId == nil,
                message = spellId == nil and (definition.fullName or "") or "",
                message_operator = spellId == nil and "find('%s')" or "",
                use_count = rule.occurrenceNumber and rule.occurrenceNumber > 0,
                count = tostring(rule.occurrenceNumber or 0),
                use_remaining = rule.secondsBeforeEnd and rule.secondsBeforeEnd > 0,
                remaining = tostring(rule.secondsBeforeEnd or 0),
                remaining_operator = "<",
            },
            untrigger = {},
        },
    }

    local hasStageFilters = next(stageNumbers) ~= nil
    if hasStageFilters then
        local stageTriggerIndex = 2
        local orParts = {}

        for stage = 0.5, 5.5, 0.5 do
            if stageNumbers[stage] then
                triggers[stageTriggerIndex] = {
                    trigger = {
                        type = "addons",
                        event = "Boss Mod Stage",
                        use_stage = true,
                        stage = tostring(stage),
                        stage_operator = "==",
                    },
                    untrigger = {},
                }
                orParts[#orParts + 1] = string.format("t[%d]", stageTriggerIndex)
                stageTriggerIndex = stageTriggerIndex + 1
            end
        end

        triggers.disjunctive = "custom"
        triggers.customTriggerLogic = string.format(
            "function(t) return t[1] and (%s) end",
            table.concat(orParts, " or ")
        )
    end

    aura.triggers = triggers

    aura.load = {
        use_encounterid = true,
        encounterid = tostring(encounterId),
        size = { multi = {} },
        spec = { multi = {} },
        class = { multi = {} },
        talent = { multi = {} },
    }

    if aura.actions and aura.actions.start then
        aura.actions.start.do_message = true
        aura.actions.start.message = rule.text or ""
        aura.actions.start.message_type = "Custom"
    end

    return aura
end

function AuraBuilder:ImportOrUpdate(rule, definition)
    local aura, err = self:BuildAuraData(rule, definition)
    if not aura then
        return false, err
    end

    local encounterId = definition.encounterId or rule.encounterId or 0
    local bossName = definition.bossName or rule.bossName
    local moduleName = definition.moduleName or rule.moduleName

    local db = GetM33kAurasDB()
    if db then
        local existing = db[aura.id]
        if not existing and rule.ruleId then
            for id, data in pairs(db) do
                if data.ap_source == "APRaidUtils" and data.ap_rule_id == rule.ruleId and not data.ap_is_template then
                    existing = data
                    if id ~= aura.id then
                        local oldParentId = data.parent
                        if oldParentId and db[oldParentId] and db[oldParentId].controlledChildren then
                            local children = db[oldParentId].controlledChildren
                            for i = #children, 1, -1 do
                                if children[i] == id then
                                    tremove(children, i)
                                    break
                                end
                            end
                        end
                        M33kAuras.Delete(data)
                    end
                    break
                end
            end
        end
        if existing then
            local oldParentId = existing.parent
            if oldParentId and oldParentId ~= aura.parent and db[oldParentId] and db[oldParentId].controlledChildren then
                local children = db[oldParentId].controlledChildren
                for i = #children, 1, -1 do
                    if children[i] == aura.id then
                        tremove(children, i)
                        break
                    end
                end
            end
            aura.uid = existing.uid
        end
    end

    self:GetOrCreateBossGroup(encounterId, bossName, moduleName, definition)

    M33kAuras.Add(aura)

    db = GetM33kAurasDB()
    local bossGroupId = bossName or moduleName or "Unknown Boss"
    local bossGroup = db[bossGroupId]
    if bossGroup and bossGroup.controlledChildren then
        if not tContains(bossGroup.controlledChildren, aura.id) then
            tinsert(bossGroup.controlledChildren, aura.id)
        end
    end

    return true
end

function AuraBuilder:RemoveByRuleId(ruleId)
    if not IsM33kAurasAvailable() then
        return false
    end

    local db = GetM33kAurasDB()
    if not db then
        return false
    end

    for id, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and data.ap_rule_id == ruleId and not data.ap_is_template then
            local parentId = data.parent
            M33kAuras.Delete(data)
            if parentId and db[parentId] and db[parentId].controlledChildren then
                local children = db[parentId].controlledChildren
                for i = #children, 1, -1 do
                    if children[i] == id then
                        tremove(children, i)
                        break
                    end
                end
                if #children == 0 and db[parentId].ap_is_group then
                    local grandParentId = db[parentId].parent
                    M33kAuras.Delete(db[parentId])
                    if grandParentId and db[grandParentId] and db[grandParentId].controlledChildren then
                        local gpChildren = db[grandParentId].controlledChildren
                        for i = #gpChildren, 1, -1 do
                            if gpChildren[i] == parentId then
                                tremove(gpChildren, i)
                                break
                            end
                        end
                    end
                end
            end
            return true
        end
    end

    return false
end

function AuraBuilder:RebuildGroups()
    if not IsM33kAurasAvailable() then
        return false, "M33kAuras is not available."
    end
    local db = GetM33kAurasDB()
    if not db then
        return false, "M33kAuras saved variables not available."
    end

    local rootGroup = self:EnsureRootGroup()
    if not rootGroup then
        return false, "Failed to create root group."
    end

    local auras = {}
    for id, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template and not data.ap_is_group then
            auras[#auras + 1] = data
        end
    end

    local raidGroups = {}
    local bossGroups = {}
    for _, data in ipairs(auras) do
        local encounterId = data.ap_encounter_id
        local bossName = data.ap_boss_name or "Unknown Boss"

        local encounterName = nil
        for id2, d2 in pairs(db) do
            if d2.ap_is_group and d2.ap_encounter_id == encounterId and d2.parent == ROOT_GROUP_ID then
                encounterName = d2.name
                break
            end
        end
        if not encounterName or encounterName == "" then
            encounterName = self:ResolveEncounterName(encounterId)
        end
        if not encounterName or encounterName == "" then
            encounterName = string.format("Raid %d", encounterId or 0)
        end

        local raidGroupId = encounterName
        local bossGroupId = bossName

        if not raidGroups[raidGroupId] then
            raidGroups[raidGroupId] = { encounterId = encounterId, encounterName = encounterName }
        end
        if not bossGroups[bossGroupId] then
            bossGroups[bossGroupId] = { encounterId = encounterId, bossName = bossName }
        end

        if data.parent ~= bossGroupId then
            data.parent = bossGroupId
        end
    end

    for raidGroupId, raidInfo in pairs(raidGroups) do
        if not db[raidGroupId] then
            self:GetOrCreateRaidGroup(raidInfo.encounterId, raidInfo.encounterName)
        end
    end

    for bossGroupId, bossInfo in pairs(bossGroups) do
        self:GetOrCreateBossGroup(bossInfo.encounterId, bossInfo.bossName)
    end

    for id, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and data.ap_is_group then
            if data.controlledChildren then
                local validChildren = {}
                for _, childId in ipairs(data.controlledChildren) do
                    if db[childId] then
                        validChildren[#validChildren + 1] = childId
                    end
                end
                data.controlledChildren = validChildren
            end
        end
    end

    return true, "Groups rebuilt."
end
