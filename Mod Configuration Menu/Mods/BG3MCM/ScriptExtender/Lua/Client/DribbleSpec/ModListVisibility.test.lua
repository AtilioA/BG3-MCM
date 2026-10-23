D.describe("ModListVisibility", { tags = { "mod_list_visibility", "client", "unit" } }, function()
    local MOD_A = "00000000-0000-0000-0000-00000000A001"
    local MOD_B = "00000000-0000-0000-0000-00000000B002"
    local MOD_C = "00000000-0000-0000-0000-00000000C003"
    local MOD_D = "00000000-0000-0000-0000-00000000D004"
    local ABSENT_MOD = "00000000-0000-0000-0000-00000000E005"

    --- In-memory stand-in for MCM.Store, so tests never touch the player's MCM_state.json
    ---@param values? table<string, any> Initial Store values, e.g. { UI = ... }
    ---@return table store
    local function FakeStore(values)
        values = values or {}
        return {
            values = values,
            RegisterVar = function() return true end,
            Get = function(var) return values[var] end,
            Set = function(var, value)
                values[var] = value
                return true
            end,
        }
    end

    ---@param choices table<string, boolean> Mod UUID -> HiddenFromList
    ---@return table ui
    local function UIWithChoices(choices)
        local mods = {}
        for modUUID, hidden in pairs(choices) do
            mods[modUUID] = { HiddenFromList = hidden }
        end
        return { Mods = mods }
    end

    D.test("explicit true moves the entry to Hidden mods", function()
        local visibility = ModListVisibility:New(FakeStore({ UI = UIWithChoices({ [MOD_A] = true }) }))

        local main, hidden, hiddenCount = visibility:Resolve({ MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
    end)

    D.test("explicit false keeps the entry in the main list", function()
        local visibility = ModListVisibility:New(FakeStore({ UI = UIWithChoices({ [MOD_A] = false }) }))

        local main, hidden, hiddenCount = visibility:Resolve({ MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_A, MOD_B })
        D.expect(hidden).toEqual({})
        D.expect(hiddenCount).toBe(0)
    end)

    D.test("both lists keep the mod-list order", function()
        local visibility = ModListVisibility:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = true, [MOD_C] = true })
        }))

        local main, hidden = visibility:Resolve({ MOD_D, MOD_C, MOD_B, MOD_A })

        D.expect(main).toEqual({ MOD_D, MOD_B })
        D.expect(hidden).toEqual({ MOD_C, MOD_A })
    end)

    D.test("choices for absent mods do not count", function()
        local visibility = ModListVisibility:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = true, [ABSENT_MOD] = true })
        }))

        local main, hidden, hiddenCount = visibility:Resolve({ MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
    end)

    D.test("Hide and Show save an explicit choice and keep other choices", function()
        local store = FakeStore({ UI = UIWithChoices({ [ABSENT_MOD] = true }) })
        local visibility = ModListVisibility:New(store)

        visibility:Hide(MOD_A)
        local _, hiddenAfterHide = visibility:Resolve({ MOD_A, MOD_B })
        D.expect(hiddenAfterHide).toEqual({ MOD_A })
        D.expect(store.values).toEqual({
            Version = 1,
            UI = { Mods = { [ABSENT_MOD] = { HiddenFromList = true }, [MOD_A] = { HiddenFromList = true } } }
        })

        visibility:Show(MOD_A)
        local mainAfterShow, hiddenAfterShow = visibility:Resolve({ MOD_A, MOD_B })
        D.expect(mainAfterShow).toEqual({ MOD_A, MOD_B })
        D.expect(hiddenAfterShow).toEqual({})
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)
end)
