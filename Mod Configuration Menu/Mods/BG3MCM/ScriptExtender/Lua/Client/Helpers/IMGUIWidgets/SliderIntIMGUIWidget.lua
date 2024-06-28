---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@return any
function SliderIntIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = SliderIntIMGUIWidget })

    -- 'Previous' button
    instance.PreviousButton = group:AddButton(" < ")
    instance.PreviousButton.IDContext = "PreviousButton_" .. setting.Id
    instance.PreviousButton.OnClick = function()
        local newValue = math.max(setting.Options.Min, instance.Widget.Value[1] - 1)
        instance:UpdateCurrentValue(newValue)
        IMGUIAPI:SetSettingValue(setting.Id, newValue, modGUID)
    end

    -- Actual slider
    instance.Widget = group:AddSliderInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modGUID)
    end
    instance.Widget.SameLine = true

    -- 'Next' button
    instance.NextButton = group:AddButton(" > ")
    instance.NextButton.IDContext = "NextButton_" .. setting.Id
    instance.NextButton.OnClick = function()
        local newValue = math.min(setting.Options.Max, instance.Widget.Value[1] + 1)
        instance:UpdateCurrentValue(newValue)
        IMGUIAPI:SetSettingValue(setting.Id, newValue, modGUID)
    end
    instance.NextButton.SameLine = true

    return instance
end

function SliderIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
