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

local function WrapToggleSetter(item)
    return function(_, _, value)
        item.set(value)
    end
end

local function WrapValueSetter(item)
    return function(_, _, value)
        item.set(value)
    end
end

local function BuildMenuItems(framework, items, menuItems)
    for index, item in ipairs(SortItems(items)) do
        if IsSurfaceEnabled(item, "df") then
            if item.type == "group" then
                menuItems[#menuItems + 1] = {
                    type = "label",
                    get = function()
                        return ResolveValue(item.name)
                    end,
                    text_template = framework:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
                    order = item.order or index,
                }

                BuildMenuItems(framework, GetChildren(item), menuItems)
                menuItems[#menuItems + 1] = { type = "blank", order = (item.order or index) + 0.5 }
            elseif item.type == "description" then
                menuItems[#menuItems + 1] = {
                    type = "label",
                    get = function()
                        return ResolveValue(item.text or item.name)
                    end,
                    order = item.order or index,
                    text_template = item.df and item.df.text_template,
                }
            elseif item.type == "execute" then
                menuItems[#menuItems + 1] = {
                    type = "execute",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    order = item.order or index,
                    width = item.df and item.df.width or 180,
                    disableif = item.disabled,
                    func = item.func,
                }
            elseif item.type == "toggle" then
                menuItems[#menuItems + 1] = {
                    type = "toggle",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    order = item.order or index,
                    boxfirst = item.df and item.df.boxfirst,
                    disableif = item.disabled,
                    get = item.get,
                    set = WrapToggleSetter(item),
                }
            elseif item.type == "range" then
                menuItems[#menuItems + 1] = {
                    type = "range",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    order = item.order or index,
                    width = item.df and item.df.width or 180,
                    min = item.min or 0,
                    max = item.max or 100,
                    step = item.step or 1,
                    usedecimals = item.df and item.df.usedecimals,
                    disableif = item.disabled,
                    get = item.get,
                    set = WrapValueSetter(item),
                }
            elseif item.type == "input" then
                menuItems[#menuItems + 1] = {
                    type = "textentry",
                    name = ResolveValue(item.name),
                    desc = ResolveValue(item.desc),
                    order = item.order or index,
                    width = item.df and item.df.width or 140,
                    disableif = item.disabled,
                    get = item.get,
                    set = WrapValueSetter(item),
                }
            end
        end
    end

    return menuItems
end

AP.SettingsDFRenderer = {
    BuildMenu = function(self, parent, framework, layout)
        layout = layout or {}

        local menuItems = {
            use_scrollframe = false,
            always_boxfirst = true,
        }

        BuildMenuItems(framework, AP.SettingsRegistry:GetSections(), menuItems)

        if menuItems[#menuItems] and menuItems[#menuItems].type == "blank" then
            table.remove(menuItems, #menuItems)
        end

        framework:BuildMenuVolatile(
            parent,
            menuItems,
            layout.xOffset or 20,
            layout.yOffset or -40,
            layout.height or parent:GetHeight() - 60,
            false,
            framework:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"),
            framework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"),
            framework:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE"),
            true,
            framework:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE"),
            framework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")
        )
    end,
}
