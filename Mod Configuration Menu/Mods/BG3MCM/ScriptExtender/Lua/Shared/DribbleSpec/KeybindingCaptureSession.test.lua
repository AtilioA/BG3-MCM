D.describe("keybinding capture session", { tags = { "keybinding_v2", "client", "unit" } }, function()
    local function KeyEvent(eventType, key)
        return {
            Event = eventType,
            Key = key,
            Repeat = false,
            prevented = false,
            stopped = false,
            PreventAction = function(self) self.prevented = true end,
            StopPropagation = function(self) self.stopped = true end
        }
    end

    local function MouseEvent(pressed, button)
        return {
            Pressed = pressed,
            Button = button,
            prevented = false,
            stopped = false,
            PreventAction = function(self) self.prevented = true end,
            StopPropagation = function(self) self.stopped = true end
        }
    end

    D.afterEach(function()
        KeybindingCaptureSession.Reset("test-cleanup")
        InputCallbackManager._HeldModifiers = {}
    end)

    D.test("owns one session and restores all temporary resources", function()
        local originalWindow = MCM_WINDOW
        local testWindow = { NoMouseInputs = false }
        local outcome = nil
        MCM_WINDOW = testWindow

        local ok, err = pcall(function()
            local session = KeybindingCaptureSession.Start({
                OnComplete = function(value) outcome = value end
            })

            D.expect(session).Not.toBeNil()
            D.expect(KeybindingCaptureSession.IsActive()).toBeTruthy()
            D.expect(testWindow.NoMouseInputs).toBeTruthy()
            D.expect(session.Subscriptions.KeyInput).Not.toBeNil()
            D.expect(session.Subscriptions.MouseButtonInput).Not.toBeNil()
            D.expect(session.Subscriptions.WindowClosed).Not.toBeNil()
            D.expect(session.Subscriptions.GameStateChanged).Not.toBeNil()
            D.expect(session.Subscriptions.Timeout).Not.toBeNil()
            D.expect(KeybindingCaptureSession.Start({ OnComplete = function() end })).toBeNil()

            session:Cancel("cancelled")
            D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
            D.expect(testWindow.NoMouseInputs).toBeFalsy()
            D.expect(next(session.Subscriptions)).toBeNil()
            D.expect(outcome).toEqual({ kind = "cancelled", reason = "cancelled" })
        end)

        KeybindingCaptureSession.Reset("test-cleanup")
        MCM_WINDOW = originalWindow
        if not ok then error(err) end
    end)

    D.test("returns a keyboard binding after the claimed release", function()
        local outcome = nil
        InputCallbackManager._HeldModifiers = { LCTRL = true }
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) outcome = value end
        })

        local press = KeyEvent("KeyDown", "k")
        session:HandleKeyInput(press)
        D.expect(outcome).toBeNil()
        D.expect(session.State).toBe("awaiting-release")
        D.expect(press.prevented).toBeTruthy()
        D.expect(press.stopped).toBeTruthy()

        local release = KeyEvent("KeyUp", "k")
        session:HandleKeyInput(release)
        D.expect(outcome).toEqual({
            kind = "binding",
            binding = { Key = "K", ModifierKeys = { "LCTRL" } },
            reason = "released"
        })
        D.expect(release.prevented).toBeTruthy()
        D.expect(release.stopped).toBeTruthy()
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Keyboard", "K", true)).toBeTruthy()
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Keyboard", "K", true)).toBeFalsy()
    end)

    D.test("hands a mouse release to global input after timeout cleanup", function()
        local outcome = nil
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) outcome = value end
        })

        session:HandleMouseInput(MouseEvent(true, 8))
        session:Cancel("timeout")

        D.expect(outcome).toEqual({
            kind = "binding",
            binding = { Button = 8, ModifierKeys = {} },
            reason = "timeout"
        })
        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", 8, true)).toBeTruthy()
    end)

    D.test("returns escape as a cancellation outcome", function()
        local outcome = nil
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) outcome = value end
        })

        session:HandleKeyInput(KeyEvent("KeyDown", "ESCAPE"))
        session:HandleKeyInput(KeyEvent("KeyUp", "ESCAPE"))

        D.expect(outcome).toEqual({ kind = "cancelled", reason = "escape" })
        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
    end)
end)
