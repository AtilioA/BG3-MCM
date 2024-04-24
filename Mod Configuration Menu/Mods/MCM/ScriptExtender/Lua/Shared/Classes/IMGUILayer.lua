---@class IMGUILayer: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
---@field private profiles table<string, table> A table of settings profiles for the MCM
---@field private mod_tabs table<string, any> A table of tabs for each mod in the MCM
IMGUILayer = _Class:Create("IMGUILayer", nil, {
    mods = {},
    profiles = {},
    mods_tabs = {}
})

--- Factory for creating IMGUI widgets based on the type of setting
local InputWidgetFactory = {
    int = function(group, setting, settingValue, modGUID)
        return IntIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    float = function(group, setting, settingValue, modGUID)
        return FloatIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    checkbox = function(group, setting, settingValue, modGUID)
        return CheckboxIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    text = function(group, setting, settingValue, modGUID)
        return TextIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    enum = function(group, setting, settingValue, modGUID)
        return EnumIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    slider = function(group, setting, settingValue, modGUID)
        return SliderIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    radio = function(group, setting, settingValue, modGUID)
        return RadioIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end
    -- dict = function(group, setting, settingValue, modGUID)
    --     return DictIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    -- end
}

--- Create the main MCM menu, which contains a tab for each mod that has MCM settings
---@return nil
function IMGUILayer:CreateModMenu()
    -- TODO: modularize etc
    -- Add a combobox to switch between profiles
    local profiles = MCM:GetProfiles()
    local currentProfile = MCM:GetCurrentProfile()
    local profileIndex = nil
    for i, name in ipairs(profiles.Profiles) do
        if name == currentProfile then
            profileIndex = i
            break
        end
    end

    local profileCombo = IMGUI_WINDOW:AddCombo("Profiles")

    profileCombo.Options = { "Select a setting profile", table.unpack(profiles.Profiles) }
    profileCombo.SelectedIndex = profileIndex or 1
    profileCombo.OnChange = function(inputChange)
        local selectedIndex = inputChange.SelectedIndex + 1
        local selectedProfile = inputChange.Options[selectedIndex]
        _P(selectedIndex, selectedProfile)
        MCM:SetProfile(selectedProfile)
        -- Refresh the mod settings after switching profiles
        -- self:CreateModMenuTab(modGUID)
    end

    local profileButton = IMGUI_WINDOW:AddButton("New Profile")
    local newProfileName = IMGUI_WINDOW:AddInputText("New Profile Name")
    newProfileName.SameLine = true
    profileButton.OnClick = function()
        _D(newProfileName)
        if newProfileName.Text ~= "" then
            MCM:CreateProfile(newProfileName.Text)
            profileCombo.Options = { "Select a setting profile", table.unpack(MCM:GetProfiles().Profiles) }
        end
    end

    local deleteProfileButton = IMGUI_WINDOW:AddButton("Delete Profile (WIP)")
    deleteProfileButton.OnClick = function()
        local currentProfile = MCM:GetCurrentProfile()
        if currentProfile ~= "Default" then
            -- MCM:DeleteProfile(currentProfile)
            profileCombo.Options = { "Select a setting profile", table.unpack(MCM:GetProfiles().Profiles) }
        else
            MCMWarn(0, "Cannot delete the default profile.")
        end
    end

    -- REFACTOR: improve this spacing logic nonsense
    IMGUI_WINDOW:AddSpacing()
    -- Add the main tab bar for the mods
    local tabBar = IMGUI_WINDOW:AddTabBar("Mods")
    self.mod_tabs = {}

    -- Iterate over all mods and create a tab for each
    for modGUID, _ in pairs(self.mods) do
        local modTab = tabBar:AddTabItem(Ext.Mod.GetMod(modGUID).Info.Name)
        self.mod_tabs[modGUID] = modTab
        self:CreateModMenuTab(modGUID)
    end
end

--- Create a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuTab(modGUID)
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    local modSchema = MCM:GetModSchema(modGUID)
    local modSettings = MCM:GetModSettings(modGUID)
    local modTab = self.mod_tabs[modGUID]

    -- Create a new IMGUI group for the mod to hold all settings
    local modGroup = modTab:AddGroup(modInfo.Name .. "_GROUP")
    local modTabs = modGroup:AddTabBar(modInfo.Name .. "_TABS")

    -- Iterate over each tab in the mod schema to create a subtab for each
    for _, tab in ipairs(modSchema:GetTabs()) do
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
    local tabHeader = modTabs:AddTabItem(tab:GetTabName())

    for _, section in ipairs(tab:GetSections()) do
        self:CreateModMenuSection(tabHeader, section, modSettings, modGUID)
    end
end

--- Create a new section for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param section SchemaSection The section to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSection(modGroup, section, modSettings, modGUID)
    local tabBar = modGroup:AddSeparator(section:GetSectionName())
    local sectionHeader = modGroup:AddText(section:GetSectionName())

    -- TODO: Set the style for the section header text somehow
    -- sectionHeader:SetStyleVar???

    -- Iterate over each setting in the section to create a widget for each
    for _, setting in pairs(section:GetSettings()) do
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
    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if createWidget == nil then
        MCMWarn(0,
            "No widget factory found for setting type '" ..
            setting:GetType() ..
            "'. Please contact " .. Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        createWidget(modGroup, setting, settingValue, modGUID)
    end
end
