 ---@class FrameManager: MetaClass
FrameManager = _Class:Create("FrameManager", nil, {
    menuCell = nil,
    contentCell = nil,
    modGroups = {}
})


function FrameManager:initFrameLayout(parent)
    local modsTable = parent:AddTable("MenuAndContent", 2)
    modsTable:AddColumn("Menu", "WidthFixed")
    modsTable:AddColumn("Frame", "WidthStretch")
    local row = modsTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()
end



function FrameManager:setVisibleFrame(guidToShow)
    for modGUID, modGroup  in pairs(self.modGroups) do
        modGroup.Visible = (guidToShow == modGUID)
    end
end


function FrameManager:AddMenuSection(text)
    self.menuCell:AddSeparatorText(text)
end


function FrameManager:addButtonAndGetGroup(textButton, tooltipText, uuid)
    local modButton = self:CreateModButton(self.menuCell, textButton, uuid)
    if tooltipText then
        self:AddModTooltip(modButton, tooltipText, uuid)
    end
    local group = self.contentCell:AddGroup(uuid)
    self.modGroups[uuid] = group
    return group
end


---@param modsTree any
---@param text string
---@param uuid string
---@return any
function FrameManager:CreateModButton(menuCell, text, uuid)
    local modItem = menuCell:AddButton(text)
    modItem.IDContext = uuid
    modItem.OnClick = function()
        self:setVisibleFrame(uuid)
    end
    modItem:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    return modItem
end

--- Add a tooltip to a mod item with the mod description
---@param modItem any
---@param uuid string
---@return nil
function FrameManager:AddModTooltip(modItem, tooltipText, uuid)
    local modTabTooltip = modItem:Tooltip()
    modTabTooltip.IDContext = uuid .. "_TOOLTIP"
    modTabTooltip:AddText(tooltipText)
end