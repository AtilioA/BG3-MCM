--------------------------------------------
-- Handles restoration of the last used subtab for each mod page
-- Managed by StateRestorationManager
--------------------------------------------

---@class SubtabRestorationService
---@field isInitialized boolean Whether the service has been initialized
---@field manager StateRestorationManager Reference to the state restoration manager
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
end

-- Restore the last used subtab for a mod page
function SubtabRestorationService:RestoreLastUsedSubtab()
    -- Check if the feature is enabled
    local restoreLastPageEnabled = MCMAPI:GetSettingValue("restore_last_page", ModuleUUID)
    if restoreLastPageEnabled ~= true then
        MCMDebug(0, "SubtabRestorationService: Page restoration disabled in settings")
        return
    end

    local restoreLastSubtabEnabled = MCMAPI:GetSettingValue("restore_last_subtab", ModuleUUID)
    if restoreLastSubtabEnabled ~= true then
        MCMDebug(0, "SubtabRestorationService: Subtab restoration disabled in settings")
        return
    end

    -- Get the last used subtabs from config
    local config = Config:getCfg()
    local lastUsedPage = config.lastUsedPage or ""
    local lastUsedSubtab = config.lastUsedSubtab or ""

    if lastUsedPage == "" then
        MCMWarn(0, "SubtabRestorationService: No previous page to restore")
        return
    end

    -- Check if we have a stored subtab for this mod
    if lastUsedSubtab == "" then
        MCMDebug(0, "SubtabRestorationService: No previous subtab to restore for mod: " .. lastUsedPage)
        return
    end

    -- Check if the mod still exists using the manager's helper
    local modExists = self.manager:CheckModExists(lastUsedPage)
    if not modExists then
        MCMWarn(1, "SubtabRestorationService: Cannot restore subtab for non-existent mod: " .. lastUsedPage)
        return
    end

    -- Use the existing DualPane:OpenModPage method to open the subtab
    MCMDebug(0, "SubtabRestorationService: Restoring subtab '" .. lastUsedSubtab .. "' for mod: " .. lastUsedPage)
    DualPane:OpenModPage(lastUsedSubtab, lastUsedPage)
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

    -- Update the config with the new subtab
    local config = Config:getCfg()
    local lastUsedSubtab = config.lastUsedSubtab or ""
    local lastUsedPage = config.lastUsedPage or ""

    -- Only update if it's a different subtab
    if lastUsedSubtab ~= subtabName then
        lastUsedSubtab = subtabName
        config.lastUsedSubtab = lastUsedSubtab
        Config:SaveCurrentConfig()
        MCMDebug(2, "SubtabRestorationService: Updated last used subtab for mod " .. modUUID .. ": " .. subtabName)
    end

    -- Update the last used page if it's different
    if lastUsedPage ~= modUUID then
        lastUsedPage = modUUID
        config.lastUsedPage = lastUsedPage
        Config:SaveCurrentConfig()
        MCMDebug(2, "SubtabRestorationService: Updated last used page for mod " .. modUUID .. ": " .. modUUID)
    end
end

return SubtabRestorationService
