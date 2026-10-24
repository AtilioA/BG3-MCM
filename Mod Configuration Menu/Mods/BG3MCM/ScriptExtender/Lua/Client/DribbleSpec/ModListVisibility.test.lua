D.describe("ModListVisibility", { tags = { "mod_list_visibility", "client", "unit" } }, function()
    local MOD_A = "00000000-0000-0000-0000-00000000A001"
    local MOD_B = "00000000-0000-0000-0000-00000000B002"
    local MOD_C = "00000000-0000-0000-0000-00000000C003"
    local MOD_D = "00000000-0000-0000-0000-00000000D004"
    local ABSENT_MOD = "00000000-0000-0000-0000-00000000E005"

    --- In-memory stand-in for MCM.Store, so tests never touch the player's MCM_state.json
    ---@param values? table<string, any> Initial Store values, e.g. { UI = ... }
    ---@param unreadable? boolean Whether the state file failed to parse, so Store refuses writes
    ---@return table store
    local function FakeStore(values, unreadable)
        values = values or {}
        return {
            values = values,
            RegisterVar = function() return true end,
            Get = function(var) return values[var] end,
            Set = function(var, value)
                if unreadable then return false end
                values[var] = value
                return true
            end,
            IsWritable = function() return not unreadable end,
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

    D.test("hiding and showing save an explicit choice and keep other choices", function()
        local store = FakeStore({ UI = UIWithChoices({ [ABSENT_MOD] = true }) })
        local visibility = ModListVisibility:New(store)

        visibility:SetHidden(MOD_A, true)
        local _, hiddenAfterHide = visibility:Resolve({ MOD_A, MOD_B })
        D.expect(hiddenAfterHide).toEqual({ MOD_A })
        D.expect(store.values).toEqual({
            Version = 1,
            UI = { Mods = { [ABSENT_MOD] = { HiddenFromList = true }, [MOD_A] = { HiddenFromList = true } } }
        })

        visibility:SetHidden(MOD_A, false)
        local mainAfterShow, hiddenAfterShow = visibility:Resolve({ MOD_A, MOD_B })
        D.expect(mainAfterShow).toEqual({ MOD_A, MOD_B })
        D.expect(hiddenAfterShow).toEqual({})
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("with no choice, the author default decides", function()
        local store = FakeStore()
        local visibility = ModListVisibility:New(store)

        local main, hidden, hiddenCount = visibility:Resolve({ MOD_A, MOD_B, MOD_C }, { [MOD_A] = true, [MOD_B] = false })

        D.expect(main).toEqual({ MOD_B, MOD_C })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
        D.expect(store.values).toEqual({})
    end)

    D.test("explicit choices override the author default", function()
        local visibility = ModListVisibility:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = false, [MOD_B] = true })
        }))

        local main, hidden = visibility:Resolve({ MOD_A, MOD_B }, { [MOD_A] = true, [MOD_B] = false })

        D.expect(main).toEqual({ MOD_A })
        D.expect(hidden).toEqual({ MOD_B })
    end)

    D.test("UseDefault removes the choice and keeps other state", function()
        local store = FakeStore({
            Version = 1,
            UI = {
                Other = "kept",
                Mods = {
                    [MOD_A] = { HiddenFromList = false, Other = "kept" },
                    [MOD_B] = { HiddenFromList = false },
                    [ABSENT_MOD] = { HiddenFromList = true },
                },
            },
        })
        local visibility = ModListVisibility:New(store)
        D.expect(visibility:HasChoice(MOD_A)).toBe(true)
        D.expect(visibility:HasChoice(MOD_C)).toBe(false)

        visibility:UseDefault(MOD_A)
        visibility:UseDefault(MOD_B)

        D.expect(visibility:HasChoice(MOD_A)).toBe(false)
        D.expect(visibility:HasChoice(MOD_B)).toBe(false)
        local main, hidden = visibility:Resolve({ MOD_A, MOD_B }, { [MOD_A] = true })
        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(store.values).toEqual({
            Version = 1,
            UI = {
                Other = "kept",
                Mods = { [MOD_A] = { Other = "kept" }, [ABSENT_MOD] = { HiddenFromList = true } },
            },
        })
    end)

    D.test("an unreadable state document resolves author defaults and refuses choices", function()
        local store = FakeStore({}, true)
        local visibility = ModListVisibility:New(store)

        local main, hidden = visibility:Resolve({ MOD_A, MOD_B }, { [MOD_A] = true })
        local hideSaved = visibility:SetHidden(MOD_B, true)

        D.expect(visibility:IsProtected()).toBe(true)
        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hideSaved).toBe(false)
        D.expect(store.values).toEqual({})
    end)

    D.test("a newer-version state document stays unchanged", function()
        local values = { Version = 2, UI = UIWithChoices({ [MOD_A] = false }) }
        local store = FakeStore(values)
        local visibility = ModListVisibility:New(store)

        local hideSaved = visibility:SetHidden(MOD_A, true)
        local showSaved = visibility:SetHidden(MOD_B, false)
        local useDefaultSaved = visibility:UseDefault(MOD_A)

        D.expect(visibility:IsProtected()).toBe(true)
        D.expect({ hideSaved, showSaved, useDefaultSaved }).toEqual({ false, false, false })
        D.expect(store.values).toEqual({ Version = 2, UI = UIWithChoices({ [MOD_A] = false }) })
    end)

    D.test("a readable current-version state document accepts choices", function()
        local store = FakeStore({ Version = 1 })
        local visibility = ModListVisibility:New(store)

        D.expect(visibility:IsProtected()).toBe(false)
        D.expect(visibility:SetHidden(MOD_A, true)).toBe(true)
        D.expect(visibility:HasChoice(MOD_A)).toBe(true)
        local main, hidden = visibility:Resolve({ MOD_A, MOD_B })
        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = true })
    end)
end)
