--------------------------------------------
-- Handles restoration of the last used subtab for each mod page
-- Manages a mapping of mod UUIDs to their last used subtab names
-- Managed by StateRestorationManager
--------------------------------------------

---@class SubtabRestorationService
---@field isInitialized boolean Whether the service has been initialized
---@field manager StateRestorationManager|nil Reference to the state restoration manager
---@field tabInsertionHandlerId integer|nil ID for the tab insertion event handler
SubtabRestorationService = {
    isInitialized = false,
    manager = nil,
    tabInsertionHandlerId = nil,
}

-- Initialize the SubtabRestorationService
---@param manager StateRestorationManager The state restoration manager
function SubtabRestorationService:Initialize(manager)
    if self.isInitialized then
        return
    end

    MCMDebug(2, "SubtabRestorationService: Initializing...")

    -- Store reference to the manager
    self.manager = manager

    -- Register event listeners to record tab/subtab activations (for JSON persistence)
    self:RegisterEventListenersForPersistence()

    -- Restore last used subtab (also listens for tab insertions for dynamic tabs)
    self:RestoreLastUsedSubtab()

    MCMDebug(2, "SubtabRestorationService: Initialized")
    self.isInitialized = true
end

-- Register all required event listeners
function SubtabRestorationService:RegisterEventListenersForPersistence()
    -- Listen for subtab activation to update the stored subtab
    ModEventManager:Subscribe(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, function(payload)
        if payload and payload.modUUID and payload.tabName then
            self:UpdateLastUsedSubtab(payload.modUUID, payload.tabName)
        end
    end)

    -- Listen for page activation to select the stored subtab for that page
    ModEventManager:Subscribe(EventChannels.MCM_MOD_TAB_ACTIVATED, function(payload)
        if payload and payload.modUUID then
            self:RestoreLastUsedSubtab(payload.modUUID)
        end
    end)
end

-- Restore the last used subtab for a mod page
---@param modUUID string|nil The UUID of the mod, or nil to use last used page
function SubtabRestorationService:RestoreLastUsedSubtab(modUUID)
    -- Check if the feature is enabled
    local restoreLastPageEnabled = MCMAPI:GetSettingValue("restore_last_page", ModuleUUID)
    if restoreLastPageEnabled ~= true then
        MCMDebug(2, "SubtabRestorationService: Page restoration disabled in settings, cannot restore subtab")
        return
    end
    local restoreLastSubtabEnabled = MCMAPI:GetSettingValue("restore_last_subtab", ModuleUUID)
    if restoreLastSubtabEnabled ~= true then
        MCMDebug(2, "SubtabRestorationService: Subtab restoration disabled in settings")
        return
    end

    -- If no mod UUID provided, use the last used page
    if not modUUID or modUUID == "" then
        local config = Config:getCfg()
        modUUID = config.lastUsedPage or ""

        if modUUID == "" then
            MCMError(1,
                "SubtabRestorationService: No mod UUID provided and no last used page found, cannot restore subtab")
            return
        end
    end

    -- Check if the mod still exists using the manager's helper
    local modExists = self.manager:CheckModExists(modUUID)
    if not modExists then
        MCMWarn(1, "SubtabRestorationService: Cannot restore subtab for non-existent mod: " .. tostring(modUUID))
        return
    end

    -- Get the last used subtab from config
    local config = Config:getCfg()
    local tabName = config.lastUsedModSubTabs and config.lastUsedModSubTabs[modUUID] or ""

    if tabName == "" then
        MCMDebug(2, "SubtabRestorationService: No previous subtab to restore for mod: " .. modUUID)
        return
    end

    -- During initialization, respect open_on_start setting
    local shouldOpenWindow = not self.isInitialized and OpenOnStartHelper:ShouldOpenOnStart()
    MCMDebug(1,
        "SubtabRestorationService: Restoring subtab '" ..
        tabName .. "' for mod: " .. modUUID .. " (shouldOpenWindow: " .. tostring(shouldOpenWindow) .. ")")

    -- Let DualPaneController handle sidebar state based on settings
    DualPane:OpenModPage(modUUID, tabName, false, true, shouldOpenWindow)

    -- Set up a listener for when tabs are inserted - this is needed for dynamic tabs
    self:SetupTabInsertionListener(modUUID, tabName, shouldOpenWindow)
end

-- Update the last used subtab for a mod page
---@param modUUID string The UUID of the mod
---@param subtabName string The name of the subtab
function SubtabRestorationService:UpdateLastUsedSubtab(modUUID, subtabName)
    -- Skip if modUUID or subtabName is nil or empty
    if not modUUID or modUUID == "" or not subtabName or subtabName == "" then
        return
    end

    -- Skip updates during initialization to avoid capturing the initial page load
    if not self.isInitialized then
        return
    end

    -- Get the config and ensure lastUsedModSubTabs exists
    local config = Config:getCfg()
    config.lastUsedModSubTabs = config.lastUsedModSubTabs or {}

    -- Only update if it's a different subtab
    if config.lastUsedModSubTabs[modUUID] ~= subtabName then
        config.lastUsedModSubTabs[modUUID] = subtabName

        -- Also update the last used page
        config.lastUsedPage = modUUID

        Config:SaveCurrentConfig()
        MCMDebug(2, "SubtabRestorationService: Updated last used subtab for mod " .. modUUID .. ": " .. subtabName)
    end
end

--- Set up a listener for when a specific tab is inserted
---@param modUUID string The UUID of the mod
---@param tabName string The name of the tab to wait for
---@param shouldOpenWindow boolean|nil If true, opens the MCM window
function SubtabRestorationService:SetupTabInsertionListener(modUUID, tabName, shouldOpenWindow)
    -- Clean up any existing handler and timer, just in case
    self:CleanupTabInsertionListener()

    -- Create a one-time handler for tab insertions
    local function onTabInserted(e)
        local tabInfo = e
        if tabInfo and tabInfo.modUUID == modUUID and tabInfo.tabName == tabName then
            MCMDebug(2, "Awaited tab now available, opening mod page: " .. modUUID .. " and tab: " .. tabName)
            DualPane:OpenModPage(modUUID, tabName, false, true, shouldOpenWindow)

            self:CleanupTabInsertionListener()
        end
    end

    -- Register the event handler
    self.tabInsertionHandlerId = ModEventManager:Subscribe(EventChannels.MCM_MOD_TAB_ADDED, onTabInserted)

    -- Set up cleanup timer if no tab is found inserted within 10 seconds
    VCTimer:OnTime(ClientGlobals.MCM_RESTORATION_MOD_TAB_INSERTED_TIMEOUT, function()
        self:CleanupTabInsertionListener()
    end)
end

--- Clean up tab insertion listener and timer
function SubtabRestorationService:CleanupTabInsertionListener()
    -- Remove event handler if it exists
    MCMDebug(2, "Cleaning up tab insertion listener with handler ID: " .. tostring(self.tabInsertionHandlerId))
    if self.tabInsertionHandlerId then
        ModEventManager:Unsubscribe(EventChannels.MCM_MOD_TAB_ADDED, self.tabInsertionHandlerId)
        self.tabInsertionHandlerId = nil
    end
end

return SubtabRestorationService
