# OVERVIEW

`settings/registry.lua` defines a small declarative settings DSL; `settings/renderers/df.lua` is the only shipped renderer and translates that DSL into DetailsFramework menu items.

## WHERE TO LOOK

- `GetSections()` for the full registry surface.
- `BuildCharacterItems()` for dynamic `items = function() ... end` expansion.
- `GetCurrentCharacterText()` and `GetM33kAurasStatusText()` for dynamic description text.
- `ResolveValue()`, `GetChildren()`, and `IsSurfaceEnabled()` in `renderers/df.lua` for registry evaluation.
- `BuildMenuItems()` for DSL-to-widget translation.
- `AP.SettingsDFRenderer:BuildMenu()` for the final DetailsFramework build entry point.

## CONVENTIONS

- Registry item shape is the contract: `id`, `type`, `order`, then type-specific fields.
- Dynamic `name`, `text`, `desc`, and `items` are zero-argument functions.
- `items` may be a static array or a function returning an array.
- `surfaces` is visibility gating, not styling metadata.
- `item.df` is for renderer-specific layout only: width, templates, checkbox ordering, decimal hints.
- Renderer code forwards `get`, `set`, and `func`; it should not own business logic.
- Group items flatten into labels plus child items in DF; nesting is logical, not separate frame ownership.
- Missing business state should be computed in registry helpers or feature modules, then rendered here.

## ANTI-PATTERNS

- Do not put feature logic in `renderers/df.lua`.
- Do not query addon state directly from the renderer when the registry can expose a closure.
- Do not hide business rules under `item.df`.
- Do not mutate registry data in place beyond read-only translation work.
- Do not add second-renderer plumbing here unless a second renderer actually ships.
- Do not pass framework objects into registry callbacks.
