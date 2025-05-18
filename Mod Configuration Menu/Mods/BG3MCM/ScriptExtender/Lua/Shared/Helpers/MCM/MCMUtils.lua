-- REFACTOR: This file should be split into multiple files, and the functions should be moved to the appropriate files.
-- ---@class HelperMCMUtils: Helper
-- MCMUtils = _Class:Create("HelperMCMUtils", Helper)

MCMUtils = {}

MCMUtils.NPAKMWarned = false


--- Sorts the mods by name and returns a sorted array of mod GUIDs, with MCM placed first
---@param mods table The table of mods to sort
---@return table The sorted array of mod GUIDs
function MCMUtils.SortModsByName(mods)
    -- Create an array for the UUIDs, to be sorted
    local sortedUuids = {}
    for uuid in pairs(mods) do
        table.insert(sortedUuids, uuid)
    end

    -- Sort the sortedUuids, placing MCM first
    table.sort(sortedUuids, function(a, b)
        if a == ModuleUUID then
            return true
        elseif b == ModuleUUID then
            return false
        else
            local modAName = MCMClientState:GetModName(a)
            local modBName = MCMClientState:GetModName(b)
            return modAName < modBName
        end
    end)

    return sortedUuids
end

function MCMUtils:ConditionalWrapper(conditionFunc, func)
    return function(...)
        if conditionFunc() then
            func(...)
        end
    end
end

-- Return the party members currently following the player
function MCMUtils:GetPartyMembers()
    local teamMembers = {}

    local allPlayers = Osi.DB_Players:Get(nil)
    for _, player in ipairs(allPlayers) do
        if not string.match(player[1]:lower(), "%f[%A]dummy%f[%A]") then
            teamMembers[#teamMembers + 1] = string.sub(player[1], -36)
        end
    end

    return teamMembers
end

-- Returns the character that the user is controlling
function MCMUtils:GetUserCharacter(userId)
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor.UserID == userId then
            return entity.Uuid.EntityUuid
        end
    end

    return nil
end

function MCMUtils:IsUserHost(userId)
    if userId == 65537 then
        return true
    end

    local character = self:GetUserCharacter(userId)
    if Osi.GetHostCharacter() == character then
        return true
    end

    return false
end

-- Thanks to Aahz for this function
function MCMUtils:PeerToUserID(u)
    -- all this for userid+1 usually smh
    return (u & 0xffff0000) | 0x0001
end

--- Play a sound effect on the host character (don't know if this works for multiplayer, would probably require getting the player character)
--- @param id GUIDSTRING
function MCMUtils:PlaySound(userid, id)
    local character = self:GetUserCharacter(userid) or Osi.GetHostCharacter()
    if character == nil then
        return
    end

    Osi.PlayEffect(character, id)
    Osi.PlaySound(character, id)
    Osi.PlaySoundResource(character, id)
end

---@param module? Guid
function MCMUtils:SyncModVars(module)
    local ModVars = Ext.Vars.GetModVariables(module or ModuleUUID)
    -- Redundant but worky :catyep:
    if ModVars then
        for varName, data in pairs(ModVars) do
            ModVars[varName] = ModVars[varName]
        end
        Ext.Vars.DirtyModVariables(module or ModuleUUID)
        Ext.Vars.SyncModVariables(module or ModuleUUID)
    end
end

--- Formats the mod version table to a string, omitting trailing zeros.
---@param ModuleUUID string The UUID of the mod
---@return string The formatted version string
function MCMUtils.FormatModVersion(ModuleUUID)
    if not ModuleUUID then
        return ""
    end

    local mod = Ext.Mod.GetMod(ModuleUUID)
    if not mod or not mod.Info.ModVersion then
        return ""
    end

    local rawVersion = mod.Info.ModVersion
    local lastIndex = #rawVersion

    while lastIndex > 1 and rawVersion[lastIndex] == 0 do
        lastIndex = lastIndex - 1
    end

    -- Build a new table with only the necessary numbers
    local parts = {}
    for i = 1, lastIndex do
        parts[i] = rawVersion[i]
    end

    return table.concat(parts, ".")
end

return MCMUtils
