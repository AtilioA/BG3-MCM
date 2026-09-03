local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

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

    ---@param pressed boolean
    ---@param button integer
    ---@return MouseInputEventStub
    local function MouseEvent(pressed, button)
        return {
            Button = button,
            Pressed = pressed,
            prevented = false,
            stopped = false,
            PreventAction = function(self) self.prevented = true end,
            StopPropagation = function(self) self.stopped = true end
        }
    end

    ---Removes the isolated test registry entry.
    local function Cleanup()
        local registry = KeybindingsRegistry.GetRegistry()
        registry[TEST_MOD_UUID] = nil
        KeybindingsRegistry.ResetInputState()
        KeybindingsRegistry.GetSubject():OnNext(registry)
    end

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

    D.test("rejects fractional mouse buttons", function()
        local isValid = KeybindingV2Validator.Validate({}, {
            Keyboard = { Key = "K", ModifierKeys = {} },
            Mouse = { Button = 1.5, ModifierKeys = {} }
        })

        D.expect(isValid).toBeFalsy()
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


    D.test("persists complete replacement values unchanged", function()
        RegisterActions({ MouseAction("replace-device", { Button = 8, ModifierKeys = { "LCTRL" } }) })
        local originalSetSettingValue = MCMProxy.SetSettingValue
        local saved = nil
        MCMProxy.SetSettingValue = function(_, _, value)
            saved = value
            return true
        end

        local ok, err = pcall(function()
            local mouseValue = {
                Mouse = { Button = 8, ModifierKeys = { "LCTRL" } },
                Enabled = false,
                AllowConflict = false
            }
            KeybindingsRegistry.UpdateBinding(TEST_MOD_UUID, "replace-device", mouseValue, true)
            D.expect(saved).toEqual(mouseValue)

            KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "replace-device", saved)
            local keyboardValue = {
                Keyboard = { Key = "K", ModifierKeys = { "LALT" } },
                Enabled = false,
                AllowConflict = false
            }
            KeybindingsRegistry.UpdateBinding(TEST_MOD_UUID, "replace-device", keyboardValue, true)
            D.expect(saved).toEqual(keyboardValue)
        end)

        MCMProxy.SetSettingValue = originalSetSettingValue
        if not ok then error(err) end
    end)

    D.test("applies authoritative keyboard mouse and unbound values", function()
        RegisterActions({ MouseAction("authoritative", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["authoritative"]

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Keyboard = { Key = "J", ModifierKeys = { "LSHIFT" } },
            Enabled = true,
            AllowConflict = false
        })
        D.expect(entry.keyboardBinding.Key).toBe("J")
        D.expect(entry.mouseBinding).toBeNil()

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Mouse = { Button = 6, ModifierKeys = { "LALT" } },
            Enabled = true,
            AllowConflict = true
        })
        D.expect(entry.keyboardBinding).toBeNil()
        D.expect(entry.mouseBinding.Button).toBe(6)
        D.expect(entry.allowConflict).toBeTruthy()

        KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "authoritative", {
            Keyboard = { Key = "", ModifierKeys = {} },
            Enabled = true,
            AllowConflict = false
        })
        D.expect(entry.keyboardBinding.Key).toBe("")
        D.expect(entry.mouseBinding).toBeNil()
    end)

    D.test("does not clear a binding when the authoritative value is missing", function()
        RegisterActions({ MouseAction("missing-authority", { Button = 7, ModifierKeys = {} }) })
        local entry = KeybindingsRegistry.GetRegistry()[TEST_MOD_UUID]["missing-authority"]

        D.expect(KeybindingsRegistry.ApplyBindingValue(TEST_MOD_UUID, "missing-authority", nil)).toBeFalsy()
        D.expect(entry.mouseBinding.Button).toBe(7)
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

        D.expect(entry.mouseBinding.Button).toBe(7)
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

        D.expect(entry.mouseBinding.Button).toBe(6)
    end)

    D.test("dispatches raw mouse press and release and prevents both edges", function()
        RegisterActions({ MouseAction("mouse-dispatch", {
            Button = 10,
            ModifierKeys = { "RALT", "RCTRL", "RSHIFT" }
        }) })
        local downEvent = nil
        local upEvent = nil
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-dispatch", "KeyboardMouse",
            function(e) downEvent = e end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-dispatch", "KeyboardMouse",
            function(e) upEvent = e end, "KeyUp")

        local press = MouseEvent(true, 10)
        local release = MouseEvent(false, 10)
        KeybindingsRegistry.DispatchMouseEvent(press, { "RSHIFT", "RALT", "RCTRL" })
        KeybindingsRegistry.DispatchMouseEvent(release, {})

        D.expect(downEvent).toBe(press)
        D.expect(upEvent).toBe(release)
        D.expect(press.prevented).toBeTruthy()
        D.expect(release.prevented).toBeTruthy()
    end)

    D.test("dispatches keyboard input through shared identity", function()
        local action = MouseAction("keyboard-dispatch", nil)
        action.KeyboardMouseBinding = { Key = "K", ModifierKeys = { "LCTRL", "LALT" } }
        action.DefaultKeyboardMouseBinding = action.KeyboardMouseBinding
        RegisterActions({ action })

        local calls = 0
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "keyboard-dispatch", "KeyboardMouse",
            function() calls = calls + 1 end, "KeyDown")
        local event = {
            Key = "k",
            Modifiers = { "LALT", "LCTRL" },
            Event = "KeyDown",
            Repeat = false,
            prevented = false,
            PreventAction = function(self) self.prevented = true end
        }
        KeybindingsRegistry.DispatchKeyboardEvent(event)

        D.expect(calls).toBe(1)
        D.expect(event.prevented).toBeTruthy()
    end)

    ---@param key string
    ---@param modifiers string[]|nil
    local function KeyEvent(key, modifiers)
        return {
            Key = key,
            Modifiers = modifiers,
            Event = "KeyDown",
            Repeat = false,
            prevented = false,
            PreventAction = function(self) self.prevented = true end
        }
    end

    ---Registers one keyboard action and counts how often it fires.
    ---@param id string
    ---@param binding KeybindingKeyboardBinding
    ---@param events { Key: string, Modifiers: string[]|nil }[]
    ---@return integer
    local function DispatchKeysCount(id, binding, events)
        local action = MouseAction(id, nil)
        action.KeyboardMouseBinding = binding
        action.DefaultKeyboardMouseBinding = binding
        RegisterActions({ action })

        local calls = 0
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, id, "KeyboardMouse",
            function() calls = calls + 1 end, "KeyDown")
        for _, input in ipairs(events) do
            KeybindingsRegistry.DispatchKeyboardEvent(KeyEvent(input.Key, input.Modifiers))
        end
        return calls
    end

    D.test("dispatches plain keyboard bindings past unsupported live modifiers", function()
        local calls = DispatchKeysCount("plain-key-noise", { Key = "K", ModifierKeys = {} }, {
            { Key = "K", Modifiers = {} },
            { Key = "K", Modifiers = nil },
            { Key = "K", Modifiers = { "NONE", "" } },
            { Key = "K", Modifiers = { "NUM" } },
            { Key = "K", Modifiers = { "CAPS", "NUM", "LGUI", "RGUI", "MODE", "SCROLL" } },
        })

        D.expect(calls).toBe(5)
    end)

    D.test("keeps exact matching for plain keyboard bindings", function()
        local calls = DispatchKeysCount("plain-key-exact", { Key = "K", ModifierKeys = {} }, {
            { Key = "K", Modifiers = { "LCTRL" } },
            { Key = "K", Modifiers = { "LCTRL", "LALT" } },
            { Key = "J", Modifiers = {} },
        })

        D.expect(calls).toBe(0)
    end)

    D.test("dispatches modified keyboard bindings past unsupported live modifiers", function()
        local calls = DispatchKeysCount("mod-key-noise", { Key = "K", ModifierKeys = { "LCTRL" } }, {
            { Key = "K", Modifiers = { "LCTRL" } },
            { Key = "k", Modifiers = { "lctrl", "LCTRL", "NUM" } },
            { Key = "K", Modifiers = { "LCTRL", "CAPS" } },
        })

        D.expect(calls).toBe(3)
    end)

    D.test("rejects incomplete, wrong, or extra supported modifiers", function()
        local calls = DispatchKeysCount("mod-key-reject", { Key = "K", ModifierKeys = { "LCTRL" } }, {
            { Key = "K", Modifiers = {} },
            { Key = "K", Modifiers = { "LALT" } },
            { Key = "K", Modifiers = { "LCTRL", "LALT" } },
        })

        D.expect(calls).toBe(0)
    end)

    D.test("never matches unsupported modifiers on either side", function()
        local calls = DispatchKeysCount("junk-key", { Key = "K", ModifierKeys = { "LGUI" } }, {
            { Key = "K", Modifiers = {} },
            { Key = "K", Modifiers = { "LGUI" } },
        })

        D.expect(calls).toBe(0)
    end)

    D.test("dispatches mouse bindings past unsupported held modifiers", function()
        RegisterActions({
            MouseAction("mouse-noise", { Button = 5, ModifierKeys = {} }),
            MouseAction("mouse-mod-noise", { Button = 6, ModifierKeys = { "LCTRL" } }),
        })
        local plain = 0
        local modified = 0
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-noise", "KeyboardMouse",
            function() plain = plain + 1 end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-noise", "KeyboardMouse",
            function() end, "KeyUp")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-mod-noise", "KeyboardMouse",
            function() modified = modified + 1 end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "mouse-mod-noise", "KeyboardMouse",
            function() end, "KeyUp")

        for _, held in ipairs({ {}, { "NUM" }, { "CAPS", "SCROLL" } }) do
            KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 5), held)
            KeybindingsRegistry.DispatchMouseEvent(MouseEvent(false, 5), held)
        end
        for _, held in ipairs({ { "LCTRL" }, { "LCTRL", "NUM" } }) do
            KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 6), held)
            KeybindingsRegistry.DispatchMouseEvent(MouseEvent(false, 6), held)
        end
        KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 6), {})
        KeybindingsRegistry.DispatchMouseEvent(MouseEvent(false, 6), {})

        D.expect(plain).toBe(3)
        D.expect(modified).toBe(2)
    end)

    D.test("does not prevent mouse edges when PreventAction is false", function()
        RegisterActions({ MouseAction("observe-mouse", { Button = 9, ModifierKeys = {} }, false, false) })
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "observe-mouse", "KeyboardMouse", function() end)
        local press = MouseEvent(true, 9)
        local release = MouseEvent(false, 9)

        KeybindingsRegistry.DispatchMouseEvent(press, {})
        KeybindingsRegistry.DispatchMouseEvent(release, {})

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

    D.test("reports all actions in a blocked conflict", function()
        RegisterActions({
            MouseAction("runtime-conflict-one", { Button = 3, ModifierKeys = {} }),
            MouseAction("runtime-conflict-two", { Button = 3, ModifierKeys = {} })
        })
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "runtime-conflict-one", "KeyboardMouse", function() end)
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "runtime-conflict-two", "KeyboardMouse", function() end)

        local originalWarn = MCMWarn
        local originalNotifyConflict = KeybindingsRegistry.NotifyConflict
        local warningActions = nil
        MCMWarn = function(_, format, _, actions)
            if format == "Keybinding conflict detected for: %s. Conflicting actions: %s" then
                warningActions = actions
            end
        end
        KeybindingsRegistry.NotifyConflict = function() end

        local ok, err = pcall(function()
            KeybindingsRegistry.DispatchMouseEvent(MouseEvent(true, 3), {})
        end)

        MCMWarn = originalWarn
        KeybindingsRegistry.NotifyConflict = originalNotifyConflict
        if not ok then error(err) end

        D.expect(warningActions).toContain("'runtime-conflict-one'")
        D.expect(warningActions).toContain("'runtime-conflict-two'")
    end)

    D.test("compares exact keyboard and mouse identities", function()
        D.expect(KeybindingManager:GetBindingIdentity(
            { Keyboard = { Key = "k", ModifierKeys = { "LCTRL", "LALT" } } }
        )).toBe("keyboard:K:LALT+LCTRL")
        D.expect(KeybindingManager:GetBindingIdentity(
            { Mouse = { Button = 5, ModifierKeys = { "LCTRL", "LALT" } } }
        )).toBe("mouse:5:LALT+LCTRL")

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

        local press = MouseEvent(true, KeybindingManager.MOUSE_BUTTON_MAX + 1)
        local ok, err = pcall(function()
            session:HandleMouseInput(press)
        end)
        if not ok then error(err) end

        D.expect(press.prevented).toBeTruthy()
        D.expect(press.stopped).toBeTruthy()
        D.expect(outcome).toBeNil()

        local release = MouseEvent(false, KeybindingManager.MOUSE_BUTTON_MAX + 1)
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

    D.test("uses current registry flags when committing a captured binding", function()
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
        local saved = nil
        widget.NotifyAssignmentConflict = function() end
        widget.StoreKeybinding = function(_, _, _, payload)
            saved = payload
            return true
        end

        InputCallbackManager._HeldModifiers = { LCTRL = true }
        local ok, err = pcall(function()
            widget:StartListeningForInput(
                { ModUUID = TEST_MOD_UUID },
                action,
                "KeyboardMouse",
                { Label = "", Disabled = false }
            )
            D.expect(widget._captureSession).Not.toBeNil()
            widget._captureSession:HandleMouseInput(MouseEvent(true, 2))
            widget._captureSession:HandleMouseInput(MouseEvent(false, 2))
        end)
        InputCallbackManager._HeldModifiers = {}
        if not ok then error(err) end

        D.expect(saved).Not.toBeNil()
        D.expect(saved.Enabled).toBeFalsy()
        D.expect(saved.AllowConflict).toBeTruthy()
        D.expect(saved.Mouse.Button).toBe(2)
        D.expect(saved.Mouse.ModifierKeys).toEqual({ "LCTRL" })
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

    D.test("presents legacy empty mouse companions as keyboard bindings", function()
        local originalGetSettingValue = MCMAPI.GetSettingValue
        MCMAPI.GetSettingValue = function()
            return {
                Keyboard = { Key = "K", ModifierKeys = { "LCTRL" } },
                Mouse = { Button = 0, ModifierKeys = {} }
            }
        end
        local ok, result = pcall(function()
            return KeyPresentationMapping:GetViewKeyForSetting("legacy", TEST_MOD_UUID)
        end)
        MCMAPI.GetSettingValue = originalGetSettingValue
        if not ok then error(result) end
        D.expect(result).toBe("[Left Ctrl] + [K]")
        D.expect(KeyPresentationMapping:GetKBViewKey({ Key = "K", ModifierKeys = { "NONE", "" } }))
            .toBe("[K]")
        D.expect(KeyPresentationMapping:GetMouseViewKey({ Button = 1, ModifierKeys = {} }))
            .toBe("[Left Mouse Button]")
        D.expect(KeyPresentationMapping:GetMouseViewKey({ Button = 10, ModifierKeys = {} }))
            .toBe("[Mouse 10]")
    end)

    D.test("registers callbacks queued before and added after load", function()
        RegisterActions({ MouseAction("callback-load", { Button = 8, ModifierKeys = {} }) })
        local originalLoaded = InputCallbackManager._KeybindingsLoaded
        local originalSubscribed = InputCallbackManager._KeybindingsLoadedSubscribed
        local originalPending = InputCallbackManager._PendingKeybindingCallbacks
        local originalRegister = InputCallbackManager.RegisterKeybinding
        local originalLoadedSubject = InputCallbackManager.KeybindingsLoadedSubject
        local registrations = 0
        local subscriptions = 0
        local loadedCallback = nil
        InputCallbackManager._KeybindingsLoaded = false
        InputCallbackManager._KeybindingsLoadedSubscribed = false
        InputCallbackManager._PendingKeybindingCallbacks = {}
        InputCallbackManager.KeybindingsLoadedSubject = {
            Subscribe = function(_, callback)
                subscriptions = subscriptions + 1
                loadedCallback = callback
            end
        }
        InputCallbackManager.RegisterKeybinding = function(...)
            registrations = registrations + 1
            return true
        end

        local ok, err = pcall(function()
            InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "callback-load", function() end)
            InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "callback-load", function() end)
            D.expect(subscriptions).toBe(1)
            loadedCallback(true)
            InputCallbackManager.SetKeybindingCallback(TEST_MOD_UUID, "callback-load", function() end)
            D.expect(registrations).toBe(3)
            D.expect(#InputCallbackManager._PendingKeybindingCallbacks).toBe(0)
            D.expect(InputCallbackManager._KeybindingsLoadedSubscribed).toBeTruthy()
        end)

        InputCallbackManager._KeybindingsLoaded = originalLoaded
        InputCallbackManager._KeybindingsLoadedSubscribed = originalSubscribed
        InputCallbackManager._PendingKeybindingCallbacks = originalPending
        InputCallbackManager.RegisterKeybinding = originalRegister
        InputCallbackManager.KeybindingsLoadedSubject = originalLoadedSubject
        if not ok then error(err) end
    end)

    D.test("allowed mouse conflicts select each event-specific callback", function()
        local modifiers = { "RALT", "RCTRL", "RSHIFT" }
        RegisterActions({
            MouseAction("first", { Button = 10, ModifierKeys = modifiers }, true),
            MouseAction("second", { Button = 10, ModifierKeys = modifiers }, false)
        })
        local downCalls = 0
        local upCalls = 0
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "first", "KeyboardMouse",
            function() downCalls = downCalls + 1 end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "second", "KeyboardMouse",
            function() downCalls = downCalls + 1 end, "KeyDown")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "first", "KeyboardMouse",
            function() upCalls = upCalls + 1 end, "KeyUp")
        KeybindingsRegistry.RegisterCallback(TEST_MOD_UUID, "second", "KeyboardMouse",
            function() upCalls = upCalls + 1 end, "KeyUp")

        local press = MouseEvent(true, 10)
        local release = MouseEvent(false, 10)
        KeybindingsRegistry.DispatchMouseEvent(press, modifiers)
        KeybindingsRegistry.DispatchMouseEvent(release, {})
        D.expect(downCalls).toBe(2)
        D.expect(upCalls).toBe(2)
        D.expect(press.prevented).toBeTruthy()
        D.expect(release.prevented).toBeTruthy()
    end)
end)
