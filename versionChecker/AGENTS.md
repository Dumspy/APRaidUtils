# OVERVIEW

`versionChecker/` is split by role: `main.lua` bootstraps the namespace, `client.lua` gathers local data and replies, `server.lua` sends requests and collects replies, and `ui.lua` owns ephemeral status plus result rows.

## WHERE TO LOOK

- `GetAllVersions()` in `client.lua` for the collected payload fields.
- `QUERY_VERSION` callback in `client.lua` for reply behavior.
- `RequestVersionCheck()` in `server.lua` for request flow and channel selection.
- `VERSION_INFO` callback in `server.lua` for inbound row updates.
- `ClearUIResults()`, `AppendUIResultRow()`, and `GetVersionRows()` in `ui.lua` for local state ownership.
- `ui/main.lua` for the actual table columns rendered in the Versions tab.

## CONVENTIONS

- `QUERY_VERSION` is a trigger message, not the real data payload.
- `VERSION_INFO` carries `{ response = "VERSION_INFO", versions = <table> }`.
- Collected fields currently include `BigWigs`, `DBM`, `MRT`, `NS`, `MRTNoteHash`, and `IgnoredRaiders`.
- Displayed fields currently include only `name`, `BigWigs`, `DBM`, `MRT`, and `NS`.
- `ClearUIResults()` always seeds the current player's row immediately from local data.
- Rows are keyed by player name; repeated replies replace the existing row's `versions` table.
- `GetVersionRows()` sorts current player first, then case-insensitive by name.
- `RefreshUI()` delegates back to `AP:RefreshVersionsTab()`; widget ownership stays outside this directory.

## ANTI-PATTERNS

- Do not build widgets or define table columns in this directory.
- Do not read addon versions in `server.lua`; collection stays in `client.lua`.
- Do not mutate `uiResults` without keeping `uiResultsByName` in sync.
- Do not assume every collected payload field is visible in the UI.
- Do not remove the self-row seed on clear.
- Do not change row keying or ordering without updating sort, replace, and sender/display-name assumptions together.
