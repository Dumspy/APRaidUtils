# APRaidUtils Technical Architecture Documentation

## Overview

This document describes the architectural changes made in v2.0.0 to align APRaidUtils with modern WoW addon patterns, reducing external dependencies while improving security and performance.

## Motivation

The original implementation used Ace3 libraries extensively. Analysis of reference addons like NorthernSkyRaidTools revealed that a more minimal approach is possible while maintaining code quality.

**Goals:**
1. Reduce external dependencies from 16 to 6 libraries
2. Improve security (sender validation, rate limiting)
3. Optimize performance (caching, reduced iterations)
4. Align with modern WoW addon patterns

---

## Architecture Changes

### 1. Namespace Pattern

**Before:**
```lua
APRaidUtils = LibStub("AceAddon-3.0"):NewAddon("APRaidUtils", "AceConsole-3.0", "AceEvent-3.0")
local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
```

**After:**
```lua
local AP = {}
_G["APRaidUtils"] = AP
_G["AP"] = AP
```

All files now use `local AP = _G["APRaidUtils"]` to access the namespace.

### 2. Central Event Frame

**Before:**
```lua
self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
```

**After:**
```lua
-- In main.lua
local eventFrame = CreateFrame("Frame")
AP.eventFrame = eventFrame
eventFrame:SetAllPoints(UIParent)

-- In eventHandler.lua
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
-- ...

eventFrame:SetScript("OnEvent", function(self, event, ...)
    AP:HandleEvent(event, ...)
end)

function AP:HandleEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:OnPlayerLogin()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if AP.LeadPassReminder then
            AP.LeadPassReminder:CheckConditions()
        end
    end
end
```

### 3. Direct Saved Variables

**Before:**
```lua
local AceDB = LibStub("AceDB-3.0")
self.db = AceDB:New("APRaidUtilsDB", defaults, true)
-- Access: self.db.profile.setting
```

**After:**
```lua
-- In main.lua InitializeSavedVariables()
APRaidUtilsDB = APRaidUtilsDB or {}
APRaidUtilsDB.profile = APRaidUtilsDB.profile or {}
APRaidUtilsDB.global = APRaidUtilsDB.global or {}

-- Access: APRaidUtilsDB.profile.setting
```

### 4. Manual Slash Commands

**Before:**
```lua
self:RegisterChatCommand("ap", "HandleChatCommand")
self:Print("Loaded")
```

**After:**
```lua
SlashCmdList["APRAIDUTILS"] = function(msg) AP:HandleChatCommand(msg) end
SLASH_APRAIDUTILS1 = "/ap"

function AP:Print(...)
    print("|cFFFFD100APRaidUtils|r:", ...)
end
```

### 5. Module Pattern

**Before:**
```lua
local Comms = AP:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")
```

**After:**
```lua
local Comms = {}
AP.Comms = Comms

-- AceComm registered separately
local AceComm = LibStub("AceComm-3.0")
AceComm:RegisterComm("AP_MSG", function(...)
    Comms:OnCommReceived(...)
end)
```

---

## Security Improvements

### Sender Validation

```lua
function Comms:OnCommReceived(prefix, message, distribution, sender)
    -- Validate sender is in group
    if not UnitInRaid(sender) and not UnitInParty(sender) then return end
    
    -- Deserialize and validate payload
    local success, payload = AceSerializer:Deserialize(message)
    if not success or type(payload.event) ~= "string" then return end
    
    -- pcall wrapper for safety
    local cbSuccess, err = pcall(callback, payload.event, sender, distribution, payload.data)
end
```

### Rate Limiting

```lua
local commRateLimits = {}
local COMM_RATE_LIMIT_WINDOW = 2  -- seconds
local COMM_RATE_LIMIT_MAX = 5     -- messages per window

local function CheckRateLimit(sender, event)
    local key = sender .. ":" .. event
    local now = GetTime()
    local limits = commRateLimits[key]
    
    if not limits or now > limits.resetTime then
        limits = { count = 0, resetTime = now + COMM_RATE_LIMIT_WINDOW }
        commRateLimits[key] = limits
    end
    
    limits.count = limits.count + 1
    return limits.count <= COMM_RATE_LIMIT_MAX
end
```

---

## Performance Optimizations

### CleanupSimcData Caching

**Before:** Called on every `GetSimcCharacter()`, `GetSimcCharacters()`, etc.
**After:** Runs once per session:

```lua
function AP:CleanupSimcData()
    if self._simcCleanupDone then return end
    self._simcCleanupDone = true
    -- ... cleanup logic
end
```

### Optimized Subgroup Lookup

**Before:**
```lua
local playerName = UnitName("player")
for i = 1, raidSize do
    local name, _, subgroup = GetRaidRosterInfo(i)
    if name == playerName then  -- String comparison
        return subgroup
    end
end
```

**After:**
```lua
for i = 1, GetNumGroupMembers() do
    if UnitIsUnit("raid" .. i, "player") then  -- Early exit
        return select(3, GetRaidRosterInfo(i)) or 0
    end
end
```

---

## Dependency Changes

### Removed Libraries (9)

- AceAddon-3.0
- AceDB-3.0
- AceEvent-3.0
- AceConsole-3.0
- AceTimer-3.0 (we use C_Timer directly)
- AceHook-3.0 (unused)
- AceBucket-3.0 (unused)
- AceTab-3.0 (unused)
- AceLocale-3.0 (unused)

### Retained Libraries (6)

- AceComm-3.0 - Addon communication
- AceSerializer-3.0 - Message serialization
- LibStub - Library loader
- CallbackHandler-1.0 - Required by AceComm
- LibSharedMedia-3.0 - Font/media access
- LibDFramework-1.0 - UI framework

---

## File Changes Summary

### New Files
- `eventHandler.lua` - Centralized event dispatcher

### Modified Files
| File | Changes |
|------|---------|
| `main.lua` | Complete rewrite for namespace pattern, saved vars, events |
| `comms.lua` | Security validation, rate limiting, direct AceComm usage |
| `leadpass.lua` | Module conversion, optimized subgroup lookup |
| `rosterManager.lua` | Module conversion |
| `simcExport/main.lua` | Module conversion |
| `reminders/main.lua` | Module conversion |
| `reminders/aurabuilder.lua` | Module conversion |
| `reminders/ui.lua` | Reference updates |
| `versionChecker/main.lua` | Module conversion |
| `versionChecker/client.lua` | Reference updates |
| `versionChecker/server.lua` | Reference updates |
| `versionChecker/ui.lua` | Reference updates |
| `ui/main.lua` | All GetModule calls → direct references |
| `ui/anchor.lua` | Module conversion |
| `settings/registry.lua` | Reference updates |
| `settings/renderers/df.lua` | Namespace update |
| `libs/libs.xml` | Removed 9 unused libraries |
| `APRaidUtils.toc` | Added eventHandler.lua, reordered |
| `AGENTS.md` | Updated with new patterns |

---

## Testing Notes

1. Run `/reload` after changes
2. Test `/ap` command
3. Verify saved variables persist (check APRaidUtilsDB)
4. Test guild/raid communication
5. Test each UI tab (SimC, Roster, Versions, Reminders, Settings)

---

## Migration for Existing Users

Users should `/reload` after updating. No manual migration needed - saved variables are accessed the same way, just through direct table access instead of AceDB.