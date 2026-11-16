D.describe("Radio reset visibility", { tags = { "radio_reset_visibility", "client", "unit" } }, function()
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
            return setmetatable(result, {
                __index = function(_, key)
                    if type(key) ~= "string" or key:sub(1, 3) ~= "Add" then return nil end
                    return function() return element({ Image = { Icon = "fake_icon" } }) end
                end,
            })
        end
        local setting = {
            GetId = function() return "radio-test" end,
            GetLocaName = function() return "Radio test" end,
            GetType = function() return "radio" end,
            GetOptions = function() return { Choices = { "first", "second" } } end,
            GetDefault = function() return "first" end,
            GetDescription = function() return nil end,
            GetTooltip = function() return nil end,
            GetHandles = function() return {} end,
        }
        local widget = IMGUIWidget:Create(element({ IDContext = "group" }), setting, "first", modUUID,
            RadioIMGUIWidget)

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
