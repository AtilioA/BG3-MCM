local RX = {
    ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
}

---@class MCMAPI: MetaClass
---@field private mods table<string, table> A table of modUUIDs that has a table of blueprints and settings for each mod
---@field private profiles table<string, table> A table of profile data
---@field private ConfigsLoaded ReplaySubject

---@class MCMAPI
--- The MCM (Mod Configuration Menu) class is the main entry point for interacting with the Mod Configuration Menu system.
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
    ConfigsLoaded = RX.ReplaySubject.Create(1)
})

--- Loads the profile manager and the configurations for all mods.
---@return nil
function MCMAPI:LoadConfigs()
    self.mods = ModConfig:GetSettings()
    self.profiles = ModConfig:GetProfiles()
    self.ConfigsLoaded:OnNext(true)
    MCMSuccess(0, "Finished loading MCM blueprints")
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCMAPI:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success, errorMessage = ModConfig.profileManager:CreateProfile(profileName)

    if success then
        if Ext.IsServer() then
            -- Notify other servers about the new profile creation
            ModEventManager:Emit(EventChannels.MCM_PROFILE_CREATED, {
                profileName = profileName,
                newSettings = ModConfig.mods
            })
        end
    end

    self:SetProfile(profileName)

    return success, errorMessage
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

    if success then
        MCMDebug(1, "Set profile to %s", profileName)
        if Ext.IsServer() then
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
            "Mod %s was not found by MCM.\nDouble check your blueprint filename, directory, and whether it's well-defined. Please contact %s about this issue.",
            modUUID,
            Ext.Mod.GetMod(modUUID).Info.Author)
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

--- Get a blueprint setting for a mod.
---@param settingId string The ID of the setting to retrieve
---@param modUUID GUIDSTRING The UUID of the mod.
---@return BlueprintSetting|nil
function MCMAPI:GetBlueprintSetting(settingId, modUUID)
    local blueprint = self:GetModBlueprint(modUUID)
    if not blueprint then
        MCMWarn(0, "Blueprint not found for mod '%s'.", modUUID)
        return nil
    end

    local setting = blueprint:GetAllSettings()[settingId]
    if not setting then
        MCMWarn(0,
            "Setting '%s' not found in the blueprint for mod '%s'. Please contact %s about this issue.",
            settingId,
            modUUID,
            Ext.Mod.GetMod(modUUID).Info.Author)
        return nil
    end

    return setting
end

--- Apply enum choices to the blueprint mirror without changing the current setting value.
---@param settingId string
---@param choices string[]
---@param choicesHandles? string[]
---@param modUUID GUIDSTRING
---@return BlueprintSetting|nil
function MCMAPI:ApplyEnumChoices(settingId, choices, choicesHandles, modUUID)
    local setting = self:GetBlueprintSetting(settingId, modUUID)
    if not setting then
        return nil
    end

    if setting:GetType() ~= "enum" then
        MCMWarn(0,
            "Setting '%s' in mod '%s' is not an enum. Choices will not be updated.", settingId, modUUID)
        return nil
    end

    if not EnumChoicesHelper.ApplyChoices(setting, choices, choicesHandles) then
        MCMWarn(0, "Enum choices must be a table of strings. Choices will not be updated.")
        return nil
    end

    return setting
end

--- Update enum choices at runtime and coerce invalid stored values when possible.
---@param settingId string
---@param choices string[]
---@param choicesHandles? string[]
---@param modUUID GUIDSTRING
---@param shouldEmitEvent? boolean
---@return boolean
function MCMAPI:SetEnumChoices(settingId, choices, choicesHandles, modUUID, shouldEmitEvent)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot update enum choices.")
        return false
    end

    local setting = self:ApplyEnumChoices(settingId, choices, choicesHandles, modUUID)
    if not setting then
        return false
    end

    local currentValue = self:GetSettingValue(settingId, modUUID)
    local resolvedValue = EnumChoicesHelper.ResolveValue(setting, currentValue)

    if currentValue ~= resolvedValue then
        local success = self:SetSettingValue(settingId, resolvedValue, modUUID, shouldEmitEvent)
        if not success then
            return false
        end
    end

    if shouldEmitEvent ~= false then
        ModEventManager:Emit(EventChannels.MCM_ENUM_CHOICES_UPDATED, {
            modUUID = modUUID,
            settingId = settingId,
            choices = EnumChoicesHelper.CopyChoices(choices),
            choicesHandles = choicesHandles and EnumChoicesHelper.CopyChoices(choicesHandles) or nil,
            value = resolvedValue
        }, true)
    end

    return true
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

    local setting = self:GetBlueprintSetting(settingId, modUUID)
    if not setting then
        return false
    end

    local isValid = DataPreprocessing:ValidateSetting(setting, value)
    if not isValid then
        MCMWarn(0,
            "Value %s is invalid for setting '%s' in mod '%s'.", value, settingId, modUUID)
    end
    return isValid
end

--- Get the value of a configuration setting
---@param settingId string The id of the setting
---@param modUUID string The UUID of the mod that has the setting
---@return any - The value of the setting
function MCMAPI:GetSettingValue(settingId, modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get setting value.")
        return nil
    end

    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for mod '%s'.", modUUID)
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

-- Uses debouncing to avoid spamming warnings for the same missing setting
--- Handle the case when a setting is missing
---@param settingId string The id of the setting
---@param modSettingsTable table The mod settings table
---@param modUUID string The UUID of the mod
function MCMAPI:HandleMissingSetting(settingId, modSettingsTable, modUUID)
    -- Create a debounced warning function (500ms delay)
    if not self._debouncedWarnings then
        self._debouncedWarnings = {}
    end

    local warningKey = modUUID .. "_" .. settingId
    if not self._debouncedWarnings[warningKey] then
        self._debouncedWarnings[warningKey] = VCTimer:Debounce(500, function()
            local modInfo = Ext.Mod.GetMod(modUUID).Info
            local closestMatch, distance = VCString:FindClosestMatch(settingId, self:GetSettingsIDs(modSettingsTable),
                false)
            if closestMatch and distance < 9 then
                MCMWarn(0,
                    "Setting '%s' not found for mod '%s'. Did you mean '%s'? Please contact %s about this issue.",
                    settingId,
                    modInfo.Name,
                    closestMatch,
                    modInfo.Author)
            else
                MCMWarn(0,
                    "Setting '%s' not found for mod '%s'. Please contact %s about this issue.",
                    settingId,
                    modInfo.Name,
                    modInfo.Author)
            end
        end)
    end

    -- Call the debounced function
    self._debouncedWarnings[warningKey]()
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modUUID string The UUID of the mod
---@param shouldEmitEvent? boolean Whether to emit an event
---@return boolean success True if the setting was successfully updated
function MCMAPI:SetSettingValue(settingId, value, modUUID, shouldEmitEvent)
    if not settingId then
        MCMWarn(0, "settingId is nil. Value will not be saved.")
        return false
    end

    if not modUUID then
        MCMWarn(0, "modUUID is nil. Value will not be saved.")
        return false
    end

    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table is nil for mod UUID: %s", modUUID)
        return false
    end

    local oldValue = modSettingsTable[settingId]

    local isValid = self:IsSettingValueValid(settingId, value, modUUID)
    MCMDebug(2, "Setting value for %s is valid? %s", settingId, isValid)
    if not isValid then
        MCMWarn(0, "Invalid value for setting '%s' (%s). Value will not be saved.", settingId, value)
        return false
    end

    modSettingsTable[settingId] = value
    ModConfig:UpdateAllSettingsForMod(modUUID, modSettingsTable)

    ModEventManager:Emit(EventChannels.MCM_INTERNAL_SETTING_SAVED, {
        modUUID = modUUID,
        settingId = settingId,
        value = value
    }, true)

    if shouldEmitEvent then
        ModEventManager:Emit(EventChannels.MCM_SETTING_SAVED, {
            modUUID = modUUID,
            settingId = settingId,
            value = value,
            oldValue = oldValue
        }, true)
    end

    return true
end

---@param settingId string The id of the setting to reset
---@param modUUID? GUIDSTRING The UUID of the mod (optional)
---@param clientRequest? boolean (deprecated) Whether the request came from the client
function MCMAPI:ResetSettingValue(settingId, modUUID, clientRequest)
    modUUID = modUUID or ModuleUUID
    local shouldEmitEvent = true
    if clientRequest == true then
        shouldEmitEvent = false
    end

    local blueprint = self:GetModBlueprint(modUUID)
    if not blueprint then
        MCMWarn(0, "Blueprint not found for mod UUID: %s", modUUID)
        return
    end

    local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(0,
            "Setting '%s' not found in the blueprint for mod '%s'. Please contact %s about this issue.",
            settingId,
            modUUID,
            Ext.Mod.GetMod(modUUID).Info.Author)
    else
        self:SetSettingValue(settingId, defaultValue, modUUID, not shouldEmitEvent)
        -- NetChannels.MCM_SETTING_RESET:Broadcast({
        --     modUUID = modUUID,
        --     settingId = settingId,
        --     defaultValue = defaultValue
        -- })
    end
end

--- Reset all settings for a mod to their default values
-- function MCMAPI:ResetAllSettings(modUUID)
--     local modBlueprint = self.blueprints[modUUID]
--     local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

--     ModConfig:UpdateAllSettingsForMod(modUUID, defaultSettings)
--     NetChannels.MCM_RELAY_TO_SERVERS:Broadcast({
--         channel = EventChannels.MCM_ALL_MOD_SETTINGS_RESET,
--         payload = { modUUID = modUUID, settings = defaultSettings }
--     })
-- end

--- Registers a callback for an event button
---@param modUUID string The UUID of the mod
---@param settingId string The ID of the event button setting
---@param callback function The callback function to be executed when the event button is clicked
---@return boolean success Whether the callback was successfully registered
function MCMAPI:RegisterEventButtonCallback(modUUID, settingId, callback)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot register event button callback.")
        return false
    end

    if not settingId then
        MCMWarn(0, "settingId is nil. Cannot register event button callback.")
        return false
    end

    if not callback then
        MCMWarn(0, "callback must be a function. Cannot register event button callback.")
        return false
    end

    -- Verify that the mod and setting exist
    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for UUID: %s", modUUID)
        return false
    end

    -- TODO: use an interface instead of direct access to EventButtonRegistry
    local success = EventButtonRegistry.RegisterCallback(modUUID, settingId, callback)
    if success then
        MCMDebug(1, "Registered event button callback for mod '%s', setting '%s'", modUUID, settingId)
    else
        MCMWarn(0,
            "Failed to register event button callback for mod '%s', setting '%s'", modUUID, settingId)
    end
    return success
end

--- Unregister a callback for an event button
---@param modUUID string
---@param settingId string
---@return boolean success
function MCMAPI:UnregisterEventButtonCallback(modUUID, settingId)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot unregister event button callback.")
        return false
    end
    if not settingId then
        MCMWarn(0, "settingId is nil. Cannot unregister event button callback.")
        return false
    end

    -- TODO: use an interface instead of direct access to EventButtonRegistry
    local success = EventButtonRegistry.UnregisterCallback(modUUID, settingId)
    if success then
        MCMDebug(1, "Unregistered event button callback for mod '%s', setting '%s'", modUUID, settingId)
    else
        MCMWarn(0,
            "Failed to unregister event button callback for mod '%s', setting '%s'", modUUID, settingId)
    end
    return success
end

--- Set the disabled state of an event button
---@param modUUID string The UUID of the mod that owns the button
---@param settingId string The ID of the event button setting
---@param disabled boolean Whether the button should be disabled
---@param tooltipText? string Optional tooltip text to show when disabled
---@return boolean success True if the state was updated successfully
function MCMAPI:SetEventButtonDisabled(modUUID, settingId, disabled, tooltipText)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot set event button disabled state.")
        return false
    end
    if not settingId then
        MCMWarn(0, "settingId is nil. Cannot set event button disabled state.")
        return false
    end
    if disabled == nil then
        MCMWarn(0, "disabled parameter is required. Cannot set event button disabled state.")
        return false
    end

    -- Verify that the mod exists
    local modSettingsTable = self:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for UUID: %s", modUUID)
        return false
    end

    -- Check if the button exists by trying to get its current state
    local currentState = EventButtonRegistry.IsDisabled(modUUID, settingId)
    if currentState == nil then
        MCMWarn(0, "Button not found: mod='%s', setting='%s'", modUUID, settingId)
        return false
    end

    -- Update the disabled state via EventButtonRegistry
    local success = EventButtonRegistry.SetDisabled(modUUID, settingId, disabled, tooltipText)
    if success then
        MCMDebug(1, "Set disabled state for mod '%s', setting '%s' to %s", modUUID, settingId, disabled)
    else
        MCMWarn(0, "Failed to set disabled state for mod '%s', setting '%s'", modUUID, settingId)
    end

    return success
end

--- Check if an event button is disabled
---@param modUUID string The UUID of the mod that owns the button
---@param settingId string The ID of the event button setting
---@return boolean|nil isDisabled True if disabled, false if enabled, nil if button not found
function MCMAPI:IsEventButtonDisabled(modUUID, settingId)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get event button disabled state.")
        return nil
    end
    if not settingId then
        MCMWarn(0, "settingId is nil. Cannot get event button disabled state.")
        return nil
    end

    -- Delegate to EventButtonRegistry to check if the button exists and get its disabled state
    local isDisabled = EventButtonRegistry.IsDisabled(modUUID, settingId)
    if isDisabled == nil then
        MCMDebug(2, "Button not found or error getting state: mod='%s', setting='%s'", modUUID, settingId)
    else
        MCMDebug(3, "Current disabled state for mod '%s', setting '%s': %s", modUUID, settingId, isDisabled)
    end

    return isDisabled
end

--- Show feedback message for an event button
---@param modUUID string The UUID of the mod that owns the button
---@param settingId string The ID of the event button setting
---@param message string The feedback message to display
---@param feedbackType? string The type of feedback ("success", "error", "info", "warning"). Defaults to "info".
---@param durationInMs? number How long to display the feedback in milliseconds. Defaults to 5000ms.
---@return boolean success True if the feedback was shown successfully
function MCMAPI:ShowEventButtonFeedback(modUUID, settingId, message, feedbackType, durationInMs)
    if Ext.IsServer() then
        MCMWarn(0, "ShowEventButtonFeedback can only be called on the client")
        return false
    end

    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot show feedback for event button.")
        return false
    end
    if not settingId then
        MCMWarn(0, "settingId is nil. Cannot show feedback for event button.")
        return false
    end
    if not message or message == "" then
        MCMWarn(0, "message is empty. Cannot show empty feedback.")
        return false
    end

    -- Delegate to EventButtonRegistry to show the feedback with all parameters
    local success = EventButtonRegistry.ShowFeedback(modUUID, settingId, message, feedbackType or "info", durationInMs)

    if not success then
        MCMDebug(1, "Failed to show feedback for button: mod='%s', setting='%s'", modUUID, settingId)
    else
        MCMDebug(3, "Showing %s feedback for mod '%s', setting '%s': %s", feedbackType or "info", modUUID, settingId, message)
    end

    return success
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
