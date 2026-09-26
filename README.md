# Bor's Drop-in Utils (OpenMW)

My collection of drop-in modules that can be added to any OpenMW Lua projects for either performance or convenience.

**It's neither a playable mod nor a dependency for something else. It's just a collection of standalone modules for OpenMW Lua API others could add to their projects.**

**Free to use, modify and redistribute. No permissions required, but a mention of the project is appreciated.**

Core premise of this collection is that you can freely drop these lua files in your project and immediately use them. No weird configuration steps, no external dependencies, no bullshit - just `require()` them or register in the correct scope and you're good to go.

I believe that the accessibility of these utilities can and will make community mods better for everyone - developers and users alike.

## Table of Contents

TODO: fill it out

- [Bor's Drop-in Utils (OpenMW)](#bors-drop-in-utils-openmw)
  - [Table of Contents](#table-of-contents)
  - [General Utils](#general-utils)
    - [Settings Cache](#settings-cache)
    - [Hard Dependency Checker](#hard-dependency-checker)
    - [Message Picker](#message-picker)
    - [Yaml Folder Parser](#yaml-folder-parser)
  - [Settings Renderers](#settings-renderers)
    - [Text Set](#text-set)
    - [Multicheckbox](#multicheckbox)
  - [Other Neat Things](#other-neat-things)
    - [Virtual List](#virtual-list)
    - [Super Settings Renderers](#super-settings-renderers)
    - [Sorre's Settings Renderers](#sorres-settings-renderers)
  - [Credits](#credits)

## General Utils

### Settings Cache

> Scope: Any

Calling settings getters is expensive, but this cost can be minimized by subscribing to changes, storing all data in tables and querying tables instead. So this is basically a wrapper for your settings that doesn't really differ in interactions, but ultimately saves you performance.

Usage example:

```lua
local async = require("openmw.async")
local storage = require("openmw.storage")

local settingsCache = require("scripts.MyMod.utils.settingsCache")

local settings = settingsCache.new(
    storage.playerSection("SettingsMyMod_mySection"),
    async,
    function(key)
        if key == "someKey" then
            doSomething(settings.someKey)
        end
    end
)

print(settings.someKey)
```

### Hard Dependency Checker

> Scope: Player

This module checks a list of required dependencies and reports any missing plugin, premature interface call (load order issue), or outdated version during player-script initialization or any other early setup step.

When a dependency fails, it prints each problem to the log and shows a generic popup to the user so they can diagnose the issue by themselves.

Usage example:

```lua
local I = require("openmw.interfaces")

local deps = require("scripts.MyMod.utils.dependencyChecker")

deps.checkAll("My Cool and Awesome Mod", {
    {
        plugin = "FollowerDetectionUtil.omwscripts",
        interface = I.FollowerDetectionUtil,     -- required if the dependency must load before this mod
        minVersion = 3,                          -- optional
        curVersion = I.FollowerDetectionUtil     -- optional
            and I.FollowerDetectionUtil.version
            or -1
    },
    {
        plugin = "h3lp_yours3lf.omwscripts",
        interface = true, -- valid when load order does not matter
    }
})
```

The appearance (text, size) can be configured in the module itself.

<div align="center">

<img src="media/depCheck_message.png">

_How it looks in-game_

<img src="media/depCheck_log.png">

_How it looks in the logs_

</div>

### Message Picker

> Scope: Any

This module allows you to assign multiple l10n strings (usually, for messages) to a single name and randomly pick them later. Really cool for keeping your mod feedback fresh.

Usage example:

```yaml
# Yaml
msg_helloWorld_1: Hello
msg_helloWorld_2: World
msg_helloWorld_3: Hello world!
msg_helloWorld_4: Hello {who}!
```

```lua
-- Lua
local core = require("openmw.core")
local Messages = require("scripts.MyMod.utils.messagePicker")

local l10n = core.l10n("MyMod")
local messages = Messages(l10n)

messages.show(player, "msg_helloWorld")
messages.show(player, "msg_helloWorld", { who = "admin" })
```

### Yaml Folder Parser

> Scope: Any

> Note: if you want to add it to NPC or Creature, initialize it in Global script and then pass it via addScript() -> onInit chain. This will save you performance in a long run.

Interops are great, but making a separate mod to just add a table to an interface is not elegant and probably inconvenient for non-tech savvy part of the community. But creating one single plain text file makes way more sense. The only thing preventing me from adding it everywhere was not having a good boilerplate template. Until now :D

Usage example:

```lua
-- TODO
```

### Preset Manager

> Scope: Menu, Player, Global

> Note: it has to be created in the same script as the preset selector you will attach it to.

If you ever tried making preset selector, you know how annoying it is to set up them. This manager should be the one stop solution for this problem - once and for all, requiring just the keys and values from you with minimum boilerplate.

Usage example:

```lua
-- TODO
```

## Settings Renderers

> Scope: Menu or Player

> Note: if you want to edit the settings renderer, please rename it. This way, you won't override or get overrided by the other renderers with the same name based on the Load Order.

Just drop these renderers in your project, add them to your .omwscripts as MENU or PLAYER scripts and use them as any other settings renderer.

### Text Set

This is a fixed and modified versiong of AttendMeList from [Attend Me](https://www.nexusmods.com/morrowind/mods/51232). Basically it's a renderer for making lookup tables. By deafult it is designed for storing different record ids, but it can easily be modified to have custom behaviour for parsing input - from capitalizing text to adding your current cell id to the list if the input field is empty.

Usage example:

```lua
{
    key = "MY_BLACKLIST",
    name = "Blacklist NPC by ID",
    description = "Add NPC IDs to the blacklist.",
    renderer = "textSet_V1",
    default = {
        ["caius cosades"] = true,
        ["guar"] = true,
        ["vivec"] = true,
    },
    argument = {
        lower = true,   -- OPTIONAL, default: false. Default values don't get lowercased automatically
    },
},
```

This stores a table like:

```lua
{
    ["caius cosades"] = true,
    ["guar"] = true,
    ["vivec"] = true,
}
```

<div align="center">

<img src="media/renderers_textSet.png">

</div>

### MultiCheckbox

This is a modified version of Multiselect from [Sorre's Custom Renderers](https://www.nexusmods.com/morrowind/mods/59808) designed to make the renderer more readable, more pleasing to look at and require less boilerplate to set up. An arbitrary amount of checkboxes crammed into one single renderer/setting position.

Usage example:

```lua
{
    key = "MY_TOGGLES",
    name = "Feature Toggles",
    description = "Pick which features are active.",
    renderer = "multiCheckbox_V1",
    default = {
        optionA = true,
        optionB = false,
        optionC = true,
    },
    argument = {
        l10n = "MyMod",   -- OPTIONAL, assumes argument.keys = l10n keys
        keys = {          -- REQUIRED, keys not in defaults will be treated as false
            "optionA",
            "optionB",
            "optionC"
        },
        colorful = false,   -- OPTIONAL, default: false. Vanilla text colors vs green/red
    },
},
```

This stores a table like:

```lua
{
    optionA = true,
    optionB = false,
    optionC = true,
}
```

<div align="center">

<img src="media/renderers_multiCheckbox.png">

_Vanilla and colorful versions_

</div>

### MultiNumber

This is a modified version of Multinumber from [Sorre's Custom Renderers](https://www.nexusmods.com/morrowind/mods/59808) with only real difference in how you localize the labels - instead of passing localized strings, you just pass l10n key. Just like you do with OpenMW's renderers.

At its core it's just a single renderer that combines multiple Number fields in one place. Handy for grouping similar values together.

Usage example:

```lua
--- TODO
```

This stores a table like:

```lua
--- TODO
```

<div align="center">

<img src="media/renderers_multiNumber.png">

</div>

### MultiTextLine

The same thing as MultiNumber, but for text.

Usage example:

```lua
--- TODO
```

This stores a table like:

```lua
--- TODO
```

<div align="center">

<img src="media/renderers_multiTextLine.png">

</div>

### Two Column Set

An odd edgecase of a Text Set for cases when you want to synchronize 2 Text Sets without setting crutches all over the place. One column assigns keys `true`, the other - `false`. If the key is not present, its value is left as `nil`.

Usage example:

```lua
--- TODO
```

This stores a table like:

```lua
{
    argonian = true,  -- left column
    imperial = true,  -- left column
    breton = false,   -- right column
}
```

<div align="center">

<img src="media/renderers_twoColumnSet.png">

_Colorful version_

</div>

## Other Neat Things

These are not made by me, but they share the idea of this project.

### Virtual List

By Greatness7.  
[GitHub](https://github.com/Greatness7/openmw_virtual_list/tree/main)

This library provides a performant virtual-list widget for use in OpenMW-lua mods.

It takes care of a lot of annoying complexities so you don't have to. Things like:

- Creating the scrollbar and related buttons, with correct "native" look and feel.
- Ensuring the content and scrollbar are properly sized and synchronized together.
- Setting up all the conventional interaction events for mouse and keyboard input.
- Providing the necessary functions for programmatically manipulating the list UI.
- Exposing comprehensive type annotations so autocomplete and error checking work.
- Doing everything it does in a reasonably performant and memory conscious manner.

### Super Settings Renderers

By ownlyme  
[Nexus](https://www.nexusmods.com/morrowind/mods/59673)

Includes these settings renderers:

- Slider
- Color Picker
- Custom Keybind
- Custom Select
- Optional Checkbox
- Optional Select
- Optional Text Line
- Optional Number Input
- Optional Color Picker

## Credits

**Sosnoviy Bor** - Author  
**urm** - initial version of Text Set ([Attend Me](https://www.nexusmods.com/morrowind/mods/51232))  
**SorreFalcon** - initial versions of MultiNumber and MultiCheckbox ([Sorre's Custom Renderers](https://www.nexusmods.com/morrowind/mods/59808))
