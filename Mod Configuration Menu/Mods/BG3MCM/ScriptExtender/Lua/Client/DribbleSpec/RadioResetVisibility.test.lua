D.describe("Radio reset visibility", { tags = { "radio_reset_visibility", "client", "unit" } }, function()
    ---@class RadioResetFakeElement : ExtuiTreeParent
    ---@field added table<string, RadioResetFakeElement[]>
    ---@field Image? { Icon: string }
    ---@field SetColor fun(self: RadioResetFakeElement)
    ---@field SetStyle fun(self: RadioResetFakeElement)
    ---@field Destroy fun(self: RadioResetFakeElement)
    ---@field Tooltip fun(self: RadioResetFakeElement): RadioResetFakeElement

    D.test("selection tracks the stored value and updates reset visibility", function(ctx)
        local modUUID = "00000000-0000-0000-0000-00000000C007"
        local writes = {}
        ctx.stub(IMGUIAPI, "SetSettingValue", function(_, id, value, uuid)
            table.insert(writes, { id = id, value = value, uuid = uuid })
        end)

        local function element(fields)
            local result = fields or {}
            result.SetColor = function() end
            result.SetStyle = function() end
            result.Destroy = function() end
            function result:Tooltip() return element() end
            local fakeElement = setmetatable(result, {
                __index = function(_, key)
                    if type(key) ~= "string" or key:sub(1, 3) ~= "Add" then return nil end
                    return function() return element({ Image = { Icon = "fake_icon" } }) end
                end,
            })
            ---@cast fakeElement RadioResetFakeElement
            return fakeElement
        end
        local setting = BlueprintSetting:New({
            Id = "radio-test",
            Name = "Radio test",
            Type = "radio",
            Default = "first",
            Options = { Choices = { "first", "second" } },
        })
        setting.GetId = function() return "radio-test" end
        setting.GetLocaName = function() return "Radio test" end
        setting.GetType = function() return "radio" end
        setting.GetOptions = function() return { Choices = { "first", "second" } } end
        setting.GetDefault = function() return "first" end
        setting.GetDescription = function() return nil end
        setting.GetTooltip = function() return nil end
        setting.GetHandles = function() return {} end
        local widget = IMGUIWidget:Create(element({ IDContext = "group" }), setting, "first", modUUID,
            RadioIMGUIWidget)
        assert(widget)
        ---@cast widget RadioIMGUIWidget

        D.expect(widget._resetButton.Visible).toBe(false)
        widget.Widget[2].OnChange(widget.Widget[2])
        D.expect(widget._currentValue).toBe("second")
        D.expect(widget._resetButton.Visible).toBe(true)
        widget.Widget[1].OnChange(widget.Widget[1])
        D.expect(widget._currentValue).toBe("first")
        D.expect(widget._resetButton.Visible).toBe(false)
        D.expect(writes).toEqual({
            { id = "radio-test", value = "second", uuid = modUUID },
            { id = "radio-test", value = "first", uuid = modUUID },
        })
    end)
end)
