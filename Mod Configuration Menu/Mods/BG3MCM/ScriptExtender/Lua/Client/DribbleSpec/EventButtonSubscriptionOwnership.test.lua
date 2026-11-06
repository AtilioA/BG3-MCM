D.describe("Event button subscription ownership", { tags = { "event_button_subscription", "client", "unit" } }, function()
    local BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
    local MOD_UUID = "00000000-0000-0000-0000-00000000E002"
    local SETTING_ID = "event-button-fixture"
    local STALE_HANDLE = "IMGUI object no longer exists"

    --- Fake IMGUI element whose handle throws once its tree is dead, as a destroyed BG3SE element does
    ---@param tree table Shared { dead = boolean }
    ---@param fields? table
    ---@return table element
    local function FakeElement(tree, fields)
        local state = fields or {}
        state.Children = {}
        state.DestroyCalls = 0

        local function add(kind)
            return function(_, label)
                local child = FakeElement(tree, { Kind = kind, Label = label })
                table.insert(state.Children, child)
                return child
            end
        end
        state.AddGroup = add("group")
        state.AddButton = add("button")
        state.AddText = add("text")
        state.SetColor = function() end
        state.Destroy = function()
            state.DestroyCalls = state.DestroyCalls + 1
            state.Destroyed = true
        end

        return setmetatable({}, {
            __index = function(_, key)
                if tree.dead then error(STALE_HANDLE) end
                return state[key]
            end,
            __newindex = function(_, key, value)
                if tree.dead then error(STALE_HANDLE) end
                state[key] = value
            end,
        })
    end

    local function FakeSetting(options)
        return {
            GetOptions = function() return options or {} end,
            GetHandles = function() return {} end,
            GetLocaName = function() return "Setting name" end,
            GetId = function() return SETTING_ID end,
        }
    end

    --- Replaces the registry's subject and widget map, so no test touches the live coordinator
    ---@return table world subject (a real BehaviorSubject), widgets, warnings, errors, tooltips, cooldowns
    local function IsolatedWorld(ctx)
        local world = {
            subject = BehaviorSubject.Create({}),
            registry = {},
            widgets = {},
            warnings = {},
            errors = {},
            tooltips = {},
            cooldowns = {},
        }

        ctx.stub(EventButtonRegistry, "GetSubject", function() return world.subject end)
        ctx.stub(EventButtonRegistry, "GetRegistry", function() return world.registry end)
        ctx.stub(EventButtonRegistry, "GetWidget", function(_, settingId) return world.widgets[settingId] end)
        ctx.stub(EventButtonRegistry, "SetWidget", function(_, settingId, widget) world.widgets[settingId] = widget end)
        ctx.stub(EventButtonRegistry, "RemoveWidget", function(_, settingId) world.widgets[settingId] = nil end)
        ctx.stub(ModEventManager, "Emit", function() end)
        ctx.stub(DialogService, "Confirm", function(_, _, _, _, _, _, onConfirm)
            world.queuedConfirm = onConfirm
            return { SetOkLabel = function() end, SetCancelLabel = function() end, Show = function() end }
        end)
        ctx.stub(VCString, "InterpolateLocalizedMessage", function(_, _, value) return tostring(value) end)
        ctx.stub(IMGUIHelpers, "AddTooltip", function(_, text)
            if world.tooltipThrows then error("tooltip failed") end
            table.insert(world.tooltips, text)
            return { Destroy = function() end }
        end)
        ctx.stub(CooldownHelper, "StartCooldown", function(_, element, duration, onTick, onComplete)
            local run = { element = element, duration = duration, onTick = onTick, onComplete = onComplete }
            table.insert(world.cooldowns, run)
            onTick(element, math.floor(duration))
        end)
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, format, ...)
            table.insert(world.warnings, string.format(format, ...))
        end)
        ctx.stub(Mods.BG3MCM, "MCMError", function(_, format, ...)
            table.insert(world.errors, string.format(format, ...))
        end)
        ctx.stub(Mods.BG3MCM, "MCMDebug", function() end)

        return world
    end

    ---@return table widget Real widget built through its constructor; widget.tree.dead kills its handles
    local function NewWidget(options)
        local tree = { dead = false }
        ---@type table
        local widget = EventButtonIMGUIWidget:new(FakeElement(tree), FakeSetting(options), nil, MOD_UUID)
        widget.tree = tree
        return widget
    end

    local function Entry(callback, disabled)
        return { [MOD_UUID] = { [SETTING_ID] = { eventButtonCallback = callback, disabled = disabled } } }
    end

    D.describe("registry state", function()
        D.test("disables the button during replay when no callback is registered", function(ctx)
            local world = IsolatedWorld(ctx)

            local widget = NewWidget()

            D.expect(widget.Widget.Button.Disabled).toBe(true)
            D.expect(#world.tooltips).toBe(1)
            D.expect(#world.warnings).toBe(0)
        end)

        D.test("follows later registry changes", function(ctx)
            local world = IsolatedWorld(ctx)
            local widget = NewWidget()

            world.subject:OnNext(Entry(function() end))
            D.expect(widget.Widget.Button.Disabled).toBe(false)

            world.subject:OnNext(Entry(function() end, true))
            D.expect(widget.Widget.Button.Disabled).toBe(true)
        end)
    end)

    D.describe("replay failure", function()
        D.test("keeps the widget, reports the failure and registers the widget", function(ctx)
            local world = IsolatedWorld(ctx)
            world.tooltipThrows = true

            local widget = NewWidget()

            D.expect(world.widgets[SETTING_ID]).toBe(widget)
            D.expect(widget.Widget.Button.Kind).toBe("button")
            D.expect(#world.warnings).toBe(1)
            D.expect(world.warnings[1]:find(SETTING_ID, 1, true) ~= nil).toBe(true)
            D.expect(world.warnings[1]:find("tooltip failed", 1, true) ~= nil).toBe(true)
        end)

        D.test("repairs the button on the next delivery", function(ctx)
            local world = IsolatedWorld(ctx)
            world.tooltipThrows = true
            local widget = NewWidget()
            world.tooltipThrows = false

            world.subject:OnNext(Entry(function() end))

            D.expect(widget.Widget.Button.Disabled).toBe(false)
        end)

        D.test("leaves a cancellable observer", function(ctx)
            local world = IsolatedWorld(ctx)
            world.tooltipThrows = true
            local widget = NewWidget()
            D.expect(#world.subject.observers).toBe(1)

            widget:Destroy()

            D.expect(#world.subject.observers).toBe(0)
        end)
    end)

    D.describe("second render of a setting", function()
        -- MCMRendering reuses the mod group, so the first button can stay live; these pin the HEAD behavior.
        D.test("registers the new widget and keeps both following the registry", function(ctx)
            local world = IsolatedWorld(ctx)
            local first = NewWidget()

            local second = NewWidget()
            world.subject:OnNext(Entry(function() end))

            D.expect(world.widgets[SETTING_ID]).toBe(second)
            D.expect(#world.subject.observers).toBe(2)
            D.expect(first.Widget.Button.Disabled).toBe(false)
            D.expect(second.Widget.Button.Disabled).toBe(false)
        end)

        D.test("keeps the current widget when the second widget cannot be built", function(ctx)
            local world = IsolatedWorld(ctx)
            local current = NewWidget()
            local tree = { dead = false }
            local brokenGroup = FakeElement(tree)
            brokenGroup.AddButton = function() error("add failed") end

            -- Expects the injected "add failed": the constructor must propagate it.
            local built = pcall(function()
                EventButtonIMGUIWidget:new(brokenGroup, FakeSetting(), nil, MOD_UUID)
            end)

            D.expect(built).toBe(false)
            D.expect(world.widgets[SETTING_ID]).toBe(current)
            world.subject:OnNext(Entry(function() end))
            D.expect(current.Widget.Button.Disabled).toBe(false)
        end)
    end)

    D.describe("destroy", function()
        D.test("stops deliveries, unregisters the widget and destroys its group", function(ctx)
            local world = IsolatedWorld(ctx)
            local widget = NewWidget()
            local group = widget.Widget.Group

            widget:Destroy()

            D.expect(world.widgets[SETTING_ID]).toBe(nil)
            D.expect(#world.subject.observers).toBe(0)
            D.expect(group.DestroyCalls).toBe(1)
        end)
    end)

    D.describe("click and cooldown", function()
        local function ClickableWidget(world, callback, cooldown)
            world.registry = Entry(callback)
            world.subject:OnNext(world.registry)
            return NewWidget({ Cooldown = cooldown })
        end

        D.test("runs the callback and starts the configured cooldown", function(ctx)
            local world = IsolatedWorld(ctx)
            local runs = 0
            local widget = ClickableWidget(world, function() runs = runs + 1 end, 3)

            widget.Widget.Button.OnClick()

            D.expect(runs).toBe(1)
            D.expect(#world.cooldowns).toBe(1)
            D.expect(world.cooldowns[1].duration).toBe(3)
            D.expect(widget.Widget.Button.Disabled).toBe(true)
        end)

        D.test("isolates a throwing author callback and starts no cooldown", function(ctx)
            local world = IsolatedWorld(ctx)
            local widget = ClickableWidget(world, function() error("author failure") end, 3)

            widget.Widget.Button.OnClick()

            D.expect(#world.cooldowns).toBe(0)
            D.expect(#world.errors).toBe(1)
            D.expect(world.errors[1]:find("author failure", 1, true) ~= nil).toBe(true)
        end)

        D.test("re-enables the button when the cooldown completes", function(ctx)
            local world = IsolatedWorld(ctx)
            local widget = ClickableWidget(world, function() end, 3)
            widget.Widget.Button.OnClick()
            local run = world.cooldowns[1]

            D.expect(run.onTick(run.element, 2)).toBe(false)
            run.onComplete(run.element)

            D.expect(widget.Widget.Button.Disabled).toBe(false)
            D.expect(widget.Widget.CooldownGroup.Children[1].Destroyed).toBe(true)
        end)

        D.test("the first button still runs the callback and its cooldown after a second render", function(ctx)
            local world = IsolatedWorld(ctx)
            local runs = 0
            local first = ClickableWidget(world, function() runs = runs + 1 end, 3)
            NewWidget({ Cooldown = 3 })

            first.Widget.Button.OnClick()

            D.expect(runs).toBe(1)
            D.expect(#world.cooldowns).toBe(1)
            D.expect(world.cooldowns[1].element).toBe(first.Widget.Button)
        end)

        D.test("a queued confirmation still runs the callback after a second render", function(ctx)
            local world = IsolatedWorld(ctx)
            local runs = 0
            world.registry = Entry(function() runs = runs + 1 end)
            local first = NewWidget({ ConfirmDialog = {} })
            first.Widget.Button.OnClick()
            D.expect(runs).toBe(0)

            NewWidget({ ConfirmDialog = {} })
            world.queuedConfirm()

            D.expect(runs).toBe(1)
        end)
    end)

    D.describe("feedback", function()
        D.test("removes the label after its duration", function(ctx)
            IsolatedWorld(ctx)
            local widget = NewWidget()

            widget:UpdateFeedback("Done", "success", 1)
            local label = widget._actionFeedbackLabel
            D.expect(label.Label).toBe("Done")

            ctx.waitUntil(function() return widget._actionFeedbackLabel == nil end, { timeoutTicks = 60 })
            D.expect(label.DestroyCalls).toBe(1)
        end)
    end)
end)
