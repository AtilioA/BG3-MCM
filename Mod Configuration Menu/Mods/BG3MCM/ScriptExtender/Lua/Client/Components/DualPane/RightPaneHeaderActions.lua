--------------------------------------------
-- HeaderActions Module
-- Manages the header action buttons independently.
--------------------------------------------

HeaderActions = {}
HeaderActions.__index = HeaderActions

function HeaderActions:New(parent)
    local self = setmetatable({}, HeaderActions)
    self.group = parent:AddGroup("HeaderActions")

    -- Create toggle buttons and set their OnClick to call DualPane:ToggleSidebar()
    self.expandBtn = self:CreateActionButton("[Show mods]", ICON_TOGGLE_EXPAND,
        VCString:InterpolateLocalizedMessage("hbb483085e7f04700beb8cc5bf94a98b4g6ac",
            KeyPresentationMapping:GetKBViewKeyForSetting("toggle_mcm_sidebar_keybinding", ModuleUUID)), 1.5)
    self.expandBtn.SameLine = true
    self.collapseBtn = self:CreateActionButton("[Hide mods]", ICON_TOGGLE_COLLAPSE,
        VCString:InterpolateLocalizedMessage("h4e0e208daa6a439ca5ba95a668a7ac36d882",
            KeyPresentationMapping:GetKBViewKeyForSetting("toggle_mcm_sidebar_keybinding", ModuleUUID)), 1.5)
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

    local dummy = self.group:AddDummy(15, 0)
    dummy.SameLine = true

    self.detachBtn = self:CreateActionButton("[Detach]", ICON_DETACH,
        Ext.Loca.GetTranslatedString("h5270f62d04b243b6b9ea0473bd610aa72b0e"), 1)
    self.detachBtn.SameLine = true
    self.detachBtn.OnClick = function()
        if DualPane.rightPane and DualPane.rightPane.currentMod and
            DualPane.rightPane.currentMod.group and DualPane.rightPane.currentMod.modUUID then
            local modUUID = DualPane.rightPane.currentMod.modUUID
            DualPane.rightPane:DetachModGroup(modUUID)
            self:UpdateDetachButtons(modUUID)
        end
    end

    self.reattachBtn = self:CreateActionButton("[Reattach]", "input_dropDownArrow_d",
        Ext.Loca.GetTranslatedString("hc2133fbab6fb47a9a4f71e83a715780237e1"), 1.5)
    self.reattachBtn.SameLine = true
    self.reattachBtn.Visible = false
    self.reattachBtn.OnClick = function()
        if DualPane.rightPane and DualPane.rightPane.currentMod and
            DualPane.rightPane.currentMod.group and DualPane.rightPane.currentMod.modUUID then
            local modUUID = DualPane.rightPane.currentMod.modUUID
            DualPane.rightPane:ReattachModGroup(modUUID)
            self:UpdateDetachButtons(modUUID)
        end
    end

    return self
end

function HeaderActions:CreateActionButton(text, icon, tooltip, multiplier)
    local button = self.group:AddImageButton(text, icon, IMGUIWidget:GetIconSizes(multiplier))

    -- Check if the image is not available and replace with text fallback if needed
    if not button.Image or button.Image.Icon == "" then
        button:Destroy()
        button = self.group:AddButton(text)
    end

    button.IDContext = "HeaderAction_" .. text .. "_BUTTON"
    MCMRendering:AddTooltip(button, tooltip, "HeaderAction_" .. text)
    return button
end

-- Update the visibility of toggle buttons based on whether the sidebar is collapsed.
-- If isCollapsed is true then show the expand button; otherwise, show the collapse button.
function HeaderActions:UpdateToggleButtons(isCollapsed)
    if self.expandBtn == nil or self.collapseBtn == nil then
        MCMError(0, "HeaderActions:UpdateToggleButtons: self.expandBtn or self.collapseBtn is nil")
        return
    end

    if isCollapsed then
        self.expandBtn.Visible = true
        self.collapseBtn.Visible = false
    else
        self.expandBtn.Visible = false
        self.collapseBtn.Visible = true
    end
end

-- Update the detach/reattach buttons based on the current mod's detachment state
-- This function should be called whenever switching mods or changing detachment state
function HeaderActions:UpdateDetachButtons(modUUID)
    if not DualPane or not DualPane.rightPane then return end

    if self.detachBtn == nil or self.reattachBtn == nil then
        MCMError(0, "HeaderActions:UpdateDetachButtons: self.detachBtn or self.reattachBtn is nil")
        return
    end

    -- If no modUUID is provided, use the current mod
    if not modUUID and DualPane.rightPane.currentMod then
        modUUID = DualPane.rightPane.currentMod.modUUID
    end

    if not modUUID then return end

    -- Check if the mod is detached
    local isDetached = DualPane.rightPane.detachedWindows and DualPane.rightPane.detachedWindows[modUUID] ~= nil

    -- Update button visibility
    self.detachBtn.Visible = not isDetached
    self.reattachBtn.Visible = isDetached

    MCMDebug(2, "Updated detach buttons for mod " .. modUUID .. ", isDetached: " .. tostring(isDetached))
end
