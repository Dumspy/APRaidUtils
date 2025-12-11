local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local RosterManager = AP:NewModule("RosterManager", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local rosterFrame

function RosterManager:OnEnable()
    self:RegisterChatCommand("aproster", "ShowUI")
end

function RosterManager:ParseRoster(rosterString)
    local roster = {}
    for nameRealm in string.gmatch(rosterString, "[^;]+") do
        local trimmed = strtrim(nameRealm)
        if trimmed ~= "" then
            roster[trimmed] = true
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

function RosterManager:NormalizePlayerName(name)
    if not name then return nil end
    if not string.find(name, "-") then
        local realm = GetRealmName()
        realm = realm:gsub("%s+", "")
        return name .. "-" .. realm
    end
    return name
end

function RosterManager:InviteMissing(roster)
    local invited = 0
    local currentMembers = self:GetCurrentRaidMembers()
    local alreadyInRaid = {}
    
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        alreadyInRaid[normalized] = true
    end
    
    for nameRealm, _ in pairs(roster) do
        if not alreadyInRaid[nameRealm] then
            C_PartyInfo.InviteUnit(nameRealm)
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
        return 0, 0, "You must be raid leader or assistant"
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
    if not rosterString or rosterString == "" then
        return nil, "Error: No roster provided"
    end
    
    local roster = self:ParseRoster(rosterString)
    local currentMembers = self:GetCurrentRaidMembers()
    local alreadyInRaid = {}
    
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        alreadyInRaid[normalized] = true
    end
    
    local missing = {}
    for nameRealm, _ in pairs(roster) do
        if not alreadyInRaid[nameRealm] then
            table.insert(missing, nameRealm)
        end
    end
    
    local toMoveOut = {}
    local toMoveIn = {}
    for _, member in pairs(currentMembers) do
        local normalized = self:NormalizePlayerName(member.name)
        if roster[normalized] and member.subgroup >= 7 then
            table.insert(toMoveIn, member.name .. " (Group " .. member.subgroup .. " → 1-4)")
        elseif not roster[normalized] and member.subgroup < 7 then
            table.insert(toMoveOut, member.name .. " (Group " .. member.subgroup .. " → 7/8)")
        end
    end
    
    return {missing = missing, toMoveOut = toMoveOut, toMoveIn = toMoveIn}
end

function RosterManager:ProcessRoster(rosterString)
    if not rosterString or rosterString == "" then
        return "Error: No roster provided"
    end
    
    local roster = self:ParseRoster(rosterString)
    local rosterCount = 0
    for _ in pairs(roster) do
        rosterCount = rosterCount + 1
    end
    
    if rosterCount == 0 then
        return "Error: Could not parse roster"
    end
    
    local invited = self:InviteMissing(roster)
    local movedOut, movedIn = self:MoveExtras(roster)
    
    local result = string.format("Processed %d roster members\nInvited: %d\nMoved to 7/8: %d\nMoved to 1-4: %d", 
        rosterCount, invited, movedOut, movedIn)
    
    return result
end

function RosterManager:ShowUI()
    if rosterFrame then
        rosterFrame:Release()
    end
    
    rosterFrame = AceGUI:Create("Frame")
    rosterFrame:SetTitle("APRaidUtils - Roster Manager")
    rosterFrame:SetWidth(550)
    rosterFrame:SetHeight(600)
    rosterFrame:SetLayout("List")
    
    local instructionLabel = AceGUI:Create("Label")
    instructionLabel:SetText("Paste your roster string (semicolon-separated Name-Realm format):")
    instructionLabel:SetFullWidth(true)
    rosterFrame:AddChild(instructionLabel)
    
    local rosterInput = AceGUI:Create("MultiLineEditBox")
    rosterInput:SetLabel("")
    rosterInput:SetFullWidth(true)
    rosterInput:SetNumLines(8)
    rosterInput:SetText("")
    rosterFrame:AddChild(rosterInput)
    
    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetText("")
    statusLabel:SetFullWidth(true)
    statusLabel:SetColor(1, 1, 1)
    rosterFrame:AddChild(statusLabel)
    
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetFullWidth(true)
    rosterFrame:AddChild(buttonGroup)
    
    local previewBtn = AceGUI:Create("Button")
    previewBtn:SetText("Preview")
    previewBtn:SetWidth(100)
    buttonGroup:AddChild(previewBtn)
    
    local processBtn = AceGUI:Create("Button")
    processBtn:SetText("Process Roster")
    processBtn:SetWidth(120)
    buttonGroup:AddChild(processBtn)
    
    local inviteOnlyBtn = AceGUI:Create("Button")
    inviteOnlyBtn:SetText("Invite Only")
    inviteOnlyBtn:SetWidth(100)
    buttonGroup:AddChild(inviteOnlyBtn)
    
    local moveOnlyBtn = AceGUI:Create("Button")
    moveOnlyBtn:SetText("Move Extras")
    moveOnlyBtn:SetWidth(100)
    buttonGroup:AddChild(moveOnlyBtn)
    
    local previewScroll = AceGUI:Create("ScrollFrame")
    previewScroll:SetFullWidth(true)
    previewScroll:SetLayout("List")
    previewScroll:SetHeight(200)
    rosterFrame:AddChild(previewScroll)
    
    previewBtn:SetCallback("OnClick", function()
        local rosterText = rosterInput:GetText()
        local preview = self:GetRosterPreview(rosterText)
        
        previewScroll:ReleaseChildren()
        
        if not preview then
            statusLabel:SetText("Error: No roster provided")
            statusLabel:SetColor(1, 0, 0)
            return
        end
        
        local missingLabel = AceGUI:Create("Label")
        missingLabel:SetText("|cffFFFF00Missing Players (Will Invite):|r")
        missingLabel:SetFullWidth(true)
        previewScroll:AddChild(missingLabel)
        
        if #preview.missing == 0 then
            local noneLabel = AceGUI:Create("Label")
            noneLabel:SetText("|cff00FF00  All roster members are in the raid|r")
            noneLabel:SetFullWidth(true)
            previewScroll:AddChild(noneLabel)
        else
            for _, player in ipairs(preview.missing) do
                local playerLabel = AceGUI:Create("Label")
                playerLabel:SetText("  • " .. player)
                playerLabel:SetFullWidth(true)
                previewScroll:AddChild(playerLabel)
            end
        end
        
        local spacer1 = AceGUI:Create("Label")
        spacer1:SetText(" ")
        spacer1:SetFullWidth(true)
        previewScroll:AddChild(spacer1)
        
        local moveInLabel = AceGUI:Create("Label")
        moveInLabel:SetText("|cffFFFF00Roster Members to Move Back (7/8 → 1-4):|r")
        moveInLabel:SetFullWidth(true)
        previewScroll:AddChild(moveInLabel)
        
        if #preview.toMoveIn == 0 then
            local noneLabel = AceGUI:Create("Label")
            noneLabel:SetText("|cff00FF00  All roster members in correct groups|r")
            noneLabel:SetFullWidth(true)
            previewScroll:AddChild(noneLabel)
        else
            for _, player in ipairs(preview.toMoveIn) do
                local playerLabel = AceGUI:Create("Label")
                playerLabel:SetText("  • " .. player)
                playerLabel:SetFullWidth(true)
                previewScroll:AddChild(playerLabel)
            end
        end
        
        local spacer2 = AceGUI:Create("Label")
        spacer2:SetText(" ")
        spacer2:SetFullWidth(true)
        previewScroll:AddChild(spacer2)
        
        local moveOutLabel = AceGUI:Create("Label")
        moveOutLabel:SetText("|cffFFFF00Non-Roster Members to Move Out (1-4 → 7/8):|r")
        moveOutLabel:SetFullWidth(true)
        previewScroll:AddChild(moveOutLabel)
        
        if #preview.toMoveOut == 0 then
            local noneLabel = AceGUI:Create("Label")
            noneLabel:SetText("|cff00FF00  No extra players to move|r")
            noneLabel:SetFullWidth(true)
            previewScroll:AddChild(noneLabel)
        else
            for _, player in ipairs(preview.toMoveOut) do
                local playerLabel = AceGUI:Create("Label")
                playerLabel:SetText("  • " .. player)
                playerLabel:SetFullWidth(true)
                previewScroll:AddChild(playerLabel)
            end
        end
        
        statusLabel:SetText(string.format("Preview: %d to invite, %d to move in, %d to move out", 
            #preview.missing, #preview.toMoveIn, #preview.toMoveOut))
        statusLabel:SetColor(0.8, 0.8, 1)
    end)
    
    processBtn:SetCallback("OnClick", function()
        local rosterText = rosterInput:GetText()
        local result = self:ProcessRoster(rosterText)
        statusLabel:SetText(result)
        if string.find(result, "Error") then
            statusLabel:SetColor(1, 0, 0)
        else
            statusLabel:SetColor(0, 1, 0)
        end
    end)
    
    inviteOnlyBtn:SetCallback("OnClick", function()
        local rosterText = rosterInput:GetText()
        if not rosterText or rosterText == "" then
            statusLabel:SetText("Error: No roster provided")
            statusLabel:SetColor(1, 0, 0)
            return
        end
        local roster = self:ParseRoster(rosterText)
        local invited = self:InviteMissing(roster)
        statusLabel:SetText(string.format("Invited: %d players", invited))
        statusLabel:SetColor(0, 1, 0)
    end)
    
    moveOnlyBtn:SetCallback("OnClick", function()
        local rosterText = rosterInput:GetText()
        if not rosterText or rosterText == "" then
            statusLabel:SetText("Error: No roster provided")
            statusLabel:SetColor(1, 0, 0)
            return
        end
        local roster = self:ParseRoster(rosterText)
        local movedOut, movedIn = self:MoveExtras(roster)
        statusLabel:SetText(string.format("Moved to 7/8: %d | Moved to 1-4: %d", movedOut, movedIn))
        statusLabel:SetColor(0, 1, 0)
    end)
end
