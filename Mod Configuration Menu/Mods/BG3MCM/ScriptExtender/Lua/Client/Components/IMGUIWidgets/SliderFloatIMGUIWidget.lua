---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

---@return any
function SliderFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderFloatIMGUIWidget })

    -- Get step value from options, default to 0.1 if not specified
    local step = setting.Options.Step or 0.1

    -- Helper function to create increment/decrement buttons
    local function createIncrementButton(label, icon, increment, tooltip)
        local button = group:AddImageButton(label, icon, IMGUIWidget:GetIconSizes())

        if not button.Image or button.Image.Icon == "" then
            button:Destroy()
            button = group:AddButton(label)
        end

        button.IDContext = (increment < 0 and "PreviousButton_" or "NextButton_") .. setting.Id
        button.OnClick = function()
            local newValue = math.max(setting.Options.Min,
                math.min(setting.Options.Max, instance.Widget.Value[1] + increment))
            instance:UpdateCurrentValue(newValue)
            IMGUIAPI:SetSettingValue(setting.Id, newValue, modUUID)
        end
        if tooltip then
            IMGUIHelpers.AddTooltip(button, tooltip, "ButtonTooltip_" .. setting.Id)
        end
        return button
    end

    -- Decrement button
    instance.PreviousButton = createIncrementButton(" < ", "input_slider_arrowL_d", -step,
        VCString:InterpolateLocalizedMessage("h0dab893ad8cc4f1a93e417c7524addecggc4", setting:GetLocaName()))

    -- Actual slider
    instance.Widget = group:AddSlider("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end
    instance.Widget.SameLine = true
    instance.Widget.AlwaysClamp = true
    instance.Widget.ClampOnInput = true
    
    -- Increment button
    instance.NextButton = createIncrementButton(" > ", "input_slider_arrowR_d", step,
        VCString:InterpolateLocalizedMessage("heed976f6e50046c2a583040d9abb6ce6c8g1", setting:GetLocaName()))
    instance.NextButton.SameLine = true

    return instance
end

function SliderFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function SliderFloatIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end

function SliderFloatIMGUIWidget:SetupTooltip(widget, setting)
    local tt = IMGUIWidget:SetupTooltip(widget, setting)

    if not tt then
        return
    end

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end

    local localizedText = VCString:InterpolateLocalizedMessage("h3914d63b7ccb425f950cea47eca955ad9788",
        string.format("%.2f", setting.Options.Min), string.format("%.2f", setting.Options.Max))
    tt:AddText(localizedText)

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end

    tt:AddText(Ext.Loca.GetTranslatedString("h0dfee4b6ba51423da77eaa53e1961ade059f"))
end
