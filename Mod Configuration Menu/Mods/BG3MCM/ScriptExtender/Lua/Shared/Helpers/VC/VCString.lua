--[[
  This file contains a set of helper functions for working with strings, such as checking if a string contains a substring, calculating the Levenshtein distance between two strings, and finding the closest match from a list of valid options to an input string, which can be used to validate user config files.
]]

---@class HelperString: nil
VCString = _Class:Create("HelperString", nil)

---Check if string contains a substring (Courtesy of Fararagi although fr I was just lazy)
---@param str string the string to check
---@param substr string the substring
---@param caseSensitive? boolean
---@return boolean
function VCString:StringContains(str, substr, caseSensitive)
    caseSensitive = caseSensitive or false
    if caseSensitive then
        return string.find(str, substr, 1, true) ~= nil
    else
        str = string.lower(str)
        substr = string.lower(substr)
        return string.find(str, substr, 1, true) ~= nil
    end
end

--- Calculate the Levenshtein distance between two strings.
--- Useful for fuzzy string matching to find the closest match, when for example a user has to input a string and you want to find the closest match from a list of valid options (e.g. config values).
function VCString:LevenshteinDistance(str1, str2, case_sensitive)
    if not case_sensitive then
        str1 = string.lower(str1)
        str2 = string.lower(str2)
    end

    local len1 = string.len(str1)
    local len2 = string.len(str2)
    local matrix = {}
    local cost = 0

    -- Initialize the matrix
    for i = 0, len1, 1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2, 1 do
        matrix[0][j] = j
    end

    -- Calculate distances
    for i = 1, len1, 1 do
        for j = 1, len2, 1 do
            if string.byte(str1, i) == string.byte(str2, j) then
                cost = 0
            else
                cost = 1
            end

            matrix[i][j] = math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
        end
    end

    return matrix[len1][len2]
end

--- Find the closest match and distance given a list of valid options to an input string, using the Levenshtein distance.
---@param input string The user input string
---@param valid_options string[] A table of valid options to compare against
---@param case_sensitive? boolean Whether to consider case sensitivity when comparing strings
--- @return string|nil closest_match The closest matching string from the valid options.
--- @return number min_distance The Levenshtein distance between the user input and the closest match.
function VCString:FindClosestMatch(input, valid_options, case_sensitive)
    local min_distance = math.huge -- Represents infinity, just to initialize the variable
    local closest_match = nil
    for _, option in ipairs(valid_options) do
        local distance = self:LevenshteinDistance(input, option, case_sensitive)
        if distance < min_distance then
            min_distance = distance
            closest_match = option
        end
    end
    return closest_match, min_distance
end

--- Capitalize the first letter of a string
---@param str string The string to capitalize
function VCString:Capitalize(str)
    return str:gsub("^%l", string.upper)
end

--- Lowercase the first letter of a string
---@param str string The string to lowercase
function VCString:Lowercase(str)
    return str:gsub("^%u", string.lower)
end

--- Update a localized message with dynamic content
---@param handle string The handle of the localized message to update
---@param dynamicContent string The dynamic content to replace the placeholder with
function VCString:UpdateLocalizedMessage(handle, dynamicContent)
    -- Retrieve the current translated string for the given handle
    local currentMessage = Ext.Loca.GetTranslatedString(handle)

    -- Replace the placeholder [1] with the dynamic content. The g flag is for global replacement.
    local updatedMessage = string.gsub(currentMessage, "%[1%]", function() return dynamicContent end)

    -- Update the translated string with the new content, altering it during runtime. Any GetTranslatedString calls will now return this updated message.
    Ext.Loca.UpdateTranslatedString(handle, updatedMessage)
    return updatedMessage
end

-- Adds full stop to the end of the string if it doesn't already have one
function VCString:AddFullStop(str)
    if string.sub(str, -1) ~= "." then
        return str .. "."
    end
    return str
end

function VCString:Wrap(text, width)
    -- Ensure width is a positive integer
    if type(width) ~= "number" or width <= 0 then
        error("Width must be a positive integer")
    end

    -- Function to split a string into words
    local function splitIntoWords(str)
        local words = {}
        for word in str:gmatch("%S+") do
            table.insert(words, word)
        end
        return words
    end

    -- Function to join words into lines of specified width
    local function joinWordsIntoLines(words, width)
        local lines, currentLine = {}, ""
        for _, word in ipairs(words) do
            if #currentLine + #word + 1 > width then
                table.insert(lines, currentLine)
                currentLine = word
            else
                if #currentLine > 0 then
                    currentLine = currentLine .. " " .. word
                else
                    currentLine = word
                end
            end
        end
        if #currentLine > 0 then
            table.insert(lines, currentLine)
        end
        return lines
    end


    -- Split the text into words
    local words = splitIntoWords(text)

    -- Join the words into lines of the specified width
    local lines = joinWordsIntoLines(words, width)

    -- Concatenate the lines into a single string with newline characters
    return table.concat(lines, "\n")
end

---Checks if the search text fuzzy matches the target string
---@param target string The string to search within
---@param pattern string The fuzzy pattern to match
---@return boolean True if the pattern matches the target fuzzily, false otherwise
function VCString:FuzzyMatch(target, pattern)
    local patternLen = #pattern
    local targetLen = #target

    if patternLen == 0 then
        return true
    end

    local patternIndex = 1
    for i = 1, targetLen do
        local targetChar = target:sub(i, i)
        local patternChar = pattern:sub(patternIndex, patternIndex)

        if targetChar == patternChar then
            patternIndex = patternIndex + 1

            if patternIndex > patternLen then
                return true
            end
        end
    end

    return false
end

--- Add newlines after each period in a string
function VCString:AddNewlinesAfterPeriods(description)
    if not description or description == "" then
        MCMWarn(3, "Description is nil or empty.")
        return nil
    end

    return string.gsub(description, "%. ", ".\n")
end

--- Replace <br> tags with newlines in a string
function VCString:ReplaceBrWithNewlines(description)
    if not description or description == "" then return "" end

    return string.gsub(description, "<br>", "\n")
end

--- Update a localized message with dynamic content.
---@param handle string The handle of the localized message to update
---@vararg string One or more dynamic content values to replace the corresponding placeholders [1], [2], [3], etc.
function VCString:InterpolateLocalizedMessage(handle, ...)
    -- Retrieve the current translated string for the given handle.
    local currentMessage = Ext.Loca.GetTranslatedString(handle)
    local updatedMessage = currentMessage

    -- Gather all dynamic content values passed as varargs.
    local args = { ... }

    -- Iterate over each argument and replace the corresponding placeholder.
    for i, value in ipairs(args) do
        -- The pattern dynamically matches [i]. The %[] escapes the brackets.
        updatedMessage = string.gsub(updatedMessage, "%[" .. i .. "%]", value)
    end

    -- Update the translated string with the new content during runtime.
    if args.updateHandle then
        Ext.Loca.UpdateTranslatedString(handle, updatedMessage)
    end
    return VCString:ReplaceBrWithNewlines(updatedMessage)
end
