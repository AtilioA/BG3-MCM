---Ext.Require files at the path
---@param path string
---@param files string[]
function RequireFiles(path, files)
    for _, file in pairs(files) do
        Ext.Require(string.format("%s%s.lua", path, file))
    end
end

RequireFiles("Shared/", {
    "MetaClass",
    "Helpers/_Init",
    "Classes/_Init",
    "Tests/_Init",
})

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion
if MODVERSION == nil then
    MCMWarn(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    local SEVersionNumber = Ext.Utils.Version()
    MCMPrint(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu version " .. versionNumber .. " loaded (SE version " .. SEVersionNumber .. ")")
end

MCMAPI = MCM:New({}, "BG3MCM")
if Config:getCfg().DEBUG.level > 1 then
    -- Add debug wrapper to BG3MCM (very useful for logging writes and reads)
    MCMAPI = _MetaClass._Debug(MCMAPI)
end

-- Unfortunately needed since postponing this will cause problems with mods that need to use the API during script initialization
MCMAPI:LoadConfigs()

if Ext.Debug.IsDeveloperMode() then
    MCMUtils.UpdateLoca()
end
