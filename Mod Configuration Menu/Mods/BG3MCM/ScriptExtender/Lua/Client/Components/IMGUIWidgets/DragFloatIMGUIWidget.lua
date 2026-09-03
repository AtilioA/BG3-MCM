---@class DragFloatIMGUIWidget: IMGUIWidget
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue number
---@param modUUID string
---@return DragFloatIMGUIWidget
function DragFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = DragFloatIMGUIWidget })
    instance.Widget = group:AddDrag("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = VCTimer:Debounce(50, function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
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
