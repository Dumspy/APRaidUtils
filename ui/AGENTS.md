# OVERVIEW

`ui/main.lua` owns the addon's single main window, all five tabs, and every public open/refresh entry point; `ui/anchor.lua` owns movable text anchors and their settings panels.

## WHERE TO LOOK

- `BuildMainWindow()` for one-time window construction and tab setup.
- `AP:OpenMainWindow(tabName)` and `AP:ToggleMainWindow(tabName)` for all supported open/show flows.
- `AP:RefreshSimcTab()`, `AP:RefreshVersionsTab()`, `AP:RefreshRemindersTab()`, and `AP:RefreshSettingsTab()` for redraw ownership.
- `BuildRemindersTab()` for the heaviest local state machine in the repo.
- `BuildSettingsTab()` for the bridge into `AP.SettingsDFRenderer:BuildMenu()`.
- `AP.APAnchor:CreateAnchor()` and `BuildSettingsPanel()` in `anchor.lua` for anchor creation and editing.
- `AP.APAnchor:RegisterRightClickMenu()` for feature-specific anchor menu extensions.

## CONVENTIONS

- Keep one top-level addon window only; new UI should plug into existing tabs or anchor flows.
- Build widgets once, cache references in file-local variables, then mutate them from refresh functions.
- Tab builders own `parent.RefreshOptions`; if a tab has redraw logic, keep it there or in `AP:Refresh*Tab()`.
- `Settings` is renderer-driven; registry data lives outside `ui/`, and this directory only hosts the tab shell.
- `Reminders` redraw is intentionally centralized in one refresh pass because browser state, editor state, and M33k status interact.
- Anchor persistence belongs in `APRaidUtilsDB.profile.anchors[key]` and should flow through merged defaults plus saved settings.
- Anchor edit visibility flows through `ShowAllAnchors()` and `HideAllAnchors()`, not raw frame `Show()` calls.
- Use existing DetailsFramework templates and helpers before adding bespoke widget styles.

## ANTI-PATTERNS

- Do not rebuild `mainWindow` or tab contents on every open.
- Do not create a second top-level panel for a feature already hosted here.
- Do not mutate tab widgets from other modules without going through the tab's refresh path.
- Do not bypass `settingsTabRefreshBase` in the Settings tab; it preserves renderer-owned refresh behavior.
- Do not split reminder redraw into ad hoc partial mutations unless state ownership is also refactored.
- Do not enter anchor edit mode by calling raw frame `Show()`; use the anchor subsystem APIs.
- Do not persist anchor settings by mutating frame fields only; save then reapply.
