SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
    if Config:getCfg().GENERAL.enabled == true then
        -- When resetting Lua states
        -- Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)

        Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)
    end
end

return SubscribedEvents
