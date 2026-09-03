---@class DragIntIMGUIWidget: IMGUIWidget
DragIntIMGUIWidget = _Class:Create("DragIntIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue integer
---@param modUUID string
---@return DragIntIMGUIWidget
function DragIntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = DragIntIMGUIWidget })
    instance.Widget = group:AddDragInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = VCTimer:Debounce(50, function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end)
    return instance
end

function DragIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

---@param value { Value: integer[] }
---@return integer
function DragIntIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end

function DragIntIMGUIWidget:SetupTooltip(widget, setting)
    return IMGUIHelpers.AddTooltipWithRange(widget, setting, "%s")
end
