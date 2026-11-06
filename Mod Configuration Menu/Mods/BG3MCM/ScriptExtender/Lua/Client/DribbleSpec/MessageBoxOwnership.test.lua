-- The fake tree models native destruction from BG3SE source; it does not prove engine lifetime.
D.describe("MessageBox popup ownership", { tags = { "message_box_ownership", "client", "unit" } }, function()
    local DEAD_HANDLE = "IMGUI object no longer exists"

    ---@return table parent
    local function FakeParent()
        local noop = function() end
        local parent = { popups = {} }

        function parent:AddPopup()
            if self.retired then error(DEAD_HANDLE) end
            local popup = {
                live = true,
                opened = 0,
                destroyAttempts = 0,
                failingDestroys = 0,
                buttons = {},
                SetSizeConstraints = noop,
                SetStyle = noop,
                AddSeparator = noop,
                AddDummy = noop,
            }
            function popup:Open() self.opened = self.opened + 1 end
            function popup:AddText(label) return { Label = label, SetColor = noop } end
            function popup:AddButton(label)
                local button = { Label = label, SetColor = noop }
                table.insert(self.buttons, button)
                return button
            end
            function popup:Destroy()
                self.destroyAttempts = self.destroyAttempts + 1
                if not self.live then error(DEAD_HANDLE) end
                if self.failingDestroys > 0 then
                    self.failingDestroys = self.failingDestroys - 1
                    error("destroy failed")
                end
                self.live = false
            end
            table.insert(self.popups, popup)
            return popup
        end

        function parent:Retire()
            self.retired = true
            for _, popup in ipairs(self.popups) do popup.live = false end
        end

        return parent
    end

    ---@param parent table
    ---@return integer
    local function LiveCount(parent)
        local count = 0
        for _, popup in ipairs(parent.popups) do
            if popup.live then count = count + 1 end
        end
        return count
    end

    ---@param mode string|nil
    ---@return table
    local function NewBox(mode)
        return MessageBox:Create("T", "M", mode or MessageBoxMode.Ok, "mod", "ctx")
            :SetOkLabel("O"):SetCancelLabel("C"):SetYesLabel("Y"):SetNoLabel("N")
    end

    -- Every response button: the mode that shows it, its setter and its position in that mode.
    local RESPONSES = {
        { name = "Ok", mode = "Ok", setter = "SetOkCallback", index = 1 },
        { name = "Cancel", mode = "OkCancel", setter = "SetCancelCallback", index = 2 },
        { name = "Yes", mode = "YesNo", setter = "SetYesCallback", index = 1 },
        { name = "No", mode = "YesNo", setter = "SetNoCallback", index = 2 },
    }

    D.test("repeated Show keeps one live popup and shows the latest labels", function()
        local parent = FakeParent()
        local box = NewBox()

        box:Show(parent)
        box:SetOkLabel("Later")
        D.expect(box:Show(parent)).toBe(box)

        D.expect(#parent.popups).toBe(2)
        D.expect(LiveCount(parent)).toBe(1)
        D.expect(parent.popups[2].opened).toBe(1)
        D.expect(parent.popups[2].buttons[1].Label).toBe("Later")
    end)

    D.test("repeated Close destroys the popup once", function()
        local parent = FakeParent()
        local box = NewBox()

        box:Show(parent)
        box:Close()
        box:Close()

        D.expect(parent.popups[1].destroyAttempts).toBe(1)
        D.expect(box.PopupDialog).toBe(nil)
    end)

    D.test("Show without a parent retains the old reference for a later close", function(ctx)
        local parent = FakeParent()
        local box = NewBox()
        local errors = {}
        ctx.stub(_G, "MCMError", function(_, message) table.insert(errors, message) end)

        box:Show(parent)
        D.expect(box:Show(nil)).toBe(nil)
        D.expect(box.PopupDialog).toBe(parent.popups[1])
        box:Close()

        D.expect(errors).toEqual({ "No parent group provided for MessageBox." })
        D.expect(LiveCount(parent)).toBe(0)
        D.expect(parent.popups[1].destroyAttempts).toBe(2)
    end)

    D.test("failed Destroy continues, keeps the reference and a later Close retries it", function()
        local parent = FakeParent()
        local box = NewBox()

        box:Show(parent)
        local popup = parent.popups[1]
        popup.failingDestroys = 1

        box:Close()
        D.expect(box.PopupDialog).toBe(popup)
        D.expect(popup.live).toBe(true)

        box:Close()
        D.expect(box.PopupDialog).toBe(nil)
        D.expect(popup.live).toBe(false)
        D.expect(popup.destroyAttempts).toBe(2)
    end)

    D.test("Show continues past a failed Destroy and owns the new popup", function()
        local parent = FakeParent()
        local box = NewBox()

        box:Show(parent)
        parent.popups[1].failingDestroys = 1
        box:Show(parent)

        D.expect(box.PopupDialog).toBe(parent.popups[2])
        D.expect(parent.popups[2].opened).toBe(1)
    end)

    D.test("a box that outlives its retired parent reopens under a new parent", function()
        local oldParent, newParent = FakeParent(), FakeParent()
        local box = NewBox()

        box:Show(oldParent)
        oldParent:Retire()
        box:Close()
        box:Show(newParent)

        D.expect(LiveCount(newParent)).toBe(1)
        D.expect(box.PopupDialog).toBe(newParent.popups[1])
        box:Close()
        D.expect(LiveCount(newParent)).toBe(0)
        D.expect(box.PopupDialog).toBe(nil)
    end)

    D.test("Show on a retired parent reports the failure and a later Show recovers", function()
        local oldParent, newParent = FakeParent(), FakeParent()
        local box = NewBox()

        box:Show(oldParent)
        oldParent:Retire()
        -- Expects the dead-parent error, which Show must not swallow.
        local shown, err = pcall(box.Show, box, oldParent)
        D.expect(shown).toBe(false)
        D.expect(string.find(tostring(err), DEAD_HANDLE, 1, true) ~= nil).toBe(true)

        box:Show(newParent)
        D.expect(box.PopupDialog).toBe(newParent.popups[1])
    end)

    for _, response in ipairs(RESPONSES) do
        D.test(response.name .. " runs its callback before it closes its popup", function()
            local parent = FakeParent()
            local box = NewBox(MessageBoxMode[response.mode])
            local liveDuringCallback
            box[response.setter](box, function() liveDuringCallback = parent.popups[1].live end)

            box:Show(parent)
            parent.popups[1].buttons[response.index].OnClick()

            D.expect(liveDuringCallback).toBe(true)
            D.expect(parent.popups[1].live).toBe(false)
            D.expect(box.PopupDialog).toBe(nil)
        end)

        D.test(response.name .. " keeps a replacement shown by its callback", function()
            local parent = FakeParent()
            local box = NewBox(MessageBoxMode[response.mode])
            box[response.setter](box, function() box:Show(parent) end)

            box:Show(parent)
            parent.popups[1].buttons[response.index].OnClick()

            D.expect(parent.popups[1].live).toBe(false)
            D.expect(parent.popups[2].live).toBe(true)
            D.expect(box.PopupDialog).toBe(parent.popups[2])
        end)
    end

    D.test("a callback that closes its own popup destroys it once", function()
        local parent = FakeParent()
        local box = NewBox()
        box:SetOkCallback(function() box:Close() end)

        box:Show(parent)
        parent.popups[1].buttons[1].OnClick()

        D.expect(parent.popups[1].destroyAttempts).toBe(1)
        D.expect(box.PopupDialog).toBe(nil)
    end)

    D.test("a throwing callback propagates and leaves its popup open", function()
        local parent = FakeParent()
        local box = NewBox()
        box:SetOkCallback(function() error("author failure") end)

        box:Show(parent)
        -- Expects the author error, which the click handler must not swallow.
        local clicked, err = pcall(parent.popups[1].buttons[1].OnClick)

        D.expect(clicked).toBe(false)
        D.expect(string.find(tostring(err), "author failure", 1, true) ~= nil).toBe(true)
        D.expect(box.PopupDialog).toBe(parent.popups[1])
        D.expect(parent.popups[1].live).toBe(true)
    end)

    D.test("a button uses the callback set after its popup opened", function()
        local parent = FakeParent()
        local box = NewBox()
        local calls = {}
        box:SetOkCallback(function() table.insert(calls, "first") end)

        box:Show(parent)
        box:SetOkCallback(function() table.insert(calls, "second") end)
        parent.popups[1].buttons[1].OnClick()

        D.expect(calls).toEqual({ "second" })
    end)

    D.test("a late click on a replaced popup does not close the replacement", function()
        local parent = FakeParent()
        local box = NewBox()
        local clicks = 0
        box:SetOkCallback(function() clicks = clicks + 1 end)

        box:Show(parent)
        parent.popups[1].failingDestroys = 1
        box:Show(parent)
        parent.popups[1].buttons[1].OnClick()

        D.expect(clicks).toBe(1)
        D.expect(parent.popups[2].live).toBe(true)
        D.expect(box.PopupDialog).toBe(parent.popups[2])
    end)

    D.describe("through DialogService", function()
        local KEY = "MessageBoxOwnershipTest"

        ---@param parent table
        ---@param onOk function|nil
        ---@return table
        local function Confirm(parent, onOk)
            return DialogService:Confirm("mod", KEY, parent, "T", "M", onOk or function() end, function() end)
        end

        D.afterEach(function()
            DialogService.cache["mod_" .. KEY] = nil
        end)

        D.test("Confirm shows on call and a second Show applies the labels", function()
            local parent = FakeParent()

            local box = Confirm(parent)
            D.expect(#parent.popups).toBe(1)
            D.expect(parent.popups[1].opened).toBe(1)

            box:SetOkLabel("Sure"):SetCancelLabel("Stop")
            box:Show(parent)

            D.expect(LiveCount(parent)).toBe(1)
            D.expect(parent.popups[2].buttons[1].Label).toBe("Sure")
            D.expect(parent.popups[2].buttons[2].Label).toBe("Stop")
        end)

        D.test("repeat Confirm reuses the cached box and its first callback", function()
            local oldParent, newParent = FakeParent(), FakeParent()
            local calls = {}

            local first = Confirm(oldParent, function() table.insert(calls, "first") end)
            oldParent:Retire()
            local second = Confirm(newParent, function() table.insert(calls, "second") end)
            newParent.popups[1].buttons[1].OnClick()

            D.expect(second).toBe(first)
            D.expect(calls).toEqual({ "first" })
            D.expect(LiveCount(newParent)).toBe(0)
        end)

        D.test("a callback that confirms again keeps the replacement open", function()
            local parent = FakeParent()

            Confirm(parent, function() Confirm(parent) end)
            parent.popups[1].buttons[1].OnClick()

            D.expect(parent.popups[2].live).toBe(true)
            D.expect(LiveCount(parent)).toBe(1)
        end)

        D.test("a callback that destroys and recreates the dialog keeps the new box open", function()
            local parent = FakeParent()
            local replacement

            local first = Confirm(parent, function()
                DialogService:Destroy("mod", KEY)
                replacement = Confirm(parent)
            end)
            parent.popups[1].buttons[1].OnClick()

            D.expect(replacement == first).toBe(false)
            D.expect(parent.popups[1].destroyAttempts).toBe(1)
            D.expect(parent.popups[2].live).toBe(true)
            D.expect(DialogService.cache["mod_" .. KEY]).toBe(replacement)
        end)
    end)
end)
