# Copilot Instructions for APRaidUtils

## Project Overview
APRaidUtils is a World of Warcraft addon designed to provide raid utility features. The codebase is structured for modularity and extensibility, leveraging the Ace3 library suite for common addon patterns (event handling, configuration, communication, UI, etc.).

## Architecture & Key Components
- **Main Addon Logic**: `main.lua` is the entry point, initializing the addon and loading modules.
- **Version Checking**: The `APVersionChecker` and `versionChecker` directories contain logic for client/server version checks, supporting cross-addon communication.
- **Libraries**: The `libs/` directory contains Ace3 libraries and their widgets. These are loaded via XML files and used throughout the addon for common tasks.
- **TOC File**: `APRaidUtils.toc` defines the load order and entry points for the addon in WoW.

## Developer Workflows
- **No build step required**: Lua and XML files are loaded directly by WoW. Place new files in the appropriate directory and update the `.toc` file as needed.
- **Testing**: Testing is manual, performed in-game. Reload the UI with `/reload` after making changes.
- **Debugging**: Use WoW's built-in `/dump` command or print statements. Ace3's debug tools (if enabled) can assist.

## Project-Specific Conventions
- **Module Pattern**: Each major feature is a separate Lua file or directory. Modules are registered with AceAddon-3.0 and communicate via AceEvent-3.0 and AceComm-3.0.
- **Configuration**: Use AceConfig-3.0 for options dialogs. See `libs/AceConfig-3.0/` and related widgets for examples.
- **Communication**: Cross-client communication uses AceComm-3.0, with message handlers defined in version checker modules.
- **XML Loading**: All libraries and widgets are loaded via XML files referenced in the `.toc` and `libs/libs.xml`.
- **Naming**: Prefix global symbols with `APRaidUtils` or `APVersionChecker` to avoid collisions.

## Integration Points
- **Ace3 Libraries**: All core functionality (events, config, comms, UI) is built on Ace3. See `libs/` for available modules.
- **WoW API**: Direct calls to WoW's Lua API are used for UI, events, and communication.

## Examples
- Registering a module: `local MyModule = APRaidUtils:NewModule("MyModule")`
- Sending a message: `APRaidUtils:SendCommMessage("Prefix", "data", "RAID")`
- Adding config options: See AceConfig-3.0 usage in `libs/AceConfig-3.0/`

## Key Files & Directories
- `main.lua`, `APRaidUtils.toc`: Addon entry points
- `APVersionChecker/`, `versionChecker/`: Version check logic
- `libs/`: Ace3 libraries and widgets should never be changed

---

**If you add new modules or features, follow the module pattern and update the `.toc` file.**

For questions or unclear conventions, ask for clarification or review existing modules for examples.
