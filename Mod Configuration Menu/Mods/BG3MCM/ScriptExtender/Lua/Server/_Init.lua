RequireFiles("Server/", {
    "MCMUtils",
    "ModEventManager",
    "AuthorizedNetCommand",
    "MCMServer",
    "EventHandlers",
    "SubscribedEvents",
    "DribbleSpec/_Init",
})

SubscribedEvents.SubscribeToEvents()
