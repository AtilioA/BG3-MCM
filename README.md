# BG3-MCM

The Mod Configuration Menu (MCM) is a framework that offers an in-game interface, allowing mod users to easily configure settings, that can be accessed through the ESC menu or by pressing the INSERT key (by default).

Mod authors can easily integrate their mods with MCM on their own, providing a consistent and user-friendly settings management system. This integration removes the need for users to manually edit JSON files and eliminates JSON management responsibilities that authors would otherwise have to handle.

## Features

- **Easy configuration**: Intuitive settings management without manual JSON edits.
- **Real-time changes**: Settings update instantly without needing to reload saves.
- **UI-agnostic**: Technically independent of IMGUI, ensuring usability even without UI visibility.
- **Save-safe**: Modifications are done in-memory and saved to JSON files, leaving save files untouched.
- **Error reduction**: Validate settings' values to minimize user errors.
- **Localization support**: Display strings in the user's preferred languages if translations are provided.
- **Uncluttered UI**: Consolidate mod settings into a single interface.
- **Multiple profiles**: Able to manage different settings for various playthroughs, and even export/restore them.

## Documentation

For detailed integration instructions, visit the [MCM documentation for mod authors](https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu).
