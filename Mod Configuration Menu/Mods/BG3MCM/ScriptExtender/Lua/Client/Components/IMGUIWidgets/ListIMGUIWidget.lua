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

        local textObject = textCell:AddText(value)
        textObject.TextWrapPos = 0

        local removeButton = buttonCell:AddImageButton("[X]", "popin_closeIco_d", IMGUIWidget:GetIconSizes())

        if not removeButton.Image or removeButton.Image.Icon == "" then
            removeButton:Destroy()
            removeButton = buttonCell:AddButton(Ext.Loca.GetTranslatedString("hc8ac6fff0508437d936bb1ae51e9a3dfc8a0") or
                "[X]")
        end

        local tooltip = removeButton:Tooltip()
        tooltip:AddText(VCString:InterpolateLocalizedMessage("hb5b5a421b3504260bcd72028b4311c4352a8", value))
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
            addButton.Label = Ext.Loca.GetTranslatedString("hf19a6659055c484797ca4f7e0b60706eff45") or "Add to the list"
        else
            addButton.Label = Ext.Loca.GetTranslatedString("hc51c15db9485404a8023ffcff47d58ee7b72") or
                "Type a new value to add to the list"
        end
    end

    addButton = self.Widget.InputGroup:AddButton(Ext.Loca.GetTranslatedString("hc51c15db9485404a8023ffcff47d58ee7b72") or
        "Type a new value to add to the list")
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
    local resetButton = group:AddButton(Ext.Loca.GetTranslatedString("hefc87cc64ef74547b4ccade4ff1676994d53") or
        "[Reset list]")
    resetButton.IDContext = modUUID .. "_" .. "ResetButton_" .. setting:GetId()
    resetButton:Tooltip():AddText(Ext.Loca.GetTranslatedString("ha0f6f33bf8ca456aa02f9dc8811b2c5a6324") or
        "Reset this list to its default values")
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modUUID)
    end
    resetButton.SameLine = true
end
