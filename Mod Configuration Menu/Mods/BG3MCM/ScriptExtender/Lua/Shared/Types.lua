---@meta

---@alias unknown nil|boolean|number|string|table|function|thread|userdata
---@alias StorageValue nil|boolean|number|string|table
---@alias MCMSettingValue StorageValue
---@alias RGBAColor number[]

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

---@class VisibleIfCondition
---@field SettingId string
---@field Operator string
---@field Value unknown

---@class VisibleIfConditionGroup
---@field Operator? string
---@field Conditions VisibleIfCondition[]

---@alias VisibleIfDefinition VisibleIfConditionGroup|nil

---@class ListV2Element
---@field name string
---@field enabled boolean

---@class ListV2SettingValue
---@field enabled boolean
---@field elements ListV2Element[]

---@class KeybindingKeyboardBinding
---@field Key string
---@field ModifierKeys string[]

---@class KeybindingMouseBinding
---@field Button number
---@field ModifierKeys string[]

---@class KeybindingV2Value
---@field Keyboard? KeybindingKeyboardBinding
---@field Mouse? KeybindingMouseBinding
---@field Enabled? boolean
---@field AllowConflict? boolean

---@class KeybindingRegistryEntry
---@field modUUID string
---@field actionName string
---@field actionId string
---@field keyboardBinding KeybindingKeyboardBinding
---@field mouseBinding KeybindingMouseBinding
---@field enabled boolean
---@field defaultKeyboardBinding KeybindingKeyboardBinding
---@field defaultMouseBinding KeybindingMouseBinding
---@field defaultEnabled boolean
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
---@field keyboardCallback? fun(e:EclLuaKeyInputEvent)
---@field keyDownCallback? fun(e:EclLuaKeyInputEvent)
---@field keyUpCallback? fun(e:EclLuaKeyInputEvent)

---@class KeybindingUIAction
---@field ModUUID string
---@field ActionName string
---@field ActionId string
---@field Enabled boolean
---@field DefaultEnabled boolean
---@field KeyboardMouseBinding KeybindingKeyboardBinding
---@field DefaultKeyboardMouseBinding KeybindingKeyboardBinding
---@field MouseBinding KeybindingMouseBinding
---@field DefaultMouseBinding KeybindingMouseBinding
---@field Description? string
---@field AllowConflict boolean
---@field Tooltip? string
---@field SortOrder? number

---@class KeybindingUIMod
---@field ModName string
---@field ModUUID string
---@field Actions KeybindingUIAction[]
---@field KeybindingSortMode string

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
