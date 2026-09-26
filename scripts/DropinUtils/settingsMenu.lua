---@diagnostic disable: missing-fields
---@omw-context menu

local I = require("openmw.interfaces")

local SettingsPresets = require("scripts.DropinUtils.utils.presetManager")

local presets = SettingsPresets.register({
    selector = {
        section = "SettingsDropinUtilsPresets",
        key = "preset",
        isGlobal = false,
    },
    sections = {
        SettingsDropinUtilsDemoRenderers = { isGlobal = false },
    },
    presets = {
        Quiet = {
            SettingsDropinUtilsDemoRenderers = {
                DEMO_NUMBERS = { volume = 0.2, radius = 3 },
            },
        },
        Loud = {
            SettingsDropinUtilsDemoRenderers = {
                DEMO_NUMBERS = { volume = 1.0, radius = 15 },
            },
        },
    },
})

I.Settings.registerPage({
    key = "DropinUtils",
    l10n = "DropinUtils",
    name = "page_name",
    description = "page_desc",
})

I.Settings.registerGroup({
    page = "DropinUtils",
    key = "SettingsDropinUtilsPresets",
    l10n = "DropinUtils",
    name = "group_presets_name",
    permanentStorage = true,
    order = 0,
    settings = {
        {
            key = "preset", -- matches the key passed to the preset manager
            name = "preset_name",
            description = "preset_desc",
            renderer = "select",
            default = "Quiet",
            argument = {
                l10n = "none",
                items = presets.names(),
            },
        },
    },
})

I.Settings.registerGroup({
    page = "DropinUtils",
    key = "SettingsDropinUtilsDemoRenderers",
    l10n = "DropinUtils",
    name = "group_renderers_name",
    permanentStorage = true,
    order = 1,
    settings = {
        {
            key = "DEMO_TOGGLES",
            name = "toggles_name",
            description = "toggles_desc",
            renderer = "multiCheckbox_V1",
            default = {
                soundOn = true,
                questMarkers = false,
                particlesOn = true,
            },
            argument = {
                l10n = "DropinUtils",
                keys = {
                    "soundOn",
                    "questMarkers",
                    "particlesOn",
                },
                colorful = true,
            },
        },
        {
            key = "DEMO_TEXTLINES",
            name = "multiTextLine_name",
            description = "multiTextLine_desc",
            renderer = "multiTextLine_V1",
            default = {
                greeting = "Hello there",
                farewell = "Safe travels"
            },
            argument = {
                l10n = "DropinUtils",
                keys = {
                    "greeting",
                    "farewell",
                },
                width = 150,
            },
        },
        {
            key = "DEMO_NUMBERS",
            name = "multiNumber_name",
            description = "multiNumber_desc",
            renderer = "multiNumber_V1",
            default = {
                volume = 0.8,
                radius = 5
            },
            argument = {
                l10n = "DropinUtils",
                keys = {
                    "volume",
                    "radius"
                },
                min = {
                    volume = 0,
                    radius = 1
                },
                max = {
                    volume = 1,
                    radius = 20
                },
                width = 100,
            },
        },
        {
            key = "DEMO_TEXTSET",
            name = "textSet_name",
            description = "textSet_desc",
            renderer = "textSet_V1",
            default = {
                ["guar"] = true,
                ["white guar"] = true,
            },
            argument = {
                lower = true,
            },
        },
        {
            key = "DEMO_TWOCOLUMN",
            name = "twoColumnSet_name",
            description = "twoColumnSet_desc",
            renderer = "twoColumnSet_V1",
            default = {
                ["caius cosades"] = true,
                ["gaenor"] = false,
                ["fargoth"] = false,
            },
            argument = {
                width = 200,
                leftLabel = "Allowed",
                rightLabel = "Blocked",
                guide = true,
                colorful = true,
            },
        },
    },
})
