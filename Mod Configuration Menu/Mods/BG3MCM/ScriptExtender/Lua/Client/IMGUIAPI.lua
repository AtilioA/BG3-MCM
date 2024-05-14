---@class IMGUIAPI: MetaClass
IMGUIAPI = _Class:Create("IMGUIAPI", nil, {})

--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
    if not MCMClientState.modsTabBar then
        Ext.RegisterNetListener(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function()
            MCMClientState:InsertModMenuTab(modGUID, tabName, tabCallback)
        end)
        return
    else
        MCMClientState:InsertModMenuTab(modGUID, tabName, tabCallback)
    end
end

--- Send a message to the server to update a setting value
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modGUID string The UUID of the mod
---@param setUIValue? function A callback function to be called after the setting value is updated
---@return nil
function IMGUIAPI:SetSettingValue(settingId, value, modGUID, setUIValue)
    Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId,
        value = value
    }))
    Ext.RegisterNetListener(Channels.MCM_SETTING_UPDATED, function(_, payload)
        local data = Ext.Json.Parse(payload)
        if data.modGUID == modGUID and data.settingId == settingId then
            if setUIValue then
                setUIValue(data.value)
            end
        end
    end)
end

--- Send a message to the server to reset a setting value
---@param settingId string The ID of the setting to reset
---@param modGUID string The UUID of the mod
---@return nil
function IMGUIAPI:ResetSettingValue(settingId, modGUID)
    Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE, Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId
    }))
end

--- Send a message to the server to set a profile
---@param profileName string The name of the profile to set
---@return nil
function IMGUIAPI:SetProfile(profileName)
    Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_SET_PROFILE, Ext.Json.Stringify({
        profileName = profileName
    }))
end

--- TODO: move somewhere else probably
---@private lmao
function IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, value)
    -- Find the widget corresponding to the setting and update its value
    local widget = self:findWidgetForSetting(modGUID, settingId)
    widget:UpdateCurrentValue(value)
end

--- Find the widget corresponding to a setting
---@private
---@param modGUID string The UUID of the mod
---@param settingId string The ID of the setting to find the widget for
---@return any | nil - The widget corresponding to the setting, or nil if no widget was found
function IMGUIAPI:findWidgetForSetting(modGUID, settingId)
    -- Check if the mod has any registered widgets
    local widgets = self:getModWidgets(modGUID)
    if widgets then
        return widgets[settingId]
    end
end

--- Get the widgets for a mod
---@private
---@param modGUID string The UUID of the mod
---@return table<string, any> | nil - widgets for the mod (keyed by setting ID), or nil if the mod has no widgets
function IMGUIAPI:getModWidgets(modGUID)
    if MCMClientState.mods and MCMClientState.mods[modGUID] and MCMClientState.mods[modGUID].widgets then
        return MCMClientState.mods[modGUID].widgets
    end
    return nil
end
