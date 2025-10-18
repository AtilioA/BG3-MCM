-- Profile management UI component that works directly with ProfileService
-- "Give someone state and they'll have a bug one day, but teach them how to represent state in two separate locations that have to be kept in sync and they'll have bugs for a lifetime."


---@class UIProfileManager
UIProfileManager = {}

---Find the index of a profile in the profiles list
---@param self UIProfileManager
---@param profile string The profile name to find
---@return number|nil index The 1-based index of the profile, or nil if not found
function UIProfileManager:FindProfileIndex(profile)
    if not profile then return nil end

    local profiles = ProfileService:GetProfiles()
    if not profiles then return nil end

    for i, name in ipairs(profiles.Profiles) do
        if name == profile then
            return i
        end
    end
    return nil
end

---Get the localized label for the delete profile button
---@param profile string The profile name
---@return string The localized button label
local function getDeleteProfileButtonLabel(profile)
    if profile == "Default" then
        return Ext.Loca.GetTranslatedString("hfdf59b69495c4aeca03f38977a00a69d431c")
    else
        local newString = VCString:InterpolateLocalizedMessage("h75b86690333d4937a1737fe8daddde41ga10", profile,
            { updateHandle = true })
        return newString
    end
end

---Create the profile management UI
---@param self UIProfileManager
function UIProfileManager:CreateProfileContent()
    -- Get current profiles and selection
    local profiles = ProfileService:GetProfiles() or {}
    local profileIndex = self:FindProfileIndex(ProfileService:GetCurrentProfile()) or 1

    -- Create UI elements using the new DualPane interface
    if not DualPane then return end

    local profilesGroup = DualPane:AddMenuSectionWithContent(
        Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"),
        Ext.Loca.GetTranslatedString("h2082b6b6954741ef970486be3bb77ad53782"),
        ClientGlobals.MCM_PROFILES
    )

    if not profilesGroup then return end

    profilesGroup:AddSeparatorText(Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"))

    -- Add disclaimer
    profilesGroup:AddText(Ext.Loca.GetTranslatedString("h48e0882af2b840e18f01ed08d40bfb03ggeb"))
    profilesGroup:AddText(Ext.Loca.GetTranslatedString("hcec0ce416d41404fa1358b7deb85124cb6d8"))

    -- Profile selection dropdown
    local profileCombo = profilesGroup:AddCombo("")
    profileCombo.Options = profiles.Profiles
    profileCombo.SelectedIndex = profileIndex - 1 -- Convert to 0-based index

    -- TODO: move button here but add delete confirmation

    -- Profile creation section
    local separatorText = Ext.Loca.GetTranslatedString("h5788159872f84825b184d42c1fbd6a216541")
    if separatorText then
        profilesGroup:AddSeparatorText(separatorText)
    end

    local newProfileName = profilesGroup:AddInputText("")

    -- Action buttons
    local buttonText = Ext.Loca.GetTranslatedString("h3e4b68e2569e4df2b548b4a5a893a57a7972")
    local profileButton = profilesGroup:AddButton(buttonText)
    profileButton.SameLine = true

    local deleteProfileButton = profilesGroup:AddButton(getDeleteProfileButtonLabel(ProfileService:GetCurrentProfile()))

    -- Set up button behaviors
    self:SetupDeleteProfileButton(deleteProfileButton, profileCombo)
    self:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    self:SetupProfileComboOnChange(profileCombo, deleteProfileButton)
end

---Update the delete profile button state based on current profile
---@param deleteProfileButton ExtuiButton The delete button to update
---@param profile? string Optional profile name to use instead of current profile
function UIProfileManager:UpdateDeleteProfileButton(deleteProfileButton, profile)
    if not deleteProfileButton then return end
    local currentProfile = profile or ProfileService:GetCurrentProfile()
    deleteProfileButton.Label = getDeleteProfileButtonLabel(currentProfile)
    deleteProfileButton.Visible = (currentProfile ~= "Default")
end

---Set up the delete profile button click handler
---@param deleteProfileButton ExtuiButton The delete button to set up
---@param profileCombo ExtuiCombo The profile selection dropdown
function UIProfileManager:SetupDeleteProfileButton(deleteProfileButton, profileCombo)
    deleteProfileButton.IDContext = "MCM_deleteProfileButton"

    deleteProfileButton.OnClick = function()
        local currentProfile = ProfileService:GetCurrentProfile()
        if currentProfile == "Default" then
            MCMWarn(0, "Cannot delete the default profile.")
            return
        end

        -- Delete the current profile and switch to Default
        ProfileService:DeleteProfile(currentProfile)
        ProfileService:SetProfile("Default")

        -- Update UI
        if profileCombo then
            local profiles = ProfileService:GetProfiles()
            if profiles then
                profileCombo.Options = profiles.Profiles or {}
                profileCombo.SelectedIndex = 0 -- Select Default profile (first in list)
                self:UpdateDeleteProfileButton(deleteProfileButton, "Default")
            end
        end
    end
end

---Set up the create profile button click handler
---@param profileButton ExtuiButton The create profile button
---@param newProfileName ExtuiInputText The input field for new profile name
---@param profileCombo ExtuiCombo The profile selection dropdown
---@param deleteProfileButton ExtuiButton The delete profile button
function UIProfileManager:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    profileButton.IDContext = "MCM_createProfileButton"
    profileButton.Disabled = newProfileName.Text == ""

    -- Add tooltip to the input field
    IMGUIHelpers.AddTooltip(profileButton, "Profile names cannot contain: < > : \" / \\ | ? *", ModuleUUID)

    -- Store the original button text for later restoration
    local originalButtonText = profileButton.Label

    -- Function to show error feedback
    local function showError(message)
        -- Change button to show error state
        profileButton.Label = message
        profileButton:SetColor("Text", Color.NormalizedRGBA(255, 0, 0, 1)) --
        profileButton.Disabled = true

        -- Revert after 3 seconds
        VCTimer:OnTime(3000, function()
            profileButton.Label = originalButtonText
            profileButton:SetColor("Text", UIStyle.Colors.Text)
            profileButton.Disabled = false
        end)
    end

    profileButton.OnClick = function()
        -- Trim whitespace from the profile name
        local profileName = newProfileName.Text:match("^%s*(.-)%s*$")

        -- Check for empty name
        if profileName == "" then
            showError(Ext.Loca.GetTranslatedString("Name cannot be empty"))
            return
        end

        -- Try to create the profile
        local success, errorMessage = ProfileService:CreateProfile(profileName)

        if success then
            -- Switch to the new profile
            if ProfileService:SetProfile(profileName) then
                newProfileName.Text = ""

                -- Update the dropdown
                if profileCombo then
                    local profiles = ProfileService:GetProfiles()
                    profileCombo.Options = profiles.Profiles or {}
                    local newIndex = self:FindProfileIndex(profileName) or 1
                    profileCombo.SelectedIndex = newIndex - 1 -- Convert to 0-based index
                    self:UpdateDeleteProfileButton(deleteProfileButton, profileName)
                end

                -- Show success feedback
                profileButton.Label = "Created!"
                profileButton.Disabled = true
                profileButton:SetColor("Text", Color.NormalizedRGBA(0, 255, 0, 1))

                -- Revert after 2 seconds
                VCTimer:OnTime(2000, function()
                    profileButton.Label = originalButtonText
                    profileButton:SetColor("Text", UIStyle.Colors.Text)
                end)
            end
        else
            -- Show the error message from the ProfileService
            showError(errorMessage or "Creation failed")
        end
    end

    -- Enable/disable button based on whether there's any text
    newProfileName.OnChange = function(input)
        local text = input.Text or ""
        profileButton.Disabled = text:match("^%s*$") ~= nil
    end
end

---Set up the profile selection dropdown change handler
---@param self UIProfileManager
---@param profileCombo ExtuiCombo The profile selection dropdown
---@param deleteProfileButton ExtuiButton The delete profile button
function UIProfileManager:SetupProfileComboOnChange(profileCombo, deleteProfileButton)
    profileCombo.IDContext = "MCM_profileCombo"

    ---@param inputChange {SelectedIndex: number, Options: string[]}
    profileCombo.OnChange = function(inputChange)
        local selectedIndex = inputChange.SelectedIndex + 1 -- Convert to 1-based index
        local selectedProfile = inputChange.Options[selectedIndex]

        if not selectedProfile then return end

        -- Switch to the selected profile
        if ProfileService:SetProfile(selectedProfile) then
            self:UpdateDeleteProfileButton(deleteProfileButton, selectedProfile)
        else
            -- Revert selection on failure
            local currentIndex = self:FindProfileIndex(selectedProfile) or 1
            profileCombo.SelectedIndex = currentIndex - 1 -- Convert to 0-based index
        end
    end
end
