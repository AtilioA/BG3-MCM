D.describe("Native keybinding ownership", { tags = { "native_keybinding_ownership", "client", "unit" } }, function()
    local NATIVE_CATEGORIES = {
        { CategoryName = "General", Actions = {
            { ActionId = "Jump", ActionName = "Jump", Description = "", Bindings = { { InputType = "Keyboard", InputId = "Q" } } },
            { ActionId = "Crouch", ActionName = "Crouch", Description = "", Bindings = {} },
        } },
        { CategoryName = "Camera", Actions = {
            { ActionId = "Pan", ActionName = "Pan", Description = "", Bindings = { { InputType = "Keyboard", InputId = "W" } } },
        } },
    }

    --- Fake IMGUI tree: destroying a node retires its subtree, and any access to a retired node throws as the BG3SE proxy does
    ---@return table tree
    local function NewTree()
        local tree = { deadAccesses = 0, log = {}, failAdd = nil, failDestroyKind = nil, onDestroy = nil }
        local states = {}

        local function deadAccess()
            tree.deadAccesses = tree.deadAccesses + 1
            error("IMGUI object no longer exists", 0)
        end

        local function retire(state)
            state.alive = false
            for _, child in ipairs(state.children) do retire(child) end
        end

        local function newNode(parentState, kind, label)
            local state = { alive = true, kind = kind, label = label, children = {}, fields = {}, parent = parentState }
            local node = {}
            local methods = {}

            function methods.Destroy()
                if tree.failDestroyKind == kind then
                    tree.failDestroyKind = nil
                    error("destroy failed", 0)
                end
                table.insert(tree.log, "destroy:" .. kind)
                if tree.onDestroy then tree.onDestroy(kind) end
                if state.parent then
                    for index, sibling in ipairs(state.parent.children) do
                        if sibling == state then
                            table.remove(state.parent.children, index)
                            break
                        end
                    end
                end
                retire(state)
            end

            function methods.SetColor() end

            setmetatable(node, {
                __index = function(_, key)
                    if not state.alive then deadAccess() end
                    if methods[key] then return methods[key] end
                    local addedKind = type(key) == "string" and key:match("^Add(.+)$")
                    if not addedKind then return state.fields[key] end
                    return function(_, childLabel)
                        local fail = tree.failAdd
                        if fail and fail.parentKind == kind and fail.kind == addedKind then
                            tree.failAdd = nil
                            error("add failed", 0)
                        end
                        local child, childState = newNode(state, addedKind, childLabel)
                        table.insert(state.children, childState)
                        return child
                    end
                end,
                __newindex = function(_, key, value)
                    if not state.alive then deadAccess() end
                    state.fields[key] = value
                end,
            })
            states[node] = state
            return node, state
        end

        function tree.Root()
            local root = newNode(nil, "Root", "Root")
            return root
        end

        --- Lists the live direct children as "Kind", or "Text:label" for text
        function tree.Children(node)
            local result = {}
            for _, child in ipairs(states[node].children) do
                table.insert(result, child.kind == "Text" and ("Text:" .. tostring(child.label)) or child.kind)
            end
            return result
        end

        --- Counts live descendants of one kind
        function tree.Count(node, kind)
            local function count(state)
                local total = 0
                for _, child in ipairs(state.children) do
                    total = total + (child.kind == kind and 1 or 0) + count(child)
                end
                return total
            end
            return count(states[node])
        end

        return tree
    end

    local searchBarBefore, mcmWidgetBefore, nativeWidgetBefore
    D.beforeEach(function()
        searchBarBefore = KeybindingsUI.SearchBar
        mcmWidgetBefore = KeybindingsUI.KeybindingWidget
        nativeWidgetBefore = KeybindingsUI.NativeKeybindingWidget
        KeybindingsUI.KeybindingWidget = nil
        KeybindingsUI.NativeKeybindingWidget = nil
    end)
    D.afterEach(function()
        KeybindingsUI.SearchBar = searchBarBefore
        KeybindingsUI.KeybindingWidget = mcmWidgetBefore
        KeybindingsUI.NativeKeybindingWidget = nativeWidgetBefore
    end)

    --- Builds one isolated native page on a fake tree with a real search bar
    ---@param ctx table DribbleSpec test context
    ---@return table page
    local function NewPage(ctx)
        local tree = NewTree()
        local page = { tree = tree, categories = NATIVE_CATEGORIES }
        ctx.stub(KeybindingsUI, "GetNativeKeybindings", function() return page.categories end)
        ctx.stub(NativeKeybindingsTranslator, "GetCategoryString", function(name) return name end)
        ctx.stub(NativeKeybindingsTranslator, "GetEventString", function(name) return name end)
        ctx.stub(VCString, "InterpolateLocalizedMessage", function(_, _, text) return "No match: " .. text end)
        page.root = tree.Root()
        page.group = page.root:AddGroup("Native Keybindings")
        page.searchBar = KeybindingSearchBar:new()
        KeybindingsUI.SearchBar = page.searchBar
        page.widget = NativeKeybindingIMGUIWidget:new(page.group)
        return page
    end

    --- Drives the production page owner on a fake tree; only the MCM widget and the dual pane are doubles
    ---@param ctx table DribbleSpec test context
    ---@return table owner
    local function NewOwner(ctx)
        local tree = NewTree()
        local root = tree.Root()
        local owner = { tree = tree, mcmDestroyError = nil }
        ctx.stub(KeybindingsUI, "GetNativeKeybindings", function() return NATIVE_CATEGORIES end)
        ctx.stub(NativeKeybindingsTranslator, "GetCategoryString", function(name) return name end)
        ctx.stub(NativeKeybindingsTranslator, "GetEventString", function(name) return name end)
        ctx.stub(KeybindingSearchBar, "Render", function() end)
        ctx.stub(KeybindingV2IMGUIWidget, "new", function()
            return { Destroy = function()
                if owner.mcmDestroyError then error(owner.mcmDestroyError, 0) end
            end }
        end)
        local dualPane = { AddMenuSectionWithContent = function() return root:AddGroup("Hotkeys") end }
        --- Builds one page and returns its hotkeys group and search subject
        function owner.Build()
            ---@diagnostic disable-next-line: param-type-mismatch
            local hotkeys = KeybindingsUI.CreateKeybindingsPage(dualPane)
            return hotkeys, KeybindingsUI.SearchBar.SearchSubject
        end
        return owner
    end

    D.test("retires the previous native widget when the page is rebuilt", function(ctx)
        ctx.requireClient()
        local owner = NewOwner(ctx)
        local oldHotkeys, oldSubject = owner.Build()
        local oldWidget = KeybindingsUI.NativeKeybindingWidget
        D.expect(#oldSubject.observers).toBe(1)

        local newHotkeys, newSubject = owner.Build()

        D.expect(#oldSubject.observers).toBe(0)
        D.expect(KeybindingsUI.NativeKeybindingWidget == oldWidget).toBe(false)
        -- The old page keeps its search and MCM groups; only the native group is retired.
        D.expect(#owner.tree.Children(oldHotkeys)).toBe(2)
        D.expect(#owner.tree.Children(newHotkeys)).toBe(3)

        local rowsBefore = owner.tree.Count(newHotkeys, "Row")
        oldSubject:OnNext("zzzz")
        D.expect(owner.tree.Count(newHotkeys, "Row")).toBe(rowsBefore)
        newSubject:OnNext("Jump")
        D.expect(owner.tree.Count(newHotkeys, "Row")).toBe(1)
        D.expect(owner.tree.deadAccesses).toBe(0)
    end)

    D.test("builds the next page when the old native group cannot be destroyed", function(ctx)
        ctx.requireClient()
        local owner = NewOwner(ctx)
        local _, oldSubject = owner.Build()
        owner.tree.failDestroyKind = "Group"

        local newHotkeys = owner.Build()

        D.expect(owner.tree.failDestroyKind).toBe(nil)
        D.expect(#oldSubject.observers).toBe(0)
        D.expect(owner.tree.Count(newHotkeys, "Row")).toBe(3)
    end)

    D.test("still owns a native widget whose first render failed", function(ctx)
        ctx.requireClient()
        local owner = NewOwner(ctx)
        owner.tree.failAdd = { parentKind = "CollapsingHeader", kind = "Text" }
        -- Expects the injected error to reach the caller, as MCMRendering's xpcall receives it.
        local ok, err = pcall(owner.Build)
        D.expect(ok).toBe(false)
        D.expect(err).toBe("add failed")
        local failedSubject = KeybindingsUI.SearchBar.SearchSubject
        D.expect(#failedSubject.observers).toBe(1)

        local newHotkeys = owner.Build()

        D.expect(#failedSubject.observers).toBe(0)
        D.expect(owner.tree.Count(newHotkeys, "Row")).toBe(3)
    end)

    D.test("keeps the current native widget when MCM widget retirement fails", function(ctx)
        ctx.requireClient()
        local owner = NewOwner(ctx)
        local _, subject = owner.Build()
        local widget = KeybindingsUI.NativeKeybindingWidget
        owner.mcmDestroyError = "mcm destroy failed"

        -- Expects the injected error to reach the caller, as MCMRendering's xpcall receives it.
        local ok, err = pcall(owner.Build)
        D.expect(ok).toBe(false)
        D.expect(err).toBe("mcm destroy failed")
        D.expect(KeybindingsUI.NativeKeybindingWidget == widget).toBe(true)
        D.expect(#subject.observers).toBe(1)

        owner.mcmDestroyError = nil
        owner.Build()
        D.expect(#subject.observers).toBe(0)
    end)

    D.test("continues a refresh when the root header cannot be destroyed", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.widget:RefreshUI()
        page.tree.failDestroyKind = "CollapsingHeader"

        page.widget:RefreshUI()

        D.expect(page.tree.failDestroyKind).toBe(nil)
        D.expect(page.tree.Children(page.group)).toEqual({ "CollapsingHeader", "CollapsingHeader" })
        D.expect(#page.widget.Widget.DynamicElements.ModHeaders).toBe(1)
    end)

    D.test("continues a refresh when the no-results text cannot be destroyed", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.searchBar.SearchSubject:OnNext("zzzz")
        page.tree.failDestroyKind = "Text"

        page.searchBar.SearchSubject:OnNext("Jump")

        D.expect(page.tree.failDestroyKind).toBe(nil)
        D.expect(page.tree.Children(page.group)).toEqual({ "Text:No match: zzzz", "CollapsingHeader" })
        D.expect(page.widget.Widget.DynamicElements.NoResultsText).toBe(nil)
    end)

    D.test("replaces one root header per refresh without touching retired descendants", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        for _ = 1, 3 do page.widget:RefreshUI() end

        D.expect(page.tree.Children(page.group)).toEqual({ "CollapsingHeader" })
        D.expect(page.tree.Count(page.group, "CollapsingHeader")).toBe(3)
        D.expect(page.tree.Count(page.group, "Row")).toBe(3)
        D.expect(#page.widget.Widget.DynamicElements.ModHeaders).toBe(1)
        D.expect(page.tree.deadAccesses).toBe(0)
    end)

    D.test("moves between results and the empty search message", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        local subject = page.searchBar.SearchSubject
        page.widget:RefreshUI()

        subject:OnNext("zzzz")
        D.expect(page.tree.Children(page.group)).toEqual({ "Text:No match: zzzz" })

        subject:OnNext("zzzzz")
        D.expect(page.tree.Children(page.group)).toEqual({ "Text:No match: zzzzz" })

        subject:OnNext("Jump")
        D.expect(page.tree.Children(page.group)).toEqual({ "CollapsingHeader" })
        D.expect(page.tree.Count(page.group, "Row")).toBe(1)

        subject:OnNext("")
        D.expect(page.tree.Count(page.group, "Row")).toBe(3)
        D.expect(page.widget.Widget.DynamicElements.NoResultsText).toBe(nil)
        D.expect(page.tree.deadAccesses).toBe(0)
    end)

    D.test("retires the message when native keybindings appear", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.categories = {}
        page.widget:RefreshUI()
        D.expect(#page.tree.Children(page.group)).toBe(1)
        D.expect(page.tree.Count(page.group, "CollapsingHeader")).toBe(0)

        page.categories = NATIVE_CATEGORIES
        page.widget:RefreshUI()
        D.expect(page.tree.Children(page.group)).toEqual({ "CollapsingHeader" })
        D.expect(page.tree.deadAccesses).toBe(0)
    end)

    D.test("owns the root header when its render fails partway", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.tree.failAdd = { parentKind = "CollapsingHeader", kind = "Text" }
        -- Expects the injected "add failed" error to reach the caller.
        local ok, err = pcall(function() page.widget:RefreshUI() end)
        D.expect(ok).toBe(false)
        D.expect(err).toBe("add failed")

        page.widget:RefreshUI()
        D.expect(page.tree.Children(page.group)).toEqual({ "CollapsingHeader" })
    end)

    D.test("disposes search before its group is destroyed", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        local subject = page.searchBar.SearchSubject
        page.widget:RefreshUI()
        local observersAtGroupDestroy
        page.tree.onDestroy = function(kind)
            if kind == "Group" then observersAtGroupDestroy = #subject.observers end
        end

        page.widget:Destroy()
        D.expect(observersAtGroupDestroy).toBe(0)
        D.expect(page.tree.log).toEqual({ "destroy:CollapsingHeader", "destroy:Group" })
        page.root:Destroy()
        D.expect(page.tree.deadAccesses).toBe(0)
    end)

    D.test("ignores a queued search emission after retirement", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.widget:RefreshUI()
        -- Model delivery after retirement without replacing the engine scheduler.
        local subject = page.searchBar.SearchSubject
        local deliverSearch = function() subject:OnNext("Jump") end

        page.widget:Destroy()
        page.root:Destroy()
        deliverSearch()

        D.expect(#subject.observers).toBe(0)
        D.expect(page.tree.deadAccesses).toBe(0)
    end)

    D.test("ignores an emission already in flight when retired", function(ctx)
        ctx.requireClient()
        local tree = NewTree()
        ctx.stub(KeybindingsUI, "GetNativeKeybindings", function() return NATIVE_CATEGORIES end)
        ctx.stub(NativeKeybindingsTranslator, "GetCategoryString", function(name) return name end)
        ctx.stub(NativeKeybindingsTranslator, "GetEventString", function(name) return name end)
        local searchBar = KeybindingSearchBar:new()
        KeybindingsUI.SearchBar = searchBar
        local group = tree.Root():AddGroup("Native Keybindings")

        -- Subscribed first, as the MCM keybinding widget is; Rx snapshots observers before delivery.
        local widget
        local mcmSearches = {}
        searchBar.SearchSubject:Subscribe(function(text)
            table.insert(mcmSearches, text)
            if widget then
                widget:Destroy()
                widget = nil
            end
        end)
        widget = NativeKeybindingIMGUIWidget:new(group)
        widget:RefreshUI()

        searchBar.SearchSubject:OnNext("Jump")
        searchBar.SearchSubject:OnNext("Pan")

        D.expect(mcmSearches).toEqual({ "Jump", "Pan" })
        D.expect(tree.deadAccesses).toBe(0)
    end)

    D.test("keeps a reopened page independent of the retired page", function(ctx)
        ctx.requireClient()
        local oldPage = NewPage(ctx)
        oldPage.widget:RefreshUI()
        local oldSubject = oldPage.searchBar.SearchSubject
        oldPage.widget:Destroy()

        local newPage = NewPage(ctx)
        newPage.widget:RefreshUI()

        oldSubject:OnNext("zzzz")
        D.expect(newPage.tree.Children(newPage.group)).toEqual({ "CollapsingHeader" })
        D.expect(newPage.tree.Count(newPage.group, "Row")).toBe(3)

        newPage.searchBar.SearchSubject:OnNext("zzzz")
        D.expect(newPage.tree.Children(newPage.group)).toEqual({ "Text:No match: zzzz" })
        D.expect(oldPage.tree.deadAccesses + newPage.tree.deadAccesses).toBe(0)
    end)

    D.test("reports a refresh on an unretired page whose parent is gone", function(ctx)
        ctx.requireClient()
        local page = NewPage(ctx)
        page.widget:RefreshUI()
        page.root:Destroy()

        -- Expects the dead-handle error to reach the caller.
        local ok, err = pcall(function() page.searchBar.SearchSubject:OnNext("Jump") end)

        D.expect(ok).toBe(false)
        D.expect(err).toBe("IMGUI object no longer exists")
        D.expect(#page.widget.Widget.DynamicElements.ModHeaders).toBe(0)
    end)
end)
