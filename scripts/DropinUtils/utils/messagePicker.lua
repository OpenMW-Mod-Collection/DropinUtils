---@omw-context local|global
-- Part of Bor's Drop-in Utils project: https://github.com/OpenMW-Mod-Collection/DropinUtils
-- ============================================================================
-- Messages — pick a random localized message from a numbered key series
-- ============================================================================
-- USAGE:
--   local core     = require("openmw.core")
--   local Messages = require("scripts.MyMod.utils.messagePicker")
--
--   local l10n = core.l10n("MyMod")
--   local messages = Messages(l10n)
--
--   messages.show(player, "ItemFound")
--
--   -- With context for placeholders in the localized string:
--   messages.show(player, "ItemFound", { itemName = "Ancient Ring" })
--
-- REQUIRES localization keys like:
--   ItemFound_1 = "You found something interesting."
--   ItemFound_2 = "Something catches your eye."
--   (numbered variants; the first missing index stops the search)
-- ============================================================================

---@alias L10nFunc fun(key: string, context?: table): string

---@class Messages
---@field show fun(player: any, messageKey: string, context?: table)

---Creates a new Messages instance.
---@param l10n L10nFunc
---@return Messages
local function Messages(l10n)

    ---@param messageKey string
    ---@param context? table
    ---@return string
    local function pickRandomMessage(messageKey, context)
        local messageOptions = {}
        local i = 1
        while true do
            local msgKey = ("%s_%d"):format(messageKey, i)
            local msg = l10n(msgKey, context)
            if msgKey ~= msg then
                messageOptions[#messageOptions + 1] = msg
            else
                break
            end
            i = i + 1
        end
        return messageOptions[math.random(#messageOptions)]
    end

    ---@param player openmw.GObject
    ---@param messageKey string
    ---@param context? table
    local function show(player, messageKey, context)
        local msg = pickRandomMessage(messageKey, context)
        player:sendEvent("ShowMessage", { message = msg })
    end

    return { show = show }
end

return Messages
