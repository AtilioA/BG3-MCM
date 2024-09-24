---@class MCMAPI: MetaClass
---@field private mods table<string, table> A table of modUUIDs that has a table of blueprints and settings for each mod
-- The MCM (Mod Configuration Menu) class is the main entry point for interacting with the Mod Configuration Menu system.
-- It acts as a high-level interface to the underlying ModConfig and ProfileManager classes, which handle the low-level details of loading, saving, and managing the mod configurations and user profiles, as well as JSON file handling from the JsonLayer class.
--
-- The MCM class is responsible for providing a consistent and user-friendly API for mod authors and the IMGUI client to interact with the Mod Configuration Menu system.
-- It provides methods for managing the configuration of mods, including:
-- - Loading the configurations for all mods
-- - Creating and managing user profiles
-- - Retrieving the settings and blueprints for individual mods
-- - Setting and getting the values of configuration settings
-- - Resetting settings to their default values
MCMAPI = _Class:Create("MCMAPI", nil, {
    mods = {},
    profiles = {},
})

--- Loads the profile manager and the configurations for all mods.
---@return nil
function MCMAPI:LoadConfigs()
    self.mods = ModConfig:GetSettings()
    self.profiles = ModConfig:GetProfiles()
    MCMSuccess(0, "Finished loading MCM blueprints")
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCMAPI:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:CreateProfile(profileName)

    if success then
        if Ext.IsServer() then
            -- Ext.Net.BroadcastMessage(EventChannels.MCM_PROFILE_CREATED, Ext.Json.Stringify({
            --     profileName = profileName,
            --     newSettings = ModConfig.mods
            -- }))

            -- Notify other servers about the new profile creation
            ModEventManager:Emit(EventChannels.MCM_PROFILE_CREATED, {
                profileName = profileName,
                newSettings = ModConfig.mods
            })
        end
    end

    self:SetProfile(profileName)

    return success
end

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
function MCMAPI:GetProfiles()
    return ModConfig:GetProfiles()
end

--- Get the current MCM profile's name
---@return string The name of the current profile
function MCMAPI:GetCurrentProfile()
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    return ModConfig.profileManager:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCMAPI:SetProfile(profileName)
    local currentProfile = self:GetCurrentProfile()
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:SetCurrentProfile(profileName)
    MCMDebug(1, "Set profile to " .. profileName)

    if success then
        if Ext.IsServer() then
            -- Ext.Net.BroadcastMessage(EventChannels.MCM_PROFILE_ACTIVATED, Ext.Json.Stringify({
            --     profileName = profileName,
            --     newSettings = ModConfig.mods
            -- }))

            -- Notify other servers about the profile change
            ModEventManager:Emit(EventChannels.MCM_PROFILE_ACTIVATED, {
                fromProfile = currentProfile,
                toProfile = profileName
            })
        end
    end

    return success
end

--- Delete a profile from the MCM
---@param profileName string The name of the profile to delete
---@return boolean success Whether the profile was successfully deleted
function MCMAPI:DeleteProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:DeleteProfile(profileName)

    return success
end

--- Get the settings table for a mod
---@param modUUID GUIDSTRING The UUID of the mod to retrieve settings from
---@return table<string, table> - The settings table for the mod
function MCMAPI:GetAllModSettings(modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get mod settings.")
        return {}
    end

    local mod = self.mods[modUUID]
    if not mod then
        MCMWarn(0,
            "Mod " ..
            modUUID ..
            " was not found by MCM.\nDouble check your blueprint filename, directory, and whether it's well-defined. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return {}
    end

    return mod.settingsValues
end

--- Get the Blueprint table for a mod
---@param modUUID GUIDSTRING The UUID of the mod.
---@return Blueprint|nil - The Blueprint for the mod, or nil if the mod was not found
function MCMAPI:GetModBlueprint(modUUID)
    if modUUID and self.mods and self.mods[modUUID] then
        return self.mods[modUUID].blueprint
    else
        return nil
    end
end

--- Check if a setting value is valid given the mod blueprint
---@param settingId string The id of the setting
---@param value any The value to check
---@return boolean Whether the value is valid
function MCMAPI:IsSettingValueValid(settingId, value, modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot validate setting value.")
        return false
    end

    -- TODO: add blueprint methods to solve this
    local blueprint = self:GetModBlueprint(modUUID)
    if not blueprint then
        MCMWarn(0, "Blueprint not found for mod '" .. modUUID .. "'.")
        return false
    end

    local setting = blueprint:GetAllSettings()[settingId]
    if not setting then
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found in the blueprint for mod '" ..
            modUUID .. "'. Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return false
    end

    local isValid = DataPreprocessing:ValidateSetting(setting, value)
    if not isValid then
        MCMWarn(0,
            "Value " ..
            tostring(value) .. " is invalid for setting '" .. settingId .. "' in mod '" .. modUUID .. "'.")
    end
    return isValid
end

--- Get the value of a configuration setting
---@param settingId string The id of the setting
---@param modUUID string The UUID of the mod that has the setting
---@return any The value of the setting
function MCMAPI:GetSettingValue(settingId, modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get setting value.")
        return nil
    end

    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for mod '" .. modUUID .. "'.")
        return nil
    end

    if modSettingsTable[settingId] ~= nil then
        return modSettingsTable[settingId]
    end

    -- No settingId
    self:HandleMissingSetting(settingId, modSettingsTable, modUUID)

    return nil
end

--- Get the names of all settings in the mod settings table
---@param modSettingsTable table The mod settings table
---@return string[] The names of all settings
function MCMAPI:GetSettingsIDs(modSettingsTable)
    local settingIDs = {}
    for settingName, _ in pairs(modSettingsTable) do
        table.insert(settingIDs, settingName)
    end
    return settingIDs
end

-- TODO: add debouncing to this function
--- Handle the case when a setting is missing
---@param settingId string The id of the setting
---@param modSettingsTable table The mod settings table
---@param modUUID string The UUID of the mod
function MCMAPI:HandleMissingSetting(settingId, modSettingsTable, modUUID)
    local modInfo = Ext.Mod.GetMod(modUUID).Info
    local closestMatch, distance = VCString:FindClosestMatch(settingId, self:GetSettingsIDs(modSettingsTable), false)
    if closestMatch and distance < 8 then
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found for mod '" ..
            modInfo.Name ..
            "'. Did you mean '" .. closestMatch .. "'? Please contact " .. modInfo.Author .. " about this issue.")
    else
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found for mod '" .. modInfo.Name .. "'. Please contact " .. modInfo.Author .. " about this issue.")
    end
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modUUID GUIDSTRING The UUID of the mod
function MCMAPI:SetSettingValue(settingId, value, modUUID)
    if not settingId then
        MCMWarn(0, "settingId is nil. Value will not be saved.")
        return
    end

    if not modUUID then
        MCMWarn(0, "modUUID is nil. Value will not be saved.")
        return
    end

    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table is nil for mod UUID: " .. modUUID)
        return
    end

    local oldValue = modSettingsTable[settingId]

    local isValid = self:IsSettingValueValid(settingId, value, modUUID)
    MCMDebug(2, "Setting value for " .. settingId .. " is valid? " .. tostring(isValid))
    if not isValid then
        MCMWarn(0, "Invalid value for setting '" .. settingId .. " (" .. tostring(value) .. "). Value will not be saved.")
        return
    end

    modSettingsTable[settingId] = value
    ModConfig:UpdateAllSettingsForMod(modUUID, modSettingsTable)

    ModEventManager:Emit(EventChannels.MCM_SETTING_SAVED, {
        modUUID = modUUID,
        settingId = settingId,
        value = value,
        oldValue = oldValue
    })
end

---@param settingId string The id of the setting to reset
---@param modUUID? GUIDSTRING The UUID of the mod (optional)
---@param clientRequest? boolean (deprecated) Whether the request came from the client
function MCMAPI:ResetSettingValue(settingId, modUUID, clientRequest)
    modUUID = modUUID or ModuleUUID

    local blueprint = self:GetModBlueprint(modUUID)
    if not blueprint then
        MCMWarn(0, "Blueprint not found for mod UUID: " .. modUUID)
        return
    end

    local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(0,
            "Setting '" .. settingId .. "' not found in the blueprint for mod '" .. modUUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
    else
        self:SetSettingValue(settingId, defaultValue, modUUID, clientRequest)
        -- Ext.Net.BroadcastMessage(EventChannels.MCM_SETTING_RESET, Ext.Json.Stringify({
        --     modUUID = modUUID,
        --     settingId = settingId,
        --     defaultValue = defaultValue
        -- }))
    end
end

--- Reset all settings for a mod to their default values
-- function MCMAPI:ResetAllSettings(modUUID)
--     local modBlueprint = self.blueprints[modUUID]
--     local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

--     ModConfig:UpdateAllSettingsForMod(modUUID, defaultSettings)
--     Ext.Net.BroadcastMessage(NetChannels.MCM_RELAY_TO_SERVERS,
--         Ext.Json.Stringify({ channel = EventChannels.MCM_ALL_MOD_SETTINGS_RESET, payload = { modUUID = modUUID, settings = defaultSettings } }))
-- end

function MCMAPI:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM configs...")
    self:LoadConfigs()
end

-- UNUSED since profile management currently calls shared code
-- --- Message handler for when the (IMGUI) client requests a new profile to be created
-- Ext.RegisterNetListener("MCM_Client_Request_Create_Profile", function(_, payload)
--     local payload = Ext.Json.Parse(payload)
--     local newProfileName = payload.profileName

--     MCMDebug(1, "Will create a new profile named " .. newProfileName)
--     MCMAPI:CreateProfile(newProfileName)
-- end)

-- --- Message handler for when the (IMGUI) client requests a profile to be deleted
-- Ext.RegisterNetListener("MCM_Client_Request_Delete_Profile", function(_, payload)
--     local payload = Ext.Json.Parse(payload)
--     local profileToDelete = payload.profileName

--     MCMDebug(1, "Will delete the profile named " .. profileToDelete)
--     MCMAPI:DeleteProfile(profileToDelete)
-- end)

local function injectMCMToModTable(modUUID)
    if modUUID == ModuleUUID then return end

    MCMPrint(2, "Injecting MCM to mod table for modUUID: " .. modUUID)

    local modTableName = Ext.Mod.GetMod(modUUID).Info.Directory
    MCMPrint(1, "Mod table name: " .. modTableName)
    local modTable = Mods[modTableName]
    if not modTable then
        MCMWarn(2, "Mod table not found for modUUID: " .. modUUID)
        return
    end

    if modTable.MCM then
        MCMPrint(1, "MCM already exists in mod table for modUUID: " .. modUUID .. ". Skipping metatable injection.")
        return
    end

    local MCM = {}

    -- Define useful functions for mods to use
    MCM.Get = function(settingId)
        -- MCMDebug(1, "Getting setting value for settingId: " .. settingId)
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    MCM.Set = function(settingId, value)
        -- MCMDebug(1, "Setting value for settingId: " .. settingId .. " to: " .. tostring(value))
        MCMAPI:SetSettingValue(settingId, value, modUUID)
    end

    Mods[modTableName].MCM = MCM

    MCMSuccess(1, "Successfully injected MCM to mod table for modUUID: " .. modUUID)
end

local function setupModsMetatable()
    -- Define a custom __newindex function to listen for new entries in the Mods table
    local modsMetatable = {
        __newindex = function(table, key, value)
            MCMDebug(2, "New mod being added to Mods table: " .. tostring(key))

            -- Set the new key-value pair in the table as normal
            rawset(table, key, value)

            if ModConfig.mods[value.ModuleUUID] then
                injectMCMToModTable(value.ModuleUUID)
            end
            NotificationManager:InjectNotificationManagerToModTable(value.ModuleUUID)
        end
    }

    -- Set the metatable for the Mods table
    setmetatable(Mods, modsMetatable)
end

setupModsMetatable()
