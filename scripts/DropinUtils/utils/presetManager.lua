---@diagnostic disable: undefined-global, undefined-field, missing-fields
---@omw-context menu|player|global
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
-- ============================================================================
-- Standalone, single-file OpenMW module for settings presets.
--
-- Copy it anywhere in your mod (e.g. scripts/MyMod/SettingsPresets.lua) and
-- require it from a GLOBAL, PLAYER or MENU script. Each script uses it for
-- its own scope only:
--
--   * PLAYER / MENU script -> works with player sections (isGlobal = false)
--   * GLOBAL script        -> works with global sections (isGlobal = true)
--
-- Global scripts cannot read player sections, and only global scripts can
-- write global sections, so a mixed preset is not supported. To control both
-- kinds of sections, keep a separate selector + registration in each scope.
--
-- The selector (the setting the player picks the preset with) must live in a
-- different section than the values it controls, in the same scope as them.
--
-- USAGE:
--   local SettingsPresets = require('scripts.MyMod.utils.presetManager')
--
--   local presets = SettingsPresets.register {
--       -- The setting that chooses the preset. Its value is a preset name.
--       selector = {
--           section  = 'SettingsMyModPresets',
--           key      = 'preset',
--           isGlobal = false,           -- default: false
--       },
--
--       -- Every section used by presets must be declared here.
--       -- isGlobal defaults to false.
--       sections = {
--           SettingsMyModGraphics = { isGlobal = false },
--           SettingsMyModHud      = { isGlobal = false },
--       },
--
--       -- presetName -> sectionKey -> { settingKey = value }
--       -- Presets may be partial: only listed keys are written.
--       presets = {
--           Low = {
--               SettingsMyModGraphics = { drawDistance = 1, shadows = false },
--               SettingsMyModHud      = { scale = 0.8 },
--           },
--           High = {
--               SettingsMyModGraphics = { drawDistance = 3, shadows = true },
--           },
--       },
--   }
--
--   presets.apply('Low')        -- apply explicitly
--   presets.applyCurrent()      -- apply whatever the selector currently holds
--   presets.getCurrent()        -- current selector value (may be nil)
--   presets.names()             -- sorted list of preset names
--
-- BEHAVIOR:
--   * Changing the selector value applies the matching preset automatically.
--     A selector value that matches no preset (e.g. "Custom") is ignored.
--   * Manual edits of controlled settings never change the selector.
--   * Nothing is applied on load; only selector changes / apply() do it.
--   * Writes are idempotent: a value is only set if it differs.
--   * Registration raises an error if any section (or the selector) does not
--     match the scope of the current script, e.g. a global section
--     registered from a player or menu script.
--   * Do not register the same selector twice within one script scope, or
--     the preset will be applied twice (harmless, but wasteful).
-- ============================================================================

local storage = require('openmw.storage')
local async = require('openmw.async')

---------------------------------------------------------------------------
-- Scope detection
---------------------------------------------------------------------------

---@alias SettingsPresetsScope 'global'|'menu'|'player'

---@return SettingsPresetsScope
local function detectScope()
    if pcall(require, 'openmw.world') then
        return 'global'
    end
    if pcall(require, 'openmw.menu') then
        return 'menu'
    end
    local ok, self = pcall(require, 'openmw.self')
    if ok then
        local types = require('openmw.types')
        if types.Player.objectIsInstance(self.object) then
            return 'player'
        end
    end
    error('SettingsPresets: can only be used from a global, player or menu script', 3)
end

---@type SettingsPresetsScope
local SCOPE = detectScope()
local IS_GLOBAL_SCOPE = SCOPE == 'global'

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

---@param name string
---@param isGlobal boolean
---@return openmw.storage.StorageSection
local function getSection(name, isGlobal)
    if isGlobal then
        return storage.globalSection(name)
    end
    return storage.playerSection(name)
end

---@param a any
---@param b any
---@return boolean
local function deepEqual(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return a == b
    end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

---@param what string
---@param name string
---@param isGlobal boolean
local function checkScope(what, name, isGlobal)
    if isGlobal and not IS_GLOBAL_SCOPE then
        error(string.format(
            "SettingsPresets: %s '%s' is a global section, but this is a %s script. " ..
            "Global sections can only be handled from a global script.",
            what, name, SCOPE), 3)
    elseif not isGlobal and IS_GLOBAL_SCOPE then
        error(string.format(
            "SettingsPresets: %s '%s' is a player section (isGlobal = false), but this is a " ..
            "global script. Global scripts cannot access player sections.",
            what, name), 3)
    end
end

---@param value any
---@param expected type
---@param path string
local function expectType(value, expected, path)
    if type(value) ~= expected then
        error(string.format('SettingsPresets: %s must be a %s, got %s',
            path, expected, type(value)), 3)
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

---@class SettingsPresetsSelector
---@field section string           Storage section the selector setting lives in
---@field key string                Setting key within that section
---@field isGlobal? boolean         Default: false

---@class SettingsPresetsSectionInfo
---@field isGlobal? boolean         Default: false

---@alias SettingsPresetsSectionValues table<string, any>              -- settingKey -> value
---@alias SettingsPresetsPreset table<string, SettingsPresetsSectionValues> -- sectionName -> values

---@class SettingsPresetsConfig
---@field selector SettingsPresetsSelector
---@field sections table<string, SettingsPresetsSectionInfo>
---@field presets table<string, SettingsPresetsPreset>                 -- presetName -> preset

---@class SettingsPresetsAPI
---@field apply fun(presetName: string)
---@field getCurrent fun(): any
---@field applyCurrent fun()
---@field names fun(): string[]

local M = {}

--- Scope of the current script: 'global', 'player' or 'menu'.
---@type SettingsPresetsScope
M.scope = SCOPE

---@param config SettingsPresetsConfig
---@return SettingsPresetsAPI
function M.register(config)
    expectType(config, 'table', 'config')

    -- Selector
    local selector = config.selector
    expectType(selector, 'table', 'config.selector')
    expectType(selector.section, 'string', 'config.selector.section')
    expectType(selector.key, 'string', 'config.selector.key')
    local selectorIsGlobal = selector.isGlobal == true
    checkScope('selector section', selector.section, selectorIsGlobal)

    -- Declared sections
    local sectionFlags = {}
    expectType(config.sections, 'table', 'config.sections')
    for name, info in pairs(config.sections) do
        expectType(name, 'string', 'config.sections key')
        info = info == nil and {} or info
        expectType(info, 'table', 'config.sections.' .. name)
        local isGlobal = info.isGlobal == true
        checkScope('section', name, isGlobal)
        if name == selector.section then
            error(string.format(
                "SettingsPresets: selector section '%s' must be separate from the " ..
                "sections it controls", name), 2)
        end
        sectionFlags[name] = isGlobal
    end

    -- Presets
    local presets = config.presets
    expectType(presets, 'table', 'config.presets')
    for presetName, sections in pairs(presets) do
        expectType(sections, 'table', 'config.presets.' .. tostring(presetName))
        for sectionName, values in pairs(sections) do
            if sectionFlags[sectionName] == nil then
                error(string.format(
                    "SettingsPresets: preset '%s' uses section '%s' which is not declared " ..
                    "in config.sections", tostring(presetName), tostring(sectionName)), 2)
            end
            expectType(values, 'table',
                string.format('config.presets.%s.%s', tostring(presetName), tostring(sectionName)))
        end
    end

    local selectorSection = getSection(selector.section, selectorIsGlobal)

    ---@type SettingsPresetsAPI
    local api = {}

    ---@param presetName string
    function api.apply(presetName)
        local preset = presets[presetName]
        if not preset then
            error(string.format("SettingsPresets: unknown preset '%s'", tostring(presetName)), 2)
        end
        for sectionName, values in pairs(preset) do
            local section = getSection(sectionName, sectionFlags[sectionName])
            for key, value in pairs(values) do
                if not deepEqual(section:getCopy(key), value) then
                    section:set(key, value)
                end
            end
        end
    end

    ---@return any
    function api.getCurrent()
        return selectorSection:get(selector.key)
    end

    function api.applyCurrent()
        local current = api.getCurrent()
        if current ~= nil and presets[current] then
            api.apply(current)
        end
    end

    ---@return string[]
    function api.names()
        local list = {}
        for name in pairs(presets) do list[#list + 1] = name end
        table.sort(list)
        return list
    end

    -- key == nil means the whole section was reset
    selectorSection:subscribe(async:callback(function(_, key)
        if key == nil or key == selector.key then
            api.applyCurrent()
        end
    end))

    return api
end

return M
