---@class ModSettings
---@field blueprint Blueprint The blueprint for the mod
---@field settingsValues table<string, any> A table of settings for the mod
---@field widgets table<string, any> A table of widgets for the mod

--- A class representing an IMGUI layer responsible for providing a UI to manage mods and profiles.
--- A table of mod UUIDs, each associated with a table containing widgets and potentially other blueprints and settings.
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

function IMGUILayer:SetClientStateValue(settingId, value, modUUID)
    modUUID = modUUID or ModuleUUID
    if not modUUID or not settingId then
        return
    end

    local mod = MCMClientState.mods[modUUID]
    if not mod or not mod.settingsValues then
        return
    end

    self:UpdateVisibility(modUUID, settingId, value)
    self:UpdateSettingValue(mod, settingId, value, modUUID)
end

function IMGUILayer:UpdateSettingValue(mod, settingId, value, modUUID)
    -- Update client values for the setting
    -- REFACTOR: this is not related to the IMGUI layer, should be moved to a more appropriate place
    mod.settingsValues[settingId] = value
    MCMAPI.mods[modUUID].settingsValues[settingId] = value

    -- Check if the setting is of type 'text'; no need to update the UI value for text settings
    -- Also, doing so creates issues with the text input field
    local blueprint = MCMAPI:GetModBlueprint(modUUID)
    if not blueprint then return end

    local setting = blueprint:GetAllSettings()[settingId]
    if not setting or setting:GetType() == "text" then return end

    -- Update the displayed value for non-text settings
    IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)
end

-- TODO: this should be refactored to use OOP or at least be more modular, however I've wasted too much time on this already with Lua's nonsense, so I'm stashing and leaving it as is
function IMGUILayer:UpdateVisibility(modUUID, settingId, value)
    if not modUUID or not settingId or value == nil then
        return
    end

    local visibilityTriggers = self.visibilityTriggers[modUUID]
    if not visibilityTriggers then
        return
    end

    local settingTriggers = visibilityTriggers[settingId]
    if not settingTriggers then
        return
    end

    self:ProcessTriggers(settingTriggers, value, modUUID)
end

function IMGUILayer:ProcessTriggers(settingTriggers, value, modUUID)
    for group, operators in pairs(settingTriggers) do
        if not group or not operators then
            MCMWarn(0, "Invalid visibility trigger group for mod '" ..
                Ext.Mod.GetMod(modUUID).Info.Name ..
                "'. Please contact " ..
                Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
            goto continue
        end

        self:ProcessOperators(group, operators, value, modUUID)

        ::continue::
    end
end

function IMGUILayer:ProcessOperators(group, operators, value, modUUID)
    for operator, triggerValue in pairs(operators) do
        if not operator or triggerValue == nil then
            MCMWarn(0, "Invalid visibility trigger operator or value for mod '" ..
                Ext.Mod.GetMod(modUUID).Info.Name ..
                "'. Please contact " ..
                Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
            goto continue
        end

        group.Visible = self:EvaluateCondition(operator, value, triggerValue, modUUID)

        ::continue::
    end
end

function IMGUILayer:EvaluateCondition(operator, value, triggerValue, modUUID)
    if operator == nil or value == nil or triggerValue == nil then
        MCMWarn(0,
            "Invalid comparison operator or values passed by mod '" ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            "' for visibility condition. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
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
        Ext.Mod.GetMod(modUUID).Info.Name ..
        "'. Please contact " ..
        Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
    return false
end

function IMGUILayer:GetClientStateValue(settingId, modUUID)
    modUUID = modUUID or ModuleUUID
    if not modUUID or not settingId then
        return nil
    end

    local mod = MCMClientState.mods[modUUID]
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
        -- TODO: re-enable this sfx logic after refactoring client-side code
        ModEventManager:Emit(EventChannels.MCM_USER_CLOSED_WINDOW, {
            playSound = playSound
        })
    else
        MCM_WINDOW.Visible = true
        MCM_WINDOW.Open = true
        ModEventManager:Emit(EventChannels.MCM_USER_OPENED_WINDOW, {
            playSound = playSound
        })
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
    ModEventManager:Emit(EventChannels.MCM_WINDOW_READY, {})
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

    -- TODO: re-enable this after refactoring client-side code
    MCM_WINDOW.AlwaysAutoResize = MCMAPI:GetSettingValue("auto_resize_window", ModuleUUID)

    -- Table Layout
    FrameManager:initFrameLayout(MCM_WINDOW)
end

--- Convert the mod configs to use the Blueprint class
---@return nil
function IMGUILayer:ConvertModTablesToBlueprints()
    for _modUUID, config in pairs(self.mods) do
        config.blueprint = Blueprint:New(config.blueprint)
    end
end

--- Create profile management header
---@return nil
function IMGUILayer:CreateProfileManagementHeader()
    if Ext.Net.IsHost() then
        UIProfileManager:CreateProfileContent()
    end
    MCM_WINDOW:AddDummy(0, 10)
end

--- Create the main table and populate it with mod trees
---@return nil
function IMGUILayer:CreateMainTable()
    FrameManager:AddMenuSection(Ext.Loca.GetTranslatedString("h47d091e82e1a475b86bbe31555121a22eca7"))

    local sortedModKeys = MCMUtils.SortModsByName(self.mods)
    for _, modUUID in ipairs(sortedModKeys) do
        self.visibilityTriggers[modUUID] = {}

        local modName = self:GetModName(modUUID)
        local modDescription = MCMUtils.AddNewlinesAfterPeriods(Ext.Mod.GetMod(modUUID).Info.Description)
        FrameManager:addButtonAndGetModTabBar(modName, modDescription, modUUID)
        self.mods[modUUID].widgets = {}

        self:CreateModMenuFrame(modUUID)

        local modSettings = self.mods[modUUID].settingsValues
        for settingId, group in pairs(self.visibilityTriggers[modUUID]) do
            self:UpdateVisibility(modUUID, settingId, modSettings[settingId])
        end
    end
    FrameManager:setVisibleFrame(ModuleUUID)
end

--- Get the mod name, considering custom blueprint names
---@param modUUID string
---@return string
function IMGUILayer:GetModName(modUUID)
    local modName = Ext.Mod.GetMod(modUUID).Info.Name
    local blueprintCustomName = self.mods[modUUID].blueprint:GetModName()
    if blueprintCustomName then
        modName = blueprintCustomName
    end
    return modName
end

--- Create a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuFrame(modUUID)
    local modInfo = Ext.Mod.GetMod(modUUID).Info
    local modBlueprint = self.mods[modUUID].blueprint
    local modSettings = self.mods[modUUID].settingsValues
    local uiGroupMod = FrameManager:GetGroup(modUUID)
    local modTabBar = FrameManager:GetModTabBar(modUUID)

    -- Footer-like text with mod information
    local function createModTabFooter()
        uiGroupMod:AddSeparator()
        uiGroupMod.IDContext = modUUID .. "_FOOTER"
        local modAuthor = modInfo.Author
        local modVersion = table.concat(modInfo.ModVersion, ".")
        -- local modDescription = modInfo.Description
        -- local modName = modInfo.Name

        local infoText = "Made by " .. modAuthor .. " | Version " .. modVersion
        local modInfoText = uiGroupMod:AddText(infoText)
        modInfoText:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.5))
        modInfoText.IDContext = modUUID .. "_FOOTER"
    end

    -- Iterate over each tab in the mod blueprint to create a subtab for each
    for _, tabInfo in ipairs(modBlueprint.Tabs) do
        self:CreateModMenuSubTab(modTabBar, tabInfo, modSettings, modUUID)
    end

    createModTabFooter()
end

--- Create a new tab for a mod in the MCM
---@param modsTab any The main tab for the mod
---@param tab BlueprintTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSubTab(modTabs, tabInfo, modSettings, modUUID)
    local tabName = tabInfo:GetLocaName()

    local tab = modTabs:AddTabItem(tabName)
    tab.IDContext = modUUID .. "_" .. tabInfo:GetTabName()
    -- TODO: re-enable this after refactoring client-side code
    -- tab.OnActivate = function()
    --     MCMDebug(3, "Activating tab " .. tabInfo:GetTabName())
    --     Ext.Net.PostMessageToServer(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, Ext.Json.Stringify({
    --         modUUID = modUUID,
    --         tabName = tabInfo:GetTabName()
    --     }))
    -- end

    -- TODO: as always, this should be abstracted away somehow but ehh (this will be needed for nested tabs etc)
    local tabSections = tabInfo:GetSections()
    local tabSettings = tabInfo:GetSettings()

    self:manageVisibleIf(modUUID, tabInfo, tab)

    if #tabSections > 0 then
        for sectionIndex, section in ipairs(tabInfo:GetSections()) do
            self:CreateModMenuSection(sectionIndex, tab, section, modSettings, modUUID)
        end
    elseif #tabSettings > 0 then
        for _, setting in ipairs(tabSettings) do
            self:CreateModMenuSetting(tab, setting, modSettings, modUUID)
        end
    end
end

function IMGUILayer:manageVisibleIf(modUUID, elementInfo, uiElement)
    if elementInfo.VisibleIf and elementInfo.VisibleIf.Conditions then
        for _, condition in ipairs(elementInfo.VisibleIf.Conditions) do
            local settingIdTriggering = condition.SettingId
            local operator = condition.Operator
            local value = condition.ExpectedValue
            self.visibilityTriggers[modUUID] = self.visibilityTriggers[modUUID] or {}
            self.visibilityTriggers[modUUID][settingIdTriggering] = self.visibilityTriggers[modUUID]
                [settingIdTriggering] or {}
            self.visibilityTriggers[modUUID][settingIdTriggering][uiElement] = self.visibilityTriggers[modUUID]
                [settingIdTriggering][uiElement] or {}
            self.visibilityTriggers[modUUID][settingIdTriggering][uiElement][operator] = value
        end
    end
end

--- Create a new section for a mod in the MCM
---@param sectionIndex number The index of the section
---@param modGroup any The IMGUI group for the mod
---@param section BlueprintSection The section to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
function IMGUILayer:CreateModMenuSection(sectionIndex, modGroup, section, modSettings, modUUID)
    -- TODO: Set the style for the section header text somehow
    if sectionIndex > 1 then
        modGroup:AddDummy(0, 5)
    end

    local sectionName = section:GetLocaName()
    local sectionId = section:GetId()
    local sectionDescription = section:GetDescription()
    local sectionOptions = section:GetOptions()
    local sectionGroup = modGroup:AddGroup(sectionId)

    self:manageVisibleIf(modUUID, section, sectionGroup)

    -- Add main section separator, or collapsible header if the section is collapsible
    local sectionContentElement = sectionGroup
    if sectionOptions.IsCollapsible then
        local sectionCollapsingHeader = sectionGroup:AddCollapsingHeader(sectionName)
        sectionContentElement = sectionCollapsingHeader
    else
        local sectionHeader = sectionContentElement:AddSeparatorText(sectionName)
        sectionHeader.IDContext = modUUID .. "_" .. sectionName
        sectionHeader:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
        sectionHeader:SetColor("Separator", Color.NormalizedRGBA(255, 255, 255, 0.33))
    end

    -- Add section description
    if sectionDescription and sectionDescription ~= "" then
        -- TODO: add abstraction to get any localizable text
        local sectionDescriptionText = sectionDescription
        local translatedDescription = Ext.Loca.GetTranslatedString(section:GetHandles().DescriptionHandle)
        if translatedDescription ~= nil and translatedDescription ~= "" then
            sectionDescriptionText = MCMUtils.ReplaceBrWithNewlines(translatedDescription)
        end

        local addedDescription = sectionContentElement:AddText(sectionDescriptionText)
        addedDescription.IDContext = sectionGroup.IDContext .. "_Description_" .. sectionId
        addedDescription:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
        sectionContentElement:AddDummy(0, 2)
    end

    -- Iterate over each setting in the section to create a widget for each
    for _, setting in pairs(section:GetSettings()) do
        self:CreateModMenuSetting(sectionContentElement, setting, modSettings, modUUID)
    end
end

--- Create a new setting for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param setting BlueprintSetting The setting to create a widget for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
---@see InputWidgetFactory
function IMGUILayer:CreateModMenuSetting(modGroup, setting, modSettings, modUUID)
    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if createWidget == nil then
        MCMWarn(0, "No widget factory found for setting type '" ..
            setting:GetType() ..
            "'. Please contact " .. Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        local widgetGroup = modGroup:AddGroup(setting:GetId())
        local widget = createWidget(widgetGroup, setting, settingValue, modUUID)

        self:manageVisibleIf(modUUID, setting, widgetGroup)

        self.mods[modUUID].widgets[setting:GetId()] = widget
    end
end
