---@class SliderIntIMGUIWidget: IMGUIWidget
---@field Widget ExtuiSliderInt
---@field PreviousButton ExtuiButton|ExtuiImageButton
---@field NextButton ExtuiButton|ExtuiImageButton
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue integer
---@param modUUID string
---@return SliderIntIMGUIWidget
function SliderIntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderIntIMGUIWidget })
    ---@cast instance SliderIntIMGUIWidget

    local options = setting:GetOptions()
    local settingId = setting:GetId()

    -- Get step value from options, default to 1 if not specified
    local step = options.Step or 1

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
    instance.Widget = group:AddSliderInt("", initialValue, options.Min, options.Max)
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

function SliderIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

--- @param widget ExtuiStyledRenderable
--- @param setting BlueprintSetting
function SliderIntIMGUIWidget:SetupTooltip(widget, setting)
    return IMGUIHelpers.AddTooltipWithRange(widget, setting, "%s")
end

---@param value { Value: integer[] }
---@return integer
function SliderIntIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end
