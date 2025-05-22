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
        local newString = VCString:UpdateLocalizedMessage("h75b86690333d4937a1737fe8daddde41ga10", profile)
        return newString
    end
end

---Create the profile management UI
---@param self UIProfileManager
function UIProfileManager:CreateProfileContent()
    -- Get current profiles and selection
    local profiles = ProfileService:GetProfiles() or {}
    local profileIndex = self:FindProfileIndex(ProfileService:GetCurrentProfile()) or 1

    -- Create UI elements
    -- REFACTOR: encapsulate this within DualPane
    if not DualPane or not DualPane.leftPane then return end

    DualPane.leftPane:AddMenuSeparator(Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"))
    DualPane.leftPane:CreateMenuButton(
        Ext.Loca.GetTranslatedString("h2082b6b6954741ef970486be3bb77ad53782"),
        nil,
        ClientGlobals.MCM_PROFILES
    )

    if not DualPane.contentScrollWindow then return end
    local contentGroup = DualPane.contentScrollWindow:AddGroup(ClientGlobals.MCM_PROFILES)

    if not contentGroup then return end

    contentGroup:AddSeparatorText(Ext.Loca.GetTranslatedString("hb7ee77283bd94bd5b9d3fe696b45e85ae804"))

    -- Add disclaimer
    contentGroup:AddText(Ext.Loca.GetTranslatedString("h48e0882af2b840e18f01ed08d40bfb03ggeb"))
    contentGroup:AddText(Ext.Loca.GetTranslatedString("hcec0ce416d41404fa1358b7deb85124cb6d8"))

    -- Profile selection dropdown
    local profileCombo = contentGroup:AddCombo("")
    profileCombo.Options = profiles.Profiles
    profileCombo.SelectedIndex = profileIndex - 1 -- Convert to 0-based index

    -- TODO: move button here but add delete confirmation

    -- Profile creation section
    local separatorText = Ext.Loca.GetTranslatedString("h5788159872f84825b184d42c1fbd6a216541")
    if separatorText then
        contentGroup:AddSeparatorText(separatorText)
    end

    local newProfileName = contentGroup:AddInputText("")

    -- Action buttons
    local buttonText = Ext.Loca.GetTranslatedString("h3e4b68e2569e4df2b548b4a5a893a57a7972")
    local profileButton = contentGroup:AddButton(buttonText)
    profileButton.SameLine = true

    local deleteProfileButton = contentGroup:AddButton(getDeleteProfileButtonLabel(ProfileService:GetCurrentProfile()))

    -- Set up button behaviors
    self:SetupDeleteProfileButton(deleteProfileButton, profileCombo)
    self:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    self:SetupProfileComboOnChange(profileCombo, deleteProfileButton)
end

---Update the delete profile button state based on current profile
---@param deleteProfileButton UIButton The delete button to update
---@param profile? string Optional profile name to use instead of current profile
function UIProfileManager:UpdateDeleteProfileButton(deleteProfileButton, profile)
    if not deleteProfileButton then return end
    local currentProfile = profile or ProfileService:GetCurrentProfile()
    deleteProfileButton.Label = getDeleteProfileButtonLabel(currentProfile)
    deleteProfileButton.Visible = (currentProfile ~= "Default")
end

---Set up the delete profile button click handler
---@param deleteProfileButton UIButton The delete button to set up
---@param profileCombo UICombo The profile selection dropdown
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
            profileCombo.Options = ProfileService:GetProfiles() or {}
            profileCombo.SelectedIndex = 0 -- Select Default profile (first in list)
            self:UpdateDeleteProfileButton(deleteProfileButton, "Default")
        end
    end
end

---Set up the create profile button click handler
---@param profileButton UIButton The create profile button
---@param newProfileName UIInputText The input field for new profile name
---@param profileCombo UICombo The profile selection dropdown
---@param deleteProfileButton UIButton The delete profile button
function UIProfileManager:SetupCreateProfileButton(profileButton, newProfileName, profileCombo, deleteProfileButton)
    profileButton.IDContext = "MCM_createProfileButton"

    profileButton.OnClick = function()
        local profileName = newProfileName.Text:match("^%s*(.-)%s*$") -- Trim whitespace
        if profileName == "" then return end

        -- Create and switch to the new profile
        if ProfileService:CreateProfile(profileName) then
            ProfileService:SetProfile(profileName)

            -- Update UI
            newProfileName.Text = ""
            if profileCombo then
                profileCombo.Options = ProfileService:GetProfiles() or {}
                local newIndex = self:FindProfileIndex(profileName) or 1
                profileCombo.SelectedIndex = newIndex - 1 -- Convert to 0-based index
                self:UpdateDeleteProfileButton(deleteProfileButton, profileName)
            end
        else
            MCMWarn(0, string.format("Failed to create profile '%s'. It may already exist.", profileName))
        end
    end
end

---Set up the profile selection dropdown change handler
---@param self UIProfileManager
---@param profileCombo UICombo The profile selection dropdown
---@param deleteProfileButton UIButton The delete profile button
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
