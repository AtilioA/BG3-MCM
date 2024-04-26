EHandlers = {}

-- function EHandlers.OnReset()
    -- MCMAPI:LoadConfigs()
-- end

function EHandlers.OnLevelGameplayStarted()
    MCMAPI:LoadConfigs()
end

return EHandlers
