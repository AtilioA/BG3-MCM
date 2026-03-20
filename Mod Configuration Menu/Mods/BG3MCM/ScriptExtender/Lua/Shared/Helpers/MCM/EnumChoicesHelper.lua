-- REVIEW: this should generally be defined in EnumWidget, and let polymorphism take over, not loosely here

---@class EnumChoicesHelper
EnumChoicesHelper = {}

---@param values table|nil
---@return table
local function copyArray(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

---@param choices any
---@return boolean
function EnumChoicesHelper.AreChoicesValid(choices)
    if type(choices) ~= "table" then
        return false
    end

    if not table.isArray(choices) then
        return false
    end

    for _, choice in ipairs(choices) do
        if type(choice) ~= "string" then
            return false
        end
    end

    return true
end

---@param choices table|nil
---@return string[]
function EnumChoicesHelper.CopyChoices(choices)
    return copyArray(choices)
end

---@param setting BlueprintSetting
---@param choices string[]
---@return boolean
function EnumChoicesHelper.ApplyChoices(setting, choices)
    if not setting or setting:GetType() ~= "enum" then
        return false
    end

    if not EnumChoicesHelper.AreChoicesValid(choices) then
        return false
    end

    local options = setting:GetOptions() or {}
    options.Choices = copyArray(choices)
    options._RuntimeChoicesInjected = true
    setting:SetOptions(options)

    return true
end

---@param setting BlueprintSetting
---@param value any
---@return boolean
function EnumChoicesHelper.IsValueValid(setting, value)
    local options = setting and setting:GetOptions() or nil
    local choices = options and options.Choices or nil
    if choices == nil then
        return false
    end

    if type(value) ~= "string" then
        return false
    end

    if options.Dynamic == true then
        return true
    end

    if #choices == 0 then
        return true
    end

    return table.contains(choices, value)
end

---@param setting BlueprintSetting
---@param currentValue any
---@return any
function EnumChoicesHelper.ResolveValue(setting, currentValue)
    local choices = setting:GetOptions().Choices or {}
    if #choices == 0 then
        return currentValue
    end

    if table.contains(choices, currentValue) then
        return currentValue
    end

    local defaultValue = setting:GetDefault()
    if type(defaultValue) == "string" and table.contains(choices, defaultValue) then
        return defaultValue
    end

    return choices[1]
end

return EnumChoicesHelper
