RequireFiles("Client/Helpers/Restoration/", {
    "StateRestorationManager",
    "PageRestorationService",
    "SubtabRestorationService"
})

-- Initialize the manager with the services
StateRestorationManager:RegisterService("PageRestorationService", PageRestorationService)
StateRestorationManager:RegisterService("SubtabRestorationService", SubtabRestorationService)

-- Start the manager
StateRestorationManager:Setup()
