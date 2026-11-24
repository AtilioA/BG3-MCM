---@class SliderFloatIMGUIWidget: IMGUIWidget
---@field Widget ExtuiSliderScalar
---@field PreviousButton ExtuiButton|ExtuiImageButton
---@field NextButton ExtuiButton|ExtuiImageButton
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue number
---@param modUUID string
---@return SliderFloatIMGUIWidget
function SliderFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderFloatIMGUIWidget })
    ---@cast instance SliderFloatIMGUIWidget

    local options = setting:GetOptions()
    local settingId = setting:GetId()

    -- Get step value from options, default to 0.1 if not specified
    local step = options.Step or 0.1

    -- Decrement button
    instance.PreviousButton = WidgetHelpers.CreateSliderStepButton(
        group,
        settingId,
        -step,
        VCString:InterpolateLocalizedMessage("h0dab893ad8cc4f1a93e417c7524addecggc4", setting:GetLocaName(), step),
        options.Min,
        options.Max,
        function() return instance.Widget.Value[1] end,
        function(newValue) IMGUIAPI:SetSettingValue(settingId, newValue, modUUID) end
    )

    -- Actual slider
    instance.Widget = group:AddSlider("", initialValue, options.Min, options.Max)
    instance.Widget.OnChange = VCTimer:Throttle(33, function(value)
        IMGUIAPI:SetSettingValue(settingId, value.Value[1], modUUID)
    end)
    instance.Widget.SameLine = true
    instance.Widget.AlwaysClamp = true
    instance.Widget.ClampOnInput = true

    -- Increment button
    instance.NextButton = WidgetHelpers.CreateSliderStepButton(
        group,
        settingId,
        step,
        VCString:InterpolateLocalizedMessage("heed976f6e50046c2a583040d9abb6ce6c8g1", setting:GetLocaName(), step),
        options.Min,
        options.Max,
        function() return instance.Widget.Value[1] end,
        function(newValue) IMGUIAPI:SetSettingValue(settingId, newValue, modUUID) end
    )
    instance.NextButton.SameLine = true

    return instance
end

function SliderFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

---@param value { Value: number[] }
---@return number
function SliderFloatIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end

function SliderFloatIMGUIWidget:SetupTooltip(widget, setting)
    return IMGUIHelpers.AddTooltipWithRange(widget, setting, "%.2f")
end
