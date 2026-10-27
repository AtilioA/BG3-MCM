D.describe("LeftPane mod entry menu", { tags = { "mod_list_visibility", "client", "unit" } }, function()
    local MOD_A = "00000000-0000-0000-0000-00000000A001"
    local MOD_B = "00000000-0000-0000-0000-00000000B002"

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

    --- Popup stand-in that records one entry per menu row; a bullet and its selectable are one row
    ---@return table popup
    local function FakePopup()
        local noop = function() end
        local popup = { Children = {}, items = {} }
        function popup:AddText() return { SetColor = noop } end
        function popup:AddSeparator() end
        function popup:AddBulletText()
            local row = { SetColor = noop, SetStyle = noop }
            table.insert(self.items, row)
            return row
        end
        function popup:AddSelectable(label)
            local row = self.items[#self.items]
            if not row then
                row = { SetStyle = noop }
                table.insert(self.items, row)
            end
            row.Label = label
            return row
        end
        popup.SetColor = noop
        popup.SetStyle = noop
        popup.SetSizeConstraints = noop
        popup.Open = noop
        return popup
    end

    --- Open the right-click menu for MOD_A
    ---@param store table Store stand-in from FakeStore
    ---@param authorHidden boolean The mod's blueprint HiddenFromList
    ---@param isHidden boolean Whether the entry is in Hidden mods
    ---@return table popup Rows the menu offers; the last row is the visibility action
    local function OpenMenu(store, authorHidden, isHidden)
        local popup = FakePopup()
        local leftPane = setmetatable({
            parent = { AddPopup = function() return popup end },
            mods = { [MOD_A] = { blueprint = { GetModName = function() return "Test Mod" end, GetHiddenFromList = function() return authorHidden end } } },
            visibility = ModListVisibility:New(store),
        }, LeftPane)
        -- Rebuilding the navigation needs a real window; these tests only check what the item saves
        leftPane.RebuildModEntries = function() end
        leftPane:OpenModEntryMenu(MOD_A, isHidden)
        return popup
    end

    D.test("a visible-by-default entry offers one Hide that saves an explicit choice", function()
        local store = FakeStore()
        local popup = OpenMenu(store, false, false)

        -- The menu lists the detach action first, then the visibility action
        D.expect(#popup.items).toBe(2)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = true })
    end)

    D.test("a hidden-by-default entry without a choice offers one Show that saves an explicit choice", function()
        local store = FakeStore()
        local popup = OpenMenu(store, true, true)

        D.expect(#popup.items).toBe(2)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("the default-marked Show removes a Hide choice and keeps other state", function()
        local store = FakeStore({
            Version = 1,
            UI = { Other = "kept", Mods = { [MOD_A] = { HiddenFromList = true }, [MOD_B] = { HiddenFromList = true } } },
        })
        local popup = OpenMenu(store, false, true)

        D.expect(#popup.items).toBe(2)
        popup.items[2].OnClick()

        D.expect(store.values).toEqual({
            Version = 1,
            UI = { Other = "kept", Mods = { [MOD_B] = { HiddenFromList = true } } },
        })
    end)

    D.test("the default-marked Hide removes a Show choice and keeps other state", function()
        local store = FakeStore({
            Version = 1,
            UI = { Other = "kept", Mods = { [MOD_A] = { HiddenFromList = false } } },
        })
        local popup = OpenMenu(store, true, false)

        D.expect(#popup.items).toBe(2)
        popup.items[2].OnClick()

        D.expect(store.values).toEqual({ Version = 1, UI = { Other = "kept", Mods = {} } })
    end)

    D.test("a choice that matches the author default offers only the opposite explicit action", function()
        local store = FakeStore({ Version = 1, UI = { Mods = { [MOD_A] = { HiddenFromList = true } } } })
        local popup = OpenMenu(store, true, true)

        D.expect(#popup.items).toBe(2)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("a protected state document offers the detach action only", function()
        local store = FakeStore({}, true)
        local popup = OpenMenu(store, false, false)

        D.expect(#popup.items).toBe(1)
        D.expect(store.values).toEqual({})
    end)
end)
