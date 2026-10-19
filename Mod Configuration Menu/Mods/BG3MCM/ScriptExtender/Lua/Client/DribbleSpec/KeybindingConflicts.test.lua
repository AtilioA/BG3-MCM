local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

D.describe("keybinding native catalog reuse", { tags = { "keybinding_v2", "client", "unit" } }, function()
    local MOD_A = "00000000-0000-0000-0000-0000000000A1"
    local MOD_B = "00000000-0000-0000-0000-0000000000B2"

    ---@param id string
    ---@param key string
    ---@return table
    local function KeyboardAction(id, key)
        return {
            ActionId = id,
            ActionName = id,
            KeyboardMouseBinding = { Key = key, ModifierKeys = {} },
            DefaultKeyboardMouseBinding = { Key = key, ModifierKeys = {} },
            Enabled = true,
            DefaultEnabled = true,
            AllowConflict = false,
            DefaultAllowConflict = false,
            ShouldTriggerOnKeyDown = true,
            ShouldTriggerOnKeyUp = true,
            PreventAction = true,
            Tooltip = "",
            Description = ""
        }
    end

    ---@param modUUID string
    ---@param actions table[]
    ---@return nil
    local function Register(modUUID, actions)
        KeybindingsRegistry.RegisterModKeybindings({ {
            ModUUID = modUUID,
            KeybindingSortMode = KeybindingSortMode.DEFAULT,
            Actions = actions
        } }, { includeDeveloper = true })
    end

    ---Registers two actions and removes them afterwards.
    ---@return nil
    local function Cleanup()
        local registry = KeybindingsRegistry.GetRegistry()
        registry[MOD_A] = nil
        registry[MOD_B] = nil
        KeybindingsRegistry.GetSubject():OnNext(registry)
    end

    D.afterEach(Cleanup)

    D.test("shared catalog matches per-row fetch results", function(ctx)
        Register(MOD_A, { KeyboardAction("a1", "K") })
        Register(MOD_B, { KeyboardAction("b1", "K") })

        local getAllCalls = 0
        ctx.stub(NativeKeybindings, "GetAll", function()
            getAllCalls = getAllCalls + 1
            return {
                Public = { {
                    EventName = "NativeJump",
                    Bindings = { { InputType = "Keyboard", InputId = "J", Modifiers = {} } }
                } },
                Internal = {}
            }
        end)

        local mod = { ModUUID = MOD_A, ModName = "M" }
        local action = { ActionId = "a1", ActionName = "a1", AllowConflict = false }

        -- One shared fetch, reused across rows.
        local nativeData = NativeKeybindings.GetAll()
        D.expect(getAllCalls).toBe(1)

        local sharedMcm = KeybindingConflictService:CheckForConflicts(
            { Key = "K", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)
        local sharedNative = KeybindingConflictService:CheckForConflicts(
            { Key = "J", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)
        local sharedMiss = KeybindingConflictService:CheckForConflicts(
            { Key = "Z", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)
        D.expect(getAllCalls).toBe(1)

        D.expect(sharedMcm).toBeTruthy()
        D.expect(sharedMcm.ActionName).toBe("b1")
        D.expect(sharedNative).toBeTruthy()
        D.expect(sharedNative.ActionName).toBe("NativeJump")
        D.expect(sharedMiss).toBeNil()

        -- Same queries without the shared catalog return the same results.
        local freshMcm = KeybindingConflictService:CheckForConflicts(
            { Key = "K", ModifierKeys = {} }, mod, action, "KeyboardMouse")
        local freshNative = KeybindingConflictService:CheckForConflicts(
            { Key = "J", ModifierKeys = {} }, mod, action, "KeyboardMouse")
        D.expect(freshMcm).toBeTruthy()
        D.expect(freshMcm.ActionName).toBe(sharedMcm.ActionName)
        D.expect(freshNative).toBeTruthy()
        D.expect(freshNative.ActionName).toBe(sharedNative.ActionName)
    end)
end)
