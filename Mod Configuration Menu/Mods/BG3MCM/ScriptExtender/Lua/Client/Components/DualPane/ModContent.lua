------------------------------------------------------------
-- ModContent Component
-- Manages the right pane (content area) including header actions and
-- mod-specific content groups (with tab containers).
------------------------------------------------------------
ModContent = {}
ModContent.__index = ModContent

function ModContent:new(parent)
    local self = setmetatable({}, ModContent)
    self.parent = parent -- Should be the contentScrollWindow
    self.contentGroups = {}
    -- Create a header for action buttons
    self.headerActions = {}
    self.headerActions.group = self.parent:AddGroup("HeaderActions")
    -- Create toggle buttons and set their OnClick to call DualPane:ToggleSidebar()
    self.headerActions.expandBtn = self:createActionButton("Toggle", ICON_TOGGLE_EXPAND, "Hide the sidebar", 1.25)
    self.headerActions.expandBtn.SameLine = true
    self.headerActions.collapseBtn = self:createActionButton("Collapse", ICON_TOGGLE_COLLAPSE, "Expand the sidebar", 1.25)
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
    self.headerActions.docBtn = self:createActionButton("Documentation", ICON_DOCS, "Show mod documentation", 1)
    self.headerActions.docBtn.SameLine = true
    self.headerActions.detachBtn = self:createActionButton("Detach mod page to a new window", ICON_DETACH, "Detach mod", 1)
    self.headerActions.detachBtn.SameLine = true
    return self
end

function ModContent:createActionButton(text, icon, tooltip, multiplier)
    local button = self.parent:AddImageButton(text, icon, IMGUIWidget:GetIconSizes(multiplier))
    button.IDContext = "HeaderAction_" .. text .. "_BUTTON"
    MCMRendering:AddTooltip(button, tooltip, "HeaderAction_" .. text)
    return button
end

-- Create a new group for a mod’s content, including a tab bar.
function ModContent:createModGroup(modUUID, modName, modDescription)
    local group = self.parent:AddGroup(modUUID)
    group:AddSeparatorText(modName)
    if modDescription then
        local desc = group:AddText(VCString:AddFullStop(modDescription))
        desc.TextWrapPos = 0
        group:AddDummy(0, 5)
    end
    self.contentGroups[modUUID] = group
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

function ModContent:getModGroup(modUUID)
    return self.contentGroups[modUUID]
end

function ModContent:createTab(modUUID, tabName)
    local group = self:getModGroup(modUUID)
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

function ModContent:insertTab(modUUID, tabName, callback)
    local tab = self:createTab(modUUID, tabName)
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

function ModContent:setVisibleGroup(modUUID)
    for uuid, group in pairs(self.contentGroups) do
        group.Visible = (uuid == modUUID)
    end
end
