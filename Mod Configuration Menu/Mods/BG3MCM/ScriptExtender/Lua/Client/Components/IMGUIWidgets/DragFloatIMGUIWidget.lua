---@class DragFloatIMGUIWidget: IMGUIWidget
---@field Widget ExtuiDragScalar
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue number
---@param modUUID string
---@return DragFloatIMGUIWidget
function DragFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = DragFloatIMGUIWidget })
    ---@cast instance DragFloatIMGUIWidget
    local options = setting:GetOptions()
    instance.Widget = group:AddDrag("", initialValue, options.Min, options.Max)
    instance.Widget.OnChange = VCTimer:Throttle(33, function(value)
        IMGUIAPI:SetSettingValue(setting:GetId(), value.Value[1], modUUID)
    end)
    return instance
end

function DragFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

---@param value { Value: number[] }
---@return number
function DragFloatIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end

function DragFloatIMGUIWidget:SetupTooltip(widget, setting)
    return IMGUIHelpers.AddTooltipWithRange(widget, setting, "%.2f")
end
