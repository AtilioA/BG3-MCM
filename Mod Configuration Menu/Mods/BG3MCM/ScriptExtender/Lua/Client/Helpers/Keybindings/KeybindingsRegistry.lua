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

function KeybindingsRegistry.BuildKeyboardPayload(binding, currentEnabled)
    return {
        Keyboard = {
            Key = binding.Key or binding,
            ModifierKeys = binding.ModifierKeys or {}
        },
        Enabled = currentEnabled
    }
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
--- @return boolean True if the action should be included (visible in the UI), false otherwise.
function KeybindingsRegistry:ShouldIncludeAction(action, options)
    if not self:ShouldIncludeDeveloperAction(action, options) then
        return false
    end
    return true
end

--- Registers keybindings for one or more mods.
--- Accepts an array of mod keybinding definitions and an optional options table.
--- The options table can be used to parameterize filtering.
--- This function always registers the actions (so that callbacks can be attached),
--- but marks each action with a 'visible' flag for listing purposes.
function KeybindingsRegistry.RegisterModKeybindings(modKeybindings, options)
    -- Default behavior: include developer keybindings only if developer mode is enabled.
    options = options or { includeDeveloper = Ext.Debug.IsDeveloperMode() }

    for _, mod in ipairs(modKeybindings) do
        registry[mod.ModUUID] = registry[mod.ModUUID] or {}
        for _, action in ipairs(mod.Actions) do
            registry[mod.ModUUID][action.ActionId] = {
                modUUID = mod.ModUUID,
                actionName = action.ActionName,
                actionId = action.ActionId,
                keyboardBinding = Fallback.Value(action.KeyboardMouseBinding, { Key = "", ModifierKeys = { "NONE" } }),
                enabled = Fallback.Value(action.Enabled, true),
                defaultKeyboardBinding = Fallback.Value(action.DefaultKeyboardMouseBinding,
                    { Key = "", ModifierKeys = { "NONE" } }),
                defaultEnabled = Fallback.Value(action.DefaultEnabled, true),
                shouldTriggerOnRepeat = Fallback.Value(action.ShouldTriggerOnRepeat, false),
                shouldTriggerOnKeyUp = Fallback.Value(action.ShouldTriggerOnKeyUp, false),
                shouldTriggerOnKeyDown = Fallback.Value(action.ShouldTriggerOnKeyDown, true),
                blockIfLevelNotStarted = Fallback.Value(action.BlockIfLevelNotStarted, false),
                preventAction = Fallback.Value(action.PreventAction, true),
                description = action.Description,
                isDeveloperOnly = Fallback.Value(action.IsDeveloperOnly, false),
                tooltip = action.Tooltip,
                -- Compute the visibility flag (for UI listing)
                visible = KeybindingsRegistry:ShouldIncludeAction(action, options)
            }
        end
    end
    keybindingsSubject:OnNext(registry)
end

--- Returns a filtered view of the registry (for listing in the UI) based on the provided options.
--- Actions that are registered but not visible (for example, developer-only actions when not in developer mode)
--- are omitted from this view.
function KeybindingsRegistry.GetFilteredRegistry(options)
    options = options or { includeDeveloper = Ext.Debug.IsDeveloperMode() }
    local filtered = {}
    for modUUID, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if binding.visible then
                filtered[modUUID] = filtered[modUUID] or {}
                filtered[modUUID][actionId] = binding
            end
        end
    end
    return filtered
end

--- Updates a binding for a given mod/action.
--- Accepts a table of updates that can include fields like 'Keyboard' and 'Enabled'.
function KeybindingsRegistry.UpdateBinding(modUUID, actionId, updates)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, string.format("No binding found to update for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    local bindingEntry = modTable[actionId]

    -- Update keyboard binding if provided.
    if updates.Keyboard ~= nil then
        bindingEntry.keyboardBinding = updates.Keyboard
    end

    -- Update enabled state if provided.
    if updates.Enabled ~= nil then
        bindingEntry.enabled = updates.Enabled
    end

    -- Persist the updated binding.
    MCMAPI:SetSettingValue(actionId, updates, modUUID)

    keybindingsSubject:OnNext(registry)
    return true
end

--- Registers a callback for a given binding.
--- Note that this uses the full registry (not the filtered view) so that callbacks
--- can be attached even for actions that are invisible in the UI.
function KeybindingsRegistry.RegisterCallback(modUUID, actionId, inputType, callback)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, string.format("No binding found to register callback for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardCallback = callback
    end

    -- It is not necessary to update the registry when registering a callback
    -- keybindingsSubject:OnNext(registry)
    return true
end

--- Evaluates if a binding should be triggered given the key event and the binding properties.
local function shouldTriggerBinding(e, binding)
    if e.Event == "KeyDown" and not binding.shouldTriggerOnKeyDown then
        return false
    elseif e.Event == "KeyUp" and not binding.shouldTriggerOnKeyUp then
        return false
    end

    if not binding.keyboardBinding then
        return false
    end

    if e.Repeat and not binding.shouldTriggerOnRepeat then
        return false
    end

    if binding.isDeveloperOnly and not Ext.Debug.IsDeveloperMode() then
        return false
    end

    if binding.enabled == false then
        return false
    end

    -- Check if we should block the keybinding when level is not started
    if binding.blockIfLevelNotStarted and MCMProxy.GameState == 'Menu' then
        MCMPrint(1, "Keybinding blocked because level not started: " .. binding.actionName)
        return false
    end

    return KeybindingManager:IsKeybindingPressed(e, {
        ScanCode = binding.keyboardBinding.Key,
        Modifier = binding.keyboardBinding.ModifierKeys
    })
end

function KeybindingsRegistry.NotifyConflict(keybindingStr)
    local conflictStr = VCString:InterpolateLocalizedMessage("hd4e656a649c14e638ab1cb4380ad714746ea", keybindingStr)
    NotificationManager:CreateIMGUINotification(
        "Keybinding_Conflict" .. Ext.Math.Random(),
        'warning',
        "Keybinding conflict",
        conflictStr,
        { duration = 10, dontShowAgainButton = false },
        ModuleUUID
    )
end

--- Determines if an action should be prevented based on the triggered bindings
--- @param e table The keyboard event
--- @param triggeredBindings table[]|nil Optional array of triggered bindings
--- @return boolean True if the action should be prevented, false otherwise
function KeybindingsRegistry.ShouldPreventAction(e, triggeredBindings)
    if e.PreventAction == nil then
        return false
    end

    if e.Key == "ESCAPE" then
        return false
    end

    -- Only check bindings if they were provided
    if triggeredBindings then
        -- If no bindings were triggered, don't prevent the action
        if #triggeredBindings == 0 then
            return false
        end

        -- Check if any triggered binding has PreventAction set to false
        -- If any binding has PreventAction = false, we don't prevent the action
        -- This will probably cause false positives, but it's better than preventing all actions or preventing none.
        for _, binding in ipairs(triggeredBindings) do
            if binding.preventAction == false then
                return false
            end
        end
    end

    -- By default, prevent the action
    return true
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

    if #triggered > 0 and KeybindingsRegistry.ShouldPreventAction(e, triggered) then
        e:PreventAction()
    end

    if #triggered > 1 then
        local binding = triggered[1]
        local keybindingStr = KeyPresentationMapping:GetKBViewKey(binding.keyboardBinding) or ""
        MCMWarn(0, "Keybinding conflict detected for: " .. keybindingStr)
        KeybindingsRegistry.NotifyConflict(keybindingStr)
    elseif #triggered == 1 then
        local binding = triggered[1]
        if binding.keyboardCallback then
            MCMPrint(1,
                "Dispatching keyboard callback for mod '" ..
                binding.modUUID .. "', action '" .. binding.actionName .. "'.")
            binding.keyboardCallback(e)
        else
            MCMWarn(0,
                "No keyboard callback found for mod '" .. binding.modUUID .. "', action '" .. binding.actionName .. "'.")
        end
    end
end

--- Exposes the registry's BehaviorSubject so others can subscribe.
function KeybindingsRegistry.GetSubject()
    return keybindingsSubject
end

--- Returns the full registry table.
function KeybindingsRegistry.GetRegistry()
    return registry
end
