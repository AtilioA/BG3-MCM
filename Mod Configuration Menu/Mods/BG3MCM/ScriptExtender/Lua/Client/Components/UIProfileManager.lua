-- "Give someone state and they'll have a bug one day, but teach them how to represent state in two separate locations that have to be kept in sync and they'll have bugs for a lifetime."
-- -ryg

-- Honestly, this is not worth being multiplayer-ready; I'll just make it work for the host for now.

UIProfileManager = {}

function UIProfileManager:FindProfileIndex(profile)
    for i, name in ipairs(MCMAPI:GetProfiles().Profiles) do
        if name == profile then
            return i
        end
    end
    return nil
end

local function getDeleteProfileButtonLabel(profile)
    if profile == "Default" then
        return Ext.Loca.GetTranslatedString("hfdf59b69495c4aeca03f38977a00a69d431c")
    else
        return VCString:UpdateLocalizedMessage("h75b86690333d4937a1737fe8daddde41ga10", profile)
    end
end

--- Create widgets for managing profiles (selecting, creating, deleting)
function UIProfileManager:CreateProfileContent()
    local profiles = MCMAPI:GetProfiles()
    local currentProfile = MCMAPI:GetCurrentProfile()
    local profileIndex = UIProfileManager:FindProfileIndex(currentProfile) - 1

    DualPane.leftPane:AddMenuSeparator(Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"), nil,
        "MCM_profiles")
    DualPane.leftPane:CreateMenuButton(Ext.Loca.GetTranslatedString("h2082b6b6954741ef970486be3bb77ad53782"), nil,
        "MCM_profiles")
    local contentGroup = DualPane.rightPane:CreateModGroup("MCM_profiles",
        Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"))

    if not contentGroup then
        return MCMError(0, "Failed to create profile content group.")
    end

    local profileCombo = contentGroup:AddCombo("")
    profileCombo.Options = profiles.Profiles
    profileCombo.SelectedIndex = profileIndex or 1

    -- Create/delete profile buttons

    contentGroup:AddSeparatorText(Ext.Loca.GetTranslatedString("h5788159872f84825b184d42c1fbd6a216541"))
    local newProfileName = contentGroup:AddInputText("")
    local profileButton = contentGroup:AddButton(Ext.Loca.GetTranslatedString("h3e4b68e2569e4df2b548b4a5a893a57a7972"))
    profileButton.SameLine = true

    local deleteProfileButton = contentGroup:AddButton(getDeleteProfileButtonLabel(MCMAPI:GetCurrentProfile()))
    self:SetupDeleteProfileButton(deleteProfileButton, profileCombo)
    self:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    self:SetupProfileComboOnChange(profileCombo, deleteProfileButton)
    -- TODO: refresh the settings UI when creating profiles
end

function UIProfileManager:UpdateDeleteProfileButton(deleteProfileButton, profile)
    if not deleteProfileButton then return end

    local newLabel = getDeleteProfileButtonLabel(MCMAPI:GetCurrentProfile())
    deleteProfileButton.Label = newLabel

    if profile == "Default" then
        deleteProfileButton.Visible = false
    else
        deleteProfileButton.Visible = true
    end
end

function UIProfileManager:SetupDeleteProfileButton(deleteProfileButton, profileCombo)
    deleteProfileButton.IDContext = "MCM_deleteProfileButton"
    deleteProfileButton.OnClick = function()
        local currentProfile = MCMAPI:GetCurrentProfile()
        if currentProfile ~= "Default" then
            MCMAPI:DeleteProfile(currentProfile)
            profileCombo.Options = MCMAPI:GetProfiles().Profiles
            MCMAPI:SetProfile("Default")
            profileCombo.SelectedIndex = UIProfileManager:FindProfileIndex(MCMAPI:GetCurrentProfile()) - 1
            self:UpdateDeleteProfileButton(deleteProfileButton, MCMAPI:GetCurrentProfile())

            -- TODO: handle the response from the server
            Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE, Ext.Json.Stringify({
                profileName = currentProfile
            }))
        else
            MCMWarn(0, "Cannot delete the default profile.")
        end
    end
end

function UIProfileManager:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    profileButton.IDContext = "MCM_createProfileButton"
    profileButton.OnClick = function()
        if newProfileName.Text ~= "" then
            MCMAPI:CreateProfile(newProfileName.Text)
            MCMAPI:SetProfile(newProfileName.Text)

            -- TODO: handle the response from the server
            Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE, Ext.Json.Stringify({
                profileName = newProfileName.Text
            }))

            newProfileName.Text = ""
            profileCombo.Options = MCMAPI:GetProfiles().Profiles
            profileCombo.SelectedIndex = UIProfileManager:FindProfileIndex(MCMAPI:GetCurrentProfile()) - 1
            self:UpdateDeleteProfileButton(deleteProfileButton, MCMAPI:GetCurrentProfile())
        end
    end
end

function UIProfileManager:SetupProfileComboOnChange(profileCombo, deleteProfileButton)
    profileCombo.IDContext = "MCM_profileCombo"
    profileCombo.OnChange = function(inputChange)
        local selectedIndex = inputChange.SelectedIndex + 1
        local selectedProfile = inputChange.Options[selectedIndex]

        -- Handle the placeholder option (this isn't used anymore)
        if selectedProfile == "Select a setting profile" then
            MCMWarn(1, "Please select a valid profile.")
            -- Reset the combo box to the current profile
            -- MCMAPI:GetCurrentProfile()
            profileCombo.SelectedIndex = UIProfileManager:FindProfileIndex(MCMAPI:GetCurrentProfile()) - 1
            return
        end

        MCMAPI:SetProfile(selectedProfile)

        -- TODO: handle the response from the server
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE, Ext.Json.Stringify({
            profileName = selectedProfile
        }))

        self:UpdateDeleteProfileButton(deleteProfileButton, selectedProfile)
    end
end
