RequireFiles("Client/", {
    "MCMProxy",
    "Components/_Init",
    "Helpers/_Init",
    "IMGUILayer",
    "IMGUIAPI",
    "SubscribedEvents",
})

Ext.Events.GameStateChanged:Subscribe(function(e)
    MCMProxy.GameState = e.ToState

    if e.ToState == Ext.Enums.ClientGameState["Menu"] then
        MCMAPI:LoadConfigs()
        MCMClientState:LoadMods(MCMAPI.mods)
        Noesis:ListenToMainMenuButtonPress()
    end
end)
