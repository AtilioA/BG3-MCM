local function updateLoca()
    for _, file in ipairs({ "BG3MCM_English.loca" }) do
        local fileName = string.format("Localization/English/%s.xml", file)
        local contents

        local success, err = pcall(function()
            contents = Ext.IO.LoadFile(fileName, "data")
        end)

        if not success then
            -- MCMWarn(2, "Error loading loca file: " .. err)
            return
        end

        if not contents then
            -- MCMWarn(1, "Failed to load loca file: " .. fileName)
            return
        end

        for line in string.gmatch(contents, "([^\r\n]+)\r*\n") do
            local handle, value = string.match(line, '<content contentuid="(%w+)".->(.+)</content>')
            if handle ~= nil and value ~= nil then
                value = value:gsub("&[lg]t;", {
                    ['&lt;'] = "<",
                    ['&gt;'] = ">"
                })
                Ext.Loca.UpdateTranslatedString(handle, value)
            end
        end
    end
end

if Ext.Debug.IsDeveloperMode() then
    updateLoca()
end

---Ext.Require files at the path
---@param path string
---@param files string[]
function RequireFiles(path, files)
    for _, file in pairs(files) do
        Ext.Require(string.format("%s%s.lua", path, file))
    end
end

-- Import NotiFramework for both server and clients
RequireFiles("NotiFramework/", {
    "_Init"
})

RequireFiles("Lib/reactivex/", { "_init" })

RequireFiles("Shared/", {
    "MetaClass",
    "Helpers/_Init",
    "Classes/_Init",
    "Tests/_Init",
    "DynamicSettings/_Init"
})

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion
if MODVERSION == nil then
    MCMWarn(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    local SEVersionNumber = Ext.Utils.Version()
    MCMPrint(0,
        "Volitio's Baldur's Gate 3 Mod Configuration Menu version " ..
        versionNumber .. " loaded (SE version " .. SEVersionNumber .. ")")
end

MCMAPI = MCMAPI:New({}, "BG3MCM")
if Config:getCfg().DEBUG.level > 2 then
    -- Add debug wrapper to BG3MCM (very useful for logging writes and reads)
    MCMAPI = _MetaClass._Debug(MCMAPI)
end

-- Unfortunately needed since postponing this will cause problems with mods that need to use the API during script initialization
MCMAPI:LoadConfigs()
