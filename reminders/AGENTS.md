# OVERVIEW

`reminders/` turns BigWigs raid metadata into deterministic reminder definitions, then maps saved rules into M33kAuras displays; `ui.lua` is only a facade into the shared APRaidUtils window.

## WHERE TO LOOK

- `EnsureRaidMetadataLoaded()` and `RebuildDefinitionsForRaid()` for the discovery pipeline.
- `BuildDefinitionFromOption()` and `GetBigWigsOptionDetails()` for timer-option extraction.
- `GetDefinitionId()` for stable identity rules.
- `GetDefinitionPhaseOptions()` and `SaveRule()` for phase-filter normalization and persistence behavior.
- `CreateDefaultTemplate()`, `ImportOrUpdate()`, `RemoveByRuleId()`, and `RebuildGroups()` in `aurabuilder.lua` for M33kAuras integration.
- `Reminders:RefreshUI()` and `Reminders:ShowUI()` in `ui.lua` for the only public UI bridge points in this directory.

## CONVENTIONS

- Source of truth for timer discovery is BigWigs metadata, not observed running bars or combat events.
- Definition IDs must stay deterministic across reloads and discovery order.
- Canonical phase tokens are `stage:N`, `intermission:N`, and `intermission:any`.
- Rule phase filters should be deduped and sorted before save.
- APRaidUtils reminder persistence lives in `M33kAurasSaved.displays`, tagged with `ap_*` fields such as `ap_source`, `ap_rule_id`, and `ap_definition_id`.
- Framework object IDs are fixed: template `APRaidUtils_Template`, root group `APReminders`.
- Generated M33kAuras hierarchy is root group -> raid group -> boss group -> aura.
- `ui.lua` should stay thin; shared window behavior belongs on `AP` under `ui/main.lua`.

## ANTI-PATTERNS

- Do not key reminder identity by localized labels, display order, or list position.
- Do not store reminder persistence in `APRaidUtilsDB`.
- Do not treat a generic `Intermission` label as `intermission:1`; use `intermission:any`.
- Do not build definitions from active bars or encounter runtime state when metadata is available.
- Do not add APRaidUtils-owned M33kAuras fields without the `ap_` prefix.
- Do not generate new template or root-group IDs; existing integration points are fixed.
- Do not move real UI logic into `reminders/ui.lua`.
