local AP = _G["APRaidUtils"]

local RosterManager = {}
AP.RosterManager = RosterManager

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

    return NormalizeRealmForKey(GetRealmName() or "")
end

local function BuildFullPlayerName(name, realm)
    if not name or name == "" then
        return nil
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

function RosterManager:GetPreparedRoster(rosterString)
    if not rosterString or strtrim(rosterString) == "" then
        return nil, 0, "Error: No roster provided"
    end

    local roster = self:ParseRoster(rosterString)
    local rosterCount = 0
    for _ in pairs(roster) do
        rosterCount = rosterCount + 1
    end

    if rosterCount == 0 then
        return nil, 0, "Error: Could not parse roster"
    end

    return roster, rosterCount
end

function RosterManager:ParseRoster(rosterString)
    local roster = {}
    for nameRealm in string.gmatch(rosterString, "[^;]+") do
        local trimmed = strtrim(nameRealm)
        if trimmed ~= "" then
            local normalized = self:NormalizePlayerName(trimmed)
            if normalized then
                roster[normalized] = trimmed
            end
        end
    end
    return roster
end

function RosterManager:GetCurrentRaidMembers()
    local members = {}
    if not IsInRaid() then
        return members
    end
    
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            members[i] = {
                name = name,
                subgroup = subgroup,
                index = i
            }
        end
    end
    return members
end

function RosterManager:GetCurrentGroupMembers()
    if IsInRaid() then
        return self:GetCurrentRaidMembers()
    end

    local members = {}
    local function AddMember(unit)
        if not UnitExists(unit) then
            return
        end

        local name, realm = UnitFullName(unit)
        if not name then
            name = UnitName(unit)
        end

        local fullName = BuildFullPlayerName(name, realm)
        if fullName then
            table.insert(members, { name = fullName })
        end
    end

    AddMember("player")

    if IsInGroup() then
        local numMembers = GetNumSubgroupMembers()
        for i = 1, numMembers do
            AddMember("party" .. i)
        end
    end

    return members
end

function RosterManager:NormalizePlayerName(name)
    if not name then
        return nil
    end

    local trimmedName = strtrim(name)
    if trimmedName == "" then
        return nil
    end

    local playerName, realm = trimmedName:match("^([^%-]+)%-(.+)$")
    if playerName then
        playerName = strtrim(playerName)
        realm = NormalizeRealmForKey(strtrim(realm))
    else
        playerName = trimmedName
        realm = GetNormalizedRealmNameSafe()
    end

    return playerName:lower() .. "-" .. realm
end

function RosterManager:InviteMissing(roster)
    local invited = 0
    local currentMembers = self:GetCurrentGroupMembers()
    local alreadyPresent = {}
    
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        alreadyPresent[normalized] = true
    end
    
    for normalizedName, inviteName in pairs(roster) do
        if not alreadyPresent[normalizedName] then
            C_PartyInfo.InviteUnit(inviteName)
            invited = invited + 1
        end
    end
    
    return invited
end

function RosterManager:FindFirstAvailableGroup()
    local currentMembers = self:GetCurrentRaidMembers()
    local groupCounts = {0, 0, 0, 0}
    
    for _, member in pairs(currentMembers) do
        if member.subgroup >= 1 and member.subgroup <= 4 then
            groupCounts[member.subgroup] = groupCounts[member.subgroup] + 1
        end
    end
    
    for group = 1, 4 do
        if groupCounts[group] < 5 then
            return group
        end
    end
    
    return 1
end

function RosterManager:MoveExtras(roster)
    if not IsInRaid() or not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return 0, 0, "Error: You must be raid leader or assistant"
    end
    
    local movedOut = 0
    local movedIn = 0
    local currentMembers = self:GetCurrentRaidMembers()
    local targetGroup = 7
    
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        if roster[normalized] and member.subgroup >= 7 then
            local newGroup = self:FindFirstAvailableGroup()
            SetRaidSubgroup(member.index, newGroup)
            movedIn = movedIn + 1
        elseif not roster[normalized] and member.subgroup < 7 then
            SetRaidSubgroup(member.index, targetGroup)
            movedOut = movedOut + 1
            targetGroup = targetGroup == 7 and 8 or 7
        end
    end
    
    return movedOut, movedIn
end

function RosterManager:GetRosterPreview(rosterString)
    local roster, _, errorMessage = self:GetPreparedRoster(rosterString)
    if not roster then
        return nil, errorMessage
    end

    local currentMembers = self:GetCurrentGroupMembers()
    local alreadyPresent = {}
    
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        alreadyPresent[normalized] = true
    end
    
    local missing = {}
    for normalizedName, inviteName in pairs(roster) do
        if not alreadyPresent[normalizedName] then
            table.insert(missing, inviteName)
        end
    end
    
    local toMoveOut = {}
    local toMoveIn = {}
    if IsInRaid() then
        for _, member in pairs(self:GetCurrentRaidMembers()) do
            local normalized = self:NormalizePlayerName(member.name)
            if roster[normalized] and member.subgroup >= 7 then
                table.insert(toMoveIn, member.name .. " (Group " .. member.subgroup .. " → 1-4)")
            elseif not roster[normalized] and member.subgroup < 7 then
                table.insert(toMoveOut, member.name .. " (Group " .. member.subgroup .. " → 7/8)")
            end
        end
    end
    
    return {missing = missing, toMoveOut = toMoveOut, toMoveIn = toMoveIn}
end

function RosterManager:ProcessRoster(rosterString)
    local roster, rosterCount, errorMessage = self:GetPreparedRoster(rosterString)
    if not roster then
        return errorMessage, false
    end

    local invited = self:InviteMissing(roster)
    local movedOut, movedIn, moveError = self:MoveExtras(roster)

    if moveError then
        local result = string.format("Processed %d roster members\nInvited: %d\n%s", rosterCount, invited, moveError)
        return result, false, invited, movedOut, movedIn
    end

    local result = string.format("Processed %d roster members\nInvited: %d\nMoved to 7/8: %d\nMoved to 1-4: %d",
        rosterCount, invited, movedOut, movedIn)

    return result, true, invited, movedOut, movedIn
end

function RosterManager:InviteOnly(rosterString)
    local roster, _, errorMessage = self:GetPreparedRoster(rosterString)
    if not roster then
        return errorMessage, false, 0
    end

    local invited = self:InviteMissing(roster)
    return string.format("Invited: %d players", invited), true, invited
end

function RosterManager:MoveOnly(rosterString)
    local roster, _, errorMessage = self:GetPreparedRoster(rosterString)
    if not roster then
        return errorMessage, false, 0, 0
    end

    local movedOut, movedIn, moveError = self:MoveExtras(roster)
    if moveError then
        return moveError, false, movedOut, movedIn
    end

    return string.format("Moved to 7/8: %d | Moved to 1-4: %d", movedOut, movedIn), true, movedOut, movedIn
end

function RosterManager:ShowUI()
    if AP.OpenMainWindow then
        AP:OpenMainWindow("Roster")
        return
    end

    AP:Print("APRaidUtils UI is unavailable.")
end
