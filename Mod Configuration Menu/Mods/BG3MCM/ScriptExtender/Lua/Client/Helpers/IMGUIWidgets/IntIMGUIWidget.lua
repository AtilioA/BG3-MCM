---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

function IntIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = IntIMGUIWidget })

    -- 'Previous' button
    instance.PreviousButton = group:AddButton(" - ")
    instance.PreviousButton.IDContext = "PreviousButton_" .. setting.Id
    instance.PreviousButton.OnClick = function()
        local newValue = instance.Widget.Value[1] - 1
        instance:UpdateCurrentValue(newValue)
        IMGUIAPI:SetSettingValue(setting.Id, newValue, modGUID)
    end

    -- Actual int input widget
    instance.Widget = group:AddInputInt("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modGUID)
    end
    instance.Widget.SameLine = true

    -- 'Next' button
    instance.NextButton = group:AddButton(" + ")
    instance.NextButton.IDContext = "NextButton_" .. setting.Id
    instance.NextButton.OnClick = function()
        local newValue = instance.Widget.Value[1] + 1
        instance:UpdateCurrentValue(newValue)
        IMGUIAPI:SetSettingValue(setting.Id, newValue, modGUID)
    end
    instance.NextButton.SameLine = true

    return instance
end

function IntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
