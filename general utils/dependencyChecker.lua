---@diagnostic disable: missing-fields, assign-type-mismatch, duplicate-doc-field
---@omw-context player
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
local core = require("openmw.core")
local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")
local v2 = util.vector2
local async = require("openmw.async")
local ambient = require("openmw.ambient")
local auxUi = require("openmw_aux.ui")

-- ============================================================
-- USAGE:
--   local deps = require("scripts.MyMod.utils.dependencyChecker")
--
--   deps.checkAll("MyMod", "Sosnoviy Bor's Mods, nil, {
--       {
--           plugin      = "OtherMod.esp",   -- REQUIRED, esp/omwaddon/omwscripts filename of the required plugin
--           interface   = I.OtherMod,       -- REQUIRED, The interface object retrieved from the other mod OR true if you don't care about the interface
--           minVersion  = 1.2,              -- OPTIONAL
--           curVersion  = I.OtherMod and I.OtherMod.version or -1, -- OPTIONAL
--       },
--   })
--
--   -- If any dependency check fails, prints the reasons to the log and
--   -- shows a generic "something went wrong" popup to the player.
-- ============================================================

local deps = {}

-- ============================================================
-- Configuration
-- ============================================================

local UI_WIDTH = 350
local DEFAULT_BODY = "Whoops! Seems like something went wrong!\n\n" ..
             "Check your logs by either pressing F10 or checking the openmw.log file.\n\n" ..
             "This is a user error and it shouldn't be reported to the mod author."

-- ============================================================
-- Color helpers
-- ============================================================

local colorFromGMST = function(gmst)
    local colorString = core.getGMST(gmst) or ""
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

local colors = {
    DEFAULT = colorFromGMST('fontcolor_color_normal'),
    BLACK   = util.color.rgb(0, 0, 0),
}

-- ============================================================
-- Button border/box templates
-- ============================================================

-- bro the button code is longer than the actual dependency checking code, but what will you do :'(

local buttonBorderSize = 4
local borderSideParts = {
    left = v2(0, 0),
    right = v2(1, 0),
    top = v2(0, 0),
    bottom = v2(0, 1),
}
local borderCornerParts = {
    top_left_corner = v2(0, 0),
    top_right_corner = v2(1, 0),
    bottom_left_corner = v2(0, 1),
    bottom_right_corner = v2(1, 1),
}
local buttonBorderPattern = 'textures/menu_button_frame_%s.dds'

local Templates = {}
Templates.TEXTURES = {}

local buttonBorderResources = {}
local buttonBorderPieces = {}

Templates.createTexture = function(path)
    if not Templates.TEXTURES[path] then
        Templates.TEXTURES[path] = ui.texture { path = path }
    end
    return Templates.TEXTURES[path]
end

Templates.intervalH = function(size)
    return {
        props = { size = v2(size, 0) },
    }
end

for k in pairs(borderSideParts) do
    buttonBorderResources[k] = Templates.createTexture(buttonBorderPattern:format(k))
    local horizontal = (k == 'top' or k == 'bottom')
    buttonBorderPieces[k] = {
        type = ui.TYPE.Image,
        props = {
            resource = buttonBorderResources[k],
            tileH = horizontal,
            tileV = not horizontal,
        }
    }
end

for k in pairs(borderCornerParts) do
    buttonBorderResources[k] = Templates.createTexture(buttonBorderPattern:format(k))
    buttonBorderPieces[k] = {
        type = ui.TYPE.Image,
        props = { resource = buttonBorderResources[k] },
    }
end

Templates.buttonBox = function()
    local template = {
        type = ui.TYPE.Container,
        content = ui.content {},
    }
    for k, v in pairs(borderSideParts) do
        local horizontal = (k == 'top' or k == 'bottom')
        local direction = horizontal and v2(1, 0) or v2(0, 1)
        template.content:add {
            template = buttonBorderPieces[k],
            props = {
                position = (direction + v) * buttonBorderSize,
                relativePosition = v,
                size = (v2(1, 1) - direction) * buttonBorderSize,
                relativeSize = direction,
            }
        }
    end
    for k, v in pairs(borderCornerParts) do
        template.content:add {
            template = buttonBorderPieces[k],
            props = {
                position = v * buttonBorderSize,
                relativePosition = v,
                size = v2(buttonBorderSize, buttonBorderSize),
            }
        }
    end
    template.content:add {
        external = { slot = true },
        props = {
            position = v2(buttonBorderSize, buttonBorderSize),
            relativeSize = v2(1, 1),
        }
    }
    return template
end

Templates.buttonBoxBgr = function(bgrAlpha)
    local template = auxUi.deepLayoutCopy(Templates.buttonBox())
    template.content:insert(1, {
        type = ui.TYPE.Image,
        props = {
            resource = Templates.createTexture('white'),
            color = colors.BLACK,
            alpha = bgrAlpha or 0,
            relativeSize = v2(1, 1),
            size = v2(buttonBorderSize * 2, buttonBorderSize * 2),
        }
    })
    return template
end

Templates.button = function(text, textSize, onClick, name, bgrAlpha)
    local element = ui.create {
        name = name,
        template = Templates.buttonBoxBgr(bgrAlpha),
        content = ui.content {
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = ui.content {
                    Templates.intervalH(8),
                    {
                        name = "btnText",
                        template = I.MWUI.templates.textNormal,
                        props = {
                            text = text,
                            textSize = textSize,
                            textColor = colors.DEFAULT,
                        },
                        userData = { colorable = true },
                    },
                    Templates.intervalH(8),
                }
            }
        },
        events = {},
        userData = { inFocus = false },
    }

    local btnText = element.layout.content[1].content[2]

    element.layout.events.focusLoss = async:callback(function()
        btnText.props.textColor = colors.DEFAULT
        element:update()
    end)
    element.layout.events.focusGain = async:callback(function()
        btnText.props.textColor = colors.DEFAULT_LIGHT
        element:update()
    end)
    element.layout.events.mousePress = async:callback(function()
        ambient.playSound('menu click')
        btnText.props.textColor = colors.DEFAULT_PRESSED
        element:update()
    end)
    element.layout.events.mouseRelease = async:callback(function()
        if onClick then onClick() end
        btnText.props.textColor = colors.DEFAULT_LIGHT
        element:update()
    end)

    return element
end

-- ============================================================
-- Dependency checking
-- ============================================================

---@class Dependency
---@field plugin      string   esp/omwaddon/omwscripts filename of the required plugin
---@field interface   any      The interface object retrieved from the other mod
---@field minVersion  number|nil
---@field curVersion  number|nil

---@param dep  Dependency
---@return     boolean, string|nil
local function checkDependency(dep)
    local checks = {
        {
            ok  = core.contentFiles.has(dep.plugin:lower()),
            msg = ("'%s' dependency not found."):format(dep.plugin)
        },
        {
            ok  = dep.interface ~= nil,
            msg = ("'%s' has to be loaded before this mod."):format(dep.plugin)
        },
        {
            ok  = not dep.minVersion or dep.curVersion >= dep.minVersion,
            msg = ("'%s' version too low. Required %s, found %s.")
                :format(dep.plugin, tostring(dep.minVersion), tostring(dep.curVersion))
        },
    }
    for _, c in ipairs(checks) do
        if not c.ok then
            return false, c.msg
        end
    end
    return true
end

-- ============================================================
-- Custom interactive message box
-- ============================================================

local activeMessageBox = nil

local function closeMessageBox()
    if activeMessageBox then
        activeMessageBox:destroy()
        activeMessageBox = nil
    end
end

local function showCustomInteractiveMessage(header, body)
    closeMessageBox()

    local layout = {
        layer = "Windows",
        template = I.MWUI.templates.boxSolidThick,
        props = {
            relativePosition = v2(0.5, 0.5),
            anchor = v2(0.5, 0.5),
            size = v2(500, 500),
            autoSize = false,
        },
        content = ui.content { {
            template = I.MWUI.templates.padding,
            content = ui.content { {
                template = I.MWUI.templates.padding,
                content = ui.content { {
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = false,
                        align = ui.ALIGNMENT.Center,
                        arrange = ui.ALIGNMENT.Center,
                    },
                    content = ui.content {
                        {
                            template = I.MWUI.templates.textHeader,
                            props = {
                                text = header,
                                textSize = 20,
                                textAlignH = ui.ALIGNMENT.Center,
                                textAlignV = ui.ALIGNMENT.Center,
                            },
                        },
                        {
                            template = I.MWUI.templates.interval,
                            props = { size = v2(0, 10) },
                        },
                        {
                            template = I.MWUI.templates.textParagraph,
                            props = {
                                text = body,
                                textSize = 16,
                                textAlignH = ui.ALIGNMENT.Center,
                                textAlignV = ui.ALIGNMENT.Center,
                                size = v2(UI_WIDTH, 0),
                            },
                        },
                        {
                            template = I.MWUI.templates.interval,
                            props = { size = v2(0, 16) },
                        },
                        Templates.button("OK", 16, closeMessageBox),
                    }
                } }
            } }
        } }
    }

    activeMessageBox = ui.create(layout)
end

-- ============================================================
-- Public API
-- ============================================================

---@param modName  string
---@param header string
---@param body? string
---@param depList  Dependency[]
deps.checkAll = function(modName, header, body, depList)
    local errors = {}
    for _, dep in ipairs(depList) do
        local ok, msg = checkDependency(dep)
        if not ok then
            errors[#errors + 1] = msg
        end
    end
    if #errors > 0 then
        print(("[%s] Dependency error:"):format(modName))
        for _, err in ipairs(errors) do
            print(("  - %s"):format(err))
        end

        showCustomInteractiveMessage(header, body or DEFAULT_BODY)
    end
end

return deps
