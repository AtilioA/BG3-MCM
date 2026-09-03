if Mods.Dribbles then
    ---@param _options table
    ---@return fun()
    local function SuppressMCMTestLogs(_options)
        local previousDebugLevel = MCMPrinter.DebugLevel
        MCMPrinter.DebugLevel = -1

        return function()
            MCMPrinter.DebugLevel = previousDebugLevel
        end
    end

    D = Mods.Dribbles.RegisterTestGlobals({
        commandAlias = "mcm_d",
        ownerModuleUUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d",
        beforeRun = SuppressMCMTestLogs,
    })

    Ext.Require("Shared/DribbleSpec/Smoke.test.lua")
    Ext.Require("Shared/DribbleSpec/BlueprintCache.test.lua")
    Ext.Require("Shared/DribbleSpec/DataPreprocessing.test.lua")
    Ext.Require("Shared/DribbleSpec/JsonLayer.test.lua")
    Ext.Require("Shared/DribbleSpec/Validators.test.lua")
    Ext.Require("Shared/DribbleSpec/ValidateAndFixSettings.test.lua")
    Ext.Require("Shared/DribbleSpec/MCMAPI.test.lua")
    Ext.Require("Shared/DribbleSpec/ModConfig.test.lua")
    Ext.Require("Shared/DribbleSpec/EventButton.test.lua")
    Ext.Require("Shared/DribbleSpec/VisibilityManager.test.lua")
    Ext.Require("Shared/DribbleSpec/StorageSyncService.test.lua")
    Ext.Require("Shared/DribbleSpec/InternalAPIGuard.test.lua")
    if Ext.IsClient() then
        Ext.Require("Shared/DribbleSpec/KeybindingCaptureSession.test.lua")
        Ext.Require("Shared/DribbleSpec/SettingWrite.test.lua")
        Ext.Require("Shared/DribbleSpec/Keybindings.test.lua")
    end
end
