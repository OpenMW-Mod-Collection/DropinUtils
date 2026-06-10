# Bor's Drop-in Utils (OpenMW)

My collection of drop-in modules that can be added to any projects for either performance or convenience.

**It's neither a playable mod nor a dependency for something else. It's just a collection of code snippets one could add to their project.**

Core premise of this collection is that you can freely drop these lua files in your project and immediately use them. No weird configuration steps, no bullshit - just `require()` them from the correct scope and you're good to go.

I believe that these utilities being accessible can and will make community mods better for everyone - developers and users alike. 

## Table of Contents

- [Settings Cache](#settings-cache)
- [Hard Dependency Checker](#hard-dependency-checker)
- [Message Picker](#message-picker)
- [Yaml Folder Parser](#yaml-folder-parser)
- [Other Neat Things](#other-neat-things)

### Settings Cache

> Scope: Any

Calling settings getters is expensive, but this cost can be minimized by subscribing to changes, storing all data in tables and querying tables instead. So this is basically a wrapper for your settings that doesn't really differ in interactions, but ultimately saves you performance.

Usage example:

```lua
-- async has to be passed from outer scope, yes
local async = require("openmw.async")
local storage = require("openmw.storage")

local settingsCache = require("scripts.MyMod.utils.settingsCache")

local settings = settingsCache.new(
  storage.playerSection("SettingsMyMod_section1"),
  async,
  -- optional onChange handler
  function(key)
    if key == "someKey" then doSomething(settings.someKey)
  end
)

print(settings.someKey)
```

### Hard Dependency Checker

> Scope: Player

This module lets you check all your registered dependencies at the player script initialization and potentially save you and your mod user a lot of headaches by printing everything in the logs in a human readable way.

Usage example:

```lua
local I = require("openmw.interfaces")

local deps = require("scripts.MyMod.utils.dependencies")
deps.checkAll("My Cool and Awesome Mod", {
    {
        plugin = "FollowerDetectionUtil.omwscripts",
        interface = I.FollowerDetectionUtil, -- if the dependency has to be initialized before the mod
        -- optional interface version checking
        minVersion = 3,
        currVersion = I.FollowerDetectionUtil
            and I.FollowerDetectionUtil.version
            or -1
    },
    {
        plugin = "h3lp_yours3lf.omwscripts",
        interface = true, -- if load order doesn't matter
    }
})
```

Demo:

-- TODO
<img src="media/dependencyCheckerMessage.png">
<img src="media/dependencyCheckerLog.png">

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
-- TODO
```

### Yaml Folder Parser

> Scope: Any

> Note: if you want to add it to NPC or Creature, initialize it in Global script and then pass it via addScript() -> onInit chain. This will save you performance in a long run.

Interops are great, but making a separate mod to just add a table to an interface is not elegant and probably inconvenient for non-tech savvy part of the community. But creating one single plain text file makes sense for this way more. The only thing preventing me from adding it everywhere was not having a good boilerplate template. Until now :D

Usage example:

```lua
-- TODO
```

## Other Neat Things

These are not made by me, but they share the idea I have here.

### [Virtual List](github.com/Greatness7/openmw_virtual_list/tree/main) by Greatness7

This library provides a performant virtual-list widget for use in OpenMW-lua mods.

It takes care of a lot of annoying complexities so you don't have to. Things like:    

- Creating the scrollbar and related buttons, with correct "native" look and feel.
- Ensuring the content and scrollbar are properly sized and synchronized together.
- Setting up all the conventional interaction events for mouse and keyboard input.
- Providing the necessary functions for programmatically manipulating the list UI.
- Exposing comprehensive type annotations so autocomplete and error checking work.
- Doing everything it does in a reasonably performant and memory conscious manner.

## Contributors

- Sosnoviy Bor