-- REFACTOR: This file should be split into multiple files, and the functions should be moved to the appropriate files.
-- ---@class HelperMCMUtils: Helper
-- MCMUtils = _Class:Create("HelperMCMUtils", Helper)

MCMUtils = {}

--- Utility function to check if a table contains a value
---@param tbl table The table to search
---@param element any The element to find
---@return boolean - Whether the table contains the element
function table.contains(tbl, element)
    if type(tbl) ~= "table" then
        return false
    end

    if tbl == nil or element == nil then
        return false
    end

    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

---Utility function to find the index of an element in a table
---@param tbl table The table to search
---@param element any The element to find
---@return integer|nil i The index of the element in the table, or nil if the element is not found
function table.indexOf(tbl, element)
    for i, value in ipairs(tbl) do
        if value == element then
            return i
        end
    end
    return nil
end

-- Utility function to check if a table is an array, since Lua couldn't be bothered to separate arrays and hash tables
---@param tbl table The table to check.
---@return boolean True if the table is an array, false otherwise.
function table.isArray(tbl)
    local index = 0
    for _ in pairs(tbl) do
        index = index + 1
        if tbl[index] == nil then
            return false
        end
    end
    return true
end

-- Convert string representations of booleans to actual boolean values in a table
function table.convertStringBooleans(tbl)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            table.convertStringBooleans(value)
        elseif value == "true" then
            tbl[key] = true
        elseif value == "false" then
            tbl[key] = false
        end
    end
end

--- Check if a table is empty ([], {})
function table.isEmpty(tbl)
    return next(tbl) == nil
end

--- Sorts the mods by name and returns a sorted array of mod GUIDs, with MCM placed first
---@param mods table The table of mods to sort
---@return table The sorted array of mod GUIDs
function MCMUtils.SortModsByName(mods)
    -- Create an array for the UUIDs, to be sorted
    local sortedUuids = {}
    for uuid in pairs(mods) do
        table.insert(sortedUuids, uuid)
    end

    -- Sort the sortedUuids, placing the mod with UUID 755a8a72-407f-4f0d-9a33-274ac0f0b53d first
    table.sort(sortedUuids, function(a, b)
        if a == "755a8a72-407f-4f0d-9a33-274ac0f0b53d" then
            return true
        elseif b == "755a8a72-407f-4f0d-9a33-274ac0f0b53d" then
            return false
        else
            local modAName = MCMClientState:GetModName(a)
            local modBName = MCMClientState:GetModName(b)
            return modAName < modBName
        end
    end)

    return sortedUuids
end

--- Add newlines after each period in a string
function MCMUtils.AddNewlinesAfterPeriods(description)
    return string.gsub(description, "%. ", ".\n")
end

--- Replace <br> tags with newlines in a string
function MCMUtils.ReplaceBrWithNewlines(description)
    return string.gsub(description, "<br>", "\n")
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
    local partyMembers = self:GetPartyMembers()
    for _, member in ipairs(partyMembers) do
        if Osi.GetReservedUserID(member) == userId then
            return member
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

function MCMUtils.UpdateLoca()
    for _, file in ipairs({ "BG3MCM_English.loca" }) do
        local fileName = string.format("Localization/English/%s.xml", file)
        local contents = Ext.IO.LoadFile(fileName, "data")

        if not contents then
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

return MCMUtils
