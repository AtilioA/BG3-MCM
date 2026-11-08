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

    --- Popup stand-in that records one entry per menu row; a bullet and its selectable are one row
    ---@return table popup
    local function FakePopup()
        local noop = function() end
        local popup = { Children = {}, items = {} }
        function popup:AddText(label) local text = { Label = label, SetColor = noop }; self.texts = self.texts or {}; table.insert(self.texts, text); return text end
        function popup:AddInputText(_, value) self.input = { Text = value, Activate = noop }; return self.input end
        function popup:AddButton(label) local button = { Label = label }; self.buttons = self.buttons or {}; table.insert(self.buttons, button); return button end
        popup.Destroy = noop
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
        function popup:SetStyle(key, value) if key == "Alpha" then self.alpha = value end end
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
            mods = { [MOD_A] = { blueprint = { GetModName = function() return "Test Mod" end, GetHiddenFromList = function() return authorHidden end, GetListFolder = function() return nil end } } },
            visibility = ModListState:New(store),
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
        D.expect(#popup.items).toBe(5)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = true })
    end)

    D.test("a hidden-by-default entry without a choice offers one Show that saves an explicit choice", function()
        local store = FakeStore()
        local popup = OpenMenu(store, true, true)

        D.expect(#popup.items).toBe(5)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("the default-marked Show removes a Hide choice and keeps other state", function()
        local store = FakeStore({
            UI = { Other = "kept", Mods = { [MOD_A] = { HiddenFromList = true }, [MOD_B] = { HiddenFromList = true } } },
        })
        local popup = OpenMenu(store, false, true)

        D.expect(#popup.items).toBe(5)
        popup.items[2].OnClick()

        D.expect(store.values).toEqual({
            UI = { Other = "kept", Mods = { [MOD_B] = { HiddenFromList = true } } },
        })
    end)

    D.test("the default-marked Hide removes a Show choice and keeps other state", function()
        local store = FakeStore({
            UI = { Other = "kept", Mods = { [MOD_A] = { HiddenFromList = false } } },
        })
        local popup = OpenMenu(store, true, false)

        D.expect(#popup.items).toBe(5)
        popup.items[2].OnClick()

        D.expect(store.values).toEqual({ UI = { Other = "kept", Mods = {} } })
    end)

    D.test("a choice that matches the author default offers only the opposite explicit action", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { HiddenFromList = true } } } })
        local popup = OpenMenu(store, true, true)

        D.expect(#popup.items).toBe(5)
        popup.items[2].OnClick()

        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ HiddenFromList = false })
    end)

    D.test("pin and move actions save the selected mod", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            mods = { [MOD_A] = { blueprint = { GetModName = function() return "Test" end, GetHiddenFromList = function() return false end } } },
            visibility = ModListState:New(store), resolved = { main = { { kind = "folder", id = "f", name = "Folder", items = {} } }, hidden = {} },
            RebuildModEntries = function() end }, LeftPane)
        pane:OpenModEntryMenu(MOD_A, false)
        D.expect(#popup.items).toBe(6)
        popup.items[3].OnClick()
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(true)
        popup.items[5].OnClick()
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("f")
    end)

    D.test("folder menu deletes a folder and returns its mods to the main list", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } } } })
        local popup = FakePopup()
        local pane = setmetatable({ expandedGroups = {}, parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderMenu({ id = "f", name = "Folder", items = { { id = MOD_A } }, members = { MOD_A } })
        D.expect(#popup.items).toBe(3)
        popup.items[2].OnClick()
        D.expect(store.values.UI.Folders.f).toBe(nil)
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe(false)
    end)

    D.test("blank sidebar menu only creates folders", function()
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore()), mods = {}, RebuildModEntries = function() end }, LeftPane)
        local opened = false
        pane.OpenFolderNamePopup = function(_, folder, mod)
            opened = folder == nil and mod == nil
        end
        pane:OpenFolderMenu({ id = "Main", name = "Main list" })
        D.expect(#popup.items).toBe(1)
        popup.items[1].OnClick()
        D.expect(opened).toBe(true)
    end)

    D.test("a refused menu save warns and keeps the list", function(ctx)
        local warnings = 0
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() warnings = warnings + 1 end)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore({}, true)), mods = {},
            RebuildModEntries = function() error("must not rebuild") end }, LeftPane)
        pane:OpenFolderMenu({ id = "f", name = "Folder", members = {} })
        popup.items[2].OnClick()
        D.expect(warnings).toBe(1)
    end)

    D.test("new folder validates its name and moves the selected mod", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Existing" } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, expandedGroups = { f = false },
            resolved = { main = { { kind = "folder", id = "f", name = "Existing", items = {} } } },
            RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderNamePopup(nil, MOD_A)
        popup.input.Text = "  "
        popup.buttons[1].OnClick()
        D.expect(store.values.UI.Mods).toBe(nil)
        popup.input.Text = " existing "
        popup.input.OnChange()
        D.expect(store.values.UI.Mods).toBe(nil)
        popup.input.Text = " New folder "
        popup.input.OnChange()
        local created = store.values.UI.Mods[MOD_A].Folder
        D.expect(created).toBe("fld-1")
        D.expect(store.values.UI.Folders[created].Name).toBe("New folder")
        D.expect(pane.expandedGroups.f).toBe(false)
        D.expect(pane:isGroupExpanded(created)).toBe(true)
        D.expect(store.values.ModListPreferences).toBeNil()
    end)

    D.test("a refused folder state save warns and keeps the change for this window only", function(ctx)
        local warnings = 0
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() warnings = warnings + 1 end)
        local store = FakeStore({ ModListPreferences = { SortMode = "manual" } }, true)
        local pane = setmetatable({ expandedGroups = {}, visibility = ModListState:New(store) }, LeftPane)
        pane:setGroupExpanded("a", false)
        D.expect(warnings).toBe(1)
        D.expect(pane:isGroupExpanded("a")).toBe(false)
        local reopened = setmetatable({ expandedGroups = {}, visibility = ModListState:New(store) }, LeftPane)
        D.expect(reopened:isGroupExpanded("a")).toBe(true)
        pane:setGroupExpanded("Hidden", true)
        D.expect(warnings).toBe(1)
    end)

    D.test("an invalid preference document warns on a folder toggle and keeps the file", function(ctx)
        local warnings = 0
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() warnings = warnings + 1 end)
        local document = { SortMode = "newest" }
        local store = FakeStore({ ModListPreferences = document })
        local pane = setmetatable({ expandedGroups = {}, visibility = ModListState:New(store) }, LeftPane)
        pane:setGroupExpanded("a", false)
        D.expect(warnings).toBe(1)
        D.expect(store.values.ModListPreferences).toBe(document)
    end)

    --- Store whose preference file alone refuses writes, as after a failed save or an unreadable file
    ---@param values table
    ---@param unreadablePreferences boolean
    local function PreferenceFailureStore(values, unreadablePreferences)
        local store = FakeStore(values)
        local set = store.Set
        store.Set = function(var, value)
            if var == "ModListPreferences" then return false end
            return set(var, value)
        end
        store.IsWritable = function(var) return not (unreadablePreferences and var == "ModListPreferences") end
        return store
    end

    --- Submit a new folder name through the real popup and return what the player sees
    local function CreateThroughPopup(pane, popup, name)
        pane:OpenFolderNamePopup(nil, nil)
        popup.input.Text = name
        popup.input.OnChange()
        return popup.texts[#popup.texts]
    end

    D.test("a failed close, then delete and recreate in one window, gives an open folder", function(ctx)
        -- A hand-written layout without a counter lets the recreated folder take the deleted folder's ID.
        local old = "fld-1"
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() end)
        local store = PreferenceFailureStore({ UI = { Folders = { [old] = { Name = "Old" } } },
            ModListPreferences = { SortMode = "manual" } }, false)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end }, expandedGroups = {},
            visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, RebuildModEntries = function() end }, LeftPane)
        pane:setGroupExpanded(old, false)
        D.expect(pane:isGroupExpanded(old)).toBe(false)
        local unchanged = setmetatable({ parent = { AddPopup = function() return FakePopup() end }, expandedGroups = { [old] = false },
            visibility = ModListState:New(FakeStore({ UI = { Folders = { [old] = { Name = "Old" } } } }, true)), mods = {},
            RebuildModEntries = function() end }, LeftPane)
        unchanged:OpenFolderMenu({ kind = "folder", id = old, name = "Old", members = {} })
        unchanged.modEntryMenu.items[2].OnClick()
        D.expect(unchanged.expandedGroups[old]).toBe(false)
        pane:OpenFolderMenu({ kind = "folder", id = old, name = "Old", members = {} })
        popup.items[2].OnClick()
        D.expect(store.values.UI.Folders[old]).toBeNil()
        CreateThroughPopup(pane, popup, "New")
        local created
        for id, folder in pairs(store.values.UI.Folders) do if folder.Name == "New" then created = id end end
        D.expect(pane:isGroupExpanded(created)).toBe(true)
    end)

    D.test("an unusable preference file does not block folder creation, and the new folder opens", function()
        for _, case in ipairs({
            { values = { ModListPreferences = { SortMode = "newest", CollapsedFolders = { ["fld-1"] = true } } }, unreadable = false },
            { values = {}, unreadable = true },
        }) do
            local store = PreferenceFailureStore(case.values, case.unreadable)
            local popup = FakePopup()
            local pane = setmetatable({ parent = { AddPopup = function() return popup end }, expandedGroups = {},
                visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, RebuildModEntries = function() end }, LeftPane)
            CreateThroughPopup(pane, popup, "New")
            D.expect(store.values.UI.Folders["fld-1"].Name).toBe("New")
            D.expect(pane:isGroupExpanded("fld-1")).toBe(true)
        end
    end)

    D.test("a refused layout write creates no folder, keeps the counter and shows the error", function()
        local store = FakeStore({ UI = { NextFolder = 2 } }, true)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end }, expandedGroups = {},
            visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, RebuildModEntries = function() end }, LeftPane)
        local message = CreateThroughPopup(pane, popup, "New")
        D.expect(store.values.UI).toEqual({ NextFolder = 2 })
        D.expect(message.Visible).toBe(true)
    end)

    D.test("deleting a folder writes only the layout, and a recreated folder opens", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } } },
            ModListPreferences = { SortMode = "manual", CollapsedFolders = { f = true } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end }, expandedGroups = {},
            visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderMenu({ kind = "folder", id = "f", name = "Folder", members = {} })
        popup.items[2].OnClick()
        D.expect(store.values.UI.Folders.f).toBeNil()
        D.expect(store.values.ModListPreferences.CollapsedFolders).toEqual({ f = true })
        local id = pane.visibility:NextFolderId(pane.resolved)
        D.expect(id ~= "f").toBe(true)
        D.expect(pane.visibility.preferences:IsFolderExpanded(id)).toBe(true)
    end)

    D.test("folder IDs skip historical references and names remove hash markers", function()
        local store = FakeStore({ UI = { Mods = { [MOD_B] = { Folder = "fld-1" } }, Order = { Main = { "fld-2" } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, expandedGroups = {},
            RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderNamePopup(nil, MOD_A)
        popup.input.Text = "Tools##x"
        popup.input.OnChange()
        D.expect(store.values.UI.Folders["fld-3"].Name).toBe("Toolsx")
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("fld-3")
        D.expect(store.values.UI.NextFolder).toBe(4)
    end)

    --- Sidebar container stand-in that records added widgets in order
    ---@param widgets table[] Receives every widget, including those added inside group boxes
    ---@return table container
    local function FakeContainer(widgets)
        local noop = function() end
        local container = { Children = {}, SetColor = noop }
        local function add(widget) widget.SetColor, widget.SetStyle = noop, noop; table.insert(widgets, widget); return widget end
        function container:AddTree(label) return add({ kind = "tree", Label = label, SetOpen = noop }) end
        function container:AddButton(label) return add({ kind = "button", Label = label }) end
        function container:AddText(label) return add({ kind = "text", Label = label }) end
        function container:AddSelectable(label, _, size) return add({ kind = "empty", Label = label, Size = size }) end
        function container:AddSeparatorText(label) return add({ kind = "pinned", Label = label }) end
        function container:AddSeparator() return add({ kind = "separator" }) end
        function container:AddTable()
            local box = add({ kind = "box" })
            function box:AddRow() return { AddCell = function() return FakeContainer(widgets) end } end
            return box
        end
        return container
    end

    --- A rendered sidebar driven by real rebuild, render, click and highlight code.
    --- Stand-ins: widgets (FakeContainer), the store, and DualPane.SwitchVisibleContent, which here only highlights,
    --- as the real controller does through SetActiveItem; the right pane is out of scope.
    local function RenderedSidebar(ctx, preferences)
        local MOD_C = "00000000-0000-0000-0000-00000000C003"
        local widgets = {}
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() for i = #widgets, 1, -1 do widgets[i] = nil end end)
        local store = FakeStore({ ModListPreferences = preferences,
            UI = { Folders = { f = { Name = "Tools" } }, Mods = { [MOD_C] = { Folder = "f" } } } })
        local function mod(name)
            return { blueprint = { GetModName = function() return name end, GetModDescription = function() return "" end,
                GetHiddenFromList = function() return false end, GetListFolder = function() return nil end } }
        end
        local mods = { [MOD_A] = mod("Alpha"), [MOD_B] = mod("Beta"), [MOD_C] = mod("Gamma") }
        local pane = setmetatable({ parent = { Children = {} }, modEntriesGroup = FakeContainer(widgets), expandedGroups = {},
            entryButtons = {}, visibility = ModListState:New(store) }, LeftPane)
        ctx.stub(DualPane, "SwitchVisibleContent", function(_, _, uuid) pane:SetActiveItem(uuid) end)
        pane:RebuildModEntries(mods)
        local view = { pane = pane, widgets = widgets }
        function view.buttons()
            local labels = {}
            for _, widget in ipairs(widgets) do
                if widget.kind == "button" and tostring(widget.IDContext):find("^MenuButton_") then table.insert(labels, widget.Label) end
            end
            return labels
        end
        function view.click(name)
            for _, widget in ipairs(widgets) do
                if widget.kind == "button" and widget.Label:gsub("^> ", "") == name then return widget.OnClick() end
            end
            error("no rendered button " .. name)
        end
        function view.folderOpen()
            for index, widget in ipairs(widgets) do
                if widget.kind == "tree" and widget.Label:find("##folder_f", 1, true) then return widgets[index + 1].Visible end
            end
        end
        return view
    end

    D.test("Frequently used reorders the rendered list on a click and keeps highlight and folder state", function(ctx)
        local view = RenderedSidebar(ctx, { SortMode = "frequent", FoldersFirst = false, Usage = { Sequence = 2,
            Mods = { [MOD_B] = { Count = 2, Last = 2 }, [MOD_A] = { Count = 1, Last = 1 } } } })
        local folder = nil
        for _, widget in ipairs(view.widgets) do if widget.kind == "tree" then folder = widget end end
        folder.OnCollapse()
        D.expect(view.folderOpen()).toBe(false)
        D.expect(view.buttons()).toEqual({ "Beta", "Alpha", "Gamma" })
        -- Count tie at 2: the later opening ranks first.
        view.click("Alpha")
        D.expect(view.buttons()).toEqual({ "> Alpha", "Beta", "Gamma" })
        view.click("Alpha")
        D.expect(view.buttons()).toEqual({ "> Alpha", "Beta", "Gamma" })
        D.expect(view.folderOpen()).toBe(false)
    end)

    D.test("Recently used keeps the rendered order on a click and still moves the highlight", function(ctx)
        local view = RenderedSidebar(ctx, { SortMode = "recent", Usage = { Sequence = 1, Mods = { [MOD_B] = { Count = 1, Last = 1 } } } })
        D.expect(view.buttons()).toEqual({ "Beta", "Alpha", "Gamma" })
        view.click("Alpha")
        D.expect(view.buttons()).toEqual({ "Beta", "> Alpha", "Gamma" })
    end)

    D.test("sidebar hides the main drop row until a drag and keeps folder labels unique", function(ctx)
        local widgets = {}
        local group = FakeContainer(widgets)
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ UI = { Folders = { f = { Name = "Tools##x" } } } })
        local pane = setmetatable({ parent = {}, modEntriesGroup = group, expandedGroups = {},
            visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
        pane:RebuildModEntries({})
        D.expect(widgets[1].Label).toBe("Toolsx##folder_f")
        -- Folders open unless the player closed them.
        D.expect(widgets[2].Visible).toBe(true)
        D.expect(group.DragDropType).toBe(nil)
        local target = pane.mainDropTargets.f
        D.expect(widgets[4]).toBe(target)
        D.expect(target.UserData.id).toBe("Main")
        D.expect(target.CanDrag).toBe(false)
        D.expect(target.Visible).toBe(false)
        D.expect(target.OnDragDrop ~= nil).toBe(true)
    end)

    D.test("folders render as saved without writing, and toggles persist across a new window", function(ctx)
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ UI = { Folders = { a = { Name = "A" }, b = { Name = "B" } } },
            ModListPreferences = { SortMode = "manual", CollapsedFolders = { b = true } } })
        local writes = 0
        local set = store.Set
        store.Set = function(var, value) writes = writes + 1; return set(var, value) end
        local function render()
            local widgets = {}
            local pane = setmetatable({ parent = {}, modEntriesGroup = FakeContainer(widgets), expandedGroups = {},
                visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
            pane:RebuildModEntries({})
            local trees = {}
            for _, widget in ipairs(widgets) do
                if widget.kind == "tree" then trees[widget.Label:match("_(%w+)$")] = widget end
            end
            return pane, trees
        end
        local pane, trees = render()
        D.expect(writes).toBe(0)
        D.expect(pane:isGroupExpanded("a")).toBe(true)
        D.expect(pane:isGroupExpanded("b")).toBe(false)
        trees.b.OnExpand()
        pane.RebuildModEntries = function() end
        trees.a.OnCollapse()
        D.expect(writes).toBe(2)
        local reopened = render()
        D.expect(writes).toBe(2)
        D.expect(reopened:isGroupExpanded("a")).toBe(false)
        D.expect(reopened:isGroupExpanded("b")).toBe(true)
        D.expect(store.values.ModListPreferences.SortMode).toBe("manual")
    end)

    D.test("an author-suggested folder appears open without a write, with a stable ID", function(ctx)
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ ModListPreferences = { SortMode = "manual" } })
        local writes = 0
        local set = store.Set
        store.Set = function(var, value) writes = writes + 1; return set(var, value) end
        local mods = { [MOD_A] = { blueprint = { GetModName = function() return "A" end,
            GetHiddenFromList = function() return false end, GetListFolder = function() return "Tools" end } } }
        ctx.stub(MCMUtils, "SortModsByName", function() return { MOD_A } end)
        local widgets = {}
        local pane = setmetatable({ parent = {}, modEntriesGroup = FakeContainer(widgets), expandedGroups = {},
            visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
        pane:RebuildModEntries(mods)
        D.expect(pane.resolved.main[1].id).toBe("suggested:tools")
        D.expect(pane:isGroupExpanded("suggested:tools")).toBe(true)
        D.expect(writes).toBe(0)
    end)

    D.test("an all-pinned list has a separator label and no trailing separator", function(ctx)
        local widgets = {}
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ UI = { Folders = { f = { Name = "Tools", Pinned = true } } } })
        local pane = setmetatable({ parent = {}, modEntriesGroup = FakeContainer(widgets), expandedGroups = {},
            visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
        pane:RebuildModEntries({})
        local kinds = {}
        for _, widget in ipairs(widgets) do table.insert(kinds, widget.kind) end
        D.expect(kinds).toEqual({ "pinned", "tree", "box", "empty", "button", "button" })
    end)

    D.test("the full empty-folder row accepts a mod and keeps its pin", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Empty" } },
            Mods = { [MOD_A] = { Pinned = true } } } })
        local state = ModListState:New(store)
        local resolved = state:Resolve({ { id = MOD_A, name = "A" } })
        local rebuilt = false
        local pane = setmetatable({ visibility = state, resolved = resolved, mods = {},
            RebuildModEntries = function() rebuilt = true end }, LeftPane)
        local widgets = {}
        pane:CreateEmptyFolderDropTarget(FakeContainer(widgets), "f")
        local target = widgets[1]
        D.expect(target.Size).toEqual({ 0, 50 })
        D.expect(target.CanDrag).toBe(false)
        target.OnDragDrop(target, { UserData = { kind = "mod", id = MOD_A, group = "Main" } })
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("f")
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(true)
        D.expect(rebuilt).toBe(true)
    end)

    D.test("the pinned section title accepts a drop and pins the source", function()
        local store = FakeStore({ UI = { Mods = { [MOD_A] = { Pinned = true } } } })
        local state = ModListState:New(store)
        local resolved = state:Resolve({ { id = MOD_A, name = "A" }, { id = MOD_B, name = "B" } })
        local pane = setmetatable({ visibility = state, resolved = resolved, mods = {},
            createModEntries = function() end, RebuildModEntries = function() end }, LeftPane)
        local widgets = {}
        pane:RenderModListItems(FakeContainer(widgets), resolved.main, "Main", false, {})
        local header = widgets[1]
        D.expect(header.CanDrag).toBe(false)
        header.OnDragDrop(header, { UserData = { kind = "mod", id = MOD_B, group = "Main" } })
        D.expect(store.values.UI.Mods[MOD_B].Pinned).toBe(true)
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_B, MOD_A })
    end)

    --- Render Main for section drops, keeping real drop callbacks on every section and folder header
    ---@param ui table Saved UI state
    ---@return table store
    ---@return table<string, table> targets Section widgets by fake kind and folder headers by ID
    local function RenderSections(ui)
        local store = FakeStore({ UI = ui })
        local state = ModListState:New(store)
        local resolved = state:Resolve({ { id = MOD_A, name = "A" } })
        local targets = {}
        local pane = setmetatable({ visibility = state, resolved = resolved, mods = {},
            createModEntries = function() end, RebuildModEntries = function() end }, LeftPane)
        pane.RenderModListGroup = function(_, id)
            targets[id] = {}
            return targets[id]
        end
        local widgets = {}
        pane:RenderModListItems(FakeContainer(widgets), resolved.main, "Main", false, {})
        for _, widget in ipairs(widgets) do targets[widget.kind] = widget end
        return store, targets
    end

    D.test("a Pinned heading that references a folder pins a Main mod and stays in Main", function()
        local store, targets = RenderSections({ Folders = { f = { Name = "F", Pinned = true } } })
        targets.pinned.OnDragDrop(targets.pinned, { UserData = { kind = "mod", id = MOD_A, group = "Main" } })
        D.expect(store.values.UI.Mods[MOD_A]).toEqual({ Pinned = true })
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_A, "f" })
    end)

    D.test("a pin boundary that references a folder unpins a Main mod and stays in Main", function()
        local store, targets = RenderSections({ Folders = { f = { Name = "F" } }, Mods = { [MOD_A] = { Pinned = true } } })
        targets.separator.OnDragDrop(targets.separator, { UserData = { kind = "mod", id = MOD_A, group = "Main" } })
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBeNil()
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBeNil()
        D.expect(store.values.UI.Order.Main).toEqual({ "f", MOD_A })
    end)

    D.test("section drops from a folder return the mod to Main and keep its pin", function()
        for _, case in ipairs({ { "pinned", true }, { "separator", false } }) do
            local kind, pinned = case[1], case[2]
            local store, targets = RenderSections({
                Folders = { f = { Name = "F", Pinned = pinned or nil }, g = { Name = "G", Pinned = (not pinned) or nil } },
                Mods = { [MOD_A] = { Folder = "g", Pinned = pinned or nil } },
            })
            targets[kind].OnDragDrop(targets[kind], { UserData = { kind = "mod", id = MOD_A, group = "g" } })
            D.expect(store.values.UI.Mods[MOD_A].Folder).toBe(false)
            D.expect(store.values.UI.Mods[MOD_A].Pinned == true).toBe(pinned)
        end
    end)

    D.test("a folder header still takes a dropped Main mod", function()
        local store, targets = RenderSections({ Folders = { f = { Name = "F", Pinned = true } } })
        targets.f.OnDragDrop(targets.f, { UserData = { kind = "mod", id = MOD_A, group = "Main" } })
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("f")
    end)

    D.test("dropping a folder on another folder reorders Main", function()
        local first = { kind = "folder", id = "first", items = {} }
        local second = { kind = "folder", id = "second", items = {} }
        local moved
        local pane = setmetatable({
            resolved = { main = { first, second }, hidden = {} },
            visibility = {
                Move = function(_, dragged, from, destination, target)
                    moved = { dragged, from, destination, target }
                    return true
                end,
            },
            RebuildModEntries = function() end,
        }, LeftPane)
        local source, target = {}, {}
        pane:ConfigureModListDrag(source, "folder", "second", "Main")
        pane:ConfigureModListDrag(target, "folder", "first", "Main")
        target.OnDragDrop(target, source)
        D.expect(moved).toEqual({ second, "Main", "Main", first })
    end)

    D.test("dropping a folder into Hidden refuses nesting without saving", function()
        local folder = { kind = "folder", id = "folder", items = {} }
        local refusal
        local pane = setmetatable({
            resolved = { main = { folder }, hidden = {} },
            visibility = {
                Move = function() error("nested folder must not be saved") end,
            },
            RefuseModListDrop = function(_, _, _, reason) refusal = reason end,
            RebuildModEntries = function() error("refused drop must not rebuild") end,
        }, LeftPane)
        local source, target = {}, {}
        pane:ConfigureModListDrag(source, "folder", "folder", "Main")
        pane:ConfigureModListDrag(target, "group", "Hidden", "Hidden")
        target.OnDragDrop(target, source)
        D.expect(refusal).toBe("nested")
    end)

    D.test("dragging a folder mod reveals only its group's main-list destination", function(ctx)
        local widgets = {}
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ UI = { Folders = {
            ["folder-1"] = { Name = "First" }, ["folder-2"] = { Name = "Second" },
        } } })
        local pane = setmetatable({ parent = {}, modEntriesGroup = FakeContainer(widgets), expandedGroups = {},
            visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
        pane:RebuildModEntries({})
        local source = { Label = "> Mod" }
        pane:ConfigureModListDrag(source, "mod", MOD_A, "folder-1")
        local preview = { AddText = function(_, text) source.previewText = text end }
        source.OnDragStart(source, preview)
        D.expect(source.previewText).toBe("Mod")
        D.expect(pane.mainDropTargets["folder-1"].Visible).toBe(true)
        D.expect(pane.mainDropTargets["folder-2"].Visible).toBe(false)
        source.OnDragEnd(source)
        D.expect(pane.mainDropTargets["folder-1"].Visible).toBe(false)
    end)

    D.test("releasing the last hold outside the sidebar resumes collapse and fade", function()
        local scheduled, faded = 0, 0
        local controller = setmetatable({ isHovered = false, windowOpacity = 0.5,
            menuScrollChildWindow = { StatusFlags = {}, SetStyle = function() end },
            rightPane = { IsCurrentModDetached = function() return false end },
            CancelAutoCollapse = function() end,
            ScheduleAutoCollapse = function() scheduled = scheduled + 1 end,
            FadeSidebarOutAlpha = function() faded = faded + 1 end }, { __index = DualPaneController })
        controller:HoldSidebar("drag", true)
        controller:HoldSidebar("folderName", true)
        controller:HoldSidebar("drag", false)
        D.expect(scheduled).toBe(0)
        controller:HoldSidebar("folderName", false)
        D.expect(scheduled).toBe(1)
        D.expect(faded).toBe(1)
    end)

    D.test("folder dialog only holds the sidebar while its input is active", function(ctx)
        local held = false
        ctx.stub(DualPane, "HoldSidebar", function(_, _, value) held = value end)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore()), resolved = { main = {} } }, LeftPane)
        pane:OpenFolderNamePopup(nil, nil)
        D.expect(held).toBe(false)
        popup.input.OnActivate()
        D.expect(held).toBe(true)
        popup.input.OnDeactivate()
        D.expect(held).toBe(false)
    end)

    D.test("leaving the sidebar schedules collapse", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function() return true end)
        local leave, scheduled
        local controller = setmetatable({ isHovered = true, windowOpacity = 1,
            menuScrollChildWindow = { Visible = true, StatusFlags = {}, SetStyle = function() end },
            rightPane = { IsCurrentModDetached = function() return false end },
            setupHoverHandlers = function(_, _, _, onLeave) leave = onLeave end,
            ScheduleAutoCollapse = function() scheduled = true end,
            FadeSidebarOutAlpha = function() end }, { __index = DualPaneController })
        controller:AttachHoverListeners()
        leave()
        D.expect(scheduled).toBe(true)
    end)

    D.test("selecting a mod keeps the sidebar open", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function() return true end)
        local toggled, switched = false, false
        ctx.stub(DualPane, "SwitchVisibleContent", function() switched = true end)
        ctx.stub(DualPane, "ToggleSidebar", function() toggled = true end)
        local button = { SetStyle = function() end, SetColor = function() end }
        local pane = setmetatable({ parent = { AddButton = function() return button end } }, LeftPane)
        pane:CreateMenuButton("Mod", nil, MOD_A)
        button.OnClick()
        D.expect(switched).toBe(true)
        D.expect(toggled).toBe(false)
    end)

    D.test("folder and mod context titles hold the sidebar while hovered", function(ctx)
        local held = false
        ctx.stub(DualPane, "HoldSidebar", function(_, _, value) held = value end)
        -- ctx.stub replaces only functions; this field is a table, and the menu reads its detached windows.
        local previousRightPane = DualPane.rightPane
        DualPane.rightPane = { detachedWindows = {} }
        ctx.sandbox:TrackRestore(function() DualPane.rightPane = previousRightPane end)
        for _, kind in ipairs({ "folder", "mod" }) do
            local popup = FakePopup()
            local pane = setmetatable({ parent = { AddPopup = function() return popup end },
                mods = { [ModuleUUID] = { blueprint = { GetModName = function() return "MCM" end } } },
                visibility = ModListState:New(FakeStore()) }, LeftPane)
            if kind == "folder" then
                pane:OpenFolderMenu({ id = "Main", name = "Main list" })
            else
                pane:OpenModEntryMenu(ModuleUUID, false)
            end
            local title = popup.texts[1]
            title.OnHoverEnter()
            D.expect(held).toBe(true)
            title.OnHoverLeave()
            D.expect(held).toBe(false)
        end
    end)

    D.test("a popup row holds the sidebar until hover leave or click", function(ctx)
        local held = false
        ctx.stub(DualPane, "HoldSidebar", function(_, _, value) held = value end)
        local popup = FakePopup()
        local clicked = false
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore()), resolved = { main = {} } }, LeftPane)
        pane:OpenFolderMenu({ id = "Main", name = "Main" })
        local row = popup.items[1]
        row.OnHoverEnter()
        D.expect(held).toBe(true)
        row.OnHoverLeave()
        D.expect(held).toBe(false)
        row.OnHoverEnter()
        ctx.stub(pane, "OpenFolderNamePopup", function() clicked = true end)
        row.OnClick()
        D.expect(held).toBe(false)
        D.expect(clicked).toBe(true)
    end)

    D.test("folder popup uses the configured window opacity", function()
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore()), resolved = { main = {} } }, LeftPane)
        pane:OpenFolderNamePopup(nil, nil)
        D.expect(popup.alpha).toBe(DualPane and DualPane.windowOpacity or 1)
    end)

    D.test("folder destinations have unique IDs and mark the current folder", function()
        local popup = FakePopup()
        local store = FakeStore()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            mods = { [MOD_A] = { blueprint = { GetModName = function() return "Test" end, GetHiddenFromList = function() return false end } } },
            visibility = ModListState:New(store), resolved = { main = {
                { kind = "folder", id = "f", name = "Main list", items = { { id = MOD_A } } },
                { kind = "folder", id = "g", name = "Main list", items = {} },
            }, hidden = {} }, RebuildModEntries = function() end }, LeftPane)
        pane:OpenModEntryMenu(MOD_A, false)
        D.expect(popup.items[5].Label).toBe("Main list##folder_f")
        D.expect(popup.items[5].Selected).toBe(true)
        D.expect(popup.items[5].Disabled).toBe(true)
        D.expect(popup.items[6].Label).toBe("Main list##folder_g")
        popup.items[3].OnClick()
        D.expect(store.values.UI.Mods[MOD_A].Pinned).toBe(true)
    end)

    D.test("failed folder save keeps input and popup", function()
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore({}, true)), mods = {}, resolved = { main = {} },
            RebuildModEntries = function() error("must not rebuild") end }, LeftPane)
        pane:OpenFolderNamePopup(nil, MOD_A)
        local errorText = popup.texts[#popup.texts]
        D.expect(errorText.Visible).toBe(false)
        popup.input.Text = "Tools"
        popup.buttons[1].OnClick()
        D.expect(pane.namePopup).toBe(popup)
        D.expect(popup.input.Text).toBe("Tools")
        D.expect(errorText.Label ~= "").toBe(true)
        D.expect(errorText.Visible).toBe(true)
    end)

    D.test("folder dialog stacks full-width save above cancel", function()
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore()), resolved = { main = {} } }, LeftPane)
        pane:OpenFolderNamePopup(nil, nil)
        D.expect(#popup.buttons).toBe(2)
        for _, button in ipairs(popup.buttons) do
            D.expect(button.Size).toEqual({ -1, 0 })
            D.expect(button.SameLine).toBe(nil)
        end
        popup.buttons[2].OnClick()
        D.expect(pane.namePopup).toBe(nil)
    end)

    D.test("MCM menu retains detach and cannot start a list drag", function()
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            mods = { [ModuleUUID] = { blueprint = { GetModName = function() return "MCM" end } } },
            visibility = ModListState:New(FakeStore()) }, LeftPane)
        pane:OpenModEntryMenu(ModuleUUID, false)
        D.expect(#popup.items).toBe(1)
        local widget = {}
        pane:ConfigureModListDrag(widget, "mod", ModuleUUID, "Main")
        D.expect(widget.CanDrag).toBe(false)
        D.expect(widget.OnDragDrop ~= nil).toBe(true)
    end)

    D.test("a section anchored by MCM keeps a dropped mod in Main behind MCM", function()
        local store = FakeStore({ UI = {} })
        local state = ModListState:New(store)
        local mods = { { id = ModuleUUID, name = "MCM" }, { id = MOD_A, name = "A" } }
        local resolved = state:Resolve(mods)
        local pane = setmetatable({ visibility = state, resolved = resolved, mods = {},
            createModEntries = function() end, RebuildModEntries = function() end }, LeftPane)
        local widgets = {}
        pane:RenderModListItems(FakeContainer(widgets), resolved.main, "Main", false, {})
        widgets[1].OnDragDrop(widgets[1], { UserData = { kind = "mod", id = MOD_A, group = "Main" } })
        local after = state:Resolve(mods)
        D.expect(after.main[1].id).toBe(ModuleUUID)
        D.expect(after.main[2].id).toBe(MOD_A)
        D.expect(after.main[2].pinned).toBe(true)
    end)

end)
