RequireFiles("Client/", {
    "Services/_Init",
    "MCMProxy",
    "Helpers/_Init",
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
