---@omw-context menu|player
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local I = require("openmw.interfaces")
local core = require("openmw.core")
local ui = require("openmw.ui")
local async = require("openmw.async")
local util = require("openmw.util")

-- ============================================================================
-- multiNumber renderer — a stack of labeled numeric inputs with optional clamping
-- ============================================================================
-- USAGE (settings config entry):
--   {
--       key = 'MY_MULTINUMBER',
--       renderer = 'multiNumber',
--       name = 'multiNumber_name',
--       description = 'multiNumber_desc',
--       default = {
--           num1 = 0.01,
--           num2 = 1,
--       },
--       argument = {
--           l10n = "MyModL10nContext",  -- OPTIONAL
--           keys = {                    -- REQUIRED, not listed keys will be ignored
--               "num1",
--               "num2",
--           },
--           integer = false,             -- OPTIONAL, default: false
--           min = {                     -- OPTIONAL
--               num1 = -10,
--               num2 = -10,
--           },
--           max = {                     -- OPTIONAL
--               num1 = 10,
--               num2 = 10,
--           },
--           width = 150,                -- OPTIONAL, default: 80. Width of the input field
--       },
--   },
--
-- RESULTING STORED VALUE:
--   { num1 = 0.01, num2 = 1 }
-- ============================================================================

---@class MultiNumberArgs
---@field keys string[] Field keys to render, in order; also used as l10n keys for labels
---@field integer? boolean If true, round values to nearest integer
---@field min? table<string, number> Per-key minimum value
---@field max? table<string, number> Per-key maximum value
---@field width? number Width of each text input box, defaults to 80
---@field l10n? string l10n context key; each field key is looked up directly as its label

---@param input table<string, number> Current values keyed by field name
---@param set fun(input: table<string, number>) Callback to persist updated values
---@param args MultiNumberArgs
I.Settings.registerRenderer('multiNumber_V1', function(input, set, args)
    local lastInput = {}
    if args == nil then args = { keys = {} } end
    if args.keys ~= nil then
        for _, k in ipairs(args.keys) do
            if input[k] == nil then
                input[k] = 0
            end
        end
    end

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

    for _, key in ipairs(args.keys) do
        local label = translate(key)
        body.content:add(interval)
        body.content:add(interval)
        body.content:add({
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
                                    lastInput[key] = tonumber(text)
                                end),
                                focusLoss = async:callback(function()
                                    local num = lastInput[key]
                                    if num == nil then
                                        input[key] = 0
                                        set(input)
                                        return
                                    end
                                    if args.integer == true then
                                        num = math.floor(num + 0.5)
                                    end
                                    if args.min[key] ~= nil and num < args.min[key] then
                                        num = args.min[key]
                                    elseif args.max[key] ~= nil and num > args.max[key] then
                                        num = args.max[key]
                                    end
                                    input[key] = num
                                    set(input)
                                end),
                            },
                        }, }),
                    }, }),
                },
            }),
        })
    end

    return {
        type = ui.TYPE.Flex,
        content = ui.content({
            body,
        }),
    }
end)
