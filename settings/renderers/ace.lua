local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")

local function ResolveValue(value)
    if type(value) == "function" then
        return value()
    end

    return value
end

local function GetChildren(item)
    local items = item.items
    if type(items) == "function" then
        return items()
    end

    return items or {}
end

local function IsSurfaceEnabled(item, surface)
    local surfaces = item.surfaces
    if not surfaces then
        return true
    end

    local enabled = surfaces[surface]
    if enabled == nil then
        return true
    end

    return enabled
end

local function SortItems(items)
    table.sort(items, function(left, right)
        return (left.order or 0) < (right.order or 0)
    end)
    return items
end

local function BuildArgs(items)
    local args = {}

    for index, item in ipairs(SortItems(items)) do
        if IsSurfaceEnabled(item, "ace") then
            local key = item.id or ("item" .. index)
            if item.type == "group" then
                args[key] = {
                    type = "group",
                    name = ResolveValue(item.name),
                    order = item.order or index,
                    inline = item.inline == true,
                    args = BuildArgs(GetChildren(item)),
                }
            elseif item.type == "description" then
                args[key] = {
                    type = "description",
                    name = ResolveValue(item.text or item.name),
                    order = item.order or index,
                    fontSize = item.ace and item.ace.fontSize,
                }
            elseif item.type == "execute" then
                args[key] = {
                    type = "execute",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    order = item.order or index,
                    disabled = item.disabled,
                    func = item.func,
                }
            elseif item.type == "toggle" then
                args[key] = {
                    type = "toggle",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    width = item.ace and item.ace.width,
                    order = item.order or index,
                    disabled = item.disabled,
                    get = function()
                        return item.get()
                    end,
                    set = function(_, value)
                        item.set(value)
                    end,
                }
            elseif item.type == "range" then
                args[key] = {
                    type = "range",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    width = item.ace and item.ace.width,
                    min = item.min or 0,
                    max = item.max or 100,
                    step = item.step or 1,
                    order = item.order or index,
                    disabled = item.disabled,
                    get = function()
                        return item.get()
                    end,
                    set = function(_, value)
                        item.set(value)
                    end,
                }
            elseif item.type == "input" then
                args[key] = {
                    type = "input",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    width = item.ace and item.ace.width,
                    order = item.order or index,
                    disabled = item.disabled,
                    get = function()
                        return tostring(item.get() or "")
                    end,
                    set = function(_, value)
                        item.set(value)
                    end,
                }
            end
        end
    end

    return args
end

AP.SettingsAceRenderer = {
    BuildOptionsTable = function(self)
        return {
            type = "group",
            name = "APRaidUtils",
            childGroups = "tree",
            args = BuildArgs(AP.SettingsRegistry:GetSections()),
        }
    end,
}
