-- Ironically, MCM cannot use itself for configuration since it needs these values on initialization. This is my now 'legacy' way of handling configuration taken from Volition Cabinet.

Config = VCConfig:New({
    folderName = Ext.Mod.GetMod(ModuleUUID).Info.Directory,
    configFilePath = "mod_configuration_menu_config.json",
    defaultConfig = {
        GENERAL = {
            enabled = true, -- Toggle the mod on/off
        },
        FEATURES = {
            open_on_start = true, -- Show the MCM window when the game starts
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
