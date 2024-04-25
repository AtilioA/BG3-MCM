Config = VCConfig:New({
    folderName = Ext.Mod.GetMod(ModuleUUID).Info.Directory,
    configFilePath = "mod_configuration_menu_config.json",
    defaultConfig = {
        GENERAL = {
            enabled = true, -- Toggle the mod on/off
        },
        FEATURES = {        -- Maybe add options that can override values set by mod authors?
        },
        DEBUG = {
            level = 0,           -- 0 = no debug, 1 = minimal, 2 = verbose debug logs
            write_to_file = true -- Write debug logs to a file (UNIMPLEMENTED)
        },
        onConfigReloaded = {}
    }
})

Config:UpdateCurrentConfig()

Config:AddConfigReloadedCallback(function(configInstance)
    MCMPrinter.DebugLevel = configInstance:GetCurrentDebugLevel()
    MCMPrint(0, "Config reloaded: " .. Ext.Json.Stringify(configInstance:getCfg(), { Beautify = true }))
end)
Config:RegisterReloadConfigCommand("mcm_reload")
