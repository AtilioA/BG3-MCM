RequireFiles("Shared/DynamicSettings/", {
    "Adapters/_Init",
    "Factories/_Init",
    "Services/_Init"
})

SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local StorageManager = Ext.Require("Shared/DynamicSettings/Services/StorageManager.lua")
StorageManager.RegisterEventListeners()
