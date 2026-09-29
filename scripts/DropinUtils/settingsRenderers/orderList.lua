---@diagnostic disable: missing-fields
---@omw-context menu
-- Based on the twoColumnSet renderer from Bor's Drop-in Utils project:
-- https://github.com/OpenMW-Mod-Collection/DropinUtils
local I = require("openmw.interfaces")
local core = require("openmw.core")
local async = require("openmw.async")
local ui = require("openmw.ui")
local util = require("openmw.util")
local ambient = require("openmw.ambient")

-- ============================================================================
-- orderList_V1 renderer - a list of string entries the player can reorder
-- ============================================================================
-- USAGE (settings config entry):
--   {
--      key = 'MY_ORDER_LIST',
--      name = 'Priority order',
--      description = 'Click an entry to select it, then use the buttons above the list.',
--      renderer = 'orderList_V1',
--      default = {
--         "Fire",
--         "Frost",
--         "- Weak -",   -- locked separator (see below)
--         "Shock",
--         "Poison",
--      },
--      argument = {
--         width = 220,  -- OPTIONAL, width (in px) of the list. Default: 220
--      },
--   },
--
-- STORED VALUE:
--   A regular list of strings, in display order.
--
-- LOCKED ENTRIES (separators):
--   Any entry written as "- name -" (starts with "- ", ends with " -") is locked.
--   It is shown greyed out and cannot be selected or moved by the player.
--   Its position is defined by the stored list; other entries move around it.
-- ============================================================================

---@class OrderListArgs
---@field width? number  OPTIONAL. Width in px of the list (height is automatic). Default: 220
---                      Values below ~200 make the button row wider than the list.

local DEFAULT_WIDTH = 220
local BUTTON_TEXT_HEIGHT = 16

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

local TEXT_STATES = {
    resting       = { color = colorFromGMST('fontcolor_color_normal'), alpha = 1.0 },
    hover         = { color = colorFromGMST('fontcolor_color_normal_over'), alpha = 1.0 },
    pressed       = { color = colorFromGMST('fontcolor_color_normal_pressed'), alpha = 1.0 },
    active        = { color = colorFromGMST('fontcolor_color_active'), alpha = 1.0 },
    activeHover   = { color = colorFromGMST('fontcolor_color_active_over'), alpha = 1.0 },
    activePressed = { color = colorFromGMST('fontcolor_color_active_pressed'), alpha = 1.0 },
    disabled      = { color = colorFromGMST('fontcolor_color_disabled'), alpha = 0.75 },
}

local interval = {
    template = I.MWUI.templates.interval
}

local function updateTextColor(state, textWidget)
    textWidget.layout.props.textColor = state.color
    textWidget.layout.props.alpha = state.alpha
    textWidget:update()
end

local selectedKey = nil

local function isLocked(key)
    return type(key) == "string" and key:match("^%- .+ %-$") ~= nil
end

local function indexOf(list, key)
    for i, v in ipairs(list) do
        if v == key then return i end
    end
    return nil
end

-- Returns the final index the entry at `idx` should end up at, or nil if it can't move.
--   stepUp / stepDown : one slot, jumping over a run of locked entries
--   jumpUp / jumpDown : over the nearest separator, or to the list end if none
local function targetIndex(list, idx, action)
    local count = #list
    if action == "stepUp" or action == "stepDown" then
        local dir = action == "stepUp" and -1 or 1
        local j = idx + dir
        if j < 1 or j > count then return nil end
        if isLocked(list[j]) then
            while j >= 1 and j <= count and isLocked(list[j]) do
                j = j + dir
            end
            j = j - dir
        end
        return j
    elseif action == "jumpUp" then
        local j = idx - 1
        while j >= 1 and not isLocked(list[j]) do j = j - 1 end
        local target = j < 1 and 1 or j
        if target == idx then return nil end
        return target
    elseif action == "jumpDown" then
        local j = idx + 1
        while j <= count and not isLocked(list[j]) do j = j + 1 end
        local target = j > count and count or j
        if target == idx then return nil end
        return target
    end
    return nil
end

I.Settings.registerRenderer('orderList_V1', function(value, set, args)
    ---@type OrderListArgs
    args = args or {}
    if args.width ~= nil and type(args.width) ~= "number" then
        error("orderList_V1: 'width' argument must be a number")
    end
    local width = args.width or DEFAULT_WIDTH

    if type(value) ~= "table" then
        value = {}
        set(value)
    end

    -- working copy, so the stored table is never mutated in place
    local list = {}
    for _, v in ipairs(value) do
        table.insert(list, tostring(v))
    end

    local rows = {}         -- key -> text widget
    local buttons = {}      -- action -> text widget
    local hoveredKey = nil
    local hoveredButton = nil
    local pressedKey = nil
    local pressedButton = nil

    local function canDo(action)
        if selectedKey == nil then return false end
        local idx = indexOf(list, selectedKey)
        if idx == nil then return false end
        return targetIndex(list, idx, action) ~= nil
    end

    local function doAction(action)
        if not canDo(action) then return end
        local idx = indexOf(list, selectedKey)
        local target = targetIndex(list, idx, action)
        if not target then return end
        ambient.playSound('menu click', {})
        table.remove(list, idx)
        table.insert(list, target, selectedKey)
        set(list)
    end

    local function paintRow(key)
        local widget = rows[key]
        if not widget then return end
        local pressed = key == pressedKey
        local hovered = key == hoveredKey
        local state
        if isLocked(key) then
            state = TEXT_STATES.disabled
        elseif key == selectedKey then
            if pressed then
                state = TEXT_STATES.activePressed
            elseif hovered then
                state = TEXT_STATES.activeHover
            else
                state = TEXT_STATES.active
            end
        elseif pressed then
            state = TEXT_STATES.pressed
        elseif hovered then
            state = TEXT_STATES.hover
        else
            state = TEXT_STATES.resting
        end
        updateTextColor(state, widget)
    end

    local function paintButton(action)
        local widget = buttons[action]
        if not widget then return end
        local state
        if not canDo(action) then
            state = TEXT_STATES.disabled
        elseif pressedButton == action then
            state = TEXT_STATES.pressed
        elseif hoveredButton == action then
            state = TEXT_STATES.hover
        else
            state = TEXT_STATES.resting
        end
        updateTextColor(state, widget)
    end

    local function refreshAll()
        for key in pairs(rows) do paintRow(key) end
        for action in pairs(buttons) do paintButton(action) end
    end

    -- ----------------------------------------------------------------
    -- control buttons: box > padding > text, stretched over the row
    -- ----------------------------------------------------------------
    local function makeButton(action, label)
        local text = ui.create({
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                autoSize = false,
                size = util.vector2(width / 4 - 9, BUTTON_TEXT_HEIGHT),
                text = label,
                textAlignH = ui.ALIGNMENT.Center,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
        buttons[action] = text

        return {
            template = I.MWUI.templates.box,
            content = ui.content({ {
                template = I.MWUI.templates.padding,
                content = ui.content({ text }),
            } }),
            events = {
                mousePress = async:callback(function(e)
                    if e.button == 1 then
                        pressedButton = action
                        paintButton(action)
                    end
                end),
                mouseRelease = async:callback(function(e)
                    if e.button == 1 then
                        pressedButton = nil
                        paintButton(action)
                    end
                end),
                mouseClick = async:callback(function()
                    doAction(action)
                end),
                focusGain = async:callback(function()
                    hoveredButton = action
                    paintButton(action)
                end),
                focusLoss = async:callback(function()
                    if hoveredButton == action then hoveredButton = nil end
                    if pressedButton == action then pressedButton = nil end
                    paintButton(action)
                end),
            },
        }
    end

    local controls = {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            gap = 4,
        },
        content = ui.content({
            makeButton("jumpUp", "Up"),
            makeButton("stepUp", "+1"),
            makeButton("stepDown", "-1"),
            makeButton("jumpDown", "Down"),
        }),
    }

    -- ----------------------------------------------------------------
    -- list rows
    -- ----------------------------------------------------------------
    local function makeEntryRow(key)
        local locked = isLocked(key)

        local entryText = ui.create({
            template = I.MWUI.templates.textNormal,
            props = {
                text = key,
                textAlignH = ui.ALIGNMENT.Start,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
        rows[key] = entryText

        local flex = {
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
        }

        if not locked then
            flex.events = {
                mousePress = async:callback(function(e)
                    if e.button == 1 then
                        pressedKey = key
                        paintRow(key)
                    end
                end),
                mouseRelease = async:callback(function(e)
                    if e.button == 1 then
                        pressedKey = nil
                        paintRow(key)
                    end
                end),
                mouseClick = async:callback(function()
                    ambient.playSound('menu click', {})
                    if selectedKey == key then
                        selectedKey = nil
                    else
                        selectedKey = key
                    end
                    refreshAll()
                end),
                focusGain = async:callback(function()
                    hoveredKey = key
                    paintRow(key)
                end),
                focusLoss = async:callback(function()
                    if hoveredKey == key then hoveredKey = nil end
                    if pressedKey == key then pressedKey = nil end
                    paintRow(key)
                end),
            }
        end

        return {
            template = I.MWUI.templates.padding,
            content = ui.content({ flex }),
        }
    end

    local listWidget = {
        type = ui.TYPE.Flex,
        props = {
            horizontal = false,
            arrange = ui.ALIGNMENT.Start,
            size = util.vector2(width, 0),
        },
        content = ui.content({}),
    }

    for _, key in ipairs(list) do
        listWidget.content:add(makeEntryRow(key))
    end

    local root = {
        type = ui.TYPE.Flex,
        props = {
            horizontal = false,
        },
        content = ui.content({
            controls,
            interval,
            interval,
            {
                template = I.MWUI.templates.box,
                content = ui.content({ {
                    template = I.MWUI.templates.padding,
                    content = ui.content({ listWidget }),
                } }),
            },
        }),
    }

    refreshAll()

    return root
end)
