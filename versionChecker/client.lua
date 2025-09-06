-- BASED ON https://wago.io/exrYkN05u

local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local VersionChecker = AP:GetModule("VersionChecker")

-- Use shared AceComm prefix from main module
local ACE_PREFIX = APVersionChecker_ACE_PREFIX

function VersionChecker:OnCommReceived(prefix, message, distribution, sender)
    if prefix == ACE_PREFIX then
        local success, payload = self:Deserialize(message)
        if success and type(payload) == "table" and payload.query == "QUERY_VERSION" then
            local waNames = payload.waNames or {}
            local versions = self:GetAllVersions(waNames)
            local replyTable = { response = "VERSION_INFO", versions = versions }
            local reply = self:Serialize(replyTable)
            self:SendCommMessage(ACE_PREFIX, reply, "WHISPER", sender)
        end
    end
end

-- All version checker logic below

local function StringHash(text)
    local counter = 1
    local len = string.len(text)
    for i = 1, len, 3 do 
        counter = math.fmod(counter*8161, 4294967279) +
        (string.byte(text,i)*16776193) +
        ((string.byte(text,i+1) or (len-i+256))*8372226) +
        ((string.byte(text,i+2) or (len-i+256))*3932164)
    end
    return math.fmod(counter, 4294967291)
end

function VersionChecker:GetWeakAurasVersion()
    if WeakAuras then
        return WeakAuras.versionString
    end
    return "0"
end

function VersionChecker:GetBigWigsVersion()
    if BigWigsAPI then
        return ("%d-%s"):format(BigWigsAPI.GetVersion(), BigWigsAPI.GetVersionHash())
    end
    return "0"
end

function VersionChecker:GetDBMVersion()
    if DBM then
        return DBM.Revision
    end
    return "0"
end

function VersionChecker:GetMRTVersion()
    if _G.VMRT then
        return _G.VMRT.Addon.Version
    end
    return "0"
end

function VersionChecker:GetNSVersion()
    local ver = C_AddOns.GetAddOnMetadata("NorthernSkyRaidTools", "Version") or "Addon Missing"
    if ver ~= "Addon Missing" then
        ver = C_AddOns.IsAddOnLoaded("NorthernSkyRaidTools") and ver or "Addon not enabled"
    end
    if ver == "Addon Missing" or ver == "Addon not enabled" then
        return "0"
    end
    return ver
end

function VersionChecker:HashMRTNote()
    if C_AddOns.IsAddOnLoaded("MRT") then
        if _G.VMRT and _G.VMRT.Note and _G.VMRT.Note.Text1 then
            local text = _G.VMRT.Note.Text1
            return StringHash(text)
        end
        return "(Unreadable)"
    end
    return "(No Addon)"
end

function VersionChecker:GetWeakAuraVersionByName(waName)
    if not WeakAuras or not WeakAuras.GetData then return -1 end
    local waData = WeakAuras.GetData(waName)
    if not waData then
        return -1
    end
    if not waData['url'] then
        return 0
    end
    local waURL = waData['url']
    local versionStr = waURL:match('.*/(%d+)$')
    if not versionStr then
        return 0
    end
    return tonumber(versionStr)
end

function VersionChecker:GetIgnoredRaiders()
    local ignoredRaiders = {}
    local groupType, numMembers

    if IsInRaid() then
        groupType = "raid"
        numMembers = GetNumGroupMembers()
    elseif IsInGroup() then
        groupType = "party"
        numMembers = GetNumSubgroupMembers()
    else
        groupType = "solo"
        numMembers = 0
    end

    if groupType == "solo" then
        return ':)'
    elseif groupType == "raid" then
        for i = 1, numMembers do
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            local name = UnitName(unit)
            if guid and C_FriendList.IsIgnoredByGuid(guid) then
                table.insert(ignoredRaiders, name)
            end
        end
    elseif groupType == "party" then
        for i = 1, numMembers do
            local unit = "party" .. i
            local guid = UnitGUID(unit)
            local name = UnitName(unit)
            if guid and C_FriendList.IsIgnoredByGuid(guid) then
                table.insert(ignoredRaiders, name)
            end
        end
        -- Also check the player themselves
        local guid = UnitGUID("player")
        local name = UnitName("player")
        if guid and C_FriendList.IsIgnoredByGuid(guid) then
            table.insert(ignoredRaiders, name)
        end
    end

    local implodedList = table.concat(ignoredRaiders, ", ")
    if implodedList == '' then
        return ':)'
    end
    return implodedList
end

function VersionChecker:GetAllVersions(waNames)
    local versions = {
        WeakAuras = self:GetWeakAurasVersion(),
        BigWigs = self:GetBigWigsVersion(),
        DBM = self:GetDBMVersion(),
        MRT = self:GetMRTVersion(),
        NS = self:GetNSVersion(),
        MRTNoteHash = self:HashMRTNote(),
        IgnoredRaiders = self:GetIgnoredRaiders(),
        WeakAuraVersions = {}
    }
    if waNames and type(waNames) == "table" then
        for _, waName in ipairs(waNames) do
            versions.WeakAuraVersions[waName] = self:GetWeakAuraVersionByName(waName)
        end
    end
    return versions
end
