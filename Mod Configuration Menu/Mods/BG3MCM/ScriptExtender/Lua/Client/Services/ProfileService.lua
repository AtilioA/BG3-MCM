---@class ProfileService
---@field currentProfile string
---@field profiles table
ProfileService = {
    currentProfile = "Default",
    profiles = {}
}

---Get all available profiles
---@return table profiles List of profile names
function ProfileService:GetProfiles()
    self.profiles = MCMAPI:GetProfiles()
    return self.profiles
end

---Get the current active profile
---@return string profileName
function ProfileService:GetCurrentProfile()
    return MCMAPI:GetCurrentProfile()
end

---Set the active profile
---@param profileName string
function ProfileService:SetProfile(profileName)
    if not profileName or profileName == "" then return end

    -- Verify the profile exists
    local exists = false
    if self.profiles and self.profiles.Profiles then
        for _, name in ipairs(self.profiles.Profiles) do
            if name == profileName then
                exists = true
                break
            end
        end
    end

    if exists or profileName == "Default" then
        self.currentProfile = profileName
        MCMAPI:SetProfile(profileName)
        return true
    end
    return false
end

---Create a new profile
---@param profileName string The name for the new profile
---@return boolean success True if the profile was created successfully
---@return string? errorMessage Error message if creation failed, nil on success
function ProfileService:CreateProfile(profileName)
    -- Try to create the profile and capture the success status and error message
    local success, errorMsg = MCMAPI:CreateProfile(profileName)
    if not success then
        if not errorMsg or errorMsg == "" then
            errorMsg = Ext.Loca.GetTranslatedString("h67618b59e83a4e4a985b6c9ac6eaddc44097") or "Failed to create profile"
        end
        return false, errorMsg
    end

    -- Update local cache
    self:GetProfiles()

    -- Set the new profile as active
    local setSuccess = self:SetProfile(profileName)
    if not setSuccess then
        return false,
            Ext.Loca.GetTranslatedString("h307fdf94464d4e4094cbd5a14524ff7a2aec") or "Profile created but failed to activate"
    end

    return true, nil
end

---Delete a profile
---@param profileName string
---@return boolean success
function ProfileService:DeleteProfile(profileName)
    if not profileName or profileName == "" or profileName == "Default" then return false end

    -- Check if profile exists
    local exists = false
    if self.profiles and self.profiles.Profiles then
        for _, name in ipairs(self.profiles.Profiles) do
            if name == profileName then
                exists = true
                break
            end
        end
    end

    if exists then
        MCMAPI:DeleteProfile(profileName)

        -- If we're deleting the current profile, switch to Default
        if self.currentProfile == profileName then
            self:SetProfile("Default")
        end

        -- Update local cache
        self:GetProfiles()
        return true
    end

    return false
end

-- Initialize
ProfileService:GetProfiles()

return ProfileService
