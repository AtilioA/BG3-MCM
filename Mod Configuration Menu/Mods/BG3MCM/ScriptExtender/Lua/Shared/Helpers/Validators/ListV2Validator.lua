---@class ListV2Validator: Validator
ListV2Validator = _Class:Create("ListV2Validator", Validator)

function ListV2Validator.Validate(config, value)
    if type(value) ~= "table" then
        MCMWarn(1, "Value must be a table")
        return false
    end

    local enabledKey = value.enabled ~= nil and "enabled" or "Enabled"
    if value[enabledKey] == nil or type(value[enabledKey]) ~= "boolean" then
        MCMWarn(1, "list_v2's 'Enabled' must be a boolean")
        return false
    end

    local elementsKey = value.elements ~= nil and "elements" or "Elements"
    if not value[elementsKey] or type(value[elementsKey]) ~= "table" then
        MCMWarn(1, "list_v2's 'Elements' must be a table.")
        return false
    end

    if #value[elementsKey] > 0 then
        for _key, element in ipairs(value[elementsKey]) do
            if type(element) ~= "table" or element.enabled == nil or type(element.enabled) ~= "boolean" then
                MCMWarn(0, "Each list_v2's element must be a table with an 'enabled' boolean")
                return false
            end
        end
    end

    return true
end
