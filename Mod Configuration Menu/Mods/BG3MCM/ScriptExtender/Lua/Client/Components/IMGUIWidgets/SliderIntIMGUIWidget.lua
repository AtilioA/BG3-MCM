---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue integer
---@param modUUID string
---@return SliderIntIMGUIWidget
function SliderIntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderIntIMGUIWidget })

    -- Get step value from options, default to 1 if not specified
    local step = setting.Options.Step or 1

    -- Decrement button
    instance.PreviousButton = WidgetHelpers.CreateSliderStepButton(
        group,
        setting.Id,
        -step,
        VCString:InterpolateLocalizedMessage("h0dab893ad8cc4f1a93e417c7524addecggc4", setting:GetLocaName(), step),
        setting.Options.Min,
        setting.Options.Max,
        function() return instance.Widget.Value[1] end,
        function(newValue) IMGUIAPI:SetSettingValue(setting.Id, newValue, modUUID) end
    )

    -- Actual slider
    instance.Widget = group:AddSliderInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = VCTimer:Debounce(50, function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end)
    instance.Widget.SameLine = true
    instance.Widget.AlwaysClamp = true
    instance.Widget.ClampOnInput = true

    -- Increment button
    instance.NextButton = WidgetHelpers.CreateSliderStepButton(
        group,
        setting.Id,
        step,
        VCString:InterpolateLocalizedMessage("heed976f6e50046c2a583040d9abb6ce6c8g1", setting:GetLocaName(), step),
        setting.Options.Min,
        setting.Options.Max,
        function() return instance.Widget.Value[1] end,
        function(newValue) IMGUIAPI:SetSettingValue(setting.Id, newValue, modUUID) end
    )
    instance.NextButton.SameLine = true

    return instance
end

function SliderIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

--- @param widget IMGUIWidget
--- @param setting Setting
function SliderIntIMGUIWidget:SetupTooltip(widget, setting)
    return IMGUIHelpers.AddTooltipWithRange(widget, setting, "%s")
end

---@param value { Value: integer[] }
---@return integer
function SliderIntIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end
