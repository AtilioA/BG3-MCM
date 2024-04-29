-- TODO: refactor to actually use OOP probably but it sucks in Lua
---@class IMGUILayer: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
---@field private profiles table<string, table> A table of settings profiles for the MCM
---@field private mod_tabs table<string, any> A table of tabs for each mod in the MCM
-- The IMGUILayer class is responsible for creating and managing the IMGUI user interface for MCM.
-- It acts as the bridge between MCM's core business logic and MCM's IMGUI window, handling the rendering and interaction of the mod configuration UI.
-- It relies on settings and profiles sent by the MCM (API) class, and then translates this data into a user-friendly IMGUI interface.
--
-- IMGUILayer provides methods for:
-- - Creating the main MCM menu, which contains a tab for each mod that has MCM settings
-- - Creating new tabs and sections for each mod, based on the mod's schema
-- - Creating IMGUI widgets for each setting in the mod's schema
-- - Sending messages to the server to update setting values
IMGUILayer = _Class:Create("IMGUILayer", nil, {
    mods = {},
    profiles = {},
    mods_tabs = {}
})

MCM_IMGUI_API = IMGUILayer:New()

--- Factory for creating IMGUI widgets based on the type of setting
local InputWidgetFactory = {
    int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, IntIMGUIWidget)
    end,
    float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, FloatIMGUIWidget)
    end,
    checkbox = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, CheckboxIMGUIWidget)
    end,
    text = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, TextIMGUIWidget)
    end,
    enum = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, EnumIMGUIWidget)
    end,
    slider_int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, SliderIntIMGUIWidget)
    end,
    slider_float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, SliderFloatIMGUIWidget)
    end,
    drag_int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, DragIntIMGUIWidget)
    end,
    drag_float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, DragFloatIMGUIWidget)
    end,
    radio = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, RadioIMGUIWidget)
    end
}

-- Create widgets for managing profiles (selecting, creating, deleting)
-- TODO: Emit events for these actions, refactor yadda yadda
function IMGUILayer:CreateProfileCollapsingHeader()
    function findProfileIndex(profile)
        local profileIndex = nil
        for i, name in ipairs(MCM:GetProfiles().Profiles) do
            if name == profile then
                profileIndex = i
                break
            end
        end
        return profileIndex
    end

    function getDeleteProfileButtonLabel(profile)
        if profile == "Default" then
            return "Cannot delete the default profile."
        else
            return "Delete profile '" .. profile .. "'"
        end
    end

    local profiles = MCM:GetProfiles()
    local currentProfile = MCM:GetCurrentProfile()
    local profileIndex = findProfileIndex(currentProfile)


    local profileCollapsingHeader = IMGUI_WINDOW:AddCollapsingHeader("Profile management")
    local profileCombo = profileCollapsingHeader:AddCombo("Select profile (WIP)")

    profileCombo.Options = { "Select a setting profile", table.unpack(profiles.Profiles) }
    profileCombo.SelectedIndex = profileIndex or 1

    local profileButton = profileCollapsingHeader:AddButton("Create profile")
    local newProfileName = profileCollapsingHeader:AddInputText("New profile name")
    newProfileName.SameLine = true

    local deleteProfileButton = profileCollapsingHeader:AddButton(getDeleteProfileButtonLabel(MCM:GetCurrentProfile()))
    deleteProfileButton.OnClick = function()
        if MCM:GetCurrentProfile() ~= "Default" then
            MCM:DeleteProfile(MCM:GetCurrentProfile())
            profileCombo.Options = { "Select a setting profile", table.unpack(MCM:GetProfiles().Profiles) }
            MCM:SetProfile("Default")
            profileCombo.SelectedIndex = findProfileIndex(MCM:GetCurrentProfile())
            deleteProfileButton.Label = getDeleteProfileButtonLabel(MCM:GetCurrentProfile())
        else
            MCMWarn(0, "Cannot delete the default profile.")
        end
    end

    profileButton.OnClick = function()
        if newProfileName.Text ~= "" then
            MCM:CreateProfile(newProfileName.Text)
            MCM:SetProfile(newProfileName.Text)
            newProfileName.Text = ""
            profileCombo.Options = { "Select a setting profile", table.unpack(MCM:GetProfiles().Profiles) }
            profileCombo.SelectedIndex = findProfileIndex(MCM:GetCurrentProfile())
            deleteProfileButton.Label = getDeleteProfileButtonLabel(MCM:GetCurrentProfile())
        end
    end

    profileCombo.OnChange = function(inputChange)
        local selectedIndex = inputChange.SelectedIndex + 1
        local selectedProfile = inputChange.Options[selectedIndex]
        MCM:SetProfile(selectedProfile)

        if deleteProfileButton then
            deleteProfileButton.Label = getDeleteProfileButtonLabel(selectedProfile)
        end
        -- TODO: refresh the settings UI; currently it doesn't update when changing profiles and you need to reopen the MCM window
    end
end

--- Create the main MCM menu, which contains a tab for each mod that has MCM settings
---@param mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
---@param profiles table<string, table> A table of settings profiles for the MCM
---@return nil
function IMGUILayer:CreateModMenu(mods, profiles)
    self.mods = mods
    self.profiles = profiles
    -- TODO: modularize etc

    -- Add functionality to manage between profiles
    IMGUILayer:CreateProfileCollapsingHeader()

    IMGUI_WINDOW:AddDummy(0, 10)

    -- TODO: refactor what is part of the class and whatever
    -- Add the main tab bar for the mods
    self.modsTabBar = IMGUI_WINDOW:AddSeparatorText("Mods")
    self.modsTabBar = IMGUI_WINDOW:AddTabBar("Mods")

    -- Make the tabs under the mods tab bar have a list popup button and be reorderable
    -- self.modsTabBar.TabListPopupButton = true
    self.modsTabBar.Reorderable = true
    self.mods_tabs = {}

    -- Iterate over all mods and create a tab for each
    for modGUID, _ in pairs(self.mods) do
        local modTab = self.modsTabBar:AddTabItem(Ext.Mod.GetMod(modGUID).Info.Name)

        -- Add tooltip with mod version
        local modVersion = table.concat(Ext.Mod.GetMod(modGUID).Info.ModVersion, ".")
        local modTabTooltip = modTab:Tooltip()
        modTabTooltip:AddText("Version: " .. modVersion)

        self.mods_tabs[modGUID] = modTab
        self:CreateModMenuTab(modGUID)
    end
end

--- Create a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuTab(modGUID)
    modGUID = modGUID or ModuleUUID
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    -- local modSchema = MCM:GetModSchema(modGUID)
    local modSchema = self.mods[modGUID].schemas
    local modSettings = self.mods[modGUID].settingsValues
    -- local modSettings = MCM:GetModSettings(modGUID)
    local modTab = self.mods_tabs[modGUID]

    -- Create a new IMGUI group for the mod to hold all settings
    -- local modGroup = modTab:AddGroup(modInfo.Name .. "_GROUP")
    local modTabs = modTab:AddTabBar(modInfo.Name .. "_TABS")

    if type(self.mods_tabs[modGUID]) == "table" then
        self.mods_tabs[modGUID].mod_tab_bar = modTabs
    else
        self.mods_tabs[modGUID] = { mod_tab_bar = modTabs }
    end

    -- Iterate over each tab in the mod schema to create a subtab for each
    for _, tab in ipairs(modSchema.Tabs) do
        self:CreateModMenuSubTab(modTabs, tab, modSettings, modGUID)
    end
end

--- Create a new tab for a mod in the MCM
---@param modsTab any The main tab for the mod
---@param tab SchemaTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSubTab(modTabs, tab, modSettings, modGUID)
    -- TODO: modularize
    local tabName = tab.TabName
    if tab.Handles then
        if tab.Handles.NameHandle then
            local translatedName = Ext.Loca.GetTranslatedString(tab.Handles.NameHandle)
            if translatedName ~= nil and translatedName ~= "" then
                tabName = translatedName
            end
        end
    end

    local tabHeader = modTabs:AddTabItem(tabName)

    -- REFACTOR: as always, this is a mess and should be abstracted away somehow throughout the application if you're reading this im sorry lol given up with the commas too smh also I created classes for all these lil elements but I'm not using them here because something was not instantiated and I was focused on something else so it just slipped by
    local tabSections = tab.Sections
    local tabSettings = tab.Settings

    if #tabSections > 0 then
        for sectionIndex, section in ipairs(tab.Sections) do
            self:CreateModMenuSection(sectionIndex, tabHeader, section, modSettings, modGUID)
        end
    elseif #tabSettings > 0 then
        for _, setting in ipairs(tabSettings) do
            self:CreateModMenuSetting(tabHeader, setting, modSettings, modGUID)
        end
    end
end

--- Create a new section for a mod in the MCM
---@param sectionIndex number The index of the section
---@param modGroup any The IMGUI group for the mod
---@param section SchemaSection The section to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSection(sectionIndex, modGroup, section, modSettings, modGUID)
    -- TODO: Set the style for the section header text somehow
    if sectionIndex > 1 then
        modGroup:AddDummy(0, 5)
    end

    -- TODO: modularize
    local sectionName = section.SectionName
    if section.Handles then
        if section.Handles.NameHandle then
            local translatedName = Ext.Loca.GetTranslatedString(section.Handles.NameHandle)
            if translatedName ~= nil and translatedName ~= "" then
                sectionName = translatedName
            end
        end
    end

    local tabBar = modGroup:AddSeparatorText(sectionName)

    -- Iterate over each setting in the section to create a widget for each
    for _, setting in pairs(section.Settings) do
        self:CreateModMenuSetting(modGroup, setting, modSettings, modGUID)
    end
end

--- Create a new setting for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param setting SchemaSetting The setting to create a widget for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
---@see InputWidgetFactory
function IMGUILayer:CreateModMenuSetting(modGroup, setting, modSettings, modGUID)
    local settingValue = modSettings[setting.Id]
    local createWidget = InputWidgetFactory[setting.Type]
    if createWidget == nil then
        -- TODO: use MCMWarn after Shared-Server mess is sorted
        MCMWarn(0, "No widget factory found for setting type '" ..
            setting.Type ..
            "'. Please contact " .. Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        createWidget(modGroup, setting, settingValue, modGUID)
    end
end


-- TODO: this was just a quick test, needs to be heavily refactored along with IMGUILayer:CreateModMenuTab
--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function IMGUILayer:InsertModMenuTab(modGUID, tabName, tabCallback)
    -- Ensure the mods_tabs entry exists for this mod
    local modInfo = Ext.Mod.GetMod(modGUID).Info

    if not self.mods_tabs[modGUID] then
        self.mods_tabs[modGUID] = {
            mod_tab_bar = nil
        }
    end

    -- Create the mod tab bar if it doesn't exist
    if not self.mods_tabs[modGUID].mod_tab_bar then
        local modTab = self.modsTabBar:AddTabItem(Ext.Mod.GetMod(modGUID).Info.Name)
        self.mods_tabs[modGUID] = modTab

        local modTabs = modTab:AddTabBar(modInfo.Name .. "_TABS")

        if type(self.mods_tabs[modGUID]) == "table" then
            self.mods_tabs[modGUID].mod_tab_bar = modTabs
        else
            self.mods_tabs[modGUID] = { mod_tab_bar = modTabs }
        end
    end

    -- Update the IMGUILayer to include the new tab
    local modTabs = self.mods_tabs[modGUID].mod_tab_bar
    if modTabs then
        local newTab = modTabs:AddTabItem(tabName)
        tabCallback(newTab)
    end

    Ext.Net.PostMessageToServer("MCM_Mod_Tab_Added", Ext.Json.Stringify({
        modGUID = modGUID,
        tabName = tabName
    }))
end

Ext.RegisterNetListener("MCM_Mod_Tab_Added", function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local tabName = data.tabName
    local tabCallback = data.tabCallback

    -- Update the IMGUILayer to include the new tab
    IMGUILayer:InsertModMenuTab(modGUID, tabName, tabCallback)
end)
