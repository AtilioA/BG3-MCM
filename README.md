# Baldur's Gate 3 Mod Configuration Menu
[![On Nexus Mods](https://img.shields.io/badge/Get_it_on-Nexus_Mods-orange?logo=nexus-mods&logoColor=white)](https://www.nexusmods.com/baldursgate3/mods/9162)
[![Documentation](https://img.shields.io/badge/Documentation-for_authors-blue?logo=bookstack&logoColor=white)](https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu)


The **Mod Configuration Menu (MCM)** is a framework for *Baldur's Gate 3* that provides an in-game interface for managing mod settings and keybindings. Users can access MCM via the ESC menu or by pressing `INSERT` (default). This eliminates the need for manual JSON edits, offering a seamless experience for both players and mod authors.

Mod authors can easily integrate their mods with MCM on their own, providing a consistent and user-friendly settings management system. This integration removes the need for users to manually edit JSON files and eliminates JSON management responsibilities that authors would otherwise have to handle.

## Features

- **Easy configuration**: Intuitive settings management without manual JSON edits.
- **Keybinding management** – Easily create and assign hotkeys with a familiar interface for users and built-in conflict resolution.
- **Real-time changes**: Settings update instantly without needing to reload saves.
- **UI-agnostic**: Technically independent of IMGUI, ensuring usability even without UI visibility.
- **Error reduction**: Validate settings' values to minimize user errors.
- **Uncluttered UI**: Consolidate mod settings into a single, dynamic and configurable interface, with smart sidebar and detach functionalities.
- **Save-safe**: Modifications are done in-memory and saved to JSON files, leaving save files untouched.
- **Localization support**: Display strings in the user's preferred languages if translations are provided.
- **Multiple profiles**: Able to manage different settings for various playthroughs, and even export/restore them.

## Documentation for authors

For detailed integration instructions, visit the [MCM documentation for mod authors](https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu).

## Contributing & support

MCM is open-source, and contributions are welcome! You can support the project by submitting **PRs** or making a **donation** via Ko-fi:

[![Support me on Ko-fi](https://raw.githubusercontent.com/doodlum/nexusmods-widgets/main/Ko-fi_40px_60fps.png)](https://ko-fi.com/volitio)

