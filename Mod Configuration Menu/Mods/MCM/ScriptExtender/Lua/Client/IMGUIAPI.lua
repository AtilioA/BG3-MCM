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

function IMGUIAPI:SetConfigValue(settingId, value, modGUID)
    Ext.Net.PostMessageToServer("MCM_SetConfigValue", Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId,
        value = value
    }))
end
