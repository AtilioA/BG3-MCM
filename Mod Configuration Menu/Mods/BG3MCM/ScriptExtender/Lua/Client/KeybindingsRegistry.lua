---@alias ActionFilterOptions { includeDeveloper: boolean? }

local RX = {
    BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
}

KeybindingsRegistry = {}

-- Internal registry: a table mapping mod UUID to its actions.
local registry = {}

-- A BehaviorSubject that always holds the current registry state.
local keybindingsSubject = RX.BehaviorSubject.Create(registry)

-- Utility functions for normalizing bindings.
function KeybindingsRegistry.NormalizeKeyboardBinding(binding)
    if binding == nil or binding == "" then
        return ""
    end
    if type(binding) ~= "table" or not binding.Key then
        MCMWarn(0, "Invalid keyboard binding, expected a table with a 'Key' field.")
        return nil
    end
    local mod = (binding.ModifierKeys and type(binding.ModifierKeys) == "table" and #binding.ModifierKeys > 0)
        and table.concat(binding.ModifierKeys, "+"):upper() or "NONE"
    local scan = binding.Key:upper()
    if mod ~= "NONE" then
        return mod .. "+" .. scan
    else
        return scan
    end
end

--- Determines if a developer-only action should be included based on the provided options.
--- @param action table The action to evaluate for inclusion.
--- @param options ActionFilterOptions|nil The options that may affect inclusion.
function KeybindingsRegistry:ShouldIncludeDeveloperAction(action, options)
    local includeDeveloper = options and options.includeDeveloper
    return not (action.IsDeveloperOnly and not includeDeveloper)
end

--- Determines if an action should be included based on the provided options.
--- 'options' can include { includeDeveloper = true/false }
--- @param action table The action to evaluate for inclusion.
--- @param options ActionFilterOptions|nil The options that may affect inclusion.
--- @return boolean True if the action should be included, false otherwise.
function KeybindingsRegistry:ShouldIncludeAction(action, options)
    if not self:ShouldIncludeDeveloperAction(action, options) then
        return false
    end

    return true
end

--- Registers keybindings for one or more mods.
--- Accepts an array of mod keybinding definitions and an optional options table.
--- The options table can be used to parameterize filtering
function KeybindingsRegistry.RegisterModKeybindings(modKeybindings, options)
    -- Default behavior: include developer keybindings only if developer mode is enabled.
    options = options or { includeDeveloper = Ext.Debug.IsDeveloperMode() }

    for _, mod in ipairs(modKeybindings) do
        registry[mod.ModUUID] = registry[mod.ModUUID] or {}
        for _, action in ipairs(mod.Actions) do
            if KeybindingsRegistry:ShouldIncludeAction(action, options) then
                registry[mod.ModUUID][action.ActionId] = {
                    modUUID = mod.ModUUID,
                    actionName = action.ActionName,
                    actionId = action.ActionId,
                    keyboardBinding = action.KeyboardMouseBinding,
                    defaultKeyboardBinding = action.DefaultKeyboardMouseBinding,
                    ShouldTriggerOnRepeat = action.ShouldTriggerOnRepeat,
                    ShouldTriggerOnKeyUp = action.ShouldTriggerOnKeyUp,
                    ShouldTriggerOnKeyDown = action.ShouldTriggerOnKeyDown,
                    description = action.Description,
                    tooltip = action.Tooltip
                }
            end
        end
    end
    keybindingsSubject:OnNext(registry)
end

--- Updates a binding for a given mod/action.
function KeybindingsRegistry.UpdateBinding(modUUID, actionId, newBinding, inputType)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, string.format("No binding found to update for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardBinding = newBinding
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Registers a callback for a given binding.
function KeybindingsRegistry.RegisterCallback(modUUID, actionId, inputType, callback)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, string.format("No binding found for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardCallback = callback
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Evaluates if a binding should be triggered given the key event and the binding properties.
local function shouldTriggerBinding(e, binding)
    if e.Event == "KeyDown" and not binding.ShouldTriggerOnKeyDown then
        return false
    elseif e.Event == "KeyUp" and not binding.ShouldTriggerOnKeyUp then
        return false
    end

    if not binding.keyboardBinding then
        return false
    end

    if e.Repeat and not binding.ShouldTriggerOnRepeat then
        return false
    end

    if binding.Options and binding.Options.IsDeveloperOnly and not Ext.Debug.IsDeveloperMode() then
        return false
    end

    return KeybindingManager:IsKeybindingPressed(e, {
        ScanCode = binding.keyboardBinding.Key,
        Modifier = binding.keyboardBinding.ModifierKeys
    })
end

--- Dispatch a keyboard event.
function KeybindingsRegistry.DispatchKeyboardEvent(e)
    local triggered = {}

    -- Collect all bindings that match the key event.
    for _modUUID, actions in pairs(registry) do
        for _actionId, binding in pairs(actions) do
            if shouldTriggerBinding(e, binding) then
                table.insert(triggered, binding)
            end
        end
    end

    if #triggered ~= 0 then
        if e.PreventAction then
            e:PreventAction()
        end
    end

    if #triggered > 1 then
        local binding = triggered[1]
        local keybindingStr = KeyPresentationMapping:GetKBViewKey(binding.keyboardBinding) or ""
        NotificationManager:CreateIMGUINotification(
            "Keybinding_Conflict" .. Ext.Math.Random(),
            'warning',
            "Keybinding conflict",
            "Keybinding " .. keybindingStr .. " is bound to multiple actions.\nOpen MCM and rebind conflicting keys.",
            { duration = 10, dontShowAgainButton = false },
            ModuleUUID
        )
        MCMClientState:ToggleMCMWindow(false)
        if binding.keyboardCallback then
            binding.keyboardCallback(e)
        end
    elseif #triggered == 1 then
        local binding = triggered[1]
        if binding.keyboardCallback then
            MCMPrint(1, "Dispatching keyboard binding for mod '" ..
                binding.modUUID .. "', action '" .. binding.actionName .. "'.")
            binding.keyboardCallback(e)
        end
    end
end

--- Exposes the registry’s BehaviorSubject so others can subscribe.
function KeybindingsRegistry.GetSubject()
    return keybindingsSubject
end

--- Returns the full registry table.
function KeybindingsRegistry.GetRegistry()
    return registry
end
