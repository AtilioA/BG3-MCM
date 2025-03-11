InvalidMods = {}

local NULL_UUID = "00000000-0000-0000-0000-000000000000"

--- Returns a list of mods that have a null UUID (00000000-0000-0000-0000-000000000000)
---@return table invalidMods
function InvalidMods:GetInvalidMods()
    local invalidMods = {}
    local modManager = Ext.Mod.GetModManager()
    if not modManager then
        return invalidMods
    end

    local availableMods = modManager.AvailableMods or {}
    
    for _, mod in ipairs(availableMods) do
        if mod
            and mod.Info
            and (mod.Info.ModuleUUID == NULL_UUID or mod.Info.ModuleUUIDString == NULL_UUID)
        then
            table.insert(invalidMods, mod)
        end
    end

    return invalidMods
end

return InvalidMods
