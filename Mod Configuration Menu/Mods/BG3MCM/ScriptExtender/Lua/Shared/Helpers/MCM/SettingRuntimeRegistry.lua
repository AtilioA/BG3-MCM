---@class MCMSettingRuntimeRegistry
MCMSettingRuntimeRegistry = {
    RuntimeChoices = {},
    CustomValidators = {},
}

local function getModBucket(storage, modUUID, shouldCreate)
    if not modUUID then
        return nil
    end

    if not storage[modUUID] and shouldCreate then
        storage[modUUID] = {}
    end

    return storage[modUUID]
end

local function cloneArray(values)
    local cloned = {}
    for i, value in ipairs(values or {}) do
        cloned[i] = value
    end
    return cloned
end

---@param choices any
---@return boolean
local function isValidChoicesArray(choices)
    if type(choices) ~= "table" or not table.isArray(choices) then
        return false
    end

    for _, choice in ipairs(choices) do
        if type(choice) ~= "string" then
            return false
        end
    end

    return true
end

---@param setting BlueprintSetting
---@return boolean
function MCMSettingRuntimeRegistry:IsDynamicChoicesEnabled(setting)
    local options = setting and setting:GetOptions() or {}
    return options and options.DynamicChoices == true
end

---@param setting BlueprintSetting
---@return boolean
function MCMSettingRuntimeRegistry:AllowEmptyValue(setting)
    local options = setting and setting:GetOptions() or {}
    return options and options.AllowEmptyValue == true
end

---@param modUUID string
---@param settingId string
---@param choices string[]
---@return boolean
function MCMSettingRuntimeRegistry:SetChoices(modUUID, settingId, choices)
    if not modUUID or not settingId then
        MCMWarn(0, "modUUID and settingId are required to set runtime choices.")
        return false
    end

    if not isValidChoicesArray(choices) then
        MCMWarn(0, "Runtime choices for setting '" .. tostring(settingId) .. "' must be an array of strings.")
        return false
    end

    local modChoices = getModBucket(self.RuntimeChoices, modUUID, true)
    modChoices[settingId] = cloneArray(choices)
    return true
end

---@param modUUID string
---@param settingId string
---@return string[]|nil
function MCMSettingRuntimeRegistry:GetChoices(modUUID, settingId)
    local modChoices = getModBucket(self.RuntimeChoices, modUUID, false)
    if not modChoices then
        return nil
    end

    local choices = modChoices[settingId]
    if choices == nil then
        return nil
    end

    return cloneArray(choices)
end

---@param modUUID string
---@param settingId string
---@return boolean
function MCMSettingRuntimeRegistry:ResetChoices(modUUID, settingId)
    local modChoices = getModBucket(self.RuntimeChoices, modUUID, false)
    if not modChoices or modChoices[settingId] == nil then
        return false
    end

    modChoices[settingId] = nil
    return true
end

---@param setting BlueprintSetting
---@param modUUID string
---@return string[]|nil effectiveChoices
---@return boolean hasRuntimeOverride
function MCMSettingRuntimeRegistry:GetEffectiveChoices(setting, modUUID)
    local runtimeChoices = self:GetChoices(modUUID, setting:GetId())
    if runtimeChoices ~= nil then
        return runtimeChoices, true
    end

    local options = setting:GetOptions() or {}
    if type(options.Choices) ~= "table" then
        return nil, false
    end

    return options.Choices, false
end

---@param modUUID string
---@param settingId string
---@param callback function
---@return boolean
function MCMSettingRuntimeRegistry:RegisterValidator(modUUID, settingId, callback)
    if not modUUID or not settingId then
        MCMWarn(0, "modUUID and settingId are required to register a custom validator.")
        return false
    end

    if type(callback) ~= "function" then
        MCMWarn(0, "Custom validator for setting '" .. tostring(settingId) .. "' must be a function.")
        return false
    end

    local modValidators = getModBucket(self.CustomValidators, modUUID, true)

    if modValidators[settingId] ~= nil then
        if modValidators[settingId] == callback then
            return true
        end

        MCMWarn(0,
            "A custom validator is already registered for setting '" ..
            tostring(settingId) ..
            "'. Unregister it first before registering a different validator.")
        return false
    end

    modValidators[settingId] = callback
    return true
end

---@param modUUID string
---@param settingId string
---@return boolean
function MCMSettingRuntimeRegistry:UnregisterValidator(modUUID, settingId)
    local modValidators = getModBucket(self.CustomValidators, modUUID, false)
    if not modValidators or modValidators[settingId] == nil then
        return false
    end

    modValidators[settingId] = nil
    return true
end

---@param modUUID string
---@param settingId string
---@return function|nil
function MCMSettingRuntimeRegistry:GetValidator(modUUID, settingId)
    local modValidators = getModBucket(self.CustomValidators, modUUID, false)
    if not modValidators then
        return nil
    end

    return modValidators[settingId]
end

---@param modUUID string
---@param setting BlueprintSetting
---@param value any
---@return boolean
function MCMSettingRuntimeRegistry:ValidateWithCustomValidator(modUUID, setting, value)
    if not modUUID or not setting then
        return true
    end

    local validator = self:GetValidator(modUUID, setting:GetId())
    if not validator then
        return true
    end

    local callbackOk, isValid, message = self:EvaluateValidatorCallback(validator, value, setting, modUUID)
    if not callbackOk then
        MCMWarn(0,
            "Custom validator for setting '" .. setting:GetId() .. "' failed: " .. tostring(message))
        return false
    end

    if not isValid then
        local reason = message and tostring(message) or "Validation callback returned false."
        MCMWarn(0,
            "Custom validator rejected value for setting '" .. setting:GetId() .. "': " .. reason)
        return false
    end

    return true
end

---@param callback function
---@param value any
---@param setting BlueprintSetting
---@param modUUID string
---@return boolean callbackOk
---@return boolean isValid
---@return string? message
function MCMSettingRuntimeRegistry:EvaluateValidatorCallback(callback, value, setting, modUUID)
    if type(callback) ~= "function" then
        return false, false, "Validator callback must be a function."
    end

    local ok, isValid, message = pcall(callback, value, setting, modUUID)
    if not ok then
        return false, false, "Validator callback threw an error: " .. tostring(isValid)
    end

    if type(isValid) ~= "boolean" then
        return false, false, "Validator callback must return a boolean as the first return value."
    end

    if message ~= nil and type(message) ~= "string" then
        message = tostring(message)
    end

    return true, isValid, message
end

return MCMSettingRuntimeRegistry
