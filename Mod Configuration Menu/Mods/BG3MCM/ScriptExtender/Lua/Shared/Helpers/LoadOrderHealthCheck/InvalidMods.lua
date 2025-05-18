InvalidMods = {}

local NULL_UUID = "00000000-0000-0000-0000-000000000000"

function InvalidMods:IsModInvalid(modUUID)
    return modUUID == NULL_UUID
end

--- Returns a list of mods that have a null UUID (00000000-0000-0000-0000-000000000000)
---@return table invalidMods
function InvalidMods:GetInvalidModsFromLoadOrder(modManagerInstance)
    local invalidMods = {}
    local availableMods = modManagerInstance.AvailableMods or {}

    for _, mod in ipairs(availableMods) do
        if mod
            and mod.Info
            and (self:IsModInvalid(mod.Info.ModuleUUID) or self:IsModInvalid(mod.Info.ModuleUUIDString))
        then
            table.insert(invalidMods, mod)
        end
    end

    return invalidMods
end

return InvalidMods
