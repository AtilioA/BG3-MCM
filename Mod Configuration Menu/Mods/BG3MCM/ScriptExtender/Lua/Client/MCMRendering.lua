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
---@field private profiles table<string, table>
---@field private visibilityTriggers table<string, table>
MCMRendering = _Class:Create("MCMRendering", nil, {
    mods = {},
    visibilityTriggers = {}
})

MCMClientState = MCMRendering:New()
-- Coupled logic :gladge:
MCMClientState.UIReady = RX.ReplaySubject.Create(1)

function MCMRendering:SetClientStateValue(settingId, value, modUUID)
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

-- TODO: this should be refactored to use OOP or at least be more modular, however I've wasted too much time on this already with Lua's nonsense, so I'm stashing and leaving it as is
function MCMRendering:UpdateVisibility(modUUID, settingId, value)
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

function MCMRendering:ProcessTriggers(settingTriggers, value, modUUID)
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

function MCMRendering:ProcessOperators(group, operators, value, modUUID)
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

function MCMRendering:EvaluateCondition(operator, value, triggerValue, modUUID)
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

    return true
end

--- Toggles the visibility of the MCM window.
--- @param playSound boolean Whether to play a sound effect when toggling the window.
function MCMRendering:ToggleMCMWindow(playSound)
    if not MCM_WINDOW then
        return
    end

    if MCM_WINDOW.Open == true then
        MCM_WINDOW.Visible = false
        MCM_WINDOW.Open = false
        -- TODO: re-enable this sfx logic after refactoring client-side code
        ModEventManager:Emit(EventChannels.MCM_WINDOW_CLOSED, {
            playSound = playSound
        })
    else
        MCM_WINDOW.Visible = true
        MCM_WINDOW.Open = true
        ModEventManager:Emit(EventChannels.MCM_WINDOW_OPENED, {
            playSound = playSound
        })
    end
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

--- Check if the menu should be populated
---@return boolean
function MCMRendering:ShouldPopulateMenu()
    -- If uiGroup exist for MCM, init done, we don't want to populate the menu again
    local uiGroup = FrameManager:GetGroup(ModuleUUID)
    if uiGroup ~= nil then
        MCMWarn(0, "UI group for MCM already exists, skipping window creation.")
        return false
    end
    return true
end

--- Initialize menu settings and destroy welcome text if it exists
---@return nil
function MCMRendering:PrepareMenu()
    -- TODO: re-enable this after refactoring client-side code
    MCM_WINDOW.AlwaysAutoResize = MCMAPI:GetSettingValue("auto_resize_window", ModuleUUID)

    -- Table Layout
    FrameManager:initFrameLayout(MCM_WINDOW)
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
    FrameManager:AddMenuSection(Ext.Loca.GetTranslatedString("h47d091e82e1a475b86bbe31555121a22eca7"))

    local sortedModKeys = MCMUtils.SortModsByName(self.mods)
    for _, modUUID in ipairs(sortedModKeys) do
        self.visibilityTriggers[modUUID] = {}

        local success, err = xpcall(function()
            local modName = self.mods[modUUID].blueprint:GetModName()
            local modDescription = VCString:AddNewlinesAfterPeriods(self.mods[modUUID].blueprint:GetModDescription())
            FrameManager:addButtonAndGetModTabBar(modName, modDescription, modUUID)
            self.mods[modUUID].widgets = {}

            self:CreateModMenuFrame(modUUID)

            local modSettings = self.mods[modUUID].settingsValues
            for settingId, _group in pairs(self.visibilityTriggers[modUUID]) do
                self:UpdateVisibility(modUUID, settingId, modSettings[settingId])
            end
        end, debug.traceback)

        if not success then
            MCMWarn(0, "Error processing mod " .. modUUID .. ": " .. err)
        end
    end
    FrameManager:setVisibleFrame(ModuleUUID)
end

--- Create a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@return nil
function MCMRendering:CreateModMenuFrame(modUUID)
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

        local infoText = VCString:InterpolateLocalizedMessage("h4c3c735aad0f47c8b13ffee7cc7fcc660338", modAuthor,
            modVersion)
        local modInfoText = uiGroupMod:AddText(infoText)
        modInfoText.TextWrapPos = 0
        modInfoText:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.5))
        modInfoText.IDContext = modUUID .. "_FOOTER"
    end

    -- Iterate over each tab in the mod blueprint to create a subtab for each
    for _, tabInfo in ipairs(modBlueprint:GetTabs()) do
        self:CreateModMenuSubTab(modTabBar, tabInfo, modSettings, modUUID)
    end

    createModTabFooter()
end

--- Create a new tab for a mod in the MCM
---@param modTabs ExtuiTabBar The main tab for the mod
---@param blueprintTab BlueprintTab The tab to create a tab for
---@param modSettings table<string, table> The settings for the mod
---@param modUUID string The UUID of the mod
---@return nil
function MCMRendering:CreateModMenuSubTab(modTabs, blueprintTab, modSettings, modUUID)
    local tabName = blueprintTab:GetLocaName()

    local imguiTab = modTabs:AddTabItem(tabName)
    imguiTab.IDContext = modUUID .. "_" .. blueprintTab:GetTabName()
    -- TODO: re-enable this after refactoring client-side code
    -- imguiTab.OnActivate = function()
    --     MCMDebug(3, "Activating imguiTab " .. blueprintTab:GetTabName())
    --     Ext.Net.PostMessageToServer(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, Ext.Json.Stringify({
    --         modUUID = modUUID,
    --         tabName = blueprintTab:GetTabName()
    --     }))
    -- end

    -- TODO: as always, this should be abstracted away somehow but ehh (this will be needed for nested tabs etc)
    local tabSections = blueprintTab:GetSections()
    local tabSettings = blueprintTab:GetSettings()

    self:manageVisibleIf(modUUID, blueprintTab, imguiTab)

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

---@param modUUID string
---@param elementInfo table
---@param uiElement ImguiHandle
function MCMRendering:manageVisibleIf(modUUID, elementInfo, uiElement)
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
function MCMRendering:CreateModMenuSection(sectionIndex, modGroup, section, modSettings, modUUID)
    -- TODO: Set the style for the section header text somehow
    if sectionIndex > 1 then
        modGroup:AddDummy(0, 5)
    end

    local sectionName = section:GetLocaName()
    local sectionId = section:GetId()
    local sectionDescription = section:GetDescription()
    local sectionOptions = section:GetOptions()
    local sectionGroup = modGroup:AddGroup(sectionId)
    sectionGroup.IDContext = modUUID .. "_" .. sectionId .. "_Group"

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
            sectionDescriptionText = VCString:ReplaceBrWithNewlines(translatedDescription)
        end

        local addedDescription = sectionContentElement:AddText(sectionDescriptionText)
        addedDescription.TextWrapPos = 0
        addedDescription.IDContext = sectionGroup.IDContext .. "_Description_"
        addedDescription:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
        sectionContentElement:AddDummy(0, 2)
    end
    -- Iterate over each setting in the section to create a widget for each
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
    if setting:GetType() == "keybinding_v2" then
        return
    end

    local settingValue = modSettings[setting:GetId()]
    local createWidget = InputWidgetFactory[setting:GetType()]
    if createWidget == nil then
        MCMWarn(0, "No widget factory found for setting type '" ..
            setting:GetType() ..
            "'. Please contact " .. Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    else
        local widgetGroup = modGroup:AddGroup(setting:GetId())
        widgetGroup.IDContext = modUUID .. "_" .. setting:GetId() .. "_Group"
        local widget = createWidget(widgetGroup, setting, settingValue, modUUID)

        self:manageVisibleIf(modUUID, setting, widgetGroup)

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
                    table.insert(modKeybindings.Actions, {
                        ActionId = setting.Id,
                        ActionName = setting:GetLocaName(),
                        KeyboardMouseBinding = keyboardBinding,
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

-- TODO: extract this to FrameManager
function MCMRendering:CreateKeybindingsPage()
    local hotkeysUUID = "MCM_HOTKEYS"
    -- MCMDebug(0, "Creating keybindings page...")

    -- Create a dedicated "Hotkeys" menu section via FrameManager.
    FrameManager:AddMenuSection(Ext.Loca.GetTranslatedString("hb20ef6573e4b42329222dcae8e6809c9ab0c"))
    FrameManager:CreateMenuButton(FrameManager.menuCell,
        Ext.Loca.GetTranslatedString("h1574a7787caa4e5f933e2f03125a539c1139"), hotkeysUUID)

    local hotkeysGroup = FrameManager.contentCell:AddGroup(hotkeysUUID)
    FrameManager.contentGroups[hotkeysUUID] = hotkeysGroup

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
    imguiObjectTooltip:AddText(tooltipText)
    imguiObjectTooltip:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
    imguiObjectTooltip:SetStyle("WindowPadding", 15, 15)
    imguiObjectTooltip:SetStyle("PopupBorderSize", 2)
    imguiObjectTooltip:SetColor("BorderShadow", { 0, 0, 0, 0.4 })

    return imguiObjectTooltip
end
