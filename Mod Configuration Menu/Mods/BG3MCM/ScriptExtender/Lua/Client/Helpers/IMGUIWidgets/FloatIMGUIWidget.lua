---@class FloatIMGUIWidget: IMGUIWidget
FloatIMGUIWidget = _Class:Create("FloatIMGUIWidget", IMGUIWidget)

---@return boolean
function FloatIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local inputScalar = group:AddInputScalar(widgetName, initialValue)
    inputScalar.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return inputScalar
end
