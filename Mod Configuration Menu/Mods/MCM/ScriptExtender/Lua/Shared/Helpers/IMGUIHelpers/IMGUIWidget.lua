---@class IMGUIWidget
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {})

function IMGUIWidget:New()
    error(
        "This is an abstract class and cannot be instantiated directly. IMGUIWidget:New() must be overridden in a derived class")
end

--- Create a new IMGUI widget and add it to the specified group.
--- This is a static method, so it can be called without an instance of the class.
---@param group string The group that the widget will be added to
---@param setting SchemaSetting The setting that the widget will be associated with
---@param settingValue any The value of the setting
---@param modGUID string The GUID of the mod that the setting belongs to
---@return any widget The created widget
function IMGUIWidget.Create(group, setting, settingValue, modGUID)
    error("IMGUIWidget:Validate(value) must be overridden in a derived class")
end
