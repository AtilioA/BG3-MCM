--------------------------------------------
-- RightPane Module
-- Manages the mod-specific content area (tabs, groups, etc.)
--------------------------------------------

RightPane = {}
RightPane.__index = RightPane

function RightPane:New(parent)
    local self = setmetatable({}, RightPane)
    -- Should:tm: be the contentScrollWindow
    self.parent = parent
    self.contentGroups = {}
    -- Table to track detached windows keyed by mod group handle
    self.detachedWindows = {}
    -- Will hold the currently active mod group info
    self.currentMod = { group = nil, modUUID = nil }
    return self
end

function RightPane:CreateModGroup(modUUID, modName, modDescription)
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
    tab.IDContext = modUUID .. "_" .. tabName .. "_TAB"
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

function RightPane:InsertTab(modUUID, tabName, callback)
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

-- Set visible groups and update header detach/reattach buttons based on the current mod.
function RightPane:SetVisibleGroup(modUUID)
    for uuid, group in pairs(self.contentGroups) do
        -- Only update groups that are attached (i.e. not detached)
        if not self.detachedWindows[group.Handle] then
            group.Visible = (uuid == modUUID)
        end
    end
    if self.contentGroups[modUUID] then
        self.currentMod = { group = self.contentGroups[modUUID], modUUID = modUUID }
        local group = self.currentMod.group
        if self.detachedWindows[group.Handle] then
            HeaderActionsInstance.detachBtn.Visible = false
            HeaderActionsInstance.reattachBtn.Visible = true
        else
            HeaderActionsInstance.detachBtn.Visible = true
            HeaderActionsInstance.reattachBtn.Visible = false
        end
    end
end

local function createDetachedWindow(name)
    local detachedWindow = Ext.IMGUI.NewWindow(name)
    local minSize = Ext.IMGUI.GetViewportSize()
    detachedWindow:SetStyle("WindowMinSize", minSize[1] / 3, minSize[2] / 3)
    return detachedWindow
end

function RightPane:DetachModGroup(modUUID)
    local group = self.contentGroups[modUUID]
    if not group then
        MCMError(0, "Tried to detach non-existent mod group for " .. modUUID)
        return
    end
    local handle = group.Handle
    if self.detachedWindows[handle] then
        MCMError(0, "Mod group " .. modUUID .. " is already detached.")
        return
    end
    local newWindow = createDetachedWindow("Detached view for mod: " .. Ext.Mod.GetMod(modUUID).Info.Name)
    local parent = group.ParentElement
    parent:DetachChild(group)
    newWindow:AttachChild(group)
    self.detachedWindows[handle] = newWindow
    newWindow.Closeable = true
    newWindow.OnClose = function() self:ReattachModGroup(modUUID) end

    -- Optionally add a temporary message inside the detached window (if desired)
    -- local tempText = parent:AddText("This mod's content is detached. Click the reattach button to reattach.")
    -- tempText.TextWrapPos = 0
    -- tempText:SetColor("Text", Color.NormalizedRGBA(255, 0, 0, 1))
    -- newWindow.UserData = {
    --     tempText = tempText
    -- }

    HeaderActionsInstance.detachBtn.Visible = false
    HeaderActionsInstance.reattachBtn.Visible = true
end

-- Reattach the mod content group from its detached window back to the parent.
function RightPane:ReattachModGroup(modUUID)
    local group = self.contentGroups[modUUID]
    if not group then
        MCMError(0, "Tried to reattach non-existent mod group for " .. modUUID)
        return
    end

    local handle = group.Handle
    if not self.detachedWindows[handle] then
        MCMWarn(0, "Mod group " .. modUUID .. " is not detached.")
        return
    end

    local detachedWin = self.detachedWindows[handle]
    detachedWin:DetachChild(group)
    self.parent:AttachChild(group)

    -- Remove the temporary text from the parent if needed (added to UserData for convenience)
    if detachedWin.UserData and detachedWin.UserData.tempText then
        detachedWin.UserData.tempText:Destroy()
    end

    detachedWin:Destroy()
    self.detachedWindows[handle] = nil
    if #group.Children > 0 then
        group:RemoveChild(group.Children[#group.Children])
    end
    -- Update header: show detach button, hide reattach button.
    HeaderActionsInstance.detachBtn.Visible = true
    HeaderActionsInstance.reattachBtn.Visible = false
end

-- Toggle detach/reattach based on current state.
function RightPane:ToggleDetach(modUUID)
    local group = self.contentGroups[modUUID]
    if not group then return end
    if self.detachedWindows[group.Handle] then
        self:ReattachModGroup(modUUID)
    else
        self:DetachModGroup(modUUID)
    end
end
