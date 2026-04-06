local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local Sync = AP:NewModule("Sync", "AceEvent-3.0")

local Comms = AP:GetModule("Comms")

local function GetM33kAurasDB()
    return M33kAurasSaved and M33kAurasSaved.displays
end

local function IsSenderInSameGuild(sender)
    if not sender or sender == "" then
        return false
    end
    GuildRoster()
    local playerGuild = GetGuildInfo("player")
    if not playerGuild or playerGuild == "" then
        return false
    end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            local nameWithoutRealm = name:match("([^%-]+)")
            if nameWithoutRealm and nameWithoutRealm:lower() == sender:lower() then
                return true
            end
        end
    end
    return false
end

function Sync:OnEnable()
    Comms:RegisterCallback("REMINDER_PUSH", function(_, sender, distribution, data)
        self:OnPushReceived(sender, data)
    end)
    Comms:RegisterCallback("REMINDER_ACK", function(_, sender, distribution, data)
        self:OnAckReceived(sender, data)
    end)
end

function Sync:HasPushPermission()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function Sync:PushFromTab(encounterId)
    if not self:HasPushPermission() then
        return false, "Only raid leaders and assistants can push reminders."
    end

    local AuraBuilder = AP:GetModule("AuraBuilder", true)
    if not AuraBuilder or not AuraBuilder:IsAvailable() then
        return false, "M33kAuras is not available."
    end

    local db = GetM33kAurasDB()
    if not db then
        return false, "M33kAuras saved variables not available."
    end

    local Reminders = AP:GetModule("Reminders", true)
    local aurasToPush = {}
    local pushedCount = 0

    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template then
            local defEncounterId = data.ap_encounter_id
            if encounterId == "ALL" or tostring(defEncounterId) == tostring(encounterId) then
                local defId = data.ap_definition_id
                aurasToPush[defId] = aurasToPush[defId] or {}
                aurasToPush[defId][data.ap_rule_id] = data
                pushedCount = pushedCount + 1
            end
        end
    end

    if pushedCount == 0 then
        return false, "No reminders exist to push."
    end

    local encounterName = encounterId == "ALL" and "All encounters" or (Reminders and Reminders.GetRaidDisplayName and Reminders:GetRaidDisplayName(tonumber(encounterId)) or "Unknown")

    local payload = {
        encounterId = encounterId,
        encounterName = encounterName,
        version = time(),
        auras = aurasToPush,
        pushedBy = UnitName("player"),
        timestamp = time(),
    }

    Comms:Broadcast("REMINDER_PUSH", "RAID", payload)

    return true, string.format("Pushed %d reminders to raid.", pushedCount)
end

function Sync:PushToPlayer(targetName, encounterId)
    if not self:HasPushPermission() then
        return false, "Only raid leaders and assistants can push reminders."
    end

    if not targetName or targetName == "" then
        return false, "Please specify a player to push to."
    end

    local AuraBuilder = AP:GetModule("AuraBuilder", true)
    if not AuraBuilder or not AuraBuilder:IsAvailable() then
        return false, "M33kAuras is not available."
    end

    local db = GetM33kAurasDB()
    if not db then
        return false, "M33kAuras saved variables not available."
    end

    local Reminders = AP:GetModule("Reminders", true)
    local aurasToPush = {}
    local pushedCount = 0

    for _, data in pairs(db) do
        if data.ap_source == "APRaidUtils" and not data.ap_is_template then
            local defEncounterId = data.ap_encounter_id
            if encounterId == "ALL" or tostring(defEncounterId) == tostring(encounterId) then
                local defId = data.ap_definition_id
                aurasToPush[defId] = aurasToPush[defId] or {}
                aurasToPush[defId][data.ap_rule_id] = data
                pushedCount = pushedCount + 1
            end
        end
    end

    if pushedCount == 0 then
        return false, "No reminders exist to push."
    end

    local encounterName = encounterId == "ALL" and "All encounters" or (Reminders and Reminders.GetRaidDisplayName and Reminders:GetRaidDisplayName(tonumber(encounterId)) or "Unknown")

    local payload = {
        encounterId = encounterId,
        encounterName = encounterName,
        version = time(),
        auras = aurasToPush,
        pushedBy = UnitName("player"),
        timestamp = time(),
    }

    Comms:Whisper("REMINDER_PUSH", targetName, payload)

    return true, string.format("Pushed %d reminders to %s.", pushedCount, targetName)
end

function Sync:OnPushReceived(sender, data)
    self.pushAckTarget = sender

    if type(data) ~= "table" or not data.auras or not data.encounterId then
        return
    end

    if not IsSenderInSameGuild(sender) then
        self:SendAck(data.encounterId, data.version, "denied", "Sender is not in your guild.")
        return
    end

    local AuraBuilder = AP:GetModule("AuraBuilder", true)
    if not AuraBuilder or not AuraBuilder:IsAvailable() then
        self:SendAck(data.encounterId, data.version, "error", "M33kAuras is not available.")
        return
    end

    local profile = AP.db and AP.db.profile
    if profile and profile.reminders and profile.reminders.autoImport == false then
        self:SendAck(data.encounterId, data.version, "ok", "Auto-import disabled.")
        return
    end

    local successCount = 0
    local errorCount = 0

    for defId, auras in pairs(data.auras) do
        if type(auras) == "table" then
            for ruleId, auraData in pairs(auras) do
                if type(auraData) == "table" then
                    auraData.uid = nil
                    local encounterId = auraData.ap_encounter_id
                    local moduleName = auraData.ap_module_name
                    local bossName = auraData.ap_boss_name
                    if AuraBuilder and encounterId then
                        AuraBuilder:GetOrCreateBossGroup(encounterId, bossName, moduleName)
                        AuraBuilder:AddToBossGroup(auraData.id, encounterId, bossName, moduleName)
                    end
                    local ok = pcall(M33kAuras.Add, auraData)
                    if ok then
                        successCount = successCount + 1
                    else
                        errorCount = errorCount + 1
                    end
                end
            end
        end
    end

    if errorCount == 0 then
        self:SendAck(data.encounterId, data.version, "ok")
    else
        self:SendAck(data.encounterId, data.version, "ok", string.format("%d errors during import", errorCount))
    end

    self:ShowReceivedReminderNotification(sender, data.pushpedBy)

    local Reminders = AP:GetModule("Reminders", true)
    if Reminders and Reminders.RefreshUI then
        Reminders:RefreshUI()
    end
end

function Sync:ShowReceivedReminderNotification(senderName, pushedBy)
    local frame = APRaidUtilsReceivedReminderPopup
    if not frame then
        frame = CreateFrame("Frame", "APRaidUtilsReceivedReminderPopup", UIParent, "BackdropTemplate")
        frame:SetSize(360, 140)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        frame:SetFrameStrata("DIALOG")
        frame:Hide()

        frame:SetBackdrop({
            bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
            edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
            tile = true,
            edgeSize = 32,
            tileSize = 32,
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOP", 0, -16)
        title:SetText("APRaidUtils Reminders Received")
        title:SetTextColor(1, 0.82, 0, 1)

        local message = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        message:SetPoint("TOP", title, "BOTTOM", 0, -20)
        message:SetSize(320, 60)
        message:SetText("")
        message:SetJustifyH("CENTER")
        frame.Message = message

        local reloadButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        reloadButton:SetSize(120, 28)
        reloadButton:SetPoint("BOTTOM", -50, 16)
        reloadButton:SetText("Reload UI")
        reloadButton:SetScript("OnClick", function()
            ReloadUI()
        end)

        local dismissButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dismissButton:SetSize(80, 28)
        dismissButton:SetPoint("LEFT", reloadButton, "RIGHT", 16, 0)
        dismissButton:SetText("Dismiss")
        dismissButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetSize(80, 28)
        closeButton:SetPoint("RIGHT", reloadButton, "LEFT", -16, 0)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local senderDisplay = pushedBy or senderName or "Unknown"
    frame.Message:SetText(string.format("You've received pushed reminders from %s.\n\nClick 'Reload UI' to apply them now, or 'Dismiss' to load them on your next reload.", senderDisplay))
    frame:Show()
end

function Sync:SendAck(encounterId, version, status, message)
    local payload = {
        encounterId = encounterId,
        version = version,
        status = status,
        message = message,
    }
    Comms:Whisper("REMINDER_ACK", self.pushAckTarget or UnitName("player"), payload)
end

function Sync:OnAckReceived(sender, data)
    self.ackLog = self.ackLog or {}
    self.ackLog[sender] = {
        status = data and data.status,
        message = data and data.message,
        timestamp = time(),
    }
end

function Sync:GetAckStatus()
    return self.ackLog or {}
end

function Sync:ClearAckLog()
    self.ackLog = {}
end
