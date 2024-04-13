ISFPrinter = VolitionCabinetPrinter:New { Prefix = "Mod Configuration Menu", ApplyColor = true, DebugLevel = Config:GetCurrentDebugLevel() }

function ISFPrint(debugLevel, ...)
    ISFPrinter:SetFontColor(0, 255, 255)
    ISFPrinter:Print(debugLevel, ...)
end

function ISFTest(debugLevel, ...)
    ISFPrinter:SetFontColor(100, 200, 150)
    ISFPrinter:PrintTest(debugLevel, ...)
end

function ISFDebug(debugLevel, ...)
    ISFPrinter:SetFontColor(200, 200, 0)
    ISFPrinter:PrintDebug(debugLevel, ...)
end

function ISFWarn(debugLevel, ...)
    ISFPrinter:SetFontColor(255, 100, 50)
    ISFPrinter:PrintWarning(debugLevel, ...)
end

function ISFDump(debugLevel, ...)
    ISFPrinter:SetFontColor(190, 150, 225)
    ISFPrinter:Dump(debugLevel, ...)
end

function ISFDumpArray(debugLevel, ...)
    ISFPrinter:DumpArray(debugLevel, ...)
end
