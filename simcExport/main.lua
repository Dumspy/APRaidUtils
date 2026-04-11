local AP = _G["APRaidUtils"]

local SimcExport = {}
AP.SimcExport = SimcExport

local LOGIN_CAPTURE_DELAY_SECONDS = 5
local CHANGE_CAPTURE_DELAY_SECONDS = 2

function SimcExport:GetSimulationcraftAddon()
    if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Simulationcraft") then
        return nil, "Simulationcraft must be installed and enabled."
    end

    local simcAddon = LibStub("AceAddon-3.0"):GetAddon("Simulationcraft", true)
    if not simcAddon then
        return nil, "Simulationcraft is unavailable."
    end

    return simcAddon
end

function SimcExport:GetSimulationcraftExporter()
    local simcAddon, simcError = self:GetSimulationcraftAddon()
    if not simcAddon then
        return nil, simcError
    end

    if SimulationcraftAPI and type(SimulationcraftAPI.GetSimcProfile) == "function" and simcAddon then
        return function(...)
            return SimulationcraftAPI.GetSimcProfile(simcAddon, ...)
        end
    end

    if simcAddon and simcAddon.GetSimcProfile then
        return function(...)
            return simcAddon:GetSimcProfile(...)
        end
    end

    return nil, "Simulationcraft export support is unavailable."
end

function SimcExport:SaveCapturedExport(characterInfo, exportText, silent)
    if not exportText or exportText == "" then
        if not silent then
            AP:Print("Simulationcraft returned an empty export.")
        end
        return false
    end

    local didSave = AP:SaveSimcExport(characterInfo, exportText)
    if not didSave then
        if not silent then
            AP:Print("Simulationcraft returned an incomplete export. Your previous saved export was kept.")
        end
        return false
    end

    if not silent then
        AP:Print("Saved SimulationCraft export for " .. AP:GetCharacterDisplayName(characterInfo) .. ".")
    end

    return true
end

function SimcExport:CaptureCurrentCharacterViaCommand(characterInfo, silent)
    local simcAddon, simcError = self:GetSimulationcraftAddon()
    if not simcAddon then
        if not silent then
            AP:Print(simcError)
        end
        return false
    end

    if not simcAddon.PrintSimcProfile or not simcAddon.GetMainFrame then
        if not silent then
            AP:Print("Simulationcraft command export support is unavailable.")
        end
        return false
    end

    if self.captureInProgress then
        if not silent then
            AP:Print("A SimulationCraft export is already being generated.")
        end
        return false
    end

    self.captureInProgress = true

    local originalGetMainFrame = simcAddon.GetMainFrame
    local frameProxy = { Show = function() end }
    local finished = false
    local wrappedGetMainFrame = nil

    local function finish(exportText, errorMessage)
        if finished then
            return
        end

        finished = true
        self.captureInProgress = false

        if simcAddon.GetMainFrame == wrappedGetMainFrame then
            simcAddon.GetMainFrame = originalGetMainFrame
        end

        if errorMessage then
            if not silent then
                AP:Print(errorMessage)
            end
            return
        end

        local didSave = self:SaveCapturedExport(characterInfo, exportText, silent)
        if didSave and self.RefreshUI then
            self:RefreshUI()
        end
    end

    wrappedGetMainFrame = function(_, text)
        finish(text, nil)
        return frameProxy
    end

    simcAddon.GetMainFrame = wrappedGetMainFrame

    local success = pcall(simcAddon.PrintSimcProfile, simcAddon, false, false, false, nil)
    if not success then
        finish(nil, "Failed to generate a SimulationCraft export via the Simulationcraft command path.")
        return false
    end

    C_Timer.After(5, function()
        finish(nil, "Simulationcraft timed out while generating the export.")
    end)

    return true
end

function SimcExport:GetAutomaticCaptureCharacterInfo(silent)
    local characterInfo = AP:RegisterCurrentCharacter()
    AP:NotifyOptionsChanged()

    if not characterInfo or not characterInfo.isMaxLevel then
        if not silent then
            AP:Print("Only max-level characters can save SimulationCraft exports.")
        end
        return nil
    end

    if not AP:IsSimcCharacterEnabled(characterInfo.key) then
        if not silent then
            AP:Print("Enable this character in APRaidUtils settings first.")
        end
        return nil
    end

    return characterInfo
end

function SimcExport:CancelAutomaticCaptureTimer()
    if self.automaticCaptureTimer and self.automaticCaptureTimer.Cancel then
        self.automaticCaptureTimer:Cancel()
    end

    self.automaticCaptureTimer = nil
end

function SimcExport:RunAutomaticCapture()
    if self.captureInProgress then
        self:ScheduleAutomaticCapture(CHANGE_CAPTURE_DELAY_SECONDS)
        return
    end

    local refreshedCharacterInfo = self:GetAutomaticCaptureCharacterInfo(true)
    if not refreshedCharacterInfo then
        return
    end

    local didStart = self:CaptureCurrentCharacterViaCommand(refreshedCharacterInfo, true)
    if didStart or self.captureInProgress then
        return
    end

    local didCapture = self:CaptureCurrentCharacter(true)
    if didCapture and self.RefreshUI then
        self:RefreshUI()
    end
end

function SimcExport:ScheduleAutomaticCapture(delaySeconds)
    self:CancelAutomaticCaptureTimer()

    local characterInfo = self:GetAutomaticCaptureCharacterInfo(true)
    if not characterInfo then
        return
    end

    self.automaticCaptureTimer = C_Timer.NewTimer(delaySeconds or LOGIN_CAPTURE_DELAY_SECONDS, function()
        self.automaticCaptureTimer = nil
        self:RunAutomaticCapture()
    end)
end

function SimcExport:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    if not isInitialLogin and not isReloadingUi then
        return
    end

    self:ScheduleAutomaticCapture(LOGIN_CAPTURE_DELAY_SECONDS)
end

function SimcExport:OnPlayerEquipmentChanged()
    self:ScheduleAutomaticCapture(CHANGE_CAPTURE_DELAY_SECONDS)
end

function SimcExport:OnTraitConfigUpdated(configID)
    local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if activeConfigID and configID and configID ~= activeConfigID then
        return
    end

    self:ScheduleAutomaticCapture(CHANGE_CAPTURE_DELAY_SECONDS)
end

function SimcExport:OnActivePlayerSpecializationChanged()
    self:ScheduleAutomaticCapture(CHANGE_CAPTURE_DELAY_SECONDS)
end

function SimcExport:CaptureCurrentCharacter(silent)
    local characterInfo = self:GetAutomaticCaptureCharacterInfo(silent)
    if not characterInfo then
        return false
    end

    local exporter, simcError = self:GetSimulationcraftExporter()
    if not exporter then
        if not silent then
            AP:Print(simcError)
        end
        return false
    end

    local success, exportText, exportError = pcall(exporter, false, false, false, nil)
    if not success then
        if not silent then
            AP:Print("Failed to generate a SimulationCraft export. Simulationcraft may still be initializing.")
        end
        return false
    end

    if exportError and exportError ~= "" then
        if not silent then
            AP:Print(exportError)
        end
        return false
    end

    return self:SaveCapturedExport(characterInfo, exportText, silent)
end

function SimcExport:ManualCapture()
    local characterInfo = AP:RegisterCurrentCharacter()
    if not characterInfo or not characterInfo.isMaxLevel then
        AP:Print("Only max-level characters can save SimulationCraft exports.")
        return
    end

    if not AP:IsSimcCharacterEnabled(characterInfo.key) then
        AP:SetSimcCharacterEnabled(characterInfo.key, true)
        AP:Print("Enabled SimulationCraft auto capture for " .. AP:GetCharacterDisplayName(characterInfo) .. ".")
    end

    local didStart = self:CaptureCurrentCharacterViaCommand(characterInfo, false)
    if not didStart then
        local didCapture = self:CaptureCurrentCharacter(false)
        if didCapture and self.RefreshUI then
            self:RefreshUI()
        end
    end
end
