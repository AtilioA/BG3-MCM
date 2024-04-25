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
    "SubscribedEvents",
    "EventHandlers",
})

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion
if MODVERSION == nil then
    MCMWarn(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    MCMPrint(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu version " .. versionNumber .. " loaded")
end

BG3MCM = MCM:New({}, "BG3MCM")
if Config:getCfg().DEBUG.level > 1 then
    -- Add debug wrapper to BG3MCM (very useful for logging writes and reads)
    BG3MCM = _MetaClass._Debug(BG3MCM)
end

SubscribedEvents.SubscribeToEvents()
