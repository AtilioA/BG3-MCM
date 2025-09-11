---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

function IntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = IntIMGUIWidget })

    -- Helper function to create increment/decrement buttons (int field)
    local function createIncrementButton(label, icon, increment, tooltip)
        local button = group:AddImageButton(label, icon, IMGUIWidget:GetIconSizes())

        if not button.Image or button.Image.Icon == "" then
            button:Destroy()
            button = group:AddButton(label)
        end

        button.IDContext = modUUID .. (increment < 0 and "PreviousButton_" or "NextButton_") .. setting.Id
        button.OnClick = function()
            local newValue = instance.Widget.Value[1] + increment
            instance:UpdateCurrentValue(newValue)
            IMGUIAPI:SetSettingValue(setting.Id, newValue, modUUID)
        end
        if tooltip then
            MCMRendering:AddTooltip(button, tooltip, modUUID .. "WidgetTooltip_" .. setting.Id)
        end
        return button
    end

    -- Decrement button
    instance.PreviousButton = createIncrementButton(" - ", "ico_min_d", -1,
        VCString:InterpolateLocalizedMessage("h9d240caa7bbe4ef482d21f1e691b0597a38g",
            setting:GetLocaName()))

    -- Actual int input widget
    instance.Widget = group:AddInputInt("", initialValue)
    instance.Widget.OnChange = VCTimer:Debounce(200, function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end)
    instance.Widget.SameLine = true

    -- Increment button
    instance.NextButton = createIncrementButton(" + ", "ico_plus_d", 1,
        VCString:InterpolateLocalizedMessage("h9cc3f92986d24e3e8c1b86eb80023a2b015c",
            setting:GetLocaName()))
    instance.NextButton.SameLine = true

    return instance
end

function IntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function IntIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end
