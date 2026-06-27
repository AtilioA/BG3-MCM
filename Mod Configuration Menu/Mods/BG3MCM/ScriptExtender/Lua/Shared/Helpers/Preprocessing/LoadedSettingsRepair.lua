---@class LoadedSettingsRepair
LoadedSettingsRepair = _Class:Create("LoadedSettingsRepair", nil)

---@param _key string
---@param value any
---@return boolean|nil
function LoadedSettingsRepair:ShouldPreserveSettingGroup(_key, value)
    local function isListV2SettingGroup(tbl)
        return type(tbl) == "table" and tbl.elements ~= nil and tbl.enabled ~= nil
    end

    local function isKeybindingV2SettingGroup(tbl)
        return type(tbl) == "table" and tbl.Keyboard ~= nil
    end

    if isKeybindingV2SettingGroup(value)
        or isListV2SettingGroup(value)
        or table.isArray(value)
        or KeybindingManager:IsKeybindingTable(value) then
        return true
    end
end

---@param blueprint Blueprint
---@param rawSettings table<string, any>
---@return table<string, any>|nil
function LoadedSettingsRepair:Repair(blueprint, rawSettings)
    local settings = JsonLayer:FlattenSettingsJSON(rawSettings, function(key, value)
        return self:ShouldPreserveSettingGroup(key, value)
    end)

    self:MigrateDeprecatedKeys(blueprint, settings)
    self:AddKeysMissingFromBlueprint(blueprint, settings)
    self:RemoveDeprecatedKeys(blueprint, settings)

    return DataPreprocessing:ValidateAndFixSettings(blueprint, settings)
end

---@param blueprint Blueprint
---@param settings table<string, any>
function LoadedSettingsRepair:MigrateDeprecatedKeys(blueprint, settings)
    MCMDebug(2, "Migrating deprecated keys for blueprint: %s", blueprint:GetModUUID())

    BlueprintShape:ForEachSetting(blueprint, function(setting)
        self:HandleListV2SettingMigration(blueprint, setting, settings)
    end)
end

---@param blueprint Blueprint
---@param setting BlueprintSetting
---@param settings table<string, any>
function LoadedSettingsRepair:HandleListV2SettingMigration(blueprint, setting, settings)
    if setting:GetType() ~= "list_v2" then
        return
    end

    local oldSetting = settings[setting:GetId()]
    if not oldSetting or type(oldSetting) ~= "table" or oldSetting.elements ~= nil then
        MCMDebug(3, "Old setting for %s does not exist or is not valid. Skipping migration.", setting:GetId())
        return
    end

    settings[setting:GetId()] = {
        elements = {},
        enabled = true
    }

    for _, element in ipairs(oldSetting) do
        table.insert(settings[setting:GetId()].elements, {
            name = element,
            enabled = true
        })
    end

    NotificationManager:CreateIMGUINotification('Migrated_listV2_setting_' ..
        setting:GetId() .. 'for_mod_' .. blueprint:GetModUUID(), 'success',
        string.format("Migrated ListV2 setting %s", setting:GetLocaName()),
        string.format("The ListV2 setting for mod %s has been migrated to the new format.", blueprint:GetModUUID()), {
            duration = 10,
            displayOnceOnly = true,
        }, ModuleUUID)

    MCMSuccess(0, "Successfully migrated ListV2 setting: %s", setting:GetId())
end

---@param blueprint Blueprint
---@param settings table<string, any>
function LoadedSettingsRepair:AddKeysMissingFromBlueprint(blueprint, settings)
    BlueprintShape:ForEachSetting(blueprint, function(setting)
        if settings[setting:GetId()] == nil then
            MCMDebug(2, "Setting missing: %s", setting:GetId())
            if settings[setting:GetOldId()] ~= nil then
                settings[setting:GetId()] = settings[setting:GetOldId()]
                MCMDebug(1, "Using old setting value for: %s", setting:GetId())
            else
                settings[setting:GetId()] = setting:GetDefault()
                MCMDebug(2, "Setting default value for: %s", setting:GetId())
            end
        end
    end)
end

---@param blueprint Blueprint
---@param settings table<string, any>
function LoadedSettingsRepair:RemoveDeprecatedKeys(blueprint, settings)
    local validSettings = {}

    BlueprintShape:ForEachSetting(blueprint, function(setting)
        validSettings[setting:GetId()] = true
    end)

    for key, value in pairs(settings) do
        if not validSettings[key] then
            if type(value) == "table" and next(value) == nil then
                -- Preserve the old flattening holdover until JSON cleanup semantics are changed
            else
                MCMWarn(2, "Removing deprecated setting: %s", key)
                settings[key] = nil
            end
        end
    end
end

return LoadedSettingsRepair
