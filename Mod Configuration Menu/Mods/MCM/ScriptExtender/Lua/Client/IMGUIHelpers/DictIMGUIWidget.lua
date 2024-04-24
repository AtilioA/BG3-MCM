---@class DictIMGUIWidget: IMGUIWidget
DictIMGUIWidget = _Class:Create("DictIMGUIWidget", IMGUIWidget)

---@param value table
---@return any
function DictIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    -- I don't even know what I should use for this
    -- local dict = group:AddDict(setting.Name, settingValue)
    -- dict.OnChange = function(value)
    --     IMGUILayer:SetConfigValue(setting.Id, value.Value, modGUID)
    -- end
end
