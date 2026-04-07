# APRaidUtils - Code Quality & Best Practices Evaluation

**Date:** April 7, 2026  
**Evaluated Against:** NorthernSkyRaidTools, Details Framework patterns, ElvUI architecture, WoW API best practices

---

## Executive Summary

APRaidUtils is a well-structured addon with good use of Ace3 patterns and modular architecture. The codebase demonstrates solid understanding of WoW addon development. However, there are several performance concerns, architectural inconsistencies, and best practice gaps that should be addressed.

**Overall Grade: B+**

---

## 1. Architecture & Structure

### ✅ Strengths

- **Good module separation**: Clean separation into `simcExport/`, `reminders/`, `versionChecker/`, `settings/`, `ui/`
- **Ace3 patterns**: Proper use of `AceAddon-3.0`, `AceEvent-3.0`, `AceComm-3.0`, `AceSerializer-3.0`, `AceDB-3.0`
- **Centralized comms**: `comms.lua` provides a clean abstraction over AceComm
- **Settings registry pattern**: Good abstraction with `settings/registry.lua` and pluggable renderers
- **TOC organization**: Logical load order

### ⚠️ Issues

#### 1.1 Mixed Namespace Patterns (Medium Priority)

**Problem:** Inconsistent addon reference patterns across files:
```lua
-- main.lua
APRaidUtils = LibStub("AceAddon-3.0"):NewAddon("APRaidUtils", ...)

-- Other files
local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
```

**Reference (NorthernSkyRaidTools):** Uses `local _, NSI = ...` for internal namespace, which is safer and avoids global lookups.

**Impact:** Minor performance hit from global lookups, potential naming conflicts.

**Recommendation:**
```lua
-- In main.lua
local AP = LibStub("AceAddon-3.0"):NewAddon("APRaidUtils", "AceConsole-3.0", "AceEvent-3.0")
_G.APRaidUtils = AP  -- Only if external addons need access
```

#### 1.2 ui/main.lua is Too Large (High Priority)

**Problem:** `ui/main.lua` is 2438 lines. This is a maintenance nightmare.

**Reference (NorthernSkyRaidTools):** Splits UI into `UI/Core.lua`, `UI/VersionCheck.lua`, `UI/Reminders.lua`, etc. (each 100-400 lines)

**Recommendation:** Split into:
- `ui/core.lua` - Window creation, tab management
- `ui/simc.lua` - SimC tab
- `ui/roster.lua` - Roster tab
- `ui/versions.lua` - Version checker tab
- `ui/reminders.lua` - Reminders tab
- `ui/settings.lua` - Settings tab

#### 1.3 Missing DataBroker Integration (Low Priority)

**Problem:** No LibDataBroker-1.1 integration for minimap button or addon compartment.

**Reference:** NorthernSkyRaidTools, ElvUI, and most modern addons use LDB for easy access.

**Recommendation:** Add LDB object with:
- Left-click: Toggle main window
- Tooltip: Show addon status

---

## 2. Performance Issues

### 🔴 Critical

#### 2.1 CleanupSimcData Called Excessively (High Priority)

**Location:** `main.lua:254-270`, called from multiple methods

**Problem:** `CleanupSimcData()` iterates over ALL characters and exports on every call. Called from:
- `GetSimcCharacter()` (line 300)
- `GetSimcCharacters()` (line 305)
- `GetSimcExport()` (line 329)
- `GetSimcExportCharacters()` (line 334)

This means a single UI refresh can trigger 4+ full iterations over saved data.

**Recommendation:**
```lua
-- Call only once on login/reload, or use lazy cleanup
function APRaidUtils:CleanupSimcData()
    if self._simcCleanupDone then return end
    self._simcCleanupDone = true
    -- ... cleanup logic
end
```

#### 2.2 Repeated GetMergedSettings Calls (Medium Priority)

**Location:** `ui/anchor.lua` - Every slider change, drag stop, and settings access calls `GetMergedSettings()` which performs 3 table merges.

**Problem:** Called on every frame during drag operations and slider adjustments.

**Recommendation:** Cache merged settings and only rebuild when values change:
```lua
local settingsCache = {}
local function GetCachedSettings(key, userDefaults)
    if not settingsCache[key] then
        settingsCache[key] = GetMergedSettings(key, userDefaults)
    end
    return settingsCache[key]
end
```

#### 2.3 GetRaidRosterInfo Called in Loop (Medium Priority)

**Location:** `leadpass.lua:40-45`, `rosterManager.lua:40-48`

**Problem:** Iterates entire raid roster to find player subgroup. Called on every `GROUP_ROSTER_UPDATE` event.

**Reference (NorthernSkyRaidTools):** Uses `IterateGroupMembers()` helper with early exit.

**Recommendation:**
```lua
local function GetPlayerRaidSubgroup()
    if not IsInRaid() then return 0 end
    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit("raid" .. i, "player") then
            return select(3, GetRaidRosterInfo(i)) or 0
        end
    end
    return 0
end
```

### 🟡 Moderate

#### 2.4 Table Allocations in Hot Paths (Medium Priority)

**Locations:**
- `main.lua:309-318` - Creates new table on every `GetSimcCharacters()` call
- `versionChecker/client.lua:85-91` - `CopyVersions()` allocates on every response

**Recommendation:** Reuse tables where possible or document that callers should cache results.

#### 2.5 String Concatenation in Loops (Low Priority)

**Location:** `rosterManager.lua:154-157`

**Problem:** Uses `..` concatenation in loops instead of `table.concat()`.

**Recommendation:** For small loops this is fine, but for large rosters:
```lua
local parts = {}
for _, member in ipairs(membersToMove) do
    parts[#parts + 1] = member.name .. " (Group " .. member.subgroup .. " → 1-4)"
end
return table.concat(parts, "\n")
```

---

## 3. Security & Robustness

### 🔴 Critical

#### 3.1 No Rate Limiting on Comm Messages (High Priority)

**Location:** `comms.lua:15-20`

**Problem:** `Broadcast()` can be called without any throttling. In a 40-man raid, this could flood addon channels.

**Reference (NorthernSkyRaidTools):** Uses LibDeflate compression and manual message building to reduce size.

**Recommendation:**
- Add rate limiting per event type
- Consider LibDeflate compression for large payloads
- Use `ChatThrottleLib` (included with AceComm) more explicitly

#### 3.2 Deserialize Without Validation (High Priority)

**Location:** `comms.lua:31-38`

**Problem:** Deserializes data from ANY sender without validation. While sender is checked against self, malicious addons could send malformed data.

**Recommendation:**
```lua
function Comms:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end
    
    -- Validate sender is in group
    if not UnitInRaid(sender) and not UnitInParty(sender) then return end
    
    local success, payload = self:Deserialize(message)
    if not success or not payload or not payload.event then return end
    
    -- Validate payload structure
    if type(payload.data) ~= "table" then return end
    
    local callback = callbacks[payload.event]
    if callback then
        callback(payload.event, sender, distribution, payload.data)
    end
end
```

#### 3.3 MRT Note Hash Could Expose Data (Medium Priority)

**Location:** `versionChecker/client.lua:57-65`

**Problem:** Hashes MRT note content and sends it. While hashed, this could be used to verify guesses about note content.

**Recommendation:** Document this behavior clearly or remove if not essential.

### 🟡 Moderate

#### 3.4 IsVersionNewer is Global (Low Priority)

**Location:** `main.lua:417-429`

**Problem:** Function is global, polluting namespace.

**Recommendation:** Make it local or attach to AP table:
```lua
function APRaidUtils:IsVersionNewer(their, mine)
    -- ...
end
```

---

## 4. Code Quality & Maintainability

### ✅ Strengths

- Good use of local functions where appropriate
- Consistent 4-space indentation
- Descriptive variable names
- Proper error handling in most places

### ⚠️ Issues

#### 4.1 Duplicate Function: CreateReminderForTimer (Medium Priority)

**Location:** `ui/main.lua:1035-1055` and `ui/main.lua:1057-1077`

**Problem:** Function is defined twice with identical logic. The second definition overwrites the first.

**Recommendation:** Remove duplicate.

#### 4.2 Magic Numbers Throughout (Low Priority)

**Locations:**
- `ui/main.lua:14-22` - Some constants defined, but many magic numbers remain
- `leadpass.lua:6-7` - `MYTHIC_DIFFICULTY_IDS = {[16] = true}` - only one difficulty

**Recommendation:** Define all magic numbers as named constants at file top.

#### 4.3 Inconsistent Error Handling (Medium Priority)

**Problem:** Some functions return `nil, error`, others print directly, others return false with message.

**Examples:**
- `rosterManager.lua:6` - Returns `nil, 0, "Error: ..."`
- `simcExport/main.lua:28` - Prints directly
- `reminders/main.lua` - Returns `success, message`

**Recommendation:** Standardize on `success, resultOrError` pattern.

#### 4.4 Missing Addon Compartment Support (Low Priority)

**Problem:** No `showInCompartment` support in TOC or code.

**Recommendation:** Add to TOC:
```
## Interface-AddonCompartment: 1
```

---

## 5. WoW API Best Practices

### ✅ Strengths

- Good use of modern C_* APIs with fallbacks (`C_SpecializationInfo`, `C_AddOns`, `C_Spell`)
- Proper event registration/unregistration
- Uses `AceDB-3.0` for saved variables

### ⚠️ Issues

#### 5.1 GetNormalizedRealmName Fallback Chain (Medium Priority)

**Location:** `main.lua:49-60`

**Problem:** Fallback to `GetRealmName()` defeats the purpose of normalization. `GetRealmName()` returns display name with spaces.

**Recommendation:**
```lua
local function GetNormalizedRealmNameSafe()
    if GetNormalizedRealmName then
        local realmName = GetNormalizedRealmName()
        if realmName and realmName ~= "" then
            return NormalizeRealmForKey(realmName)
        end
    end
    -- If no normalized name available, return empty string
    -- Cross-realm features won't work, but better than wrong data
    return ""
end
```

#### 5.2 UnitClass vs UnitClassBase (Low Priority)

**Location:** `main.lua:190`

**Problem:** Uses `UnitClass("player")` which returns localized name. Should use `UnitClassBase("player")` for consistent classFile.

**Recommendation:**
```lua
local _, classFile = UnitClassBase("player")
```

#### 5.3 Missing C_Timer.After Cleanup (Medium Priority)

**Location:** `simcExport/main.lua:117-119`

**Problem:** Timer created but not stored for cleanup. If player logs out during capture, timer could fire on next login.

**Recommendation:** Already partially handled with `loginCaptureTimer` check, but ensure all timers are cancelled in `OnDisable`.

---

## 6. Dependencies & External Integrations

### ⚠️ Issues

#### 6.1 Heavy Reliance on DetailsFramework (High Priority)

**Problem:** Entire UI built on DetailsFramework. If DF updates with breaking changes or user doesn't have it, addon is non-functional.

**Reference:** NorthernSkyRaidTools bundles LibDFramework in `Libs/` directory.

**Recommendation:**
- Bundle DF as embedded library (check license)
- OR add graceful degradation with fallback UI
- OR clearly document DF as hard dependency in TOC

#### 6.2 M33kAuras Integration is Fragile (Medium Priority)

**Location:** `reminders/aurabuilder.lua`

**Problem:** Direct manipulation of `M33kAurasSaved` table. If M33kAuras changes internal structure, this breaks.

**Recommendation:** Add version checks and defensive coding:
```lua
local function GetM33kAurasDB()
    if not M33kAurasSaved or not M33kAurasSaved.displays then
        return nil
    end
    if type(M33kAurasSaved.displays) ~= "table" then
        return nil
    end
    return M33kAurasSaved.displays
end
```

#### 6.3 BigWigs Integration Assumes Module Structure (Medium Priority)

**Location:** `reminders/main.lua`

**Problem:** Assumes BigWigs modules have specific structure (`module.toggleOptions`, `module.optionHeaders`, etc.).

**Recommendation:** Add defensive checks and log warnings when structure doesn't match expectations.

---

## 7. User Experience

### ✅ Strengths

- Good use of color coding for class names
- Clear status messages
- Anchor system for positioning is user-friendly

### ⚠️ Issues

#### 7.1 No Minimap Button (Low Priority)

**Problem:** Users must type `/ap` to access addon.

**Recommendation:** Add LDB integration (see 1.3).

#### 7.2 Reload UI Prompts Are Disruptive (Medium Priority)

**Location:** Multiple places call `AP:ShowReloadDialog()`

**Problem:** Requires UI reload after creating reminders, which is disruptive during raid prep.

**Reference:** Modern addons avoid reload requirements.

**Recommendation:** Investigate if M33kAuras supports dynamic updates without reload. If not, at least batch reload prompts.

#### 7.3 No Import/Export for Settings (Low Priority)

**Problem:** No way to share reminder configurations between characters or with other users.

**Recommendation:** Add import/export functionality for reminder rules.

---

## 8. Testing & Debugging

### ⚠️ Issues

#### 8.1 No Debug Mode (Medium Priority)

**Problem:** No centralized debug logging system.

**Reference (NorthernSkyRaidTools):** Has `NSI:Print()` with debug flag and DevTool integration.

**Recommendation:**
```lua
local debugMode = false

function APRaidUtils:Debug(...)
    if debugMode then
        print("[APDebug]", ...)
    end
end
```

#### 8.2 Error Handling in Comm Callbacks (Medium Priority)

**Location:** `comms.lua:38`

**Problem:** If callback throws error, it's not caught and could break comm handling.

**Recommendation:**
```lua
local success, err = pcall(callbacks[payload.event], payload.event, sender, distribution, data)
if not success then
    self:Print("Error handling comm event " .. payload.event .. ": " .. tostring(err))
end
```

---

## Priority Action Items

### Immediate (Before Next Release)

1. **[Critical]** Fix duplicate `CreateReminderForTimer` function in `ui/main.lua`
2. **[Critical]** Add sender validation in `Comms:OnCommReceived()`
3. **[High]** Reduce `CleanupSimcData()` call frequency
4. **[High]** Split `ui/main.lua` into smaller files

### Short Term (Next 2-4 Weeks)

5. **[High]** Add rate limiting to comm broadcasts
6. **[Medium]** Cache merged anchor settings
7. **[Medium]** Standardize error handling patterns
8. **[Medium]** Add pcall wrappers around comm callbacks
9. **[Medium]** Bundle or clearly document DetailsFramework dependency

### Long Term (Next 1-3 Months)

10. **[Medium]** Add LibDataBroker integration
11. **[Medium]** Investigate reload-free reminder updates
12. **[Low]** Add debug mode
13. **[Low]** Add settings import/export
14. **[Low]** Add minimap button

---

## Comparison with Reference Addons

| Aspect | APRaidUtils | NorthernSkyRaidTools | Notes |
|--------|-------------|---------------------|-------|
| Module Structure | ✅ Good | ✅ Excellent | NSRT has better separation |
| Code Organization | ⚠️ Large files | ✅ Well-split | NSRT UI files are 100-400 lines |
| Comm Security | ⚠️ Basic | ✅ Validated | NSRT has allowedcomms whitelist |
| Performance | ⚠️ Some issues | ✅ Optimized | NSRT uses compression |
| Error Handling | ⚠️ Inconsistent | ✅ Consistent | NSRT has debug system |
| User Experience | ✅ Good | ✅ Good | Both have good UX |
| Dependencies | ⚠️ Heavy DF | ✅ Bundled | NSRT bundles libraries |
| API Usage | ✅ Modern | ✅ Modern | Both use C_* APIs |

---

## Conclusion

APRaidUtils is a solid addon with good architecture choices. The main areas for improvement are:

1. **Performance optimization** - Reduce redundant operations
2. **Security hardening** - Validate incoming comm data
3. **Code organization** - Split large files
4. **Consistency** - Standardize patterns across modules

The addon follows most WoW addon best practices and demonstrates good understanding of the Ace3 ecosystem. With the recommended improvements, it would be on par with high-quality reference addons.
