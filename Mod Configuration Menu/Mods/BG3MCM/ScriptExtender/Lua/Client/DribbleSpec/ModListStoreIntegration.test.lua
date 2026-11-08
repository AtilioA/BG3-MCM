-- Runs ModListState:Move over real MCM.Store, SettingsService and JsonAdapter; only Ext.IO is replaced.
-- Both Store files are seeded in the Sandbox's memory first, so LoadFile never falls through to the player's files.
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

local LAYOUT_VAR, PREFERENCES_VAR = "UI", "ModListPreferences"
local MOD_A = "b7a1e3c0-0000-4000-8000-00000000a001"
local MOD_B = "b7a1e3c0-0000-4000-8000-00000000b002"
local MODS = { { id = MOD_A, name = "Integration Alpha" }, { id = MOD_B, name = "Integration Beta" } }

---@param fileName string
---@return string path
local function StorePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

local LAYOUT_PATH = StorePath("MCM_state.json")
local PREFERENCES_PATH = StorePath("MCM_mod_list_preferences.json")

---@param entries ResolvedModListEntry[]
---@return string[] ids
local function Ids(entries)
    local ids = {}
    for _, entry in ipairs(entries) do table.insert(ids, entry.id) end
    return ids
end

---@param resolved ResolvedModList
---@param id string
---@return ResolvedModListEntry|nil
local function Entry(resolved, id)
    for _, entry in ipairs(resolved.main) do
        if entry.id == id then return entry end
    end
end

---@param path string
---@return table document The JSON on the Sandbox's disk
local function ReadFile(path)
    return Ext.Json.Parse(Ext.IO.LoadFile(path))
end

D.describe("Mod list move over the real Store", { tags = { "store", "mod_list_sorting", "client", "unit" } }, function()
    local fixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        fixture:Isolate(ctx)
    end)

    D.afterEach(function()
        fixture:Restore()
    end)

    --- Seed folders X and Y and two mods, shown as X, Y, A, B under Folders first.
    ---@param preferences table
    ---@return ModListState state
    local function NewState(preferences)
        Ext.IO.SaveFile(LAYOUT_PATH, Ext.Json.Stringify({ [LAYOUT_VAR] = {
            Folders = { x = { Name = "X" }, y = { Name = "Y" } },
            Order = { Main = { MOD_A, "x", MOD_B, "y" } },
        } }))
        Ext.IO.SaveFile(PREFERENCES_PATH, Ext.Json.Stringify({ [PREFERENCES_VAR] = preferences }))
        return ModListState:New(MCM.Store)
    end

    --- Make chosen SaveFile attempts fail; earlier attempts on the path succeed.
    ---@param ctx table
    ---@param failFrom table<string, integer> Path -> first attempt that fails
    ---@return table<string, integer> attempts
    ---@return fun() allow Lets every later write succeed
    -- bg3-lint: allow BG3-ENGINE-WRITE -- the SaveFile result is the contract under test, and the Sandbox already stubs this function
    local function FailSaves(ctx, failFrom)
        local attempts, sandboxSave, failing = {}, Ext.IO.SaveFile, true
        ctx.stub(Ext.IO, "SaveFile", function(path, content)
            attempts[path] = (attempts[path] or 0) + 1
            if failing and failFrom[path] and attempts[path] >= failFrom[path] then return false end
            return sandboxSave(path, content)
        end)
        return attempts, function() failing = false end
    end

    --- Drag folder X onto mod A, which Folders first would hide.
    ---@param state ModListState
    ---@return boolean saved
    ---@return ModListMoveFailure|nil reason
    local function DragFolderOntoMod(state)
        local resolved = state:Resolve(MODS)
        return state:Move(Entry(resolved, "x"), "Main", "Main", Entry(resolved, MOD_A), resolved)
    end

    --- Assert the mode, grouping and displayed order the player would see.
    local function ExpectView(state, mode, foldersFirst, shown)
        D.expect(state.preferences:GetSortMode()).toBe(mode)
        D.expect(state.preferences:GetFoldersFirst()).toBe(foldersFirst)
        D.expect(Ids(state:Resolve(MODS).main)).toEqual(shown)
    end

    local GROUPED = { "x", "y", MOD_A, MOD_B }

    D.test("TestSuccessSavesReorderManualAndClearedGroupingToDisk", function(ctx)
        local state = NewState({ SortMode = "recent", FoldersFirst = true })
        local attempts = FailSaves(ctx, {})

        D.expect(DragFolderOntoMod(state)).toBe(true)

        D.expect(attempts[LAYOUT_PATH]).toBe(1)
        D.expect(attempts[PREFERENCES_PATH]).toBe(1)
        D.expect(ReadFile(PREFERENCES_PATH)[PREFERENCES_VAR].SortMode).toBe("manual")
        D.expect(ReadFile(PREFERENCES_PATH)[PREFERENCES_VAR].FoldersFirst).toBe(false)
        D.expect(ReadFile(LAYOUT_PATH)[LAYOUT_VAR].Order.Main).toEqual({ "y", MOD_A, "x", MOD_B })
        -- A new load reads only what the files hold.
        StorageSyncService._cache = {}
        JsonAdapter._cache = {}
        ExpectView(ModListState:New(MCM.Store), "manual", false, { "y", MOD_A, "x", MOD_B })
    end)

    D.test("TestLayoutSaveFailureChangesNothing", function(ctx)
        local state = NewState({ SortMode = "alphabetical", FoldersFirst = true })
        local layoutBefore = Ext.IO.LoadFile(LAYOUT_PATH)
        local preferencesBefore = Ext.IO.LoadFile(PREFERENCES_PATH)
        local uiBefore = table.deepcopy(MCM.Store.Get(LAYOUT_VAR))
        local attempts = FailSaves(ctx, { [LAYOUT_PATH] = 1 })
        fixture.emittedEvents = {}

        local saved, reason = DragFolderOntoMod(state)

        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(attempts[PREFERENCES_PATH]).toBeNil()
        D.expect(Ext.IO.LoadFile(LAYOUT_PATH)).toBe(layoutBefore)
        D.expect(Ext.IO.LoadFile(PREFERENCES_PATH)).toBe(preferencesBefore)
        D.expect(MCM.Store.Get(LAYOUT_VAR)).toEqual(uiBefore)
        D.expect(#fixture.emittedEvents).toBe(0)
        D.expect(#fixture.sentToServer).toBe(0)
        ExpectView(state, "alphabetical", true, GROUPED)
    end)

    --- The reorder fails on the preference write and the layout returns to its earlier state.
    ---@param ctx table
    ---@param mode ModListSortMode
    local function ExpectRollback(ctx, mode)
        local state = NewState({ SortMode = mode, FoldersFirst = true })
        local uiBefore = table.deepcopy(MCM.Store.Get(LAYOUT_VAR))
        local preferencesBefore = Ext.IO.LoadFile(PREFERENCES_PATH)
        local attempts = FailSaves(ctx, { [PREFERENCES_PATH] = 1 })
        fixture.emittedEvents = {}

        local saved, reason = DragFolderOntoMod(state)

        D.expect(saved).toBe(false)
        D.expect(reason).toBe("save")
        D.expect(attempts[LAYOUT_PATH]).toBe(2)
        D.expect(ReadFile(LAYOUT_PATH)[LAYOUT_VAR]).toEqual(uiBefore)
        D.expect(MCM.Store.Get(LAYOUT_VAR)).toEqual(uiBefore)
        D.expect(Ext.IO.LoadFile(PREFERENCES_PATH)).toBe(preferencesBefore)
        -- The forward write and its rollback each saved, and nothing saved for the preferences.
        D.expect(#fixture.emittedEvents).toBe(2)
        for _, event in ipairs(fixture.emittedEvents) do D.expect(event.data.key).toBe(LAYOUT_VAR) end
        D.expect(#fixture.sentToServer).toBe(0)
        ExpectView(state, mode, true, GROUPED)
    end

    D.test("TestPreferenceSaveFailureRollsBackInManual", function(ctx)
        ExpectRollback(ctx, "manual")
    end)

    D.test("TestPreferenceSaveFailureRollsBackInAutomaticMode", function(ctx)
        ExpectRollback(ctx, "alphabetical")
    end)

    D.test("TestFailedRollbackReportsPartialAndTheStateOnDisk", function(ctx)
        local warnings = {}
        ctx.stub(_G, "MCMWarn", function(_, message) table.insert(warnings, message) end)
        local state = NewState({ SortMode = "recent", FoldersFirst = true })
        FailSaves(ctx, { [PREFERENCES_PATH] = 1, [LAYOUT_PATH] = 2 })

        local saved, reason = DragFolderOntoMod(state)

        D.expect(saved).toBe(false)
        D.expect(reason).toBe("partial")
        local moved = { "y", MOD_A, "x", MOD_B }
        D.expect(ReadFile(LAYOUT_PATH)[LAYOUT_VAR].Order.Main).toEqual(moved)
        D.expect(MCM.Store.Get(LAYOUT_VAR).Order.Main).toEqual(moved)
        D.expect(ReadFile(PREFERENCES_PATH)[PREFERENCES_VAR].SortMode).toBe("recent")
        D.expect(ReadFile(PREFERENCES_PATH)[PREFERENCES_VAR].FoldersFirst).toBe(true)
        D.expect(state.preferences:GetSortMode()).toBe("recent")
        local warned = false
        for _, message in ipairs(warnings) do
            warned = warned or message:find("could not save its order settings", 1, true) ~= nil
        end
        D.expect(warned).toBe(true)
    end)

    --- Every organization write the player can make, against a resolved list.
    local function OrganizationWrites(state, resolved)
        return {
            function() return state:SetHidden(MOD_A, true) end,
            function() return state:UseDefault(MOD_B) end,
            function() return state:SetPinned(MOD_A, true) end,
            function() return state:SetFolder(MOD_A, "x") end,
            function() return state:CreateFolder("new", "New") end,
            function() return state:RenameFolder("x", "Renamed") end,
            function() return state:DeleteFolder("x") end,
            function() return (state:Move(Entry(resolved, "x"), "Main", "Main", Entry(resolved, MOD_A), resolved)) end,
        }
    end

    --- Seed a layout with the given Version.
    local function NewVersionedState(version)
        Ext.IO.SaveFile(LAYOUT_PATH, Ext.Json.Stringify({ Version = version, Other = "kept", [LAYOUT_VAR] = {
            Folders = { x = { Name = "X" }, y = { Name = "Y" } },
            Mods = { [MOD_B] = { HiddenFromList = false } },
            Order = { Main = { MOD_A, "x", MOD_B, "y" } },
        } }))
        Ext.IO.SaveFile(PREFERENCES_PATH, Ext.Json.Stringify({ [PREFERENCES_VAR] = { SortMode = "recent", FoldersFirst = true } }))
        return ModListState:New(MCM.Store)
    end

    for _, version in ipairs({ 2, "x" }) do
        D.test("TestUnsupportedVersionRefusesEveryWrite_" .. tostring(version), function(ctx)
            local warnings = 0
            ctx.stub(_G, "MCMWarn", function() warnings = warnings + 1 end)
            local state = NewVersionedState(version)
            local layoutBefore = Ext.IO.LoadFile(LAYOUT_PATH)
            local preferencesBefore = Ext.IO.LoadFile(PREFERENCES_PATH)
            D.expect(warnings).toBe(1)
            D.expect(state:IsProtected()).toBe(true)
            local resolved = state:Resolve(MODS)
            D.expect(state:NextFolderId(resolved)).toBeNil()
            for _, write in ipairs(OrganizationWrites(state, resolved)) do
                D.expect(write()).toBe(false)
            end
            D.expect(Ext.IO.LoadFile(LAYOUT_PATH)).toBe(layoutBefore)
            D.expect(Ext.IO.LoadFile(PREFERENCES_PATH)).toBe(preferencesBefore)
            D.expect(state.preferences:GetSortMode()).toBe("recent")
            D.expect(state.preferences:GetFoldersFirst()).toBe(true)
        end)
    end

    D.test("TestSupportedVersionKeepsWritesAndAddsNoField", function()
        local state = NewVersionedState(1)
        D.expect(state:SetPinned(MOD_A, true)).toBe(true)
        D.expect(ReadFile(LAYOUT_PATH).Version).toBe(1)
        D.expect(ReadFile(LAYOUT_PATH).Other).toBe("kept")
    end)

    D.test("TestAbsentVersionWritesWithoutAddingVersionAndResolveWritesNothing", function()
        local state = NewState({ SortMode = "manual" })
        local before = Ext.IO.LoadFile(LAYOUT_PATH)
        D.expect(state:IsProtected()).toBe(false)
        D.expect(Ids(state:Resolve(MODS).main)).toEqual({ MOD_A, "x", MOD_B, "y" })
        D.expect(Ext.IO.LoadFile(LAYOUT_PATH)).toBe(before)
        D.expect(state:SetPinned(MOD_A, true)).toBe(true)
        D.expect(ReadFile(LAYOUT_PATH).Version).toBeNil()
    end)

    D.test("TestFolderCounterSurvivesDeleteAndFreshLoad", function()
        local state = NewState({ SortMode = "manual" })
        for _, expected in ipairs({ "fld-1", "fld-2" }) do
            local id = state:NextFolderId(state:Resolve(MODS))
            D.expect(id).toBe(expected)
            D.expect(state:CreateFolder(id, expected)).toBe(true)
        end
        D.expect(state:DeleteFolder("fld-2")).toBe(true)
        D.expect(ReadFile(LAYOUT_PATH)[LAYOUT_VAR].NextFolder).toBe(3)
        StorageSyncService._cache = {}
        JsonAdapter._cache = {}
        local fresh = ModListState:New(MCM.Store)
        D.expect(fresh:NextFolderId(fresh:Resolve(MODS))).toBe("fld-3")
    end)

    D.test("TestALaterSaveDoesNotFlushAFailedValue", function(ctx)
        local state = NewState({ SortMode = "recent", FoldersFirst = true })
        local _, allow = FailSaves(ctx, { [LAYOUT_PATH] = 1, [PREFERENCES_PATH] = 1 })
        D.expect(DragFolderOntoMod(state)).toBe(false)
        D.expect(state.preferences:SetSortMode("manual")).toBe(false)
        allow()

        D.expect(state.preferences:RecordOpen(MOD_A)).toBe(true)
        D.expect(state:SetPinned(MOD_B, true)).toBe(true)

        local preferences = ReadFile(PREFERENCES_PATH)[PREFERENCES_VAR]
        D.expect(preferences.SortMode).toBe("recent")
        D.expect(preferences.FoldersFirst).toBe(true)
        D.expect(preferences.Usage.Mods[MOD_A].Count).toBe(1)
        local layout = ReadFile(LAYOUT_PATH)[LAYOUT_VAR]
        D.expect(layout.Order.Main).toEqual({ MOD_A, "x", MOD_B, "y" })
        D.expect(layout.Mods[MOD_B].Pinned).toBe(true)
    end)
end)
