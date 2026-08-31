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
            PreventAction = function(self) self.prevented = true end
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

    D.test("compares exact keyboard and mouse identities", function()
        D.expect(KeybindingConflictService:AreKeybindingsEqual(
            { Button = 5, ModifierKeys = { "LCTRL", "LALT" } },
            { Button = 5, ModifierKeys = { "LALT", "LCTRL" } }
        )).toBeTruthy()
        D.expect(KeybindingConflictService:AreKeybindingsEqual(
            { Button = 5, ModifierKeys = { "LCTRL" } },
            { Button = 6, ModifierKeys = { "LCTRL" } }
        )).toBeFalsy()
        D.expect(KeybindingConflictService:AreKeybindingsEqual(
            { Key = "K", ModifierKeys = {} },
            { Button = 5, ModifierKeys = {} }
        )).toBeFalsy()
    end)

    D.test("normalizes a verified native middle mouse binding", function(ctx)
        local nativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")
        ctx.stub(nativeKeybindings, "GetAll", function()
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
