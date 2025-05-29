MCMPrinter = Printer:New { Prefix = "Mod Configuration Menu", ApplyColor = true }

---@class MCMPrinter: Printer
---@field LogLevels table<string, boolean>
MCMPrinter = Printer:New {
    Prefix = "Mod Configuration Menu",
    ApplyColor = true,
    DebugLevel = Config:GetCurrentDebugLevel(),
    LogLevels = {
        print = true,
        debug = true,
        info = true,
        warn = true
    }
}

-- Update the Printer debug level when the setting is changed
function Printer:UpdateLogLevels()
    if not MCMAPI then
        return
    end
    MCMPrinter.LogLevels = {
        print = MCMAPI:GetSettingValue("log_level_print", ModuleUUID) ~= false,
        debug = MCMAPI:GetSettingValue("log_level_debug", ModuleUUID) == true,
        info = MCMAPI:GetSettingValue("log_level_info", ModuleUUID) == true,
        warn = MCMAPI:GetSettingValue("log_level_warn", ModuleUUID) ~= false
    }
end

-- Check if a specific log level is enabled
---@param logType string The log type to check (print, debug, info, warn)
---@return boolean
local function shouldLog(logType)
    return MCMPrinter.LogLevels[logType:lower()] == true
end

-- Update the Printer debug level when the setting is changed, since the value is only used during the object's creation
Ext.ModEvents['BG3MCM'][EventChannels.MCM_SETTING_SAVED]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "debug_level" then
        MCMPrint(0, "Setting debug level to " .. payload.value)
        MCMPrinter.DebugLevel = payload.value
        local config = Config:getCfg()
        config.DEBUG.level = payload.value
        Config:SaveCurrentConfig()
    elseif payload.settingId:find("^log_level_") then
        MCMPrinter:UpdateLogLevels()
    end
end)

function MCMPrint(debugLevel, ...)
    if not shouldLog("print") then return end
    MCMPrinter:SetFontColor(0, 255, 255) -- Cyan
    MCMPrinter:Print(debugLevel, ...)
end

---@param debugLevel integer Debug level for the message
---@param ... any Message parts to print
function MCMInfo(debugLevel, ...)
    if not shouldLog("info") then return end
    MCMPrinter:SetFontColor(200, 200, 200) -- Light gray
    MCMPrinter:Print(debugLevel, ...)
end

function MCMSuccess(debugLevel, ...)
    if not shouldLog("print") then return end
    MCMPrinter:SetFontColor(50, 255, 100) -- Green
    MCMPrinter:Print(debugLevel, ...)
end

function MCMDebug(debugLevel, ...)
    if not shouldLog("debug") then return end
    MCMPrinter:SetFontColor(200, 200, 0) -- Yellow
    MCMPrinter:PrintDebug(debugLevel, ...)
end

function MCMDeprecation(debugLevel, ...)
    if not MCMAPI:GetSettingValue("print_deprecation_warnings", ModuleUUID) then return end
    if not Ext.Debug.IsDeveloperMode() then return end

    MCMPrinter:SetFontColor(200, 80, 0) -- Orange
    MCMPrinter:PrintDeprecation(debugLevel, ...)
end

function MCMWarn(debugLevel, ...)
    if not shouldLog("warn") then return end
    MCMPrinter:SetFontColor(255, 100, 30) -- Orange-red
    MCMPrinter:PrintWarning(debugLevel, ...)
end

function MCMError(debugLevel, ...)
    -- Errors are always shown regardless of log level settings
    MCMPrinter:SetFontColor(255, 38, 38) -- Red
    MCMPrinter:PrintError(debugLevel, ...)
end

function MCMDump(debugLevel, ...)
    if not shouldLog("debug") then return end
    MCMPrinter:SetFontColor(190, 150, 225) -- Light purple
    MCMPrinter:Dump(debugLevel, ...)
end

function MCMDumpArray(debugLevel, ...)
    if not shouldLog("debug") then return end
    MCMPrinter:DumpArray(debugLevel, ...)
end
