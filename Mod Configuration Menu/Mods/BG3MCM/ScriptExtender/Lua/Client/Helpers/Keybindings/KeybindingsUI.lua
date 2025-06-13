local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

---@class KeybindingsUI
--- Handles UI-related functionality for keybindings in MCM

---@class KeybindingsUI
---@field GetAllKeybindings fun(self: KeybindingsUI): table<string, table>
---@field CreateKeybindingsPage fun(self: KeybindingsUI, dualPane: DualPane): any
---@field GetNativeKeybindings fun(self: KeybindingsUI): table[]

---@class KeybindingsUI
KeybindingsUI = {}


-- Local references for better performance
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local string_format = string.format
local pcall = pcall
local type = type
local Fallback_Value = Fallback.Value

--- Gets all keybinding settings from loaded mods
---@return table<string, table> A table of keybinding settings organized by mod UUID
function KeybindingsUI.GetAllKeybindings()
    local keybindings = {}

    for modUUID, modData in pairs(MCMClientState.mods) do
        local blueprint = modData.blueprint
        if blueprint then
            local modKeybindings = { ModUUID = modUUID, Actions = {} }
            local allSettings = blueprint:GetAllSettings()

            for settingId, setting in pairs(allSettings) do
                if setting:GetType() == "keybinding_v2" then
                    local currentBinding = modData.settingsValues and modData.settingsValues[settingId]
                    local keyboardBinding = nil

                    if currentBinding and currentBinding.Keyboard then
                        keyboardBinding = currentBinding.Keyboard
                        MCMDebug(2, "Using saved keyboard binding for setting: " .. settingId)
                    else
                        keyboardBinding = Fallback_Value(
                            setting.Default and setting.Default.Keyboard,
                            { Key = "", ModifierKeys = { "NONE" } }
                        )
                        MCMDebug(1, "Falling back to default keyboard binding for setting: " .. settingId)
                    end

                    local description = setting.GetDescription and setting:GetDescription() or ""
                    local tooltip = setting.GetTooltip and setting:GetTooltip() or ""
                    local enabled = Fallback_Value(
                        currentBinding and currentBinding.Enabled,
                        true
                    )
                    local defaultEnabled = Fallback_Value(
                        setting.Default and setting.Default.Enabled,
                        true
                    )

                    ---@type table
                    local action = {
                        ActionId = setting.Id or "",
                        ActionName = (setting.GetLocaName and setting:GetLocaName()) or "",
                        KeyboardMouseBinding = keyboardBinding,
                        DefaultEnabled = defaultEnabled,
                        Enabled = enabled,
                        DefaultKeyboardMouseBinding = Fallback_Value(
                            setting.Default and setting.Default.Keyboard,
                            { Key = "", ModifierKeys = { "NONE" } }
                        ),
                        Description = description,
                        Tooltip = tooltip,
                        ShouldTriggerOnRepeat = Fallback_Value(
                            setting.Options and setting.Options.ShouldTriggerOnRepeat,
                            false
                        ),
                        ShouldTriggerOnKeyUp = Fallback_Value(
                            setting.Options and setting.Options.ShouldTriggerOnKeyUp,
                            false
                        ),
                        ShouldTriggerOnKeyDown = Fallback_Value(
                            setting.Options and setting.Options.ShouldTriggerOnKeyDown,
                            true
                        ),
                        BlockIfLevelNotStarted = Fallback_Value(
                            setting.Options and setting.Options.BlockIfLevelNotStarted,
                            false
                        ),
                        PreventAction = Fallback_Value(
                            setting.Options and setting.Options.PreventAction,
                            true
                        ),
                        IsDeveloperOnly = Fallback_Value(
                            setting.Options and setting.Options.IsDeveloperOnly,
                            false
                        )
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
    local native = NativeKeybindings.GetByDeviceType("Keyboard")
    if not native or not native.Public then return result end
    local byCategory = {}
    for _, kb in ipairs(native.Public) do
        local cat = kb.CategoryName or "Uncategorized"
        byCategory[cat] = byCategory[cat] or {}
        table_insert(byCategory[cat], kb)
    end
    for category, kbs in pairs(byCategory) do
        local actions = {}
        for _, kb in ipairs(kbs) do
            local action = {
                ActionId = kb.EventName or "",
                ActionName = kb.EventName or "",
                Description = kb.Description or "",
                Bindings = kb.Bindings or {}
            }
            table_insert(actions, action)
        end
        table_insert(result, { CategoryName = category, Actions = actions })
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

    -- Create a dedicated "Hotkeys" menu section using the new interface
    local success, hotkeysGroup = pcall(function()
        return dualPane:AddMenuSectionWithContent(
            Ext.Loca.GetTranslatedString("hb20ef6573e4b42329222dcae8e6809c9ab0c") or "Hotkeys",
            Ext.Loca.GetTranslatedString("h1574a7787caa4e5f933e2f03125a539c1139") or "Configure your keybindings here",
            ClientGlobals.MCM_HOTKEYS or "MCM_HOTKEYS"
        )
    end)


    if not success or not hotkeysGroup then
        MCMDebug(1, "Failed to create hotkeys group in CreateKeybindingsPage")
        return {}
    end

    -- Create groups in advance to preserve order
    local nativeHotkeysGroup = hotkeysGroup:AddGroup("Native Keybindings")
    local MCMHotkeysGroup = hotkeysGroup:AddGroup("MCM Keybindings")

    -- Safely create the keybinding widget
    pcall(function()
        if type(KeybindingV2IMGUIWidget) == "table" and type(KeybindingV2IMGUIWidget.new) == "function" then
            local _keybindingWidget = KeybindingV2IMGUIWidget:new(MCMHotkeysGroup)
        end
    end)

    -- Safely create native keybindings
    pcall(function()
        if type(NativeKeybindingIMGUIWidget) == "table" and type(NativeKeybindingIMGUIWidget.new) == "function" then
            local nativeWidget = NativeKeybindingIMGUIWidget:new(nativeHotkeysGroup)
            nativeWidget:RefreshUI()
        end
    end)

    return hotkeysGroup
end

-- TODO: display native keybindings with Ext.ClientInput.GetInputManager():
-- InputDefinitions has all the actions (EventName entries) ID for bindings (EventID entries).
-- InputScheme.InputBindings[] has all currently-assigned bindings. InputScheme.RawToBinding[] also has it, not sure what's the difference though.
-- Native bindings can be keybinding (including mouse buttons) or gamepad, and there can be two bindings for each; front-end needs to be custom to handle this. We must have an adapter to map between the SE format and our data format. We need to determine what are keybindings and what are gamepad bindings, and ignore keybindings. We'll need to improve KeyPresentationMapping to handle mouse buttons.
-- We won't tackle editing any native bindings. We'll only be displaying them and displaying any conflict detection with MCM-defined bindings.

return KeybindingsUI
