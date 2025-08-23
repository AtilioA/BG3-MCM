RequireFiles("Client/", {
    "Helpers/_Init",
    "Services/_Init",
    "MCMProxy",
    "Components/_Init",
    "MCMRendering",
    "IMGUIAPI",
    "SubscribedEvents",
})

local LoadOrderHealthCheckToggles = require("Shared/Helpers/LoadOrderHealthCheck/LoadOrderHealthCheckToggles")

Ext.Events.GameStateChanged:Subscribe(function(e)
    LoadOrderHealthCheckToggles:RunAllChecks(e)
end)
