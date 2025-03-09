-- TODO: decouple UI presentation from data handling (e.g. mod blueprint, settings values, keybinding gathering, etc)

local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua"),
    ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
}

---@class ModSettings
---@field blueprint Blueprint The blueprint for the mod
---@field settingsValues table<string, any> A table of settings for the mod
---@field widgets table<string, any> A table of widgets for the mod

--- Class responsible for rendering the MCM UI to manage mods and profiles.
--- A table of mod UUIDs, each associated with a table containing widgets and potentially other blueprints and settings.
-- The MCMRendering class is responsible for creating and managing the IMGUI user interface for MCM.
-- It acts as the bridge between MCM's core business logic and MCM's IMGUI window, handling the rendering and interaction of the mod configuration UI.
-- It relies on settings and profiles managed by the MCM (API) class, and then translates this data into a user-friendly IMGUI interface.
-- MCMRendering provides methods for:
-- - Creating the main MCM menu, which contains a tab for each mod that has MCM settings
-- - Creating new tabs and sections for each mod, based on the mod's blueprint
-- - Creating IMGUI widgets for each setting in the mod's blueprint
-- - Sending messages to the server to update setting values
---@class MCMRendering: MetaClass
---@field mods table<string, ModSettings>
---@field UIReady ReplaySubject
---@field private profiles table<string, table>
MCMRendering = _Class:Create("MCMRendering", nil, {
    mods = {},
    UIReady = RX.Subject.Create(1)
})

-- Coupled logic :gladge:
MCMClientState = MCMRendering:New()

---@type DualPaneController|nil
DualPane = nil -- will be assigned in CreateMainIMGUIWindow

function MCMRendering:SetClientStateValue(settingId, value, modUUID)
    modUUID = modUUID or ModuleUUID
    if not modUUID or not settingId then return end
    local mod = MCMClientState.mods[modUUID]
    if not mod or not mod.settingsValues then return end

    self:UpdateSettingValue(mod, settingId, value, modUUID)
end

function MCMRendering:UpdateSettingValue(mod, settingId, value, modUUID)
    -- Update client values for the setting
    mod.settingsValues[settingId] = value
    MCMAPI.mods[modUUID].settingsValues[settingId] = value

    -- Check if the setting is of type 'text'; no need to update the UI value for text settings
    -- Also, doing so creates issues with the text input field
    -- local blueprint = MCMAPI:GetModBlueprint(modUUID)
    if not blueprint then return end

    local setting = blueprint:GetAllSettings()[settingId]
    if not setting or setting:GetType() == "text" then return end

    -- Update the displayed value for non-text settings
    IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)
end

function MCMRendering:GetModName(modUUID)
    if not modUUID then
        return nil
    end

    if self.mods[modUUID] and self.mods[modUUID].blueprint then
        return self.mods[modUUID].blueprint:GetModName()
    end

    return nil
end

function MCMRendering:GetClientStateValue(settingId, modUUID)
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

--- Get the initial size for the MCM window based on the current viewport resolution.
function GetInitialMCMWindowSize()
    -- Base dimensions for a 1440p viewport (manually tested)
    local BASE_WIDTH = 650
    local BASE_HEIGHT = 700
    local BASE_RESOLUTION_HEIGHT = 1440

    local viewportSize = Ext.IMGUI.GetViewportSize()
    local currentHeight = viewportSize[2]

    -- Compute scaled width and height, round to nearest integer
    local scaleFactor = currentHeight / BASE_RESOLUTION_HEIGHT
    local width = math.floor(BASE_WIDTH * scaleFactor + 0.5)
    local height = math.floor(BASE_HEIGHT * scaleFactor + 0.5)

    return { width, height }
end

function MCMRendering:GetMCMWindowSizeConstraints()
    local viewportSize = Ext.IMGUI.GetViewportSize()
    return { viewportSize[1] / 3, viewportSize[2] / 3 }
end

--- Create the main IMGUI window for MCM
function MCMRendering:CreateMainIMGUIWindow()
    if not Ext.IMGUI then
        MCMWarn(0, "IMGUI is not available, skipping MCM window creation.")
        return false
    end

    if self.welcomeText then
        MCMDebug(2, "Welcome text already exists, skipping...")
        return true
    end

    local modMenuTitle = Ext.Loca.GetTranslatedString("hae2bbc06g288dg43dagb3a5g967fa625c769")
    if modMenuTitle == nil or modMenuTitle == "" then
        modMenuTitle = "Mod Configuration Menu"
    end

    ---@class ExtuiWindow
    MCM_WINDOW = Ext.IMGUI.NewWindow(modMenuTitle)
    UIStyle:ApplyDefaultStylesToIMGUIElement(MCM_WINDOW)
    local minWidth, minHeight = table.unpack(self:GetMCMWindowSizeConstraints())
    MCM_WINDOW:SetStyle("WindowMinSize", minWidth, minHeight)
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
    MCM_WINDOW.NoScrollbar = true
    MCM_WINDOW.NoScrollWithMouse = true
    MCM_WINDOW:SetScroll({ 0, 0 })

    if table.isEmpty(self.mods) then
        self.welcomeText = MCM_WINDOW:AddText(
            VCString:ReplaceBrWithNewlines(
                Ext.Loca.GetTranslatedString(
                    "h81a4a9991875424984b876d017675879c959")
            )
        )
        self.welcomeText.TextWrapPos = 0
    end

    MainMenu.CreateMainMenu()

    DualPane = DualPaneController:InitWithWindow(MCM_WINDOW)

    return true
end

function MCMRendering:SetActiveWindowAlpha(bool)
    VCTimer:OnTime(100, function()
        if bool then
            MCM_WINDOW:SetStyle("Alpha", 1)
            MCM_WINDOW.Visible = bool
        else
            MCM_WINDOW:SetStyle("Alpha", 0.67)
        end
    end)
end

function MCMRendering:NotifyMCMWindowReady()
    ModEventManager:Emit(EventChannels.MCM_WINDOW_READY, {})
end

function MCMRendering:LoadMods(mods)
    self.mods = mods

    -- if MCM_WINDOW then MCM_WINDOW:Destroy() end
    local createdWindow = self:CreateMainIMGUIWindow()
    if not createdWindow then
        return
    end
    self:CreateModMenu()
    self:NotifyMCMWindowReady()
end

--- Create the main MCM menu, which contains a tree view for each mod that has MCM settings
---@return nil
function MCMRendering:CreateModMenu()
    -- if not self:ShouldPopulateMenu() then
    --     return
    -- end

    self:PrepareMenu()
    self:ConvertModTablesToBlueprints()
    self:CreateProfileManagementHeader()
    self:CreateKeybindingsPage()
    self:CreateMainTable()

    MCMClientState.UIReady:OnNext(true)
end

--- Initialize menu settings and destroy welcome text if it exists
---@return nil
function MCMRendering:PrepareMenu()
    -- TODO: re-enable this after refactoring client-side code
    MCM_WINDOW.AlwaysAutoResize = MCMAPI:GetSettingValue("auto_resize_window", ModuleUUID)
end

--- Convert the mod configs to use the Blueprint class
---@return nil
function MCMRendering:ConvertModTablesToBlueprints()
    for _modUUID, config in pairs(self.mods) do
        config.blueprint = Blueprint:New(config.blueprint)
    end
end

--- Create profile management header
---@return nil
function MCMRendering:CreateProfileManagementHeader()
    if Ext.Net.IsHost() then
        UIProfileManager:CreateProfileContent()
    end
    MCM_WINDOW:AddDummy(0, 10)
end

--- Create the main table and populate it with mod trees
---@return nil
function MCMRendering:CreateMainTable()
    DualPane.leftPane:AddMenuSeparator(Ext.Loca.GetTranslatedString("h47d091e82e1a475b86bbe31555121a22eca7"))
    local sortedModKeys = MCMUtils.SortModsByName(self.mods)
    for _, modUUID in ipairs(sortedModKeys) do
        local success, err = xpcall(function()
            local modName = self.mods[modUUID].blueprint:GetModName()
            local modDescription = VCString:AddNewlinesAfterPeriods(self.mods[modUUID].blueprint:GetModDescription())
            DualPane.leftPane:CreateMenuButton(modName, modDescription, modUUID)
            self.mods[modUUID].widgets = {}
            self:RenderMenuPageContent(modUUID)
        end, debug.traceback)
        if not success then
            MCMWarn(0, "Error processing mod " .. modUUID .. ": " .. err)
        end
    end
    DualPane:SetVisibleFrame(ModuleUUID)
end

--- Create a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@return nil
function MCMRendering:RenderMenuPageContent(modUUID)
    local modInfo = Ext.Mod.GetMod(modUUID).Info
    local modBlueprint = self.mods[modUUID].blueprint
    local modSettings = self.mods[modUUID].settingsValues
    local uiGroupMod = DualPane.rightPane:GetModGroup(modUUID)
    if not uiGroupMod then
        uiGroupMod = DualPane.rightPane:CreateModGroup(modUUID, modBlueprint:GetModName(),
            modBlueprint:GetModDescription())
    end

    -- Footer-like text with mod information
    local function createModTabFooter()
        uiGroupMod:AddSeparator()
        uiGroupMod.IDContext = modUUID .. "_FOOTER"
        local modAuthor = modInfo.Author
        local modVersion = table.concat(modInfo.ModVersion, ".")
        -- local modDescription = modInfo.Description
        -- local modName = modInfo.Name

        local infoText = VCString:InterpolateLocalizedMessage("h4c3c735aad0f47c8b13ffee7cc7fcc660338", modAuthor,
            modVersion)
        local modInfoText = uiGroupMod:AddText(infoText)
        modInfoText.TextWrapPos = 0
        modInfoText:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.5))
        modInfoText.IDContext = modUUID .. "_FOOTER"
    end

    -- Iterate over each tab in the mod blueprint to create a subtab for each
    for _, tabInfo in ipairs(modBlueprint:GetTabs()) do
        self:CreateModMenuSubTab(DualPane.rightPane:GetModTabBar(modUUID), tabInfo, modSettings, modUUID)
    end

    createModTabFooter()
end

--- Create a new tab for a mod in the MCM
---@param modTabs ExtuiTabBar|nil The main tab for the mod
---@param blueprintTab BlueprintTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
function MCMRendering:CreateModMenuSubTab(modTabs, blueprintTab, modSettings, modUUID)
    if not modTabs then
        MCMError(0, "No tab bar found for mod " .. modUUID)
        return
    end
    local tabName = blueprintTab:GetLocaName()
    local imguiTab = modTabs:AddTabItem(tabName)
    imguiTab.IDContext = DualPaneController:GenerateTabId(modUUID, blueprintTab:GetTabName())
    imguiTab.UserData = {
        tabId = blueprintTab:GetId(),
        tabName = blueprintTab:GetTabName()
    }

    imguiTab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
            modUUID = modUUID,
            tabName = tabName
        }, true)
    end

    local blueprintVisibleIf = blueprintTab:GetVisibleIf()
    if blueprintVisibleIf then
        VisibilityManager.registerCondition(modUUID, imguiTab, blueprintVisibleIf)
    end

    local tabSections = blueprintTab:GetSections()
    local tabSettings = blueprintTab:GetSettings()
    if #tabSections > 0 then
        for sectionIndex, section in ipairs(blueprintTab:GetSections()) do
            self:CreateModMenuSection(sectionIndex, imguiTab, section, modSettings, modUUID)
        end
    elseif #tabSettings > 0 then
        for _, setting in ipairs(tabSettings) do
            self:CreateModMenuSetting(imguiTab, setting, modSettings, modUUID)
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
function MCMRendering:CreateModMenuSection(sectionIndex, modGroup, section, modSettings, modUUID)
    if sectionIndex > 1 then
        modGroup:AddDummy(0, 5)
    end

    local sectionName = section:GetLocaName()
    local sectionId = section:GetId()
    local sectionDescription = section:GetDescription()
    local sectionOptions = section:GetOptions()
    local sectionGroup = modGroup:AddGroup(sectionId)
    sectionGroup.IDContext = modUUID .. "_" .. sectionId .. "_Group"

    if section:GetVisibleIf() and section:GetVisibleIf().Conditions then
        VisibilityManager.registerCondition(modUUID, sectionGroup, section:GetVisibleIf())
    end

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

    if sectionDescription and sectionDescription ~= "" then
        local sectionDescriptionText = sectionDescription
        local translatedDescription = Ext.Loca.GetTranslatedString(section:GetHandles().DescriptionHandle)
        if translatedDescription and translatedDescription ~= "" then
            sectionDescriptionText = VCString:ReplaceBrWithNewlines(translatedDescription)
        end

        local addedDescription = sectionContentElement:AddText(sectionDescriptionText)
        addedDescription.TextWrapPos = 0
        addedDescription.IDContext = sectionGroup.IDContext .. "_Description_"
        addedDescription:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
        sectionContentElement:AddDummy(0, 2)
    end

    for i, setting in pairs(section:GetSettings()) do
        self:CreateModMenuSetting(sectionContentElement, setting, modSettings, modUUID)
        if i ~= #section:GetSettings() then
            sectionContentElement:AddDummy(0, 10)
        end
    end
end

--- Create a new setting for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param setting BlueprintSetting The setting to create a widget for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
---@see InputWidgetFactory
function MCMRendering:CreateModMenuSetting(modGroup, setting, modSettings, modUUID)
    if setting:GetType() == "keybinding_v2" then return end

    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if not createWidget then
        MCMWarn(0, "No widget factory found for setting type '" .. setting:GetType() .. "'. Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        local widgetGroup = modGroup:AddGroup(setting:GetId())
        widgetGroup.IDContext = modUUID .. "_" .. setting:GetId() .. "_Group"
        local widget = createWidget(widgetGroup, setting, settingValue, modUUID)
        VisibilityManager.registerCondition(modUUID, widgetGroup,
            setting:GetVisibleIf())
        self.mods[modUUID].widgets[setting:GetId()] = widget
    end
end

------------------------------------------------------------
-- Helper: Extract all keybinding settings from loaded mods.
------------------------------------------------------------
function MCMRendering:GetAllKeybindings()
    local keybindings = {}
    for modUUID, modData in pairs(self.mods) do
        local blueprint = modData.blueprint
        if blueprint then
            local modKeybindings = { ModUUID = modUUID, Actions = {} }
            local allSettings = blueprint:GetAllSettings()
            for settingId, setting in pairs(allSettings) do
                if setting:GetType() == "keybinding_v2" then
                    local currentBinding = modData.settingsValues[settingId]
                    local keyboardBinding = nil
                    if currentBinding and currentBinding.Keyboard then
                        keyboardBinding = currentBinding.Keyboard
                        MCMDebug(1, "Using saved keyboard binding for setting: " .. settingId)
                    else
                        keyboardBinding = setting.Default and setting.Default.Keyboard or
                            { Key = "", ModifierKeys = { "NONE" } }
                        MCMDebug(1, "Falling back to default keyboard binding for setting: " .. settingId)
                    end

                    local description = setting:GetDescription()
                    local tooltip = setting:GetTooltip()
                    local enabled = modData.settingsValues[settingId] and
                        modData.settingsValues[settingId].Enabled ~= false
                    local defaultEnabled = true
                    if setting.Default and setting.Default.Enabled ~= nil then
                        defaultEnabled = setting.Default.Enabled
                    end
                    table.insert(modKeybindings.Actions, {
                        ActionId = setting.Id,
                        ActionName = setting:GetLocaName(),
                        KeyboardMouseBinding = keyboardBinding,
                        DefaultEnabled = defaultEnabled,
                        Enabled = enabled,
                        DefaultKeyboardMouseBinding = setting.Default and setting.Default.Keyboard or
                            { Key = "", ModifierKeys = { "NONE" } },
                        Description = description,
                        Tooltip = tooltip,
                        ShouldTriggerOnRepeat = (setting.Options and setting.Options.ShouldTriggerOnRepeat) or false,
                        ShouldTriggerOnKeyUp = (setting.Options and setting.Options.ShouldTriggerOnKeyUp) or false,
                        ShouldTriggerOnKeyDown = (setting.Options and setting.Options.ShouldTriggerOnKeyDown) or true,
                        IsDeveloperOnly = (setting.Options and setting.Options.IsDeveloperOnly) or false

                    })
                end
            end
            if #modKeybindings.Actions > 0 then
                table.insert(keybindings, modKeybindings)
            end
        end
    end
    return keybindings
end

-- TODO: extract this to DualPane
function MCMRendering:CreateKeybindingsPage()
    local hotkeysUUID = "MCM_HOTKEYS"
    -- MCMDebug(0, "Creating keybindings page...")

    -- Create a dedicated "Hotkeys" menu section via DualPane.
    DualPane.leftPane:AddMenuSeparator(Ext.Loca.GetTranslatedString("hb20ef6573e4b42329222dcae8e6809c9ab0c"))
    DualPane.leftPane:CreateMenuButton(Ext.Loca.GetTranslatedString("h1574a7787caa4e5f933e2f03125a539c1139"), nil,
        hotkeysUUID)

    local hotkeysGroup = DualPane.contentScrollWindow:AddGroup(hotkeysUUID)
    DualPane.rightPane.contentGroups[hotkeysUUID] = hotkeysGroup

    -- Create the keybinding widget (which will subscribe to registry changes via ReactiveX)
    local _keybindingWidget = KeybindingV2IMGUIWidget:new(hotkeysGroup)
    -- MCMDebug(0, "Keybinding widget created.")

    -- Load keybindings from the mod settings
    local allModKeybindings = self:GetAllKeybindings()
    if #allModKeybindings == 0 then
        -- MCMDebug(0, "No keybinding settings found for any mod.")
    else
        -- MCMDebug(0, "Registering keybindings...")
        -- Register the keybindings in the centralized registry.
        KeybindingsRegistry.RegisterModKeybindings(allModKeybindings)

        -- Initialize our reactive input dispatcher.
        InputCallbackManager.Initialize()

        -- Technically, mods should not worry about this, but we'll emit an event here for them.
        ModEventManager:Emit(EventChannels.MCM_KEYBINDINGS_LOADED, {})
        -- Tell the dispatcher that keybindings have been loaded so it may process any pending callbacks.
        InputCallbackManager.KeybindingsLoadedSubject:OnNext(true)

        MCMProxy:RegisterMCMKeybindings()
    end
end

--- Add a tooltip to a button
---@param imguiObject ExtuiStyledRenderable
---@param tooltipText string
---@param uuid string
---@return ExtuiStyledRenderable | nil
function MCMRendering:AddTooltip(imguiObject, tooltipText, uuid)
    if not imguiObject then
        MCMWarn(1, "Tried to add a tooltip to a nil object")
        return nil
    end
    if not tooltipText then
        tooltipText = ""
        return nil
    end
    if not uuid then
        MCMWarn(1, "Mod UUID not provided for tooltip")
        return nil
    end
    if not imguiObject.Tooltip then
        MCMWarn(1, "Tried to add a tooltip to an object with no tooltip support")
        return nil
    end

    local imguiObjectTooltip = imguiObject:Tooltip()
    imguiObjectTooltip.IDContext = uuid .. "_TOOLTIP"
    local preprocessedTooltip = VCString:ReplaceBrWithNewlines(VCString:AddNewlinesAfterPeriods(tooltipText))
    imguiObjectTooltip:AddText(preprocessedTooltip)
    imguiObjectTooltip:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
    imguiObjectTooltip:SetStyle("WindowPadding", 15, 15)
    imguiObjectTooltip:SetStyle("PopupBorderSize", 2)
    imguiObjectTooltip:SetColor("BorderShadow", { 0, 0, 0, 0.4 })

    return imguiObjectTooltip
end
