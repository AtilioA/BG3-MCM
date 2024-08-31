-- TODO: clean this up and document it

---@class ListIMGUIWidget: IMGUIWidget
ListIMGUIWidget = _Class:Create("ListIMGUIWidget", IMGUIWidget)

function ListIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = ListIMGUIWidget })
    instance.Widget = { List = initialValue or {} }
    instance.Widget.Group = group
    instance.Widget.modUUID = modUUID
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
        local removeButton = buttonCell:AddImageButton("[X]", "popin_closeIco_d", { 40, 40 })

        if not removeButton.Image or removeButton.Image.Icon == "" then
            removeButton:Destroy()
            removeButton = buttonCell:AddButton("[X]")
        end

        local tooltip = removeButton:Tooltip()
        tooltip:AddText("Remove '" .. value .. "' from the list")
        removeButton.OnClick = function()
            table.remove(self.Widget.List, i)
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, self.Widget.List, self.Widget.modUUID)
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
    local addButton
    textInput.OnChange = function(newValue)
        newText = newValue.Text
        if newText and newText ~= "" and addButton then
            addButton.Label = "Add to the list"
        else
            addButton.Label = "Type a new value to add to the list"
        end
    end

    addButton = self.Widget.InputGroup:AddButton("Type a new value to add to the list")
    addButton.OnClick = function()
        if newText ~= "" then
            -- TODO: remove this kludge
            if not self.Widget.List then
                self.Widget.List = {}
            elseif type(self.Widget.List) ~= "table" then
                self.Widget.List = { self.Widget.List }
            end

            table.insert(self.Widget.List, newText)
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, self.Widget.List, self.Widget.modUUID)
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

--- Add a reset button to the widget
---@param group any The IMGUI group to add the button to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param modUUID string The UUID of the mod that owns this widget
---@return nil
---@see IMGUIAPI:ResetSettingValue
function ListIMGUIWidget:AddResetButton(group, setting, modUUID)
    local resetButton = group:AddButton("[Reset list]")
    resetButton.IDContext = modUUID .. "_" .. "ResetButton_" .. setting:GetId()
    resetButton:Tooltip():AddText("Reset this list to its default values")
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modUUID)
    end
    resetButton.SameLine = true
end
