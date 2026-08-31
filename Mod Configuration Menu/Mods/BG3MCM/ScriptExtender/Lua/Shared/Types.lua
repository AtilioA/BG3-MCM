---@meta

---@alias unknown nil|boolean|number|string|table|function|thread|userdata
---@alias StorageValue nil|boolean|number|string|table
---@alias MCMSettingValue StorageValue
---@alias RGBAColor number[]

---Controls how a dynamic setting is stored and synchronized.
---@class StorageConfig
---@field SyncToClient? boolean
---@field SyncToServer? boolean
---@field Server? boolean
---@field Client? boolean
---@field WriteableOnServer? boolean
---@field WriteableOnClient? boolean
---@field Persistent? boolean
---@field SyncOnTick? boolean
---@field SyncOnWrite? boolean
---@field DontCache? boolean

---Defines one condition controlling setting visibility.
---@class VisibleIfCondition
---@field SettingId string
---@field Operator string
---@field Value unknown

---Combines multiple setting visibility conditions.
---@class VisibleIfConditionGroup
---@field Operator? string
---@field Conditions VisibleIfCondition[]

---@alias VisibleIfDefinition VisibleIfConditionGroup|nil

---Represents one configurable list entry.
---@class ListV2Element
---@field name string
---@field enabled boolean

---Stores the enabled state and entries of a list_v2 setting.
---@class ListV2SettingValue
---@field enabled boolean
---@field elements ListV2Element[]

---Represents an assigned keyboard key and its modifiers.
---@class KeybindingKeyboardBinding
---@field Key string
---@field ModifierKeys string[]

---Represents an assigned mouse button and its keyboard modifiers.
---@class KeybindingMouseBinding
---@field Button number
---@field ModifierKeys string[]

---Stores a complete keyboard-backed keybinding_v2 value.
---@class KeybindingV2KeyboardValue
---@field Keyboard KeybindingKeyboardBinding
---@field Enabled? boolean
---@field AllowConflict? boolean

---Stores a complete mouse-backed keybinding_v2 value.
---@class KeybindingV2MouseValue
---@field Mouse KeybindingMouseBinding
---@field Enabled? boolean
---@field AllowConflict? boolean

---@alias KeybindingV2Value KeybindingV2KeyboardValue|KeybindingV2MouseValue

---Stores runtime state and callbacks for one registered action.
---@class KeybindingRegistryEntry
---@field modUUID string
---@field actionName string
---@field actionId string
---@field keyboardBinding? KeybindingKeyboardBinding
---@field mouseBinding? KeybindingMouseBinding
---@field enabled boolean
---@field defaultKeyboardBinding? KeybindingKeyboardBinding
---@field defaultMouseBinding? KeybindingMouseBinding
---@field defaultEnabled boolean
---@field defaultAllowConflict boolean
---@field shouldTriggerOnRepeat boolean
---@field shouldTriggerOnKeyUp boolean
---@field shouldTriggerOnKeyDown boolean
---@field blockIfLevelNotStarted boolean
---@field preventAction boolean
---@field description? string
---@field isDeveloperOnly boolean
---@field tooltip? string
---@field allowConflict boolean
---@field skipCallback boolean
---@field sortOrder? number
---@field visible boolean
---@field keyboardCallback? fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent)
---@field keyDownCallback? fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent)
---@field keyUpCallback? fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent)

---Provides the keybinding action data rendered by the MCM UI.
---@class KeybindingUIAction
---@field ModUUID string
---@field ActionName string
---@field ActionId string
---@field Enabled boolean
---@field DefaultEnabled boolean
---@field KeyboardMouseBinding KeybindingKeyboardBinding|string
---@field DefaultKeyboardMouseBinding? KeybindingKeyboardBinding
---@field MouseBinding KeybindingMouseBinding
---@field DefaultMouseBinding KeybindingMouseBinding
---@field Description? string
---@field AllowConflict boolean
---@field DefaultAllowConflict boolean
---@field Tooltip? string
---@field SortOrder? number

---Groups rendered keybinding actions for one mod.
---@class KeybindingUIMod
---@field ModName string
---@field ModUUID string
---@field Actions KeybindingUIAction[]
---@field KeybindingSortMode string

---Contains normalized blueprint data ready for construction.
---@class PreprocessedBlueprintData
---@field ModUUID string
---@field SchemaVersion number
---@field Optional boolean
---@field ModName? string
---@field ModDescription? string
---@field KeybindingSortMode string
---@field Handles? table
---@field Tabs BlueprintTab[]
---@field Sections BlueprintSection[]
---@field Settings BlueprintSetting[]

return {}
