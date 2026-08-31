---@alias KeybindingCaptureDevice "Keyboard"|"Mouse"
---@alias KeybindingCaptureOutcomeKind "binding"|"cancelled"

---@class KeybindingCaptureOutcome
---@field kind KeybindingCaptureOutcomeKind
---@field binding? KeybindingKeyboardBinding|KeybindingMouseBinding
---@field reason string

---@class KeybindingCaptureOptions
---@field OnComplete fun(outcome: KeybindingCaptureOutcome)

---@class KeybindingCaptureSession
---@field State "listening"|"awaiting-release"|"closed"
---@field ClaimedInput? { Device: KeybindingCaptureDevice, Input: string|integer }
---@field PendingOutcome? KeybindingCaptureOutcome
---@field Subscriptions table
---@field Window? table
---@field PreviousNoMouseInputs boolean
---@field OnComplete? fun(outcome: KeybindingCaptureOutcome)
KeybindingCaptureSession = {}
KeybindingCaptureSession.__index = KeybindingCaptureSession

local activeSession = nil
local releaseClaims = { Keyboard = nil, Mouse = nil }
local CAPTURE_TIMEOUT_MS = 10000
local RELEASE_CLAIM_TIMEOUT_MS = 30000

---@param e EclLuaKeyInputEvent|EclLuaMouseButtonEvent
local function claimEvent(e)
    if e.PreventAction then e:PreventAction() end
    if e.StopPropagation then e:StopPropagation() end
end

---@param device KeybindingCaptureDevice
---@param input string|integer
local function claimRelease(device, input)
    releaseClaims[device] = {
        Input = input,
        Expires = Ext.Timer.MonotonicTime() + RELEASE_CLAIM_TIMEOUT_MS
    }
end

---Starts the one active capture session.
---@param options KeybindingCaptureOptions
---@return KeybindingCaptureSession|nil session
function KeybindingCaptureSession.Start(options)
    if activeSession then return nil end
    if type(options) ~= "table" or type(options.OnComplete) ~= "function" then
        error("KeybindingCaptureSession.Start requires an OnComplete callback")
    end

    local session = setmetatable({
        State = "listening",
        Subscriptions = {},
        Window = MCM_WINDOW,
        PreviousNoMouseInputs = MCM_WINDOW and MCM_WINDOW.NoMouseInputs == true or false,
        OnComplete = options.OnComplete
    }, KeybindingCaptureSession)
    activeSession = session

    if session.Window then session.Window.NoMouseInputs = true end
    session:RegisterSubscriptions()
    return session
end

---Returns whether capture currently owns raw input.
---@return boolean
function KeybindingCaptureSession.IsActive()
    return activeSession ~= nil
end

---Consumes a release retained after capture cleanup.
---@param device KeybindingCaptureDevice
---@param input string|integer
---@param isRelease boolean
---@return boolean claimed
function KeybindingCaptureSession.ConsumeClaimedRelease(device, input, isRelease)
    local claim = releaseClaims[device]
    if claim and Ext.Timer.MonotonicTime() > claim.Expires then
        releaseClaims[device] = nil
        claim = nil
    end
    if not isRelease or not claim or claim.Input ~= input then return false end

    releaseClaims[device] = nil
    return true
end

---Closes active capture and clears retained releases during input lifecycle resets.
---@param reason? string
function KeybindingCaptureSession.Reset(reason)
    local session = activeSession
    if session then session:Close(reason or "reset") end
    releaseClaims.Keyboard = nil
    releaseClaims.Mouse = nil
end

---Registers all temporary resources owned by this session.
function KeybindingCaptureSession:RegisterSubscriptions()
    local subscriptions = self.Subscriptions
    subscriptions.KeyInput = Ext.Events.KeyInput:Subscribe(function(e) self:HandleKeyInput(e) end)
    subscriptions.MouseButtonInput = Ext.Events.MouseButtonInput:Subscribe(function(e) self:HandleMouseInput(e) end)
    subscriptions.WindowClosed = ModEventManager:Subscribe(EventChannels.MCM_WINDOW_CLOSED, function()
        self:Close("window-closed")
    end)
    subscriptions.GameStateChanged = Ext.Events.GameStateChanged:Subscribe(function(e)
        if InputCallbackManager.IsInputCleanupGameState(e.ToState) then self:Close("game-state") end
    end)
    subscriptions.Timeout = Ext.Timer.WaitFor(CAPTURE_TIMEOUT_MS, function()
        subscriptions.Timeout = nil
        self:Close("timeout")
    end)
end

---Releases every temporary resource owned by this session.
function KeybindingCaptureSession:UnregisterSubscriptions()
    local subscriptions = self.Subscriptions
    if subscriptions.KeyInput then
        Ext.Events.KeyInput:Unsubscribe(subscriptions.KeyInput)
        subscriptions.KeyInput = nil
    end
    if subscriptions.MouseButtonInput then
        Ext.Events.MouseButtonInput:Unsubscribe(subscriptions.MouseButtonInput)
        subscriptions.MouseButtonInput = nil
    end
    if subscriptions.WindowClosed then
        ModEventManager:Unsubscribe(EventChannels.MCM_WINDOW_CLOSED, subscriptions.WindowClosed)
        subscriptions.WindowClosed = nil
    end
    if subscriptions.GameStateChanged then
        Ext.Events.GameStateChanged:Unsubscribe(subscriptions.GameStateChanged)
        subscriptions.GameStateChanged = nil
    end
    if subscriptions.Timeout then
        Ext.Timer.Cancel(subscriptions.Timeout)
        subscriptions.Timeout = nil
    end
end

---@param device KeybindingCaptureDevice
---@param input string|integer
---@param outcome KeybindingCaptureOutcome
function KeybindingCaptureSession:AwaitRelease(device, input, outcome)
    self.State = "awaiting-release"
    self.ClaimedInput = { Device = device, Input = input }
    self.PendingOutcome = outcome
    claimRelease(device, input)
end

---Handles keyboard capture and records one binding or cancellation outcome.
---@param e EclLuaKeyInputEvent
function KeybindingCaptureSession:HandleKeyInput(e)
    local key = tostring(e.Key):upper()
    local claimed = self.ClaimedInput
    if claimed and claimed.Device == "Keyboard" and e.Event == "KeyUp" and key == claimed.Input then
        claimEvent(e)
        self:Close("released")
        return
    end

    if self.State ~= "listening" or e.Event ~= "KeyDown" or e.Repeat then return end
    if KeybindingManager:IsActiveModifier(key) then return end

    claimEvent(e)
    if key == "ESCAPE" then
        self:AwaitRelease("Keyboard", key, { kind = "cancelled", reason = "escape" })
        return
    end

    local binding = key == "BACKSPACE"
        and { Key = "", ModifierKeys = {} }
        or { Key = key, ModifierKeys = InputCallbackManager.GetHeldModifiers() }
    self:AwaitRelease("Keyboard", key, { kind = "binding", binding = binding, reason = "selected" })
end

---Handles mouse capture and records one binding outcome.
---@param e EclLuaMouseButtonEvent
function KeybindingCaptureSession:HandleMouseInput(e)
    local claimed = self.ClaimedInput
    if claimed and claimed.Device == "Mouse" and not e.Pressed and e.Button == claimed.Input then
        claimEvent(e)
        self:Close("released")
        return
    end
    if self.State ~= "listening" or not e.Pressed then return end

    -- Swallow unsupported buttons like the previous capture path: claim both
    -- edges so the click never reaches the game, then finish without a binding.
    if e.Button < KeybindingManager.MOUSE_BUTTON_MIN or e.Button > KeybindingManager.MOUSE_BUTTON_MAX then
        claimEvent(e)
        self:AwaitRelease("Mouse", e.Button, { kind = "cancelled", reason = "unsupported-button" })
        return
    end

    claimEvent(e)
    self:AwaitRelease("Mouse", e.Button, {
        kind = "binding",
        binding = { Button = e.Button, ModifierKeys = InputCallbackManager.GetHeldModifiers() },
        reason = "selected"
    })
end

---Closes the session exactly once, restores resources, and emits one outcome.
---@param reason string
---@return boolean closed
function KeybindingCaptureSession:Close(reason)
    if self.State == "closed" then return false end
    self.State = "closed"
    self:UnregisterSubscriptions()
    if self.Window then self.Window.NoMouseInputs = self.PreviousNoMouseInputs end
    if activeSession == self then activeSession = nil end

    local outcome = self.PendingOutcome or { kind = "cancelled", reason = reason }
    if outcome.reason == "selected" then outcome.reason = reason end
    self.ClaimedInput = nil
    self.PendingOutcome = nil
    self.Window = nil
    local onComplete = self.OnComplete
    self.OnComplete = nil
    if onComplete then onComplete(outcome) end
    return true
end

---Cancels capture through the same cleanup path.
---@param reason? string
function KeybindingCaptureSession:Cancel(reason)
    self:Close(reason or "cancelled")
end

return KeybindingCaptureSession
