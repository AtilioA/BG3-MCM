local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")
local ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")

---Minimal keybinding action fixture accepted by the registry.
---@class KeybindingTestAction
---@field ActionId string
---@field ActionName string
---@field MouseBinding? KeybindingMouseBinding
---@field DefaultMouseBinding? KeybindingMouseBinding
---@field Enabled boolean
---@field DefaultEnabled boolean
---@field AllowConflict boolean
---@field DefaultAllowConflict boolean
---@field ShouldTriggerOnKeyDown boolean
---@field ShouldTriggerOnKeyUp boolean
---@field PreventAction boolean
---@field Tooltip string
---@field Description string

---Minimal mouse event fixture used for registry dispatch tests.
---@class MouseInputEventStub
---@field Button integer
---@field Pressed boolean
---@field prevented boolean
---@field PreventAction fun(self: MouseInputEventStub)

D.describe("keybinding_v2 runtime", { tags = { "keybinding_v2", "client", "unit" } }, function()
    local TEST_MOD_UUID = "00000000-0000-0000-0000-000000000042"
    local inputCallbackState
    local heldModifiersBefore
    local registryBefore
    local ownsInputState = false

    ---@param actions KeybindingTestAction[]
    local function RegisterActions(actions)
        KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID] = nil
        KeybindingsRegistry.RegisterModKeybindings({ {
            ModUUID = TEST_MOD_UUID,
            KeybindingSortMode = KeybindingSortMode.DEFAULT,
            Actions = actions
        } }, { includeDeveloper = true })
    end

    ---@param id string
    ---@param binding KeybindingMouseBinding|nil
    ---@param allowConflict? boolean
    ---@param preventAction? boolean
    ---@return KeybindingTestAction
    local function MouseAction(id, binding, allowConflict, preventAction)
        return {
            ActionId = id,
            ActionName = id,
            MouseBinding = binding,
            DefaultMouseBinding = binding,
            Enabled = true,
            DefaultEnabled = true,
            AllowConflict = allowConflict == true,
            DefaultAllowConflict = allowConflict == true,
            ShouldTriggerOnKeyDown = true,
            ShouldTriggerOnKeyUp = true,
            PreventAction = preventAction ~= false,
            Tooltip = "",
            Description = ""
        }
    end

    ---@param id string
    ---@param key string
    ---@return KeybindingTestAction
    local function KeyboardAction(id, key)
        local action = MouseAction(id, nil)
        action.KeyboardMouseBinding = { Key = key, ModifierKeys = {} }
        action.DefaultKeyboardMouseBinding = action.KeyboardMouseBinding
        return action
    end

    ---@param pressed boolean
    ---@param button integer
    ---@return MouseInputEventStub
    local function MouseEvent(pressed, button)
        return {
            Button = button,
            Pressed = pressed,
            Stopped = false,
            prevented = false,
            stopped = false,
            PreventAction = function(self) self.prevented = true end,
            StopPropagation = function(self)
                self.stopped = true
                self.Stopped = true
            end
        }
    end

    ---Records the action, edge, and exact input object delivered to a consumer.
    ---@param calls table[]
    ---@param actionId string
    ---@param eventType "KeyDown"|"KeyUp"
    ---@return fun(event: table)
    local function RecordCallback(calls, actionId, eventType)
        return function(event)
            table.insert(calls, { actionId = actionId, eventType = eventType, event = event })
        end
    end

    ---Asserts exact callback identity, edge, event identity, and multiplicity.
    ---@param actual table[]
    ---@param expected table[]
    local function ExpectCalls(actual, expected)
        D.expect(#actual).toBe(#expected)
        for index, call in ipairs(expected) do
            D.expect(actual[index].actionId).toBe(call.actionId)
            D.expect(actual[index].eventType).toBe(call.eventType)
            D.expect(actual[index].event).toBe(call.event)
        end
    end

    ---Removes the isolated test registry entry.
    local function Cleanup()
        if not ownsInputState then return end
        ownsInputState = false
        local registry = KeybindingsRegistry.GetRegistry()
        for modUUID in pairs(registry) do registry[modUUID] = nil end
        for modUUID, actions in pairs(registryBefore) do registry[modUUID] = actions end
        registryBefore = nil
        KeybindingsRegistry.ResetInputState()
        KeybindingCaptureSession.Reset("reset")
        if heldModifiersBefore then
            InputCallbackManager._HeldModifiers = heldModifiersBefore
            heldModifiersBefore = nil
        end
        KeybindingsRegistry.GetSubject():OnNext(registry)
        if inputCallbackState then
            InputCallbackManager._KeybindingsLoaded = inputCallbackState.loaded
            InputCallbackManager._KeybindingsLoadedSubscribed = inputCallbackState.subscribed
            InputCallbackManager._PendingKeybindingCallbacks = inputCallbackState.pending
            InputCallbackManager.KeybindingsLoadedSubject = inputCallbackState.subject
            inputCallbackState = nil
        end
    end

    D.beforeEach(function(ctx)
        if KeybindingCaptureSession.IsActive() then
            ctx.skip("A player capture session is already active")
        end
        ownsInputState = true
        heldModifiersBefore = InputCallbackManager._HeldModifiers
        InputCallbackManager._HeldModifiers = {}
        local registry = KeybindingsRegistry.GetRegistry()
        registryBefore = {}
        for modUUID, actions in pairs(registry) do registryBefore[modUUID] = actions end
        for modUUID in pairs(registry) do registry[modUUID] = nil end
    end)

    D.afterEach(Cleanup)

    D.test("canonicalizes one device and modifier order", function()
        local value = KeybindingsRegistry.CanonicalizeValue({
            Mouse = { Button = 8, ModifierKeys = { "RSHIFT", "LCTRL", "RSHIFT", "NONE" } },
            Enabled = false,
            AllowConflict = true
        })

        D.expect(value).toEqual({
            Mouse = { Button = 8, ModifierKeys = { "LCTRL", "RSHIFT" } },
            Enabled = false,
            AllowConflict = true
        })
        D.expect(KeybindingsRegistry.CanonicalizeValue({})).toEqual({
            Keyboard = { Key = "", ModifierKeys = {} },
            Enabled = true,
            AllowConflict = false
        })
    end)

    D.test("does not treat unsupported modifiers as unmodified", function()
        D.expect(KeybindingManager:AreBindingsEqual(
            { Key = "A", ModifierKeys = {} },
            { Key = "A", ModifierKeys = { "LGUI" } }
        )).toBeFalsy()
    end)

    D.test("adapts no-modifier forms to one empty list", function()
        local modifiers, invalid = KeybindingManager:AdaptModifierKeys({ "", "NONE", "none" })
        D.expect(modifiers).toEqual({})
        D.expect(invalid).toBeNil()

        local valid = KeybindingManager:AdaptModifierKeys({ "rshift", "LCTRL", "RSHIFT" })
        D.expect(valid).toEqual({ "LCTRL", "RSHIFT" })

        local rejected, invalidModifier = KeybindingManager:AdaptModifierKeys({ "LCTRL_BAD" })
        D.expect(rejected).toBeNil()
        D.expect(invalidModifier).toBe("LCTRL_BAD")
    end)


    D.test("sends complete replacement values to the setting-write boundary", function(ctx)
        RegisterActions({ MouseAction("replace-device", { Button = 8, ModifierKeys = { "LCTRL" } }) })
        local writes = {}
        ctx.stub(MCMProxy, "SetSettingValue", function(_, settingId, value, modUUID, setUIValue, shouldEmitEvent)
            table.insert(writes, {
                settingId = settingId,
                value = value,
                modUUID = modUUID,
                setUIValue = setUIValue,
                shouldEmitEvent = shouldEmitEvent,
            })
            return { accepted = true, state = "saved", value = value }
        end)
        local mouseValue = {
            Mouse = { Button = 8, ModifierKeys = { "LCTRL" } },
            Enabled = false,
            AllowConflict = false
        }
        D.expect(KeybindingsRegistry.UpdateBinding(TEST_MOD_UUID, "replace-device", mouseValue, true)).toBe(true)
        D.expect(writes[1].settingId).toBe("replace-device")
        D.expect(writes[1].modUUID).toBe(TEST_MOD_UUID)
        D.expect(writes[1].value).toEqual(mouseValue)
        D.expect(writes[1].shouldEmitEvent).toBe(true)

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "replace-device", writes[1].value)
        local keyboardValue = {
            Keyboard = { Key = "K", ModifierKeys = { "LALT" } },
            Enabled = false,
            AllowConflict = false
        }
        D.expect(KeybindingsRegistry.UpdateBinding(TEST_MOD_UUID, "replace-device", keyboardValue, true)).toBe(true)
        D.expect(#writes).toBe(2)
        D.expect(writes[2].value).toEqual(keyboardValue)
    end)

    D.test("applies authoritative keyboard mouse and unbound values", function()
        RegisterActions({ MouseAction("authoritative", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["authoritative"]

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Keyboard = { Key = "J", ModifierKeys = { "LSHIFT" } },
            Enabled = true,
            AllowConflict = false
        })
        D.expect(entry.keyboardBinding).toEqual({ Key = "J", ModifierKeys = { "LSHIFT" } })
        D.expect(entry.mouseBinding).toBeNil()
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(false)

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Mouse = { Button = 6, ModifierKeys = { "LALT" } },
            Enabled = true,
            AllowConflict = true
        })
        D.expect(entry.keyboardBinding).toBeNil()
        D.expect(entry.mouseBinding).toEqual({ Button = 6, ModifierKeys = { "LALT" } })
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(true)

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Keyboard = { Key = "", ModifierKeys = {} },
            Enabled = true,
            AllowConflict = false
        })
        D.expect(entry.keyboardBinding).toEqual({ Key = "", ModifierKeys = {} })
        D.expect(entry.mouseBinding).toBeNil()
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(false)
    end)

    D.test("does not clear a binding when the authoritative value is missing", function()
        RegisterActions({ MouseAction("missing-authority", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["missing-authority"]

        D.expect(KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "missing-authority", nil)).toBeFalsy()
        D.expect(entry.mouseBinding).toEqual({ Button = 7, ModifierKeys = {} })
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(false)
    end)

    D.test("does not clear a binding on a rejected save without an old value", function()
        RegisterActions({ MouseAction("rejected-save", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["rejected-save"]

        Ext.ModEvents["BG3MCM"][EventChannels.MCM_INTERNAL_SETTING_SAVED]:Throw({
            modUUID = TEST_MOD_UUID,
            settingId = "rejected-save",
            value = { Mouse = { Button = KeybindingManager.MOUSE_BUTTON_MAX + 1, ModifierKeys = {} } },
            error = "rejected"
        })

        D.expect(entry.mouseBinding).toEqual({ Button = 7, ModifierKeys = {} })
        D.expect(entry.keyboardBinding).toBeNil()
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(false)
    end)

    D.test("rolls back a rejected save to its authoritative old value", function()
        RegisterActions({ MouseAction("authoritative-rejection", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["authoritative-rejection"]

        Ext.ModEvents["BG3MCM"][EventChannels.MCM_INTERNAL_SETTING_SAVED]:Throw({
            modUUID = TEST_MOD_UUID,
            settingId = "authoritative-rejection",
            value = { Mouse = { Button = KeybindingManager.MOUSE_BUTTON_MAX + 1, ModifierKeys = {} } },
            oldValue = { Mouse = { Button = 6, ModifierKeys = {} }, Enabled = true, AllowConflict = false },
            error = "rejected"
        })

        D.expect(entry.mouseBinding).toEqual({ Button = 6, ModifierKeys = {} })
        D.expect(entry.keyboardBinding).toBeNil()
        D.expect(entry.enabled).toBe(true)
        D.expect(entry.allowConflict).toBe(false)
    end)

    D.test("dispatches raw mouse press and release and prevents both edges", function()
        RegisterActions({ MouseAction("mouse-dispatch", {
            Button = 10,
            ModifierKeys = { "RALT", "RCTRL", "RSHIFT" }
        }) })
        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-dispatch", "KeyboardMouse",
            RecordCallback(calls, "mouse-dispatch", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-dispatch", "KeyboardMouse",
            RecordCallback(calls, "mouse-dispatch", "KeyUp"), "KeyUp")

        local press = MouseEvent(true, 10)
        local release = MouseEvent(false, 10)
        KeybindingsRegistry.DispatchMouseEvent(press, { "RSHIFT", "RALT", "RCTRL" })
        KeybindingsRegistry.DispatchMouseEvent(release, {})

        ExpectCalls(calls, {
            { actionId = "mouse-dispatch", eventType = "KeyDown", event = press },
            { actionId = "mouse-dispatch", eventType = "KeyUp", event = release },
        })
        D.expect(press.prevented).toBeTruthy()
        D.expect(release.prevented).toBeTruthy()
    end)

    D.test("dispatches keyboard input through shared identity", function()
        local action = MouseAction("keyboard-dispatch", nil)
        action.KeyboardMouseBinding = { Key = "K", ModifierKeys = { "LCTRL", "LALT" } }
        action.DefaultKeyboardMouseBinding = action.KeyboardMouseBinding
        RegisterActions({ action })

        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "keyboard-dispatch", "KeyboardMouse",
            RecordCallback(calls, "keyboard-dispatch", "KeyDown"), "KeyDown")
        local event = {
            Key = "k",
            Modifiers = { "LALT", "LCTRL" },
            Event = "KeyDown",
            Repeat = false,
            prevented = false,
            PreventAction = function(self) self.prevented = true end
        }
        KeybindingsRegistry.DispatchKeyboardEvent(event)

        ExpectCalls(calls, {
            { actionId = "keyboard-dispatch", eventType = "KeyDown", event = event },
        })
        D.expect(event.prevented).toBeTruthy()
    end)

    ---@param key string
    ---@param modifiers string[]|nil
    ---@param eventType? "KeyDown"|"KeyUp"
    local function KeyEvent(key, modifiers, eventType)
        return {
            Key = key,
            Modifiers = modifiers,
            Event = eventType or "KeyDown",
            Repeat = false,
            Stopped = false,
            prevented = false,
            stopped = false,
            PreventAction = function(self) self.prevented = true end,
            StopPropagation = function(self)
                self.stopped = true
                self.Stopped = true
            end
        }
    end

    ---Registers one keyboard action and counts how often it fires.
    ---@param id string
    ---@param binding KeybindingKeyboardBinding
    ---@param events table[]
    ---@return table[] calls
    local function DispatchKeys(id, binding, events)
        local action = MouseAction(id, nil)
        action.KeyboardMouseBinding = binding
        action.DefaultKeyboardMouseBinding = binding
        RegisterActions({ action })

        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, id, "KeyboardMouse",
            RecordCallback(calls, id, "KeyDown"), "KeyDown")
        for _, input in ipairs(events) do
            KeybindingsRegistry.DispatchKeyboardEvent(input)
        end
        return calls
    end

    D.test("dispatches plain keyboard bindings past unsupported live modifiers", function()
        local events = {
            KeyEvent("K", {}),
            KeyEvent("K", nil),
            KeyEvent("K", { "NONE", "" }),
            KeyEvent("K", { "NUM" }),
            KeyEvent("K", { "CAPS", "NUM", "LGUI", "RGUI", "MODE", "SCROLL" }),
        }
        local calls = DispatchKeys("plain-key-noise", { Key = "K", ModifierKeys = {} }, events)
        local expected = {}
        for _, event in ipairs(events) do
            table.insert(expected, { actionId = "plain-key-noise", eventType = "KeyDown", event = event })
        end
        ExpectCalls(calls, expected)
    end)

    D.test("keeps exact matching for plain keyboard bindings", function()
        local calls = DispatchKeys("plain-key-exact", { Key = "K", ModifierKeys = {} }, {
            KeyEvent("K", { "LCTRL" }),
            KeyEvent("K", { "LCTRL", "LALT" }),
            KeyEvent("J", {}),
        })

        ExpectCalls(calls, {})
    end)

    D.test("dispatches modified keyboard bindings past unsupported live modifiers", function()
        local events = {
            KeyEvent("K", { "LCTRL" }),
            KeyEvent("k", { "lctrl", "LCTRL", "NUM" }),
            KeyEvent("K", { "LCTRL", "CAPS" }),
        }
        local calls = DispatchKeys("mod-key-noise", { Key = "K", ModifierKeys = { "LCTRL" } }, events)
        local expected = {}
        for _, event in ipairs(events) do
            table.insert(expected, { actionId = "mod-key-noise", eventType = "KeyDown", event = event })
        end
        ExpectCalls(calls, expected)
    end)

    D.test("rejects incomplete, wrong, or extra supported modifiers", function()
        local calls = DispatchKeys("mod-key-reject", { Key = "K", ModifierKeys = { "LCTRL" } }, {
            KeyEvent("K", {}),
            KeyEvent("K", { "LALT" }),
            KeyEvent("K", { "LCTRL", "LALT" }),
        })

        ExpectCalls(calls, {})
    end)

    D.test("never matches unsupported modifiers on either side", function()
        local calls = DispatchKeys("junk-key", { Key = "K", ModifierKeys = { "LGUI" } }, {
            KeyEvent("K", {}),
            KeyEvent("K", { "LGUI" }),
        })

        ExpectCalls(calls, {})
    end)

    D.test("dispatches mouse bindings past unsupported held modifiers", function()
        RegisterActions({
            MouseAction("mouse-noise", { Button = 5, ModifierKeys = {} }),
            MouseAction("mouse-mod-noise", { Button = 6, ModifierKeys = { "LCTRL" } }),
        })
        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-noise", "KeyboardMouse",
            RecordCallback(calls, "mouse-noise", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-noise", "KeyboardMouse",
            RecordCallback(calls, "mouse-noise", "KeyUp"), "KeyUp")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-mod-noise", "KeyboardMouse",
            RecordCallback(calls, "mouse-mod-noise", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-mod-noise", "KeyboardMouse",
            RecordCallback(calls, "mouse-mod-noise", "KeyUp"), "KeyUp")

        local expected = {}
        local inputs = {
            { button = 5, held = {}, actionId = "mouse-noise" },
            { button = 5, held = { "NUM" }, actionId = "mouse-noise" },
            { button = 5, held = { "CAPS", "SCROLL" }, actionId = "mouse-noise" },
            { button = 6, held = { "LCTRL" }, actionId = "mouse-mod-noise" },
            { button = 6, held = { "LCTRL", "NUM" }, actionId = "mouse-mod-noise" },
            { button = 6, held = {}, actionId = false },
        }
        for _, input in ipairs(inputs) do
            local press = MouseEvent(true, input.button)
            local release = MouseEvent(false, input.button)
            KeybindingsRegistry.DispatchMouseEvent(press, input.held)
            KeybindingsRegistry.DispatchMouseEvent(release, input.held)
            if input.actionId then
                table.insert(expected, { actionId = input.actionId, eventType = "KeyDown", event = press })
                table.insert(expected, { actionId = input.actionId, eventType = "KeyUp", event = release })
            end
        end

        ExpectCalls(calls, expected)
    end)

    D.test("does not prevent mouse edges when PreventAction is false", function()
        RegisterActions({ MouseAction("observe-mouse", { Button = 9, ModifierKeys = {} }, false, false) })
        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "observe-mouse", "KeyboardMouse",
            RecordCallback(calls, "observe-mouse", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "observe-mouse", "KeyboardMouse",
            RecordCallback(calls, "observe-mouse", "KeyUp"), "KeyUp")
        local press = MouseEvent(true, 9)
        local release = MouseEvent(false, 9)

        KeybindingsRegistry.DispatchMouseEvent(press, {})
        KeybindingsRegistry.DispatchMouseEvent(release, {})

        ExpectCalls(calls, {
            { actionId = "observe-mouse", eventType = "KeyDown", event = press },
            { actionId = "observe-mouse", eventType = "KeyUp", event = release },
        })
        D.expect(press.prevented).toBeFalsy()
        D.expect(release.prevented).toBeFalsy()
    end)

    D.test("does not dispatch disabled mouse bindings", function()
        local action = MouseAction("disabled-mouse", { Button = 9, ModifierKeys = {} })
        action.Enabled = false
        RegisterActions({ action })
        local calls = 0
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "disabled-mouse", "KeyboardMouse",
            function() calls = calls + 1 end)
        local press = MouseEvent(true, 9)
        local release = MouseEvent(false, 9)

        KeybindingsRegistry.DispatchMouseEvent(press, {})
        KeybindingsRegistry.DispatchMouseEvent(release, {})

        D.expect(calls).toBe(0)
        D.expect(press.prevented).toBeFalsy()
        D.expect(release.prevented).toBeFalsy()
    end)

    D.test("reports blocked conflicts without calling either action", function(ctx)
        RegisterActions({
            MouseAction("runtime-conflict-one", { Button = 3, ModifierKeys = {} }),
            MouseAction("runtime-conflict-two", { Button = 3, ModifierKeys = {} })
        })
        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "runtime-conflict-one", "KeyboardMouse",
            RecordCallback(calls, "runtime-conflict-one", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "runtime-conflict-two", "KeyboardMouse",
            RecordCallback(calls, "runtime-conflict-two", "KeyDown"), "KeyDown")

        local warnings = {}
        ctx.stub(_G, "MCMWarn", function(_, format, ...)
            table.insert(warnings, string.format(format, ...))
        end)
        ctx.stub(KeybindingsRegistry, "NotifyConflict", function() end)

        KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 3), {})

        ExpectCalls(calls, {})
        D.expect(#warnings).toBe(1)
        D.expect(warnings[1]).toContain("runtime-conflict-one")
        D.expect(warnings[1]).toContain("runtime-conflict-two")
    end)

    D.test("compares exact keyboard and mouse identities", function()
        D.expect(KeybindingManager:AreBindingsEqual(
            { Button = 5, ModifierKeys = { "LCTRL", "LALT" } },
            { Button = 5, ModifierKeys = { "LALT", "LCTRL" } }
        )).toBeTruthy()
        D.expect(KeybindingManager:AreBindingsEqual(
            { Button = 5, ModifierKeys = { "LCTRL" } },
            { Button = 6, ModifierKeys = { "LCTRL" } }
        )).toBeFalsy()
        D.expect(KeybindingManager:AreBindingsEqual(
            { Key = "K", ModifierKeys = {} },
            { Button = 5, ModifierKeys = {} }
        )).toBeFalsy()
        D.expect(KeybindingManager:AreBindingsEqual(
            { Button = 5, ModifierKeys = { "LCTRL" } },
            { Button = 5, ModifierKeys = { "LALT" } }
        )).toBeFalsy()
        D.expect(KeybindingManager:AreBindingsEqual(nil, { Keyboard = { Key = "", ModifierKeys = {} } }))
            .toBeTruthy()
    end)

    D.test("checks invisible registry bindings for MCM conflicts", function()
        RegisterActions({
            MouseAction("visible-conflict", { Button = 5, ModifierKeys = {} }),
            MouseAction("hidden-conflict", { Button = 5, ModifierKeys = {} })
        })
        KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["hidden-conflict"].visible = false

        local conflict = KeybindingConflictService:CheckMCMForConflicts(
            { Button = 5, ModifierKeys = {} },
            { ActionId = "visible-conflict" },
            TEST_MOD_UUID
        )

        D.expect(conflict).toBeTruthy()
        D.expect(conflict.ActionName).toBe("hidden-conflict")
    end)

    D.test("suppresses unsupported mouse buttons during capture", function()
        local outcome = nil
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) outcome = value end
        })

        local press = MouseEvent(true, 11)
        local ok, err = pcall(function()
            session:HandleMouseInput(press)
        end)
        if not ok then error(err) end

        D.expect(press.prevented).toBeTruthy()
        D.expect(press.stopped).toBeTruthy()
        D.expect(outcome).toBeNil()

        local release = MouseEvent(false, 11)
        session:HandleMouseInput(release)
        D.expect(release.prevented).toBeTruthy()
        D.expect(outcome).toEqual({ kind = "cancelled", reason = "unsupported-button" })
    end)

    D.test("stops captured mouse release propagation", function()
        local outcome = nil
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) outcome = value end
        })

        session:HandleMouseInput(MouseEvent(true, 1))
        D.expect(outcome).toBeNil()

        local release = MouseEvent(false, 1)
        session:HandleMouseInput(release)

        D.expect(release.prevented).toBeTruthy()
        D.expect(release.stopped).toBeTruthy()
        D.expect(outcome.kind).toBe("binding")
        D.expect(outcome.binding.Button).toBe(1)
    end)

    D.test("retains the claimed release after selection", function()
        local session = KeybindingCaptureSession.Start({
            OnComplete = function() end
        })

        session:HandleMouseInput(MouseEvent(true, 1))
        session:HandleMouseInput(MouseEvent(false, 1))

        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", 1, true)).toBeTruthy()
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", 1, true)).toBeFalsy()
    end)

    D.test("saves captured input with the current registry flags", function(ctx)
        local action = MouseAction("capture-race", { Button = 8, ModifierKeys = {} })
        RegisterActions({ action })
        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "capture-race", {
            Mouse = { Button = 8, ModifierKeys = {} },
            Enabled = false,
            AllowConflict = true
        })

        local widget = setmetatable({}, { __index = KeybindingV2IMGUIWidget })
        widget.FilterActions = function() end
        widget.RefreshUI = function() end
        local writes = {}
        local button = { Label = "Assign", Disabled = false }
        ctx.stub(MCMProxy, "SetSettingValue", function(_, settingId, value, modUUID, setUIValue, shouldEmitEvent)
            table.insert(writes, {
                settingId = settingId,
                value = value,
                modUUID = modUUID,
                setUIValue = setUIValue,
                shouldEmitEvent = shouldEmitEvent,
            })
            return { accepted = true, state = "saved", value = value }
        end)
        ctx.stub(NativeKeybindings, "GetAll", function()
            return { Public = {}, Internal = {} }
        end)

        local capturedSession
        local startCapture = KeybindingCaptureSession.Start
        ctx.stub(KeybindingCaptureSession, "Start", function(options)
            capturedSession = startCapture(options)
            return capturedSession
        end)
        InputCallbackManager._HeldModifiers = { LCTRL = true }
        widget:StartListeningForInput(
            { ModUUID = TEST_MOD_UUID, ModName = "Capture test" },
            action,
            "KeyboardMouse",
            button
        )
        D.expect(KeybindingCaptureSession.IsActive()).toBeTruthy()
        D.expect(capturedSession).Not.toBeNil()
        capturedSession:HandleKeyInput(KeyEvent("K", { "LCTRL" }))
        D.expect(KeybindingCaptureSession.IsActive()).toBeTruthy()
        capturedSession:HandleKeyInput(KeyEvent("K", { "LCTRL" }, "KeyUp"))

        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
        D.expect(#writes).toBe(1)
        D.expect(writes[1].settingId).toBe("capture-race")
        D.expect(writes[1].modUUID).toBe(TEST_MOD_UUID)
        D.expect(writes[1].shouldEmitEvent).toBe(true)
        D.expect(writes[1].value).toEqual({
            Keyboard = { Key = "K", ModifierKeys = { "LCTRL" } },
            Enabled = false,
            AllowConflict = true,
        })
    end)

    D.test("uses shared identity for conflict and default UI comparisons", function()
        RegisterActions({ MouseAction("identity-conflict", {
            Button = 5,
            ModifierKeys = { "LCTRL", "LALT" }
        }) })
        local conflict = KeybindingConflictService:CheckMCMForConflicts(
            { Button = 5, ModifierKeys = { "LALT", "LCTRL" } },
            { ActionId = "other-action" }, "other-mod"
        )
        D.expect(conflict).toBeTruthy()
        D.expect(conflict.ActionName).toBe("identity-conflict")

        local action = {
            KeyboardMouseBinding = nil,
            DefaultKeyboardMouseBinding = nil,
            MouseBinding = { Button = 5, ModifierKeys = { "LCTRL", "LALT" } },
            DefaultMouseBinding = { Button = 5, ModifierKeys = { "LALT", "LCTRL" } },
            Enabled = true,
            DefaultEnabled = true,
            AllowConflict = false,
            DefaultAllowConflict = false
        }
        D.expect(KeybindingV2IMGUIWidget:IsDefaultBinding(action)).toBeTruthy()
        action.DefaultMouseBinding.Button = 6
        D.expect(KeybindingV2IMGUIWidget:IsDefaultBinding(action)).toBeFalsy()
    end)

    D.test("normalizes a verified native middle mouse binding", function(ctx)
        ctx.stub(NativeKeybindings, "GetAll", function()
            return {
                Public = { {
                    EventName = "NativeMiddleMouse",
                    Bindings = { {
                        InputType = "Mouse",
                        InputId = "middle",
                        Modifiers = { "LCTRL" }
                    } }
                } },
                Internal = {}
            }
        end)

        local conflict = KeybindingConflictService:CheckNativeForConflicts({
            Button = 2,
            ModifierKeys = { "LCTRL" }
        })

        D.expect(conflict).toBeTruthy()
        D.expect(conflict.ActionName).toBe("NativeMiddleMouse")
        D.expect(KeybindingConflictService:CheckNativeForConflicts({
            Button = 1,
            ModifierKeys = {}
        })).toBeNil()
    end)

    D.test("uses one lifecycle predicate for input cleanup", function()
        D.expect(InputCallbackManager.IsInputCleanupGameState(
            Ext.Enums.ClientGameState.UnloadSession)).toBeTruthy()
        D.expect(InputCallbackManager.IsInputCleanupGameState(
            Ext.Enums.ClientGameState.Running)).toBeFalsy()
    end)

    D.test("resetting input clears held modifiers, capture claims, and pressed callbacks", function()
        RegisterActions({ MouseAction("lifecycle-reset", { Button = 8, ModifierKeys = {} }) })

        local downEvents = {}
        local upEvents = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "lifecycle-reset", "KeyboardMouse",
            function(event) table.insert(downEvents, event) end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "lifecycle-reset", "KeyboardMouse",
            function(event) table.insert(upEvents, event) end, "KeyUp")
        KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 8), {})
        D.expect(#downEvents).toBe(1)

        InputCallbackManager._HeldModifiers = { LCTRL = true }
        local outcome = nil
        local completionCount = 0
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value)
                completionCount = completionCount + 1
                outcome = value
            end
        })
        session:HandleMouseInput(MouseEvent(true, 9))

        InputCallbackManager.ResetInputState()

        D.expect(InputCallbackManager.GetHeldModifiers()).toEqual({})
        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
        D.expect(outcome).toEqual({
            kind = "binding",
            binding = { Button = 9, ModifierKeys = { "LCTRL" } },
            reason = "input-reset",
        })
        D.expect(completionCount).toBe(1)
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", 9, true)).toBeFalsy()

        KeybindingsRegistry.DispatchMouseEvent(MouseEvent(false, 8), {})
        D.expect(#upEvents).toBe(0)
    end)

    D.test("presents legacy empty mouse companions as keyboard bindings", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function()
            return {
                Keyboard = { Key = "K", ModifierKeys = { "LCTRL" } },
                Mouse = { Button = 0, ModifierKeys = {} }
            }
        end)
        local result = KeyPresentationMapping:GetViewKeyForSetting("legacy", TEST_MOD_UUID)
        D.expect(result).toBe("[Left Ctrl] + [K]")
        D.expect(KeyPresentationMapping:GetKBViewKey({ Key = "K", ModifierKeys = { "NONE", "" } }))
            .toBe("[K]")
        D.expect(KeyPresentationMapping:GetMouseViewKey({ Button = 1, ModifierKeys = {} }))
            .toBe("[Left Mouse Button]")
        D.expect(KeyPresentationMapping:GetMouseViewKey({ Button = 10, ModifierKeys = {} }))
            .toBe("[Mouse 10]")
    end)

    D.test("registers queued and post-load callbacks on their own input", function(ctx)
        RegisterActions({
            KeyboardAction("queued-one", "K"),
            KeyboardAction("queued-two", "J"),
            KeyboardAction("added-after-load", "L"),
        })
        inputCallbackState = {
            loaded = InputCallbackManager._KeybindingsLoaded,
            subscribed = InputCallbackManager._KeybindingsLoadedSubscribed,
            pending = InputCallbackManager._PendingKeybindingCallbacks,
            subject = InputCallbackManager.KeybindingsLoadedSubject,
        }

        local subject = ReplaySubject.Create(1)
        InputCallbackManager._KeybindingsLoaded = false
        InputCallbackManager._KeybindingsLoadedSubscribed = false
        InputCallbackManager._PendingKeybindingCallbacks = {}
        InputCallbackManager.KeybindingsLoadedSubject = subject
        local subscriptionCalls = ctx.spyOn(subject, "Subscribe")
        local calls = {}

        InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "queued-one",
            RecordCallback(calls, "queued-one", "KeyDown"), "KeyDown")
        InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "queued-two",
            RecordCallback(calls, "queued-two", "KeyDown"), "KeyDown")
        D.expect(subscriptionCalls).toHaveBeenCalledTimes(1)

        subject:OnNext(true)
        InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "added-after-load",
            RecordCallback(calls, "added-after-load", "KeyDown"), "KeyDown")
        D.expect(#InputCallbackManager._PendingKeybindingCallbacks).toBe(0)
        D.expect(InputCallbackManager._KeybindingsLoadedSubscribed).toBeTruthy()

        local queuedOneInput = KeyEvent("K", {})
        local queuedTwoInput = KeyEvent("J", {})
        local afterLoadInput = KeyEvent("L", {})
        KeybindingsRegistry.DispatchKeyboardEvent(queuedOneInput)
        KeybindingsRegistry.DispatchKeyboardEvent(queuedTwoInput)
        KeybindingsRegistry.DispatchKeyboardEvent(afterLoadInput)

        ExpectCalls(calls, {
            { actionId = "queued-one", eventType = "KeyDown", event = queuedOneInput },
            { actionId = "queued-two", eventType = "KeyDown", event = queuedTwoInput },
            { actionId = "added-after-load", eventType = "KeyDown", event = afterLoadInput },
        })
    end)

    D.test("allowed mouse conflicts select each event-specific callback", function()
        local modifiers = { "RALT", "RCTRL", "RSHIFT" }
        RegisterActions({
            MouseAction("first", { Button = 10, ModifierKeys = modifiers }, true),
            MouseAction("second", { Button = 10, ModifierKeys = modifiers }, false)
        })
        local calls = {}
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "first", "KeyboardMouse",
            RecordCallback(calls, "first", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "second", "KeyboardMouse",
            RecordCallback(calls, "second", "KeyDown"), "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "first", "KeyboardMouse",
            RecordCallback(calls, "first", "KeyUp"), "KeyUp")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "second", "KeyboardMouse",
            RecordCallback(calls, "second", "KeyUp"), "KeyUp")

        local press = MouseEvent(true, 10)
        local release = MouseEvent(false, 10)
        KeybindingsRegistry.DispatchMouseEvent(press, modifiers)
        KeybindingsRegistry.DispatchMouseEvent(release, {})
        for _, actionId in ipairs({ "first", "second" }) do
            local downCalls = {}
            local upCalls = {}
            for _, call in ipairs(calls) do
                if call.actionId == actionId and call.eventType == "KeyDown" then
                    table.insert(downCalls, call)
                elseif call.actionId == actionId and call.eventType == "KeyUp" then
                    table.insert(upCalls, call)
                end
            end
            ExpectCalls(downCalls, {
                { actionId = actionId, eventType = "KeyDown", event = press },
            })
            ExpectCalls(upCalls, {
                { actionId = actionId, eventType = "KeyUp", event = release },
            })
        end
        D.expect(press.prevented).toBeTruthy()
        D.expect(release.prevented).toBeTruthy()
    end)
end)
