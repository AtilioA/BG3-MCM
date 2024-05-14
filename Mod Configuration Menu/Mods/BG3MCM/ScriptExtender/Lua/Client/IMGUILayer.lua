---@class ModSettings
---@field widgets table<string, any> A table of widgets for the mod

--- A class representing an IMGUI layer responsible for providing a UI to manage mods and profiles.
--- A table of mod GUIDs, each associated with a table containing widgets and potentially other blueprints and settings.
-- The IMGUILayer class is responsible for creating and managing the IMGUI user interface for MCM.
-- It acts as the bridge between MCM's core business logic and MCM's IMGUI window, handling the rendering and interaction of the mod configuration UI.
-- It relies on settings and profiles managed by the MCM (API) class, and then translates this data into a user-friendly IMGUI interface.
-- IMGUILayer provides methods for:
-- - Creating the main MCM menu, which contains a tab for each mod that has MCM settings
-- - Creating new tabs and sections for each mod, based on the mod's blueprint
-- - Creating IMGUI widgets for each setting in the mod's blueprint
-- - Sending messages to the server to update setting values
---@class IMGUILayer: MetaClass
---@field mods table<string, ModSettings>
---@field private profiles table<string, table>
---@field private mod_tabs table<string, any> A table of tabs for each mod in the MCM
IMGUILayer = _Class:Create("IMGUILayer", nil, {
    mods = {},
    mods_tabs = {}
})

MCMClientState = IMGUILayer:New()

function IMGUILayer:SetClientStateValue(modGUID, settingId, value)
    if not modGUID or not settingId then
        return
    end

    local mod = MCMClientState.mods[modGUID]
    if not mod or not mod.settingsValues then
        return
    end

    mod.settingsValues[settingId] = value
end

function IMGUILayer:GetClientStateValue(modGUID, settingId)
    if not modGUID or not settingId then
        return nil
    end

    local mod = MCMClientState.mods[modGUID]
    if not mod or not mod.settingsValues then
        return nil
    end

    return mod.settingsValues[settingId]
end

--- Create the main IMGUI window for MCM
function IMGUILayer:CreateMainIMGUIWindow()
    local modMenuTitle = Ext.Loca.GetTranslatedString("hae2bbc06g288dg43dagb3a5g967fa625c769")
    if modMenuTitle == nil or modMenuTitle == "" then
        modMenuTitle = "Mod Configuration Menu"
    end

    MCM_WINDOW = Ext.IMGUI.NewWindow(modMenuTitle)

    local shouldOpenOnStart = MCMClientState:GetClientStateValue(ModuleUUID, "open_mcm_on_start")
    if shouldOpenOnStart == nil then
        shouldOpenOnStart = true
    end

    MCM_WINDOW.NoFocusOnAppearing = true

    MCM_WINDOW.Visible = shouldOpenOnStart
    MCM_WINDOW.Open = shouldOpenOnStart

    MCM_WINDOW.IDContext = "MCM_WINDOW"
    MCM_WINDOW.AlwaysAutoResize = true
    MCM_WINDOW.Closeable = true

    MCM_WINDOW:SetColor("Border", Color.normalized_rgba(0, 0, 0, 1))
    MCM_WINDOW:SetStyle("WindowBorderSize", 2)
    MCM_WINDOW:SetStyle("WindowRounding", 2)

    -- Set the window background color
    MCM_WINDOW:SetColor("TitleBg", Color.normalized_rgba(36, 28, 68, 0.5))
    MCM_WINDOW:SetColor("TitleBgActive", Color.normalized_rgba(36, 28, 68, 1))

    MCM_WINDOW:SetStyle("ScrollbarSize", 10)

    self.welcomeText = MCM_WINDOW:AddText(
        "Welcome to Baldur's Gate 3 Mod Configuration Menu!\nIf you don't see any mods here, you might need to load a save file first.\nIf you still don't see any mods, make sure you have mods that support MCM.\n\nBy default, you can press Insert to toggle this menu while it is unfocused.")

    -- TODO: add stuff to the menu bar (it's not working)
    -- local m = MCM_WINDOW:AddMainMenu()

    -- local help = m:AddMenu("Help")
    -- local helpAbout = help:AddItem("About")
    -- help:AddItem("Troubleshooting").OnClick = function()
    --     local aboutPopup = MCM_WINDOW:AddPopup("Yea")
    --     helpAbout.OnClick = function()
    --         aboutPopup:Open()
    --     end
    -- end
end

function IMGUILayer:ToggleMCMWindow()
    if MCM_WINDOW.Open == true then
        MCM_WINDOW.Visible = false
        MCM_WINDOW.Open = false
    else
        MCM_WINDOW.Visible = true
        MCM_WINDOW.Open = true
    end
end

--- Create the main MCM menu, which contains a tree view for each mod that has MCM settings
---@param mods table<string, table> A table of modGUIDs that has a table of blueprint and settings for each mod
---@return nil
function IMGUILayer:CreateModMenu(mods)
    -- If self.mods_tabs already has content, we don't want to populate the menu again
    if not table.isEmpty(self.mods_tabs) then
        return
    end

    if self.welcomeText then
        self.welcomeText:Destroy()
    end

    MCM_WINDOW.AlwaysAutoResize = MCMAPI:GetSettingValue("auto_resize_window", ModuleUUID)
    self.mods = mods

    -- Sort mods by name
    local sortedModKeys = MCMUtils.SortModsByName(mods)

    -- Convert the mod configs to use the Blueprint class
    for _modGUID, config in pairs(self.mods) do
        config.blueprint = Blueprint:New(config.blueprint)
    end

    -- Add functionality to manage between profiles
    UIProfileManager:CreateProfileCollapsingHeader()

    MCM_WINDOW:AddDummy(0, 10)

    -- Create the main table
    -- local modsSection = MCM_WINDOW:AddSeparator("Mods")
    local mainTable = MCM_WINDOW:AddTable("", 1)
    mainTable.IDContext = "MCM_MAIN_TABLE"
    local treeTableRow = mainTable:AddRow()

    -- Create the treeview
    local modsTree = treeTableRow:AddCell():AddTree("Mods")
    modsTree.FramePadding = true
    modsTree.CollapsingHeader = true
    modsTree.SpanFullWidth = true
    modsTree.Leaf = true

    -- Iterate over all mods and create the trees
    for _, modGUID in ipairs(sortedModKeys) do
        local modName = Ext.Mod.GetMod(modGUID).Info.Name
        local modItem = modsTree:AddTree(modName)
        modItem:SetColor("Text", Color.normalized_rgba(255, 255, 255, 1))
        -- modItem.CollapsingHeader = true
        -- Tentative way to open MCM options by default
        if modGUID == ModuleUUID then
            modItem.DefaultOpen = true
        end

        -- Add tooltip with mod version
        local modDescription = MCMUtils.AddNewlinesAfterPeriods(Ext.Mod.GetMod(modGUID).Info.Description)
        local modTabTooltip = modItem:Tooltip()
        modTabTooltip:AddText(modDescription)
        modItem.IDContext = modGUID

        modsTree:AddSeparator()

        self.mods_tabs[modGUID] = modItem
        self:CreateModMenuTab(modGUID)
    end
end

--- Create a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuTab(modGUID)
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    local modBlueprint = self.mods[modGUID].blueprint
    local modSettings = self.mods[modGUID].settingsValues
    local modTab = self.mods_tabs[modGUID]

    local function createModTabBar()
        local modTabs = modTab:AddTabBar(modInfo.Name .. "_TABS")

        if type(self.mods_tabs[modGUID]) == "table" then
            self.mods_tabs[modGUID].mod_tab_bar = modTabs
            self.mods[modGUID].widgets = {}
        else
            self.mods_tabs[modGUID] = { mod_tab_bar = modTabs }
            self.mods[modGUID].widgets = {}
        end

        return modTabs
    end

    -- Footer-like text with mod information
    local function createModTabFooter()
        modTab:AddSeparator()
        local modAuthor = modInfo.Author
        local modVersion = table.concat(modInfo.ModVersion, ".")
        local modDescription = modInfo.Description
        local modName = modInfo.Name

        local infoText = "Made by " .. modAuthor .. " | Version " .. modVersion
        local modInfoText = modTab:AddText(infoText)
        modInfoText:SetColor("Text", Color.normalized_rgba(255, 255, 255, 0.5))
        modInfoText.IDContext = modGUID .. "_FOOTER"
    end

    local modTabs = createModTabBar()

    -- Iterate over each tab in the mod blueprint to create a subtab for each
    for _, tab in ipairs(modBlueprint.Tabs) do
        self:CreateModMenuSubTab(modTabs, tab, modSettings, modGUID)
    end

    createModTabFooter()
end

--- Create a new tab for a mod in the MCM
---@param modsTab any The main tab for the mod
---@param tab BlueprintTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSubTab(modTabs, tab, modSettings, modGUID)
    local tabName = tab:GetTabLocaName()

    local tabHeader = modTabs:AddTabItem(tabName)

    -- TODO: as always, this should be abstracted away somehow but ehh (this will be needed for nested tabs etc)
    local tabSections = tab:GetSections()
    local tabSettings = tab:GetSettings()

    if #tabSections > 0 then
        for sectionIndex, section in ipairs(tab:GetSections()) do
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
---@param section BlueprintSection The section to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSection(sectionIndex, modGroup, section, modSettings, modGUID)
    -- TODO: Set the style for the section header text somehow
    if sectionIndex > 1 then
        modGroup:AddDummy(0, 5)
    end

    local sectionName = section:GetSectionLocaName()

    local sectionHeader = modGroup:AddSeparatorText(sectionName)
    sectionHeader:SetColor("Text", Color.normalized_rgba(255, 255, 255, 1))
    sectionHeader:SetColor("Separator", Color.normalized_rgba(255, 255, 255, 0.33))

    -- Iterate over each setting in the section to create a widget for each
    for _, setting in pairs(section:GetSettings()) do
        self:CreateModMenuSetting(modGroup, setting, modSettings, modGUID)
    end
end

--- Create a new setting for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param setting BlueprintSetting The setting to create a widget for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
---@see InputWidgetFactory
function IMGUILayer:CreateModMenuSetting(modGroup, setting, modSettings, modGUID)
    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if createWidget == nil then
        MCMWarn(0, "No widget factory found for setting type '" ..
            setting:GetType() ..
            "'. Please contact " .. Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        local widget = createWidget(modGroup, setting, settingValue, modGUID)
        self.mods[modGUID].widgets[setting:GetId()] = widget
    end
end

--- Insert a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@return nil
function IMGUILayer:InsertModMenuTab(modGUID, tabName, tabCallback)
    if not self.mods_tabs[modGUID] then
        self.mods_tabs[modGUID] = {
            mod_tab_bar = nil
        }
    end

    if self.mods_tabs[modGUID].mod_tab_bar then
        self:AddTabToModTabBar(modGUID, tabName, tabCallback)
        return
    end

    -- Create the mod tab bar if it doesn't exist
    self:CreateModTabBar(modGUID)

    self:AddTabToModTabBar(modGUID, tabName, tabCallback)
end

function IMGUILayer:CreateModTabBar(modGUID)
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    local modTab = self.modsTabBar:AddTabItem(modInfo.Name)
    -- Refactor this nonsense
    self.mods_tabs[modGUID].mod_tab = modTab

    local modTabs = modTab:AddTabBar(modInfo.Name .. "_TABS")
    self.mods_tabs[modGUID].mod_tab_bar = modTabs
end

--- Add a new tab to the mod tab bar
---@param modGUID string The UUID of the mod
---@param tabName string The name of the tab to be added
---@param tabCallback function The callback function to create the tab
function IMGUILayer:AddTabToModTabBar(modGUID, tabName, tabCallback)
    local modTabs = self.mods_tabs[modGUID].mod_tab_bar
    local newTab = modTabs:AddTabItem(tabName)
    tabCallback(newTab)

    Ext.Net.PostMessageToServer(Channels.MCM_MOD_TAB_ADDED, Ext.Json.Stringify({
        modGUID = modGUID,
        tabName = tabName
    }))
end
