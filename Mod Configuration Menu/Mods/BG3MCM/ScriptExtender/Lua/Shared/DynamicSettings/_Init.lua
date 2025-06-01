RequireFiles("Shared/DynamicSettings/", {
  "Adapters/_Init",
  "Factories/_Init",
  "Services/_Init"
})

local StorageManager = require("Shared/DynamicSettings/Services/StorageManager")
StorageManager.RegisterEventListeners()
