# Mod Configuration Menu (MCM) for Baldur's Gate 3

> In-game framework for managing mod settings and keybindings. Eliminates manual JSON edits for both players and mod authors.

## Overview

MCM is a **Baldur's Gate 3 Script Extender (BG3SE)** mod framework created by [Volitio](https://next.nexusmods.com/profile/Volitio) that provides a centralized in-game UI for managing mod configurations. It offers a seamless experience for both mod authors (who get a robust settings system without boilerplate) and players (who get a familiar, unified interface).

## Key Features

- **20k+ lines of code** so you don't have to write configuration systems
- **15 widget types**: checkboxes, sliders, dropdowns, color pickers, keybindings, lists, and more
- **Real-time saving**: settings update instantly without save reloads
- **Keybinding management** with automatic conflict detection
- **Multiple configuration profiles**: create, save, load, and delete profiles
- **Localization support** for translations
- **Event-driven API** for reactive settings
- **Validation** with detailed error messages

## For Mod Authors

MCM allows you to define your mod's settings via a simple JSON blueprint file. MCM handles:

- UI generation (no IMGUI code required)
- Settings persistence (no JSON file management)
- Validation and error reporting
- Keybinding registration and conflict resolution

```json
{
    "SchemaVersion": 1,
    "ModName": "My Awesome Mod",
    "Tabs": [
        {
            "TabId": "general",
            "TabName": "General",
            "Settings": [
                {
                    "Id": "enable_mod",
                    "Name": "Enable mod",
                    "Type": "checkbox",
                    "Default": true,
                    "Tooltip": "Toggle the main feature on/off"
                }
            ]
        }
    ]
}
```

Then in your Lua code:

```lua
local enabled = MCM.Get("enable_mod")
MCM.Set("enable_mod", false)
```

## Quick Start

1. Create an `MCM_blueprint.json` file alongside your mod's `meta.lsx`
2. Add MCM as a dependency in your mod's `meta.lsx`
3. Replace hardcoded values with `MCM.Get("settingId")` calls

See the [full documentation](https://github.com/AtilioA/BG3-MCM) for details.

## Links

- **[Nexus Mods](https://www.nexusmods.com/baldursgate3/mods/9162)** - Download MCM
- **[GitHub](https://github.com/AtilioA/BG3-MCM)** - Source code and issue tracker
- **[Wiki](https://github.com/AtilioA/BG3-MCM/blob/main/wiki.md)** - Full documentation
- **[Discord](https://discord.gg/DcS8c7KUa6)** - Community and support
- **[MCM GPT](https://chatgpt.com/g/g-69095e14686481918fb288289170e87b-mcmgpt)** - AI assistant for MCM questions

---

**Created with love by [Volitio](https://next.nexusmods.com/profile/Volitio) for the BG3 modding community.**
