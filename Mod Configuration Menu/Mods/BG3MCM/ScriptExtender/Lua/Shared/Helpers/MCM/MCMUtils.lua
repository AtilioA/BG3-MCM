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
            local modA = Ext.Mod.GetMod(a)
            local modB = Ext.Mod.GetMod(b)
            return modA.Info.Name < modB.Info.Name
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

-- function MCMUtils.UpdateLoca()
--     for _, file in ipairs({ "mcm.loca" }) do
--         local fileName = string.format("Localization/English/%s.xml", file)
--         local contents = Ext.IO.LoadFile(fileName, "data")

--         for line in string.gmatch(contents, "([^\r\n]+)\r*\n") do
--             local handle, value = string.match(line, '<content contentuid="(%w+)".->(.+)</content>')
--             if handle ~= nil and value ~= nil then
--                 value = value:gsub("&[lg]t;", {
--                     ['&lt;'] = "<",
--                     ['&gt;'] = ">"
--                 })
--                 Ext.Loca.UpdateTranslatedString(handle, value)
--             end
--         end
--     end

--     if debug then
--         VCDebug(0, "Finished loading loca files.")
--     end
-- end

-- MCMUtils.UpdateLoca()

function MCMUtils:ConditionalWrapper(conditionFunc, func)
    return function(...)
        if conditionFunc() then
            func(...)
        end
    end
end

function MCMUtils:UIScaleValueToNumber(value)
    if type(value) == "number" then
        return value
    end
    return tonumber(value:sub(1, -2))
end

--- Play a sound effect on the host character (don't know if this works for multiplayer, would probably require getting the player character)
--- @param id GUIDSTRING
function MCMUtils:PlaySound(id)
    Osi.PlayEffect(Osi.GetHostCharacter(), id)
    Osi.PlaySound(Osi.GetHostCharacter(), id)
    Osi.PlaySoundResource(Osi.GetHostCharacter(), id)
end

return MCMUtils
