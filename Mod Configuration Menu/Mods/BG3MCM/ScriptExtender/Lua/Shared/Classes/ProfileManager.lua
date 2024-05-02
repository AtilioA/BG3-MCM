-- The ProfileManager class manages the profiles for the Mod Configuration Menu system.
-- It handles loading, saving, and switching between different profiles, which allow users to have multiple configurations for their mod settings.
--
-- The ProfileManager class is responsible for:
-- - Maintaining the list of available profiles
-- - Keeping track of the currently selected profile
-- - Loading and saving profile data to the MCM configuration file
-- - Creating new profiles
-- - Setting the current profile
---@class ProfileManager
---@field DefaultProfile string The name of the default profile
---@field SelectedProfile string The name of the currently selected profile
---@field Profiles string[] A list of profile names
---@field DefaultConfig table The default configuration settings
ProfileManager = _Class:Create("ProfileManager", nil, {
    DefaultProfile = "Default",
    SelectedProfile = "Default",
    Profiles = { "Default" },
    DefaultConfig = {
        Features = {
            Profiles = {
                DefaultProfile = "Default",
                SelectedProfile = "Default",
                Profiles = {
                    "Default"
                }
            }
        }
    }
})

function ProfileManager:Create(mcmParams)
    local profile = ProfileManager:New()

    if not mcmParams then
        MCMWarn(1, "MCM config file is nil.")
        return
    end

    if not mcmParams.Features or not mcmParams.Features.Profiles then
        MCMWarn(1, "Profile feature is not properly configured in the MCM config JSON.")
        return
    end

    profile.SelectedProfile = mcmParams.Features.Profiles.SelectedProfile
    profile.Profiles = mcmParams.Features.Profiles.Profiles
    profile.DefaultProfile = mcmParams.Features.Profiles.DefaultProfile

    return profile
end

--- Get the currently selected profile.
---@return string The name of the currently selected profile, or the default profile if no profile data is found.
function ProfileManager:GetCurrentProfile()
    -- Fallback to default if no profile data is found
    if not self.Profiles or type(self.Profiles) ~= "table" then
        return self.DefaultProfile or "Default"
    end

    if self.SelectedProfile then
        return self.SelectedProfile
    end

    return self.DefaultProfile
end

--- Save the profile values to the MCM configuration file.
function ProfileManager:SaveProfileValuesToConfig()
    local configFilePath = ModConfig:GetMCMParamsFilePath()

    local data = ModConfig:LoadMCMParams()
    if not data then
        MCMWarn(1, "MCM config file not found: " .. configFilePath)
        return
    end

    data.Features.Profiles = {
        SelectedProfile = self.SelectedProfile,
        Profiles = self.Profiles,
        DefaultProfile = self.DefaultProfile
    }
    JsonLayer:SaveJSONFile(configFilePath, data)
end

--- Set the currently selected profile
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function ProfileManager:SetCurrentProfile(profileName)
    if not profileName then
        MCMWarn(1, "Profile name is required.")
        return false
    end

    if not self.Profiles then
        MCMWarn(1, "Profile feature is not properly configured in MCM.")
        return false
    end

    if not table.contains(self.Profiles, profileName) then
        MCMWarn(1,
            "Profile " ..
            profileName .. " does not exist. Available profiles: " .. table.concat(self.Profiles, ", "))
        return false
    end

    self.SelectedProfile = profileName

    MCMPrint(1, "Profile set to: " .. profileName)
    self:SaveProfileValuesToConfig()
    ModConfig:LoadSettings()

    -- TODO: untangle this from shared client/server code
    if Ext.IsServer() then
        Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SET_PROFILE, Ext.Json.Stringify({
            profileName = profileName,
            newSettings = ModConfig.mods
        }))
    end

    return true
end

--- Create a new profile and save it to the MCM params JSON file (mcm_params.json)
---@param profileName string The name of the new profile
---@return boolean success Whether the profile was successfully created
function ProfileManager:CreateProfile(profileName)
    if not self.Profiles then
        MCMWarn(1, "Profile feature is not properly configured in MCM.")
        return false
    end

    if table.contains(self.Profiles, profileName) then
        MCMWarn(1, "Profile " .. profileName .. " already exists.")
        return false
    end

    table.insert(self.Profiles, profileName)

    self:SaveProfileValuesToConfig()

    return true
end

--- Delete a profile and save the changes to the MCM params JSON file (mcm_params.json)
---@param profileName string The name of the profile to delete
---@return boolean Whether the profile was successfully deleted
function ProfileManager:DeleteProfile(profileName)
    if not self.Profiles then
        MCMWarn(1, "Profile feature is not properly configured in MCM.")
        return false
    end

    if not table.contains(self.Profiles, profileName) then
        MCMWarn(1, "Profile " .. profileName .. " does not exist and cannot be deleted.")
        return false
    end

    if profileName == self.DefaultProfile then
        MCMWarn(1, "Cannot delete the default profile.")
        return false
    end

    table.remove(self.Profiles, table.indexOf(self.Profiles, profileName))

    if self.SelectedProfile == profileName then
        self.SelectedProfile = self.DefaultProfile
    end
    self:SaveProfileValuesToConfig()

    return true
end

--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
--- @return string The full path to the settings file.
function ProfileManager:GetModProfileSettingsPath(modGUID)
    local MCMPath = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local profileName = self:GetCurrentProfile()
    local profilePath = MCMPath .. '/' .. "Profiles" .. '/' .. profileName

    local modFolderName = Ext.Mod.GetMod(modGUID).Info.Directory
    return profilePath .. '/' .. modFolderName
end
