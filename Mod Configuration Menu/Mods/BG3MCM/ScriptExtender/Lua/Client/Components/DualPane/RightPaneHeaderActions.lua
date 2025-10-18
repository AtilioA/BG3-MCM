--------------------------------------------
-- HeaderActions Module
-- Manages the header action buttons independently.
--------------------------------------------

HeaderActions = {}
HeaderActions.__index = HeaderActions

-- REFACTOR: replace DualPane.rightPane calls with encapsulation

function HeaderActions:New(parent)
    local self = setmetatable({}, HeaderActions)
    self.group = parent:AddGroup("HeaderActions")

    -- Create toggle buttons and set their OnClick to call DualPane:ToggleSidebar()
    self.expandBtn = self:CreateActionButton("[Show mods]", ICON_TOGGLE_EXPAND,
        VCString:InterpolateLocalizedMessage("hbb483085e7f04700beb8cc5bf94a98b4g6ac",
            KeyPresentationMapping:GetViewKeyForSetting("toggle_mcm_sidebar_keybinding", ModuleUUID)), 1.5)
    self.expandBtn.SameLine = true
    self.collapseBtn = self:CreateActionButton("[Hide mods]", ICON_TOGGLE_COLLAPSE,
        VCString:InterpolateLocalizedMessage("h4e0e208daa6a439ca5ba95a668a7ac36d882",
            KeyPresentationMapping:GetViewKeyForSetting("toggle_mcm_sidebar_keybinding", ModuleUUID)), 1.5)
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

    -- Keybinding indicator: shows when current mod has assigned hotkeys.
    self.keybindingsIndicator = self:CreateActionButton(
    "[" .. Ext.Loca.GetTranslatedString("h1574a7787caa4e5f933e2f03125a539c1139") .. "]", nil,
        Ext.Loca.GetTranslatedString("hdbcd16c5f55e4e9c800e7284ebef8b0f5372"), 1)
    self.keybindingsIndicator.SameLine = true
    self.keybindingsIndicator.Disabled = false
    self.keybindingsIndicator.Visible = false
    self.keybindingsIndicator.OnClick = function()
        if not DualPane or not DualPane.rightPane or not DualPane.rightPane.currentMod then return end
        local modUUID = DualPane.rightPane.currentMod.modUUID
        if not modUUID or modUUID == "" then return end

        -- Navigate to the Hotkeys page
        -- TODO: focus the mod
        if DualPane and DualPane.OpenKeybindingsPage then
            DualPane:OpenKeybindingsPage(modUUID)
        end
    end

    -- React to keybindings registry updates so the indicator stays in sync.
    if KeybindingsRegistry and KeybindingsRegistry.GetSubject then
        self._kbSubscription = KeybindingsRegistry:GetSubject():Subscribe(function()
            self:UpdateKeybindingIndicator()
        end)
    end

    -- Initial state for indicator.
    self:UpdateKeybindingIndicator()

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
    IMGUIHelpers.AddTooltip(button, tooltip, "HeaderAction_" .. text)
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

--- Updates the keybinding indicator visibility and tooltip for the current or provided mod
---@param modUUID string|nil
function HeaderActions:UpdateKeybindingIndicator(modUUID)
    if not self.keybindingsIndicator then return end

    -- Resolve modUUID from current context if not provided
    if (not modUUID) and DualPane and DualPane.rightPane and DualPane.rightPane.currentMod then
        modUUID = DualPane.rightPane.currentMod.modUUID
    end

    if not modUUID then
        self.keybindingsIndicator.Visible = false
        return
    end

    local hasAssigned = KeybindingsRegistry and KeybindingsRegistry.HasKeybindings
        and KeybindingsRegistry.HasKeybindings(modUUID) or false

    if not hasAssigned then
        self.keybindingsIndicator.Visible = false
        return
    end

    -- If we have assigned hotkeys, show the indicator and ensure tooltip is informative
    self.keybindingsIndicator.Visible = true

    -- Count assigned actions to enrich tooltip
    -- local count = 0
    -- local filtered = KeybindingsRegistry.GetFilteredRegistry and KeybindingsRegistry.GetFilteredRegistry() or {}
    -- local nActions = #filtered[modUUID] or 0

    -- local modName = (MCMClientState and MCMClientState.GetModName and MCMClientState:GetModName(modUUID)) or modUUID
    -- local tooltip = string.format("%s has %d assigned hotkey%s. Click to open Hotkeys.", tostring(modName), nActions, nActions == 1 and "" or "s")
    -- IMGUIHelpers.AddTooltip(self.keybindingsIndicator, tooltip, "HeaderAction_[Hotkeys]")
end
