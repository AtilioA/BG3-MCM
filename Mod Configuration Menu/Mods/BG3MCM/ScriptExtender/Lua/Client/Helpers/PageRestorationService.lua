--------------------------------------------
-- PageRestorationService
-- Encapsulates auto-restoration of the last used mod page when the MCM UI is initialized.
--------------------------------------------

---@class PageRestorationService
---@field isInitialized boolean Whether the service has been initialized
PageRestorationService = {
    isInitialized = false,
    isSubscribed = false
}

-- Setup the service subscription to MCMClientState.UIReady
-- This ensures we don't try to access MCMClientState before it's ready
function PageRestorationService:Setup()
    if self.isSubscribed then
        return
    end

    MCMDebug(2, "PageRestorationService: Setting up subscription to MCMClientState.UIReady")

    -- Wait until MCMClientState is ready before initializing our service
    -- This is delayed to ensure we don't access MCMClientState too early
    Ext.Events.SessionLoaded:Subscribe(function()
        -- Small delay to ensure MCMClientState is properly initialized
        VCTimer:OnTicks(1, function()
            if MCMClientState and MCMClientState.UIReady then
                -- REVIEW: do I need to unsubscribe from this?
                MCMClientState.UIReady:Subscribe(function(ready)
                    if ready then
                        MCMDebug(1, "PageRestorationService: UIReady triggered, initializing service")
                        self:Initialize()
                    end
                end)

                self.isSubscribed = true
            else
                MCMWarn(0, "PageRestorationService: MCMClientState not found or UIReady not available")
            end
        end)
    end)

    return self
end

-- Initialize the PageRestorationService
-- Only called after MCMClientState.UIReady has triggered
function PageRestorationService:Initialize()
    if self.isInitialized then
        return
    end

    MCMDebug(1, "Initializing PageRestorationService...")

    -- Register the event listener for tab activation
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
    local restoreLastPageEnabled = MCMAPI:GetSettingValue("restore_last_page", ModuleUUID)
    if restoreLastPageEnabled ~= true then
        MCMDebug(1, "PageRestorationService: Page restoration disabled in settings")
        return
    end

    -- Get the last mod UUID from config
    local lastModUUID = Config:getCfg().lastUsedPage

    -- Check if the lastModUUID is empty or nil (e.g.: was never set)
    if not lastModUUID or lastModUUID == "" then
        MCMDebug(1, "PageRestorationService: No previous mod page to restore")
        return
    end

    -- Check if the mod still exists
    local modExists = self:CheckModExists(lastModUUID)
    if not modExists then
        MCMWarn(1,
        "PageRestorationService: Stored mod page no longer exists or is invalid (UUID: " ..
            lastModUUID .. "). Falling back to main page.")
        return
    end

    -- Restore the mod page using DualPaneController
    MCMDebug(0, "PageRestorationService: Restoring last used mod page: " .. lastModUUID)
    DualPane:OpenModPage(nil, lastModUUID)
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
        MCMDebug(2, "PageRestorationService: Updated last used mod page: " .. modUUID)
    end
end

-- Helper function to check if a mod exists
function PageRestorationService:CheckModExists(modUUID)
    if not modUUID or modUUID == "" then
        return false
    end

    -- Check if the mod UUID exists in the MCMClientState.mods
    if MCMClientState.mods and MCMClientState.mods[modUUID] then
        return true
    end

    return false
end

-- Start the setup process, which will wait for the appropriate time to initialize
PageRestorationService:Setup()

return PageRestorationService
