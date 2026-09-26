---@omw-context local|global
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local vfs = require("openmw.vfs")
local markup = require("openmw.markup")

-- ============================================================================
-- yamlFolderParser — merge list fields from every YAML file in a VFS folder
-- ============================================================================
-- USAGE:
--   local yamlFolderParser = require("scripts.MyMod.utils.yamlFolderParser")
--
--   local config = yamlFolderParser.new("scripts/MyMod/config/")
--   config:load()
--
--   local whitelist = config:getSet("whitelisted_models")   -- {[stem]=true, ...}
--   local blacklist = config:getSet("blacklisted_models")
--
--   if blacklist[someStem] then ... end
--
-- Any YAML file under the given prefix can define any fields you like;
-- this module doesn't enforce a schema, it just merges whatever list
-- fields you ask for by name across every file it finds.
-- ============================================================================

local yamlFolderParser = {}
yamlFolderParser.__index = yamlFolderParser

--- Extracts the filename stem (no directory, no extension) from a path.
-- e.g. "meshes/x/goblin01.nif" -> "goblin01"
local function extractFileName(path)
    if type(path) ~= "string" then return nil end
    return path:match("([^/\\]+)%.%w+$")
end
yamlFolderParser.extractFileName = extractFileName

---@class GeneratorOptions
---@field logTag? string        prefix used for print() messages (default "[yamlFolderParser]")
---@field silent? boolean       suppress all print() output (default false)

--- Creates a new loader bound to a VFS folder prefix.
---@param prefix string     VFS folder prefix to scan, e.g. "scripts/MyMod/config/"
---@param opts? GeneratorOptions
function yamlFolderParser.new(prefix, opts)
    opts = opts or {}
    local self = setmetatable({}, yamlFolderParser)
    self.prefix = prefix
    self.logTag = opts.logTag or "[yamlFolderParser]"
    self.silent = opts.silent or false
    self.files = {} -- filePath -> parsed table
    self.loadedCount = 0
    self.failedCount = 0
    self.loaded = false
    return self
end

function yamlFolderParser:_log(msg)
    if not self.silent then
        print(self.logTag .. " " .. msg)
    end
end

--- Scans the VFS prefix and parses every .yaml/.yml file found.
-- Safe to call multiple times, but not recommended; each call re-scans from scratch.
function yamlFolderParser:load()
    self.files = {}
    self.loadedCount = 0
    self.failedCount = 0

    for filePath in vfs.pathsWithPrefix(self.prefix) do
        if filePath:match("%.ya?ml$") then
            local ok, data = pcall(markup.loadYaml, filePath)
            if not ok then
                self.failedCount = self.failedCount + 1
                self:_log("WARNING: could not parse " .. filePath .. ": " .. tostring(data))
            elseif type(data) ~= "table" then
                self.failedCount = self.failedCount + 1
                self:_log("WARNING: " .. filePath .. " did not contain a YAML mapping/list, skipping")
            else
                self.files[filePath] = data
                self.loadedCount = self.loadedCount + 1
                self:_log("Loaded config: " .. filePath)
            end
        end
    end

    if self.loadedCount == 0 then
        self:_log("WARNING: no config YAMLs found under " .. self.prefix)
    end

    self.loaded = true
end

local function ensureLoaded(self)
    if not self.loaded then
        self:load()
    end
end

---@class GetSetOptions
---@field lowercase boolean|nil         lowercase string values before inserting (default true)
---@field stripExtension boolean|nil    run extractFileName() on each value first (default false)
---@field transform function|nil        optional function(value) -> value

--- Merges a list-valued field from every loaded file into a lookup set.
---@param field string          key to read from each file; expected to hold a YAML list
---@param opts GetSetOptions|nil
---@return table set  set in the form {[value] = true}
function yamlFolderParser:getSet(field, opts)
    opts = opts or {}
    local lowercase = opts.lowercase
    if lowercase == nil then lowercase = true end

    ensureLoaded(self)

    local set = {}
    for filePath, data in pairs(self.files) do
        local list = data[field]
        if type(list) == "table" then
            for _, v in ipairs(list) do
                local value = v
                if opts.stripExtension then
                    value = extractFileName(value) or value
                end
                if lowercase and type(value) == "string" then
                    value = value:lower()
                end
                if opts.transform then
                    value = opts.transform(value)
                end
                if value ~= nil then
                    set[value] = true
                end
            end
        elseif list ~= nil then
            self:_log("WARNING: field '" .. field .. "' in " .. filePath .. " is not a list, ignoring")
        end
    end
    return set
end

--- Same as getSet(), but returns a flat array instead of a lookup table.
---@param field string          key to read from each file; expected to hold a YAML list
---@param opts GetSetOptions|nil
---@return table list  array of values
function yamlFolderParser:getList(field, opts)
    local set = self:getSet(field, opts)
    local list = {}
    for value in pairs(set) do
        table.insert(list, value)
    end
    return list
end

--- Reads a single scalar field. If multiple files define it, the value
-- from the last one loaded wins. Useful for one-off settings rather
-- than merged lists.
---@param field string
---@param default any   returned if no loaded file defines the field
function yamlFolderParser:getValue(field, default)
    ensureLoaded(self)
    local result = default
    for _, data in pairs(self.files) do
        if data[field] ~= nil then
            result = data[field]
        end
    end
    return result
end

--- Number of successfully parsed files (triggers a load if none has happened yet).
function yamlFolderParser:count()
    ensureLoaded(self)
    return self.loadedCount
end

return yamlFolderParser
