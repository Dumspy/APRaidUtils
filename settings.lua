local AP = LibStub("AceAddon-3.0"):GetAddon("APRaidUtils")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function APRaidUtils:BuildOptionsTable()
    return self.SettingsAceRenderer:BuildOptionsTable()
end

function APRaidUtils:SetupOptions()
    AceConfig:RegisterOptionsTable("APRaidUtils", function()
        return self:BuildOptionsTable()
    end)

    self.optionsFrame, self.optionsCategory = AceConfigDialog:AddToBlizOptions("APRaidUtils", "APRaidUtils")
end

function APRaidUtils:OpenSettings()
    if self.optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.optionsCategory)
        return
    end

    if self.optionsFrame and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
end
