---@omw-context player
local core = require("openmw.core")
local storage = require("openmw.storage")
local async = require("openmw.async")
local input = require("openmw.input")
local self = require("openmw.self")

local SettingsCache = require("scripts.DropinUtils.utils.settingsCache")
local deps = require("scripts.DropinUtils.utils.dependencyChecker")
local Messages = require("scripts.DropinUtils.utils.messagePicker")

-- ----------------------------------------------------------------------
-- settingsCache: mirror the renderers section into a plain table and log
-- whenever anything in it changes.
-- ----------------------------------------------------------------------
local rendererSection = storage.playerSection("SettingsDropinUtilsRenderers")
local settings = SettingsCache.new(rendererSection, async, function(key)
    print(("SettingsCache noticed a change to '%s'"):format(tostring(key)))
end)

-- ----------------------------------------------------------------------
-- dependencyChecker: demo call. Passing `true` as the interface means "just
-- check the plugin is present", which will succeed on a vanilla load order
-- since Morrowind.esm is always loaded. Swap this for a real dependency to
-- test the failure popup.
-- ----------------------------------------------------------------------
deps.checkAll("DropinUtils", "Drop-in Utils Demo", nil, {
    { plugin = "Morrowind.esm", interface = true },
})

-- ----------------------------------------------------------------------
-- messagePicker: random localized message, triggered on demand so it
-- doesn't spam the log. See l10n/en/DropinUtils.yaml for the message
-- key variants it picks between.
-- ----------------------------------------------------------------------
local l10n = core.l10n("DropinUtils")
local messages = Messages(l10n)

local function runSmokeTestReadout()
    print("--- smoke test readout ---")
    print(("volume=%s radius=%s"):format(
        tostring(settings.DEMO_NUMBERS and settings.DEMO_NUMBERS.volume),
        tostring(settings.DEMO_NUMBERS and settings.DEMO_NUMBERS.radius)))
end

async:newUnsavableSimulationTimer(0.1, runSmokeTestReadout)

return {
    engineHandlers = {
        onKeyPress = function(key)
            if key.code == input.KEY.I then
                messages.show(self, "DemoGreeting")
            end
        end,
    },
}
