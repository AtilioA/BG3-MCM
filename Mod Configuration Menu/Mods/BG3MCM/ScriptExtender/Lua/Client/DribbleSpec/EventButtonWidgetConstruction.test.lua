D.describe("Event button construction", { tags = { "event_button_construction", "client", "unit" } }, function()
    local MOD_UUID = "00000000-0000-0000-0000-00000000E001"
    local LABEL = "Run action"

    --- Records live buttons, so a test sees what remains after cleanup
    ---@param behavior? table addImageThrows, imageReadThrows, destroyThrows, or imageData (the button's Image field)
    ---@return table container
    local function FakeContainer(behavior)
        behavior = behavior or {}
        local container = { buttons = {}, groups = {}, imageCalls = {}, destroyCalls = 0 }

        local function track(button)
            function button.Destroy(self)
                container.destroyCalls = container.destroyCalls + 1
                if behavior.destroyThrows then error("destroy failed") end
                for index, live in ipairs(container.buttons) do
                    if live == self then table.remove(container.buttons, index) end
                end
            end

            table.insert(container.buttons, button)
            return button
        end

        function container:AddButton(label)
            return track({ Kind = "text", Label = label })
        end

        function container:AddImageButton(label, icon, size)
            table.insert(self.imageCalls, { label = label, icon = icon, size = size })
            if behavior.addImageThrows then error("Param 4: expected 2-element array") end

            local button = track({ Kind = "image", Label = label })
            if behavior.imageReadThrows then
                return setmetatable(button, {
                    __index = function(_, key)
                        if key == "Image" then error("IMGUI object no longer exists") end
                    end,
                })
            end

            button.Image = behavior.imageData
            return button
        end

        function container:AddGroup(name)
            local group = { Name = name }
            table.insert(self.groups, group)
            return group
        end

        return container
    end

    ---@param options table
    ---@return table setting
    local function FakeSetting(options)
        return {
            GetOptions = function() return options end,
            GetHandles = function() return {} end,
            GetLocaName = function() return "Setting name" end,
            GetId = function() return "event-button-fixture" end,
        }
    end

    ---@param container table
    ---@param options table
    ---@return table widget
    local function FakeWidget(container, options)
        return setmetatable({
            Widget = { Group = container, Setting = FakeSetting(options), ModUUID = MOD_UUID },
        }, { __index = EventButtonIMGUIWidget })
    end

    --- Silences and counts icon warnings
    ---@return table warnings Formatted messages
    local function CaptureWarnings(ctx)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, format, ...)
            table.insert(warnings, string.format(format, ...))
        end)
        return warnings
    end

    local function IconOptions(size)
        return { Label = LABEL, Icon = { Name = "fixture_icon", Size = size } }
    end

    D.beforeEach(function(ctx)
        ctx.stub(IMGUIWidget, "GetIconSizes", function(_, multiplier)
            return { 16 * multiplier, 16 * multiplier }
        end)
    end)

    D.test("uses a text button when no icon is configured", function()
        local container = FakeContainer()

        FakeWidget(container, { Label = LABEL }):CreateButton()

        D.expect(#container.imageCalls).toBe(0)
        D.expect(#container.buttons).toBe(1)
        D.expect(container.buttons[1].Kind).toBe("text")
        D.expect(container.buttons[1].Label).toBe(LABEL)
    end)

    D.test("keeps the image button of a bound icon at the default size", function()
        local container = FakeContainer({ imageData = { Icon = "fixture_icon" } })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button).toBe(container.buttons[1])
        D.expect(widget.Widget.Button.Kind).toBe("image")
        D.expect(container.imageCalls[1]).toEqual({ label = LABEL, icon = "fixture_icon", size = { 32, 32 } })
        D.expect(container.destroyCalls).toBe(0)
    end)

    D.test("passes the configured icon size", function()
        local container = FakeContainer({ imageData = { Icon = "fixture_icon" } })

        FakeWidget(container, IconOptions({ Width = 20, Height = 24 })):CreateButton()

        D.expect(container.imageCalls[1].size).toEqual({ 20, 24 })
    end)

    D.test("replaces an image button whose icon did not bind", function(ctx)
        local warnings = CaptureWarnings(ctx)
        local container = FakeContainer({ imageData = { Icon = "" } })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button).toBe(container.buttons[1])
        D.expect(widget.Widget.Button.Kind).toBe("text")
        D.expect(widget.Widget.Button.Label).toBe(LABEL)
        D.expect(#warnings).toBe(0)
    end)

    D.test("replaces an image button without image data", function()
        local container = FakeContainer()
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button.Kind).toBe("text")
    end)

    D.test("creates one text button when the image button call throws", function(ctx)
        local warnings = CaptureWarnings(ctx)
        local container = FakeContainer({ addImageThrows = true })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button).toBe(container.buttons[1])
        D.expect(widget.Widget.Button.Kind).toBe("text")
        D.expect(#warnings).toBe(1)
        D.expect(warnings[1]:find("event-button-fixture", 1, true) ~= nil).toBe(true)
    end)

    D.test("destroys a partial image button when reading it throws", function(ctx)
        local warnings = CaptureWarnings(ctx)
        local container = FakeContainer({ imageReadThrows = true })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button.Kind).toBe("text")
        D.expect(#warnings).toBe(1)
    end)

    D.test("still creates a text button when partial cleanup throws", function(ctx)
        local warnings = CaptureWarnings(ctx)
        local container = FakeContainer({ imageData = { Icon = "" }, destroyThrows = true })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(container.destroyCalls).toBe(1)
        -- The partial button cannot be removed; no further orphan may join it.
        D.expect(#container.buttons).toBe(2)
        D.expect(widget.Widget.Button.Kind).toBe("text")
        D.expect(#warnings).toBe(1)
    end)

    D.test("creates one cooldown group after a fallback", function(ctx)
        CaptureWarnings(ctx)
        local container = FakeContainer({ addImageThrows = true })
        local widget = FakeWidget(container, IconOptions())

        widget:CreateButton()

        D.expect(#container.groups).toBe(1)
        D.expect(widget.Widget.CooldownGroup).toBe(container.groups[1])
    end)

    D.test("wires the click and ID onto the fallback button", function(ctx)
        CaptureWarnings(ctx)
        local container = FakeContainer({ addImageThrows = true })
        local widget = FakeWidget(container, IconOptions())
        local clicks = 0
        widget.RegisterCallbackSub = function() end
        widget.HandleButtonClick = function() clicks = clicks + 1 end

        widget:CreateWidgetElements()
        widget._actionSubscription:Unsubscribe()
        widget.Widget.Button.OnClick()

        D.expect(#container.buttons).toBe(1)
        D.expect(widget.Widget.Button.IDContext).toBe(MOD_UUID .. "_event-button-fixture_EventButton")
        D.expect(clicks).toBe(1)
    end)
end)
