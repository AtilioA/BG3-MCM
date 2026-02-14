---@class RadioValidator: Validator
RadioValidator = _Class:Create("RadioValidator", Validator)

---@param config BlueprintSetting
---@param value any
---@param validationContext? table
---@return boolean
function RadioValidator.Validate(config, value, validationContext)
    if type(value) ~= "string" then
        return false
    end

    validationContext = validationContext or {}

    local modUUID = validationContext.modUUID
    local allowStaleDynamicChoice = validationContext.allowStaleDynamicChoice == true
    local dynamicChoicesEnabled = MCMSettingRuntimeRegistry and MCMSettingRuntimeRegistry:IsDynamicChoicesEnabled(config)
    local allowEmptyValue = MCMSettingRuntimeRegistry and MCMSettingRuntimeRegistry:AllowEmptyValue(config)

    if allowEmptyValue and value == "" then
        return true
    end

    local availableChoices = nil
    if MCMSettingRuntimeRegistry then
        availableChoices = MCMSettingRuntimeRegistry:GetEffectiveChoices(config, modUUID)
    end

    if type(availableChoices) ~= "table" then
        local options = config:GetOptions() or {}
        availableChoices = options.Choices
    end

    if type(availableChoices) == "table" and #availableChoices > 0 then
        if table.contains(availableChoices, value) then
            return true
        end

        if dynamicChoicesEnabled and allowStaleDynamicChoice then
            return true
        end

        return false
    end

    if dynamicChoicesEnabled then
        if allowStaleDynamicChoice then
            return true
        end

        return allowEmptyValue and value == ""
    end

    return false
end
