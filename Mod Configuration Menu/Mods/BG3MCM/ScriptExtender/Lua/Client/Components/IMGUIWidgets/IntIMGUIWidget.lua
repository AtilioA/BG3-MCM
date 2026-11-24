---@class IntIMGUIWidget: IMGUIWidget
---@field Widget ExtuiInputInt
---@field PreviousButton ExtuiButton|ExtuiImageButton
---@field NextButton ExtuiButton|ExtuiImageButton
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue integer
---@param modUUID string
---@return IntIMGUIWidget
function IntIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = IntIMGUIWidget })
    ---@cast instance IntIMGUIWidget

    local settingId = setting:GetId()

    -- Helper function to create increment/decrement buttons (int field)
    local function createIncrementButton(label, icon, increment, tooltip)
        ---@type ExtuiButton|ExtuiImageButton
        local button = group:AddImageButton(label, icon, IMGUIWidget:GetIconSizes())

        if not button.Image or button.Image.Icon == "" then
            button:Destroy()
            button = group:AddButton(label)
        end

        button.IDContext = modUUID .. (increment < 0 and "PreviousButton_" or "NextButton_") .. settingId
        button.OnClick = function()
            local newValue = instance.Widget.Value[1] + increment
            instance:UpdateCurrentValue(newValue)
            IMGUIAPI:SetSettingValue(settingId, newValue, modUUID)
        end
        if tooltip then
            IMGUIHelpers.AddTooltip(button, tooltip, modUUID .. "WidgetTooltip_" .. settingId)
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
        IMGUIAPI:SetSettingValue(settingId, value.Value[1], modUUID)
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

---@param value { Value: integer[] }
---@return integer
function IntIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end
