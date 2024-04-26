# \[ALPHA\] Mod Configuration Menu (BG3MCM)

I feel like I'm ready to share a preview of my Baldur's Gate 3 Mod Configuration Menu (`BG3MCM` or MCM) mod, currently in its alpha stage (not feature-complete), since it's already close to what I designed it to do and *can* already be used by mods.

**This tool allows authors to provide players with easy setting management and configuration for their mods, all from within the game**. This only requires mod authors to **integrate their mods with the MCM with a JSON schema file** in order for their settings to appear in the UI; an example schema is provided below. To write or read settings from the MCM, authors call the MCM API with the setting's ID as they have defined it in the schema.

Although I honestly don't expect many mods to benefit from this (SE mods are few :norb:), I at least hope that it will encourage :catnod: more authors to add settings to their mods, now that it is way easier for both them to do so and for players to manage them. I spent a few days setting up my first config structure when I started modding, and I'm sure at least a few authors have been put off by the complexity of it all. It doesn't have to be that way anymore.

## What is the MCM?

**MCM is a mod that provides an in-game user interface through SE's ImGui API to enable players to intuitively manage mod settings**. It supports a wide range of setting types, including integers, floats, checkboxes, text inputs, combos/dropdowns, sliders, radio buttons, etc. In the beta, it shall offer all the input types that SE's ImGui API supports (alpha already has almost all of them).

### Key Features

- **Centralized mod settings management** - all mod settings in one place;
- **Intuitive** and **user-friendly UI** built with ImGui - no manual JSON editing required (although allowed!);
- **Automatic saving and loading** of mod settings;
- **Support for multiple settings profiles**, allowing users to quickly switch between different configurations - users and authors can create, save, load and delete profiles;
- **Ability to reset individual settings** to default values in the UI.

For authors, specifically, MCM aims to accommodate at least two of the following use cases:

- **Mods that have settings fetched by scripts** for any kind of operation: most mods probably fit into this category - all of my mods and Fallen's mods do;
- **Mods that have bespoke ImGui windows**: while not exactly Configuration-related, MCM's API would allow inserting tabs into its own window as e.g. mods' subtabs - players would be able to access them all in one place without cluttering the UI with potential multiple windows;
- Additionally, something I'm considering is **mods that may want dynamic settings** (this is not yet remotely supported); for example, a mod that conditionally shows/adds or hides/removes settings based on events in the game. Realistically, there's not much of an use case for this right now, but it might be because of a lack of tooling. I might scrap this idea if it's not feasible, especially since working on `KeyInput` would probably be a better use of my time (Norb suddenly dropped this bomb lmao)

## How to use

Using the MCM is straightforward for both players and authors. Here's a quick guide on how to get started with the MCM:

### Players

1. Make sure you have the latest version of SE, at least v16 (or currently `devel`);
2. Make sure MCM is installed and enabled in your mod manager, loaded before any mods that use it, preferably at the top;
3. Launch the game and you should see the MCM window appear (this will be changed in the future). Mods will be loaded on `LevelGameplayStarted` or after a `reset` in the console when in-game;
4. Use the tab bar at the top to navigate between the different mods that have MCM support;
5. Adjust the settings for each mod to your liking. Each setting should have a tooltip or a description that explains what it does. The settings will be automatically saved when you change them;
6. ~~You can create and switch between different profiles to quickly change your mod configurations.~~ This has been temporarily disabled while I work on some refactorings, but has been implemented.

---

### Authors

The MCM is designed to work with a wide range of mods. However, mod authors need to specifically integrate their mods with the MCM in order for their settings to appear in the UI. This is done in two steps:

   1. Define the MCM JSON config schema for your mod's settings and place it alongside your mod's `meta.lsx` file - [Key aspects of the Schema](#key-aspects-of-the-schema)
      - It is also a good idea to define `BG3MCM` as a dependency in your `meta.lsx` file;
   2. Replace your mod's settings read/write logic with calls to the MCM API - [Using values from MCM](#using-values-from-mcm)
      - TIP: Allow global usage of BG3MCM by importing early in your scripts with `setmetatable(Mods[Ext.Mod.GetMod(ModuleUUID).Info.Directory], { __index = Mods.BG3MCM })`. Otherwise, prepend `Mods.BG3MCM` to all API calls.

MCM uses a JSON acting as schema to define the settings for each mod. This JSON allows the MCM to automatically generate a user-friendly interface for managing those settings within the game, and to validate the values set by the player.

#### Key aspects of the Schema

Some rambling first: the schema reflects a structure I designed as a POC/MVP inspired by FO4's MCM, and is not set in stone. Most importantly, it does not allow an indefinite amount of nesting, which is a limitation that I *might* rework in the future, although I'm kinda worried allowing such indefinite amount of nesting might require making the UI needlessly complicated/cluttered. I'm still studying what the ImGui API can do, most of the work on MCM until now was focused on file I/O and fumbling with client-server communication, so a final schema and UI design are still to be defined.

With that being said, I do feel like the current structure is already quite flexible and can accommodate almost any kind of mod config, even though certain mods might need to mold their settings a bit to fit it. The only configurable mod I've seen that should simply not be able to use MCM is Combat Extender, *but* then again that JSON file is quite big and mostly a sort of declarative JSON at that - it's primarily a data file used for defining behaviors or mechanics rather than regular user settings - that I'm not even sure it would make sense to have it in a menu like MCM's.

- **Organizational structure**: The schema defines a hierarchical organization using `Tabs` and `Sections`:
   1. `Tabs`: Serve as top-level organizational units in the MCM menu. Each tab can exclusively contain either `Sections` or standalone `Settings`.
      - `Sections`: Sub-divisions within tabs to group related settings.

   2. **`Settings`**:
        - `Id`: A unique string identifier for each setting, similar to a variable name in your code; used to reference the setting programmatically.
        - `Name`: The readable name of the setting as to be displayed in the MCM menu.
        - `Type`: Defines the data type and ultimately the UI representation of the setting, with supported types including `int`, `float`, `checkbox`, `text`, `enum`, `slider`, `radio`.
        - `Default`: Specifies the initial value of the setting used during initialization or when a reset is needed. Supports various data types (`integer`, `number`, `boolean`, `string`, `object`, `null`) depending on the setting type.
        - `Description` and `Tooltip`: Textual explanations of the setting's purpose and usage, where `Description` is visible next to the setting and `Tooltip` appears on hover. At least one of these fields is required.
        - `Options`: Additional parameters that tailor the setting's behavior, applicable to certain types like `enum`, `radio`, and `slider`. This includes:
          - `Choices`: Available options for `enum` and `radio` types.
          - `Min` and `Max`: Boundary values for types such as `slider`/`drag`.

A JSON 'meta' schema for the MCM config schema file is attached to this post. Although not mandatory, it is very recommended that you set it up, as you can easily validate your MCM schema files using VSCode by adding this JSON schema entry to your settings:

```json
"json.schemas": [
    {
        "fileMatch": [
            "MCM_schema*.json"
        ],
        "url": "path/to/mcm_meta_schema.json"
    }
],
```

Replace `url` with the mcm_meta_schema.json file path (e.g. where you place IDEHelpers or Osi.lua files). This should supposedly work with a URL, but I couldn't get it to work with any JSON schema URL, so I just use the local path.

#### Using values from MCM

After setting up the config schema, mod authors can access the values set by the player through the MCM API. After setting it up, it can be accessed from anywhere in a mod's code, allowing authors to easily read and write the values of their settings.

If you have a setting with the ID `MySetting`, you can access its value like this:

```lua
local mySettingValue = MCM:GetConfigValue("MySetting", ModuleUUID)
```

If you wish to programmatically change the value of a setting, you can do so like this:

```lua
MCM:SetConfigValue("MySetting", newValue, ModuleUUID)
```

This shall also trigger a validation step, ensuring that the new value is valid for the setting type, and when saving user input from the UI. Currently, it is only performed when loading settings from a JSON file. Invalid values will be replaced with the default value.

#### Validation in MCM

Validation is an important aspect of the MCM, ensuring that the values set adhere to the defined schema. The MCM performs validation checks when:

- Loading settings from a JSON file;
  - Other 'transitive' cases like switching between profiles (since ends up loading from JSON), etc.
- TODO: Programmatically setting values through the API.
- TODO: Processing user input from the UI;

Additionally, MCM creates files for each mod that uses it: these files will always be created with default values if they don't exist before trying to read them, and will be updated when settings are changed. They are located in `AppData\Local\Larian Studios\Baldur's Gate 3\Script Extender\BG3MCM\Profiles\<PROFILE>\<MOD_NAME>\settings.json`.

Keys not present in the schema will be removed from the JSON file, and invalid values will be replaced with the default value. New keys are introduced automatically when new settings are added to the schema.

In the future, the MCM config schema JSON files shall also be validated against aspects of the meta schema (this is done in a limited way already)

#### Example schema and usage

As an example, I showcase my Auto Send Food To Camp mod, which uses quite a few different ImGui widgets across 3 subtabs and demonstrates the flexibility provided by MCM's meta schema. A full working example can be found here: [Auto Send Food To Camp MCM](https://github.com/AtilioA/BG3-auto-send-food-to-camp/tree/MCM-integration/Auto%20Send%20Food%20To%20Camp/Mods/AutoSendFoodToCamp).

```json
{
    "SchemaVersion": 1,
    "Tabs": [
        {
            "TabName": "General",
            "TabId": "general",
            "Settings": [
                {
                    "Id": "enabled",
                    "Name": "Enable mod",
                    "Type": "checkbox",
                    "Default": true,
                    "Description": "Toggle the mod on/off without uninstalling it.",
                    "Tooltip": "Toggle the mod on/off"
                }
            ]
        },
        {
            "TabName": "Features",
            "TabId": "features",
            "Sections": [
                {
                    "SectionId": "food_management",
                    "SectionName": "Food management",
                    "Settings": [
                        {
                            "Id": "move_food",
                            "Name": "Move food to camp chest",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether food items to the camp chest"
                        },
                        {
                            "Id": "move_beverages",
                            "Name": "Move beverages to camp chest",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to move beverages to the camp chest"
                        },
                        {
                            "Id": "move_bought_food",
                            "Name": "Move purchased food to camp chest",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to move purchased food to the camp chest"
                        },
                        {
                            "Id": "minimum_food_to_keep",
                            "Name": "Minimum food to keep",
                            "Type": "int",
                            "Default": 0,
                            "Tooltip": "Minimum number of food items to keep in inventory after moving to camp chest"
                        },
                        {
                            "Id": "maximum_rarity",
                            "Name": "Maximum rarity to send food",
                            "Type": "enum",
                            "Default": "Comamon",
                            "Options": {
                                "Choices": [
                                    "Common",
                                    "Uncommon",
                                    "Rare",
                                    "Epic",
                                    "Legendary"
                                ]
                            },
                            "Tooltip": "Maximum rarity of the food item to send to camp chest"
                        },
                        {
                            "Id": "send_existing_food",
                            "Name": "Manage existing food",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to send existing food items in inventory"
                        },
                        {
                            "Id": "nested_containers",
                            "Name": "Search in nested containers",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to search for food in nested containers inside player inventories"
                        },
                        {
                            "Id": "create_supply_sack",
                            "Name": "Create supply sack in chest",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to create a single supply sack in the camp chest if it doesn't exist"
                        },
                        {
                            "Id": "send_to_supply_sack",
                            "Name": "Send food to supply sack",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to send food items to the supply sack in the camp chest"
                        }
                    ]
                },
                {
                    "SectionId": "ignore_settings",
                    "SectionName": "Ignore settings",
                    "Settings": [
                        {
                            "Id": "ignore_healing",
                            "Name": "Ignore healing items",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to ignore healing food items"
                        },
                        {
                            "Id": "ignore_weapons",
                            "Name": "Ignore weapons",
                            "Type": "checkbox",
                            "Default": false,
                            "Tooltip": "Whether to ignore food items that are weapons"
                        },
                        {
                            "Id": "ignore_user_defined",
                            "Name": "Ignore user defined items",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to ignore items from a user-defined item list"
                        },
                        {
                            "Id": "ignore_wares",
                            "Name": "Ignore wares",
                            "Type": "checkbox",
                            "Default": true,
                            "Tooltip": "Whether to ignore food items marked as wares"
                        }
                    ]
                }
            ]
        },
        {
            "TabName": "Debug",
            "TabId": "debug",
            "Settings": [
                {
                    "Id": "debug_level",
                    "Name": "Debug level",
                    "Type": "slider",
                    "Default": 0,
                    "Description": "Debug level for the mod, used mainly for determining which messages to print",
                    "Options": {
                        "Min": 0,
                        "Max": 2
                    }
                }
            ]
        }
    ]
}
```

---

Here are some milestones I have in mind; some of these are minor things that were added/pushed back after some recent major refactoring:

### Wishlist for Beta

- [ ] Add support for more setting types, such as color pickers, and any others that I have omitted from SE's API (it already has almost all of them though); also implement some custom ones (such allowing arrays in the schema and mapping to some sort of augmented widget?);
- [ ] Reintroduce profile functionality and implement profile deletion;
- [ ] Decide on a final schema structure and UI design;
- [ ] Allow modders to define their own ImGui stuff and insert it in the MCM window;
- [ ] At least consider adding support for dynamic settings, allowing mods to conditionally show or hide settings based on Lua scripts?
- [ ] Make the `settings.json` files follow the schema structure instead of flattening it;
  - [ ] Allow duplicate ids if in different tabs/sections, would require a slight change in the API
- [ ] Write automated tests for the validation logic?
- [ ] Expose 'reset to default' functionality in the UI;
- [ ] Investigate emitting API events, when settings are saved a message is sent to the client just to be sent back to the servers, since server to server communication is not possible lol
- [ ] Do some additional refactoring now that client-server communication works;

### Wishlist for 1.0

- [ ] Think about what to do with `KeyInput`;
- [ ] Maybe add localization support (should be easy to implement but eh would make writing MCM schema files annoying);
- [ ] Proper documentation (GitHub Wiki, etc all sorts of busywork rip me);
- [ ] Improve the UI's organization and appearance, also when it should be shown (probably using `KeyInput`);

### Beyond 1.0


All work is in progress and subject to change:tm:. **Any feedback is welcome, and I hope this tool will be useful for mod authors and players alike :catnod:**
