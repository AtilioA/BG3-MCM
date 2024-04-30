---@class IMGUIAPI: MetaClass
IMGUIAPI = _Class:Create("IMGUIAPI", nil, {})

--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
    MCM_IMGUI_LAYER:InsertModMenuTab(modGUID, tabName, tabCallback)
end

--- Send a message to the server to update a setting value
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modGUID string The UUID of the mod
---@return nil
function IMGUIAPI:SetConfigValue(settingId, value, modGUID)
    Ext.Net.PostMessageToServer("MCM_Client_Request_Set_Setting_Value", Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId,
        value = value
    }))
end

--- Send a message to the server to reset a setting value
---@param settingId string The ID of the setting to reset
---@param modGUID string The UUID of the mod
---@return nil
function IMGUIAPI:ResetConfigValue(settingId, modGUID)
    Ext.Net.PostMessageToServer("MCM_Client_Request_Reset_Setting_Value", Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId
    }))
end

function IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, value)
    -- Find the widget corresponding to the setting and update its value
    local widget = self:FindWidgetForSetting(modGUID, settingId)
    widget:UpdateCurrentValue(value)
end

--- Find the widget corresponding to a setting
---@param modGUID string The UUID of the mod
---@param settingId string The ID of the setting to find the widget for
---@return any | nil - The widget corresponding to the setting, or nil if no widget was found
function IMGUIAPI:FindWidgetForSetting(modGUID, settingId)
    -- Check if the mod has any registered widgets
    local widgets = self:getModWidgets(modGUID)
    if widgets then
        return widgets[settingId]
    end
end

--- Get the widgets for a mod
---@param modGUID string The UUID of the mod
---@return table<string, any> | nil - widgets for the mod (keyed by setting ID), or nil if the mod has no widgets
function IMGUIAPI:getModWidgets(modGUID)
    if MCM_IMGUI_LAYER.mods and MCM_IMGUI_LAYER.mods[modGUID] and MCM_IMGUI_LAYER.mods[modGUID].widgets then
        return MCM_IMGUI_LAYER.mods[modGUID].widgets
    end
    return nil
end