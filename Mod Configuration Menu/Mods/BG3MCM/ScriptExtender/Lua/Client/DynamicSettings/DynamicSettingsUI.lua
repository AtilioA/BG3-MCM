-- UI component for dynamic settings

---@class DynamicSettingsUI
local DynamicSettingsUI = {}

-- Dependencies
local DynamicSettingsManager = Ext.Require("Client/DynamicSettings/DynamicSettingsManager.lua")
-- local WidgetFactory = Ext.Require("Client/Components/IMGUIWidgets/WidgetFactory.lua")

-- Create the global controls (checkboxes and refresh button)
function DynamicSettingsUI.CreateGlobalControls(parent)
    local group = parent:AddGroup("DynamicSettingsGlobalControls")

    -- Client write checkbox
    local clientWriteCheckbox = group:AddCheckbox("Try write on client", DynamicSettingsManager.tryWriteToClient)
    clientWriteCheckbox.OnChange = function(widget, newValue)
        DynamicSettingsManager.tryWriteToClient = newValue
    end

    -- Server write checkbox
    local serverWriteCheckbox = group:AddCheckbox("Try write on server", DynamicSettingsManager.tryWriteToServer)
    serverWriteCheckbox.SameLine = true
    serverWriteCheckbox.OnChange = function(widget, newValue)
        DynamicSettingsManager.tryWriteToServer = newValue
    end

    -- Disable server write checkbox in main menu
    if MCMProxy.IsMainMenu() then
        serverWriteCheckbox.Disabled = true
    end

    -- Refresh button (only visible in-game)
    local refreshButton = group:AddButton("Refresh")
    refreshButton.SameLine = true
    refreshButton.OnClick = function()
        DynamicSettingsManager.RefreshAll()
    end
    refreshButton.Visible = not MCMProxy.IsMainMenu()

    -- Add a separator
    group:AddSeparator()

    return group
end

-- Create a tab for client or server variables
function DynamicSettingsUI.CreateVariablesTab(parent, isServerTab)
    local tabName = isServerTab and "Server Variables" or "Client Variables"
    local tab = parent:AddTabItem(tabName)

    -- Hide server tab in main menu
    if isServerTab and MCMProxy.IsMainMenu() then
        tab.Visible = false
    end

    return tab
end

-- Create a collapsing header for a mod
function DynamicSettingsUI.CreateModHeader(parent, modUUID, modName)
    local header = parent:AddCollapsingHeader(modName or modUUID)
    header.UserData = { modUUID = modUUID }
    return header
end

-- Create a widget for a variable based on its type
function DynamicSettingsUI.CreateVariableWidget(parent, moduleUUID, varName, varValue, storageType, isServerVar)
    local varType = type(varValue)
    local entry = { type = varType }
    local widget = nil

    -- Create widget based on type
    if varType == "boolean" then
        widget = parent:AddCheckbox(varName, varValue)
    elseif varType == "number" then
        widget = parent:AddDragFloat(varName, varValue)
    elseif varType == "string" then
        widget = parent:AddInputText(varName, varValue)
    elseif varType == "table" then
        -- For tables, just show a placeholder
        widget = parent:AddText(varName .. ": " .. Ext.Json.Stringify(varValue))
        return widget
    else
        widget = parent:AddText(varName .. ": " .. tostring(varValue))
        return widget
    end

    -- Set up value change handler
    if widget.OnChange then
        widget.OnChange = function(_, newValue)
            local success, error = DynamicSettingsManager.SetVariable(moduleUUID, varName, storageType, newValue)

            -- Show error if failed
            if not success and error then
                local errorWidget = parent:AddText("Error: " .. tostring(error))
                errorWidget:SetStyle("TextColor", 1, 0, 0, 1)

                -- Remove error after a few seconds
                VCTimer:OnTicks(120, function()
                    if errorWidget and errorWidget.Destroy then
                        errorWidget:Destroy()
                    end
                end)
            end
        end
    end

    -- Store widget in the manager for refresh functionality
    local widgetKey = moduleUUID .. "_" .. varName .. "_" .. (isServerVar and "server" or "client")
    DynamicSettingsManager.allWidgetDescriptors[widgetKey] = widget

    return widget
end

-- Populate a tab with variables
function DynamicSettingsUI.PopulateVariablesTab(tab, variables, isServerTab)
    -- Clear existing content
    for _, child in ipairs(tab.Children) do
        child:Destroy()
    end

    -- If no variables, show a message
    if not variables or table.isEmpty(variables) then
        tab:AddText("No variables found")
        return
    end

    -- Group variables by mod
    -- TODO: iterate by storageType instead of hardcoding modVars
    for moduleUUID, modVars in pairs(variables) do
        local modInfo = Ext.Mod.GetMod(moduleUUID)
        local modName = modInfo and modInfo.Info.Name or moduleUUID

        -- Create a collapsing header for the mod
        local modHeader = DynamicSettingsUI.CreateModHeader(tab, moduleUUID, modName)

        -- Add variables
        for varName, varInfo in pairs(modVars) do
            DynamicSettingsUI.CreateVariableWidget(
                modHeader,
                moduleUUID,
                varName,
                varInfo.value,
                varInfo.storageType,
                isServerTab
            )
        end
    end
end

-- Create the dynamic settings UI in the provided parent
function DynamicSettingsUI.CreateUI(parent, dynamicSettingsManager)
    -- Add global controls
    local controlsGroup = DynamicSettingsUI.CreateGlobalControls(parent)

    -- Create tab bar
    local tabBar = parent:AddTabBar("DynamicSettingsTabBar")

    -- Create client variables tab
    local clientTab = DynamicSettingsUI.CreateVariablesTab(tabBar, false)

    -- Create server variables tab
    local serverTab = DynamicSettingsUI.CreateVariablesTab(tabBar, true)

    -- Populate client tab
    local clientVars = DynamicSettingsManager.DiscoverClientVars()
    DynamicSettingsUI.PopulateVariablesTab(clientTab, clientVars, false)

    -- Populate server tab if not in main menu
    if not MCMProxy.IsMainMenu() then
        DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
    end

    -- Subscribe to server vars updated event
    ModEventManager:Subscribe(EventChannels.MCM_SERVER_VARS_UPDATED, function()
        DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
    end)

    -- Subscribe to refresh event
    ModEventManager:Subscribe(EventChannels.MCM_DYNAMIC_SETTINGS_REFRESHED, function()
        -- Repopulate client tab
        local clientVars = DynamicSettingsManager.DiscoverClientVars()
        DynamicSettingsUI.PopulateVariablesTab(clientTab, clientVars, false)

        -- Repopulate server tab if not in main menu
        if not MCMProxy.IsMainMenu() then
            DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
        end
    end)

    return tabBar
end

-- Add the dynamic settings section to the MCM
function DynamicSettingsUI.AddDynamicSettingsSection(dualPane)
    -- Only available for the host
    if not Ext.Net.IsHost() then
        return
    end

    -- Create the section
    -- TODO: refactor dual pane to allow inserting buttons to an existing section (will be used for each storageType)
    local contentGroup = dualPane:AddMenuSectionWithContent(
        "Dynamic Settings",
        "Dynamic settings",
        "dynamic_settings"
    )

    -- Add global controls
    local controlsGroup = DynamicSettingsUI.CreateGlobalControls(contentGroup)

    -- Create tab bar
    local tabBar = contentGroup:AddTabBar("DynamicSettingsTabBar")

    -- Create client variables tab
    local clientTab = DynamicSettingsUI.CreateVariablesTab(tabBar, false)

    -- Create server variables tab
    local serverTab = DynamicSettingsUI.CreateVariablesTab(tabBar, true)

    -- Populate client tab
    local clientVars = DynamicSettingsManager.DiscoverClientVars()
    DynamicSettingsUI.PopulateVariablesTab(clientTab, clientVars, false)

    -- Populate server tab if not in main menu
    if not MCMProxy.IsMainMenu() then
        DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
    end

    -- Subscribe to server vars updated event
    ModEventManager:Subscribe(EventChannels.MCM_SERVER_VARS_UPDATED, function()
        DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
    end)

    -- Subscribe to refresh event
    ModEventManager:Subscribe(EventChannels.MCM_DYNAMIC_SETTINGS_REFRESHED, function()
        -- Repopulate client tab
        local clientVars = DynamicSettingsManager.DiscoverClientVars()
        DynamicSettingsUI.PopulateVariablesTab(clientTab, clientVars, false)

        -- Repopulate server tab if not in main menu
        if not MCMProxy.IsMainMenu() then
            DynamicSettingsUI.PopulateVariablesTab(serverTab, DynamicSettingsManager.serverSideVars, true)
        end
    end)

    return contentGroup
end

return DynamicSettingsUI
