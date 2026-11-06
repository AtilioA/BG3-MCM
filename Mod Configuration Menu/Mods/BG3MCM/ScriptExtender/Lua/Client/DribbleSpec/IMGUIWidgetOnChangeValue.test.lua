D.describe("IMGUIWidget OnChange value", { tags = { "imgui_widget_onchange", "client", "unit" } }, function()
    local MOD_UUID = "00000000-0000-0000-0000-00000000C006"
    local SETTING_ID = "test-setting"
    local DEFAULT_COLOR = { 1, 1, 1, 1 }
    local CHANGED_COLOR = { 0.25, 0.5, 0.75, 0.4 }

    --- Engine-free element: every Add* call returns a recorded child element
    ---@param fields? table
    ---@return table element
    local function FakeElement(fields)
        local element = fields or {}
        local noop = function() end
        element.added = {}
        element.SetColor = noop
        element.SetStyle = noop
        element.Destroy = noop
        function element:Tooltip() return FakeElement() end
        return setmetatable(element, {
            __index = function(_, key)
                if type(key) ~= "string" or key:sub(1, 3) ~= "Add" then return nil end
                return function(self)
                    local child = FakeElement({ Image = { Icon = "fake_icon" } })
                    self.added[key] = self.added[key] or {}
                    table.insert(self.added[key], child)
                    return child
                end
            end,
        })
    end

    ---@param settingType string
    ---@param default any
    ---@param options? table
    ---@return any setting
    local function FakeSetting(settingType, default, options)
        return {
            Id = SETTING_ID,
            GetId = function() return SETTING_ID end,
            GetLocaName = function() return "Test setting" end,
            GetType = function() return settingType end,
            GetOptions = function() return options or {} end,
            GetDefault = function() return default end,
            GetDescription = function() return nil end,
            GetTooltip = function() return nil end,
            GetHandles = function() return {} end,
        }
    end

    ---@param ctx table
    ---@return table writes Recorded SetSettingValue calls
    local function RecordWrites(ctx)
        local writes = {}
        ctx.stub(IMGUIAPI, "SetSettingValue", function(_, settingId, value, modUUID)
            table.insert(writes, { settingId = settingId, value = value, modUUID = modUUID })
        end)
        return writes
    end

    ---@param settingType string
    ---@param default any
    ---@param initial any
    ---@param widgetClass table
    ---@param options? table
    ---@return table widget
    local function CreateWidget(settingType, default, initial, widgetClass, options)
        local setting = FakeSetting(settingType, default, options)
        return IMGUIWidget:Create(FakeElement({ IDContext = "group" }), setting, initial, MOD_UUID, widgetClass)
    end

    D.test("extractors return the literal value of each event shape", function()
        local numericEvent = { Value = { 3, 0, 0, 0 } }
        ---@type any
        local enumWidget = setmetatable({
            Widget = { UserData = { OptionsLookup = { ["Label B"] = "second" } } },
        }, { __index = EnumIMGUIWidget })
        local cases = {
            { CheckboxIMGUIWidget, { Checked = false }, false },
            { IntIMGUIWidget, numericEvent, 3 },
            { FloatIMGUIWidget, numericEvent, 3 },
            { DragIntIMGUIWidget, numericEvent, 3 },
            { DragFloatIMGUIWidget, numericEvent, 3 },
            { SliderIntIMGUIWidget, numericEvent, 3 },
            { SliderFloatIMGUIWidget, numericEvent, 3 },
            { TextIMGUIWidget, { Text = "typed" }, "typed" },
            { RadioIMGUIWidget, { UserData = { OriginalValue = "stored" }, Label = "shown" }, "stored" },
            { ColorEditIMGUIWidget, { Color = CHANGED_COLOR }, CHANGED_COLOR },
            { ColorPickerIMGUIWidget, { Color = CHANGED_COLOR }, CHANGED_COLOR },
        }

        for _, case in ipairs(cases) do
            local widget = setmetatable({}, { __index = case[1] })
            D.expect(IMGUIWidget:ExtractValueFromWidgetEvent(widget, case[2])).toEqual(case[3])
        end

        local enumEvent = { Options = { "Label A", "Label B" }, SelectedIndex = 1 }
        D.expect(IMGUIWidget:ExtractValueFromWidgetEvent(enumWidget, enumEvent)).toBe("second")
    end)

    D.test("color picker tracks RGBA and runs its handler once with the original event", function(ctx)
        local writes = RecordWrites(ctx)
        local widget = CreateWidget("color_picker", DEFAULT_COLOR, DEFAULT_COLOR, ColorPickerIMGUIWidget)
        D.expect(widget._resetButton.Visible).toBe(false)

        local event = { Color = CHANGED_COLOR }
        widget.Widget.OnChange(event)

        D.expect(#writes).toBe(1)
        D.expect(writes[1].settingId).toBe(SETTING_ID)
        D.expect(writes[1].value).toBe(CHANGED_COLOR)
        D.expect(writes[1].modUUID).toBe(MOD_UUID)
        D.expect(widget._currentValue).toEqual({ 0.25, 0.5, 0.75, 0.4 })
        D.expect(widget._resetButton.Visible).toBe(true)

        widget.Widget.OnChange({ Color = { 1, 1, 1, 1 } })
        D.expect(#writes).toBe(2)
        D.expect(widget._resetButton.Visible).toBe(false)
    end)

    D.test("color picker reset tracking follows the matching saved event and value updates", function(ctx)
        RecordWrites(ctx)
        local resets = {}
        ---@type fun(data: table)
        local savedListener
        ctx.stub(IMGUIAPI, "ResetSettingValue", function(_, settingId, modUUID)
            table.insert(resets, { settingId = settingId, modUUID = modUUID })
        end)
        ctx.stub(ModEventManager, "Subscribe", function(_, _, listener) savedListener = listener end)
        local widget = CreateWidget("color_picker", DEFAULT_COLOR, DEFAULT_COLOR, ColorPickerIMGUIWidget)
        widget.Widget.OnChange({ Color = CHANGED_COLOR })

        widget._resetButton.OnClick()
        D.expect(resets).toEqual({ { settingId = SETTING_ID, modUUID = MOD_UUID } })

        savedListener({ modUUID = MOD_UUID, settingId = "other-setting", value = { 0, 0, 0, 0 } })
        D.expect(widget._currentValue).toEqual({ 0.25, 0.5, 0.75, 0.4 })
        D.expect(widget._resetButton.Visible).toBe(true)

        savedListener({ modUUID = MOD_UUID, settingId = SETTING_ID, value = { 1, 1, 1, 1 } })
        D.expect(widget._currentValue).toEqual({ 1, 1, 1, 1 })
        D.expect(widget._resetButton.Visible).toBe(false)

        widget:UpdateCurrentValue(CHANGED_COLOR)
        D.expect(widget.Widget.Color).toEqual({ 0.25, 0.5, 0.75, 0.4 })
        D.expect(widget._resetButton.Visible).toBe(true)
    end)

    D.test("checkbox keeps a false value through tracking and its handler", function(ctx)
        local writes = RecordWrites(ctx)
        local widget = CreateWidget("checkbox", true, true, CheckboxIMGUIWidget)

        widget.Widget.OnChange({ Checked = false })

        D.expect(#writes).toBe(1)
        D.expect(writes[1].value).toBe(false)
        D.expect(widget._currentValue).toBe(false)
        D.expect(widget._resetButton.Visible).toBe(true)
    end)

    D.test("enum tracks the stored choice instead of its label", function(ctx)
        local writes = RecordWrites(ctx)
        local widget = CreateWidget("enum", "first", "first", EnumIMGUIWidget, { Choices = { "first", "second" } })

        widget.Widget.OnChange({ Options = { "first", "second" }, SelectedIndex = 1 })

        D.expect(#writes).toBe(1)
        D.expect(writes[1].value).toBe("second")
        D.expect(widget._currentValue).toBe("second")
        D.expect(widget._resetButton.Visible).toBe(true)
    end)

    D.test("a failing extractor falls back to the event and the handler still runs once", function()
        local WidgetWithoutExtractor = setmetatable({}, { __index = IMGUIWidget })
        local received = {}
        function WidgetWithoutExtractor:new(group)
            ---@type any
            local instance = setmetatable({}, { __index = WidgetWithoutExtractor })
            instance.Widget = group:AddInputText()
            instance.Widget.OnChange = function(event) table.insert(received, event) end
            return instance
        end
        local widget = CreateWidget("text", "default", "default", WidgetWithoutExtractor)

        local event = { Text = "changed" }
        widget.Widget.OnChange(event)

        D.expect(#received).toBe(1)
        D.expect(received[1]).toBe(event)
        D.expect(widget._currentValue).toBe(event)
        D.expect(widget._resetButton.Visible).toBe(true)
    end)

    D.test("deprecated keybinding writes from its own combos without interception", function(ctx)
        local writes = RecordWrites(ctx)
        local initial = { ScanCode = "A", Modifier = "NONE" }
        local widget = CreateWidget("keybinding", initial, initial, KeybindingIMGUIWidget)

        D.expect(widget.Widget.OnChange).toBeNil()
        widget.Widget.ModifierWidget.OnChange({ Options = { "LShift" }, SelectedIndex = 0 })

        D.expect(#writes).toBe(1)
        D.expect(writes[1].value).toEqual({ ScanCode = "A", Modifier = "LShift" })
    end)

    D.test("deprecated list writes from its own input without interception", function(ctx)
        local writes = RecordWrites(ctx)
        local widget = CreateWidget("list", {}, {}, ListIMGUIWidget)

        D.expect(widget.Widget.OnChange).toBeNil()
        local inputGroup = widget.Widget.InputGroup
        inputGroup.added.AddInputText[1].OnChange({ Text = "added" })
        inputGroup.added.AddButton[1].OnClick()

        D.expect(#writes).toBe(1)
        D.expect(writes[1].value).toEqual({ "added" })
    end)
end)
