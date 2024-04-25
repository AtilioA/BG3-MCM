EHandlers = {}

function EHandlers.OnReset()
    BG3MCM:LoadConfigs()
end

function EHandlers.OnLevelGameplayStarted()
    BG3MCM:LoadConfigs()
end

return EHandlers
