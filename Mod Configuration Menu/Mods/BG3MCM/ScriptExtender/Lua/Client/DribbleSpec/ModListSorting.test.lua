D.describe("Mod list sorting", { tags = { "mod_list_sorting", "client", "unit" } }, function()
    local MOD_A = "00000000-0000-0000-0000-00000000A001"
    local MOD_B = "00000000-0000-0000-0000-00000000B002"
    local MOD_C = "00000000-0000-0000-0000-00000000C003"
    local ABSENT_MOD = "00000000-0000-0000-0000-00000000E005"
    local PREFERENCES = "ModListPreferences"

    --- In-memory stand-in for MCM.Store; `refused` names variables whose writes fail
    ---@param values? table<string, any>
    ---@param refused? table<string, boolean>
    ---@return table store
    local function FakeStore(values, refused)
        values = values or {}
        return {
            values = values,
            RegisterVar = function() return true end,
            IsWritable = function() return true end,
            Get = function(var) return values[var] end,
            Set = function(var, value)
                if refused and refused[var] then return false end
                values[var] = value
                return true
            end,
        }
    end

    local function ids(entries)
        local result = {}
        for _, entry in ipairs(entries) do table.insert(result, entry.id) end
        return result
    end

    local MODS = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" }, { id = MOD_C, name = "Charlie" } }

    local function usage(records)
        return { Sequence = 100, Mods = records }
    end

    D.test("Alphabetical is the default and ignores saved manual order", function()
        local state = ModListState:New(FakeStore({ UI = { Order = { Main = { MOD_C, MOD_B, MOD_A } } } }))
        D.expect(state.preferences:GetSortMode()).toBe("alphabetical")
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_A, MOD_B, MOD_C })
    end)

    D.test("Manual uses saved order, then names for unpositioned entries", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_C } } }, [PREFERENCES] = { SortMode = "manual" } })
        D.expect(ids(ModListState:New(store):Resolve(MODS).main)).toEqual({ MOD_C, MOD_A, MOD_B })
    end)

    D.test("changing the mode restores Manual without rewriting saved order", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_C, MOD_B, MOD_A } } } })
        local state = ModListState:New(store)
        D.expect(state.preferences:SetSortMode("frequent")).toBe(true)
        D.expect(state.preferences:SetSortMode("manual")).toBe(true)
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_C, MOD_B, MOD_A })
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_C, MOD_B, MOD_A })
    end)

    D.test("Recently used sorts by last use and never-used entries follow by name", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "recent",
            Usage = usage({ [MOD_C] = { Count = 1, Last = 9 }, [MOD_B] = { Count = 5, Last = 2 } }) } })
        local mods = { MODS[1], MODS[2], MODS[3], { id = "AAA", name = "Aardvark" } }
        D.expect(ids(ModListState:New(store):Resolve(mods).main)).toEqual({ MOD_C, MOD_B, "AAA", MOD_A })
    end)

    D.test("Frequently used breaks count ties by last use, then name", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "frequent", Usage = usage({
            [MOD_A] = { Count = 2, Last = 1 }, [MOD_B] = { Count = 2, Last = 8 }, [MOD_C] = { Count = 7, Last = 3 },
        }) } })
        D.expect(ids(ModListState:New(store):Resolve(MODS).main)).toEqual({ MOD_C, MOD_B, MOD_A })
        store.values[PREFERENCES].Usage = usage({})
        D.expect(ids(ModListState:New(store):Resolve({ { id = "b", name = "Same" }, { id = "a", name = "same" } }).main))
            .toEqual({ "a", "b" })
    end)

    D.test("folders rank by visible members and ignore hidden members", function()
        local ui = { Folders = { f = { Name = "Folder" } }, Mods = {
            [MOD_A] = { Folder = "f" }, [MOD_B] = { Folder = "f" }, [MOD_C] = { Folder = "f", HiddenFromList = true },
        } }
        local records = { [MOD_A] = { Count = 2, Last = 1 }, [MOD_B] = { Count = 2, Last = 3 },
            [MOD_C] = { Count = 50, Last = 50 }, loose = { Count = 3, Last = 2 } }
        local mods = { MODS[1], MODS[2], MODS[3], { id = "loose", name = "Loose" } }
        -- Recent: folder max 3 beats loose 2; Frequent: folder sum 4 beats loose 3.
        for _, mode in ipairs({ "recent", "frequent" }) do
            local store = FakeStore({ UI = ui, [PREFERENCES] = { SortMode = mode, Usage = usage(records) } })
            D.expect(ids(ModListState:New(store):Resolve(mods).main)).toEqual({ "f", "loose" })
        end
    end)

    D.test("Folders first applies per pin section in Main and keeps saved order", function()
        local store = FakeStore({ UI = {
            Folders = { f = { Name = "Z folder" }, g = { Name = "Y folder", Pinned = true } },
            Mods = { [MOD_A] = { Pinned = true }, [MOD_C] = { Folder = "f" } },
            Order = { Main = { MOD_A, MOD_B, "g", "f" } },
        }, [PREFERENCES] = { SortMode = "manual", FoldersFirst = true } })
        local result = ModListState:New(store):Resolve(MODS)
        D.expect(ids(result.main)).toEqual({ "g", MOD_A, "f", MOD_B })
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_A, MOD_B, "g", "f" })
    end)

    D.test("MCM, pins and Hidden keep their places in every mode", function()
        for _, mode in ipairs({ "alphabetical", "manual", "recent", "frequent" }) do
            local store = FakeStore({ UI = { Mods = { [MOD_B] = { Pinned = true }, [MOD_C] = { HiddenFromList = true } } },
                [PREFERENCES] = { SortMode = mode, FoldersFirst = true,
                    Usage = usage({ [MOD_A] = { Count = 99, Last = 99 } }) } })
            local mods = { MODS[1], MODS[2], MODS[3], { id = ModuleUUID, name = "Zed" } }
            local result = ModListState:New(store):Resolve(mods)
            D.expect(ids(result.main)).toEqual({ ModuleUUID, MOD_B, MOD_A })
            D.expect(ids(result.hidden)).toEqual({ MOD_C })
        end
    end)

    D.test("a reorder in an automatic mode snapshots every group and switches to Manual", function()
        local store = FakeStore({ UI = {
            Folders = { f = { Name = "Folder" } }, Mods = { [MOD_C] = { HiddenFromList = true } },
            Order = { Main = { ABSENT_MOD, MOD_B }, Hidden = { "gone" }, f = { "also-gone" } },
        } })
        local state = ModListState:New(store)
        local before = state:Resolve({ MODS[1], MODS[2], MODS[3], { id = "d", name = "Delta" } })
        D.expect(ids(before.main)).toEqual({ MOD_A, MOD_B, "d", "f" })
        local saved = state:Move(before.main[3], "Main", "Main", before.main[1], before)
        D.expect(saved).toBe(true)
        D.expect(state.preferences:GetSortMode()).toBe("manual")
        D.expect(store.values.UI.Order.Main).toEqual({ "d", MOD_A, MOD_B, "f", ABSENT_MOD })
        D.expect(store.values.UI.Order.Hidden).toEqual({ MOD_C, "gone" })
        D.expect(store.values.UI.Order.f).toEqual({ "also-gone" })
        local after = state:Resolve({ MODS[1], MODS[2], MODS[3], { id = "d", name = "Delta" } })
        D.expect(ids(after.main)).toEqual({ "d", MOD_A, MOD_B, "f" })
        D.expect(ids(after.hidden)).toEqual({ MOD_C })
    end)

    D.test("section pin adoption in an automatic mode also switches to Manual", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { Pinned = true } } } })
        local state = ModListState:New(store)
        local result = state:Resolve(MODS)
        D.expect(state:Move(result.main[3], "Main", "Main", result.main[1], result)).toBe(true)
        D.expect(store.values.UI.Mods[MOD_C].Pinned).toBe(true)
        D.expect(state.preferences:GetSortMode()).toBe("manual")
    end)

    D.test("a refused layout save keeps the mode and layout", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_C } } } }, { UI = true })
        local state = ModListState:New(store)
        local result = state:Resolve(MODS)
        local saved, reason = state:Move(result.main[2], "Main", "Main", result.main[1], result)
        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(state.preferences:GetSortMode()).toBe("alphabetical")
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_C })
    end)

    --- Main with one pinned-free folder pair and two loose mods, shown as X, Y, A, B under Folders first
    local function GroupedStore(mode, refused)
        return FakeStore({ UI = { Folders = { x = { Name = "X" }, y = { Name = "Y" } },
            Order = { Main = { MOD_A, "x", MOD_B, "y" } } },
            [PREFERENCES] = { SortMode = mode, FoldersFirst = true } }, refused)
    end
    local GROUPED_MODS = { MODS[1], MODS[2] }

    local function entry(result, id)
        for _, item in ipairs(result.main) do
            if item.id == id then return item end
        end
    end

    D.test("a cross-kind drag hidden by Folders first turns it off in both Manual and automatic modes", function()
        for _, mode in ipairs({ "manual", "alphabetical" }) do
            local store = GroupedStore(mode)
            local state = ModListState:New(store)
            local before = state:Resolve(GROUPED_MODS)
            D.expect(state:Move(entry(before, "x"), "Main", "Main", entry(before, MOD_A), before)).toBe(true)
            D.expect(state.preferences:GetFoldersFirst()).toBe(false)
            D.expect(state.preferences:GetSortMode()).toBe("manual")
            local shown = ids(state:Resolve(GROUPED_MODS).main)
            D.expect(shown[1] == MOD_A or shown[2] == MOD_A).toBe(true)
            local aAt, xAt
            for index, id in ipairs(shown) do
                if id == MOD_A then aAt = index elseif id == "x" then xAt = index end
            end
            D.expect(xAt).toBe(aAt + 1)
        end
    end)

    D.test("within-kind drags keep Folders first", function()
        local state = ModListState:New(GroupedStore("manual"))
        local before = state:Resolve(GROUPED_MODS)
        D.expect(state:Move(entry(before, "y"), "Main", "Main", entry(before, "x"), before)).toBe(true)
        before = state:Resolve(GROUPED_MODS)
        D.expect(state:Move(entry(before, MOD_B), "Main", "Main", entry(before, MOD_A), before)).toBe(true)
        D.expect(state.preferences:GetFoldersFirst()).toBe(true)
        D.expect(ids(state:Resolve(GROUPED_MODS).main)).toEqual({ "y", "x", MOD_B, MOD_A })
    end)

    D.test("a cross-kind drag that grouping can show keeps Folders first", function()
        local store = FakeStore({ UI = { Folders = { x = { Name = "X" } }, Mods = { [MOD_A] = { Pinned = true } } },
            [PREFERENCES] = { SortMode = "manual", FoldersFirst = true } })
        local state = ModListState:New(store)
        local before = state:Resolve(GROUPED_MODS)
        D.expect(ids(before.main)).toEqual({ MOD_A, "x", MOD_B })
        -- Unpinned folder onto the pinned mod: it adopts the pin and lands just above the mod.
        D.expect(state:Move(entry(before, "x"), "Main", "Main", entry(before, MOD_A), before)).toBe(true)
        D.expect(state.preferences:GetFoldersFirst()).toBe(true)
        D.expect(ids(state:Resolve(GROUPED_MODS).main)).toEqual({ "x", MOD_A, MOD_B })
    end)

    D.test("a section drop that grouping would hide turns Folders first off and keeps the pin", function()
        local store = FakeStore({ UI = { Folders = { x = { Name = "X", Pinned = true } } },
            [PREFERENCES] = { SortMode = "manual", FoldersFirst = true } })
        local state = ModListState:New(store)
        local before = state:Resolve(GROUPED_MODS)
        -- Pinned heading referencing the folder: the mod asks for the top of the section.
        D.expect(state:Move(entry(before, MOD_B), "Main", "Main", entry(before, "x"), before)).toBe(true)
        D.expect(state.preferences:GetFoldersFirst()).toBe(false)
        D.expect(ids(state:Resolve(GROUPED_MODS).main)).toEqual({ MOD_B, "x", MOD_A })
    end)

    D.test("a folder dropped after MCM keeps Folders first; a mod dropped there clears it", function()
        local mods = { { id = ModuleUUID, name = "MCM" }, MODS[1] }
        local function run(itemId)
            local store = FakeStore({ UI = { Folders = { x = { Name = "X", Pinned = true } }, Mods = { [MOD_A] = { Pinned = true } } },
                [PREFERENCES] = { SortMode = "manual", FoldersFirst = true } })
            local state = ModListState:New(store)
            local before = state:Resolve(mods)
            D.expect(ids(before.main)).toEqual({ ModuleUUID, "x", MOD_A })
            D.expect(state:Move(entry(before, itemId), "Main", "Main", entry(before, ModuleUUID), before)).toBe(true)
            return state
        end
        D.expect(run("x").preferences:GetFoldersFirst()).toBe(true)
        local state = run(MOD_A)
        D.expect(state.preferences:GetFoldersFirst()).toBe(false)
        D.expect(ids(state:Resolve(mods).main)).toEqual({ ModuleUUID, MOD_A, "x" })
    end)

    D.test("a cross-group move and a pin change keep Folders first", function()
        local state = ModListState:New(GroupedStore("manual"))
        local before = state:Resolve(GROUPED_MODS)
        D.expect(state:Move(entry(before, MOD_A), "Main", "x", nil, before)).toBe(true)
        D.expect(state:SetPinned(MOD_B, true)).toBe(true)
        D.expect(state.preferences:GetFoldersFirst()).toBe(true)
    end)

    D.test("a refused settings save leaves the cross-kind drag and every flag unchanged", function()
        local store = GroupedStore("manual", { [PREFERENCES] = true })
        local state = ModListState:New(store)
        local uiBefore = table.deepcopy(store.values.UI)
        local before = state:Resolve(GROUPED_MODS)
        local saved, reason = state:Move(entry(before, "x"), "Main", "Main", entry(before, MOD_A), before)
        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(store.values.UI).toEqual(uiBefore)
        D.expect(state.preferences:GetFoldersFirst()).toBe(true)
        D.expect(ids(state:Resolve(GROUPED_MODS).main)).toEqual({ "x", "y", MOD_A, MOD_B })
    end)

    D.test("a failed restore reports a partial save and warns", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_C } } } }, { [PREFERENCES] = true })
        local state = ModListState:New(store)
        local set = store.Set
        store.Set = function(var, value)
            if var == "UI" and store.values.UI.Order.Main[1] ~= MOD_C then return false end
            return set(var, value)
        end
        local result = state:Resolve(MODS)
        local saved, reason = state:Move(result.main[2], "Main", "Main", result.main[1], result)
        D.expect(saved).toBe(false)
        D.expect(reason).toBe("partial")
        D.expect(state.preferences:GetSortMode()).toBe("alphabetical")
    end)

    D.test("the invalid-file message appears once in the log and stays in settings", function(ctx)
        local warnings = 0
        ctx.stub(_G, "MCMWarn", function() warnings = warnings + 1 end)
        local preferences = ModListState:New(FakeStore({ [PREFERENCES] = { SortMode = "newest" } })).preferences
        preferences:GetSortMode()
        preferences:GetFoldersFirst()
        preferences:GetView()
        D.expect(warnings).toBe(1)
        D.expect(preferences:IsInvalid()).toBe(true)
    end)

    D.test("a refused mode save restores the layout and reports failure", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_C } } } }, { [PREFERENCES] = true })
        local state = ModListState:New(store)
        local result = state:Resolve(MODS)
        local saved, reason = state:Move(result.main[2], "Main", "Main", result.main[1], result)
        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(store.values[PREFERENCES]).toBe(nil)
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_C })
    end)

    D.test("membership and pin changes keep an automatic mode", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } } }, [PREFERENCES] = { SortMode = "recent" } })
        local state = ModListState:New(store)
        local result = state:Resolve(MODS)
        local folder = result.main[4]
        D.expect(state:Move(result.main[1], "Main", "f", nil, result)).toBe(true)
        D.expect(state:SetPinned(MOD_B, true)).toBe(true)
        D.expect(state:SetHidden(MOD_C, true)).toBe(true)
        D.expect(state:RenameFolder(folder.id, "Renamed", folder)).toBe(true)
        D.expect(state.preferences:GetSortMode()).toBe("recent")
    end)

    D.test("Resolve never writes", function()
        local writes = 0
        local store = FakeStore()
        local set = store.Set
        store.Set = function(var, value)
            writes = writes + 1
            return set(var, value)
        end
        ModListState:New(store):Resolve(MODS)
        D.expect(writes).toBe(0)
    end)

    D.test("recording updates counts and keeps absent mods, while ranks stay frozen", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "recent",
            Usage = { Sequence = 4, Mods = { [ABSENT_MOD] = { Count = 3, Last = 4 } } } } })
        local state = ModListState:New(store)
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_A, MOD_B, MOD_C })
        D.expect(state.preferences:RecordOpen(MOD_C)).toBe(true)
        D.expect(state.preferences:RecordOpen(MOD_C)).toBe(true)
        D.expect(store.values[PREFERENCES].Usage.Sequence).toBe(6)
        D.expect(store.values[PREFERENCES].Usage.Mods[MOD_C]).toEqual({ Count = 2, Last = 6 })
        D.expect(store.values[PREFERENCES].Usage.Mods[ABSENT_MOD]).toEqual({ Count = 3, Last = 4 })
        -- A group collapse rebuilds the list inside the session.
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_A, MOD_B, MOD_C })
        D.expect(state.preferences:RefreshRanks()).toBe(true)
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_C, MOD_A, MOD_B })
    end)

    D.test("a session without new usage or a usage mode needs no rebuild", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "recent" } })
        local preferences = ModListState:New(store).preferences
        preferences:GetView()
        D.expect(preferences:RefreshRanks()).toBe(false)
        preferences:GetView()
        store.values[PREFERENCES].SortMode = "manual"
        preferences:RecordOpen(MOD_A)
        D.expect(preferences:RefreshRanks()).toBe(false)
    end)

    D.test("an explicit mode change uses current usage", function()
        local state = ModListState:New(FakeStore({ [PREFERENCES] = { SortMode = "manual" } }))
        state:Resolve(MODS)
        state.preferences:RecordOpen(MOD_B)
        state.preferences:SetSortMode("recent")
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_B, MOD_A, MOD_C })
    end)

    D.test("clearing usage keeps every other preference and the layout", function()
        local ui = { Mods = { [MOD_A] = { Pinned = true } }, Order = { Main = { MOD_B } } }
        local store = FakeStore({ UI = ui, [PREFERENCES] = { SortMode = "frequent", FoldersFirst = true,
            Usage = usage({ [MOD_C] = { Count = 2, Last = 2 } }) } })
        local state = ModListState:New(store)
        state:Resolve(MODS)
        D.expect(state.preferences:ClearUsage()).toBe(true)
        D.expect(store.values[PREFERENCES]).toEqual({ SortMode = "frequent", FoldersFirst = true })
        D.expect(store.values.UI).toEqual(ui)
        D.expect(ids(state:Resolve(MODS).main)).toEqual({ MOD_A, MOD_B, MOD_C })
    end)

    D.test("preferences use their own client-only file, away from the shareable layout", function()
        local registered = {}
        local store = FakeStore()
        store.RegisterVar = function(var, options) registered[var] = options end
        local state = ModListState:New(store)
        local config = registered[PREFERENCES].storageConfig
        D.expect(config.fileName).toBe("MCM_mod_list_preferences.json")
        D.expect(config.SyncToClient).toBe(false)
        D.expect(config.SyncToServer).toBe(false)
        D.expect(registered.UI.storageConfig.fileName).toBe("MCM_state.json")
        state.preferences:RecordOpen(MOD_A)
        D.expect(store.values.UI).toBe(nil)
    end)

    D.test("an invalid preference document reads as defaults and refuses writes", function()
        local bad = { SortMode = "newest", Usage = "broken" }
        local store = FakeStore({ [PREFERENCES] = bad })
        local preferences = ModListState:New(store).preferences
        D.expect(preferences:GetSortMode()).toBe("alphabetical")
        D.expect(preferences:SetSortMode("manual")).toBe(false)
        D.expect(preferences:RecordOpen(MOD_A)).toBe(false)
        D.expect(store.values[PREFERENCES]).toBe(bad)
    end)

    D.test("invalid usage numbers read as defaults, refuse writes and keep the document", function()
        local cases = {
            { Sequence = -1 }, { Sequence = 1.5 },
            { Sequence = 1, Mods = { [MOD_A] = { Count = -1, Last = 1 } } },
            { Sequence = 1, Mods = { [MOD_A] = { Count = 1.5, Last = 1 } } },
            { Sequence = 1, Mods = { [MOD_A] = { Count = 1, Last = -1 } } },
            { Sequence = 2, Mods = { [MOD_A] = { Count = 1, Last = 1.5 } } },
            { Sequence = 1, Mods = { [MOD_A] = { Count = 1, Last = 100 } } },
            { Mods = { [MOD_A] = { Count = 1, Last = 1 } } },
        }
        for _, bad in ipairs(cases) do
            local document = { SortMode = "manual", Usage = bad }
            local store = FakeStore({ [PREFERENCES] = document })
            local preferences = ModListState:New(store).preferences
            D.expect(preferences:IsInvalid()).toBe(true)
            D.expect(preferences:GetSortMode()).toBe("alphabetical")
            D.expect(preferences:RecordOpen(MOD_B)).toBe(false)
            D.expect(preferences:ClearUsage()).toBe(false)
            D.expect(store.values[PREFERENCES]).toBe(document)
        end
    end)

    D.test("zero and whole usage numbers are valid, and fields stay optional", function()
        for _, good in ipairs({
            { Sequence = 0 }, {}, { Sequence = 5, Mods = { [MOD_A] = { Count = 0, Last = 0 } } },
            { Sequence = 0, Mods = { [MOD_A] = { Count = 0, Last = 0 } } }, { Mods = { [MOD_A] = { Count = 0, Last = 0 } } },
            { Sequence = 3, Mods = { [MOD_A] = { Count = 1, Last = 3 } } },
        }) do
            local preferences = ModListState:New(FakeStore({ [PREFERENCES] = { Usage = good } })).preferences
            D.expect(preferences:IsInvalid()).toBe(false)
            D.expect(preferences:RecordOpen(MOD_B)).toBe(true)
        end
    end)

    D.test("repeated recording and clearing keep the document valid", function()
        local preferences = ModListState:New(FakeStore()).preferences
        D.expect(preferences:RecordOpen(MOD_A)).toBe(true)
        D.expect(preferences:RecordOpen(MOD_B)).toBe(true)
        D.expect(preferences:IsInvalid()).toBe(false)
        D.expect(preferences:ClearUsage()).toBe(true)
        D.expect(preferences:RecordOpen(MOD_A)).toBe(true)
        D.expect(preferences:IsInvalid()).toBe(false)
    end)

    D.test("folders open unless closed, and a closed state saves, reloads and stays per folder", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "manual", Usage = usage({}) } })
        local preferences = ModListState:New(store).preferences
        D.expect(preferences:IsFolderExpanded("a")).toBe(true)
        D.expect(preferences:SetFolderExpanded("a", false)).toBe(true)
        D.expect(preferences:SetFolderExpanded("b", false)).toBe(true)
        D.expect(preferences:SetFolderExpanded("b", true)).toBe(true)
        D.expect(store.values[PREFERENCES].CollapsedFolders).toEqual({ a = true })
        D.expect(store.values[PREFERENCES].SortMode).toBe("manual")
        local reloaded = ModListState:New(store).preferences
        D.expect(reloaded:IsFolderExpanded("a")).toBe(false)
        D.expect(reloaded:IsFolderExpanded("b")).toBe(true)
        D.expect(reloaded:SetFolderExpanded("a", true)).toBe(true)
        D.expect(store.values[PREFERENCES].CollapsedFolders).toBeNil()
    end)

    D.test("an unchanged folder state writes nothing", function()
        local writes = 0
        local store = FakeStore({ [PREFERENCES] = { CollapsedFolders = { a = true } } })
        local set = store.Set
        store.Set = function(var, value) writes = writes + 1; return set(var, value) end
        local preferences = ModListState:New(store).preferences
        D.expect(preferences:SetFolderExpanded("a", false)).toBe(true)
        D.expect(preferences:SetFolderExpanded("z", true)).toBe(true)
        D.expect(writes).toBe(0)
    end)

    D.test("an invalid saved folder state protects the document", function()
        for _, bad in ipairs({ "closed", { a = false }, { a = 1 }, { [1] = true } }) do
            local document = { CollapsedFolders = bad }
            local store = FakeStore({ [PREFERENCES] = document })
            local preferences = ModListState:New(store).preferences
            D.expect(preferences:IsInvalid()).toBe(true)
            D.expect(preferences:SetFolderExpanded("a", false)).toBe(false)
            D.expect(store.values[PREFERENCES]).toBe(document)
        end
    end)

    D.test("folder IDs come from a layout counter that only grows", function()
        local store = FakeStore()
        local state = ModListState:New(store)
        local ids = {}
        for index = 1, 3 do
            ids[index] = state:NextFolderId({ main = {} })
            D.expect(state:CreateFolder(ids[index], "Folder " .. index)).toBe(true)
        end
        D.expect(ids).toEqual({ "fld-1", "fld-2", "fld-3" })
        D.expect(store.values.UI.NextFolder).toBe(4)
        D.expect(state:DeleteFolder("fld-3")).toBe(true)
        D.expect(store.values.UI.NextFolder).toBe(4)
        D.expect(state:NextFolderId({ main = {} })).toBe("fld-4")
        D.expect(state:CreateFolder("custom", "Not numbered")).toBe(true)
        D.expect(store.values.UI.NextFolder).toBe(4)
    end)

    D.test("a closed state for a deleted folder never reaches a new folder, readable or not", function()
        local store = FakeStore({ UI = { NextFolder = 3, Folders = { ["fld-2"] = { Name = "Old" } } },
            [PREFERENCES] = { CollapsedFolders = { ["fld-2"] = true } } })
        local state = ModListState:New(store)
        D.expect(state:DeleteFolder("fld-2")).toBe(true)
        -- A fresh context where the preference file reads as nil, as Ext.IO.LoadFile gives for a missing or unopenable file
        local saved = store.values[PREFERENCES]
        store.values[PREFERENCES] = nil
        local fresh = ModListState:New(store)
        local id = fresh:NextFolderId({ main = {} })
        D.expect(id).toBe("fld-3")
        D.expect(fresh:CreateFolder(id, "New")).toBe(true)
        store.values[PREFERENCES] = saved
        D.expect(ModListState:New(store).preferences:IsFolderExpanded(id)).toBe(true)
    end)

    D.test("a corrupted counter protects the layout and a refused write keeps the counter", function()
        for _, bad in ipairs({ 0, 1.5, "7" }) do
            local document = { NextFolder = bad }
            local store = FakeStore({ UI = document })
            local state = ModListState:New(store)
            D.expect(state:NextFolderId({ main = {} })).toBeNil()
            D.expect(state:CreateFolder("fld-1", "New")).toBe(false)
            D.expect(store.values.UI).toBe(document)
        end
        local store = FakeStore({ UI = { NextFolder = 5 } }, { UI = true })
        local state = ModListState:New(store)
        D.expect(state:CreateFolder(state:NextFolderId({ main = {} }), "New")).toBe(false)
        D.expect(store.values.UI).toEqual({ NextFolder = 5 })
    end)

    --- A list button wired to stand-ins for the pane's navigation
    ---@param ctx table
    ---@param store table
    ---@param active string|nil Page shown before the activation
    ---@param uuid string
    ---@return table button
    local function ListButton(ctx, store, active, uuid)
        ctx.stub(DualPane, "SwitchVisibleContent", function() end)
        local button = { SetStyle = function() end, SetColor = function() end }
        local pane = setmetatable({
            parent = { AddButton = function() return button end },
            activeUUID = active,
            mods = { [MOD_A] = {}, [ModuleUUID] = {} },
            visibility = ModListState:New(store),
        }, LeftPane)
        pane:CreateMenuButton("Entry", nil, uuid)
        return button
    end

    D.test("activating a list entry counts one use", function(ctx)
        local store = FakeStore()
        ListButton(ctx, store, MOD_B, MOD_A).OnClick()
        D.expect(store.values[PREFERENCES].Usage.Mods[MOD_A]).toEqual({ Count = 1, Last = 1 })
    end)

    D.test("reselecting the page, MCM and tools do not count", function(ctx)
        local store = FakeStore()
        ListButton(ctx, store, MOD_A, MOD_A).OnClick()
        ListButton(ctx, store, MOD_B, ModuleUUID).OnClick()
        ListButton(ctx, store, MOD_B, ClientGlobals.MCM_HOTKEYS).OnClick()
        D.expect(store.values[PREFERENCES]).toBe(nil)
    end)

    D.test("API navigation and restoration do not count", function(ctx)
        local store = FakeStore()
        local leftPane = { SetActiveItem = function() end, visibility = ModListState:New(store) }
        local rightPane = { SetVisibleGroup = function() end, FocusModContentChildWindow = function() end }
        local controller = setmetatable({ leftPane = leftPane, rightPane = rightPane }, DualPaneController)
        ctx.stub(controller, "FindTab", function() return nil end)
        ctx.stub(controller, "HandleSidebarStateChange", function() end)
        ctx.stub(controller, "UnselectTabAfterDelay", function() end)
        controller:OpenModPage(MOD_A, nil, false, true, false)
        controller:SetVisibleFrame(MOD_A, false)
        D.expect(store.values[PREFERENCES]).toBe(nil)
    end)

    D.test("closing MCM rebuilds only when the new ranks can change the list", function()
        local store = FakeStore({ [PREFERENCES] = { SortMode = "recent" } })
        local state = ModListState:New(store)
        state:Resolve(MODS)
        local rebuilt = 0
        local pane = setmetatable({ visibility = state, mods = {},
            RebuildModEntries = function() rebuilt = rebuilt + 1 end }, LeftPane)
        pane:StartRankingSession()
        D.expect(rebuilt).toBe(0)
        state:Resolve(MODS)
        state.preferences:RecordOpen(MOD_A)
        pane:StartRankingSession()
        D.expect(rebuilt).toBe(1)
    end)

    --- A Mod list section rendered on stand-in widgets
    ---@param store table
    ---@return ModListSettings settings
    ---@return table pane
    local function Settings(store)
        local noop = function() end
        local group = {}
        function group:AddSeparatorText() return { SetColor = noop } end
        function group:AddText(label) return { Label = label, SetColor = noop } end
        function group:AddDummy() end
        function group:AddRadioButton(label, active) return { Label = label, Active = active } end
        function group:AddCheckbox(label, checked) return { Label = label, Checked = checked } end
        function group:AddButton(label) return { Label = label } end
        local parent = { AddGroup = function() return group end, AddDummy = noop }
        local pane = { visibility = ModListState:New(store), mods = {}, rebuilt = 0 }
        function pane:RebuildModEntries() self.rebuilt = self.rebuilt + 1 end
        return ModListSettings:New(parent, pane), pane
    end

    D.test("settings list the four orders with Alphabetical selected and hide the empty feedback", function()
        local settings = Settings(FakeStore())
        local modes = {}
        for _, radio in ipairs(settings.radios) do table.insert(modes, radio.UserData.mode) end
        D.expect(modes).toEqual({ "alphabetical", "manual", "recent", "frequent" })
        D.expect(settings.radios[1].Active).toBe(true)
        D.expect(settings.foldersFirst.Checked).toBe(false)
        D.expect(settings.feedback.Visible).toBe(false)
    end)

    D.test("settings explain an invalid file, and absent fields stay valid", function(ctx)
        local dialog = { SetOkLabel = function() end, SetCancelLabel = function() end, Show = function() end }
        ctx.stub(DialogService, "Confirm", function() return dialog end)
        D.expect(Settings(FakeStore({ [PREFERENCES] = { FoldersFirst = "yes" } })).feedback.Visible).toBe(true)
        local bad = { SortMode = "newest" }
        local store = FakeStore({ [PREFERENCES] = bad })
        local settings = Settings(store)
        settings.radios[2].OnChange()
        settings:ConfirmClearUsage()
        D.expect(settings.feedback.Visible).toBe(true)
        D.expect(store.values[PREFERENCES]).toBe(bad)
        D.expect(Settings(FakeStore({ [PREFERENCES] = {} })).feedback.Visible).toBe(false)
    end)

    D.test("selecting an order saves it, selects one radio and rebuilds once", function()
        local store = FakeStore()
        local settings, pane = Settings(store)
        settings.radios[3].OnChange()
        D.expect(store.values[PREFERENCES].SortMode).toBe("recent")
        D.expect(settings.radios[1].Active).toBe(false)
        D.expect(settings.radios[3].Active).toBe(true)
        D.expect(pane.rebuilt).toBe(1)
        settings.radios[3].OnChange()
        D.expect(pane.rebuilt).toBe(1)
    end)

    D.test("a refused order keeps the controls and shows an error", function()
        local store = FakeStore(nil, { [PREFERENCES] = true })
        local settings, pane = Settings(store)
        settings.radios[2].OnChange()
        D.expect(settings.radios[1].Active).toBe(true)
        D.expect(settings.radios[2].Active).toBe(false)
        D.expect(settings.feedback.Visible).toBe(true)
        D.expect(pane.rebuilt).toBe(0)
    end)

    D.test("a refused Folders first restores the checkbox", function()
        local settings = Settings(FakeStore(nil, { [PREFERENCES] = true }))
        settings.foldersFirst.Checked = true
        settings.foldersFirst.OnChange(settings.foldersFirst)
        D.expect(settings.foldersFirst.Checked).toBe(false)
        D.expect(settings.feedback.Visible).toBe(true)
    end)

    D.test("Sync shows an automatic switch to Manual", function()
        local settings, pane = Settings(FakeStore())
        pane.visibility.preferences:SetSortMode("manual")
        settings:Sync()
        D.expect(settings.radios[2].Active).toBe(true)
    end)

    D.test("Clear usage history waits for confirmation and reports the result", function(ctx)
        local store = FakeStore({ [PREFERENCES] = { SortMode = "manual", Usage = usage({}) } })
        local settings = Settings(store)
        local confirm
        local dialog = { SetOkLabel = function() end, SetCancelLabel = function() end, Show = function() end }
        ctx.stub(DialogService, "Confirm", function(_, _, _, _, _, _, onOk)
            confirm = onOk
            return dialog
        end)
        settings:ConfirmClearUsage()
        D.expect(store.values[PREFERENCES].Usage ~= nil).toBe(true)
        confirm()
        D.expect(store.values[PREFERENCES]).toEqual({ SortMode = "manual" })
        D.expect(settings.feedback.Visible).toBe(true)
    end)
end)
