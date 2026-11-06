local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

---@class KeybindingsUI
--- Handles UI-related functionality for keybindings in MCM

---@class KeybindingsUI
---@field GetAllKeybindings fun(self: KeybindingsUI): table<string, table>
---@field CreateKeybindingsPage fun(dualPane: DualPaneController): ExtuiGroup
---@field GetNativeKeybindings fun(self: KeybindingsUI): table[]
---@field KeybindingWidget? KeybindingV2IMGUIWidget
---@field NativeKeybindingWidget? NativeKeybindingIMGUIWidget

---@class KeybindingsUI
KeybindingsUI = {}

KeybindingsUI.SearchBar = nil

-- Local references for better performance (desperate placebo stuff)
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local Fallback_Value = Fallback.Value

--- Resolves the current bindings, falling back to the setting defaults.
---@param setting table The keybinding setting
---@param currentBinding table|nil The saved binding values
---@return table|nil The keyboard binding
---@return table|nil The mouse binding
local function resolveKeybindingBindings(setting, currentBinding)
    if currentBinding then
        return currentBinding.Keyboard, currentBinding.Mouse
    end

    return Fallback_Value(
        setting:GetDefault() and setting:GetDefault().Keyboard,
        { Key = "", ModifierKeys = {} }
    ), setting:GetDefault() and setting:GetDefault().Mouse
end

--- Resolves the enabled and conflict flags for one keybinding setting.
---@param setting table The keybinding setting
---@param currentBinding table|nil The saved binding values
---@param options table|nil The setting options
---@return table The flag values
local function resolveKeybindingFlags(setting, currentBinding, options)
    return {
        Enabled = Fallback_Value(currentBinding and currentBinding.Enabled, true),
        DefaultEnabled = Fallback_Value(setting:GetDefault() and setting:GetDefault().Enabled, true),
        AllowConflict = Fallback_Value(
            currentBinding and currentBinding.AllowConflict,
            options and options.AllowConflict or false
        ),
        DefaultAllowConflict = Fallback_Value(options and options.AllowConflict, false)
    }
end

--- Builds the unified action table for one keybinding_v2 setting.
---@param setting table The keybinding setting
---@param settingIndex integer The setting position in the blueprint
---@param currentBinding table|nil The saved binding values
---@return table The unified action
local function buildKeybindingAction(setting, settingIndex, currentBinding)
    local settingId = setting:GetId()
    local options = setting:GetOptions()
    local flags = resolveKeybindingFlags(setting, currentBinding, options)
    local keyboardBinding, mouseBinding = resolveKeybindingBindings(setting, currentBinding)

    if currentBinding then
        MCMDebug(2, "Using saved keybinding for setting: %s", settingId)
    else
        MCMDebug(1, "Falling back to default keybinding for setting: %s", settingId)
    end

    return {
        ActionId = settingId or "",
        ActionName = (setting.GetLocaName and setting:GetLocaName()) or "",
        KeyboardMouseBinding = keyboardBinding,
        MouseBinding = mouseBinding,
        DefaultEnabled = flags.DefaultEnabled,
        Enabled = flags.Enabled,
        DefaultKeyboardMouseBinding = Fallback_Value(
            setting:GetDefault() and setting:GetDefault().Keyboard,
            { Key = "", ModifierKeys = {} }
        ),
        DefaultMouseBinding = Fallback_Value(
            setting:GetDefault() and setting:GetDefault().Mouse,
            { Button = 0, ModifierKeys = {} }
        ),
        Description = setting.GetDescription and setting:GetDescription() or "",
        Tooltip = setting.GetTooltip and setting:GetTooltip() or "",
        ShouldTriggerOnRepeat = Fallback_Value(options and options.ShouldTriggerOnRepeat, false),
        ShouldTriggerOnKeyUp = Fallback_Value(options and options.ShouldTriggerOnKeyUp, false),
        ShouldTriggerOnKeyDown = Fallback_Value(options and options.ShouldTriggerOnKeyDown, true),
        BlockIfLevelNotStarted = Fallback_Value(options and options.BlockIfLevelNotStarted, false),
        PreventAction = Fallback_Value(options and options.PreventAction, true),
        IsDeveloperOnly = Fallback_Value(options and options.IsDeveloperOnly, false),
        AllowConflict = flags.AllowConflict,
        DefaultAllowConflict = flags.DefaultAllowConflict,
        SkipCallback = Fallback_Value(options and options.SkipCallback, false),
        SortOrder = (setting.GetSortOrder and setting:GetSortOrder()) or settingIndex
    }
end

--- Gets all keybinding settings from loaded mods
---@return table<string, table> A table of keybinding settings organized by mod UUID
function KeybindingsUI.GetAllKeybindings()
    local keybindings = {}

    for modUUID, modData in pairs(MCMClientState.mods) do
        local blueprint = modData.blueprint
        if blueprint then
            local modKeybindings = {
                ModUUID = modUUID,
                Actions = {},
                KeybindingSortMode = blueprint:GetKeybindingSortMode() or KeybindingSortMode.DEFAULT
            }

            for settingIndex, setting in ipairs(blueprint:GetAllSettingsOrdered()) do
                if setting:GetType() == "keybinding_v2" then
                    local settingId = setting:GetId()
                    local currentBinding = modData.settingsValues and modData.settingsValues[settingId]
                    table.insert(modKeybindings.Actions, buildKeybindingAction(setting, settingIndex, currentBinding))
                end
            end

            if #modKeybindings.Actions > 0 then
                table.insert(keybindings, modKeybindings)
            end
        end
    end

    return keybindings
end

--- Gets native keybindings in unified model
---@return table[] unified native keybinding groups
function KeybindingsUI.GetNativeKeybindings()
    local result = {}
    local native = NativeKeybindings.GetAll()
    if not native or not native.Public then return result end
    local byCategory = {}
    for _, kBinding in ipairs(native.Public) do
        local category = kBinding.CategoryName or Ext.Loca.GetTranslatedString("hf3ff49ff1f6745f3baab4ed65795b61a300b")
            or "Uncategorized"
        byCategory[category] = byCategory[category] or {}
        table_insert(byCategory[category], kBinding)
    end
    for category, keybindings in pairs(byCategory) do
        local actions = {}
        for _, kBinding in ipairs(keybindings) do
            local bindings = {}
            for _, binding in ipairs(kBinding.Bindings or {}) do
                if binding.InputType == "Keyboard" or binding.InputType == "Mouse" then
                    table_insert(bindings, binding)
                end
            end
            local action = {
                ActionId = kBinding.EventName or "",
                ActionName = kBinding.EventName or "",
                Description = kBinding.Description or "",
                Bindings = bindings
            }
            if #bindings > 0 then table_insert(actions, action) end
        end
        if #actions > 0 then table_insert(result, { CategoryName = category, Actions = actions }) end
    end
    return result
end

--- Creates the keybindings page in the MCM UI
---@param dualPane DualPaneController The dual pane controller to add the keybindings to
---@return ExtuiGroup The created hotkeys group
function KeybindingsUI.CreateKeybindingsPage(dualPane)
    if KeybindingsUI.KeybindingWidget then
        KeybindingsUI.KeybindingWidget:Destroy()
        KeybindingsUI.KeybindingWidget = nil
    end
    local retiredNativeWidget = KeybindingsUI.NativeKeybindingWidget
    if retiredNativeWidget then
        KeybindingsUI.NativeKeybindingWidget = nil
        retiredNativeWidget:Destroy()
    end

    -- Create a dedicated "Hotkeys" menu section using the new interface
    local hotkeysGroup = dualPane:AddMenuSectionWithContent(
        Ext.Loca.GetTranslatedString("hb20ef6573e4b42329222dcae8e6809c9ab0c"),
        Ext.Loca.GetTranslatedString("h68e7c491c9ff4a02b2b099889c482fc323a0"),
        ClientGlobals.MCM_HOTKEYS
    )

    -- Create search bar group at the top
    local searchBarGroup = hotkeysGroup:AddGroup("Search Keybindings")

    -- Create and render the search bar instance
    KeybindingsUI.SearchBar = KeybindingSearchBar:new()
    KeybindingsUI.SearchBar:Render(searchBarGroup)

    -- Create groups in advance to preserve order
    local nativeHotkeysGroup = hotkeysGroup:AddGroup("Native Keybindings")
    local MCMHotkeysGroup = hotkeysGroup:AddGroup("MCM Keybindings")
    MCMHotkeysGroup:AddDummy(0, 2)
    nativeHotkeysGroup:AddDummy(0, 2)

    -- Create the keybinding widget
    KeybindingsUI.KeybindingWidget = KeybindingV2IMGUIWidget:new(MCMHotkeysGroup)

    -- Add a separator to separate the groups
    MCMHotkeysGroup:AddSeparator()
    MCMHotkeysGroup:AddDummy(0, 2)

    -- Create native keybindings; own the widget before rendering so a failed render is still retired
    KeybindingsUI.NativeKeybindingWidget = NativeKeybindingIMGUIWidget:new(nativeHotkeysGroup)
    KeybindingsUI.NativeKeybindingWidget:RefreshUI()

    return hotkeysGroup
end

return KeybindingsUI
