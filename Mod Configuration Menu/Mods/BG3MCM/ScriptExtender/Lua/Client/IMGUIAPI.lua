---@class IMGUIAPI: MetaClass
IMGUIAPI = _Class:Create("IMGUIAPI", nil, {})

IMGUIAPI.insertedTabs = {}

--- Update values for the MCM window
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modUUID string The UUID of the mod
function IMGUIAPI:UpdateMCMWindowValues(settingId, value, modUUID)
    if modUUID ~= ModuleUUID then
        return
    end

    if not MCM_WINDOW then
        return
    end

    if settingId == "auto_resize_window" then
        MCM_WINDOW.AlwaysAutoResize = value
    end
end

--- Insert a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
---REVIEW: review this when refactoring server/client code, and potentially make this smarter by postponing the insertion until the client has finished initializing
function IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback)
    if not self.insertedTabs[modUUID] then
        self.insertedTabs[modUUID] = {}
    end

    -- Check if the callback is already registered for this mod
    for _, existingCallback in ipairs(self.insertedTabs[modUUID]) do
        if existingCallback == tabCallback then
            return
        end
    end

    -- Register the new callback
    table.insert(self.insertedTabs[modUUID], tabCallback)

    MCMProxy:InsertModMenuTab(modUUID, tabName, tabCallback)
end

--- Send a message to the server to update a setting value
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modUUID string The UUID of the mod
---@param setUIValue? function A callback function to be called after the setting value is updated
---@return nil
function IMGUIAPI:SetSettingValue(settingId, value, modUUID, setUIValue)
    MCMProxy:SetSettingValue(settingId, value, modUUID, setUIValue)

    -- FIXME: this is leaking listeners
    ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(data)
        if data.modUUID == modUUID and data.settingId == settingId then
            if setUIValue then
                setUIValue(data.value)
            end
        end
    end)
end

--- Send a message to the server to reset a setting value
---@param settingId string The ID of the setting to reset
---@param modUUID string The UUID of the mod
---@return nil
function IMGUIAPI:ResetSettingValue(settingId, modUUID)
    MCMProxy:ResetSettingValue(settingId, modUUID)
end

-- --- Send a message to the server to set a profile
-- ---@param profileName string The name of the profile to set
-- ---@return nil
-- function IMGUIAPI:SetProfile(profileName)
--     Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE, Ext.Json.Stringify({
--         profileName = profileName
--     }))
-- end

--- TODO: move somewhere else probably
---@private lmao
function IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)
    -- Find the widget corresponding to the setting and update its value
    local widget = self:findWidgetForSetting(settingId, modUUID)
    if not widget then
        MCMWarn(1, "No widget found for setting " .. settingId)
        return
    end
    widget:UpdateCurrentValue(value)
end

--- Find the widget corresponding to a setting
--- TODO: perform a traversal of the window nodes to find the widget;
--- Storing references in a table is troublesome because they get lost for some reason
---@private
---@param modUUID string The UUID of the mod
---@param settingId string The ID of the setting to find the widget for
---@return any | nil - The widget corresponding to the setting, or nil if no widget was found
function IMGUIAPI:findWidgetForSetting(settingId, modUUID)
    -- Check if the mod has any registered widgets
    local widgets = self:getModWidgets(modUUID)
    if widgets then
        return widgets[settingId]
    end
end

--- Get the widgets for a mod
---@private
---@param modUUID string The UUID of the mod
---@return table<string, any> | nil - widgets for the mod (keyed by setting ID), or nil if the mod has no widgets
function IMGUIAPI:getModWidgets(modUUID)
    -- _DS(MCMClientState.mods[modUUID].widgetsQ)
    if MCMClientState.mods and MCMClientState.mods[modUUID] and MCMClientState.mods[modUUID].widgets then
        return MCMClientState.mods[modUUID].widgets
    end
    return nil
end
