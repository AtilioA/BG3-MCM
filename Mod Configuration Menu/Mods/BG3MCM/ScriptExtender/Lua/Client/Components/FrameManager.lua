---@class FrameManager: MetaClass
---@field menuCell any
---@field contentCell any
---@field contentGroups table<string, any>
FrameManager = _Class:Create("FrameManager", nil, {
    menuCell = nil,
    contentCell = nil,
    contentGroups = {}
})

function FrameManager:initFrameLayout(parent)
    if not parent then
        MCMWarn(0, "FrameManager:initFrameLayout called with invalid parameters")
        return
    end

    local layoutTable = parent:AddTable("MenuAndContent", 2)
    layoutTable:AddColumn("Menu", "WidthFixed")
    layoutTable:AddColumn("Frame", "WidthStretch")
    local row = layoutTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()
end

---@param uuidToShow string
function FrameManager:setVisibleFrame(uuidToShow)
    for uuid, group in pairs(self.contentGroups) do
        if group then
            group.Visible = (uuidToShow == uuid)
        end
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
---@param modUUID string
---@return any the group to add Content associated to the button
function FrameManager:addButtonAndGetModTabBar(modName, modDescription, modUUID)
    if not modName or not modUUID then
        MCMWarn(0, "addButtonAndGetModTabBar called with invalid parameters")
        return
    end

    modName = VCString:Wrap(modName, 33)

    local menuButton = self:CreateMenuButton(self.menuCell, modName, modUUID)
    if modDescription then
        IMGUILayer:AddTooltip(menuButton, modDescription, modUUID)
    end
    local uiGroupMod = self.contentCell:AddGroup(modUUID)

    uiGroupMod:AddSeparatorText(modName)
    if modDescription then
        local modDescriptionText = VCString:AddFullStop(modDescription)
        local descriptionTextObject = uiGroupMod:AddText(modDescriptionText)
        descriptionTextObject.TextWrapPos = 0
        uiGroupMod:AddDummy(0, 5)
    end

    self.contentGroups[modUUID] = uiGroupMod

    local modTabs = uiGroupMod:AddTabBar(modUUID .. "_TABS")
    modTabs.IDContext = modUUID .. "_TABS"

    return modTabs
end

---@param modUUID string
---@return any the group Content associated to modUUID
function FrameManager:GetGroup(modUUID)
    return self.contentGroups[modUUID]
end

---@param modUUID string
---@return any the group Content associated to modUUID
function FrameManager:GetModTabBar(modUUID)
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

--- Insert a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function FrameManager:InsertModTab(modUUID, tabName, tabCallback)
    if not MCM_WINDOW then
        return
    end
    local modTabBar = FrameManager:GetModTabBar(modUUID)

    if not modTabBar then
        local modData = Ext.Mod.GetMod(modUUID)
        MCMWarn(0, "'InsertModTab' called before any modTabBar created: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return
    end

    local newTab = modTabBar:AddTabItem(tabName)
    newTab.IDContext = modUUID .. "_" .. tabName

    newTab.UserData = newTab.UserData or {}
    if tabCallback and not newTab.UserData["Callback"] then
        newTab.UserData.Callback = tabCallback
        tabCallback(newTab)

        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ADDED, {
            modUUID = modUUID,
            tabName = tabName,
        })
    end

    newTab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
            modUUID = modUUID,
            tabName = tabName
        })
    end

    return newTab
end

---@param menuCell any
---@param text string
---@param uuid string
---@return any
function FrameManager:CreateMenuButton(menuCell, text, uuid)
    local button = menuCell:AddButton(text)
    button.IDContext = "MenuButton_" .. text .. "_" .. uuid
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
        if not MCMProxy.IsMainMenu() then
            ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ACTIVATED, {
                modUUID = uuid
            })
        end
    end
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    return button
end
