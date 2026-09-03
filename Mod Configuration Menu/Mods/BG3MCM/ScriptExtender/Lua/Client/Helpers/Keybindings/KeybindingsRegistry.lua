---@alias ActionFilterOptions { includeDeveloper: boolean? }

local RX = {
    BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
}

KeybindingsRegistry = {}

-- Internal registry: a table mapping mod UUID to its actions.
local registry = {}

-- A BehaviorSubject that always holds the current registry state.
local keybindingsSubject = RX.BehaviorSubject.Create(registry)

---@type table<integer, KeybindingRegistryEntry[]>
local activeMouseBindings = {}

---Canonicalizes a complete keybinding value to one active device or one empty keyboard binding.
---@param value KeybindingV2Value|nil
---@param fallbackEnabled? boolean
---@param fallbackAllowConflict? boolean
---@return KeybindingV2Value
function KeybindingsRegistry.CanonicalizeValue(value, fallbackEnabled, fallbackAllowConflict)
    return KeybindingManager:CanonicalizeV2Value(value, {
        Enabled = fallbackEnabled,
        AllowConflict = fallbackAllowConflict
    })
end

---@param binding KeybindingKeyboardBinding
---@param currentEnabled? boolean
---@param currentAllowConflict? boolean
---@return KeybindingV2Value
function KeybindingsRegistry.BuildKeyboardPayload(binding, currentEnabled, currentAllowConflict)
    return KeybindingsRegistry.CanonicalizeValue({
        Keyboard = {
            Key = binding.Key or binding,
            ModifierKeys = binding.ModifierKeys or {}
        },
        Enabled = currentEnabled,
        AllowConflict = currentAllowConflict
    }, currentEnabled, currentAllowConflict)
end

---@param binding KeybindingMouseBinding
---@param currentEnabled? boolean
---@param currentAllowConflict? boolean
---@return KeybindingV2Value
function KeybindingsRegistry.BuildMousePayload(binding, currentEnabled, currentAllowConflict)
    return KeybindingsRegistry.CanonicalizeValue({
        Mouse = {
            Button = binding.Button or 0,
            ModifierKeys = binding.ModifierKeys or {}
        },
        Enabled = currentEnabled,
        AllowConflict = currentAllowConflict
    }, currentEnabled, currentAllowConflict)
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
    options = options or { includeDeveloper = Ext.Debug.IsDeveloperMode() }

    for _, mod in ipairs(modKeybindings or {}) do
        registry[mod.ModUUID] = registry[mod.ModUUID] or {}
        registry[mod.ModUUID]._keybindingSortMode = mod.KeybindingSortMode or KeybindingSortMode.DEFAULT
        for _, action in ipairs(mod.Actions or {}) do
            local existing = registry[mod.ModUUID][action.ActionId] or {}
            local currentValue = KeybindingsRegistry.CanonicalizeValue({
                Keyboard = action.KeyboardMouseBinding,
                Mouse = action.MouseBinding,
                Enabled = action.Enabled,
                AllowConflict = action.AllowConflict
            })
            local defaultValue = KeybindingsRegistry.CanonicalizeValue({
                Keyboard = action.DefaultKeyboardMouseBinding,
                Mouse = action.DefaultMouseBinding,
                Enabled = action.DefaultEnabled,
                AllowConflict = action.DefaultAllowConflict
            })
            registry[mod.ModUUID][action.ActionId] = {
                modUUID = mod.ModUUID,
                actionName = action.ActionName,
                actionId = action.ActionId,
                keyboardBinding = currentValue.Keyboard,
                mouseBinding = currentValue.Mouse,
                enabled = currentValue.Enabled,
                defaultKeyboardBinding = defaultValue.Keyboard,
                defaultMouseBinding = defaultValue.Mouse,
                defaultEnabled = defaultValue.Enabled,
                defaultAllowConflict = defaultValue.AllowConflict,
                shouldTriggerOnRepeat = Fallback.Value(action.ShouldTriggerOnRepeat, false),
                shouldTriggerOnKeyUp = Fallback.Value(action.ShouldTriggerOnKeyUp, false),
                shouldTriggerOnKeyDown = Fallback.Value(action.ShouldTriggerOnKeyDown, true),
                blockIfLevelNotStarted = Fallback.Value(action.BlockIfLevelNotStarted, false),
                preventAction = Fallback.Value(action.PreventAction, true),
                description = action.Description,
                isDeveloperOnly = Fallback.Value(action.IsDeveloperOnly, false),
                tooltip = action.Tooltip,
                allowConflict = currentValue.AllowConflict,
                skipCallback = Fallback.Value(action.SkipCallback, false),
                sortOrder = action.SortOrder,
                visible = KeybindingsRegistry:ShouldIncludeAction(action, options),
                keyboardCallback = existing.keyboardCallback,
                keyDownCallback = existing.keyDownCallback,
                keyUpCallback = existing.keyUpCallback
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
        local sortMode = actions._keybindingSortMode or KeybindingSortMode.DEFAULT
        for actionId, binding in pairs(actions) do
            if actionId ~= "_keybindingSortMode" and binding.visible then
                filtered[modUUID] = filtered[modUUID] or {}
                filtered[modUUID]._keybindingSortMode = sortMode
                filtered[modUUID][actionId] = binding
            end
        end
    end
    return filtered
end

---Persists a complete replacement value for a binding.
--- @param modUUID string The UUID of the mod to update the binding for
--- @param actionId string The ID of the action to update the binding for
--- @param value KeybindingV2Value The complete value to persist
--- @param shouldEmitEvent? boolean Whether to emit the setting saved event
--- @return boolean success
function KeybindingsRegistry.UpdateBinding(modUUID, actionId, value, shouldEmitEvent)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, "No binding found to update for mod '%s', action '%s'.", modUUID, actionId)
        return false
    end

    -- The immediate acceptance outcome decides the boolean result.
    local receipt = MCMProxy:SetSettingValue(actionId, value, modUUID, nil, shouldEmitEvent)
    return receipt.accepted
end

---Applies an authoritative saved or profile value to an existing registry entry.
---@param modUUID string
---@param actionId string
---@param value KeybindingV2Value|nil
---@return boolean
function KeybindingsRegistry.ApplyBindingValue(modUUID, actionId, value)
    local bindingEntry = registry[modUUID] and registry[modUUID][actionId]
    if not bindingEntry or type(value) ~= "table" then return false end

    local canonical = KeybindingsRegistry.CanonicalizeValue(value, bindingEntry.enabled, bindingEntry.allowConflict)
    bindingEntry.keyboardBinding = canonical.Keyboard
    bindingEntry.mouseBinding = canonical.Mouse
    bindingEntry.enabled = canonical.Enabled
    bindingEntry.allowConflict = canonical.AllowConflict
    keybindingsSubject:OnNext(registry)
    return true
end

---Clears mouse presses retained for dispatch.
function KeybindingsRegistry.ResetInputState()
    activeMouseBindings = {}
end

--- Registers a callback for a given binding.
--- Note that this uses the full registry (not the filtered view) so that callbacks
--- can be attached even for actions that are invisible in the UI.
---@param modUUID string The UUID of the mod
---@param actionId string The ID of the action
---@param inputType string The input type (e.g., "KeyboardMouse")
---@param callback function The callback function
---@param eventType? string Optional event type: "KeyDown", "KeyUp", or nil for both (backward compatible)
function KeybindingsRegistry.RegisterCallback(modUUID, actionId, inputType, callback, eventType)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, "No binding found to register callback for mod '%s', action '%s'.", modUUID, actionId)
        return false
    end

    if inputType == "KeyboardMouse" then
        if eventType == "KeyDown" then
            modTable[actionId].keyDownCallback = callback
        elseif eventType == "KeyUp" then
            modTable[actionId].keyUpCallback = callback
        else
            -- Backward compatible: set both to the same callback
            modTable[actionId].keyboardCallback = callback
        end
    end

    -- It is not necessary to update the registry when registering a callback
    -- keybindingsSubject:OnNext(registry)
    return true
end

---@param binding KeybindingRegistryEntry
---@return boolean
local function canTriggerBinding(binding)
    if binding.isDeveloperOnly and not Ext.Debug.IsDeveloperMode() then
        return false
    end

    if binding.enabled == false then
        return false
    end

    -- Check if we should block the keybinding when level is not started
    if binding.blockIfLevelNotStarted and MCMProxy.IsMainMenu() then
        MCMPrint(2, "Keybinding blocked because level not started: %s", binding.actionName)
        return false
    end

    return true
end

---@param binding KeybindingRegistryEntry
---@param eventType "KeyDown"|"KeyUp"
---@param isRepeat? boolean
---@return boolean
local function shouldTriggerEvent(binding, eventType, isRepeat)
    if eventType == "KeyDown" and not binding.shouldTriggerOnKeyDown then return false end
    if eventType == "KeyUp" and not binding.shouldTriggerOnKeyUp then return false end
    if isRepeat and not binding.shouldTriggerOnRepeat then return false end
    return true
end

---@param binding KeybindingRegistryEntry
---@param eventType "KeyDown"|"KeyUp"
---@return function|nil
local function getCallback(binding, eventType)
    if eventType == "KeyDown" then
        return binding.keyDownCallback or binding.keyboardCallback
    end
    return binding.keyUpCallback or binding.keyboardCallback
end

---@param binding KeybindingRegistryEntry
---@param e EclLuaKeyInputEvent|EclLuaMouseButtonEvent
---@param eventType "KeyDown"|"KeyUp"
local function invokeCallback(binding, e, eventType)
    local callback = getCallback(binding, eventType)
    if not callback then
        if not binding.skipCallback then
            MCMWarn(0, "No keybinding callback found for mod '%s', action '%s'.", binding.modUUID,
                binding.actionName)
        end
        return
    end

    MCMPrint(1, "Dispatching keybinding callback for mod '%s', action '%s'.",
        binding.modUUID, binding.actionName)
    xpcall(function()
        callback(e)
    end, function(err)
        local traceback = debug and type(debug.traceback) == "function" and debug.traceback("", 2) or ""
        local mod = Ext.Mod.GetMod(binding.modUUID)
        local modName = (mod and mod.Info and mod.Info.Name) or tostring(binding.modUUID)
        MCMError(0,
            "Keybinding callback failed for mod '%s', action '%s': %s%s\nPlease contact %s about this issue.",
            modName, tostring(binding.actionName), tostring(err), traceback,
            mod and mod.Info and mod.Info.Author or modName)
    end)
end

---@param triggered KeybindingRegistryEntry[]
---@return boolean
local function shouldBlockConflictingCallbacks(triggered)
    if #triggered <= 1 then return false end

    local allowConflictCount = 0
    for _, binding in ipairs(triggered) do
        if binding.allowConflict then allowConflictCount = allowConflictCount + 1 end
    end
    if allowConflictCount >= #triggered - 1 then return false end

    local binding = triggered[1]
    local activeBinding = KeybindingManager:GetActiveV2Binding({
        Mouse = binding.mouseBinding,
        Keyboard = binding.keyboardBinding
    })
    local keybindingStr = KeyPresentationMapping:GetKBViewKey(activeBinding) or ""
    local actionNames = {}
    for _, triggeredBinding in ipairs(triggered) do
        table.insert(actionNames, string.format("'%s'", tostring(triggeredBinding.actionName)))
    end
    local actionNamesStr = table.concat(actionNames, ", ")
    MCMWarn(0, "Keybinding conflict detected for: %s. Conflicting actions: %s", keybindingStr, actionNamesStr)
    local conflictTitle = VCString:InterpolateLocalizedMessage("hac5a1fd7d223410b8a5fab04951eb428adde",
        binding.actionName)
    local conflictStr = VCString:InterpolateLocalizedMessage("h8509840fdfe4453b800fd84957a50800gacb",
        keybindingStr, actionNamesStr)
    KeybindingsRegistry.NotifyConflict(conflictTitle, conflictStr)
    return true
end

---@param e EclLuaKeyInputEvent|EclLuaMouseButtonEvent
---@param triggered KeybindingRegistryEntry[]
---@param eventType "KeyDown"|"KeyUp"
local function dispatchCallbacks(e, triggered, eventType)
    if shouldBlockConflictingCallbacks(triggered) then return end
    for _, binding in ipairs(triggered) do
        invokeCallback(binding, e, eventType)
    end
end

function KeybindingsRegistry.NotifyConflict(conflictTitle, conflictStr)
    if not conflictTitle or conflictTitle == "" or not conflictStr or conflictStr == "" then
        return
    end

    NotificationManager:CreateIMGUINotification(
        "Keybinding_Conflict" .. Ext.Math.Random(),
        'warning',
        conflictTitle,
        conflictStr,
        { duration = 10, dontShowAgainButton = false },
        ModuleUUID
    )
end

--- Determines if an action should be prevented based on the triggered bindings
--- @param e EclLuaKeyInputEvent|EclLuaMouseButtonEvent The input event
--- @param triggeredBindings KeybindingRegistryEntry[]|nil Optional array of triggered bindings
--- @param isKeyboard? boolean Whether keyboard-only event fields may be read
--- @return boolean True if the action should be prevented, false otherwise
function KeybindingsRegistry.ShouldPreventAction(e, triggeredBindings, isKeyboard)
    if e.PreventAction == nil then
        return false
    end

    if isKeyboard and tostring(e.Key) == "ESCAPE" then
        return false
    end

    -- Only check bindings if they were provided
    if triggeredBindings then
        -- If no bindings were triggered, don't prevent the action
        if #triggeredBindings == 0 then
            return false
        end

        -- Any matching binding may require suppression
        for _, binding in ipairs(triggeredBindings) do
            if binding.preventAction ~= false then return true end
        end
        return false
    end

    -- By default, prevent the action
    return true
end

---Dispatches a keyboard event through shared binding identity.
---@param e EclLuaKeyInputEvent
function KeybindingsRegistry.DispatchKeyboardEvent(e)
    local triggered = {}
    local inputBinding = { Key = e.Key, ModifierKeys = KeybindingManager:GetActiveModifiers(e.Modifiers) }

    for _modUUID, actions in pairs(registry) do
        for _actionId, binding in pairs(actions) do
            if type(binding) == "table" and KeybindingManager:IsKeyboardBindingAssigned(binding.keyboardBinding)
                and canTriggerBinding(binding)
                and shouldTriggerEvent(binding, e.Event, e.Repeat)
                and KeybindingManager:AreBindingsEqual(inputBinding, binding.keyboardBinding) then
                table.insert(triggered, binding)
            end
        end
    end

    if #triggered > 0 and KeybindingsRegistry.ShouldPreventAction(e, triggered, true) then
        e:PreventAction()
    end

    dispatchCallbacks(e, triggered, e.Event)
end

---Dispatches a mouse press/release event using shared binding identity.
---@param e EclLuaMouseButtonEvent
---@param heldModifiers string[]
function KeybindingsRegistry.DispatchMouseEvent(e, heldModifiers)
    local button = e.Button
    local matched = {}

    if e.Pressed then
        local inputBinding = { Button = button, ModifierKeys = KeybindingManager:GetActiveModifiers(heldModifiers) }
        for _modUUID, actions in pairs(registry) do
            for _actionId, binding in pairs(actions) do
                if type(binding) == "table" and KeybindingManager:IsMouseBindingAssigned(binding.mouseBinding)
                    and KeybindingManager:AreBindingsEqual(inputBinding, binding.mouseBinding)
                    and canTriggerBinding(binding) then
                    table.insert(matched, binding)
                end
            end
        end
        activeMouseBindings[button] = matched
    else
        matched = activeMouseBindings[button] or {}
        activeMouseBindings[button] = nil
    end

    if #matched > 0 and KeybindingsRegistry.ShouldPreventAction(e, matched, false) then
        e:PreventAction()
    end

    local eventType = e.Pressed and "KeyDown" or "KeyUp"
    local triggered = {}
    for _, binding in ipairs(matched) do
        if shouldTriggerEvent(binding, eventType, false) then
            table.insert(triggered, binding)
        end
    end
    dispatchCallbacks(e, triggered, eventType)
end

--- Exposes the registry's BehaviorSubject so others can subscribe.
function KeybindingsRegistry.GetSubject()
    return keybindingsSubject
end

--- Returns true if the given mod has at least one visible, enabled, and assigned keyboard binding
---@param modUUID string|nil
---@return boolean
function KeybindingsRegistry.HasKeybindings(modUUID)
    if not modUUID then return false end

    local filtered = KeybindingsRegistry and KeybindingsRegistry.GetFilteredRegistry
        and KeybindingsRegistry.GetFilteredRegistry() or {}
    local actions = filtered[modUUID]
    if not actions then return false end

    return true
end

--- Returns the full registry table.
function KeybindingsRegistry.GetRegistry()
    return registry
end

--- Returns the keybinding sort mode for a given mod.
---@param modUUID string The UUID of the mod
---@return string The sort mode ("alphabetical" or "blueprint")
function KeybindingsRegistry.GetKeybindingSortMode(modUUID)
    if not modUUID or not registry[modUUID] then
        return KeybindingSortMode.DEFAULT
    end
    return registry[modUUID]._keybindingSortMode or KeybindingSortMode.DEFAULT
end
