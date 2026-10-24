D.describe("keybinding capture session", { tags = { "keybinding_v2", "client", "unit" } }, function()
    local function KeyEvent(eventType, key)
        return {
            Event = eventType,
            Key = key,
            Modifiers = {},
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

    local function MouseEvent(pressed, button)
        return {
            Pressed = pressed,
            Button = button,
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

    local originalWindow
    local capturedWindow = false
    local heldModifiersBefore
    local ownsCaptureState = false

    D.beforeEach(function(ctx)
        if KeybindingCaptureSession.IsActive() then
            ctx.skip("A player capture session is already active")
        end
        ownsCaptureState = true
        heldModifiersBefore = InputCallbackManager._HeldModifiers
        InputCallbackManager._HeldModifiers = {}
    end)

    D.afterEach(function()
        if not ownsCaptureState then return end
        ownsCaptureState = false
        KeybindingCaptureSession.Reset("reset")
        InputCallbackManager._HeldModifiers = heldModifiersBefore or {}
        heldModifiersBefore = nil
        if capturedWindow then
            MCM_WINDOW = originalWindow
            capturedWindow = false
        end
    end)

    D.test("restores window input and completes once on cancellation and window close", function()
        originalWindow = MCM_WINDOW
        capturedWindow = true
        local window = { NoMouseInputs = false }
        local outcomes = {}
        MCM_WINDOW = window

        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value) table.insert(outcomes, value) end,
        })
        D.expect(session).Not.toBeNil()
        D.expect(window.NoMouseInputs).toBe(true)
        D.expect(KeybindingCaptureSession.Start({ OnComplete = function() end })).toBeNil()

        session:Cancel("cancelled")
        session:Cancel("cancelled")
        session:HandleKeyInput(KeyEvent("KeyUp", "K"))
        D.expect(KeybindingCaptureSession.IsActive()).toBe(false)
        D.expect(window.NoMouseInputs).toBe(false)
        D.expect(outcomes).toEqual({ { kind = "cancelled", reason = "cancelled" } })

        local nextSession = KeybindingCaptureSession.Start({
            OnComplete = function(value) table.insert(outcomes, value) end,
        })
        D.expect(window.NoMouseInputs).toBe(true)
        nextSession:HandleMouseInput(MouseEvent(true, 8))
        Ext.ModEvents["BG3MCM"][EventChannels.MCM_WINDOW_CLOSED]:Throw({})
        D.expect(KeybindingCaptureSession.IsActive()).toBe(false)
        D.expect(window.NoMouseInputs).toBe(false)
        D.expect(outcomes).toEqual({
            { kind = "cancelled", reason = "cancelled" },
            { kind = "binding", binding = { Button = 8, ModifierKeys = {} }, reason = "window-closed" },
        })
        Ext.ModEvents["BG3MCM"][EventChannels.MCM_WINDOW_CLOSED]:Throw({})
        D.expect(#outcomes).toBe(2)
    end)

    D.test("returns a keyboard binding after the claimed release", function()
        local outcome = nil
        local completions = 0
        InputCallbackManager._HeldModifiers = { LCTRL = true }
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value)
                completions = completions + 1
                outcome = value
            end
        })

        local press = KeyEvent("KeyDown", "k")
        session:HandleKeyInput(press)
        D.expect(outcome).toBeNil()
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
        session:Cancel("cancelled")
        session:HandleKeyInput(KeyEvent("KeyUp", "K"))
        D.expect(completions).toBe(1)
    end)

    D.test("retains the selected mouse release when closed with a timeout reason", function()
        local outcome = nil
        local completions = 0
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value)
                completions = completions + 1
                outcome = value
            end
        })

        session:HandleMouseInput(MouseEvent(true, 8))
        session:Cancel("timeout")
        session:Cancel("timeout")

        D.expect(outcome).toEqual({
            kind = "binding",
            binding = { Button = 8, ModifierKeys = {} },
            reason = "timeout"
        })
        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
        D.expect(KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", 8, true)).toBeTruthy()
        D.expect(completions).toBe(1)
    end)

    D.test("returns escape as a cancellation outcome", function()
        local outcome = nil
        local completions = 0
        local session = KeybindingCaptureSession.Start({
            OnComplete = function(value)
                completions = completions + 1
                outcome = value
            end
        })

        session:HandleKeyInput(KeyEvent("KeyDown", "ESCAPE"))
        session:HandleKeyInput(KeyEvent("KeyUp", "ESCAPE"))
        session:Cancel("cancelled")

        D.expect(outcome).toEqual({ kind = "cancelled", reason = "escape" })
        D.expect(KeybindingCaptureSession.IsActive()).toBeFalsy()
        D.expect(completions).toBe(1)
    end)
end)
