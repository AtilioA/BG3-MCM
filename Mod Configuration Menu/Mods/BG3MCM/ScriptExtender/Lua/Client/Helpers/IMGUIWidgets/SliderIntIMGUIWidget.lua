---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@return any
function SliderIntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderIntIMGUIWidget })

    -- Helper function to create increment/decrement buttons
    local function createIncrementButton(label, icon, increment, tooltip)
        local button = group:AddImageButton(label, icon, IMGUIWidget:GetIconSizes())

        -- MCMDebug(1, Ext.DumpExport(button))
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
            local buttonTooltip = button:Tooltip()
            buttonTooltip.IDContext = "ButtonTooltip_" .. setting.Id
            buttonTooltip:AddText(tooltip)
        end
        return button
    end

    -- Decrement button
    instance.PreviousButton = createIncrementButton(" < ", "input_slider_arrowL_d", -1,
        "Decrease the '" .. setting:GetLocaName() .. "' value by 1")

    -- Actual slider
    instance.Widget = group:AddSliderInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end
    instance.Widget.SameLine = true

    -- Increment button
    instance.NextButton = createIncrementButton(" > ", "input_slider_arrowR_d", 1,
        "Increase the '" .. setting:GetLocaName() .. "' value by 1")
    instance.NextButton.SameLine = true

    return instance
end

function SliderIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function SliderIntIMGUIWidget:SetupTooltip(widget, setting)
    -- Call the base class method first
    IMGUIWidget.SetupTooltip(self, widget, setting)

    local tooltip = widget:Tooltip()
    tooltip:AddText(string.format("Min: %s", setting.Options.Min))
    tooltip:AddText(string.format("Max: %s", setting.Options.Max))
    if not table.isEmpty(tooltip.Children) then
        local tooltipSeparator = tooltip:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end
    tooltip:AddText("CTRL + click it to input value manually.")
end
