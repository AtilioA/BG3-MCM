RequireFiles("Shared/DynamicSettings/", {
    "Adapters/_Init",
    "Factories/_Init",
    "Services/_Init"
})

SettingsService = require("Shared/DynamicSettings/Services/SettingsService")
local StorageManager = require("Shared/DynamicSettings/Services/StorageManager")
StorageManager.RegisterEventListeners()
