---@omw-context menu|player
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local I = require("openmw.interfaces")
local core = require("openmw.core")
local ui = require("openmw.ui")
local async = require("openmw.async")
local util = require("openmw.util")

-- --------------------------------------------------------------------
-- {
--     key = 'MY_MULTITEXTLINE',
--     renderer = 'multiTextLine',
--     name = 'multiTextLine_name',
--     description = 'multiTextLine_desc',
--     default = {
--         line1 = "hello",
--         line2 = "world",
--     },
--     argument = {
--         l10n = "MyModL10nContext",  -- OPTIONAL
--         keys = {                    -- REQUIRED, not listed keys will be ignored
--             "line1",
--             "line2",
--         },
--         lower = false,              -- OPTIONAL, default: false. Lowercases all input values
--         width = 150,                -- OPTIONAL, default: 80. Width of the input field
--     },
-- },
-- --------------------------------------------------------------------
-- Resulting stored value is a table like
-- {
--     line1 = "hello",
--     line2 = "world",
-- }
-- --------------------------------------------------------------------

---@class MultiTextLineArgs
---@field keys string[] Field keys to render, in order; also used as l10n keys for labels
---@field lower? boolean If true, lowercase all input values (default false)
---@field width? number Width of each text input box, defaults to 80
---@field l10n? string l10n context key; each field key is looked up directly as its label

---@param input table<string, string> Current values keyed by field name
---@param set fun(input: table<string, string>) Callback to persist updated values
---@param args MultiTextLineArgs
I.Settings.registerRenderer('multiTextLine', function(input, set, args)
    local lastInput = {}
    if args == nil then args = { keys = {} } end
    if args.keys ~= nil then
        for _, k in ipairs(args.keys) do
            if input[k] == nil then
                input[k] = ""
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
                {
                    template = I.MWUI.templates.box,
                    content = ui.content({ {
                        template = I.MWUI.templates.textNormal,
                        content = ui.content({ {
                            template = I.MWUI.templates.textEditLine,
                            props = {
                                text = tostring(input[key]),
                                size = util.vector2(width, 0),
                            },
                            events = {
                                textChanged = async:callback(function(text)
                                    lastInput[key] = text
                                end),
                                focusLoss = async:callback(function()
                                    local text = lastInput[key]
                                    if text == nil then
                                        text = input[key]
                                    end
                                    if args.lower == true then
                                        text = string.lower(text)
                                    end
                                    input[key] = text
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
