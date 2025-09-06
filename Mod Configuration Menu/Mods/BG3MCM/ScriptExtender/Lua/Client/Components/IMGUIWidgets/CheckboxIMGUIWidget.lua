---@class CheckboxIMGUIWidget: IMGUIWidget
CheckboxIMGUIWidget = _Class:Create("CheckboxIMGUIWidget", IMGUIWidget)

function CheckboxIMGUIWidget:new(group, setting, initialValue, modUUID)
    -- Ensure Widget is an instance-specific property. This is some Lua nonsense that I don't understand. Try designing a better language next time. /hj
    local instance = setmetatable({}, { __index = CheckboxIMGUIWidget })

    instance.Widget = group:AddCheckbox("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Checked, modUUID)
    end
    instance.Widget.SameLine = false

    local opts = setting:GetOptions() or {}
    if opts["InlineTitle"] ~= false then
        instance:_addTitleText(group, setting, modUUID)
    end

    return instance
end

--- Adds a title text to the checkbox that can be clicked to toggle the checkbox.
---@param group any
---@param setting BlueprintSetting
---@param modUUID string
function CheckboxIMGUIWidget:_addTitleText(group, setting, modUUID)
    local titleText = setting:GetLocaName() or setting:GetId()
    if titleText == "" then return end

    local checkboxTitleText = group:AddText(titleText)

    checkboxTitleText.OnClick = function()
        IMGUIAPI:SetSettingValue(setting.Id, not self.Widget.Checked, modUUID)
    end

    checkboxTitleText.OnHoverEnter = function()
        self.Widget:SetColor("FrameBg", UIStyle.UnofficialColors.BoxHoverColor)
    end

    checkboxTitleText.OnHoverLeave = function()
        self.Widget:SetColor("FrameBg", UIStyle.UnofficialColors.BoxColor)
    end

    checkboxTitleText.TextWrapPos = 0
    checkboxTitleText.SameLine = true
end

function CheckboxIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Checked = value
end

function CheckboxIMGUIWidget:GetOnChangeValue(value)
    return value.Checked
end
