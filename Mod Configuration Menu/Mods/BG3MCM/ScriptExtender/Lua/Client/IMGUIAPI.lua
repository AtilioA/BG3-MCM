---@class IMGUIAPI: MetaClass
IMGUIAPI = _Class:Create("IMGUIAPI", nil, {})

--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
    IMGUILayer:InsertModMenuTab(modGUID, tabName, tabCallback)
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

    -- TODO / NOTE: this is a simplification; each widget will have its own way of updating its value
    if widget then
        widget.Value = value
    end
end

function IMGUIAPI:FindWidgetForSetting(modGUID, settingId)
    -- TODO: Implement logic to find the widget corresponding to the setting. This might involve maintaining a mapping of settings to widgets (I already kind of do this), or searching through the UI hierarchy...
    --- This will be required to update the widget value when a setting is changed, e.g. when resetting to default or switching profiles
end
