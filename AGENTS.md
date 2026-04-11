# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-11
**Commit:** `2c2d398`
**Branch:** `main`

## OVERVIEW

APRaidUtils is a World of Warcraft raid utility addon built around a global namespace table, one shared event frame, direct saved variables, and a single DetailsFramework-backed window. First-party code lives outside `libs/`; reminders bridge BigWigs metadata into M33kAuras, while SimC and version features integrate with external addons through exported APIs or AceComm.

## STRUCTURE

```text
APRaidUtils/
|- APRaidUtils.toc          # load order, SavedVariables, release version token
|- main.lua                 # namespace bootstrap, DB init, SimC storage, slash command
|- eventHandler.lua         # central WoW event registration and dispatch
|- comms.lua                # AceComm transport, sender validation, throttling
|- rosterManager.lua        # roster parsing, invite, move helpers
|- leadpass.lua             # Mythic lead-pass reminder and anchor usage
|- settings/                # settings registry DSL and DF renderer
|- simcExport/              # SimulationCraft capture and UI shim
|- reminders/               # BigWigs discovery and M33kAuras sync
|- versionChecker/          # group version request/reply flow
|- ui/                      # main window and anchor editor subsystem
|- .github/workflows/       # tag-driven release automation
`- libs/                    # vendored third-party code; runtime path is libs/libs.xml only
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Startup and load order | `APRaidUtils.toc`, `main.lua`, `eventHandler.lua` | Namespace bootstrap first, then central event dispatch |
| Add or change comm traffic | `comms.lua` plus consumer module | Serialized `{ event, data }`, group validation, 5 messages / 2 seconds |
| Change shared window behavior | `ui/AGENTS.md` | Tab ownership and open/refresh flows are centralized there |
| Change reminder discovery or imports | `reminders/AGENTS.md` | BigWigs metadata in, M33kAuras objects out |
| Change settings surface | `settings/AGENTS.md` | Registry DSL feeds one DetailsFramework renderer |
| Change SimC capture | `simcExport/AGENTS.md` | Command-hook path first, direct exporter fallback |
| Change group version checks | `versionChecker/AGENTS.md` | Query/reply/UI split |
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

## ANTI-PATTERNS (THIS PROJECT)

- Do not reintroduce AceAddon, AceDB, or AceEvent patterns into first-party code.
- Do not register new top-level event frames when `AP.eventFrame` can own the event.
- Do not bypass `AP.Comms` sender validation or throttling with raw addon-message handlers.
- Do not treat `libs/` as project-authored code or document vendor tests/examples as addon behavior.
- Do not create parallel top-level windows for features already hosted in `ui/main.lua`.
- Do not assume every directory under `libs/` loads at runtime; check `libs/libs.xml` first.
- Do not store reminder persistence in `APRaidUtilsDB`; that feature owns records in `M33kAurasSaved.displays`.

## UNIQUE STYLES

- Settings are metadata-driven: registry entries with closures, then one DF renderer flattens them into menu items.
- Reminder rules live in `M33kAurasSaved.displays` with `ap_*` tags, not in `APRaidUtilsDB`.
- SimC automatic capture is event-driven but delayed/coalesced, and manual/automatic capture prefer the Simulationcraft command path first.
- Version checker collects more fields than the UI renders; `MRTNoteHash` and `IgnoredRaiders` stay off-table today.
- Anchor editing is its own subsystem with persisted detached settings-panel position under `APRaidUtilsDB.profile.anchors`.

## COMMANDS

```text
/reload
/ap
git tag vX.Y.Z
git push origin vX.Y.Z
```

## NOTES

- No local build or test runner is defined in this repo; verification is manual in-game.
- No LSP codemap was available during generation, so this file stays source-inspection driven.
- `.github/workflows/bump-release.yml` computes semver tags; `.github/workflows/build-release.yml` packages tagged refs with `BigWigsMods/packager`.
- `libs/` contains retained-but-unloaded Ace directories plus vendor tests/examples; tree size overstates first-party complexity.
- Child knowledge files exist in `ui/`, `reminders/`, `settings/`, `simcExport/`, and `versionChecker/`.
