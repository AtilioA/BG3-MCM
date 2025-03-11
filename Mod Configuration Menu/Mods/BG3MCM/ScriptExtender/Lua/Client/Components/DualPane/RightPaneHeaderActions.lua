--------------------------------------------
-- HeaderActions Module
-- Manages the header action buttons independently.
--------------------------------------------

HeaderActions = {}
HeaderActions.__index = HeaderActions

function HeaderActions:New(parent)
    local self = setmetatable({}, HeaderActions)
    self.parent = parent
    self.group = self.parent:AddGroup("HeaderActions")

    -- Create toggle buttons and set their OnClick to call DualPane:ToggleSidebar()
    self.expandBtn = self:CreateActionButton("Toggle", ICON_TOGGLE_EXPAND,
        Ext.Loca.GetTranslatedString("hbb483085e7f04700beb8cc5bf94a98b4g6ac"), 1.5)
    self.expandBtn.SameLine = true
    self.collapseBtn = self:CreateActionButton("Collapse", ICON_TOGGLE_COLLAPSE,
        Ext.Loca.GetTranslatedString("h4e0e208daa6a439ca5ba95a668a7ac36d882"), 1.5)
    self.collapseBtn.SameLine = true
    self.expandBtn.OnClick = function() DualPane:ToggleSidebar() end
    self.collapseBtn.OnClick = function() DualPane:ToggleSidebar() end

    if DualPane and DualPane.isCollapsed then
        self.expandBtn.Visible = true
        self.collapseBtn.Visible = false
    else
        self.expandBtn.Visible = false
        self.collapseBtn.Visible = true
    end

    local dummy = self.parent:AddDummy(15, 0)
    dummy.SameLine = true

    self.detachBtn = self:CreateActionButton("[Detach]", ICON_DETACH,
        Ext.Loca.GetTranslatedString("h5270f62d04b243b6b9ea0473bd610aa72b0e"), 1)
    self.detachBtn.SameLine = true
    self.detachBtn.OnClick = function()
        if DualPane.rightPane and DualPane.rightPane.currentMod and
            DualPane.rightPane.currentMod.group and DualPane.rightPane.currentMod.modUUID then
            DualPane.rightPane:DetachModGroup(DualPane.rightPane.currentMod.modUUID)
        end
    end

    self.reattachBtn = self:CreateActionButton("[Reattach]", "input_dropDownArrow_d",
        "Reattach mod", 1.5)
    self.reattachBtn.SameLine = true
    self.reattachBtn.Visible = false
    self.reattachBtn.OnClick = function()
        if DualPane.rightPane and DualPane.rightPane.currentMod and
            DualPane.rightPane.currentMod.group and DualPane.rightPane.currentMod.modUUID then
            DualPane.rightPane:ReattachModGroup(DualPane.rightPane.currentMod.modUUID)
        end
    end

    return self
end

function HeaderActions:CreateActionButton(text, icon, tooltip, multiplier)
    local button = self.parent:AddImageButton(text, icon, IMGUIWidget:GetIconSizes(multiplier))
    button.IDContext = "HeaderAction_" .. text .. "_BUTTON"
    MCMRendering:AddTooltip(button, tooltip, "HeaderAction_" .. text)
    return button
end

-- Update the visibility of toggle buttons based on whether the sidebar is collapsed.
-- If isCollapsed is true then show the expand button; otherwise, show the collapse button.
function HeaderActions:UpdateToggleButtons(isCollapsed)
    if isCollapsed then
        self.expandBtn.Visible = true
        self.collapseBtn.Visible = false
    else
        self.expandBtn.Visible = false
        self.collapseBtn.Visible = true
    end
end
