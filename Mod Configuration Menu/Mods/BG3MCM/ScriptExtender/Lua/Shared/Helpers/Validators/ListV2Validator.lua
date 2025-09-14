---@class ListV2Validator: Validator
ListV2Validator = _Class:Create("ListV2Validator", Validator)

-- TODO: refactor validator to allow removing only incorrect elements instead of resetting the entire list
function ListV2Validator.Validate(config, value)
    if type(value) ~= "table" then
        MCMWarn(1, "Value must be a table")
        return false
    end

    if value.enabled == nil or type(value.enabled) ~= "boolean" then
        MCMWarn(1, "list_v2's 'enabled' must be a boolean")
        return false
    end

    if not value.elements or type(value.elements) ~= "table" then
        MCMWarn(1, "list_v2's 'elements' must be a table.")
        return false
    end

    if #value.elements > 0 then
        for _key, element in ipairs(value.elements) do
            if type(element) ~= "table" or element.enabled == nil or type(element.enabled) ~= "boolean" or element.name == nil or type(element.name) ~= "string" or element.name == "" then
                MCMWarn(0, "Each list_v2's element must be a table with an 'enabled' boolean")
                return false
            end
        end
    end

    return true
end
