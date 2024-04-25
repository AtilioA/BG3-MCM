SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
    if Config:getCfg().GENERAL.enabled == true then
        -- Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)

        -- Ext.Osiris.RegisterListener("UseStarted", 2, "before", EHandlers.OnUseStarted)
        -- Ext.Osiris.RegisterListener("ReadyCheckFailed", 1, "after", EHandlers.OnReadyCheckFailed)
        -- Ext.Osiris.RegisterListener("ReadyCheckPassed", 1, "after", EHandlers.OnReadyCheckPassed)
        -- Ext.Osiris.RegisterListener("UserConnected", 3, "after", EHandlers.OnUserConnected)
        -- Ext.Osiris.RegisterListener("CastedSpell", 5, "after", EHandlers.OnCastedSpell)

        -- When resetting Lua states
        Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)

        Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)
    end
end

return SubscribedEvents
