# APRaidUtils Agent Guidelines

## Build/Test Commands
- **No build step required**: Lua/XML files load directly in WoW
- **Testing**: Manual in-game testing only. Reload UI with `/reload` after changes
- **No automated tests**: Test manually in WoW client

## Code Style
- **Imports**: Use `LibStub` for Ace3 libraries. Example: `local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")`
- **Naming**: Prefix all globals with `APRaidUtils` or module-specific names to avoid collisions
- **Module Pattern**: Use AceAddon-3.0 module system: `local MyModule = AP:NewModule("MyModule", "AceConsole-3.0")`
- **No comments**: Do not add comments unless explicitly requested
- **Formatting**: 4-space indentation, local variables before functions, descriptive names
- **Functions**: Use `function ModuleName:MethodName()` for module methods, `function FunctionName()` for standalone

## Architecture
- **Entry Point**: `main.lua` initializes addon, modules in separate files
- **Load Order**: Defined in `APRaidUtils.toc` - update when adding new files
- **Communication**: Use `Comms` module for AceComm-3.0 messaging, register callbacks with `Comms:RegisterCallback(event, func)`
- **Events**: Use AceEvent-3.0 with `self:RegisterEvent("EVENT_NAME", "HandlerMethod")`
- **Never modify**: Files in `libs/` directory (Ace3 libraries)

## Key Files
- `APRaidUtils.toc`: Load order and metadata (update when adding files)
- `main.lua`: Addon initialization
- `comms.lua`: Centralized communication module
- `.github/copilot-instructions.md`: Complete architecture documentation
