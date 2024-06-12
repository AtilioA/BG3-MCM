-- TODO: clean this up and document it

---@class ListIMGUIWidget: IMGUIWidget
ListIMGUIWidget = _Class:Create("ListIMGUIWidget", IMGUIWidget)

function ListIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = ListIMGUIWidget })
    instance.Widget = { List = initialValue or {} }
    instance.Widget.Group = group
    instance.Widget.ModGUID = modGUID
    instance.Widget.Setting = setting

    instance.Widget.TableGroup = group:AddGroup("ListTableGroup" .. setting.Id)
    instance.Widget.InputGroup = group:AddGroup("ListInputGroup" .. setting.Id)

    instance:RenderList()
    instance:AddInputAndAddButton()

    return instance
end

function ListIMGUIWidget:RenderList()
    local imguiTable = self.Widget.TableGroup:AddTable("", 2)
    for i, value in ipairs(self.Widget.List) do
        local tableRow = imguiTable:AddRow()
        local textCell = tableRow:AddCell()
        local buttonCell = tableRow:AddCell()

        textCell:AddText(value)
        local removeButton = buttonCell:AddButton("[X]")
        removeButton.OnClick = function()
            table.remove(self.Widget.List, i)
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, self.Widget.List, self.Widget.ModGUID)
            self:Refresh()
        end
    end
end

function ListIMGUIWidget:AddInputAndAddButton()
    if not self.Widget.List then
        self.Widget.List = {}
    elseif type(self.Widget.List) ~= "table" then
        self.Widget.List = { self.Widget.List }
    end

    local newText = ""
    local textInput = self.Widget.InputGroup:AddInputText("", newText)
    textInput.OnChange = function(newValue)
        newText = newValue.Text
    end

    local addButton = self.Widget.InputGroup:AddButton("Add")
    addButton.OnClick = function()
        if newText ~= "" then
            table.insert(self.Widget.List, newText)
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, self.Widget.List, self.Widget.ModGUID)
            self:Refresh()
        end
    end
end

local function clearGroup(group)
    if not group then
        return
    end
    for _, child in ipairs(group.Children or {}) do
        child:Destroy()
    end
end

function ListIMGUIWidget:Refresh()
    clearGroup(self.Widget.TableGroup)
    self:RenderList()
end

function ListIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.List = value
    self:Refresh()
end
