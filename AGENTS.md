# PROJECT KNOWLEDGE BASE

**Single source of truth for APRaidUtils.** This file covers the whole repo — the
`ui/`, `settings/`, and `versionChecker/` subsystems are documented here, not in
their own files.

## OVERVIEW

APRaidUtils is a World of Warcraft raid utility addon built around a global namespace table, one shared event frame, direct saved variables, and a single DetailsFramework-backed window. First-party code lives outside `libs/`; version features integrate with external addons through exported APIs or AceComm.

## PRINCIPLES (HARD RULES)

These rules govern every change; violations are rejected. Base any review on the rules below.

**1. Zero cost unless enabled.** A user who never enables a feature pays nothing: no event/message/comm registrations, no hooks doing work, no frames created, no `OnUpdate`, no background timers. Build lazily on first enable and tear down on disable. Repo mechanism: features declare their events in `featureEvents` (`eventHandler.lua`) and toggle them via `AP:EnableFeatureEvents("name")` / `AP:DisableFeatureEvents("name")`. Each feature exposes `Enable()`, `Disable()`, and `Restore()`; `main.lua` calls `Restore()` on login so previously-enabled features rebuild while off ones stay dormant. Anchor frames are created in `Enable()`, never at load.

**2. Zero behavior change without opt-in.** New settings default OFF; a feature that appears for everyone after an update is a violation. Only genuine bug fixes may change behavior without opt-in.

**3. Low cost when enabled.** Event-driven, never `OnUpdate` polling; no wall-clock timers as logic gates; no per-frame table allocations in hot paths; small loops with early guards.

**4. Zero taint risk.** Any change that can cause a Lua error is rejected: no forced/secure API, no reparenting or hooking Blizzard-owned frames, error containment around protected calls. **Chat reskinning PRs are flatly rejected** (unacceptable taint).

**5. One client, current only.** Target the current retail client: no version gates or compatibility branches for older builds, no references to removed/replaced APIs or CVars, no dead compat shims.

## STRUCTURE

```text
APRaidUtils/
|- APRaidUtils.toc          # load order, SavedVariables, release version token
|- main.lua                 # namespace bootstrap, DB init, slash command
|- eventHandler.lua         # central WoW event registration + feature event gating
|- comms.lua                # AceComm transport, sender validation, throttling
|- rosterManager.lua        # roster parsing, invite, move helpers
|- leadpass.lua             # Mythic lead-pass reminder (lazy opt-in feature)
|- breaktimer.lua           # break timer anchor (lazy opt-in feature)
|- sszorak.lua              # Sszorak caller helper octagon (lazy opt-in feature)
|- settings/                # settings registry DSL + DF renderer
|- versionChecker/          # group version request/reply flow
|- ui/                      # main window, tabs, and anchor editor subsystem
|- .github/workflows/       # tag-driven release automation
`- libs/                    # vendored third-party code; runtime path is libs/libs.xml only
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Startup and load order | `APRaidUtils.toc`, `main.lua`, `eventHandler.lua` | Namespace bootstrap first, then central event dispatch |
| Add or change comm traffic | `comms.lua` plus consumer module | Serialized `{ event, data }`, group validation, 5 messages / 2 seconds |
| Gate a feature's events on/off | `eventHandler.lua` | `featureEvents` map + `AP:EnableFeatureEvents()` / `AP:DisableFeatureEvents()` |
| Change shared window / tabs / anchors | `ui/main.lua`, `ui/anchor.lua` | See UI guide below |
| Change settings surface | `settings/registry.lua`, `settings/renderers/df.lua` | See Settings guide below |
| Change group version checks | `versionChecker/` modules | See Version checker guide below |
| Touch release flow | `.github/workflows/` | `bump-release.yml` creates tags, `build-release.yml` packages them |
| Verify loaded vendor code | `libs/libs.xml` | Not every folder under `libs/` is on the runtime path |

## CONVENTIONS

- All first-party files use `local AP = _G["APRaidUtils"]`.
- Root addon pattern is namespace-based; no AceAddon root object, no `AP:NewModule()`.
- WoW events register on `AP.eventFrame`; `eventHandler.lua` is the shared dispatcher.
- Saved state is direct `APRaidUtilsDB.global` and `APRaidUtilsDB.profile`; defaults initialize in `AP:OnAddonLoaded()`.
- Cross-player traffic goes through `AP.Comms`; sender must be in raid or party before callbacks run.
- Feature `ui.lua` files are thin facades into `ui/main.lua`; heavy widget ownership stays under `ui/`.
- Runtime-loaded third-party code is whatever `libs/libs.xml` includes, not every directory under `libs/`.
- Features are opt-in (default off) and follow the Enable/Disable/Restore + feature-events lifecycle (see PRINCIPLES).

## ANTI-PATTERNS (THIS PROJECT)

- Do not reintroduce AceAddon, AceDB, or AceEvent patterns into first-party code.
- Do not register new top-level event frames when `AP.eventFrame` can own the event.
- Do not bypass `AP.Comms` sender validation or throttling with raw addon-message handlers.
- Do not treat `libs/` as project-authored code or document vendor tests/examples as addon behavior.
- Do not create parallel top-level windows for features already hosted in `ui/main.lua`.
- Do not assume every directory under `libs/` loads at runtime; check `libs/libs.xml` first.
- Do not register events, register messages, or create frames at load for an opt-in feature (PRINCIPLE 1).

## SUBSYSTEM GUIDES

### UI (`ui/`)

`ui/main.lua` owns the addon's single main window, its tabs (Roster, Versions, Settings), and every public open/refresh entry point; `ui/anchor.lua` owns movable text anchors and their settings panels.

**Where to look**
- `BuildMainWindow()` for one-time window construction and tab setup.
- `AP:OpenMainWindow(tabName)` and `AP:ToggleMainWindow(tabName)` for all supported open/show flows.
- `AP:RefreshVersionsTab()` and `AP:RefreshSettingsTab()` for redraw ownership.
- `BuildSettingsTab()` for the bridge into `AP.SettingsDFRenderer:BuildMenu()`.
- `AP.APAnchor:CreateAnchor()` and `BuildSettingsPanel()` in `anchor.lua` for anchor creation and editing.
- `AP.APAnchor:RegisterRightClickMenu()` for feature-specific anchor menu extensions.

**Conventions**
- Keep one top-level addon window only; new UI should plug into existing tabs or anchor flows.
- Build widgets once, cache references in file-local variables, then mutate them from refresh functions.
- Tab builders own `parent.RefreshOptions`; if a tab has redraw logic, keep it there or in `AP:Refresh*Tab()`.
- `Settings` is renderer-driven; registry data lives outside `ui/`, and this directory only hosts the tab shell.
- Anchor persistence belongs in `APRaidUtilsDB.profile.anchors[key]` and should flow through merged defaults plus saved settings.
- Anchor edit visibility flows through `ShowAllAnchors()` and `HideAllAnchors()`, not raw frame `Show()` calls.
- Use existing DetailsFramework templates and helpers before adding bespoke widget styles.

**Anti-patterns**
- Do not rebuild `mainWindow` or tab contents on every open.
- Do not create a second top-level panel for a feature already hosted here.
- Do not mutate tab widgets from other modules without going through the tab's refresh path.
- Do not bypass `settingsTabRefreshBase` in the Settings tab; it preserves renderer-owned refresh behavior.
- Do not enter anchor edit mode by calling raw frame `Show()`; use the anchor subsystem APIs.
- Do not persist anchor settings by mutating frame fields only; save then reapply.

### Settings (`settings/`)

`settings/registry.lua` defines a small declarative settings DSL; `settings/renderers/df.lua` is the only shipped renderer and translates that DSL into DetailsFramework menu items.

**Where to look**
- `GetSections()` for the full registry surface.
- `ResolveValue()`, `GetChildren()`, and `IsSurfaceEnabled()` in `renderers/df.lua` for registry evaluation.
- `BuildMenuItems()` for DSL-to-widget translation.
- `AP.SettingsDFRenderer:BuildMenu()` for the final DetailsFramework build entry point.

**Conventions**
- Registry item shape is the contract: `id`, `type`, `order`, then type-specific fields.
- Dynamic `name`, `text`, `desc`, and `items` are zero-argument functions.
- `items` may be a static array or a function returning an array.
- `surfaces` is visibility gating, not styling metadata.
- `item.df` is for renderer-specific layout only: width, templates, checkbox ordering, decimal hints.
- Renderer code forwards `get`, `set`, and `func`; it should not own business logic.
- Group items flatten into labels plus child items in DF; nesting is logical, not separate frame ownership.
- Missing business state should be computed in registry helpers or feature modules, then rendered here.
- New feature toggles must default OFF and gate on the feature lifecycle (PRINCIPLE 2).

**Anti-patterns**
- Do not put feature logic in `renderers/df.lua`.
- Do not query addon state directly from the renderer when the registry can expose a closure.
- Do not hide business rules under `item.df`.
- Do not mutate registry data in place beyond read-only translation work.
- Do not add second-renderer plumbing here unless a second renderer actually ships.
- Do not pass framework objects into registry callbacks.

### Version checker (`versionChecker/`)

`versionChecker/` is split by role: `main.lua` bootstraps the namespace, `client.lua` gathers local data and replies, `server.lua` sends requests and collects replies, and `ui.lua` owns ephemeral status plus result rows.

**Where to look**
- `GetAllVersions()` in `client.lua` for the collected payload fields.
- `QUERY_VERSION` callback in `client.lua` for reply behavior.
- `RequestVersionCheck()` in `server.lua` for request flow and channel selection.
- `VERSION_INFO` callback in `server.lua` for inbound row updates.
- `ClearUIResults()`, `AppendUIResultRow()`, and `GetVersionRows()` in `ui.lua` for local state ownership.
- `ui/main.lua` for the actual table columns rendered in the Versions tab.

**Conventions**
- `QUERY_VERSION` is a trigger message, not the real data payload.
- `VERSION_INFO` carries `{ response = "VERSION_INFO", versions = <table> }`.
- Collected fields currently include `BigWigs`, `DBM`, `MRT`, `NS`, `MRTNoteHash`, and `IgnoredRaiders`.
- Displayed fields currently include only `name`, `BigWigs`, `DBM`, `MRT`, and `NS`.
- `ClearUIResults()` always seeds the current player's row immediately from local data.
- Rows are keyed by player name; repeated replies replace the existing row's `versions` table.
- `GetVersionRows()` sorts current player first, then case-insensitive by name.
- `RefreshUI()` delegates back to `AP:RefreshVersionsTab()`; widget ownership stays outside this directory.

**Anti-patterns**
- Do not build widgets or define table columns in this directory.
- Do not read addon versions in `server.lua`; collection stays in `client.lua`.
- Do not mutate `uiResults` without keeping `uiResultsByName` in sync.
- Do not assume every collected payload field is visible in the UI.
- Do not remove the self-row seed on clear.
- Do not change row keying or ordering without updating sort, replace, and sender/display-name assumptions together.

## UNIQUE STYLES

- Settings are metadata-driven: registry entries with closures, then one DF renderer flattens them into menu items.
- Version checker collects more fields than the UI renders; `MRTNoteHash` and `IgnoredRaiders` stay off-table today.
- Anchor editing is its own subsystem with persisted detached settings-panel position under `APRaidUtilsDB.profile.anchors`.

## TOOLING

This repo uses repo-owned Lua tooling for consistent editor/AI support.

| File | Purpose |
|------|---------|
| `flake.nix` | Nix dev shell definition |
| `.luarc.json` | LuaLS configuration (editor-agnostic) |
| `.stylua.toml` | Code formatting |
| `.luacheckrc` | Linting with WoW globals |
| `meta/` | Project and WoW API annotations |

**Tools in shell:** `lua-language-server`, `lua5.1`, `luacheck`, `stylua`

**Exclude from lint:** `libs/**` (vendored code)

## NOTES

- No local build or test runner is defined in this repo; verification is manual in-game.
- `.github/workflows/bump-release.yml` computes semver tags; `.github/workflows/build-release.yml` packages tagged refs with `BigWigsMods/packager`.
- `libs/` contains retained-but-unloaded Ace directories plus vendor tests/examples; tree size overstates first-party complexity.
- This single AGENTS.md is the source of truth; there are no child knowledge files.
