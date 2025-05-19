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
---@param profileName string
---@return boolean success
function ProfileService:CreateProfile(profileName)
  if not profileName or profileName == "" or profileName == "Default" then return false end

  -- Check if profile already exists
  if self.profiles and self.profiles.Profiles then
      for _, name in ipairs(self.profiles.Profiles) do
          if name == profileName then
              return false
          end
      end
  end

  -- Create the profile
  MCMAPI:CreateProfile(profileName)

  -- Update local cache
  self:GetProfiles()
  return self:SetProfile(profileName)
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
