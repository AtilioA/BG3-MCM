RequireFiles("Client/", {
    "Helpers/_Init",
    "Services/_Init",
    "MCMProxy",
    "Components/_Init",
    "MCMRendering",
    "IMGUIAPI",
    "SubscribedEvents",
})

Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.ToState == Ext.Enums.ClientGameState["Menu"] then
        LoadOrderHealthCheck:WarnAboutInvalidUUIDs()
        LoadOrderHealthCheck:WarnAboutLoadOrderDependencies()
        LoadOrderHealthCheck:WarnAboutNPAKM()
        LoadOrderHealthCheck:WarnAboutModConflicts()
    end
end)
