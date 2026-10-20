---@omw-context menu|player
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local I = require("openmw.interfaces")
local core = require("openmw.core")
local ui = require("openmw.ui")
local async = require("openmw.async")
local util = require("openmw.util")

-- ============================================================================
-- MultiInput renderer — a stack of labeled inputs, in "text" or "number" mode
-- ============================================================================
-- All arguments are set ONCE and apply to every field, except min/max, which
-- are per-field (number mode).
--
-- USAGE (settings config entry), number mode:
--   {
--       key = 'MY_NUMBERS',
--       renderer = 'multiInput_V1',
--       name = 'myNumbers_name',
--       description = 'myNumbers_desc',
--       default = {
--           num1 = 0.01,
--           num2 = 1,
--       },
--       argument = {
--           mode = "number",            -- REQUIRED: "number" or "text"
--           keys = {                    -- REQUIRED, not listed keys will be ignored
--               "num1",
--               "num2",
--           },
--           l10n = "MyModL10nContext",  -- OPTIONAL, label lookup context
--           width = 150,                -- OPTIONAL, default: 80. Width of the input field
--           integer = false,            -- OPTIONAL, number mode only, default: false
--           min = {                     -- OPTIONAL, number mode only, per-field
--               num1 = -10,
--               num2 = -10,
--           },
--           max = {                     -- OPTIONAL, number mode only, per-field
--               num1 = 10,
--               num2 = 10,
--           },
--       },
--   },

-- USAGE, text mode:
--   {
--       key = 'MY_TEXTS',
--       renderer = 'multiInput_V1',
--       name = 'myTexts_name',
--       description = 'myTexts_desc',
--       default = {
--           text1 = "hello",
--           text2 = "world",
--       },
--       argument = {
--           mode = "text",              -- REQUIRED: "number" or "text"
--           keys = {                    -- REQUIRED
--               "text1",
--               "SEPARATOR",            -- "SEPARATOR" adds empty vertical space
--               "text2",
--           },
--           l10n = "MyModL10nContext",  -- OPTIONAL
--           width = 200,                -- OPTIONAL, default: 80
--           lower = true,               -- OPTIONAL, text mode only, default: false
--                                       -- Stored values are always lowercase
--       },
--   },

-- RESULTING STORED VALUES:
--   number mode: { num1 = 0.01, num2 = 1 }
--   text mode:   { text1 = "hello", text2 = "world" }
-- ============================================================================

---@class MultiInputArgs
---@field mode "text"|"number" Input mode. REQUIRED
---@field keys string[] Field keys to render, in order; also used as l10n keys for labels. "SEPARATOR" adds empty space
---@field l10n? string l10n context key; each field key is looked up directly as its label
---@field width? number Width of each input box, defaults to 80
---@field integer? boolean number mode: if true, round values to nearest integer
---@field min? table<string, number> number mode: per-key minimum value
---@field max? table<string, number> number mode: per-key maximum value
---@field lower? boolean text mode: if true, values are forced to lowercase

local SEPARATOR_KEY = "SEPARATOR"

-- ----------------------------------------------------------------------------
-- Per-mode behaviour. To add a new mode, add an entry here with:
--   default(args)         -> value used when a key is missing from the stored table
--   parse(text, args)     -> value parsed from the raw edit-line text, or nil if invalid
--   normalize(value, args, key) -> final value to store (clamping, rounding, casing...)
-- ----------------------------------------------------------------------------
local modes = {
    number = {
        default = function(_) return 0 end,
        parse = function(text, _) return tonumber(text) end,
        normalize = function(num, args, key)
            if args.integer == true then
                num = math.floor(num + 0.5)
            end
            local min = args.min and args.min[key]
            local max = args.max and args.max[key]
            if min ~= nil and num < min then
                num = min
            end
            if max ~= nil and num > max then
                num = max
            end
            return num
        end,
    },
    text = {
        default = function(_) return "" end,
        parse = function(text, _) return text end,
        normalize = function(str, args, _)
            if args.lower == true then
                str = str:lower()
            end
            return str
        end,
    },
}

---@param input table<string, number|string> Current values keyed by field name
---@param set fun(input: table<string, number|string>) Callback to persist updated values
---@param args MultiInputArgs
I.Settings.registerRenderer('multiInput_V1', function(input, set, args)
    ---@diagnostic disable-next-line: missing-fields
    args = args or {}
    local keys = args.keys or {}
    local mode = modes[args.mode] or "number"

    input = input or {}
    for _, k in ipairs(keys) do
        if k ~= SEPARATOR_KEY and input[k] == nil then
            input[k] = mode.default(args)
        end
    end

    local lastInput = {}
    local width = args.width or 80
    local translate = args.l10n
        and core.l10n(args.l10n)
        or function(key) return key end

    local interval = {
        template = I.MWUI.templates.interval
    }

    local body = {
        type = ui.TYPE.Flex,
        props = {
            horizontal = false,
            arrange = ui.ALIGNMENT.End,
        },
        content = ui.content({}),
    }

    local function newInputField(key)
        local label = translate(key)
        return {
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                arrange = ui.ALIGNMENT.Center,
            },
            content = ui.content({
                {
                    template = I.MWUI.templates.textNormal,
                    props = {
                        text = label,
                        textAlignV = ui.ALIGNMENT.Center,
                    },
                },
                interval,
                interval,
                interval,
                {
                    template = I.MWUI.templates.box,
                    content = ui.content({ {
                        template = I.MWUI.templates.padding,
                        content = ui.content({ {
                            template = I.MWUI.templates.textEditLine,
                            props = {
                                text = tostring(input[key]),
                                size = util.vector2(width, 0),
                            },
                            events = {
                                textChanged = async:callback(function(text)
                                    -- nil here means "invalid for this mode" (e.g. not a number)
                                    lastInput[key] = mode.parse(text, args)
                                end),
                                focusLoss = async:callback(function()
                                    local value = lastInput[key]
                                    if value == nil then
                                        -- no edit happened (or invalid input), keep the existing value
                                        return
                                    end
                                    input[key] = mode.normalize(value, args, key)
                                    lastInput[key] = nil
                                    set(input)
                                end),
                            },
                        }, }),
                    }, }),
                },
            }),
        }
    end

    for i, key in ipairs(keys) do
        if i ~= 1 then -- skip first iteration
            body.content:add(interval)
            body.content:add(interval)
        end

        if key == SEPARATOR_KEY then
            body.content:add(interval)
            body.content:add(interval)
            body.content:add(interval)
            body.content:add(interval)
            body.content:add(interval)
        else
            body.content:add(newInputField(key))
        end
    end

    return {
        type = ui.TYPE.Flex,
        content = ui.content({
            body,
        }),
    }
end)
