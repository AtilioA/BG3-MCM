NotificationPrinter = Printer:New { Prefix = "Notification Framework", ApplyColor = true, DebugLevel = MCM.Get('notification_framework_debug_level') }

-- Update the Printer debug level when the setting is changed, since the value is only used during the object's creation
-- NOTE: this does not work as expected because there are two sources of truth for the debug level: Notification settings.json and VCConfig json file
Ext.ModEvents['BG3MCM'][EventChannels.Notification_SETTING_SAVED]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "notification_framework_debug_level" then
        NotificationPrint(0, "Setting debug level to " .. payload.value)
        NotificationPrinter.DebugLevel = payload.value
    end
end)

function NotificationPrint(debugLevel, ...)
    NotificationPrinter:SetFontColor(0, 255, 255)
    NotificationPrinter:Print(debugLevel, ...)
end

-- TODO: Change to 'success'
function NotificationTest(debugLevel, ...)
    NotificationPrinter:SetFontColor(100, 200, 150)
    NotificationPrinter:PrintTest(debugLevel, ...)
end

function NotificationDebug(debugLevel, ...)
    NotificationPrinter:SetFontColor(200, 200, 0)
    NotificationPrinter:PrintDebug(debugLevel, ...)
end

function NotificationDeprecation(debugLevel, ...)
    NotificationPrinter:SetFontColor(220, 100, 0)

    if Notification and Notification.Get("print_deprecation_warnings") then
        NotificationPrinter:PrintWarning(debugLevel, ...)
    end
end

function NotificationWarn(debugLevel, ...)
    NotificationPrinter:SetFontColor(255, 100, 50)
    NotificationPrinter:PrintWarning(debugLevel, ...)
end

function NotificationDump(debugLevel, ...)
    NotificationPrinter:SetFontColor(190, 150, 225)
    NotificationPrinter:Dump(debugLevel, ...)
end

function NotificationDumpArray(debugLevel, ...)
    NotificationPrinter:DumpArray(debugLevel, ...)
end
