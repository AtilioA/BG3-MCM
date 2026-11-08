D.describe("keybinding identities", { tags = { "keybinding_identity", "client" } }, function()
    D.test("same-named mods retain distinct headers through repeated navigation", function(ctx)
        local a = "00000000-0000-0000-0000-0000000000a1"
        local b = "00000000-0000-0000-0000-0000000000b2"
        local group = { Children = {} }
        function group:AddText() return {} end
        function group:AddTree(label)
            local header = { Label = label }
            function header:SetOpen(open) self.open = open end
            table.insert(self.Children, header)
            return header
        end
        group.AddCollapsingHeader = group.AddTree
        ctx.stub(MCMClientState, "GetModName", function() return "Same name" end)
        ctx.stub(KeybindingV2IMGUIWidget, "SortFilteredActions", function() end)
        ctx.stub(KeybindingV2IMGUIWidget, "RenderKeybindingTable", function() end)
        local widget = setmetatable({ Widget = {
            Group = group,
            FilteredActions = { { ModUUID = a, ModName = "Same name" }, { ModUUID = b, ModName = "Same name" } },
            DynamicElements = { ModHeaders = {} }
        } }, { __index = KeybindingV2IMGUIWidget })
        widget:RenderKeybindingTables()
        local first, second = group.Children[1], group.Children[2]
        D.expect(first.IDContext).toBe(a .. "_CollapsingHeader")
        D.expect(second.IDContext).toBe(b .. "_CollapsingHeader")
        DualPaneController:_toggleCollapsingHeaders(group, DualPaneController:_computeTargetHeaderId(a))
        D.expect(first.open).toBe(true)
        D.expect(second.open).toBe(false)
        DualPaneController:_toggleCollapsingHeaders(group, DualPaneController:_computeTargetHeaderId(b))
        D.expect(first.open).toBe(false)
        D.expect(second.open).toBe(true)
        D.expect(first.IDContext).toBe(a .. "_CollapsingHeader")
        D.expect(second.IDContext).toBe(b .. "_CollapsingHeader")
    end)

    D.test("same-named mods retain distinct action control and tooltip identities", function(ctx)
        local ids = {}
        ctx.stub(IMGUIHelpers, "ApplyInputStyle", function() end)
        ctx.stub(IMGUIHelpers, "AddTooltip", function(_, _, id) table.insert(ids, id) end)
        local row = {}
        local a = { ModUUID = "mod-a", ModName = "Same name" }
        local b = { ModUUID = "mod-b", ModName = "Same name" }
        local action = { ActionId = "action", Enabled = true }
        local controls = {}
        function row:AddCell()
            return { AddCheckbox = function()
                local checkbox = {}
                table.insert(controls, checkbox)
                return checkbox
            end }
        end
        KeybindingV2IMGUIWidget:RenderEnabledCell(row, a, action)
        KeybindingV2IMGUIWidget:RenderEnabledCell(row, b, action)
        D.expect(controls[1].IDContext).toBe("mod-a_Enabled_action")
        D.expect(controls[2].IDContext).toBe("mod-b_Enabled_action")
        D.expect(ids).toEqual({ "mod-a_Enabled_action_TOOLTIP", "mod-b_Enabled_action_TOOLTIP" })
    end)
end)
