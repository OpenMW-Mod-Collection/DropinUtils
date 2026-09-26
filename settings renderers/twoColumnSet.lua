---@diagnostic disable: missing-fields
---@omw-context menu
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local I = require("openmw.interfaces")
local core = require("openmw.core")
local async = require("openmw.async")
local ui = require("openmw.ui")
local util = require("openmw.util")
local ambient = require("openmw.ambient")

-- --------------------------------------------------------------------
-- {
--    key = 'MY_TWO_COLUMN_SET',
--    name = 'Allowed / Blocked NPCs',
--    description = 'Left-click an entry to move it to the other column, right-click to remove it.',
--    renderer = 'twoColumnSet',
--    default = {
--       ["caius cosades"] = true,   -- true  -> left column
--       ["guar"]          = false, -- false -> right column
--    },
--    argument = {
--       width      = 200,          -- REQUIRED, width (in px) of EACH column
--       leftLabel  = 'Allowed',    -- OPTIONAL, default: 'True'
--       rightLabel = 'Blocked',    -- OPTIONAL, default: 'False'
--       l10n       = 'MyMod',      -- OPTIONAL, if set leftLabel/rightLabel are treated as l10n keys
--       lower      = false,        -- OPTIONAL, default: false. Lowercases new user-typed entries
--       colorful   = false,        -- OPTIONAL, default: false. Vanilla text colors vs green/red
--       guide      = true,         -- OPTIONAL, default: false. Shows an LMB/RMB usage hint below the lists
--       guideText  = nil,          -- OPTIONAL, override the default guide text (or an l10n key if l10n is set)
--    },
-- },

-- Resulting stored value is a table like { ["caius cosades"] = true, ["guar"] = false }.
-- Keys with a value of `true` are rendered in the left column, `false` in the right column.
-- --------------------------------------------------------------------

---@class TwoColumnSetArgs
---@field width number             REQUIRED. Width in px of each column (height is automatic).
---@field leftLabel string|nil     OPTIONAL. Header text for the left (true) column. Default: 'True'
---@field rightLabel string|nil   OPTIONAL. Header text for the right (false) column. Default: 'False'
---@field l10n string|nil         OPTIONAL. If set, leftLabel/rightLabel are treated as l10n keys.
---@field lower boolean|nil       OPTIONAL. If true, newly typed entries are lowercased. Default: false
---@field colorful boolean|nil    OPTIONAL. If true, use green/red palette instead of vanilla. Default: false
---@field guide boolean|nil       OPTIONAL. If true, shows an LMB/RMB usage hint below the lists. Default: true
---@field guideText string|nil    OPTIONAL. Override the default guide text (or an l10n key if l10n is set)


local colorFromGMST = function(gmst)
    local colorString = core.getGMST(gmst)
    local numberTable = {}
    for numberString in colorString:gmatch("([^,]+)") do
        if #numberTable == 3 then break end
        local number = tonumber(numberString:match("^%s*(.-)%s*$"))
        if number then
            table.insert(numberTable, number / 255)
        end
    end

    if #numberTable < 3 then error('Invalid color GMST name: ' .. gmst) end

    return util.color.rgb(table.unpack(numberTable))
end

local MORROWIND_TEXT_STATES = {
    resting    = { color = colorFromGMST('fontcolor_color_normal'), alpha = 1.0 },
    hover      = { color = colorFromGMST('fontcolor_color_normal_over'), alpha = 1.0 },
    interacted = { color = colorFromGMST('fontcolor_color_normal_pressed'), alpha = 1.0 },
    disabled   = { color = colorFromGMST('fontcolor_color_disabled'), alpha = 0.75 },
}
local COLORFUL_LEFT_STATES = {
    resting    = { color = util.color.rgb(0.50, 0.95, 0.40), alpha = 1.0 },
    hover      = { color = util.color.rgb(0.75, 1.00, 0.75), alpha = 1.0 },
    interacted = { color = util.color.rgb(0.95, 1.00, 0.95), alpha = 1.0 },
}
local COLORFUL_RIGHT_STATES = {
    resting    = { color = util.color.rgb(0.95, 0.35, 0.35), alpha = 1.0 },
    hover      = { color = util.color.rgb(1.00, 0.55, 0.55), alpha = 1.0 },
    interacted = { color = util.color.rgb(1.00, 0.75, 0.75), alpha = 1.0 },
}

local padding = {
    template = I.MWUI.templates.padding
}
local interval = {
    template = I.MWUI.templates.interval
}

local function updateTextColor(state, textWidget)
    textWidget.layout.props.textColor = state.color
    textWidget.layout.props.alpha = state.alpha
    textWidget:update()
end

I.Settings.registerRenderer('twoColumnSet', function(input, set, args)
    ---@type TwoColumnSetArgs
    args = args or {}
    if type(args.width) ~= "number" then
        error("twoColumnSet renderer requires a numeric 'width' argument")
    end
    local width = args.width
    local lower = args.lower == true

    if type(input) ~= "table" then
        input = {}
        set(input)
    end

    local translate
    if args.l10n == nil then
        translate = function(text) return text end
    else
        local l10n = core.l10n(args.l10n)
        translate = function(key) return l10n(key) end
    end

    local leftLabel = translate(args.leftLabel or 'True')
    local rightLabel = translate(args.rightLabel or 'False')

    -- pending text typed into each column's input box (kept outside `input`)
    local pendingText = { [true] = '', [false] = '' }

    local function isColorful()
        return args.colorful == true
    end

    -- ----------------------------------------------------------------
    -- entry row (an existing key in `input`)
    -- ----------------------------------------------------------------
    local function makeEntryRow(key, isLeft)
        local states
        if isColorful() then
            states = isLeft and COLORFUL_LEFT_STATES or COLORFUL_RIGHT_STATES
        else
            states = MORROWIND_TEXT_STATES
        end

        local entryText = ui.create({
            template = I.MWUI.templates.textNormal,
            props = {
                text = key,
                textAlignH = ui.ALIGNMENT.Start,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
        updateTextColor(states.resting, entryText)

        local buttonHeld = false

        return {
            template = I.MWUI.templates.padding,
            content = ui.content({
                {
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = true,
                        propagateEvents = false,
                        arrange = ui.ALIGNMENT.Start,
                    },
                    external = {
                        stretch = 1,
                    },
                    content = ui.content({ entryText }),
                    events = {
                        mousePress = async:callback(function(e)
                            if e.button == 1 or e.button == 3 then
                                buttonHeld = true
                                updateTextColor(states.interacted, entryText)
                            end
                        end),
                        mouseRelease = async:callback(function(e)
                            buttonHeld = false
                            if e.button == 1 then
                                -- left click: move to the other column
                                ambient.playSound('menu click', {})
                                input[key] = not isLeft
                                set(input)
                            elseif e.button == 3 then
                                -- right click: remove entirely
                                ambient.playSound('menu click', {})
                                input[key] = nil
                                set(input)
                            else
                                updateTextColor(states.resting, entryText)
                            end
                        end),
                        focusGain = async:callback(function()
                            if not buttonHeld then
                                updateTextColor(states.hover, entryText)
                            end
                        end),
                        focusLoss = async:callback(function()
                            if not buttonHeld then
                                updateTextColor(states.resting, entryText)
                            end
                        end),
                    },
                },
            }),
        }
    end

    local ADD_BUTTON_WIDTH = 30
    local BOX_INNER_PADDING = 7
    local ADD_ROW_GAP = 2

    -- ----------------------------------------------------------------
    -- "Add" input row at the bottom of a column (taken from textSet)
    -- ----------------------------------------------------------------
    local function makeAddRow(isLeft)
        local header = {
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
            },
            content = ui.content({}),
        }

        header.content:add({
            template = I.MWUI.templates.box,
            props = {
                size = util.vector2(ADD_BUTTON_WIDTH, 0),
            },
            content = ui.content({ {
                template = I.MWUI.templates.padding,
                content = ui.content({ {
                    template = I.MWUI.templates.textNormal,
                    props = {
                        text = "Add",
                        textAlignH = ui.ALIGNMENT.Center,
                    },
                    events = {
                        mouseClick = async:callback(function()
                            local text = pendingText[isLeft]
                            if text == "" then return end
                            if input[text] ~= nil then
                                -- already present somewhere; just move/keep it in this column
                                input[text] = isLeft
                                set(input)
                                return
                            end
                            input[text] = isLeft
                            set(input)
                        end),
                    },
                } }),
            } }),
        })
        header.content:add({
            type = ui.TYPE.Widget,
            props = {
                size = util.vector2(ADD_ROW_GAP, 0),
            },
        })

        local textFieldBoxWidth = width - ADD_BUTTON_WIDTH - ADD_ROW_GAP
        local textFieldWidth = textFieldBoxWidth - BOX_INNER_PADDING

        header.content:add({
            template = I.MWUI.templates.box,
            props = {
                size = util.vector2(textFieldBoxWidth, 0),
            },
            content = ui.content({ {
                template = I.MWUI.templates.padding,
                content = ui.content({ {
                    template = I.MWUI.templates.textEditLine,
                    props = {
                        size = util.vector2(textFieldWidth, 0),
                    },
                    events = {
                        textChanged = async:callback(function(text)
                            pendingText[isLeft] = lower and text:lower() or text
                        end),
                    },
                } }),
            } }),
        })

        return header
    end


    -- ----------------------------------------------------------------
    -- one column: label, add-row (input), then only the item list boxed
    -- ----------------------------------------------------------------
    local function makeColumn(label, isLeft)
        local column = {
            type = ui.TYPE.Flex,
            props = {
                horizontal = false,
                arrange = ui.ALIGNMENT.Start,
            },
            content = ui.content({}),
        }

        column.content:add {
            template = I.MWUI.templates.textNormal,
            props = {
                text = label,
                textAlignH = ui.ALIGNMENT.Start,
            },
        }
        column.content:add(interval)
        column.content:add(interval)

        column.content:add(makeAddRow(isLeft))
        column.content:add(interval)

        local list = {
            type = ui.TYPE.Flex,
            props = {
                horizontal = false,
                arrange = ui.ALIGNMENT.Start,
                size = util.vector2(width, 0),
            },
            content = ui.content({}),
        }

        local sortedKeys = {}
        for key, value in pairs(input) do
            if value == isLeft then
                table.insert(sortedKeys, key)
            end
        end
        table.sort(sortedKeys)

        for _, key in ipairs(sortedKeys) do
            list.content:add(makeEntryRow(key, isLeft))
        end

        column.content:add({
            template = I.MWUI.templates.box,
            content = ui.content({ {
                template = I.MWUI.templates.padding,
                content = ui.content({ list }),
            } }),
        })

        return column
    end

    local body = {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Start,
        },
        content = ui.content({
            makeColumn(leftLabel, true),
            interval,
            interval,
            interval,
            makeColumn(rightLabel, false),
        }),
    }

    local root = {
        type = ui.TYPE.Flex,
        content = ui.content({
            body,
        }),
    }

    -- ----------------------------------------------------------------
    -- optional LMB/RMB usage guide, shown once below both columns
    -- ----------------------------------------------------------------
    if args.guide then
        root.content:add(interval)
        root.content:add(interval)
        root.content:add(interval)
        root.content:add {
            template = I.MWUI.templates.textParagraph,
            props = {
                size = util.vector2(width * 2 + 3, 0),
                text = 'Left click: move between columns.\nRight click: remove.',
                textAlignH = ui.ALIGNMENT.Start,
                textColor = MORROWIND_TEXT_STATES.disabled.color,
                alpha = MORROWIND_TEXT_STATES.disabled.alpha,
            }
        }
    end

    return root
end)
