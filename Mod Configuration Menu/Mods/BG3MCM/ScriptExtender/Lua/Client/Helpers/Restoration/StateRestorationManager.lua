--------------------------------------------
-- Central coordinator for UI state restoration services
-- Manages initialization and provides shared helpers for restoration services
--------------------------------------------

---@class StateRestorationManager
---@field isInitialized boolean Whether the manager has been initialized
---@field isSubscribed boolean Whether the manager has subscribed to MCMClientState.UIReady
---@field services table<string, any> Table of registered restoration services
StateRestorationManager = {
    isInitialized = false,
    isSubscribed = false,
    services = {}
}

-- Common function to check if a mod exists in MCMClientState
function StateRestorationManager:CheckModExists(modUUID)
    if not modUUID or modUUID == "" then
        return false
    end

    -- if not DualPane:DoesModPageExist(modUUID) then
    --     return false
    -- end

    if MCMClientState and MCMClientState.mods and MCMClientState.mods[modUUID] then
        return true
    end

    return false
end

-- Register a restoration service with the manager
---@param name string Service identifier
---@param service table The service object
function StateRestorationManager:RegisterService(name, service)
    if self.services[name] then
        MCMDebug(1, "StateRestorationManager: Service already registered: " .. name)
        return
    end

    self.services[name] = service
    MCMDebug(1, "StateRestorationManager: Registered service: " .. name)
end

-- Initialize all registered services
function StateRestorationManager:InitializeServices()
    for name, service in pairs(self.services) do
        if service.Initialize then
            MCMDebug(1, "StateRestorationManager: Initializing service: " .. name)
            service:Initialize(self)
        end
    end

    self.isInitialized = true
end

-- Setup the manager subscription to MCMClientState.UIReady
function StateRestorationManager:Setup()
    if self.isSubscribed then
        return
    end

    MCMDebug(2, "StateRestorationManager: Setting up...")

    -- Wait until MCMClientState is ready before initializing services
    Ext.Events.SessionLoaded:Subscribe(function()
        -- Small delay to ensure MCMClientState is properly initialized
        VCTimer:OnTicks(1, function()
            if MCMClientState and MCMClientState.UIReady then
                -- Subscribe to UIReady to know when the UI is fully loaded
                MCMClientState.UIReady:Subscribe(function(ready)
                    if ready then
                        MCMDebug(1, "StateRestorationManager: MCM UI is ready, initializing services")
                        self:InitializeServices()
                    end
                end)

                self.isSubscribed = true
            else
                MCMWarn(0, "StateRestorationManager: MCMClientState not found or UIReady not available")
            end
        end)
    end)

    return self
end

return StateRestorationManager
