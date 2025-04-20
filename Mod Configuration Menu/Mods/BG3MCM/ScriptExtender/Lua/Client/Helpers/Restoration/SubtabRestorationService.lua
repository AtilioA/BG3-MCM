--------------------------------------------
-- Handles restoration of the last used subtab for each mod page
-- Manages a mapping of mod UUIDs to their last used subtab names
-- Managed by StateRestorationManager
--------------------------------------------

---@class SubtabRestorationService
---@field isInitialized boolean Whether the service has been initialized
---@field manager StateRestorationManager|nil Reference to the state restoration manager
SubtabRestorationService = {
    isInitialized = false,
    manager = nil
}

-- Initialize the SubtabRestorationService
---@param manager StateRestorationManager The state restoration manager
function SubtabRestorationService:Initialize(manager)
    if self.isInitialized then
        return
    end

    MCMDebug(1, "SubtabRestorationService: Initializing...")

    -- Store reference to the manager
    self.manager = manager

    -- Register event listeners
    self:RegisterEventListeners()

    self:RestoreLastUsedSubtab()

    MCMDebug(1, "SubtabRestorationService: Initialized")
    self.isInitialized = true
end

-- Register all required event listeners
function SubtabRestorationService:RegisterEventListeners()
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
---@param modUUID string The UUID of the mod
function SubtabRestorationService:RestoreLastUsedSubtab(modUUID)
    -- Check if the feature is enabled
    local restoreLastPageEnabled = MCMAPI:GetSettingValue("restore_last_page", ModuleUUID)
    if restoreLastPageEnabled ~= true then
        MCMDebug(2, "SubtabRestorationService: Page restoration disabled in settings")
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
            MCMDebug(2, "SubtabRestorationService: No mod UUID provided and no last used page found")
            return
        end
    end

    -- Check if the mod still exists using the manager's helper
    local modExists = self.manager:CheckModExists(modUUID)
    if not modExists then
        MCMWarn(1, "SubtabRestorationService: Cannot restore subtab for non-existent mod: " .. modUUID)
        return
    end

    -- Get the last used subtabs from config
    local config = Config:getCfg()
    local lastUsedModSubTabs = config.lastUsedModSubTabs or {}
    local lastUsedSubtab = lastUsedModSubTabs[modUUID] or ""

    -- Check if we have a stored subtab for this mod
    if lastUsedSubtab == "" then
        MCMDebug(2, "SubtabRestorationService: No previous subtab to restore for mod: " .. modUUID)
        return
    end

    -- During initialization, respect open_on_start setting
    local shouldOpenWindow = not self.isInitialized or MCMAPI:GetSettingValue("open_on_start", ModuleUUID)
    MCMDebug(1, "SubtabRestorationService: Restoring subtab '" .. lastUsedSubtab .. "' for mod: " .. modUUID)

    -- Let DualPaneController handle sidebar state based on settings
    DualPane:OpenModPage(lastUsedSubtab, modUUID, false, true, shouldOpenWindow)
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

return SubtabRestorationService
