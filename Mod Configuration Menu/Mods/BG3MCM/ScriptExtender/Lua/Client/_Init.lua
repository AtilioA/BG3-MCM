RequireFiles("Client/", {
    "MCMProxy",
    "Components/_Init",
    "Helpers/_Init",
    "IMGUILayer",
    "IMGUIAPI",
    "SubscribedEvents",
})


MCMAPI:LoadConfigs()
MCMClientState:LoadMods(MCMAPI.mods)
