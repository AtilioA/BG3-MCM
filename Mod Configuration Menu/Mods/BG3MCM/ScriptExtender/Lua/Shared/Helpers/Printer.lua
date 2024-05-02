MCMPrinter = Printer:New { Prefix = "Mod Configuration Menu", ApplyColor = true, DebugLevel = Config:GetCurrentDebugLevel() }

-- Update the Printer debug level when the setting is changed, since the value is only used during the object's creation
-- NOTE: this does not work as expected because there are two sources of truth for the debug level: MCM settings.json and VCConfig json file
Ext.RegisterNetListener(Channels.MCM_SAVED_SETTING, function(call, payload)
    local data = Ext.Json.Parse(payload)
    if not data or data.modGUID ~= ModuleUUID or not data.settingName then
        return
    end

    if data.settingName == "debug_level" then
        _D("Setting debug level to " .. data.value)
        MCMPrinter.DebugLevel = data.value
    end
end)

function MCMPrint(debugLevel, ...)
    MCMPrinter:SetFontColor(0, 255, 255)
    MCMPrinter:Print(debugLevel, ...)
end

function MCMTest(debugLevel, ...)
    MCMPrinter:SetFontColor(100, 200, 150)
    MCMPrinter:PrintTest(debugLevel, ...)
end

function MCMDebug(debugLevel, ...)
    MCMPrinter:SetFontColor(200, 200, 0)
    MCMPrinter:PrintDebug(debugLevel, ...)
end

function MCMWarn(debugLevel, ...)
    MCMPrinter:SetFontColor(255, 100, 50)
    MCMPrinter:PrintWarning(debugLevel, ...)
end

function MCMDump(debugLevel, ...)
    MCMPrinter:SetFontColor(190, 150, 225)
    MCMPrinter:Dump(debugLevel, ...)
end

function MCMDumpArray(debugLevel, ...)
    MCMPrinter:DumpArray(debugLevel, ...)
end
