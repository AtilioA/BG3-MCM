MCMPrinter = Printer:New { Prefix = "Mod Configuration Menu", ApplyColor = true, DebugLevel = Config:GetCurrentDebugLevel() }

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
