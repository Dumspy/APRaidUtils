# OVERVIEW

`simcExport/main.lua` owns SimulationCraft export capture for the current character; `simcExport/ui.lua` only forwards into shared APRaidUtils UI entry points.

## WHERE TO LOOK

- `GetSimulationcraftAddon()` for addon presence and AceAddon lookup.
- `GetSimulationcraftExporter()` for direct exporter lookup order.
- `CaptureCurrentCharacterViaCommand()` for the command-hook path, timeout, and restore logic.
- `RunAutomaticCapture()` and `ScheduleAutomaticCapture()` for delayed/coalesced capture behavior.
- `ManualCapture()` for the explicit user-triggered flow.
- Root `main.lua` for `AP:IsSimcExportValid()` and `AP:SaveSimcExport()`.
- `simcExport/ui.lua` for the only UI bridge points in this directory.

## CONVENTIONS

- Preferred capture path is Simulationcraft command-hook first, direct exporter fallback second.
- Login/reload auto-capture delay is `5` seconds.
- Equipment, talents, and spec-change auto-capture delay is `2` seconds.
- Rescheduling replaces the previous timer; latest state wins.
- Automatic capture requires a registered, max-level, enabled character.
- Manual capture auto-enables the current character if needed.
- `captureInProgress` gates the command-hook path and prevents overlapping work.
- Wrapped `GetMainFrame` must be restored on success, error, or timeout.
- Persist only through `AP:SaveSimcExport()` so validation stays centralized.

## ANTI-PATTERNS

- Do not call the direct exporter first.
- Do not overlap captures or clear `captureInProgress` outside the local completion path.
- Do not leave `simcAddon.GetMainFrame` wrapped after any exit path.
- Do not save raw export text without `AP:IsSimcExportValid()`.
- Do not add event registrations inside this directory; routing already lives in `eventHandler.lua`.
- Do not treat empty export text and invalid export text as the same failure case.
