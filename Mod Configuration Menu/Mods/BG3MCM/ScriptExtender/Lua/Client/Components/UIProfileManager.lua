-- TODO: review if this will even make sense and apply to others if it's sound

UIProfileManager = {}

function UIProfileManager:FindProfileIndex(profile)
    for i, name in ipairs(MCMAPI:GetProfiles().Profiles) do
        if name == profile then
            return i
        end
    end
    return nil
end

--- Create widgets for managing profiles (selecting, creating, deleting)
-- TODO: Emit events for these actions etc
function UIProfileManager:CreateProfileCollapsingHeader()
    local getDeleteProfileButtonLabel = function(profile)
        if profile == "Default" then
            return "Cannot delete the default profile."
        else
            return "Delete profile '" .. profile .. "'"
        end
    end

    local profiles = MCMAPI:GetProfiles()
    local currentProfile = MCMAPI:GetCurrentProfile()
    local profileIndex = UIProfileManager:FindProfileIndex(currentProfile)

    local profileCollapsingHeader = IMGUI_WINDOW:AddCollapsingHeader("Profile management")
    local profileCombo = profileCollapsingHeader:AddCombo("Select profile (WIP)")

    profileCombo.Options = { "Select a setting profile", table.unpack(profiles.Profiles) }
    profileCombo.SelectedIndex = profileIndex or 1

    local profileButton = profileCollapsingHeader:AddButton("Create profile")
    local newProfileName = profileCollapsingHeader:AddInputText("New profile name")
    newProfileName.SameLine = true

    local deleteProfileButton = profileCollapsingHeader:AddButton(getDeleteProfileButtonLabel(MCMAPI:GetCurrentProfile()))
    self:SetupDeleteProfileButton(deleteProfileButton, profileCombo, getDeleteProfileButtonLabel)

    self:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, getDeleteProfileButtonLabel,
        deleteProfileButton)

    self:SetupProfileComboOnChange(profileCombo, getDeleteProfileButtonLabel, deleteProfileButton)
    -- TODO: refresh the settings UI; currently it doesn't update when changing profiles and you need to reopen the MCM window
end

function UIProfileManager:SetupDeleteProfileButton(deleteProfileButton, profileCombo, getDeleteProfileButtonLabel)
    deleteProfileButton.OnClick = function()
        local currentProfile = MCMAPI:GetCurrentProfile()
        if currentProfile ~= "Default" then
            MCMAPI:DeleteProfile(currentProfile)
            profileCombo.Options = { "Select a setting profile", table.unpack(MCMAPI:GetProfiles().Profiles) }
            MCMAPI:SetProfile("Default")
            profileCombo.SelectedIndex = UIProfileManager:FindProfileIndex(MCMAPI:GetCurrentProfile())
            deleteProfileButton.Label = getDeleteProfileButtonLabel(MCMAPI:GetCurrentProfile())
        else
            MCMWarn(0, "Cannot delete the default profile.")
        end
    end
end

function UIProfileManager:SetupCreateProfileButton(profileButton, newProfileName, profileCombo,
                                                   getDeleteProfileButtonLabel,
                                                   deleteProfileButton)
    profileButton.OnClick = function()
        if newProfileName.Text ~= "" then
            MCMAPI:CreateProfile(newProfileName.Text)
            MCMAPI:SetProfile(newProfileName.Text)
            newProfileName.Text = ""
            profileCombo.Options = { "Select a setting profile", table.unpack(MCMAPI:GetProfiles().Profiles) }
            profileCombo.SelectedIndex = UIProfileManager:FindProfileIndex(MCMAPI:GetCurrentProfile())
            deleteProfileButton.Label = getDeleteProfileButtonLabel(MCMAPI:GetCurrentProfile())
        end
    end
end

function UIProfileManager:SetupProfileComboOnChange(profileCombo, getDeleteProfileButtonLabel, deleteProfileButton)
    profileCombo.OnChange = function(inputChange)
        local selectedIndex = inputChange.SelectedIndex + 1
        local selectedProfile = inputChange.Options[selectedIndex]
        MCMAPI:SetProfile(selectedProfile)

        if deleteProfileButton then
            deleteProfileButton.Label = getDeleteProfileButtonLabel(selectedProfile)
        end
    end
end
