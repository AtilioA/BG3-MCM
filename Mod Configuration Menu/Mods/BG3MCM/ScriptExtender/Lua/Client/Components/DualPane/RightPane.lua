--------------------------------------------
-- RightPane Module
-- Manages the mod-specific content area (tabs, groups, etc.)
--------------------------------------------

---@class RightPane
---@field parent ExtuiStyledRenderable
---@field contentGroups table
---@field detachedWindows table
---@field currentMod table<string, any>
RightPane = _Class:Create("RightPane", nil, {
    parent = nil,
    contentGroups = nil,
    detachedWindows = nil,
    currentMod = nil,
})
RightPane.__index = RightPane

function RightPane:New(parent)
    local self = setmetatable({}, RightPane)
    -- Should:tm: be the contentScrollWindow
    self.parent = parent
    self.contentGroups = {}
    -- Table to track detached windows keyed by mod UUID (not by handle)
    self.detachedWindows = {}
    -- Will hold the currently active mod group info
    self.currentMod = { group = nil, modUUID = nil }
    return self
end

function RightPane:CreateModGroup(modUUID, modName, modDescription)
    local group = self.parent:AddGroup(modUUID)
    local modNameWidget = group:AddSeparatorText(modName)
    group.UserData = group.UserData or {}
    group.UserData.modNameWidget = modNameWidget
    if modDescription and modDescription ~= "" then
        local desc = group:AddText(VCString:AddFullStop(modDescription))
        desc.TextWrapPos = 0
        group:AddDummy(0, 5)
    end
    self.contentGroups[modUUID] = group
    self.currentMod = { group = group, modUUID = modUUID }
    local modTabBar = group:AddTabBar(modUUID .. "_TABS")
    modTabBar.IDContext = modUUID .. "_TABS"
    return group
end

--- Get the TabBar for the specified modUUID
--- @param modUUID any
--- @return nil|ExtuiTabBar
function RightPane:GetModTabBar(modUUID)
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

function RightPane:GetModGroup(modUUID)
    return self.contentGroups[modUUID]
end

function RightPane:CreateTab(modUUID, tabName)
    local group = self:GetModGroup(modUUID)
    local modTabBar = self:GetModTabBar(modUUID)
    if not group or not modTabBar then return nil end

    local tab = modTabBar:AddTabItem(tabName)

    local tabId = DualPaneController:GenerateTabId(modUUID, tabName)
    tab.IDContext = DualPaneController:GenerateTabId(modUUID, tabName)
    tab.UserData = tab.UserData or {}
    tab.UserData.tabId = tabId
    tab.UserData.tabName = tabName

    tab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
            modUUID = modUUID,
            tabName = tabName
        }, true)
    end

    return tab
end

function RightPane:InsertTab(modUUID, tabName, callback)
    local tab = self:CreateTab(modUUID, tabName)
    if tab and callback then
        tab.UserData.Callback = callback
        xpcall(function()
            callback(tab)
        end, function(err)
            MCMError(0,
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

-- Set visible groups and update header detach/reattach buttons based on the current mod.
function RightPane:SetVisibleGroup(modUUID)
    -- Update visibility for all content groups
    for uuid, group in pairs(self.contentGroups) do
        -- Skip visibility update for detached groups
        if not self.detachedWindows[uuid] then
            -- Only make the requested mod visible
            group.Visible = (uuid == modUUID)

            -- Debug info
            MCMDebug(3, "Setting visibility for mod " .. uuid .. " to " .. tostring(group.Visible))
        else
            MCMDebug(3, "Skipping visibility update for detached mod " .. uuid)
        end
    end

    -- Update current mod reference
    if self.contentGroups[modUUID] then
        self.currentMod = {
            group = self.contentGroups[modUUID],
            modUUID = modUUID
        }

        -- Use HeaderActions to update detach/reattach buttons based on current mod
        if HeaderActionsInstance then
            HeaderActionsInstance:UpdateDetachButtons(modUUID)
        end
    end
end

local function createDetachedWindow(name)
    local detachedWindow = Ext.IMGUI.NewWindow(name)
    local minSize = Ext.IMGUI.GetViewportSize()
    detachedWindow:SetStyle("WindowMinSize", minSize[1] / 6, minSize[2] / 6)
    return detachedWindow
end

function RightPane:DetachModGroup(modUUID)
    local group = self.contentGroups[modUUID]
    if not group then
        MCMError(0, "Tried to detach non-existent mod group for " .. modUUID)
        return
    end

    if self.detachedWindows[modUUID] then
        MCMError(0, "Mod group " .. modUUID .. " is already detached.")
        return
    end

    -- Hide modNameWidget when detached
    if group.UserData and group.UserData.modNameWidget then
        group.UserData.modNameWidget.Visible = false
    end

    local newWindow = createDetachedWindow(VCString:InterpolateLocalizedMessage("hb341a515eea64380ad0ccfe6c1ff115d1310",
        Ext.Mod.GetMod(modUUID).Info.Name))
    local parent = group.ParentElement

    -- Store parent reference and mod UUID in the window's UserData for proper reattachment
    newWindow.UserData = {
        originalParent = parent,
        modUUID = modUUID,
        originalHandle = group.Handle -- Store the original handle for verification
    }

    MCMDebug(1, "Detaching mod group " .. modUUID .. " with handle " .. tostring(group.Handle))
    parent:DetachChild(group)
    newWindow:AttachChild(group)
    self.detachedWindows[modUUID] = newWindow
    newWindow.Closeable = true
    newWindow.OnClose = function() self:ReattachModGroup(modUUID) end

    -- Update button visibility through HeaderActions
    if HeaderActionsInstance then
        HeaderActionsInstance:UpdateDetachButtons(modUUID)
    end

    DualPane:Expand()
end

-- Reattach the mod content group from its detached window back to the parent.
function RightPane:ReattachModGroup(modUUID)
    local group = self.contentGroups[modUUID]
    if not group then
        MCMError(0, "Tried to reattach non-existent mod group for " .. modUUID)
        return
    end

    if not self.detachedWindows[modUUID] then
        MCMWarn(0, "Mod group " .. modUUID .. " is not detached.")
        return
    end

    -- Show modNameWidget when reattached
    if group.UserData and group.UserData.modNameWidget then
        group.UserData.modNameWidget.Visible = true
    end

    local detachedWin = self.detachedWindows[modUUID]
    local tabBar = nil

    -- Find the tab bar before detachment to preserve reference
    if #group.Children > 0 then
        for _, child in ipairs(group.Children) do
            if child.IDContext and child.IDContext:sub(-5) == "_TABS" then
                tabBar = child
                break
            end
        end
    end

    MCMDebug(1, "Reattaching mod group " .. modUUID .. " with handle " .. tostring(group.Handle))

    -- Get the correct parent to reattach to
    local targetParent = detachedWin.UserData and detachedWin.UserData.originalParent or self.parent

    -- Store children count before detaching
    local childrenBefore = #group.Children
    MCMDebug(1, "Children before detach: " .. childrenBefore .. ", tabBar: " .. tostring(tabBar ~= nil))

    -- Detach from window and reattach to original parent
    detachedWin:DetachChild(group)
    targetParent:AttachChild(group)

    -- Check if children were preserved
    local childrenAfter = #group.Children
    MCMDebug(1, "Children after reattach: " .. childrenAfter)

    -- Make sure the group visibility is set correctly based on current mod
    group.Visible = (modUUID == self.currentMod.modUUID)

    -- Destroy the detached window and clean up references
    detachedWin:Destroy()
    self.detachedWindows[modUUID] = nil

    -- Update button visibility through HeaderActions
    if HeaderActionsInstance then
        HeaderActionsInstance:UpdateDetachButtons(modUUID)
    end
end

-- Update header buttons visibility based on detachment state
-- Legacy function, use HeaderActions:UpdateDetachButtons instead
function RightPane:UpdateDetachButtons()
    if HeaderActionsInstance then
        if self.currentMod and self.currentMod.modUUID then
            HeaderActionsInstance:UpdateDetachButtons(self.currentMod.modUUID)
        end
    end
end
