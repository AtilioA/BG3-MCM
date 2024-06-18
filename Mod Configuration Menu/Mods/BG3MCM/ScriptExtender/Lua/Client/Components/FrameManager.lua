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
    self.menuCell.ItemWidth = 100
    self.contentCell = row:AddCell()
end

---@param guidToShow string
function FrameManager:setVisibleFrame(guidToShow)
    for uuid, group  in pairs(self.contentGroups) do
        group.Visible = (guidToShow == uuid)
    end
end

---@param text string
function FrameManager:AddMenuSection(text)
    self.menuCell:AddSeparatorText(text)
end

---@param textButton string
---@param tooltipText string
---@param uuid string
---@return any the group to add Content associated to the button
function FrameManager:addButtonAndGetGroup(textButton, tooltipText, uuid)
    local menuButton = self:CreateMenuButton(self.menuCell, textButton, uuid)
    if tooltipText then
        self:AddTooltip(menuButton, tooltipText, uuid)
    end
    local group = self.contentCell:AddGroup(uuid)
    self.contentGroups[uuid] = group
    return group
end


---@param menuCell any
---@param text string
---@param uuid string
---@return any
function FrameManager:CreateMenuButton(menuCell, text, uuid)
    local button = menuCell:AddButton(text)
    button.IDContext = "Button"..uuid
    button.OnClick = function()
        self:setVisibleFrame(uuid)
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