# APRaidUtils Development Guide

## Architecture

- **Pattern**: Namespace-based, no AceAddon dependency
- **Events**: Frame-based event system
- **Storage**: Direct saved variables
- **UI**: LibDFramework-1.0 (bundled)

## Key Patterns

### Event Handling
- All events registered on central `AP.eventFrame`
- Single `AP:HandleEvent(event, ...)` dispatcher

### Module Pattern
- Direct table assignment: `AP.ModuleName = {}`
- No `AP:NewModule()` calls

### Communication
- Use AceComm-3.0 for cross-addon messaging
- Always validate sender is in group
- Rate limit broadcasts (5 msg/2sec max)

### Saved Variables
- Access via `APRaidUtilsDB.global`, `APRaidUtilsDB.profile`
- Initialize defaults in ADDON_LOADED handler

## Code Style

- 4-space indentation, no tabs
- Local variables before functions
- Use `local AP = _G["APRaidUtils"]` in all files
- No comments unless API docs needed

## Testing

- `/reload` after changes
- Test in raid environment for comms
- Verify saved variable migration

## Resources

### Libraries (Bundled)
- **LibDFramework-1.0**: `libs/LibDFramework-1.0/` - UI framework
- **AceComm-3.0**: `libs/AceComm-3.0/` - Addon communication
- **AceSerializer-3.0**: `libs/AceSerializer-3.0/` - Data serialization
- **LibSharedMedia-3.0**: `libs/LibSharedMedia-3.0/` - Font/media access
- **LibStub**: `libs/LibStub/` - Library loader
- **CallbackHandler-1.0**: `libs/CallbackHandler-1.0/` - Callback system

### Reference Addons
- **NorthernSkyRaidTools**: https://github.com/Reloe/NorthernSkyRaidTools - Modern raid tools architecture
- **Details! Damage Meter**: https://github.com/Detailsfw/Performance - Combat logging
- **BigWigs**: https://github.com/BigWigsMods/BigWigs - Boss mod architecture

### WoW API
- **WoW Wiki API**: https://wowpedia.fandom.com/wiki/API
- **FrameXML Reference**: https://wowpedia.fandom.com/wiki/Patch_12.0.0/API_changes

### Libraries (External)
- **Ace3**: https://www.wowace.com/projects/ace3 - Reference for library patterns
- **LibStub**: https://github.com/kwikky/LibStub - Library loader spec
- **ChatThrottleLib**: https://github.com/Elv22/ChatThrottleLib - Message rate limiting

## License Notes

- LibSharedMedia-3.0: LGPL v2.1
- Ace libraries: BSD-style (free to use)
- LibDFramework: Bundled with Details!, check license for derivative use
