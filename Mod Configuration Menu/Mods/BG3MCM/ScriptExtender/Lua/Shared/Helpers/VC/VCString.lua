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
    local updatedMessage = string.gsub(currentMessage, "%[1%]", dynamicContent)

    -- Update the translated string with the new content, altering it during runtime. Any GetTranslatedString calls will now return this updated message.
    Ext.Loca.UpdateTranslatedString(handle, updatedMessage)
    return updatedMessage
end
