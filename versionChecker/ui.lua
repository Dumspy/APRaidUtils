local AP = _G["APRaidUtils"]
local VersionChecker = AP.VersionChecker

local function GetPlayerName()
    return UnitName("player") or "Player"
end

local function CopyVersions(versions)
    local copy = {}
    for key, value in pairs(versions or {}) do
        copy[key] = value
    end
    return copy
end

local function EnsureResultsState(self)
    self.uiResults = self.uiResults or {}
    self.uiResultsByName = self.uiResultsByName or {}
end

function VersionChecker:GetVersionStatusText()
    return self.uiStatusText or "Run a version check to populate the list."
end

function VersionChecker:SetVersionStatusText(text, suppressRefresh)
    self.uiStatusText = text or ""
    if not suppressRefresh then
        self:RefreshUI()
    end
end

function VersionChecker:GetVersionRows()
    EnsureResultsState(self)

    local rows = {}
    for _, row in ipairs(self.uiResults) do
        rows[#rows + 1] = row
    end

    local playerName = GetPlayerName()
    table.sort(rows, function(left, right)
        local leftIsPlayer = left.name == playerName
        local rightIsPlayer = right.name == playerName
        if leftIsPlayer ~= rightIsPlayer then
            return leftIsPlayer
        end

        return tostring(left.name):lower() < tostring(right.name):lower()
    end)

    return rows
end

function VersionChecker:RefreshUI()
    if AP.RefreshVersionsTab then
        AP:RefreshVersionsTab()
    end
end

function VersionChecker:ClearUIResults()
    EnsureResultsState(self)

    wipe(self.uiResults)
    wipe(self.uiResultsByName)

    local playerName = GetPlayerName()
    local playerRow = {
        name = playerName,
        versions = CopyVersions(self.GetAllVersions and self:GetAllVersions() or {}),
    }

    self.uiResults[1] = playerRow
    self.uiResultsByName[playerName] = playerRow
    self:RefreshUI()
end

function VersionChecker:AppendUIResultRow(name, versions)
    EnsureResultsState(self)

    local rowName = tostring(name or "Unknown")
    local row = self.uiResultsByName[rowName]
    if row then
        row.versions = CopyVersions(versions)
    else
        row = {
            name = rowName,
            versions = CopyVersions(versions),
        }
        self.uiResultsByName[rowName] = row
        self.uiResults[#self.uiResults + 1] = row
    end

    self:RefreshUI()
end

function VersionChecker:ShowUI()
    if AP.OpenMainWindow then
        AP:OpenMainWindow("Versions")
        return
    end

    AP:Print("APRaidUtils UI is unavailable.")
end