D.describe("ListV2 widget ownership", { tags = { "listv2_ownership", "client", "unit" } }, function()
    local MOD_UUID = "00000000-0000-0000-0000-00000000F201"
    local SETTING_ID = "listv2-ownership-fixture"
    local DEAD_HANDLE = "IMGUI object no longer exists"

    --- Fake IMGUI tree: destroying a node retires its subtree, and any access to a retired node throws as the BG3SE proxy does
    ---@return table tree
    ---@return table root
    local function NewTree()
        local tree = { deadAccesses = 0, destroyed = {}, failAdd = nil, states = {} }

        local function retire(state)
            state.alive = false
            for _, child in ipairs(state.children) do retire(child) end
        end

        local function newNode(parentState, kind, label, text)
            local state = {
                alive = true,
                kind = kind,
                parent = parentState,
                children = {},
                fields = { Label = label, Text = text },
            }
            if kind == "ImageButton" then state.fields.Image = { Icon = "fixture_icon" } end
            table.insert(tree.states, state)

            local node = {}
            state.node = node
            local methods = {
                SetColor = function() end,
                SetStyle = function() end,
                GetStyle = function() end,
                Open = function() end,
                Tooltip = function() return node end,
                RemoveAllChildren = function()
                    for _, child in ipairs(state.children) do retire(child) end
                    state.children = {}
                end,
                Destroy = function()
                    table.insert(tree.destroyed, kind)
                    if state.parent then
                        for index, sibling in ipairs(state.parent.children) do
                            if sibling == state then
                                table.remove(state.parent.children, index)
                                break
                            end
                        end
                    end
                    retire(state)
                end,
            }

            setmetatable(node, {
                __index = function(_, key)
                    if not state.alive then
                        tree.deadAccesses = tree.deadAccesses + 1
                        error(DEAD_HANDLE, 0)
                    end
                    if key == "Children" then
                        local children = {}
                        for _, child in ipairs(state.children) do table.insert(children, child.node) end
                        return children
                    end
                    if methods[key] then return methods[key] end
                    local addedKind = type(key) == "string" and key:match("^Add(.+)$")
                    if not addedKind then return state.fields[key] end
                    return function(_, childLabel, childText)
                        local fail = tree.failAdd
                        if fail and fail.parentKind == kind and fail.kind == addedKind then
                            fail.count = (fail.count or 1) - 1
                            if fail.count <= 0 then tree.failAdd = nil end
                            error("add failed", 0)
                        end
                        local child, childState = newNode(state, addedKind, childLabel, childText)
                        table.insert(state.children, childState)
                        return child
                    end
                end,
                __newindex = function(_, key, value)
                    if not state.alive then
                        tree.deadAccesses = tree.deadAccesses + 1
                        error(DEAD_HANDLE, 0)
                    end
                    state.fields[key] = value
                end,
            })
            return node, state
        end

        local root = newNode(nil, "Root", "root")

        --- Live nodes of a kind, or whose IDContext contains the given text
        function tree:Live(pattern, kind)
            local found = {}
            for _, state in ipairs(self.states) do
                local id = state.alive and state.fields.IDContext
                if state.alive and (kind == nil or state.kind == kind)
                    and (pattern == nil or (id and id:find(pattern, 1, true))) then
                    table.insert(found, state.node)
                end
            end
            return found
        end

        return tree, root
    end

    ---@param ctx table
    ---@param value? any Initial setting value
    ---@param options? table Blueprint options
    ---@return any fixture
    local function Mount(ctx, value, options)
        ---@type any
        local fx = { writes = {}, resets = {}, logs = {}, onWrite = nil, onReset = nil, order = {} }
        fx.tree, fx.root = NewTree()
        ---@type any
        local setting = {
            Id = SETTING_ID,
            GetId = function() return SETTING_ID end,
            GetOptions = function() return options or { Suggestions = { "abc", "abd" } } end,
            GetDefault = function() return { enabled = true, elements = { { name = "default", enabled = true } } } end,
        }

        ctx.stub(IMGUIHelpers, "AddTooltip", function() end)
        ctx.stub(IMGUIWidget, "GetIconSizes", function() return { 32, 32 } end)
        ctx.stub(Mods.BG3MCM, "MCMDebug", function(_, format, ...)
            table.insert(fx.logs, string.format(format, ...))
        end)
        ctx.stub(IMGUIAPI, "SetSettingValue", function(_, settingId, settingValue, modUUID)
            table.insert(fx.order, "write")
            table.insert(fx.writes, {
                settingId = settingId,
                modUUID = modUUID,
                enabled = settingValue.enabled,
                names = fx.Names(settingValue.elements),
            })
            if fx.onWrite then fx.onWrite() end
            return { accepted = true, state = "queued", value = settingValue }
        end)
        ctx.stub(IMGUIAPI, "ResetSettingValue", function(_, settingId, modUUID)
            table.insert(fx.order, "reset")
            table.insert(fx.resets, { settingId = settingId, modUUID = modUUID })
            if fx.onReset then fx.onReset() end
        end)

        function fx.Names(elements)
            local names = {}
            ---@type any
            local widgetState = fx.widget.Widget
            for _, element in ipairs(elements or widgetState.Elements) do table.insert(names, element.name) end
            return names
        end

        fx.widget = ListV2IMGUIWidget:new(fx.root, setting, value, MOD_UUID)
        fx.widget:AddResetButton(fx.root, setting, MOD_UUID)

        function fx.One(pattern, kind)
            local found = fx.tree:Live(pattern, kind)
            D.expect(#found).toBe(1)
            return found[1]
        end

        function fx.Click(pattern)
            local node = fx.One(pattern)
            node.OnClick(node)
        end

        function fx.Type(text)
            local input = fx.One("_AddElementInput_")
            input.Text = text
            input.OnChange(input)
        end

        return fx
    end

    ---@return string[] shown Names of live table rows
    local function ShownNames(fx)
        local shown = {}
        for _, node in ipairs(fx.tree:Live("_ElementName_")) do table.insert(shown, node.Label) end
        return shown
    end

    D.describe("add input", function()
        D.test("shows the typed text in the one rebuilt input after an unrelated refresh", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.widget:Refresh()

            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
            D.expect(fx.tree.deadAccesses).toBe(0)
            D.expect(fx.logs).toEqual({})
        end)

        D.test("types again after a refresh through the rebuilt input", function(ctx)
            local fx = Mount(ctx)
            fx.Type("zz")
            fx.widget:Refresh()
            fx.Type("ab")

            D.expect(#fx.tree:Live("_AddSearchResult_")).toBe(2)
        end)

        D.test("clears the typed text and suggestions after a typed add", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.Type("ab")
            D.expect(#fx.tree:Live("_SearchResultsHeader_")).toBe(1)
            fx.Click("_AddElementButton_")

            D.expect(fx.writes).toEqual({
                { settingId = SETTING_ID, modUUID = MOD_UUID, enabled = true, names = { "ab", "old" } },
            })
            D.expect(fx.One("_AddElementInput_").Text).toBe("")
            D.expect(#fx.tree:Live("_SearchResultsHeader_")).toBe(0)
            D.expect(ShownNames(fx)).toEqual({ "ab", "old" })
            D.expect(fx.logs).toEqual({})
        end)

        D.test("trims the typed name before it writes", function(ctx)
            local fx = Mount(ctx)
            fx.Type("  ab ")
            fx.Click("_AddElementButton_")

            D.expect(fx.Names()).toEqual({ "ab" })
        end)

        D.test("keeps the typed text and writes nothing for empty and duplicate names", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.Type("   ")
            fx.Click("_AddElementButton_")
            D.expect(fx.One("_AddElementInput_").Text).toBe("   ")

            fx.Type("old")
            fx.Click("_AddElementButton_")
            D.expect(fx.One("_AddElementInput_").Text).toBe("old")
            D.expect(fx.writes).toEqual({})
        end)

        D.test("keeps the typed text and remaining suggestions after a suggestion add", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.Click("_AddSearchResult_" .. SETTING_ID .. "_abc")

            D.expect(fx.Names()).toEqual({ "abc" })
            D.expect(#fx.writes).toBe(1)
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
            D.expect(#fx.tree:Live("_AddSearchResult_" .. SETTING_ID .. "_abc")).toBe(0)
            D.expect(#fx.tree:Live("_AddSearchResult_" .. SETTING_ID .. "_abd")).toBe(1)
        end)

        D.test("disables a stale suggestion that became a duplicate", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            local button = fx.One("_AddSearchResult_" .. SETTING_ID .. "_abc")
            table.insert(fx.widget.Widget.Elements, { name = "abc", enabled = true })
            button.OnClick(button)

            D.expect(button.Disabled).toBe(true)
            D.expect(#fx.writes).toBe(0)
        end)

        D.test("follows the disabled state across rebuilds and keeps the text", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.widget:UpdateCurrentValue({ enabled = false, elements = {} })

            local disabledInput = fx.One("_AddElementInput_")
            D.expect(disabledInput.ReadOnly).toBe(true)
            D.expect(disabledInput.Text).toBe("ab")
            D.expect(fx.One("_AddElementButton_").Disabled).toBe(true)

            fx.widget:UpdateCurrentValue({ enabled = true, elements = {} })
            D.expect(fx.One("_AddElementInput_").ReadOnly).toBe(nil)
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
        end)

        D.test("does not render the input for a read-only list", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } },
            { ReadOnly = true })
            fx.widget:Refresh()

            D.expect(#fx.tree:Live("_AddElementInput_")).toBe(0)
            D.expect(ShownNames(fx)).toEqual({ "old" })
        end)
    end)

    D.describe("add failure recovery", function()
        D.test("contains and logs a failed save, keeping the mutation and the typed text", function(ctx)
            local fx = Mount(ctx)
            fx.onWrite = function() error("save failed", 0) end
            fx.Type("ab")
            local input = fx.One("_AddElementInput_")
            fx.Click("_AddElementButton_")

            D.expect(fx.logs).toEqual({ "Error adding new element: save failed" })
            D.expect(fx.Names()).toEqual({ "ab" })
            D.expect(input.Text).toBe("ab")
            D.expect(fx.widget.Widget.NewElementName).toBe("ab")
            D.expect(ShownNames(fx)).toEqual({})
        end)

        D.test("contains and logs a failed rebuild after a save, with one write", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.tree.failAdd = { parentKind = "Group", kind = "Table" }
            fx.Click("_AddElementButton_")

            D.expect(fx.logs).toEqual({ "Error adding new element: add failed" })
            D.expect(#fx.writes).toBe(1)
            D.expect(fx.widget.Widget.NewElementName).toBe("ab")
            D.expect(fx.widget.Widget.NewElementInput).toBe(nil)
            D.expect(fx.widget.Widget.SearchResultsGroup).toBe(nil)

            fx.widget:Refresh()
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
            D.expect(ShownNames(fx)).toEqual({ "ab" })
        end)

        D.test("keeps the typed text visible when the rebuild fails after the input", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.tree.failAdd = { parentKind = "Group", kind = "ImageButton" }
            fx.Click("_AddElementButton_")

            D.expect(fx.logs).toEqual({ "Error adding new element: add failed" })
            D.expect(fx.widget.Widget.NewElementName).toBe("ab")
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
        end)

        D.test("survives an authoritative value delivered during the save", function(ctx)
            local fx = Mount(ctx)
            fx.onWrite = function()
                fx.onWrite = nil
                fx.widget:UpdateCurrentValue({ enabled = true, elements = { { name = "ab", enabled = true } } })
            end
            fx.Type("ab")
            fx.Click("_AddElementButton_")

            D.expect(fx.One("_AddElementInput_").Text).toBe("")
            D.expect(ShownNames(fx)).toEqual({ "ab" })
            D.expect(fx.tree.deadAccesses).toBe(0)
            D.expect(fx.logs).toEqual({})
        end)

        D.test("lets a later authoritative value replace a queued add", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.Click("_AddElementButton_")
            D.expect(ShownNames(fx)).toEqual({ "ab" })

            fx.Type("next")
            fx.widget:UpdateCurrentValue({ enabled = true, elements = { { name = "server", enabled = true } } })

            D.expect(ShownNames(fx)).toEqual({ "server" })
            D.expect(fx.One("_AddElementInput_").Text).toBe("next")
        end)
    end)

    D.describe("input construction recovery", function()
        D.test("logs a failed input and retries it with the typed text", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.tree.failAdd = { parentKind = "Group", kind = "InputText" }
            fx.widget:Refresh()

            D.expect(fx.logs).toEqual({ "Error in adding new element input: add failed" })
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
            D.expect(#fx.tree:Live("_AddElementButton_")).toBe(1)
            fx.Type("abd")
            D.expect(#fx.tree:Live("_AddSearchResult_")).toBe(1)
        end)

        D.test("logs a failed style, retries it and keeps a working input", function(ctx)
            local fx = Mount(ctx)
            local failures = 1
            ctx.stub(IMGUIHelpers, "ApplyInputStyle", function()
                if failures > 0 then
                    failures = failures - 1
                    error("style failed", 0)
                end
            end)
            fx.Type("ab")
            fx.widget:Refresh()

            D.expect(fx.logs).toEqual({ "Error in adding new element input: style failed" })
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
            fx.Type("abd")
            D.expect(#fx.tree:Live("_AddSearchResult_")).toBe(1)
        end)

        D.test("logs the first failure and throws the second from a refresh", function(ctx)
            local fx = Mount(ctx)
            ctx.stub(IMGUIHelpers, "ApplyInputStyle", function() error("style failed", 0) end)
            -- Expects the injected "style failed"
            local ok, err = pcall(function() fx.widget:Refresh() end)

            D.expect(ok).toBe(false)
            D.expect(err).toBe("style failed")
            D.expect(fx.logs).toEqual({ "Error in adding new element input: style failed" })
        end)

        D.test("keeps the typed text when both input creations fail during a typed add", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            fx.tree.failAdd = { parentKind = "Group", kind = "InputText", count = 2 }
            fx.Click("_AddElementButton_")

            D.expect(fx.logs).toEqual({
                "Error in adding new element input: add failed",
                "Error adding new element: add failed",
            })
            D.expect(#fx.writes).toBe(1)
            D.expect(fx.widget.Widget.NewElementName).toBe("ab")
            D.expect(fx.widget.Widget.NewElementInput).toBe(nil)

            fx.widget:Refresh()
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
        end)

        D.test("keeps the typed text when both input styles fail during a typed add", function(ctx)
            local fx = Mount(ctx)
            fx.Type("ab")
            local failures = 2
            ctx.stub(IMGUIHelpers, "ApplyInputStyle", function(_, element)
                -- Row checkboxes render first and use this helper too
                if element == fx.widget.Widget.NewElementInput and failures > 0 then
                    failures = failures - 1
                    error("style failed", 0)
                end
            end)
            fx.Click("_AddElementButton_")

            D.expect(fx.logs).toEqual({
                "Error in adding new element input: style failed",
                "Error adding new element: style failed",
            })
            D.expect(#fx.writes).toBe(1)
            D.expect(fx.widget.Widget.NewElementName).toBe("ab")
            D.expect(fx.widget.Widget.NewElementInput.Text).toBe("ab")

            fx.widget:Refresh()
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
        end)

        D.test("does not log a normal refresh", function(ctx)
            local fx = Mount(ctx)
            fx.widget:Refresh()

            D.expect(fx.logs).toEqual({})
        end)
    end)

    local POPUPS = {
        {
            name = "delete all",
            field = "ConfirmationPopup",
            open = "DeleteAllButton_",
            confirm = "_ConfirmDeleteAll_",
            cancel = "_CancelDeleteAll_",
            commits = function(fx) return #fx.writes end,
        },
        {
            name = "reset",
            field = "ResetConfirmationPopup",
            open = "ResetButton_",
            confirm = "_ConfirmReset_",
            cancel = "_CancelReset_",
            commits = function(fx) return #fx.resets end,
        },
    }

    for _, popup in ipairs(POPUPS) do
        D.describe(popup.name .. " popup", function()
            local INITIAL = { enabled = true, elements = { { name = "old", enabled = true } } }

            D.test("confirm commits once, retires the popup and reopens cleanly", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.Click(popup.open)
                fx.Click(popup.confirm)

                D.expect(popup.commits(fx)).toBe(1)
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(0)

                fx.Click(popup.open)
                D.expect(fx.widget.Widget[popup.field]).toBe(fx.One(nil, "Popup"))
            end)

            D.test("cancel commits nothing and reopens cleanly", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.Click(popup.open)
                fx.Click(popup.cancel)

                D.expect(popup.commits(fx)).toBe(0)
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(0)

                fx.Click(popup.open)
                D.expect(fx.widget.Widget[popup.field]).toBe(fx.One(nil, "Popup"))
            end)

            D.test("reopening replaces a dismissed popup", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.Click(popup.open)
                fx.Click(popup.open)

                D.expect(#fx.tree:Live(nil, "Popup")).toBe(1)
                D.expect(fx.tree.deadAccesses).toBe(0)
            end)

            D.test("stays open and usable across a refresh", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.Click(popup.open)
                fx.widget:UpdateCurrentValue({ enabled = true, elements = {} })
                fx.Click(popup.confirm)

                D.expect(popup.commits(fx)).toBe(1)
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(0)
            end)

            D.test("replaces a popup whose construction failed", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.tree.failAdd = { parentKind = "Popup", kind = "Button" }
                -- Expects the injected "add failed"
                D.expect(pcall(function() fx.Click(popup.open) end)).toBe(false)

                fx.Click(popup.open)
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(1)
                D.expect(fx.tree.deadAccesses).toBe(0)
            end)

            D.test("propagates a commit failure and keeps the popup open for a retry", function(ctx)
                local fx = Mount(ctx, INITIAL)
                local fail = function()
                    fx.onWrite, fx.onReset = nil, nil
                    error("commit failed", 0)
                end
                fx.onWrite, fx.onReset = fail, fail
                fx.Click(popup.open)
                -- Expects the injected "commit failed"
                local ok, err = pcall(function() fx.Click(popup.confirm) end)

                D.expect(ok).toBe(false)
                D.expect(err).toBe("commit failed")
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(1)

                fx.Click(popup.confirm)
                D.expect(popup.commits(fx)).toBe(2)
                D.expect(#fx.tree:Live(nil, "Popup")).toBe(0)
                D.expect(fx.tree.deadAccesses).toBe(0)
            end)

            D.test("reopens after another owner destroyed the popup", function(ctx)
                local fx = Mount(ctx, INITIAL)
                fx.Click(popup.open)
                fx.widget.Widget[popup.field]:Destroy()

                fx.Click(popup.open)

                D.expect(#fx.tree:Live(nil, "Popup")).toBe(1)
                D.expect(fx.widget.Widget[popup.field]).toBe(fx.One(nil, "Popup"))
            end)
        end)
    end

    D.describe("popup commit content", function()
        D.test("delete all writes the empty list and rebuilds", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.Type("ab")
            fx.Click("DeleteAllButton_")
            fx.Click("_ConfirmDeleteAll_")

            D.expect(fx.writes).toEqual({ { settingId = SETTING_ID, modUUID = MOD_UUID, enabled = true, names = {} } })
            D.expect(ShownNames(fx)).toEqual({})
            D.expect(fx.One("_AddElementInput_").Text).toBe("ab")
        end)

        D.test("a failed delete rebuild keeps the popup, as its destroy is the last step", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.Click("DeleteAllButton_")
            fx.tree.failAdd = { parentKind = "Group", kind = "Table" }
            -- Expects the injected "add failed"
            D.expect(pcall(function() fx.Click("_ConfirmDeleteAll_") end)).toBe(false)

            D.expect(#fx.writes).toBe(1)
            D.expect(#fx.tree:Live(nil, "Popup")).toBe(1)
        end)

        D.test("a failed reset rebuild after the update closes the popup, as it closes before the rebuild", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            local update = fx.widget.UpdateCurrentValue
            fx.widget.UpdateCurrentValue = function(self, value)
                update(self, value)
                fx.tree.failAdd = { parentKind = "Group", kind = "Table" }
            end
            fx.Click("ResetButton_")
            -- Expects the injected "add failed"
            D.expect(pcall(function() fx.Click("_ConfirmReset_") end)).toBe(false)

            D.expect(#fx.resets).toBe(1)
            D.expect(#fx.tree:Live(nil, "Popup")).toBe(0)
        end)

        D.test("reset asks for the reset first, then shows defaults through the instance update", function(ctx)
            local fx = Mount(ctx, { enabled = false, elements = { { name = "old", enabled = true } } })
            local update = fx.widget.UpdateCurrentValue
            fx.widget.UpdateCurrentValue = function(self, value)
                table.insert(fx.order, "update:" .. fx.Names(value.elements)[1])
                update(self, value)
            end
            fx.Click("ResetButton_")
            fx.Click("_ConfirmReset_")

            D.expect(fx.order).toEqual({ "reset", "update:default" })
            D.expect(fx.resets).toEqual({ { settingId = SETTING_ID, modUUID = MOD_UUID } })
            D.expect(#fx.writes).toBe(0)
            D.expect(fx.widget.Widget.Enabled).toBe(true)
            D.expect(ShownNames(fx)).toEqual({ "default" })
        end)

        D.test("reset keeps a later authoritative value and a popup opened before it arrives", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.Click("ResetButton_")
            fx.Click("_ConfirmReset_")
            fx.Click("ResetButton_")
            local reopened = fx.widget.Widget.ResetConfirmationPopup

            fx.widget:UpdateCurrentValue({ enabled = true, elements = { { name = "server", enabled = true } } })

            D.expect(ShownNames(fx)).toEqual({ "server" })
            D.expect(fx.widget.Widget.ResetConfirmationPopup).toBe(reopened)
            D.expect(fx.One(nil, "Popup")).toBe(reopened)
        end)

        D.test("reset applies a value delivered during the reset, then the defaults", function(ctx)
            local fx = Mount(ctx, { enabled = true, elements = { { name = "old", enabled = true } } })
            fx.onReset = function()
                fx.widget:UpdateCurrentValue({ enabled = true, elements = { { name = "local", enabled = true } } })
                D.expect(ShownNames(fx)).toEqual({ "local" })
            end
            fx.Click("ResetButton_")
            fx.Click("_ConfirmReset_")

            D.expect(ShownNames(fx)).toEqual({ "default" })
            D.expect(fx.tree.deadAccesses).toBe(0)
        end)
    end)
end)
