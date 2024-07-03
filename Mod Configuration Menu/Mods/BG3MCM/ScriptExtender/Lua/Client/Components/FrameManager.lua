---@class FrameManager: MetaClass
FrameManager = _Class:Create("FrameManager", nil, {
    menuCell = nil,
    contentCell = nil,
    contentGroups = {}
})


function FrameManager:initFrameLayout(parent)
    local layoutTable = parent:AddTable("MenuAndContent", 2)
    layoutTable:AddColumn("Menu", "WidthFixed")
    layoutTable:AddColumn("Frame", "WidthStretch")
    local row = layoutTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()
end

---@param guidToShow string
function FrameManager:setVisibleFrame(guidToShow)
    for uuid, group in pairs(self.contentGroups) do
        group.Visible = (guidToShow == uuid)
    end
end

---@param text string
function FrameManager:AddMenuSection(text)
    -- local modsListIcon = self.menuCell:AddImage("ico_identity_d", {40, 40})
    -- modsListIcon.SameLine = true
    self.menuCell:AddSeparatorText(text)
end

---@param modName string
---@param modDescription string
---@param uuid string
---@return any the group to add Content associated to the button
function FrameManager:addButtonAndGetModTabBar(modName, modDescription, modGUID)
    if not modName or not modGUID then
        MCMWarn(0, "addButtonAndGetModTabBar called with invalid parameters")
        return
    end

    modName = VCString:Wrap(modName, 33)

    local menuButton = self:CreateMenuButton(self.menuCell, modName, modGUID)
    if modDescription then
        self:AddTooltip(menuButton, modDescription, modGUID)
    end
    local uiGroupMod = self.contentCell:AddGroup(modGUID)

    uiGroupMod:AddSeparatorText(modName)
    if modDescription then
        local modDescription = VCString:AddFullStop(VCString:Wrap(modDescription, 60))
        uiGroupMod:AddText(modDescription)
        uiGroupMod:AddDummy(0, 5)
    end

    self.contentGroups[modGUID] = uiGroupMod

    local modTabs = uiGroupMod:AddTabBar(modGUID .. "_TABS")
    modTabs.IDContext = modGUID .. "_TABS"

    return modTabs
end

---@param uuid string
---@return any the group Content associated to uuid
function FrameManager:GetGroup(uuid)
    return self.contentGroups[uuid]
end

---@param uuid string
---@return any the group Content associated to uuid
function FrameManager:GetModTabBar(uuid)
    for _, child in ipairs(self.contentGroups[uuid].Children) do
        if child.IDContext and child.IDContext:sub(-5) == "_TABS" then
            return child
        end
    end
    return nil
end

--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function FrameManager:InsertModTab(modGUID, tabName, tabCallback)
    if not MCM_WINDOW then
        return
    end
    local modTabBar = FrameManager:GetModTabBar(modGUID)

    if not modTabBar then
        local modData = Ext.Mod.GetMod(modGUID)
        MCMWarn(0, "'InsertModTab' called before any modTabBarCreated: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    local newTab = modTabBar:AddTabItem(tabName)
    newTab.IDContext = modGUID .. "_" .. tabName
    newTab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        Ext.Net.PostMessageToServer(Channels.MCM_MOD_SUBTAB_ACTIVATED, Ext.Json.Stringify({
            modGUID = modGUID,
            tabName = tabName
        }))
    end
    tabCallback(newTab)
    Ext.Net.PostMessageToServer(Channels.MCM_MOD_TAB_ADDED, Ext.Json.Stringify({
        modGUID = modGUID,
        tabName = tabName
    }))

    return newTab
end

---@param menuCell any
---@param text string
---@param uuid string
---@return any
function FrameManager:CreateMenuButton(menuCell, text, uuid)
    local button = menuCell:AddButton(text)
    button.IDContext = "Button" .. uuid
    button.OnClick = function()
        self:setVisibleFrame(uuid)
        MCMDebug(2, "Set mod Visible : " .. button.IDContext)
        for _, c in ipairs(menuCell.Children) do
            if c == button then
                c:SetColor("Button", UIStyle.Colors["ButtonActive"])
            else
                c:SetColor("Button", UIStyle.Colors["Button"])
            end
        end
        Ext.Net.PostMessageToServer(Channels.MCM_RELAY_TO_CLIENTS, Ext.Json.Stringify({
            channel = Channels.MCM_MOD_TAB_ACTIVATED,
            payload = {
                modGUID = uuid
            }
        }))
    end
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    return button
end

--- Add a tooltip to a button
---@param button any
---@param tooltipText string
---@param uuid string
---@return nil
function FrameManager:AddTooltip(button, tooltipText, uuid)
    local buttonTooltip = button:Tooltip()
    buttonTooltip.IDContext = uuid .. "_TOOLTIP"
    buttonTooltip:AddText(tooltipText)
end
