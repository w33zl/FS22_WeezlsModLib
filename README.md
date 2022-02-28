# Weezl's Mod Lib for Farming Simulator 22

This library contains quality of life functions to ease development of script (LUA) based mods for Farming Simulator 22 (FS22).


## Contents/features
* [ModHelper](#modhelper) - A base class/bootstrapper for any script based mod
* **LogHelper** - Quality of life class/library for logging and debugging
* **DebugHelper** - Extension to the LogHelper that is particularly useful when debugging
* **FillTypeManagerExtension** - Extension class to the FillTypeManager that enables your mod to add custom fill types and height types (material that can be dumped to ground) 


## Like the work I do?
I love to hear you feedback so please check out my [Facebook](https://www.facebook.com/w33zl). If you want to support me you can become my [Patron](https://www.patreon.com/wzlmodding) or buy me a [Ko-fi](https://ko-fi.com/w33zl) :heart:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/X8X0BB65P) [![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dwzlmodding%3F%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/wzlmodding?)


## ModHelper

#### 1. Copy the `"lib"` folder to the root folder of your mod

#### 2. Create a script file (if you haven't already), e.g. *"YourModName.lua"*, with the following content:
```lua
YourModName = Mod:init() -- "YourModName" is your actual mod object/instance, ready to use
```

#### 3. Add this line to the `<extraSourceFiles>` section of your *ModDesc.xml* file:
```xml
<sourceFile filename="lib/ModHelper.lua" />
```

It shoud look something like this:
```xml
<extraSourceFiles>
    <sourceFile filename="lib/ModHelper.lua" /><!-- Must be above your mod lua file -->
    <sourceFile filename="YourModName.lua" />
</extraSourceFiles>
```

#### 4. Now your mod is ready to be used, e.g. you could att these lines to "YourModName.lua" to print a text when your mod is loaded:

```lua
function YourModName:loadMap(filename) 
    print("Mod loaded")
end
```

Some more events that can be used similar to loadMap:
* `loadMapFinished()` - This event execute *after* the actual map has finished loading and *before* other mods are loaded (with `loadMap`)
* `startMission()` - When user selects "Start", execute after both `loadMapFinished` and `loadMap`
* `update(dt)` - Looped as long game is running (*CAUTION!* Anything in here will constantly execute and might severly affect performance)

### Built-in properties in your mod
The `Mod` class will automatically add a number of field/properties to your for convinient access, e.g.
```lua
local authorsName = myMod.author -- The name is automatically read from the modDesc file
```

* `dir` - The mod directory, i.e. folder or zip file on disk (same as `g_currentModDirectory`)
* `name` - The name of your mod (i.e. `g_currentModName`)
* `title` - The english title of your mod (from modDesc.xml)
* `author` - The author node from modDesc.xml
* `version` - The version node from your modDesc.xml

### Built-in functions in your mod
The `Mod` class will automatically add a number of functions/methods to your mod for convinient access, e.g.
```lua
local aSound = myMod:loadSound("SoundName", "/sounds/aSound.ogg")
```

* `loadSound(name, relativeFilename)` - Loads a sound/sample (automatically appends the mod.dir path to the filename) 
* `trySource(relativeFilename, [silentFail])` - Will try to load/source a LUA script file if that file exists, automatically adding mod.dir path to the filename, and with optional "silent fail" (no error message if file is missing)

### Automatic support for user config file
Built-in (semi-)automatic support to read and write user settings.
