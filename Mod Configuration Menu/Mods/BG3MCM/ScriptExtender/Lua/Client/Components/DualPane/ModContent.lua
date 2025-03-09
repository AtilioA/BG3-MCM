------------------------------------------------------------
-- ModContent Component
-- Manages the right pane (content area) including header actions and
-- mod-specific content groups (with tab containers).
------------------------------------------------------------
ModContent = {}
ModContent.__index = ModContent

function ModContent:New(parent)
    local self = setmetatable({}, ModContent)
    -- Should:tm: be the contentScrollWindow
    self.parent = parent
    self.contentGroups = {}
    -- Table to track detached windows keyed by mod group handle
    self.detachedWindows = {}
    -- Will hold the currently active mod group info
    self.currentMod = {
        group = nil,
        modUUID = nil
    }

    -- Create a header for action buttons
    self.headerActions = {}
    self.headerActions.group = self.parent:AddGroup("HeaderActions")
    -- Create toggle buttons and set their OnClick to call DualPane:ToggleSidebar()
    self.headerActions.expandBtn = self:CreateActionButton("Toggle", ICON_TOGGLE_EXPAND, "Hide the sidebar", 1.5)
    self.headerActions.expandBtn.SameLine = true
    self.headerActions.collapseBtn = self:CreateActionButton("Collapse", ICON_TOGGLE_COLLAPSE, "Expand the sidebar", 1.25)
    self.headerActions.collapseBtn.SameLine = true
    self.headerActions.expandBtn.OnClick = function() DualPane:ToggleSidebar() end
    self.headerActions.collapseBtn.OnClick = function() DualPane:ToggleSidebar() end
    -- Initialize visibility based on current state
    if DualPane and DualPane.isCollapsed then
        self.headerActions.expandBtn.Visible = true
        self.headerActions.collapseBtn.Visible = false
    else
        self.headerActions.expandBtn.Visible = false
        self.headerActions.collapseBtn.Visible = true
    end
    local dummy = self.parent:AddDummy(10, 0)
    dummy.SameLine = true
    self.headerActions.docBtn = self:CreateActionButton("Documentation", ICON_DOCS, "Show mod documentation", 1)
    self.headerActions.docBtn.SameLine = true
    self.headerActions.detachBtn = self:CreateActionButton("Detach mod page to a new window", ICON_DETACH, "Detach mod",
        1)
    self.headerActions.detachBtn.SameLine = true
    self.headerActions.detachBtn.OnClick = function()
        if self.currentMod and self.currentMod.group and self.currentMod.modUUID then
            self:ToggleDetach(self.currentMod.modUUID)
        end
    end
    return self
end

function ModContent:CreateActionButton(text, icon, tooltip, multiplier)
    local button = self.parent:AddImageButton(text, icon, IMGUIWidget:GetIconSizes(multiplier))
    button.IDContext = "HeaderAction_" .. text .. "_BUTTON"
    MCMRendering:AddTooltip(button, tooltip, "HeaderAction_" .. text)
    return button
end

-- Create a new content group for a mod, including a tab bar.
function ModContent:CreateModGroup(modUUID, modName, modDescription)
    local group = self.parent:AddGroup(modUUID)
    group:AddSeparatorText(modName)
    if modDescription then
        local desc = group:AddText(VCString:AddFullStop(modDescription))
        desc.TextWrapPos = 0
        group:AddDummy(0, 5)
    end
    self.contentGroups[modUUID] = group
    self.currentMod = { group = group, modUUID = modUUID }
    local modTabBar = group:AddTabBar(modUUID .. "_TABS")
    modTabBar.IDContext = modUUID .. "_TABS"
    -- self.contentGroups[modUUID] = { group = group, tabBar = nil }
    -- self.contentGroups[modUUID].tabBar = group:AddTabBar(modUUID .. "_TABS")
    -- self.contentGroups[modUUID].tabBar.IDContext = modUUID .. "_TABS"
    return group
end

function ModContent:GetModTabBar(modUUID)
    if not self.contentGroups or not self.contentGroups[modUUID] then
        return nil
    end

    if table.isEmpty(self.contentGroups[modUUID].Children) then
        return nil
    end

    for _, child in ipairs(self.contentGroups[modUUID].Children) do
        if child.IDContext and child.IDContext:sub(-5) == "_TABS" then
            return child
        end
    end
    return nil
end

function ModContent:GetModGroup(modUUID)
    return self.contentGroups[modUUID]
end

function ModContent:CreateTab(modUUID, tabName)
    local group = self:GetModGroup(modUUID)
    local modTabBar = self:GetModTabBar(modUUID)
    if not group or not modTabBar then return nil end
    local tab = modTabBar:AddTabItem(tabName)
    tab.IDContext = modUUID .. "_" .. tabName
    tab.UserData = tab.UserData or {}
    tab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
            modUUID = modUUID,
            tabName = tabName
        })
    end
    return tab
end

function ModContent:InsertTab(modUUID, tabName, callback)
    local tab = self:CreateTab(modUUID, tabName)
    if tab and callback then
        tab.UserData.Callback = callback
        xpcall(function()
            callback(tab)
        end, function(err)
            MCMWarn(0,
                "Callback failed for mod " ..
                Ext.Mod.GetMod(modUUID).Info.Name ..
                ": " .. err .. "\nPlease contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        end)
        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ADDED, {
            modUUID = modUUID,
            tabName = tabName
        })
    end
    return tab
end

-- Update visibility: only update groups that are attached to the parent.
function ModContent:SetVisibleGroup(modUUID)
    for uuid, group in pairs(self.contentGroups) do
        -- If the group is detached (exists in detachedWindows), skip updating its Visible property.
        if not self.detachedWindows[group.Handle] then
        group.Visible = (uuid == modUUID)
        end
    end
    if self.contentGroups[modUUID] then
        self.currentMod = { group = self.contentGroups[modUUID], modUUID = modUUID }
    end
end

local function createDetachedWindow(name)
    local detachedWindow = Ext.IMGUI.NewWindow(name)
    local minSize = Ext.IMGUI.GetViewportSize()
    detachedWindow:SetStyle("WindowMinSize", minSize[1] / 3, minSize[2] / 3)
    return detachedWindow
end

-- Toggle detach/attach of a mod content group.
-- When detached, the group is removed from the contentScrollWindow and attached to a new window.
-- When reattached, the group is moved back.
function ModContent:ToggleDetach(modUUID)
    local group = self.contentGroups[modUUID]

    if not group then
        MCMError(0, "Tried to detach non-existent mod group for " .. modUUID)
        return
    end

    local handle = group.Handle
    self.detachedWindows = self.detachedWindows or {}
    if self.detachedWindows[handle] then
        -- Reattach: detach group from the detached window and attach it back to parent.
        MCMDebug(1, "Reattaching " .. modUUID)
        local detachedWin = self.detachedWindows[handle]
        detachedWin:DetachChild(group)
        self.parent:AttachChild(group)

        detachedWin:Destroy()
        self.detachedWindows[handle] = nil
    else
        -- Detach: create new window, detach group from parent, and attach to new window.
        MCMDebug(1, "Detaching " .. modUUID)
        local newWindow = createDetachedWindow("Mod: " .. modUUID)
        local parent = group.ParentElement
        parent:DetachChild(group)
        newWindow:AttachChild(group)

        self.detachedWindows[handle] = newWindow
        newWindow.Closeable = true
        newWindow.OnClose = function()
            MCMDebug(1, "Closing detached window for " .. modUUID)
            self:ToggleDetach(modUUID)
        end
    end
end
