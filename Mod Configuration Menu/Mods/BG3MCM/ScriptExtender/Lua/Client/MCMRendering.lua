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
    UIReady = RX.ReplaySubject.Create(1)
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

    local blueprint = MCMAPI:GetModBlueprint(modUUID)
    if not blueprint then return end

    -- Update the displayed value
    IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)
end

function MCMRendering:GetMCMFontSize()
    if not MCM_WINDOW then return end
    return MCMClientState:GetClientStateValue("font_size", ModuleUUID)
end

function MCMRendering:GetMCMTypeface()
    local family = MCMClientState:GetClientStateValue("typeface", ModuleUUID)
    if family == nil then return "" end
    return family
end

function MCMRendering:SetFont(family, size)
    IMGUIHelpers.SetFont(MCM_WINDOW, family, size)
end

--- Returns the current font family and size
--- @return string|nil - The font family
--- @return string|nil - The font size
function MCMRendering:GetMCMFont()
    return self:GetMCMTypeface(), self:GetMCMFontSize()
end

--- Sets the font size for the MCM window
--- @param size string|nil The font size
function MCMRendering:SetMCMFontSize(size)
    if not MCM_WINDOW then return end
    if not size then return end

    local family = self:GetMCMTypeface()

    self:SetFont(family, size)
end

--- Sets the font family for the MCM window
--- @param family string|nil The font family
function MCMRendering:SetMCMTypeface(family)
    if not MCM_WINDOW then return end
    if not family then return end

    local sizeSetting = MCMClientState:GetClientStateValue("font_size", ModuleUUID) or "Default"

    self:SetFont(family, sizeSetting)
end

--- Returns the name of the mod with the given UUID
--- @param modUUID string The UUID of the mod
--- @return string|nil The name of the mod, or nil if the mod is not found
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

--- Ensures the MCM window is within the viewport bounds
--- @return boolean True if window was repositioned, false otherwise
function MCMRendering:EnsureWindowVisible()
    if not MCM_WINDOW then
        return false
    end

    -- Define margin from screen edges
    local SCREEN_MARGIN = 30
    local DEFAULT_WINDOW_POSITION = { 10, 10 }

    local function checkVec2IsZero(vec2)
        return vec2[1] == 0 and vec2[2] == 0
    end

    local shouldRepositionWindow = MCMClientState:GetClientStateValue("reposition_window_if_out_of_bounds", ModuleUUID)
    if shouldRepositionWindow == nil then
        shouldRepositionWindow = true
    end

    if not shouldRepositionWindow then
        return false
    end

    -- Get viewport dimensions
    local viewportSize = Ext.IMGUI.GetViewportSize()

    local shouldReset = false

    -- Check if LastPosition exists and is outside the screen boundaries
    -- REVIEW: "note that window size is only calculated on draw, so you have to wait for 1 frame to get size after creating it"
    local pos = MCM_WINDOW.LastPosition
    local size = MCM_WINDOW.LastSize
    if pos and size and not checkVec2IsZero(pos) and not checkVec2IsZero(size) then
        if pos[1] + size[1] <= 0 + SCREEN_MARGIN or        -- Left edge
            pos[1] >= viewportSize[1] - SCREEN_MARGIN or   -- Right edge
            pos[2] + size[2] <= 0 + SCREEN_MARGIN or       -- Top edge
            pos[2] >= viewportSize[2] - SCREEN_MARGIN then -- Bottom edge
            shouldReset = true
        end
    end

    -- Reset position if needed
    if shouldReset then
        MCM_WINDOW:SetPos(DEFAULT_WINDOW_POSITION)
        return true
    end

    return false
end

--- Ensure the MCM window is focused under the right conditions
function MCMRendering:EnsureWindowFocused()
    if not MCM_WINDOW then
        return
    end

    -- If not in controller mode, don't focus the window
    if Ext.Utils.GetGlobalSwitches().ControllerMode == 0 then
        return
    end

    MCM_WINDOW:SetFocus()
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

    local modVersion = MCMUtils.FormatModVersion(ModuleUUID)
    ---@class ExtuiWindow
    MCM_WINDOW = Ext.IMGUI.NewWindow(modMenuTitle .. " " .. modVersion)
    MCM_WINDOW.Scaling = "Scaled"
    local sizeSetting = MCMClientState:GetClientStateValue("font_size", ModuleUUID) or "Default"
    local family = MCMClientState:GetClientStateValue("typeface", ModuleUUID) or ""

    self:SetFont(family, sizeSetting)

    MCM_WINDOW.AlwaysAutoResize = false

    UIStyle:ApplyDefaultStylesToIMGUIElement(MCM_WINDOW)

    local minWidth, minHeight = table.unpack(self:GetMCMWindowSizeConstraints())
    MCM_WINDOW:SetStyle("WindowMinSize", minWidth, minHeight)
    MCM_WINDOW.IDContext = "MCM_WINDOW"

    local shouldOpenOnStart = MCMClientState:GetClientStateValue("open_on_start", ModuleUUID)
    if shouldOpenOnStart == nil then
        shouldOpenOnStart = true
    end

    MCM_WINDOW.NoFocusOnAppearing = true

    self:EnsureWindowVisible()

    MCM_WINDOW.Visible = shouldOpenOnStart
    MCM_WINDOW.Open = shouldOpenOnStart
    MCM_WINDOW.OnClose = function()
        ModEventManager:Emit(EventChannels.MCM_WINDOW_CLOSED, {}, true)
    end

    MCM_WINDOW.AlwaysAutoResize = false
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

    self:ConvertModTablesToBlueprints()
    self:CreateProfileManagementHeader()
    self:CreateKeybindingsPage()
    self:CreateMainTable()

    MCMClientState.UIReady:OnNext(true)
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
    if MCMProxy:IsMainMenu() or Ext.Net.IsHost() then
        UIProfileManager:CreateProfileContent()
        MCM_WINDOW:AddDummy(0, 10)
    end
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
    local tabDescription = blueprintTab:GetTabDescription()
    local imguiTab = modTabs:AddTabItem(tabName)
    imguiTab.IDContext = DualPaneController:GenerateTabId(modUUID, blueprintTab:GetTabName())
    imguiTab.UserData = {
        tabId = blueprintTab:GetId(),
        tabName = blueprintTab:GetTabName()
    }

    if tabDescription and tabDescription ~= "" then
        imguiTab:AddText(VCString:ReplaceBrWithNewlines(tabDescription))
        imguiTab.TextWrapPos = 0
    end

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
        -- Gather setting groups to add dummy separators (which makes them go away if visibility conditions are not met)
        local settingGroups = {}
        for _, setting in ipairs(tabSettings) do
            local group = self:CreateModMenuSetting(imguiTab, setting, modSettings, modUUID)
            if group then table.insert(settingGroups, group) end
        end
        for i, group in ipairs(settingGroups) do
            if i < #settingGroups then group:AddDummy(0, 10) end
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

    -- FIXME: handles are being misobtained somehow
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

    -- Gather setting groups to add dummy separators (which makes them go away if visibility conditions are not met)
    local settingGroups = {}
    for _, setting in ipairs(section:GetSettings()) do
        local group = self:CreateModMenuSetting(sectionContentElement, setting, modSettings, modUUID)
        if group then table.insert(settingGroups, group) end
    end
    for i, group in ipairs(settingGroups) do
        if i < #settingGroups then group:AddDummy(0, 10) end
    end
end

--- Create a new setting for a mod in the MCM
---@param modGroup any The IMGUI group for the mod
---@param setting BlueprintSetting The setting to create a widget for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return ExtuiStyledRenderable|nil
function MCMRendering:CreateModMenuSetting(modGroup, setting, modSettings, modUUID)
    if setting:GetType() == "keybinding_v2" then return nil end

    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if not createWidget then
        MCMWarn(0, "No compatible widget found for setting type '" .. setting:GetType() .. "'. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue (mod " .. Ext.Mod.GetMod(modUUID).Info.Name .. ").")
        return nil
    else
        local widgetGroup = modGroup:AddGroup(setting:GetId())
        widgetGroup.IDContext = modUUID .. "_" .. setting:GetId() .. "_Group"

        local widget = createWidget(widgetGroup, setting, settingValue, modUUID)
        VisibilityManager.registerCondition(modUUID, widgetGroup, setting:GetVisibleIf())
        self.mods[modUUID].widgets[setting:GetId()] = widget
        return widgetGroup
    end
end

--- Gets all keybinding settings from loaded mods
---@return table<string, table> A table of keybinding settings organized by mod UUID
function MCMRendering:GetAllKeybindings()
    return KeybindingsUI.GetAllKeybindings()
end

--- Creates the keybindings page in the MCM UI
---@return ExtuiGroup|nil The created hotkeys group
function MCMRendering:CreateKeybindingsPage()
    if not DualPane then
        MCMWarn(1, "DualPane is not available, skipping keybindings page creation.")
        return nil
    end

    -- Delegate keybindings page creation to KeybindingsUI
    local hotkeysGroup = KeybindingsUI.CreateKeybindingsPage(DualPane)

    -- Load and register keybindings
    local allModKeybindings = self:GetAllKeybindings()
    if #allModKeybindings == 0 then
        MCMDebug(1, "No keybinding settings found for any mod.")
    end

    -- Register the keybindings in the centralized registry
    KeybindingsRegistry.RegisterModKeybindings(allModKeybindings)

    -- Initialize our reactive input dispatcher.
    if not InputCallbackManager._initialized then
        InputCallbackManager.Initialize()

        -- Notify that keybindings have been loaded
        if ModEventManager then
            -- Technically, mods should not worry about this, but we'll emit an event here for them.
            ModEventManager:Emit(EventChannels.MCM_KEYBINDINGS_LOADED, {})
        end

        -- Tell the dispatcher that keybindings have been loaded so it may process any pending callbacks.
        if InputCallbackManager.KeybindingsLoadedSubject then
            InputCallbackManager.KeybindingsLoadedSubject:OnNext(true)
        end

        -- Register MCM keybindings if MCMProxy is available
        if MCMProxy and MCMProxy.RegisterMCMKeybindings then
            MCMProxy:RegisterMCMKeybindings()
        end
    end

    return hotkeysGroup
end
