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
        ownerModuleUUID = ModuleUUID,
        beforeRun = SuppressMCMTestLogs,
    })

    Ext.Require("Shared/DribbleSpec/BlueprintShape.test.lua")
    Ext.Require("Shared/DribbleSpec/EnumChoicesHelper.test.lua")
    Ext.Require("Shared/DribbleSpec/ConfigDefinition.test.lua")
    Ext.Require("Shared/DribbleSpec/BlueprintCache.test.lua")
    Ext.Require("Shared/DribbleSpec/DataPreprocessing.test.lua")
    Ext.Require("Shared/DribbleSpec/BlueprintHiddenFromList.test.lua")
    Ext.Require("Shared/DribbleSpec/JsonLayer.test.lua")
    Ext.Require("Shared/DribbleSpec/Validators.test.lua")
    Ext.Require("Shared/DribbleSpec/PathValidator.test.lua")
    Ext.Require("Shared/DribbleSpec/ValidateAndFixSettings.test.lua")
    Ext.Require("Shared/DribbleSpec/MCMAPI.test.lua")
    Ext.Require("Shared/DribbleSpec/ModConfig.test.lua")
    Ext.Require("Shared/DribbleSpec/LoadedSettingsRepair.test.lua")
    Ext.Require("Shared/DribbleSpec/EventButton.test.lua")
    Ext.Require("Shared/DribbleSpec/StorageSyncService.test.lua")
    Ext.Require("Shared/DribbleSpec/StoreFileName.test.lua")
    Ext.Require("Shared/DribbleSpec/StoreUnreadableFile.test.lua")
    Ext.Require("Shared/DribbleSpec/StoreSaveFailure.test.lua")
    Ext.Require("Shared/DribbleSpec/StorageSyncRegistration.test.lua")
    Ext.Require("Shared/DribbleSpec/StorageSyncLocalOnly.test.lua")
    Ext.Require("Shared/DribbleSpec/StoreModVarDefaults.test.lua")
    Ext.Require("Shared/DribbleSpec/StoreValues.test.lua")
    Ext.Require("Shared/DribbleSpec/SettingsServiceValidation.test.lua")
    Ext.Require("Shared/DribbleSpec/InternalAPIGuard.test.lua")
end
