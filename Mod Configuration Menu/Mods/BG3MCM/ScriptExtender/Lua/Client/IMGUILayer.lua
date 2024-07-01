---@class ModSettings
---@field blueprint Blueprint The blueprint for the mod
---@field settingsValues table<string, any> A table of settings for the mod
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
---@field private visibilityTriggers table<string, table>
IMGUILayer = _Class:Create("IMGUILayer", nil, {
    mods = {},
    visibilityTriggers = {}
})

MCMClientState = IMGUILayer:New()

function IMGUILayer:SetClientStateValue(settingId, value, modGUID)
    modGUID = modGUID or ModuleUUID
    if not modGUID or not settingId then
        return
    end

    local mod = MCMClientState.mods[modGUID]
    if not mod or not mod.settingsValues then
        return
    end

    self:UpdateVisibility(modGUID, settingId, value)

    mod.settingsValues[settingId] = value

    -- Check if the setting is of type 'text'; no need to update the UI value for text settings
    -- Also, doing so creates issues with the text input field
    local blueprint = MCMAPI:GetModBlueprint(modGUID)
    if not blueprint then return end

    local setting = blueprint:GetAllSettings()[settingId]
    if not setting or setting:GetType() == "text" then return end

    -- Update the displayed value for non-text settings
    IMGUIAPI:UpdateSettingUIValue(settingId, value, modGUID)
end

-- TODO: this should be refactored to use OOP or at least be more modular, however I've wasted too much time on this already with Lua's nonsense, so I'm stashing and leaving it as is
function IMGUILayer:UpdateVisibility(modGUID, settingId, value)
    if not modGUID or not settingId or value == nil then
        return
    end

    local visibilityTriggers = self.visibilityTriggers[modGUID]
    if not visibilityTriggers then
        return
    end

    local settingTriggers = visibilityTriggers[settingId]
    if not settingTriggers then
        return
    end

    self:ProcessTriggers(settingTriggers, value, modGUID)
end

function IMGUILayer:ProcessTriggers(settingTriggers, value, modGUID)
    for group, operators in pairs(settingTriggers) do
        if not group or not operators then
            MCMWarn(0, "Invalid visibility trigger group for mod '" ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                "'. Please contact " ..
                Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            goto continue
        end

        self:ProcessOperators(group, operators, value, modGUID)

        ::continue::
    end
end

function IMGUILayer:ProcessOperators(group, operators, value, modGUID)
    for operator, triggerValue in pairs(operators) do
        if not operator or triggerValue == nil then
            MCMWarn(0, "Invalid visibility trigger operator or value for mod '" ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                "'. Please contact " ..
                Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            goto continue
        end

        group.Visible = self:EvaluateCondition(operator, value, triggerValue, modGUID)

        ::continue::
    end
end

function IMGUILayer:EvaluateCondition(operator, value, triggerValue, modGUID)
    if operator == nil or value == nil or triggerValue == nil then
        MCMWarn(0,
            "Invalid comparison operator or values passed by mod '" ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            "' for visibility condition. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end

    local strValue, strTrigger = tostring(value), tostring(triggerValue)
    local numValue, numTrigger = tonumber(value), tonumber(triggerValue)

    local operators = {
        ["=="] = function(a, b) return a == b end,
        ["!="] = function(a, b) return a ~= b end,
        ["<="] = function(a, b) return a <= b end,
        [">="] = function(a, b) return a >= b end,
        ["<"] = function(a, b) return a < b end,
        [">"] = function(a, b) return a > b end
    }

    if operators[operator] then
        if operator == "==" or operator == "!=" then
            return operators[operator](strValue, strTrigger)
        elseif numValue ~= nil and numTrigger ~= nil then
            return operators[operator](numValue, numTrigger)
        end
        return false
    end

    MCMWarn(0, "Unknown comparison operator: " .. operator .. " for mod '" ..
        Ext.Mod.GetMod(modGUID).Info.Name ..
        "'. Please contact " ..
        Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
    return false
end

function IMGUILayer:GetClientStateValue(settingId, modGUID)
    modGUID = modGUID or ModuleUUID
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
    if not Ext.IMGUI then
        MCMWarn(0, "IMGUI is not available, skipping MCM window creation.")
        return false
    end

    if self.welcomeText then
        -- self.welcomeText:Destroy()
        MCMDebug(2, "Welcome text already exists, skipping...")
        return true
    end

    local modMenuTitle = Ext.Loca.GetTranslatedString("hae2bbc06g288dg43dagb3a5g967fa625c769")
    if modMenuTitle == nil or modMenuTitle == "" then
        modMenuTitle = "Mod Configuration Menu"
    end

    MCM_WINDOW = Ext.IMGUI.NewWindow(modMenuTitle)
    MCM_WINDOW.IDContext = "MCM_WINDOW"

    local shouldOpenOnStart = MCMClientState:GetClientStateValue("open_on_start", ModuleUUID)
    if shouldOpenOnStart == nil then
        shouldOpenOnStart = true
    end

    MCM_WINDOW.NoFocusOnAppearing = true

    MCM_WINDOW.Visible = shouldOpenOnStart
    MCM_WINDOW.Open = shouldOpenOnStart

    MCM_WINDOW.AlwaysAutoResize = true
    MCM_WINDOW.Closeable = true

    UIStyle:ApplyStyleToIMGUIElement(MCM_WINDOW)

    self.welcomeText = MCM_WINDOW:AddText(
        MCMUtils.ReplaceBrWithNewlines(
            Ext.Loca.GetTranslatedString(
                "h81a4a9991875424984b876d017675879c959")
        )
    )

    MainMenu.CreateMainMenu()

    return true
end

--- Toggles the visibility of the MCM window.
--- @param playSound boolean Whether to play a sound effect when toggling the window.
function IMGUILayer:ToggleMCMWindow(playSound)
    if not MCM_WINDOW then
        return
    end

    if MCM_WINDOW.Open == true then
        MCM_WINDOW.Visible = false
        MCM_WINDOW.Open = false
        Ext.Net.PostMessageToServer(Channels.MCM_USER_CLOSED_WINDOW, Ext.Json.Stringify({
            playSound = playSound
        }))
    else
        MCM_WINDOW.Visible = true
        MCM_WINDOW.Open = true
        Ext.Net.PostMessageToServer(Channels.MCM_USER_OPENED_WINDOW, Ext.Json.Stringify({
            playSound = playSound
        }))
    end
end

function IMGUILayer:SetActiveWindowAlpha(bool)
    VCTimer:OnTime(100, function()
        if bool then
            MCM_WINDOW:SetStyle("Alpha", 1)
            MCM_WINDOW.Visible = bool
        else
            MCM_WINDOW:SetStyle("Alpha", 0.67)
        end
    end)
end

function IMGUILayer:NotifyMCMWindowReady()
    Ext.Net.PostMessageToServer(Channels.MCM_WINDOW_READY, "")
end

function IMGUILayer:LoadMods(mods)
    self.mods = mods
    local createdWindow = self:CreateMainIMGUIWindow()
    if not createdWindow then
        return
    end
    self:CreateModMenu()
    self:NotifyMCMWindowReady()
end

--- Create the main MCM menu, which contains a tree view for each mod that has MCM settings
---@return nil
function IMGUILayer:CreateModMenu()
    if not self:ShouldPopulateMenu() then
        return
    end

    self:PrepareMenu()
    self:ConvertModTablesToBlueprints()
    self:CreateProfileManagementHeader()
    self:CreateMainTable()
end

--- Check if the menu should be populated
---@return boolean
function IMGUILayer:ShouldPopulateMenu()
    -- If uiGroup exist for MCM, init done, we don't want to populate the menu again
    return FrameManager:GetGroup(ModuleUUID) == nil
end

--- Initialize menu settings and destroy welcome text if it exists
---@return nil
function IMGUILayer:PrepareMenu()
    if self.welcomeText then
        self.welcomeText:Destroy()
    end

    MCM_WINDOW.AlwaysAutoResize = MCMAPI:GetSettingValue("auto_resize_window", ModuleUUID)
    -- Table Layout
    FrameManager:initFrameLayout(MCM_WINDOW)
end

--- Convert the mod configs to use the Blueprint class
---@return nil
function IMGUILayer:ConvertModTablesToBlueprints()
    for _modGUID, config in pairs(self.mods) do
        config.blueprint = Blueprint:New(config.blueprint)
    end
end

--- Create profile management header
---@return nil
function IMGUILayer:CreateProfileManagementHeader()
    UIProfileManager:CreateProfileContent()
    MCM_WINDOW:AddDummy(0, 10)
end

--- Create the main table and populate it with mod trees
---@return nil
function IMGUILayer:CreateMainTable()
    FrameManager:AddMenuSection(Ext.Loca.GetTranslatedString("h47d091e82e1a475b86bbe31555121a22eca7"))

    local sortedModKeys = MCMUtils.SortModsByName(self.mods)
    for _, modGUID in ipairs(sortedModKeys) do
        self.visibilityTriggers[modGUID] = {}

        local modName = self:GetModName(modGUID)
        local modDescription = MCMUtils.AddNewlinesAfterPeriods(Ext.Mod.GetMod(modGUID).Info.Description)
        FrameManager:addButtonAndGetModTabBar(modName, modDescription, modGUID)
        self.mods[modGUID].widgets = {}

        self:CreateModMenuFrame(modGUID)

        local modSettings = self.mods[modGUID].settingsValues
        for settingId, group in pairs(self.visibilityTriggers[modGUID]) do
            self:UpdateVisibility(modGUID, settingId, modSettings[settingId])
        end
    end
    FrameManager:setVisibleFrame(ModuleUUID)
end

--- Get the mod name, considering custom blueprint names
---@param modGUID string
---@return string
function IMGUILayer:GetModName(modGUID)
    local modName = Ext.Mod.GetMod(modGUID).Info.Name
    local blueprintCustomName = self.mods[modGUID].blueprint:GetModName()
    if blueprintCustomName then
        modName = blueprintCustomName
    end
    return modName
end

--- Create a new tab for a mod in the MCM
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuFrame(modGUID)
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    local modBlueprint = self.mods[modGUID].blueprint
    local modSettings = self.mods[modGUID].settingsValues
    local uiGroupMod = FrameManager:GetGroup(modGUID)
    local modTabBar = FrameManager:GetModTabBar(modGUID)

    -- Footer-like text with mod information
    local function createModTabFooter()
        uiGroupMod:AddSeparator()
        uiGroupMod.IDContext = modGUID .. "_FOOTER"
        local modAuthor = modInfo.Author
        local modVersion = table.concat(modInfo.ModVersion, ".")
        -- local modDescription = modInfo.Description
        -- local modName = modInfo.Name

        local infoText = "Made by " .. modAuthor .. " | Version " .. modVersion
        local modInfoText = uiGroupMod:AddText(infoText)
        modInfoText:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.5))
        modInfoText.IDContext = modGUID .. "_FOOTER"
    end

    -- Iterate over each tab in the mod blueprint to create a subtab for each
    for _, tabInfo in ipairs(modBlueprint.Tabs) do
        self:CreateModMenuSubTab(modTabBar, tabInfo, modSettings, modGUID)
    end

    createModTabFooter()
end

--- Create a new tab for a mod in the MCM
---@param modsTab any The main tab for the mod
---@param tab BlueprintTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modGUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSubTab(modTabs, tabInfo, modSettings, modGUID)
    local tabName = tabInfo:GetTabLocaName()

    local tab = modTabs:AddTabItem(tabName)
    tab.IDContext = modGUID .. "_" .. tabInfo:GetTabName()
    tab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabInfo:GetTabName())
        Ext.Net.PostMessageToServer(Channels.MCM_MOD_SUBTAB_ACTIVATED, Ext.Json.Stringify({
            modGUID = modGUID,
            tabName = tabInfo:GetTabName()
        }))
    end

    -- TODO: as always, this should be abstracted away somehow but ehh (this will be needed for nested tabs etc)
    local tabSections = tabInfo:GetSections()
    local tabSettings = tabInfo:GetSettings()

    self:manageVisibleIf(modGUID, tabInfo, tab)

    if #tabSections > 0 then
        for sectionIndex, section in ipairs(tabInfo:GetSections()) do
            self:CreateModMenuSection(sectionIndex, tab, section, modSettings, modGUID)
        end
    elseif #tabSettings > 0 then
        for _, setting in ipairs(tabSettings) do
            self:CreateModMenuSetting(tab, setting, modSettings, modGUID)
        end
    end
end

function IMGUILayer:manageVisibleIf(modGUID, elementInfo, uiElement)
    if elementInfo.VisibleIf and elementInfo.VisibleIf.Conditions then
        for _, condition in ipairs(elementInfo.VisibleIf.Conditions) do
            local settingIdTriggering = condition.SettingId
            local operator = condition.Operator
            local value = condition.ExpectedValue
            self.visibilityTriggers[modGUID] = self.visibilityTriggers[modGUID] or {}
            self.visibilityTriggers[modGUID][settingIdTriggering] = self.visibilityTriggers[modGUID]
                [settingIdTriggering] or {}
            self.visibilityTriggers[modGUID][settingIdTriggering][uiElement] = self.visibilityTriggers[modGUID]
                [settingIdTriggering][uiElement] or {}
            self.visibilityTriggers[modGUID][settingIdTriggering][uiElement][operator] = value
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
    local sectionId = section:GetSectionId()
    local sectionOptions = section:GetOptions()
    local sectionGroup = modGroup:AddGroup(sectionId)

    self:manageVisibleIf(modGUID, section, sectionGroup)

    local sectionContentElement = sectionGroup
    if sectionOptions.IsCollapsible then
        local sectionCollapsingHeader = sectionGroup:AddCollapsingHeader(sectionName)
        sectionContentElement = sectionCollapsingHeader
    else
        local sectionHeader = sectionContentElement:AddSeparatorText(sectionName)
        sectionHeader.IDContext = modGUID .. "_" .. sectionName
        sectionHeader:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
        sectionHeader:SetColor("Separator", Color.NormalizedRGBA(255, 255, 255, 0.33))
    end

    -- Iterate over each setting in the section to create a widget for each
    for _, setting in pairs(section:GetSettings()) do
        self:CreateModMenuSetting(sectionContentElement, setting, modSettings, modGUID)
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
        local widgetGroup = modGroup:AddGroup(setting:GetId())
        local widget = createWidget(widgetGroup, setting, settingValue, modGUID)

        self:manageVisibleIf(modGUID, setting, widgetGroup)

        self.mods[modGUID].widgets[setting:GetId()] = widget
    end
end
