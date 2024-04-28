EHandlers = {}

function EHandlers.OnLevelGameplayStarted()
    MCM:LoadAndSendSettings()
end

return EHandlers
