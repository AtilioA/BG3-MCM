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

    D.test("shared catalog stays stable when the live catalog changes", function(ctx)
        Register(MOD_A, { KeyboardAction("a1", "K") })
        Register(MOD_B, { KeyboardAction("b1", "K") })

        local nativeEventName = "NativeJump"
        ctx.stub(NativeKeybindings, "GetAll", function()
            return {
                Public = { {
                    EventName = nativeEventName,
                    Bindings = { { InputType = "Keyboard", InputId = "J", Modifiers = {} } }
                } },
                Internal = {}
            }
        end)

        local mod = { ModUUID = MOD_A, ModName = "M" }
        local action = { ActionId = "a1", ActionName = "a1", AllowConflict = false }

        -- One shared fetch, reused across rows.
        local nativeData = NativeKeybindings.GetAll()
        nativeEventName = "NativeFly"

        local sharedMcm = KeybindingConflictService:CheckForConflicts(
            { Key = "K", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)
        local sharedNative = KeybindingConflictService:CheckForConflicts(
            { Key = "J", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)
        local sharedMiss = KeybindingConflictService:CheckForConflicts(
            { Key = "Z", ModifierKeys = {} }, mod, action, "KeyboardMouse", nativeData)

        D.expect(type(sharedMcm)).toBe("table")
        D.expect(sharedMcm.ActionName).toBe("b1")
        D.expect(sharedMcm.Keybinding.Key).toBe("K")
        D.expect(sharedMcm.Keybinding.ModifierKeys).toEqual({})
        D.expect(type(sharedNative)).toBe("table")
        D.expect(sharedNative.ActionName).toBe("NativeJump")
        D.expect(sharedNative.Keybinding.Key).toBe("J")
        D.expect(sharedMiss).toBeNil()

        -- A fresh query sees the updated catalog; supplied catalogs keep their contents.
        local freshMcm = KeybindingConflictService:CheckForConflicts(
            { Key = "K", ModifierKeys = {} }, mod, action, "KeyboardMouse")
        local freshNative = KeybindingConflictService:CheckForConflicts(
            { Key = "J", ModifierKeys = {} }, mod, action, "KeyboardMouse")
        D.expect(freshMcm.ActionName).toBe("b1")
        D.expect(freshMcm.Keybinding.Key).toBe("K")
        D.expect(freshNative.ActionName).toBe("NativeFly")
        D.expect(freshNative.Keybinding.Key).toBe("J")
    end)
end)
