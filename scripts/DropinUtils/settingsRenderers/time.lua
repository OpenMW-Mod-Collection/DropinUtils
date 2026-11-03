---@omw-context menu
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
-- Button look & colours taken from the orderList renderer.
local ui = require('openmw.ui')
local util = require('openmw.util')
local async = require('openmw.async')
local core = require('openmw.core')
local input = require('openmw.input')
local ambient = require('openmw.ambient')
local time = require('openmw_aux.time')
local I = require('openmw.interfaces')


-- ============================================================================
-- Example:
--     {
--         key = "MY_TIME",
--         name = "Time Settings Renderer",
--         renderer = "time_V1",
--         default = 2 * time.day + 5 * time.hour,
--         argument = {
--             days = true, -- OPTIONAL, set to false to hide the days column. Default: true
--         },
--     }
--
-- Returns time in seconds
-- ============================================================================

local v2 = util.vector2
local RENDERER_KEY = 'time_V1'
local LABEL_DAYS = 'Days:'
local SEPARATOR = ':'
local INPUT_WIDTH = 26 -- text edit / button width, hours / minutes / seconds
local BUTTON_TEXT_HEIGHT = 16
local GAP_DAYS = 30    -- day column -> time input
local INTERVAL = { template = I.MWUI.templates.interval }

-- hold-to-repeat tuning (real-time seconds)
local HOLD_DELAY = 0.5   -- how long to hold before repeating starts
local REPEAT_SLOW = 0.15 -- repeat interval right after the delay
local REPEAT_FAST = 0.05 -- repeat interval after holding for a while
local FAST_AFTER = 1.5   -- seconds of repeating before switching to fast

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
    resting  = { color = colorFromGMST('fontcolor_color_normal'), alpha = 1.0 },
    hover    = { color = colorFromGMST('fontcolor_color_normal_over'), alpha = 1.0 },
    pressed  = { color = colorFromGMST('fontcolor_color_normal_pressed'), alpha = 1.0 },
    disabled = { color = colorFromGMST('fontcolor_color_disabled'), alpha = 0.75 },
}

local function updateTextColor(state, textWidget)
    textWidget.layout.props.textColor = state.color
    textWidget.layout.props.alpha = state.alpha
    textWidget:update()
end

local UNITS = {
    { key = 'day',    secs = time.day,    pad = false },
    { key = 'hour',   secs = time.hour,   pad = true },
    { key = 'minute', secs = time.minute, pad = true },
    { key = 'second', secs = time.second, pad = true },
}

local function enabledUnits(arg)
    local list = {}
    for _, u in ipairs(UNITS) do
        if u.key ~= 'day' or arg.days ~= false then
            list[#list + 1] = u
        end
    end
    return list
end

local function decompose(total, units)
    local out, rest = {}, total
    for _, u in ipairs(units) do
        local n = math.floor(rest / u.secs)
        out[u.key] = n
        rest = rest - n * u.secs
    end
    return out
end

--------------------------------------------------------------------------------
-- Hold-to-repeat
--------------------------------------------------------------------------------
-- Changing the value makes OpenMW rebuild the renderer, which destroys the
-- button under the cursor (so it never sees mouseRelease). The hold state
-- therefore lives at module level and the release is detected by polling the
-- mouse button in onFrame.

---@type table|nil
local hold = nil

local function stopHold()
    hold = nil
end

local function onFrame()
    if not hold then return end

    if not input.isMouseButtonPressed(1) then
        stopHold()
        return
    end

    local now = core.getRealTime()
    if now < hold.nextTick then return end

    local heldFor = now - hold.repeatStart
    hold.nextTick = now + (heldFor >= FAST_AFTER and REPEAT_FAST or REPEAT_SLOW)

    local h = hold
    local ok = h.step(h.unitIndex, h.direction)
    if ok == false then stopHold() end -- hit the lower limit
end

--------------------------------------------------------------------------------
-- Renderer
--------------------------------------------------------------------------------

local function renderer(value, set, arg)
    arg = arg or {}
    local units = enabledUnits(arg)
    local startValue = math.max(0, math.floor(tonumber(value) or 0))
    local vals = decompose(startValue, units)
    local pending = {} -- typed but not yet committed numbers by unit key

    local function total()
        local t = 0
        for _, u in ipairs(units) do t = t + vals[u.key] * u.secs end
        return t
    end

    local function flushPending()
        for key, n in pairs(pending) do vals[key] = n end
        pending = {}
    end

    local function publish()
        local t = total()
        vals = decompose(t, units)
        set(t)
    end

    -- returns false if the step was not possible (would go below zero)
    local function step(i, direction)
        flushPending()
        local t = total() + direction * units[i].secs
        if t < 0 then return false end
        vals = decompose(t, units)
        publish()
        if hold then hold.expected = t end
        return true
    end

    local function stepButton(i, direction, label)
        -- If this widget is the continuation of a button that is currently
        -- being held (the renderer was rebuilt after a step), draw it pressed.
        local isHeld = hold ~= nil
            and hold.unitIndex == i
            and hold.direction == direction
            and hold.expected == startValue

        local text = ui.create({
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                autoSize = false,
                size = v2(INPUT_WIDTH, BUTTON_TEXT_HEIGHT),
                text = label,
                textAlignH = ui.ALIGNMENT.Center,
                textAlignV = ui.ALIGNMENT.Center,
                textColor = (isHeld and TEXT_STATES.pressed or TEXT_STATES.resting).color,
            },
        })

        local pressed = isHeld
        local hovered = false
        local function paint()
            local state = TEXT_STATES.resting
            if pressed then
                state = TEXT_STATES.pressed
            elseif hovered then
                state = TEXT_STATES.hover
            end
            updateTextColor(state, text)
        end

        return {
            template = I.MWUI.templates.box,
            props = { alpha = 0.5 },
            content = ui.content { {
                template = I.MWUI.templates.padding,
                props = { inheritAlpha = false },
                content = ui.content { text },
            } },
            events = {
                mousePress = async:callback(function(e)
                    if e.button ~= 1 then return end
                    pressed = true
                    paint()
                    ambient.playSound('menu click', {})
                    local ok = step(i, direction)
                    if ok == false then return end
                    local now = core.getRealTime()
                    hold = {
                        unitIndex = i,
                        direction = direction,
                        step = step,
                        expected = total(),
                        repeatStart = now + HOLD_DELAY,
                        nextTick = now + HOLD_DELAY,
                    }
                end),
                mouseRelease = async:callback(function(e)
                    if e.button ~= 1 then return end
                    pressed = false
                    stopHold()
                    paint()
                end),
                focusGain = async:callback(function()
                    hovered = true
                    paint()
                end),
                focusLoss = async:callback(function()
                    hovered = false
                    paint()
                end),
            },
        }
    end

    local function inputCell(u)
        local n = vals[u.key]
        return {
            template = I.MWUI.templates.box,
            content = ui.content { {
                template = I.MWUI.templates.padding,
                content = ui.content { {
                    type = ui.TYPE.TextEdit,
                    template = I.MWUI.templates.textEditLine,
                    props = {
                        size = v2(INPUT_WIDTH, 0),
                        text = u.pad and string.format('%02d', n) or tostring(n),
                        textAlignH = ui.ALIGNMENT.Center,
                        textAlignV = ui.ALIGNMENT.Center,
                    },
                    events = {
                        textChanged = async:callback(function(text)
                            local digits = (tostring(text or ''):gsub('%D', ''))
                            pending[u.key] = tonumber(digits) or 0
                        end),
                        focusLoss = async:callback(function()
                            if next(pending) ~= nil then
                                flushPending()
                                publish()
                            end
                        end),
                    },
                }, }
            } },
        }
    end

    local function column(i)
        return {
            type = ui.TYPE.Flex,
            props = { arrange = ui.ALIGNMENT.Center },
            content = ui.content {
                stepButton(i, 1, '+'),
                INTERVAL,
                INTERVAL,
                inputCell(units[i]),
                INTERVAL,
                INTERVAL,
                stepButton(i, -1, '-'),
            },
        }
    end

    local function label(str)
        return {
            template = I.MWUI.templates.textNormal,
            props = {
                text = str,
                textAlignV = ui.ALIGNMENT.Center,
            },
        }
    end

    local function intervalH(width)
        return { props = { size = v2(width, 0) } }
    end

    local row = {}
    local hasDays = units[1].key == 'day'
    for i, u in ipairs(units) do
        if u.key == 'day' then
            row[#row + 1] = label(LABEL_DAYS)
            row[#row + 1] = INTERVAL
            row[#row + 1] = INTERVAL
            row[#row + 1] = column(i)
            if units[i + 1] then
                row[#row + 1] = intervalH(GAP_DAYS)
            end
        else
            if i > 1 and not (hasDays and i == 2) then
                row[#row + 1] = INTERVAL
                row[#row + 1] = label(SEPARATOR)
                row[#row + 1] = INTERVAL
            end
            row[#row + 1] = column(i)
        end
    end

    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content(row),
    }
end

I.Settings.registerRenderer(RENDERER_KEY, renderer)

return {
    engineHandlers = {
        onFrame = onFrame,
    },
}
