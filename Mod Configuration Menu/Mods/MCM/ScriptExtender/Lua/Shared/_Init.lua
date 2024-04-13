setmetatable(Mods.BG3MCM, { __index = Mods.VolitionCabinet })

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

local VCModuleUUID = "f97b43be-7398-4ea5-8fe2-be7eb3d4b5ca"
if (not Ext.Mod.IsModLoaded(VCModuleUUID)) then
    Ext.Utils.Print("VOLITION CABINET HAS NOT BEEN LOADED. PLEASE MAKE SURE IT IS ENABLED IN YOUR MOD MANAGER.")
end

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion
if MODVERSION == nil then
    ISFWarn(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    ISFPrint(0, "Volitio's Baldur's Gate 3 Mod Configuration Menu version " .. versionNumber .. " loaded")
end

BG3MCM = ItemShipment:New()
if Config:getCfg().DEBUG.level > 1 then
    -- Add debug wrapper to BG3MCM (very useful for logging writes and reads)
    BG3MCM = _MetaClass._Debug(BG3MCM)
end

SubscribedEvents.SubscribeToEvents()
