local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

---@class KeybindingsUI
--- Handles UI-related functionality for keybindings in MCM

---@class KeybindingsUI
---@field GetAllKeybindings fun(self: KeybindingsUI): table<string, table>
---@field CreateKeybindingsPage fun(self: KeybindingsUI, dualPane: DualPane): any
---@field GetNativeKeybindings fun(self: KeybindingsUI): table[]
---@field KeybindingWidget? KeybindingV2IMGUIWidget

---@class KeybindingsUI
KeybindingsUI = {}

KeybindingsUI.SearchBar = nil

-- Local references for better performance (desperate placebo stuff)
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local Fallback_Value = Fallback.Value

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
            local allSettings = blueprint:GetAllSettingsOrdered()

            for settingIndex, setting in ipairs(allSettings) do
                local settingId = setting:GetId()
                if setting:GetType() == "keybinding_v2" then
                    local currentBinding = modData.settingsValues and modData.settingsValues[settingId]
                    local keyboardBinding = nil
                    local mouseBinding = nil

                    if currentBinding then
                        keyboardBinding = currentBinding.Keyboard
                        mouseBinding = currentBinding.Mouse
                        MCMDebug(2, "Using saved keybinding for setting: %s", settingId)
                    else
                        keyboardBinding = Fallback_Value(
                            setting:GetDefault() and setting:GetDefault().Keyboard,
                            { Key = "", ModifierKeys = {} }
                        )
                        mouseBinding = setting:GetDefault() and setting:GetDefault().Mouse
                        MCMDebug(1, "Falling back to default keybinding for setting: %s", settingId)
                    end

                    local description = setting.GetDescription and setting:GetDescription() or ""
                    local tooltip = setting.GetTooltip and setting:GetTooltip() or ""
                    local enabled = Fallback_Value(
                        currentBinding and currentBinding.Enabled,
                        true
                    )
                    local defaultEnabled = Fallback_Value(
                        setting:GetDefault() and setting:GetDefault().Enabled,
                        true
                    )
                    local allowConflict = Fallback_Value(
                        currentBinding and currentBinding.AllowConflict,
                        setting:GetOptions() and setting:GetOptions().AllowConflict or false
                    )
                    local defaultAllowConflict = Fallback_Value(
                        setting:GetOptions() and setting:GetOptions().AllowConflict,
                        false
                    )

                    ---@type table
                    local action = {
                        ActionId = settingId or "",
                        ActionName = (setting.GetLocaName and setting:GetLocaName()) or "",
                        KeyboardMouseBinding = keyboardBinding,
                        MouseBinding = mouseBinding,
                        DefaultEnabled = defaultEnabled,
                        Enabled = enabled,
                        DefaultKeyboardMouseBinding = Fallback_Value(
                            setting:GetDefault() and setting:GetDefault().Keyboard,
                            { Key = "", ModifierKeys = {} }
                        ),
                        DefaultMouseBinding = Fallback_Value(
                            setting:GetDefault() and setting:GetDefault().Mouse,
                            { Button = 0, ModifierKeys = {} }
                        ),
                        Description = description,
                        Tooltip = tooltip,
                        ShouldTriggerOnRepeat = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().ShouldTriggerOnRepeat,
                            false
                        ),
                        ShouldTriggerOnKeyUp = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().ShouldTriggerOnKeyUp,
                            false
                        ),
                        ShouldTriggerOnKeyDown = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().ShouldTriggerOnKeyDown,
                            true
                        ),
                        BlockIfLevelNotStarted = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().BlockIfLevelNotStarted,
                            false
                        ),
                        PreventAction = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().PreventAction,
                            true
                        ),
                        IsDeveloperOnly = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().IsDeveloperOnly,
                            false
                        ),
                        AllowConflict = allowConflict,
                        DefaultAllowConflict = defaultAllowConflict,
                        SkipCallback = Fallback_Value(
                            setting:GetOptions() and setting:GetOptions().SkipCallback,
                            false
                        ),
                        SortOrder = (setting.GetSortOrder and setting:GetSortOrder()) or settingIndex
                    }

                    table.insert(modKeybindings.Actions, action)
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
---@return any The created hotkeys group
function KeybindingsUI.CreateKeybindingsPage(dualPane)
    if not dualPane then
        MCMDebug(1, "Invalid dualPane parameter in CreateKeybindingsPage")
        return {}
    end

    if KeybindingsUI.KeybindingWidget then
        KeybindingsUI.KeybindingWidget:Destroy()
        KeybindingsUI.KeybindingWidget = nil
    end

    -- Create a dedicated "Hotkeys" menu section using the new interface
    local success, hotkeysGroup = pcall(function()
        return dualPane:AddMenuSectionWithContent(
            Ext.Loca.GetTranslatedString("hb20ef6573e4b42329222dcae8e6809c9ab0c"),
            Ext.Loca.GetTranslatedString("h68e7c491c9ff4a02b2b099889c482fc323a0"),
            ClientGlobals.MCM_HOTKEYS or "MCM_HOTKEYS"
        )
    end)


    if not success or not hotkeysGroup then
        MCMDebug(1, "Failed to create hotkeys group in CreateKeybindingsPage")
        return {}
    end

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

    -- Safely create the keybinding widget
    pcall(function()
        if type(KeybindingV2IMGUIWidget) == "table" and type(KeybindingV2IMGUIWidget.new) == "function" then
            KeybindingsUI.KeybindingWidget = KeybindingV2IMGUIWidget:new(MCMHotkeysGroup)
        end
    end)

    -- Add a separator to separate the groups
    MCMHotkeysGroup:AddSeparator()
    MCMHotkeysGroup:AddDummy(0, 2)

    -- Safely create native keybindings
    pcall(function()
        if type(NativeKeybindingIMGUIWidget) == "table" and type(NativeKeybindingIMGUIWidget.new) == "function" then
            local nativeWidget = NativeKeybindingIMGUIWidget:new(nativeHotkeysGroup)
            nativeWidget:RefreshUI()
        end
    end)

    return hotkeysGroup
end

return KeybindingsUI
