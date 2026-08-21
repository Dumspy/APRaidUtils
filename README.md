# APRaidUtils Tooling

This repo now uses repo-owned Lua tooling config so editors and AI agents can share the same setup.

## Quick Start

1. Enter the shell with `nix develop`.
2. If you use `direnv`, run `direnv allow` once.
3. Point your editor's LuaLS client at this repo root.

`.luarc.json` is the source of truth for LuaLS settings.

## Included Tools

- `lua-language-server` for LSP support
- `lua5.1` and `luac` for syntax checks
- `stylua` for formatting
- `luacheck` for linting

## Common Commands

- `lua-language-server --version`
- `stylua main.lua eventHandler.lua comms.lua rosterManager.lua leadpass.lua settings versionChecker ui`
- `luacheck main.lua eventHandler.lua comms.lua rosterManager.lua leadpass.lua settings versionChecker ui`
- `find . -name '*.lua' -not -path './libs/*' -not -path './.lua-libs/*' -print0 | xargs -0 -n1 luac -p`

## LuaLS Notes

- `.luarc.json` targets `Lua 5.1`.
- WoW API annotations are auto-fetched by `nix develop` into `.lua-libs/wow-api`.
- Project stubs live in `meta/`.
- Vendored code under `libs/` is ignored by LuaLS and `luacheck`.
