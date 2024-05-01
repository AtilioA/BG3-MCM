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

function ProfileManager:Create(mcmConfig)
    local profile = ProfileManager:New()

    if not mcmConfig then
        MCMWarn(1, "MCM config file is nil.")
        return
    end

    if not mcmConfig.Features or not mcmConfig.Features.Profiles then
        MCMWarn(1, "Profile feature is not properly configured in the MCM config JSON.")
        return
    end

    profile.SelectedProfile = mcmConfig.Features.Profiles.SelectedProfile
    profile.Profiles = mcmConfig.Features.Profiles.Profiles
    profile.DefaultProfile = mcmConfig.Features.Profiles.DefaultProfile

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
    local mcmFolder = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local configFilePath = mcmFolder .. '/' .. 'mcm_config.json'

    local data = ModConfig:LoadMCMConfig()
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

    Ext.Net.BroadcastMessage("MCM_Server_Set_Profile", Ext.Json.Stringify({
        profileName = profileName,
        newSettings = ModConfig.mods
    }))

    return true
end

--- Create a new profile and save it to the MCM configuration JSON file (mcm_config.json)
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

--- Delete a profile and save the changes to the MCM configuration JSON file (mcm_config.json)
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
