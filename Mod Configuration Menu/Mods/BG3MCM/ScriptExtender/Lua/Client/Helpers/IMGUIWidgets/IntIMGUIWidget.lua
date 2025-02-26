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
            IMGUILayer:AddTooltip(button, tooltip, modUUID .. "WidgetTooltip_" .. setting.Id)
        end
        return button
    end

    -- Decrement button
    instance.PreviousButton = createIncrementButton(" - ", "ico_min_d", -1,
        "Decrease the '" .. setting:GetLocaName() .. "' value by 1")

    -- Actual int input widget
    instance.Widget = group:AddInputInt("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end
    instance.Widget.SameLine = true

    -- Increment button
    instance.NextButton = createIncrementButton(" + ", "ico_plus_d", 1,
        "Increase the '" .. setting:GetLocaName() .. "' value by 1")
    instance.NextButton.SameLine = true

    return instance
end

function IntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
