Config = VCConfig:New({
    folderName = "BG3MCM",
    configFilePath = "mod_configuration_menu_config.json",
    defaultConfig = {
        GENERAL = {
            enabled = true, -- Toggle the mod on/off
        },
        FEATURES = {        -- Options that can override values set by mod authors?
        },
        DEBUG = {
            level = 0 -- 0 = no debug, 1 = minimal, 2 = verbose debug logs
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
