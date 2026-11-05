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
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderMenu({ id = "f", name = "Folder", items = { { id = MOD_A } }, members = { MOD_A } }, false)
        D.expect(#popup.items).toBe(4)
        popup.items[2].OnClick()
        D.expect(store.values.UI.Folders.f).toBe(nil)
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe(false)
    end)

    D.test("hidden menu only offers sorting", function()
        local store = FakeStore({ UI = { Order = { Hidden = { MOD_A } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderMenu({ id = "Hidden", name = "Hidden" }, true)
        D.expect(#popup.items).toBe(1)
        popup.items[1].OnClick()
        D.expect(store.values.UI.Order.Hidden).toEqual({ MOD_A })
        popup.buttons[1].OnClick()
        D.expect(store.values.UI.Order.Hidden).toBe(nil)
    end)

    D.test("blank sidebar menu creates folders and confirms sorting only Main", function()
        local store = FakeStore({ UI = { Order = { Main = { MOD_B, MOD_A }, Hidden = { MOD_A } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, RebuildModEntries = function() end }, LeftPane)
        local opened = false
        pane.OpenFolderNamePopup = function(_, folder, mod)
            opened = folder == nil and mod == nil
        end
        pane:OpenFolderMenu({ id = "Main", name = "Main list" }, false)
        D.expect(#popup.items).toBe(3)
        popup.items[1].OnClick()
        D.expect(opened).toBe(true)
        popup.items[2].OnClick()
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_B, MOD_A })
        popup.buttons[1].OnClick()
        D.expect(store.values.UI.Order.Main).toBe(nil)
        D.expect(store.values.UI.Order.Hidden).toEqual({ MOD_A })
    end)

    D.test("blank sidebar folders-first action waits for confirmation", function()
        local store = FakeStore({ UI = { Folders = { f = { Name = "Folder" } },
            Order = { Main = { MOD_A, "f" } } } })
        local state = ModListState:New(store)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = state, mods = {}, resolved = state:Resolve({ { id = MOD_A, name = "A" } }),
            RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderMenu({ id = "Main", name = "Main list" }, false)
        popup.items[3].OnClick()
        D.expect(store.values.UI.Order.Main).toEqual({ MOD_A, "f" })
        popup.buttons[1].OnClick()
        D.expect(store.values.UI.Order.Main).toEqual({ "f", MOD_A })
    end)

    D.test("a refused menu save warns and keeps the list", function(ctx)
        local warnings = 0
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() warnings = warnings + 1 end)
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(FakeStore({}, true)), mods = {},
            RebuildModEntries = function() error("must not rebuild") end }, LeftPane)
        pane:OpenFolderMenu({ id = "f", name = "Folder", members = {} }, false)
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
        D.expect(store.values.UI.Folders["folder-1"].Name).toBe("New folder")
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("folder-1")
        D.expect(pane.expandedGroups["folder-1"]).toBe(true)
        D.expect(pane.expandedGroups.f).toBe(false)
    end)

    D.test("folder IDs skip historical references and names remove hash markers", function()
        local store = FakeStore({ UI = { Mods = { [MOD_B] = { Folder = "folder-1" } }, Order = { Main = { "folder-2" } } } })
        local popup = FakePopup()
        local pane = setmetatable({ parent = { AddPopup = function() return popup end },
            visibility = ModListState:New(store), mods = {}, resolved = { main = {} }, expandedGroups = {},
            RebuildModEntries = function() end }, LeftPane)
        pane:OpenFolderNamePopup(nil, MOD_A)
        popup.input.Text = "Tools##x"
        popup.input.OnChange()
        D.expect(store.values.UI.Folders["folder-3"].Name).toBe("Toolsx")
        D.expect(store.values.UI.Mods[MOD_A].Folder).toBe("folder-3")
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

    D.test("sidebar hides the main drop row until a drag and keeps folder labels unique", function(ctx)
        local widgets = {}
        local group = FakeContainer(widgets)
        ctx.stub(IMGUIHelpers, "DestroyChildren", function() end)
        local store = FakeStore({ UI = { Folders = { f = { Name = "Tools##x" } } } })
        local pane = setmetatable({ parent = {}, modEntriesGroup = group, expandedGroups = {},
            visibility = ModListState:New(store), createModEntries = function() end }, LeftPane)
        pane:RebuildModEntries({})
        D.expect(widgets[1].Label).toBe("Toolsx##folder_f")
        D.expect(widgets[2].Visible).toBe(false)
        D.expect(group.DragDropType).toBe(nil)
        local target = pane.mainDropTargets.f
        D.expect(widgets[4]).toBe(target)
        D.expect(target.UserData.id).toBe("Main")
        D.expect(target.CanDrag).toBe(false)
        D.expect(target.Visible).toBe(false)
        D.expect(target.OnDragDrop ~= nil).toBe(true)
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
            menuScrollChildWindow = { SetStyle = function() end },
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

    D.test("leaving the sidebar releases a menu hold and schedules collapse", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function() return true end)
        local leave, scheduled
        local controller = setmetatable({ isHovered = true, windowOpacity = 1,
            sidebarHolds = { menu = true },
            menuScrollChildWindow = { Visible = true, SetStyle = function() end },
            rightPane = { IsCurrentModDetached = function() return false end },
            setupHoverHandlers = function(_, _, _, onLeave) leave = onLeave end,
            ScheduleAutoCollapse = function() scheduled = true end,
            FadeSidebarOutAlpha = function() end }, { __index = DualPaneController })
        controller:AttachHoverListeners()
        leave()
        D.expect(controller.sidebarHolds.menu).toBe(nil)
        D.expect(scheduled).toBe(true)
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
        popup.input.Text = "Tools"
        popup.buttons[1].OnClick()
        D.expect(pane.namePopup).toBe(popup)
        D.expect(popup.input.Text).toBe("Tools")
        D.expect(popup.texts[#popup.texts].Label ~= "").toBe(true)
    end)

end)
