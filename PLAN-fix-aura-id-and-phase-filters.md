# Fix Plan: Aura ID Uniqueness + Phase Filter Trigger Integration

## Problem 1 (P1): Aura ID Collision Breaks Multiple Reminders

**Root cause:** `aurabuilder.lua:496-504` generates `aura.id` from spell/option metadata only:
```lua
baseName = MakeSafeId(spellName) .. "-" .. tostring(spellId)
-- or
baseName = MakeSafeId(optName) .. "-opt"
aura.id = baseName
```

Two reminders for the same timer produce identical `aura.id` values. In `ImportOrUpdate` (line 617), `db[aura.id]` finds the first reminder and treats it as "existing", causing the second reminder to overwrite the first. The fallback search by `ap_rule_id` (lines 618-637) only activates when `db[aura.id]` is nil — which won't happen when reminders share the same spell.

M33kAuras uses `uid` as its internal unique identifier, but `id` is the DB key in `db.displays`. Two auras cannot share the same `id` — the second `M33kAuras.Add()` call overwrites the first.

**Fix:** Incorporate `rule.ruleId` into the aura ID.

### Changes to `reminders/aurabuilder.lua`

**Lines 496-504** — append `ruleId` to the generated aura ID:

```lua
-- Before:
aura.id = baseName

-- After:
aura.id = baseName .. "-" .. (rule.ruleId or "unknown")
```

This ensures every reminder rule gets a unique `aura.id` in the M33kAuras DB, even when multiple reminders target the same timer.

**Migration behavior:** Existing reminders already have colliding IDs. The fallback search in `ImportOrUpdate` (lines 618-637) will find them by `ap_rule_id`, delete the old entry, and create a new one with the unique ID. This is safe — the old aura is removed from its parent group and deleted before the new one is added.

---

## Problem 2 (P2): Phase Filters Ignored in Trigger Building

**Root cause:** `aurabuilder.lua:524-534` collects stage numbers from `definition.phaseStageValues` and `definition.observedStageValues` (BigWigs metadata showing ALL phases a timer appears in). The user's `rule.phaseFilters` selection is only stored as metadata at line 520 (`aura.ap_phase_filters`) and never used in trigger building.

This means if a timer fires in stages 1, 2, and 3, but the user only wants reminders for stage 2, the trigger still fires for all three stages.

**Fix:** Use `rule.phaseFilters` tokens to build stage triggers instead of definition metadata.

### Changes to `reminders/aurabuilder.lua`

**Lines 524-534** — replace definition-based stage collection with user-selected phase filters:

```lua
-- Before:
local stageNumbers = {}
for _, stageValue in ipairs(definition.phaseStageValues or {}) do
    if stageValue <= 5.5 then
        stageNumbers[stageValue] = true
    end
end
for _, stageValue in ipairs(definition.observedStageValues or {}) do
    if stageValue <= 5.5 and not stageNumbers[stageValue] then
        stageNumbers[stageValue] = true
    end
end

-- After:
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
```

**Behavior:**
- Empty `phaseFilters` (user selected "All phases") → no stage triggers added, reminder fires whenever the timer fires regardless of stage (preserves current "all phases" behavior)
- Specific phase selections → stage triggers built only for selected phases, reminder fires only when timer triggers AND encounter is in a selected phase
- `intermission:any` token → expands to all intermission stages (1.5 through 5.5)

---

## Files Modified

| File | Changes |
|---|---|
| `reminders/aurabuilder.lua` | Line 504: append `ruleId` to `aura.id` |
| `reminders/aurabuilder.lua` | Lines 524-534: use `rule.phaseFilters` for stage trigger building |

## Risk Assessment

**P1 Fix — Low risk:**
- Existing reminders will be migrated automatically via the `ap_rule_id` fallback on next save
- No TOC or load order changes needed
- M33kAuras handles the ID change gracefully (deletes old, creates new)

**P2 Fix — Low risk:**
- Existing reminders with no `phaseFilters` set will continue to fire in all phases (no stage triggers added)
- Only affects reminders where the user explicitly selected phase filters — these will now work as intended
- The `PhaseTokenToStageNumber` helper already exists and is tested

## Testing Plan

1. Create two reminders for the same timer → verify both appear in M33kAuras with unique IDs
2. Create reminder with phase filter "stage:2" only → verify trigger only fires in stage 2
3. Create reminder with "All phases" selected → verify trigger fires in any stage
4. Save an existing reminder (migration test) → verify old ID is cleaned up and new unique ID is created
