---@class DictIMGUIWidget: IMGUIWidget
DictIMGUIWidget = _Class:Create("DictIMGUIWidget", IMGUIWidget)

---@param value table
---@return any
function DictIMGUIWidget.Create(group, setting, settingValue, modGUID)
    -- I don't even know what I should use for this
    -- local dict = group:AddDict(setting.Name, settingValue)
    -- local tooltip = dict:Tooltip()
    -- tooltip:AddText(setting.Description)
    -- dict.OnChange = function(value)
    --     BG3MCM:SetConfigValue(setting.Id, value.Value, modGUID)
    -- end
end
