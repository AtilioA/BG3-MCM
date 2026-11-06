D.describe("Dialog button stack", { tags = { "dialog_stack", "client", "unit" } }, function()
    --- Popup stand-in that records buttons in creation order
    ---@return table parent
    ---@return table popup
    local function FakePopupParent()
        local noop = function() end
        local popup = { buttons = {}, SetSizeConstraints = noop, AddSeparator = noop, AddDummy = noop, Open = noop }
        function popup:Destroy() self.destroyed = true end
        function popup:SetStyle(key, x, y) if key == "ItemSpacing" then self.spacing = { x, y } end end
        function popup:AddText(label) return { Label = label, SetColor = noop } end
        function popup:AddButton(label)
            local button = { Label = label, SetColor = noop }
            table.insert(self.buttons, button)
            return button
        end
        return { AddPopup = function() return popup end }, popup
    end

    ---@param popup table
    ---@param count integer
    local function ExpectStack(popup, count)
        D.expect(#popup.buttons).toBe(count)
        D.expect(popup.spacing).toEqual({ 8, 6 })
        for _, button in ipairs(popup.buttons) do
            D.expect(button.Size).toEqual({ -1, 0 })
            D.expect(button.SameLine).toBe(nil)
        end
    end

    D.test("MessageBox stacks every button in order and runs its callback", function()
        local parent, popup = FakePopupParent()
        local calls = {}
        local box = MessageBox:Create("T", "M", MessageBoxMode.YesNoCancel, "mod", "ctx")
        box:SetYesLabel("Y"):SetNoLabel("N"):SetCancelLabel("C")
        box:SetNoCallback(function() table.insert(calls, "no") end)
        box:Show(parent)
        ExpectStack(popup, 3)
        D.expect(popup.buttons[1].Label).toBe("Y")
        D.expect(popup.buttons[2].Label).toBe("N")
        D.expect(popup.buttons[3].Label).toBe("C")
        popup.buttons[2].OnClick()
        D.expect(calls).toEqual({ "no" })
        D.expect(popup.destroyed).toBe(true)
    end)

    D.test("OkCancel keeps OK first and cancel closes without running OK", function()
        local parent, popup = FakePopupParent()
        local ok, cancelled = false, false
        local box = MessageBox:Create("T", "M", MessageBoxMode.OkCancel, "mod", "ctx")
        box:SetOkLabel("O"):SetCancelLabel("C")
        box:SetOkCallback(function() ok = true end):SetCancelCallback(function() cancelled = true end)
        box:Show(parent)
        ExpectStack(popup, 2)
        D.expect(popup.buttons[1].Label).toBe("O")
        popup.buttons[2].OnClick()
        D.expect(ok).toBe(false)
        D.expect(cancelled).toBe(true)
    end)

    ---@param ctx table
    ---@return table widget
    ---@return table popup
    local function FakeListWidget(ctx)
        ctx.stub(IMGUIHelpers, "AddTooltip", function() end)
        local parent, popup = FakePopupParent()
        return setmetatable({
            Widget = { Group = parent, ModUUID = "mod", Setting = { Id = "list" }, Enabled = true, Elements = { {} } },
        }, ListV2IMGUIWidget), popup
    end

    D.test("list delete-all cancel leaves elements unchanged", function(ctx)
        local widget, popup = FakeListWidget(ctx)
        widget:ShowDeleteAllConfirmationPopup()
        ExpectStack(popup, 2)
        popup.buttons[2].OnClick()
        D.expect(#widget.Widget.Elements).toBe(1)
        D.expect(popup.destroyed).toBe(true)
    end)

    D.test("list reset cancel does not reset", function(ctx)
        local widget, popup = FakeListWidget(ctx)
        local reset = false
        ctx.stub(IMGUIAPI, "ResetSettingValue", function() reset = true end)
        widget:ShowResetConfirmationPopup({}, "mod")
        ExpectStack(popup, 2)
        popup.buttons[2].OnClick()
        D.expect(reset).toBe(false)
        D.expect(popup.destroyed).toBe(true)
    end)
end)
