D.describe("ModListState", { tags = { "mod_list_visibility", "client", "unit" } }, function()
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
            IsWritable = function() return not unreadable end,
            -- These suites cover the layout, so they run in Manual; ModListSorting.test.lua covers the modes
            Get = function(var)
                if var == "ModListPreferences" and values[var] == nil then return { SortMode = "manual" } end
                return values[var]
            end,
            Set = function(var, value)
                if unreadable then return false end
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

    local function resolve(state, ids, defaults)
        local mods, author = {}, {}
        for _, id in ipairs(ids) do
            table.insert(mods, { id = id, name = id })
            author[id] = { HiddenFromList = defaults and defaults[id] }
        end
        local result = state:Resolve(mods, author)
        local main, hidden = {}, {}
        for _, item in ipairs(result.main) do table.insert(main, item.id) end
        for _, item in ipairs(result.hidden) do table.insert(hidden, item.id) end
        return main, hidden, #hidden
    end

    D.test("explicit true moves the entry to Hidden mods", function()
        local visibility = ModListState:New(FakeStore({ UI = UIWithChoices({ [MOD_A] = true }) }))

        local main, hidden, hiddenCount = resolve(visibility, { MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
    end)

    D.test("explicit false keeps the entry in the main list", function()
        local visibility = ModListState:New(FakeStore({ UI = UIWithChoices({ [MOD_A] = false }) }))

        local main, hidden, hiddenCount = resolve(visibility, { MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_A, MOD_B })
        D.expect(hidden).toEqual({})
        D.expect(hiddenCount).toBe(0)
    end)

    D.test("both lists sort alphabetically", function()
        local visibility = ModListState:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = true, [MOD_C] = true })
        }))

        local main, hidden = resolve(visibility, { MOD_D, MOD_C, MOD_B, MOD_A })

        D.expect(main).toEqual({ MOD_B, MOD_D })
        D.expect(hidden).toEqual({ MOD_A, MOD_C })
    end)

    D.test("choices for absent mods do not count", function()
        local visibility = ModListState:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = true, [ABSENT_MOD] = true })
        }))

        local main, hidden, hiddenCount = resolve(visibility, { MOD_A, MOD_B })

        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
    end)

    D.test("hiding and showing save an explicit choice and keep other choices", function()
        local store = FakeStore({ UI = UIWithChoices({ [ABSENT_MOD] = true }) })
        local visibility = ModListState:New(store)

        visibility:SetHidden(MOD_A, true)
        local _, hiddenAfterHide = resolve(visibility, { MOD_A, MOD_B })
        D.expect(hiddenAfterHide).toEqual({ MOD_A })
        D.expect(store.values).toEqual({
            UI = { Mods = { [ABSENT_MOD] = { HiddenFromList = true }, [MOD_A] = { HiddenFromList = true } } }
        })

        visibility:SetHidden(MOD_A, false)
        local mainAfterShow, hiddenAfterShow = resolve(visibility, { MOD_A, MOD_B })
        D.expect(mainAfterShow).toEqual({ MOD_A, MOD_B })
        D.expect(hiddenAfterShow).toEqual({})
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("with no choice, the author default decides", function()
        local store = FakeStore()
        local visibility = ModListState:New(store)

        local main, hidden, hiddenCount = resolve(visibility, { MOD_A, MOD_B, MOD_C }, { [MOD_A] = true, [MOD_B] = false })

        D.expect(main).toEqual({ MOD_B, MOD_C })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hiddenCount).toBe(1)
        D.expect(store.values).toEqual({})
    end)

    D.test("explicit choices override the author default", function()
        local visibility = ModListState:New(FakeStore({
            UI = UIWithChoices({ [MOD_A] = false, [MOD_B] = true })
        }))

        local main, hidden = resolve(visibility, { MOD_A, MOD_B }, { [MOD_A] = true, [MOD_B] = false })

        D.expect(main).toEqual({ MOD_A })
        D.expect(hidden).toEqual({ MOD_B })
    end)

    D.test("UseDefault removes the choice and keeps other state", function()
        local store = FakeStore({
            UI = {
                Other = "kept",
                Mods = {
                    [MOD_A] = { HiddenFromList = false, Other = "kept" },
                    [MOD_B] = { HiddenFromList = false },
                    [ABSENT_MOD] = { HiddenFromList = true },
                },
            },
        })
        local visibility = ModListState:New(store)
        D.expect(visibility:HasChoice(MOD_A)).toBe(true)
        D.expect(visibility:HasChoice(MOD_C)).toBe(false)

        visibility:UseDefault(MOD_A)
        visibility:UseDefault(MOD_B)

        D.expect(visibility:HasChoice(MOD_A)).toBe(false)
        D.expect(visibility:HasChoice(MOD_B)).toBe(false)
        local main, hidden = resolve(visibility, { MOD_A, MOD_B }, { [MOD_A] = true })
        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(store.values).toEqual({
            UI = {
                Other = "kept",
                Mods = { [MOD_A] = { Other = "kept" }, [ABSENT_MOD] = { HiddenFromList = true } },
            },
        })
    end)

    D.test("an unreadable state document resolves author defaults and refuses choices", function()
        local store = FakeStore({}, true)
        local visibility = ModListState:New(store)

        local main, hidden = resolve(visibility, { MOD_A, MOD_B }, { [MOD_A] = true })
        local hideSaved = visibility:SetHidden(MOD_B, true)

        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(hideSaved).toBe(false)
        D.expect(store.values).toEqual({})
    end)

    D.test("an empty state document accepts choices", function()
        local store = FakeStore()
        local visibility = ModListState:New(store)

        D.expect(visibility:SetHidden(MOD_A, true)).toBe(true)
        D.expect(visibility:HasChoice(MOD_A)).toBe(true)
        local main, hidden = resolve(visibility, { MOD_A, MOD_B })
        D.expect(main).toEqual({ MOD_B })
        D.expect(hidden).toEqual({ MOD_A })
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = true })
    end)
    D.test("folders resolve player choices and suggested names and preserve state", function()
        local store = FakeStore({ UI = { Other = "kept", Mods = { [ABSENT_MOD] = { Other = 7 }, [MOD_B] = { Folder = false } }, Folders = { f = { Name = "Renamed", Suggested = "Libraries" } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" }, [MOD_B] = { ListFolder = "Libraries" } }
        local result = state:Resolve(mods, defaults)
        D.expect(result.main[1].id).toBe(MOD_B)
        D.expect(result.main[2].items[1].id).toBe(MOD_A)
        state:SetPinned(MOD_A, true)
        state:SetHidden(MOD_A, true)
        D.expect(state:Resolve(mods, defaults).hidden[1].pinned).toBe(true)
        state:SetHidden(MOD_A, false)
        state:DeleteFolder("f", { MOD_A })
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe(false)
        D.expect(store.values.UI.Mods[ABSENT_MOD].Other).toBe(7)
        D.expect(store.values.UI.Other).toBe("kept")
    end)

    D.test("ordering and folder moves", function()
        local state = ModListState:New(FakeStore())
        local mods = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" }, { id = MOD_C, name = "Charlie" } }
        state:CreateFolder("f", "Folder")
        state:SetPinned(MOD_C, true)
        local result = state:Resolve(mods)
        D.expect(result.main[1].id).toBe(MOD_C)
        D.expect(state:Move(result.main[1], "Main", "Main", nil, result)).toBe(false)
        local a = { kind = "mod", id = MOD_A }
        local b = { kind = "mod", id = MOD_B }
        D.expect(state:Move(b, "Main", "Main", a, result)).toBe(true)
        result = state:Resolve(mods)
        D.expect(result.main[3].id).toBe(MOD_B)
        D.expect(state:Move(a, "Main", "f", nil, result)).toBe(true)
        result = state:Resolve(mods)
        D.expect(state:Move({ kind = "folder", id = "f" }, "Main", "f", nil, result)).toBe(false)
        D.expect(state:Resolve(mods).main[3].id).toBe(MOD_B)
    end)

    D.test("crossing pin sections saves the target pin and new order in one write", function()
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" }, { id = MOD_C, name = "C" } }
        for _, pinDragged in ipairs({ true, false }) do
            local store = FakeStore({ UI = { Other = "kept", Mods = {
                [MOD_A] = { Pinned = true, Other = "kept" },
            } } })
            local writes = 0
            local set = store.Set
            store.Set = function(key, value)
                if key == "UI" then writes = writes + 1 end
                return set(key, value)
            end
            local state = ModListState:New(store)
            local result = state:Resolve(mods)
            local dragged = pinDragged and result.main[2] or result.main[1]
            local target = pinDragged and result.main[1] or result.main[2]

            D.expect(state:Move(dragged, "Main", "Main", target, result)).toBe(true)
            D.expect(store.values.UI.Mods[dragged.id].Pinned == true).toBe(pinDragged)
            D.expect(store.values.UI.Order.Main).toEqual({ MOD_B, MOD_A, MOD_C })
            D.expect(writes).toBe(1)
            D.expect(store.values.UI.Other).toBe("kept")
            D.expect(store.values.UI.Mods[MOD_A].Other).toBe("kept")
            D.expect(state:Resolve(mods).main[1].id).toBe(MOD_B)
        end
    end)

    D.test("folder header drops adopt both pinned and unpinned target sections", function()
        for _, targetPinned in ipairs({ true, false }) do
            local store = FakeStore({ UI = { Folders = {
                f = { Name = "First", Pinned = not targetPinned, Other = "kept" },
                g = { Name = "Second", Pinned = targetPinned },
            } } })
            local state = ModListState:New(store)
            local result = state:Resolve({})
            local dragged, target
            for _, folder in ipairs(result.main) do
                if folder.id == "f" then dragged = folder else target = folder end
            end

            D.expect(state:Move(dragged, "Main", "Main", target, result)).toBe(true)
            D.expect(store.values.UI.Folders.f.Pinned == true).toBe(targetPinned)
            D.expect(store.values.UI.Folders.f.Other).toBe("kept")
            D.expect(store.values.UI.Order.Main).toEqual(targetPinned and { "f", "g" } or { "g", "f" })
        end
    end)

    D.test("pinning a virtual folder by dropping preserves its author association", function()
        local store = FakeStore({ UI = { Folders = { pinned = { Name = "Pinned", Pinned = true } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "A" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" } }
        local result = state:Resolve(mods, defaults)
        local folder = result.main[2]

        D.expect(state:Move(folder, "Main", "Main", result.main[1], result)).toBe(true)
        D.expect(store.values.UI.Folders[folder.id]).toEqual({ Name = "Libraries", Suggested = "Libraries", Pinned = true })
        local reloaded = state:Resolve(mods, defaults)
        D.expect(reloaded.main[1].id).toBe(folder.id)
        D.expect(reloaded.main[1].items[1].id).toBe(MOD_A)
    end)

    D.test("failed pin-section drops leave both pin and order unchanged", function()
        local store = FakeStore({ UI = {
            Mods = { [MOD_A] = { Pinned = true } }, Order = { Main = { MOD_A, MOD_B } },
        } })
        store.Set = function() return false end
        local before = table.deepcopy(store.values)
        local state = ModListState:New(store)
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } })

        local moved, reason = state:Move(result.main[1], "Main", "Main", result.main[2], result)
        D.expect(moved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(store.values).toEqual(before)
    end)

    D.test("cross-folder drops preserve the source pin despite the target section", function()
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        for _, sourcePinned in ipairs({ true, false }) do
            local store = FakeStore({ UI = {
                Folders = { f = { Name = "First" }, g = { Name = "Second" } },
                Mods = {
                    [MOD_A] = { Folder = "f", Pinned = sourcePinned },
                    [MOD_B] = { Folder = "g", Pinned = not sourcePinned },
                },
            } })
            local state = ModListState:New(store)
            local result = state:Resolve(mods)
            local source, destination = result.main[1], result.main[2]

            D.expect(state:Move(source.items[1], "f", "g", destination.items[1], result)).toBe(true)
            D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(sourcePinned)
            D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("g")
        end
    end)

    D.test("same group drops take the target position", function()
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" }, { id = MOD_C, name = "C" } }
        local cases = {
            { 1, 2, { MOD_B, MOD_A, MOD_C } },
            { 1, 3, { MOD_B, MOD_C, MOD_A } },
            { 3, 1, { MOD_C, MOD_A, MOD_B } },
        }
        for _, case in ipairs(cases) do
            local state = ModListState:New(FakeStore({ UI = { Order = { Main = { MOD_A, ABSENT_MOD, MOD_B, MOD_C } } } }))
            local result = state:Resolve(mods)
            D.expect(state:Move(result.main[case[1]], "Main", "Main", result.main[case[2]], result)).toBe(true)
            local ids = {}
            for _, entry in ipairs(state:Resolve(mods).main) do table.insert(ids, entry.id) end
            D.expect(ids).toEqual(case[3])
        end
    end)

    D.test("cross group drops insert before the target", function()
        local state = ModListState:New(FakeStore({ UI = { Folders = { f = { Name = "Folder" } }, Mods = { [MOD_B] = { Folder = "f" }, [MOD_C] = { Folder = "f" } } } }))
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" }, { id = MOD_C, name = "C" } }
        local result = state:Resolve(mods)
        local folder = result.main[2]
        D.expect(state:Move(result.main[1], "Main", "f", folder.items[2], result)).toBe(true)
        local items = state:Resolve(mods).main[1].items
        D.expect({ items[1].id, items[2].id, items[3].id }).toEqual({ MOD_B, MOD_A, MOD_C })
    end)

    D.test("hidden ordering keeps pins and folder through hide and show", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { Folder = "f", Pinned = true }, [MOD_B] = { Pinned = true } }, Folders = { f = { Name = "Folder" } }, Order = { Hidden = { MOD_B, MOD_A }, f = { MOD_A } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" }, { id = MOD_C, name = "Charlie" } }
        state:SetHidden(MOD_A, true)
        state:SetHidden(MOD_B, true)
        state:SetHidden(MOD_C, true)
        local result = state:Resolve(mods)
        D.expect(result.hidden[1].id).toBe(MOD_B)
        D.expect(result.hidden[2].id).toBe(MOD_A)
        D.expect(result.hidden[3].id).toBe(MOD_C)
        state:SetHidden(MOD_A, false)
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("f")
        D.expect(store.values.UI.Order.f).toEqual({ MOD_A })
    end)

    D.test("editing a virtual folder preserves its suggested name", function()
        local state = ModListState:New(FakeStore())
        local mods = { { id = MOD_A, name = "Alpha" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" } }
        local folder = state:Resolve(mods, defaults).main[1]
        state:RenameFolder(folder.id, "Renamed", folder)
        local result = state:Resolve(mods, defaults)
        D.expect(result.main[1].name).toBe("Renamed")
        D.expect(result.main[1].items[1].id).toBe(MOD_A)
    end)

    D.test("moves reorder mods and folders and adopt the same-group target pin", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" }, g = { Name = "Group" } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" }, { id = MOD_C, name = "Charlie" } }
        local result = state:Resolve(mods)
        D.expect(state:Move(result.main[2], "Main", "Main", result.main[1], result)).toBe(true)
        result = state:Resolve(mods)
        D.expect(result.main[1].id).toBe(MOD_B)
        D.expect(state:Move(result.main[1], "Main", "f", nil, result)).toBe(true)
        result = state:Resolve(mods)
        local folder, other
        for _, entry in ipairs(result.main) do
            if entry.id == "f" then folder = entry end
            if entry.id == "g" then other = entry end
        end
        D.expect(folder.items[1].id).toBe(MOD_B)
        D.expect(state:Move(other, "Main", "Main", folder, result)).toBe(true)
        result = state:Resolve(mods)
        local ids = {}
        for _, entry in ipairs(result.main) do table.insert(ids, entry.id) end
        D.expect(ids).toEqual({ MOD_A, MOD_C, "g", "f" })
        state:SetPinned(MOD_A, true)
        result = state:Resolve(mods)
        D.expect(state:Move(result.main[1], "Main", "Main", result.main[2], result)).toBe(true)
        D.expect(state:Resolve(mods).main[1].id).toBe(MOD_C)
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(nil)
    end)

    D.test("malformed saved state refuses changes without changing it", function()
        local cases = {
            false,
            { Mods = false },
            { Mods = { [MOD_A] = false } },
            { Folders = { bad = false } },
            { Order = { Main = false } },
            { Order = { Main = { MOD_A, false } } },
        }
        for _, ui in ipairs(cases) do
            local store = FakeStore({ UI = ui })
            local before = table.deepcopy(store.values)
            local state = ModListState:New(store)
            D.expect(state:SetHidden(MOD_A, true)).toBe(false)
            D.expect(state:CreateFolder("f", "Folder")).toBe(false)
            D.expect(store.values).toEqual(before)
        end
    end)

    D.test("renaming a saved folder matched by suggestion retains its members", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Libraries" } },
            Mods = { [MOD_B] = { Folder = false } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" }, [MOD_B] = { ListFolder = "Libraries" } }
        local before = table.deepcopy(store.values)
        local folder = state:Resolve(mods, defaults).main[2]
        D.expect(store.values).toEqual(before)
        D.expect(state:RenameFolder("f", "Renamed", folder)).toBe(true)
        local result = state:Resolve(mods, defaults)
        D.expect(result.main[1].id).toBe(MOD_B)
        D.expect(result.main[2].name).toBe("Renamed")
        D.expect(result.main[2].items[1].id).toBe(MOD_A)
        D.expect(store.values.UI.Folders.f.Suggested).toBe("Libraries")
    end)

    D.test("cross group drops keep the pin and same group header drops do nothing", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { Pinned = true }, [MOD_B] = { Folder = "f" } }, Folders = { f = { Name = "Folder" } }, Order = { Main = { MOD_A } } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        local result = state:Resolve(mods)
        local a, folder = result.main[1], result.main[2]
        D.expect(state:Move(a, "Main", "f", folder.items[1], result)).toBe(true)
        result = state:Resolve(mods)
        D.expect(result.main[1].items[1].id).toBe(MOD_A)
        D.expect(state:Move(result.main[1].items[1], "f", "f", nil, result)).toBe(false)
    end)

    D.test("dropping a pinned mod onto an unpinned entry saves unpin and order together", function()
        local store = FakeStore({ UI = { Mods = {
            [MOD_A] = { Pinned = true, Other = "kept" },
        } } })
        local state = ModListState:New(store)
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        local result = state:Resolve(mods)
        D.expect(state:Move(result.main[1], "Main", "Main", result.main[2], result)).toBe(true)
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ Other = "kept" })
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_B, MOD_A })
        D.expect(state:Resolve(mods).main[1].id).toBe(MOD_B)
    end)

    D.test("folder headers adopt target pins in both directions without losing names", function()
        local store = FakeStore({ UI = { Folders = {
            f = { Name = "First" }, g = { Name = "Second", Pinned = true },
        } } })
        local state = ModListState:New(store)
        local result = state:Resolve({})
        D.expect(state:Move(result.main[2], "Main", "Main", result.main[1], result)).toBe(true)
        D.expect(store.values.UI.Folders.f.Pinned).toBe(true)
        state:SetPinned("g", false, "folder", result.main[1])
        result = state:Resolve({})
        D.expect(state:Move(result.main[1], "Main", "Main", result.main[2], result)).toBe(true)
        D.expect(store.values.UI.Folders.f).toEqual({ Name = "First" })
        D.expect(store.values.UI.Order.Main).toEqual({ "g", "f" })
    end)

    D.test("failed drop save changes neither pin nor order", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { Pinned = true } } } })
        local state = ModListState:New(store)
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } })
        local before = table.deepcopy(store.values)
        store.Set = function() return false end
        local saved, reason = state:Move(result.main[1], "Main", "Main", result.main[2], result)
        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(store.values).toEqual(before)
    end)

    D.test("move reports refusal reasons without changing state", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } }, Mods = { [MOD_A] = { Pinned = true } } } })
        local state = ModListState:New(store)
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } })
        local before = table.deepcopy(store.values)
        local _, reason = state:Move(result.main[1], "Main", "Main", result.main[1], result)
        D.expect(reason).toBe("unchanged")
        _, reason = state:Move(result.main[1], "Main", "Main", nil, result)
        D.expect(reason).toBe("unchanged")
        _, reason = state:Move({ kind = "folder", id = "f" }, "Main", "Hidden", nil, result)
        D.expect(reason).toBe("nested")
        D.expect(store.values).toEqual(before)
    end)

    D.test("hidden suggested members are retained for folder deletion", function()
        local state = ModListState:New(FakeStore())
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" }, [MOD_B] = { ListFolder = "Libraries", HiddenFromList = true } }
        local folder = state:Resolve(mods, defaults).main[1]
        state:DeleteFolder(folder.id, folder.members)
        state:SetHidden(MOD_B, false)
        local result = state:Resolve(mods, defaults)
        D.expect(result.main[2].id).toBe(MOD_B)
    end)

    D.test("deleting a folder removes stale order and explicit references", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } }, Mods = { [ABSENT_MOD] = { Folder = "f", Other = 1 } }, Order = { Main = { "f", MOD_A } } } })
        local state = ModListState:New(store)
        state:DeleteFolder("f")
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_A })
        D.expect(store.values.UI.Mods[ABSENT_MOD]).toEqual({ Folder = false, Other = 1 })
    end)

    D.test("suggested folder names match case insensitively", function()
        local state = ModListState:New(FakeStore())
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }, { [MOD_A] = { ListFolder = "Libraries" }, [MOD_B] = { ListFolder = "libraries" } })
        D.expect(#result.main).toBe(1)
        D.expect(#result.main[1].items).toBe(2)
    end)

    D.test("virtual folder edits retain author casing", function()
        local mods = { { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }
        local defaults = { [MOD_A] = { ListFolder = "Libraries" } }
        for _, action in ipairs({ "pin", "assign", "rename", "move" }) do
            local store = FakeStore()
            local state = ModListState:New(store)
            local result = state:Resolve(mods, defaults)
            local folder = result.main[2]
            if action == "pin" then state:SetPinned(folder.id, true, "folder", folder)
            elseif action == "assign" then state:SetFolder(MOD_B, folder.id, folder)
            elseif action == "rename" then state:RenameFolder(folder.id, "Renamed", folder)
            else state:Move(result.main[1], "Main", folder.id, nil, result) end
            D.expect(store.values.UI.Folders[folder.id].Suggested).toBe("Libraries")
            D.expect(store.values.UI.Folders[folder.id].Name).toBe(action == "rename" and "Renamed" or "Libraries")
        end
    end)

    D.test("hidden-only suggestions do not create a header", function()
        local state = ModListState:New(FakeStore())
        local result = state:Resolve({ { id = MOD_A, name = "A" } }, { [MOD_A] = { ListFolder = "Libraries", HiddenFromList = true } })
        D.expect(#result.main).toBe(0)
        D.expect(#result.hidden).toBe(1)
    end)

    D.test("foreign drop target is rejected without a write", function()
        local store = FakeStore()
        local state = ModListState:New(store)
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } })
        D.expect(state:Move(result.main[1], "Main", "Hidden", result.main[2], result)).toBe(false)
        D.expect(store.values.UI).toBe(nil)
    end)

    D.test("menu folder moves reveal hidden mods atomically", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { HiddenFromList = true }, [MOD_B] = { HiddenFromList = true } } } })
        local state = ModListState:New(store)
        state:SetFolder(MOD_A, false)
        state:CreateFolder("f", "Folder", nil, MOD_B)
        D.expect(store.values.UI.Mods[MOD_A].HiddenFromList).toBe(false)
        D.expect(store.values.UI.Mods[MOD_B].HiddenFromList).toBe(false)
        D.expect(store.values.UI.Mods[MOD_B].Folder).toBe("f")
    end)

    D.test("new folder IDs skip saved and resolved historical references without writing", function()
        local store = FakeStore({ UI = {
            Folders = { ["fld-1"] = { Name = "Existing" } },
            Mods = { [ABSENT_MOD] = { Folder = "fld-2" } },
            Order = { ["fld-3"] = {}, Main = { "fld-4" } },
        } })
        local before = table.deepcopy(store.values)
        local state = ModListState:New(store)
        local resolved = { main = { { id = "fld-5" } }, hidden = {} }

        D.expect(state:NextFolderId(resolved)).toBe("fld-6")
        D.expect(store.values).toEqual(before)
    end)

    D.test("malformed documents do not allocate a folder ID", function()
        local values = { UI = { Mods = "corrupt" } }
        local store = FakeStore(values)
        local state = ModListState:New(store)

        D.expect(state:NextFolderId(nil)).toBe(nil)
        D.expect(store.values.UI.Mods).toBe("corrupt")
    end)

    D.test("a drop inside a folder adopts the target pin and reorders", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } }, Mods = {
            [MOD_A] = { Folder = "f" }, [MOD_B] = { Folder = "f", Pinned = true },
        } } })
        local state = ModListState:New(store)
        local result = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }, {})
        local folder = result.main[1]
        D.expect(folder.items[1].id).toBe(MOD_B)
        D.expect(folder.items[1].pinned).toBe(true)
        D.expect(folder.items[2].id).toBe(MOD_A)
        D.expect(folder.items[2].pinned).toBe(false)
        D.expect(store.values.UI.Mods[MOD_B].Pinned).toBe(true)
        local moved, reason = state:Move(folder.items[2], "f", "f", folder.items[1], result)
        D.expect(moved).toBe(true)
        D.expect(reason).toBe(nil)
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(true)
        D.expect(store.values.UI.Order.f).toEqual({ MOD_A, MOD_B })
        local reordered = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } }).main[1].items
        D.expect(reordered[1].id).toBe(MOD_A)
    end)

    D.test("MCM remains first pinned despite hostile choices", function()
        local ui = { Mods = { [ModuleUUID] = { HiddenFromList = true, Folder = "f", Pinned = false },
            [MOD_A] = { Pinned = true } }, Folders = { f = { Name = "A folder", Pinned = true } },
            Order = { Main = { "f", MOD_A, ModuleUUID } } }
        local state = ModListState:New(FakeStore({ UI = ui }))
        local mods = { { id = MOD_A, name = "A" }, { id = ModuleUUID, name = "Z" } }
        local defaults = { [ModuleUUID] = { HiddenFromList = true, ListFolder = "suggested" } }
        local result = state:Resolve(mods, defaults)
        D.expect(result.main[1].id).toBe(ModuleUUID)
        D.expect(result.main[1].pinned).toBe(true)
        D.expect(#result.hidden).toBe(0)
        D.expect(#result.main[2].items).toBe(0)
        D.expect(#state:Resolve({}).main).toBe(1) -- the saved empty folder remains
    end)

    D.test("organization changes refuse MCM and preserve other mod flexibility", function()
        local store = FakeStore({ UI = { Mods = { [ModuleUUID] = { Folder = "f", HiddenFromList = true } },
            Folders = { f = { Name = "Folder" } } } })
        local state = ModListState:New(store)
        local mods = { { id = ModuleUUID, name = "MCM" }, { id = MOD_A, name = "A" } }
        local result = state:Resolve(mods)
        local before = table.deepcopy(store.values.UI)
        D.expect(state:SetHidden(ModuleUUID, true)).toBe(false)
        D.expect(state:UseDefault(ModuleUUID)).toBe(false)
        D.expect(state:SetPinned(ModuleUUID, false)).toBe(false)
        D.expect(state:SetFolder(ModuleUUID, "f")).toBe(false)
        D.expect(state:CreateFolder("new", "New", nil, ModuleUUID)).toBe(false)
        D.expect(state:Move(result.main[1], "Main", "Hidden", nil, result)).toBe(false)
        D.expect(store.values.UI).toEqual(before)
        D.expect(state:DeleteFolder("f", { ModuleUUID })).toBe(true)
        D.expect(store.values.UI.Mods[ModuleUUID]).toEqual(before.Mods[ModuleUUID])
        D.expect(state:SetHidden(MOD_A, true)).toBe(true)
    end)

    D.test("dropping another mod onto MCM pins it without displacing MCM", function()
        local state = ModListState:New(FakeStore())
        local mods = { { id = ModuleUUID, name = "MCM" }, { id = MOD_A, name = "A" } }
        local result = state:Resolve(mods)
        D.expect(state:Move(result.main[2], "Main", "Main", result.main[1], result)).toBe(true)
        result = state:Resolve(mods)
        D.expect(result.main[1].id).toBe(ModuleUUID)
        D.expect(result.main[2].id).toBe(MOD_A)
        D.expect(result.main[2].pinned).toBe(true)
    end)

    D.describe("drops with MCM saved after other entries", function()
        ---@param ui SavedModListUI
        ---@return ModListState state
        ---@return ModListInput[] mods
        ---@return table store
        local function dropFixture(ui)
            local store = FakeStore({ UI = ui })
            return ModListState:New(store), {
                { id = ModuleUUID, name = "MCM" },
                { id = MOD_A, name = "A" },
                { id = MOD_B, name = "B" },
                { id = MOD_C, name = "C" },
            }, store
        end

        ---@param entries ResolvedModListEntry[]
        ---@param id string
        ---@return ResolvedModListEntry|nil
        local function entryById(entries, id)
            for _, entry in ipairs(entries) do
                if entry.id == id then return entry end
            end
        end

        ---@param entries ResolvedModListEntry[]
        ---@return string[]
        local function idsOf(entries)
            local ids = {}
            for _, entry in ipairs(entries) do table.insert(ids, entry.id) end
            return ids
        end

        local function pinnedChoices()
            return { [MOD_A] = { Pinned = true }, [MOD_B] = { Pinned = true }, [MOD_C] = { Pinned = true } }
        end

        D.test("a pinned entry lands directly after MCM and unloaded references stay", function()
            local state, mods, store = dropFixture({
                Mods = pinnedChoices(),
                Order = { Main = { MOD_A, ModuleUUID, ABSENT_MOD, MOD_B, MOD_C } },
            })
            local resolved = state:Resolve(mods)
            D.expect(idsOf(resolved.main)).toEqual({ ModuleUUID, MOD_A, MOD_B, MOD_C })
            local saved = state:Move(entryById(resolved.main, MOD_B), "Main", "Main", resolved.main[1], resolved)
            D.expect(saved).toBe(true)
            D.expect(idsOf(state:Resolve(mods).main)).toEqual({ ModuleUUID, MOD_B, MOD_A, MOD_C })
            D.expect(store.values.UI.Order.Main).toContain(ABSENT_MOD)
        end)

        D.test("an unpinned Main entry adopts the pin and lands directly after MCM", function()
            local state, mods = dropFixture({
                Mods = { [MOD_A] = { Pinned = true } },
                Order = { Main = { MOD_A, ModuleUUID, MOD_B, MOD_C } },
            })
            local resolved = state:Resolve(mods)
            D.expect(state:Move(entryById(resolved.main, MOD_C), "Main", "Main", resolved.main[1], resolved)).toBe(true)
            local after = state:Resolve(mods).main
            D.expect(idsOf(after)).toEqual({ ModuleUUID, MOD_C, MOD_A, MOD_B })
            D.expect(after[2].pinned).toBe(true)
        end)

        D.test("a pinned entry from a folder keeps its pin and lands directly after MCM", function()
            local choices = pinnedChoices()
            choices[MOD_B].Folder = "f"
            local state, mods = dropFixture({
                Mods = choices,
                Folders = { f = { Name = "F" } },
                Order = { Main = { MOD_A, ModuleUUID, MOD_C } },
            })
            local resolved = state:Resolve(mods)
            local source = entryById(entryById(resolved.main, "f").items, MOD_B)
            D.expect(state:Move(source, "f", "Main", resolved.main[1], resolved)).toBe(true)
            local after = idsOf(state:Resolve(mods).main)
            D.expect({ after[1], after[2], after[3] }).toEqual({ ModuleUUID, MOD_B, MOD_A })
        end)

        D.test("an unpinned entry from a folder stays unpinned", function()
            local state, mods = dropFixture({
                Mods = { [MOD_A] = { Pinned = true }, [MOD_B] = { Folder = "f" } },
                Folders = { f = { Name = "F" } },
                Order = { Main = { MOD_A, ModuleUUID, MOD_C } },
            })
            local resolved = state:Resolve(mods)
            local source = entryById(entryById(resolved.main, "f").items, MOD_B)
            D.expect(state:Move(source, "f", "Main", resolved.main[1], resolved)).toBe(true)
            local after = state:Resolve(mods).main
            D.expect(idsOf(after)).toEqual({ ModuleUUID, MOD_A, MOD_C, "f", MOD_B })
            D.expect(entryById(after, MOD_B).pinned).toBe(false)
        end)

        D.test("a drop onto another target stays relative to that target", function()
            local state, mods, store = dropFixture({
                Mods = pinnedChoices(),
                Order = { Main = { MOD_A, ModuleUUID, ABSENT_MOD, MOD_B, MOD_C } },
            })
            local resolved = state:Resolve(mods)
            local saved = state:Move(entryById(resolved.main, MOD_C), "Main", "Main",
                entryById(resolved.main, MOD_B), resolved)
            D.expect(saved).toBe(true)
            D.expect(idsOf(state:Resolve(mods).main)).toEqual({ ModuleUUID, MOD_A, MOD_C, MOD_B })
            D.expect(store.values.UI.Order.Main).toContain(ABSENT_MOD)
        end)
    end)

end)
