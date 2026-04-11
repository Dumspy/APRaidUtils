---@meta

---@diagnostic disable: lowercase-global

---@class APRaidUtilsCharacter
---@field key string
---@field name string
---@field realm string?
---@field classFile string?
---@field className string?
---@field level integer?
---@field specName string?
---@field isMaxLevel boolean?

---@class APRaidUtilsSavedVariables
---@field global table
---@field profile table

---@type APRaidUtilsSavedVariables
APRaidUtilsDB = APRaidUtilsDB

---@class APRaidUtilsNamespace
local APRaidUtils = {}

---@type APRaidUtilsNamespace
_G["APRaidUtils"] = _G["APRaidUtils"] or APRaidUtils

---@type APRaidUtilsNamespace
_G["AP"] = _G["AP"] or APRaidUtils

---@type table<string, string>
M33kAurasSaved = M33kAurasSaved

---@type string
SLASH_APRAIDUTILS1 = SLASH_APRAIDUTILS1
