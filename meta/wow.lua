---@meta

---@diagnostic disable: lowercase-global

---@class WowClassInfo
---@field classFile string?

---@class WowMapInfo
---@field name string?

---@class WowTimerHandle
---@field Cancel fun(self: WowTimerHandle)

---@class WowAddOnApi
---@field GetAddOnMetadata fun(name: string, field: string): string?
---@field IsAddOnLoaded fun(name: string): boolean

---@class WowTimerApi
---@field After fun(delay: number, callback: fun())
---@field NewTimer fun(delay: number, callback: fun()): WowTimerHandle

---@class WowCreatureInfoApi
---@field GetClassInfo fun(classID: integer): WowClassInfo?

---@class WowSpellApi
---@field GetSpellName fun(spellID: integer): string?
---@field GetSpellTexture fun(spellID: integer): any

---@class WowMapApi
---@field GetMapInfo fun(mapID: integer): WowMapInfo?

---@class WowFriendListApi
---@field IsIgnoredByGuid fun(guid: string): boolean

---@class WowClassTalentsApi
---@field GetActiveConfigID fun(): integer?

---@class WowPartyInfoApi
---@field InviteUnit fun(name: string)

---@type WowAddOnApi
C_AddOns = C_AddOns

---@type WowTimerApi
C_Timer = C_Timer

---@type WowCreatureInfoApi
C_CreatureInfo = C_CreatureInfo

---@type WowSpellApi
C_Spell = C_Spell

---@type WowMapApi
C_Map = C_Map

---@type WowFriendListApi
C_FriendList = C_FriendList

---@type WowClassTalentsApi
C_ClassTalents = C_ClassTalents

---@type WowPartyInfoApi
C_PartyInfo = C_PartyInfo

---@type fun(frameType: string, name?: string, parent?: table, template?: string): table
CreateFrame = CreateFrame

---@type fun(): number
GetTime = GetTime

---@type fun(format: string, value?: number): string
date = date

---@type table
UIParent = UIParent

---@type table
SlashCmdList = SlashCmdList

---@type table<string, table>
StaticPopupDialogs = StaticPopupDialogs

---@type table<string, any>
CUSTOM_CLASS_COLORS = CUSTOM_CLASS_COLORS

---@type table<string, any>
RAID_CLASS_COLORS = RAID_CLASS_COLORS

---@type table<string, string>
LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE

---@type table<string, string>
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_FEMALE

---@type table
bit = bit

---@type any
LibStub = LibStub

---@type any
BigWigs = BigWigs

---@type any
BigWigsAPI = BigWigsAPI

---@type any
BigWigsLoader = BigWigsLoader

---@type any
DBM = DBM

---@type any
VMRT = VMRT

---@type any
SimulationcraftAPI = SimulationcraftAPI

---@type any
DetailsFramework = DetailsFramework

---@type any
GameRulesUtil = GameRulesUtil

---@type any
Enum = Enum

---@type any
Constants = Constants
