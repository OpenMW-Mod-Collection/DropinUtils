---@diagnostic disable: invisible
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
--
-- DETERMINISM:
--   Files are processed in sorted path order (case-insensitive, ties broken
--   by raw path). getList() output order and getValue() "last wins" both
--   follow that order. Use numeric filename prefixes (10_base.yaml,
--   90_patch.yaml) to control priority.
-- ============================================================================

---@class yamlFolderParser
---@field prefix string                     VFS folder prefix being scanned
---@field logTag string                     prefix used for print() messages
---@field silent boolean                    whether print() output is suppressed
---@field files table<string, table>        file path -> parsed YAML table
---@field order string[]                    loaded file paths in deterministic (sorted) order
---@field loadedCount integer               number of successfully parsed files
---@field failedCount integer               number of files that failed to parse
---@field loaded boolean                    true once load() has run
local yamlFolderParser = {}
yamlFolderParser.__index = yamlFolderParser

--- Extracts the filename stem (no directory, no extension) from a path.
-- e.g. "meshes/x/goblin01.nif" -> "goblin01"
---@param path any            non-string input returns nil
---@return string|nil stem
local function extractFileName(path)
    if type(path) ~= "string" then return nil end
    return path:match("([^/\\]+)%.%w+$")
end
yamlFolderParser.extractFileName = extractFileName

---@class yamlFolderParser.Options
---@field logTag? string        prefix used for print() messages (default "[yamlFolderParser]")
---@field silent? boolean       suppress all print() output (default false)

--- Creates a new loader bound to a VFS folder prefix.
---@param prefix string                     VFS folder prefix to scan, e.g. "scripts/MyMod/config/"
---@param opts? yamlFolderParser.Options
---@return yamlFolderParser
function yamlFolderParser.new(prefix, opts)
    opts = opts or {}
    ---@type yamlFolderParser
    local self = setmetatable({}, yamlFolderParser)
    self.prefix = prefix
    self.logTag = opts.logTag or "[yamlFolderParser]"
    self.silent = opts.silent or false
    self.files = {}
    self.order = {}
    self.loadedCount = 0
    self.failedCount = 0
    self.loaded = false
    return self
end

---@private
---@param msg string
function yamlFolderParser:_log(msg)
    if not self.silent then
        print(self.logTag .. " " .. msg)
    end
end

--- Scans the VFS prefix and parses every .yaml/.yml file found.
-- Safe to call multiple times, but not recommended; each call re-scans from scratch.
function yamlFolderParser:load()
    self.files = {}
    self.order = {}
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
                table.insert(self.order, filePath)
                self.loadedCount = self.loadedCount + 1
                self:_log("Loaded config: " .. filePath)
            end
        end
    end

    -- Deterministic processing order: case-insensitive path, ties broken by raw path
    table.sort(self.order, function(a, b)
        local la, lb = a:lower(), b:lower()
        if la ~= lb then return la < lb end
        return a < b
    end)

    if self.loadedCount == 0 then
        self:_log("WARNING: no config YAMLs found under " .. self.prefix)
    end

    self.loaded = true
end

---@param self yamlFolderParser
local function ensureLoaded(self)
    if not self.loaded then
        self:load()
    end
end

---@class yamlFolderParser.GetOptions
---@field lowercase? boolean        lowercase string values before inserting (default true)
---@field stripExtension? boolean   run extractFileName() on each value first (default false)
---@field transform? fun(value: any): any   optional; returning nil skips the value

--- Internal: ordered, de-duplicated values (first occurrence wins position).
---@param self yamlFolderParser
---@param field string
---@param opts? yamlFolderParser.GetOptions
---@return any[] list
---@return table<any, true> set
local function collect(self, field, opts)
    opts = opts or {}
    local lowercase = opts.lowercase
    if lowercase == nil then lowercase = true end

    ensureLoaded(self)

    local list, seen = {}, {}
    for _, filePath in ipairs(self.order) do
        local entries = self.files[filePath][field]
        if type(entries) == "table" then
            for _, v in ipairs(entries) do
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
                if value ~= nil and not seen[value] then
                    seen[value] = true
                    table.insert(list, value)
                end
            end
        elseif entries ~= nil then
            self:_log("WARNING: field '" .. field .. "' in " .. filePath .. " is not a list, ignoring")
        end
    end
    return list, seen
end

--- Merges a list-valued field from every loaded file into a lookup set.
---@param field string                          key to read from each file; expected to hold a YAML list
---@param opts? yamlFolderParser.GetOptions
---@return table<any, true> set                 set in the form {[value] = true}
function yamlFolderParser:getSet(field, opts)
    local _, set = collect(self, field, opts)
    return set
end

--- Deterministic: files in sorted path order, entries in file order, duplicates dropped.
---@param field string                          key to read from each file; expected to hold a YAML list
---@param opts? yamlFolderParser.GetOptions
---@return any[] list                           array of values
function yamlFolderParser:getList(field, opts)
    local list = collect(self, field, opts)
    return list
end

--- Reads a single scalar field. If several files define it, the last in
-- sorted path order wins. Useful for one-off settings rather than merged lists.
---@generic T
---@param field string
---@param default? T        returned if no loaded file defines the field
---@return T|any value
function yamlFolderParser:getValue(field, default)
    ensureLoaded(self)
    local result = default
    for _, filePath in ipairs(self.order) do
        local v = self.files[filePath][field]
        if v ~= nil then
            result = v
        end
    end
    return result
end

--- Number of successfully parsed files (triggers a load if none has happened yet).
---@return integer
function yamlFolderParser:count()
    ensureLoaded(self)
    return self.loadedCount
end

return yamlFolderParser
