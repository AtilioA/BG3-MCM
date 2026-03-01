--------------------------------------------
-- Encapsulates restoration of the last used mod page when the MCM UI is initialized
-- Managed by StateRestorationManager
--------------------------------------------

---@class PageRestorationService
---@field isInitialized boolean Whether the service has been initialized
---@field manager StateRestorationManager Reference to the state restoration manager
PageRestorationService = {
    isInitialized = false,
    manager = nil ---@type StateRestorationManager
}

-- Initialize the PageRestorationService
---@param manager StateRestorationManager The state restoration manager
function PageRestorationService:Initialize(manager)
    if self.isInitialized then
        return
    end

    MCMDebug(2, "PageRestorationService: Initializing...")

    -- Store reference to the manager
    self.manager = manager

    -- Register event listeners
    self:RegisterEventListeners()

    -- Attempt to restore the page (if we have one stored)
    self:RestoreLastModPage()

    MCMDebug(2, "PageRestorationService: Initialized")
    self.isInitialized = true
end

-- Register all required event listeners
function PageRestorationService:RegisterEventListeners()
    -- Listen for mod tab activation to update the stored mod page
    ModEventManager:Subscribe(EventChannels.MCM_MOD_TAB_ACTIVATED, function(payload)
        if payload and payload.modUUID then
            self:UpdateLastModPage(payload.modUUID)
        end
    end)
end

-- Restore the last used mod page when the MCM UI is ready
function PageRestorationService:RestoreLastModPage()
    -- Check if the feature is enabled
    local restoreLastPageEnabled = MCMAPI:GetSettingValue("restore_last_page", ModuleUUID)
    if restoreLastPageEnabled ~= true then
        MCMDebug(1, "PageRestorationService: Page restoration disabled in settings")
        return
    end

    -- Get the last mod UUID from config
    local config = Config:getCfg()
    local lastModUUID = config.lastUsedPage

    -- Check if the lastModUUID is empty or nil (e.g.: was never set)
    if not lastModUUID or lastModUUID == "" then
        MCMDebug(1, "PageRestorationService: No previous mod page to restore")
        return
    end

    -- Check if the mod still exists using the manager's helper
    local modExists = self.manager:CheckModExists(lastModUUID)
    if not modExists then
        MCMWarn(1,
            "PageRestorationService: Stored mod page no longer exists or is invalid (UUID: " ..
            lastModUUID .. "). Falling back to main page.")
        return
    end

    -- Only defer to subtab restoration if it's enabled AND we have a valid subtab saved for this mod
    local restoreLastSubtabEnabled = MCMAPI:GetSettingValue("restore_last_subtab", ModuleUUID)
    local hasValidSubtab = config.lastUsedModSubTabs and
        config.lastUsedModSubTabs[lastModUUID] and
        config.lastUsedModSubTabs[lastModUUID] ~= ""

    if restoreLastSubtabEnabled == true and hasValidSubtab then
        MCMDebug(1,
            "PageRestorationService: Subtab restoration enabled and valid subtab found - deferring to subtab restoration")
        return
    end

    -- During initialization, respect open_on_start setting
    local shouldOpenWindow = not self.isInitialized and OpenOnStartHelper:ShouldOpenOnStart()
    MCMDebug(1, "PageRestorationService: Restoring last used mod page: " .. lastModUUID)

    -- Let DualPaneController handle sidebar state based on settings
    DualPane:OpenModPage(lastModUUID, nil, false, true, shouldOpenWindow)
end

-- Update the last used mod page in the config
function PageRestorationService:UpdateLastModPage(modUUID)
    -- Skip if modUUID is nil or empty
    if not modUUID or modUUID == "" then
        return
    end

    -- Skip updates during initialization to avoid capturing the initial page load
    if not self.isInitialized then
        return
    end

    -- Update the config with the new mod UUID
    local config = Config:getCfg()

    -- Only update if it's a different mod UUID
    if config.lastUsedPage ~= modUUID then
        config.lastUsedPage = modUUID
        Config:SaveCurrentConfig()
        MCMDebug(1, "PageRestorationService: Updated last used mod page: " .. modUUID)
    end
end

return PageRestorationService
