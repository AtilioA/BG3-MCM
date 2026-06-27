if Mods.Dribbles then
    D = Mods.Dribbles.RegisterTestGlobals({
        commandAlias = "mcm_d",
        ownerModuleUUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d",
    })

    Ext.Require("Shared/DribbleSpec/Smoke.test.lua")
    Ext.Require("Shared/DribbleSpec/DataPreprocessing.test.lua")
    Ext.Require("Shared/DribbleSpec/Validators.test.lua")
    Ext.Require("Shared/DribbleSpec/ValidateAndFixSettings.test.lua")
    Ext.Require("Shared/DribbleSpec/MCMAPI.test.lua")
    Ext.Require("Shared/DribbleSpec/ModConfig.test.lua")
    Ext.Require("Shared/DribbleSpec/EventButton.test.lua")
    Ext.Require("Shared/DribbleSpec/VisibilityManager.test.lua")
    Ext.Require("Shared/DribbleSpec/StorageSyncService.test.lua")
end
