--- TODO: add exception handling

---@class HelperBlueprintPreprocessing
BlueprintPreprocessing = _Class:Create("HelperBlueprintPreprocessing", nil)
-- The UUID of the mod being currently processed
BlueprintPreprocessing.currentmodUUID = nil

--- Builds the standard contact-the-author sentence appended to validation warnings.
---@param self HelperBlueprintPreprocessing The preprocessing instance
---@return string
local function contactAuthor(self)
    return "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue."
end

--- TODO: clean this up, but currently better than nothing
--- Checks if all elements in the blueprint have valid IDs
---@param blueprint Blueprint The blueprint data
---@return boolean True if all elements have valid IDs, false otherwise
function BlueprintPreprocessing:CheckValidIDs(blueprint)
    local function hasValidID(element)
        if not element.GetId then
            return true
        end

        return element:GetId() and element:GetId() ~= ""
    end

    local isValid = true

    BlueprintShape:ForEachElement(blueprint, function(element)
        if not hasValidID(element) then
            isValid = false
            MCMWarn(0,
                "Missing ID in element: " .. (element and element.GetLocaName and element:GetLocaName() or "Unknown"))
        end
    end)

    return isValid
end

--- Validate the structure of the blueprint data
---@param blueprint Blueprint The blueprint data to validate
---@return boolean True if the blueprint data is correct, false otherwise
function BlueprintPreprocessing:HasIncorrectStructure(blueprint)
    --- Check if blueprint has at least one tab
    local hasTabs = blueprint:GetTabs() and #blueprint:GetTabs() > 0

    --- Check if blueprint has at least one setting
    local hasSettings = blueprint:GetSettings() and #blueprint:GetSettings() > 0

    --- Check if blueprint does NOT have both tabs and settings
    if hasTabs and hasSettings then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "' has both tabs and settings. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    end

    if not self:CheckValidIDs(blueprint) then
        MCMWarn(0,
            "Missing IDs in blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    end

    if not self:ValidateTabStructure(blueprint:GetTabs()) then
        return true
    end

    for _, section in ipairs(BlueprintShape:GetSections(blueprint)) do
        if not self:ValidateTabStructure(BlueprintShape:GetTabs(section)) then
            return true
        end
    end

    return false
end

---@param tabs BlueprintTab[]|nil
---@return boolean
function BlueprintPreprocessing:ValidateTabStructure(tabs)
    if tabs == nil then
        return true
    end

    for _, tab in ipairs(tabs) do
        if tab:GetTabName() == nil or tab:GetTabName() == "" then
            MCMWarn(0,
                "Tab '" .. tostring(tab:GetId()) .. "' in mod '" ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                "' is missing a tab name. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end

        local nestedTabs = BlueprintShape:GetTabs(tab)

        if not self:ValidateTabStructure(nestedTabs) then
            return false
        end

        for _, section in ipairs(BlueprintShape:GetSections(tab)) do
            if not self:ValidateTabStructure(BlueprintShape:GetTabs(section)) then
                return false
            end
        end
    end

    return true
end

--- Verify that all tabs in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifyTabIDUniqueness(blueprint)
    local tabIDs = {}

    local isValid = true
    BlueprintShape:ForEachTab(blueprint, function(tab)
        if tabIDs[tab:GetId()] then
            MCMWarn(0,
                "Duplicate tab ID found in blueprint for mod '" ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
            return
        end
        tabIDs[tab:GetId()] = true
    end)

    return isValid
end

--- Verify that all sections in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifySectionIDUniqueness(blueprint)
    local sectionIDs = {}
    local isValid = true

    BlueprintShape:ForEachSection(blueprint, function(section)
        if sectionIDs[section:GetId()] then
            MCMWarn(0,
                "Duplicate section ID found in blueprint for mod '" ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
            return
        end
        sectionIDs[section:GetId()] = true
    end)

    return isValid
end

--- Verify that all setting IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifySettingIDUniqueness(blueprint)
    local settingIDs = {}
    local isValid = true

    BlueprintShape:ForEachSetting(blueprint, function(setting)
        if setting == nil then
            return
        end

        if settingIDs[setting:GetId()] then
            MCMWarn(0,
                "Duplicate setting ID '%s' found in blueprint for mod '%s'. Please contact %s about this issue.",
                setting:GetId(),
                Ext.Mod.GetMod(self.currentmodUUID).Info.Name,
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author)
            isValid = false
            return
        end
        settingIDs[setting:GetId()] = true
    end)

    return isValid
end

--- Verify that no setting shares an ID with a sibling section or tab, because both would use the same key in the settings file
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifySettingKeyUniqueness(blueprint)
    local isValid = true

    BlueprintShape:ForEachElement(blueprint, function(element, elementType)
        if elementType == "setting" then
            return
        end

        local containerIDs = {}
        for _, section in ipairs(BlueprintShape:GetSections(element)) do
            containerIDs[section:GetId()] = true
        end
        for _, tab in ipairs(BlueprintShape:GetTabs(element)) do
            containerIDs[tab:GetId()] = true
        end

        for _, setting in ipairs(BlueprintShape:GetSettings(element)) do
            if containerIDs[setting:GetId()] then
                MCMWarn(0,
                    "Setting ID '%s' matches a sibling section or tab ID in blueprint for mod '%s'. Please contact %s about this issue.",
                    setting:GetId(),
                    Ext.Mod.GetMod(self.currentmodUUID).Info.Name,
                    Ext.Mod.GetMod(self.currentmodUUID).Info.Author)
                isValid = false
            end
        end
    end)

    return isValid
end

--- Verify all IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifyIDUniqueness(blueprint)
    return self:VerifyTabIDUniqueness(blueprint) and
        self:VerifySectionIDUniqueness(blueprint) and
        self:VerifySettingIDUniqueness(blueprint) and
        self:VerifySettingKeyUniqueness(blueprint)
end

-- REFACTOR: this is way uglier and repetitive than it needs to be. Especially since we have validation functions for each type already. However, I'm too tired to refactor this. It is just validation, it is kinda fine.
--- Validate the setting data in the blueprint (e.g.: ensure that all IDs are unique, default values are valid, etc.)
---@param blueprint Blueprint The blueprint data to validate
function BlueprintPreprocessing:ValidateBlueprintSettings(blueprint)
    local isValid = true

    if BlueprintShape:HasAnySettings(blueprint) then
        BlueprintShape:ForEachSetting(blueprint, function(setting)
            if not isValid then
                return
            end

            if not self:BlueprintCheckDefaultType(setting) then
                isValid = false
                return
            end

            local settingType = setting:GetType()
            if settingType == "enum" then
                if not self:ValidateEnumSetting(setting) then
                    isValid = false
                    return
                end
            elseif settingType == "radio" then
                if not self:ValidateRadioSetting(setting) then
                    isValid = false
                    return
                end
            elseif self:IsSliderSetting(settingType) then
                if not self:ValidateSliderSetting(setting) then
                    isValid = false
                    return
                end
            elseif settingType == "keybinding_v2" then
                if not self:ValidateKeybindingV2Setting(setting) then
                    isValid = false
                    return
                end
            elseif settingType == "event_button" then
                if not self:ValidateEventButtonSetting(setting) then
                    isValid = false
                    return
                end
            elseif settingType == "checkbox" then
                if not self:ValidateCheckboxSetting(setting) then
                    isValid = false
                    return
                end
            end

            -- Validate VisibleIf for the setting
            if not self:ValidateVisibleIf(setting:GetVisibleIf(), blueprint, "Setting", setting:GetId()) then
                isValid = false
            end
        end)
    end

    if not isValid then
        return false
    end

    -- Validate VisibleIf for tabs
    if not self:ValidateTabsVisibleIf(blueprint) then
        return false
    end

    return isValid
end

function BlueprintPreprocessing:ValidateCheckboxSetting(setting)
    local opts = setting:GetOptions() or {}
    if opts["InlineTitle"] ~= nil and type(opts["InlineTitle"]) ~= "boolean" then
        MCMWarn(0,
            "Checkbox setting '" ..
            setting:GetId() ..
            "' has Options.InlineTitle of type '" ..
            type(opts["InlineTitle"]) .. "'. It must be a boolean (true/false) if present.")
    end
    return true
end

function BlueprintPreprocessing:ValidateEnumSetting(setting)
    if not self:BlueprintShouldHaveOptionsForEnum(setting) then
        return false
    end

    if not self:BlueprintDynamicFlagForEnumShouldBeBoolean(setting) then
        return false
    end

    if not self:BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings(setting) then
        return false
    end

    return true
end

function BlueprintPreprocessing:ValidateRadioSetting(setting)
    if not self:BlueprintShouldHaveOptionsForRadio(setting) then
        return false
    end

    if not self:BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings(setting) then
        return false
    end

    return true
end

function BlueprintPreprocessing:IsSliderSetting(settingType)
    return settingType == "slider_int" or settingType == "slider_float" or settingType == "drag_float" or
        settingType == "drag_int"
end

function BlueprintPreprocessing:ValidateSliderSetting(setting)
    if not self:BlueprintShouldHaveMinAndMaxForSlider(setting) then
        return false
    end

    if not self:BlueprintMinAndMaxForSliderShouldBeNumbers(setting) then
        return false
    end

    if not self:BlueprintMinIsLessThanMaxForSlider(setting) then
        return false
    end

    if not self:BlueprintDefaultShouldBeWithinRange(setting) then
        return false
    end

    if not self:BlueprintStepShouldBeNonZeroNumber(setting) then
        return false
    end

    -- Set default Step values if not provided
    self:SetDefaultStepForSlider(setting)

    return true
end

--- Sets default Step value for slider settings if not provided
---@param setting BlueprintSetting The setting to set default Step for
function BlueprintPreprocessing:SetDefaultStepForSlider(setting)
    local opts = setting:GetOptions()
    if not opts then
        return
    end

    -- Only set default if Step is not already defined
    if opts.Step == nil then
        local settingType = setting:GetType()
        if settingType == "slider_int" or settingType == "drag_int" then
            opts.Step = 1
        elseif settingType == "slider_float" or settingType == "drag_float" then
            opts.Step = 0.1
        end
    end
end

--- Validates the options for an event_button setting
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the setting is valid, false otherwise
function BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    local options = setting:GetOptions() or {}
    local isValid = true
    local settingId = setting:GetId()

    if options.Cooldown ~= nil and type(options.Cooldown) ~= "number" then
        MCMWarn(0, "Options.Cooldown for event_button setting '" .. settingId ..
            "' must be a number. " .. contactAuthor(self))
        isValid = false
    end

    if options.Icon ~= nil then
        if type(options.Icon) ~= "table" then
            MCMWarn(0, "Options.Icon for event_button setting '" .. settingId ..
                "' must be an object with a Name field. " .. contactAuthor(self))
            isValid = false
        else
            if type(options.Icon.Name) ~= "string" or options.Icon.Name == "" then
                MCMWarn(0, "Options.Icon.Name for event_button setting '" .. settingId ..
                    "' must be a non-empty string. " .. contactAuthor(self))
                isValid = false
            end
            if options.Icon.Size ~= nil then
                if type(options.Icon.Size) ~= "table"
                    or type(options.Icon.Size.Width) ~= "number"
                    or type(options.Icon.Size.Height) ~= "number" then
                    MCMWarn(0, "Options.Icon.Size for event_button setting '" .. settingId ..
                        "' must be a table with numeric Width and Height fields. " .. contactAuthor(self))
                    isValid = false
                end
            end
        end
    end

    if options.Label ~= nil then
        if type(options.Label) ~= "string" or options.Label == "" then
            MCMWarn(0, "Options.Label for event_button setting '" .. settingId ..
                "' must be a non-empty string. " .. contactAuthor(self))
            isValid = false
        end
    end

    if options.ConfirmDialog ~= nil then
        if type(options.ConfirmDialog) ~= "table" then
            MCMWarn(0, "Options.ConfirmDialog for event_button setting '" .. settingId ..
                "' must be a table. " .. contactAuthor(self))
            isValid = false
        else
            local dialog = options.ConfirmDialog
            for _, field in ipairs({ "Title", "Message", "ConfirmText", "CancelText" }) do
                if dialog[field] == nil then
                    MCMWarn(0, string.format(
                        "Missing required field 'Options.ConfirmDialog.%s' for event_button setting '%s'. ",
                        field, settingId) .. contactAuthor(self))
                    return false
                end
            end

            local validFieldTypes = {
                Title = "string",
                Message = "string",
                ConfirmText = "string",
                CancelText = "string"
            }
            for field, expectedType in pairs(validFieldTypes) do
                if dialog[field] ~= nil and type(dialog[field]) ~= expectedType then
                    MCMWarn(0, string.format(
                        "Options.ConfirmDialog.%s for event_button setting '%s' must be a %s. ",
                        field, settingId, expectedType) .. contactAuthor(self))
                    isValid = false
                end
            end
        end
    end

    return isValid
end

local KeybindingBooleanOptions = {
    "ShouldTriggerOnRepeat",
    "IsDeveloperOnly",
    "ShouldTriggerOnKeyUp",
    "ShouldTriggerOnKeyDown",
    "BlockIfLevelNotStarted",
    "PreventAction",
    "SkipCallback",
    "AllowConflict",
}

---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param setting BlueprintSetting The setting to validate
---@param options table The setting options
---@param optionKey string The option name to check
---@return boolean True if the option is absent or a boolean
local function validateKeybindingBooleanOption(self, setting, options, optionKey)
    if options[optionKey] ~= nil and type(options[optionKey]) ~= "boolean" then
        MCMWarn(0, "Options." .. optionKey .. " for keybinding_v2 setting '" .. setting:GetId() ..
            "' must be a boolean. " .. contactAuthor(self))
        return false
    end

    return true
end

---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the setting default is valid
local function validateKeybindingV2Default(self, setting)
    local default = setting.Default
    if not default or type(default) ~= "table" then
        return true
    end

    local hasKeyboard = default.Keyboard and type(default.Keyboard) == "table" and
        default.Keyboard.Key and default.Keyboard.Key ~= ""
    if hasKeyboard and KeybindingManager:IsMouseBindingAssigned(default.Mouse) then
        MCMWarn(0, "Keybinding_v2 setting '" .. setting:GetId() ..
            "' cannot have both Keyboard and Mouse defaults. Use one or the other. " .. contactAuthor(self))
        return false
    end

    if default.Mouse then
        if type(default.Mouse) ~= "table" then
            MCMWarn(0, "Default.Mouse for keybinding_v2 setting '" .. setting:GetId() ..
                "' must be a table. " .. contactAuthor(self))
            return false
        end

        if default.Mouse.Button == nil or type(default.Mouse.Button) ~= "number" then
            MCMWarn(0, "Default.Mouse.Button for keybinding_v2 setting '" .. setting:GetId() ..
                "' must be a number. " .. contactAuthor(self))
            return false
        end

        if default.Mouse.Button ~= math.floor(default.Mouse.Button) then
            MCMWarn(0, "Default.Mouse.Button for keybinding_v2 setting '" .. setting:GetId() ..
                "' must be an integer. " .. contactAuthor(self))
            return false
        end

        if default.Mouse.Button < KeybindingManager.MOUSE_BUTTON_MIN
            or default.Mouse.Button > KeybindingManager.MOUSE_BUTTON_MAX then
            MCMWarn(0, "Default.Mouse.Button for keybinding_v2 setting '" .. setting:GetId() ..
                "' must be between 1 and " .. KeybindingManager.MOUSE_BUTTON_MAX .. ". " .. contactAuthor(self))
            return false
        end

        if default.Mouse.ModifierKeys ~= nil and type(default.Mouse.ModifierKeys) ~= "table" then
            MCMWarn(0, "Default.Mouse.ModifierKeys for keybinding_v2 setting '" .. setting:GetId() ..
                "' must be a table. " .. contactAuthor(self))
            return false
        end

        local normalizedModifiers, invalidModifier =
            KeybindingManager:AdaptModifierKeys(default.Mouse.ModifierKeys)
        if not normalizedModifiers then
            MCMWarn(0, "Invalid modifier '" .. tostring(invalidModifier) ..
                "' in Default.Mouse.ModifierKeys for keybinding_v2 setting '" .. setting:GetId() ..
                "'. Valid modifiers are: " .. table.concat(KeybindingManager.SUPPORTED_MODIFIERS, ", ") ..
                ". " .. contactAuthor(self))
            return false
        end
        default.Mouse.ModifierKeys = normalizedModifiers
    end

    return true
end

--- Validates a keybinding_v2 setting
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the setting is valid, false otherwise
function BlueprintPreprocessing:ValidateKeybindingV2Setting(setting)
    local options = setting:GetOptions() or {}

    for _, optionKey in ipairs(KeybindingBooleanOptions) do
        if not validateKeybindingBooleanOption(self, setting, options, optionKey) then
            return false
        end
    end

    return validateKeybindingV2Default(self, setting)
end

--- Validates VisibleIf conditions for all tabs and their nested sections
---@param blueprint Blueprint The blueprint data
---@return boolean True if all VisibleIf conditions are valid, false otherwise
function BlueprintPreprocessing:ValidateTabsVisibleIf(blueprint)
    local isValid = true

    BlueprintShape:ForEachTab(blueprint, function(tab)
        if not self:ValidateVisibleIf(tab:GetVisibleIf(), blueprint, "Tab", tab:GetId()) then
            isValid = false
        end
    end)

    BlueprintShape:ForEachSection(blueprint, function(section)
        if not self:ValidateVisibleIf(section:GetVisibleIf(), blueprint, "Section", section:GetId()) then
            isValid = false
        end
    end)

    return isValid
end

local VisibleIfAllowedGroupKeys = {
    LogicalOperator = true,
    Conditions = true,
}

local VisibleIfAllowedConditionKeys = {
    SettingId = true,
    Operator = true,
    ExpectedValue = true,
}

local VisibleIfAllowedOperators = {
    ["=="] = true,
    ["!="] = true,
    [">"] = true,
    ["<"] = true,
    [">="] = true,
    ["<="] = true,
}

---@param value table
---@param allowed table<string, boolean>
---@return boolean, string|nil
local function hasOnlyAllowedKeys(value, allowed)
    for key, _ in pairs(value) do
        if type(key) ~= "string" or not allowed[key] then
            return false, tostring(key)
        end
    end

    return true, nil
end

---@param condition table
---@return string
local function buildVisibleIfConditionSignature(condition)
    local expectedValueType = type(condition.ExpectedValue)
    local expectedValue = tostring(condition.ExpectedValue)
    return condition.SettingId .. "|" .. condition.Operator .. "|" .. expectedValueType .. "|" .. expectedValue
end

--- Validates a VisibleIf condition group
---@param visibleIf table|nil The VisibleIf condition group to validate
---@param blueprint Blueprint The blueprint data for reference
---@param elementType string The type of element ("Setting", "Tab", "Section")
---@param elementId string The ID of the element being validated
---@return boolean True if the VisibleIf is valid or nil, false otherwise
--- Validates the Conditions array of a VisibleIf group.
---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param visibleIf table The VisibleIf group to validate
---@param blueprint Blueprint The blueprint data for reference
---@param elementType string The type of element ("Setting", "Tab", "Section")
---@param elementId string The ID of the element being validated
---@return boolean True if the Conditions array is valid
local function validateVisibleIfConditions(self, visibleIf, blueprint, elementType, elementId)
    if not visibleIf.Conditions then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has VisibleIf without Conditions array. " ..
            contactAuthor(self))
        return false
    end

    if type(visibleIf.Conditions) ~= "table" then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has invalid VisibleIf.Conditions (not an array). " ..
            contactAuthor(self))
        return false
    end

    if #visibleIf.Conditions == 0 then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has empty VisibleIf.Conditions array. " ..
            contactAuthor(self))
        return false
    end

    local conditionCount = 0
    for key, _ in pairs(visibleIf.Conditions) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            MCMWarn(0, elementType .. " '" .. elementId ..
                "' has invalid VisibleIf.Conditions (not an array). " .. contactAuthor(self))
            return false
        end
        conditionCount = conditionCount + 1
    end

    if conditionCount ~= #visibleIf.Conditions then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has invalid VisibleIf.Conditions (sparse array). " ..
            contactAuthor(self))
        return false
    end

    local conditionSignatures = {}
    for i, condition in ipairs(visibleIf.Conditions) do
        if not self:ValidateVisibilityCondition(condition, blueprint, elementType, elementId, i) then
            return false
        end

        local conditionSignature = buildVisibleIfConditionSignature(condition)
        if conditionSignatures[conditionSignature] then
            MCMWarn(0, elementType .. " '" .. elementId .. "' has duplicate condition #" .. i ..
                " in VisibleIf.Conditions. " .. contactAuthor(self))
            return false
        end

        conditionSignatures[conditionSignature] = true
    end

    return true
end

--- Validates a VisibleIf condition group
---@param visibleIf table|nil The VisibleIf condition group to validate
---@param blueprint Blueprint The blueprint data for reference
---@param elementType string The type of element ("Setting", "Tab", "Section")
---@param elementId string The ID of the element being validated
---@return boolean True if the VisibleIf is valid or nil, false otherwise
function BlueprintPreprocessing:ValidateVisibleIf(visibleIf, blueprint, elementType, elementId)
    -- VisibleIf is optional; empty string is used as the internal "not set" default
    if visibleIf == nil or visibleIf == "" then
        return true
    end

    if type(visibleIf) ~= "table" then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has invalid VisibleIf (not a table). " ..
            contactAuthor(self))
        return false
    end

    local onlyAllowedGroupKeys, invalidGroupKey = hasOnlyAllowedKeys(visibleIf, VisibleIfAllowedGroupKeys)
    if not onlyAllowedGroupKeys then
        MCMWarn(0, elementType .. " '" .. elementId .. "' has invalid VisibleIf field '" .. invalidGroupKey ..
            "'. Only 'LogicalOperator' and 'Conditions' are allowed. " .. contactAuthor(self))
        return false
    end

    if visibleIf.LogicalOperator ~= nil then
        if type(visibleIf.LogicalOperator) ~= "string" then
            MCMWarn(0, elementType .. " '" .. elementId ..
                "' has invalid VisibleIf.LogicalOperator (not a string). " .. contactAuthor(self))
            return false
        end
        if visibleIf.LogicalOperator ~= "and" and visibleIf.LogicalOperator ~= "or" then
            MCMWarn(0, elementType .. " '" .. elementId .. "' has invalid VisibleIf.LogicalOperator ('" ..
                visibleIf.LogicalOperator .. "'). Must be 'and' or 'or'. " .. contactAuthor(self))
            return false
        end
    end

    return validateVisibleIfConditions(self, visibleIf, blueprint, elementType, elementId)
end

--- Validates a single visibility condition
---@param condition table The condition to validate
---@param blueprint Blueprint The blueprint data for reference
---@param elementType string The type of element ("Setting", "Tab", "Section")
---@param elementId string The ID of the element being validated
---@param conditionIndex number The index of the condition in the array
---@return boolean True if the condition is valid, false otherwise
function BlueprintPreprocessing:ValidateVisibilityCondition(condition, blueprint, elementType, elementId, conditionIndex)
    if type(condition) ~= "table" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has invalid condition #" .. conditionIndex ..
            " in VisibleIf.Conditions (not a table). " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    local onlyAllowedConditionKeys, invalidConditionKey = hasOnlyAllowedKeys(condition, VisibleIfAllowedConditionKeys)
    if not onlyAllowedConditionKeys then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " with invalid field '" .. invalidConditionKey .. "'. " ..
            "Only 'SettingId', 'Operator', and 'ExpectedValue' are allowed. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate SettingId
    if not condition.SettingId then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " missing SettingId. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if type(condition.SettingId) ~= "string" or condition.SettingId == "" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " with invalid SettingId (not a non-empty string). " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate that the referenced setting exists
    local settingExists = BlueprintShape:IsSettingId(blueprint, condition.SettingId)

    if not settingExists then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " referencing non-existent SettingId '" .. condition.SettingId .. "'. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate Operator
    if not condition.Operator then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " missing Operator. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if type(condition.Operator) ~= "string" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " with invalid Operator (not a string). " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if not VisibleIfAllowedOperators[condition.Operator] then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " with invalid Operator '" .. condition.Operator .. "'. " ..
            "Must be one of: ==, !=, >, <, >=, <=. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate ExpectedValue
    if condition.ExpectedValue == nil then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " missing ExpectedValue. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- According to schema, ExpectedValue must be string, boolean, or number
    local expectedValueType = type(condition.ExpectedValue)
    if expectedValueType ~= "string" and expectedValueType ~= "boolean" and expectedValueType ~= "number" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf condition #" .. conditionIndex ..
            " with invalid ExpectedValue type ('" .. expectedValueType .. "'). " ..
            "Must be string, boolean, or number. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

--- Emits the standard wrong-default-type warning.
---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param setting BlueprintSetting The setting to validate
---@param expected string The expected type phrase, such as "a boolean"
---@return boolean Always false
local function warnDefaultType(self, setting, expected)
    MCMWarn(0, "Default value for setting '" .. setting:GetId() .. "' must be " .. expected .. ". " ..
        contactAuthor(self))
    return false
end

---@param value unknown
---@return boolean
local function isInteger(value)
    return type(value) == "number" and math.floor(value) == value
end

---@param value unknown
---@return boolean
local function isColorArray(value)
    return type(value) == "table" and #value == 4
        and type(value[1]) == "number" and type(value[2]) == "number"
        and type(value[3]) == "number" and type(value[4]) == "number"
end

--- Validates the default of a keybinding_v2 setting.
---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the default is valid
local function validateKeybindingV2DefaultValue(self, setting)
    local default = setting.Default
    if type(default) ~= "table" then
        return true
    end

    if default.Enabled ~= nil and type(default.Enabled) ~= "boolean" then
        MCMWarn(0, "Default value for 'enabled' in keybinding_v2 setting '" .. setting:GetId() ..
            "' must be a boolean. " .. contactAuthor(self))
        return false
    end

    local hasKeyboard = default.Keyboard ~= nil and type(default.Keyboard) == "table"
    local hasMouse = default.Mouse ~= nil and type(default.Mouse) == "table"
    if not hasKeyboard and not hasMouse then
        MCMWarn(0, "Default value for setting '" .. setting:GetId() ..
            "' must contain either a 'Keyboard' or 'Mouse' table. " .. contactAuthor(self))
        return false
    end

    if not hasKeyboard then
        return true
    end

    local keyboard = default.Keyboard
    local key = keyboard.Key
    if type(key) ~= "string" or (key ~= "" and not table.contains(SDLKeys.ScanCodes, key)) then
        MCMWarn(0, "Invalid key '" .. key .. "' in Keyboard.Key for setting '" .. setting:GetId() ..
            "'. Valid keys are: " .. table.concat(SDLKeys.ScanCodes, ", "))
        return false
    end

    if keyboard.ModifierKeys ~= nil and type(keyboard.ModifierKeys) ~= "table" then
        MCMWarn(0, "Keyboard.ModifierKeys must be a table. " .. contactAuthor(self))
        return false
    end

    local normalizedModifiers, invalidModifier = KeybindingManager:AdaptModifierKeys(keyboard.ModifierKeys)
    if not normalizedModifiers then
        MCMWarn(0, "Invalid modifier '" .. tostring(invalidModifier) ..
            "' in Keyboard.ModifierKeys for setting '" .. setting:GetId() ..
            "'. Valid modifiers are: " .. table.concat(KeybindingManager.SUPPORTED_MODIFIERS, ", "))
        return false
    end
    keyboard.ModifierKeys = normalizedModifiers

    return true
end

--- Validates the default of a list_v2 setting and normalizes its field names.
---@param self HelperBlueprintPreprocessing The preprocessing instance
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the default is valid
local function validateListV2DefaultValue(self, setting)
    local default = setting.Default
    if type(default) == "table" then
        if default.elements == nil then
            default.elements = default.Elements
        end
        if default.enabled == nil then
            default.enabled = default.Enabled
        end
        default.Elements = nil
        default.Enabled = nil
    end

    local enabled = type(default) == "table" and default.enabled
    -- SanitizeBlueprint converts "true"/"false" after validation; accept only those strings here.
    if type(default) ~= "table" or type(default.elements) ~= "table"
        or (type(enabled) ~= "boolean" and enabled ~= "true" and enabled ~= "false") then
        MCMWarn(0, "Default value for setting '" .. setting:GetId() ..
            "' must be a table with boolean 'Enabled' and table 'Elements'. " .. contactAuthor(self))
        return false
    end

    for _, element in ipairs(default.elements) do
        if type(element) ~= "table" or not element.name or type(element.name) ~= "string" or element.name == "" then
            MCMWarn(0, "Element " .. Ext.DumpExport(element) .. " for setting '" .. setting:GetId() ..
                "' must be a table with 'name' as a non-empty string and 'enabled' as a boolean.")
            return false
        end
        if element.enabled ~= nil and type(element.enabled) ~= "boolean" then
            MCMWarn(0, "Element " .. Ext.DumpExport(element) .. " for setting '" .. setting:GetId() ..
                "' must be a table with 'name' as a non-empty string and 'enabled' as a boolean.")
            return false
        end
        if element.enabled == nil then
            element.enabled = true
        end
    end

    return true
end

--- Checks that a setting default matches the setting type.
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the default is valid
function BlueprintPreprocessing:BlueprintCheckDefaultType(setting)
    if setting.Type == "event_button" then
        return true
    end

    if setting.Default == nil then
        MCMWarn(0, "Setting '" .. setting:GetId() .. "' is missing a 'Default' value. " .. contactAuthor(self))
        return false
    end

    local default = setting.Default
    local settingType = setting.Type

    -- REFACTOR: Replace this long if-elseif chain
    if settingType == "bool" or settingType == "checkbox" then
        if type(default) ~= "boolean" then return warnDefaultType(self, setting, "a boolean") end
    elseif settingType == "int" or settingType == "slider_int" or settingType == "drag_int" then
        if not isInteger(default) then return warnDefaultType(self, setting, "an integer") end
    elseif settingType == "float" or settingType == "slider_float" or settingType == "drag_float" then
        if type(default) ~= "number" then return warnDefaultType(self, setting, "a number") end
    elseif settingType == "text" or settingType == "enum" or settingType == "radio" then
        if type(default) ~= "string" then return warnDefaultType(self, setting, "a string") end
    elseif settingType == "color_picker" or settingType == "color_edit" then
        if not isColorArray(default) then return warnDefaultType(self, setting, "a table of 4 numbers") end
    elseif settingType == "keybinding_v2" then
        return validateKeybindingV2DefaultValue(self, setting)
    elseif settingType == "list_v2" then
        return validateListV2DefaultValue(self, setting)
    end

    return true
end

function BlueprintPreprocessing:BlueprintDefaultShouldBeWithinRange(setting)
    if setting.Options and setting.Options.Min and setting.Options.Max then
        if setting.Default < setting.Options.Min or setting.Default > setting.Options.Max then
            MCMWarn(0,
                "Default value for setting '" ..
                setting:GetId() ..
                "' must be within the range of 'Options.Min' and 'Options.Max'. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    end
    return true
end

function BlueprintPreprocessing:BlueprintStepShouldBeNonZeroNumber(setting)
    if setting.Options and setting.Options.Step and (type(setting.Options.Step) ~= "number" or setting.Options.Step == 0) then
        MCMWarn(0,
            "Step value for setting '" ..
            setting:GetId() ..
            "' must be a non-zero number. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveOptionsForEnum(setting)
    if not setting.Options or not setting.Options.Choices then
        MCMWarn(0,
            "Enum setting '" ..
            setting:GetId() ..
            "' must have 'Options.Choices' defined. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if #setting.Options.Choices == 0 then
        if setting.Options.Dynamic ~= true then
            MCMWarn(0,
                "Enum setting '" ..
                setting:GetId() ..
                "' has an empty Choices array but Options.Dynamic is not set to true. " ..
                "If choices will be injected at runtime via MCM.Enum.SetChoices, set Options.Dynamic = true.")
        end
        return true
    end

    if setting.Options.Dynamic == true then
        return true
    end

    if not table.contains(setting.Options.Choices, setting.Default) then
        MCMWarn(0,
            "Enum setting '" ..
            setting:GetId() ..
            "' must have a 'Default' value that is one of the 'Options.Choices'. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintDynamicFlagForEnumShouldBeBoolean(setting)
    if setting.Options and setting.Options.Dynamic ~= nil and type(setting.Options.Dynamic) ~= "boolean" then
        MCMWarn(0,
            "Options.Dynamic for enum setting '" .. setting:GetId() .. "' must be a boolean.")
        return false
    end

    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveOptionsForRadio(setting)
    if not setting.Options or not setting.Options.Choices or #setting.Options.Choices == 0 then
        MCMWarn(0,
            "Radio setting '" .. setting:GetId() .. "' must have 'Options.Choices' defined.")
        return false
    end

    -- Radio choices are static, so the default must be one of them, as with enum settings.
    if not table.contains(setting.Options.Choices, setting.Default) then
        MCMWarn(0,
            "Radio setting '" .. setting:GetId() ..
            "' must have a 'Default' value that is one of the 'Options.Choices'. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

function BlueprintPreprocessing:BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings(setting)
    if setting.Options and setting.Options.Choices then
        for _, choice in ipairs(setting.Options.Choices) do
            if type(choice) ~= "string" then
                MCMWarn(0,
                    "Options.Choices for enum setting '%s' must be an array of strings.", setting:GetId())
                return false
            end
        end
    end
    return true
end

function BlueprintPreprocessing:BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings(setting)
    if not setting.Options or not setting.Options.Choices then
        MCMWarn(0,
            "Radio setting '%s' must have 'Options.Choices' defined. Please contact %s about this issue.",
            setting:GetId(),
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author)
        return false
    end

    for _, choice in pairs(setting.Options.Choices) do
        if type(choice) ~= "string" then
            MCMWarn(0,
                "Options.Choices for radio setting '%s' must be an array of strings.", setting:GetId())
            return false
        end
    end

    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveMinAndMaxForSlider(setting)
    if not setting.Options or not setting.Options.Min or not setting.Options.Max then
        MCMWarn(0,
            "Slider setting '%s' must have 'Options.Min' and 'Options.Max' defined.", setting:GetId())
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintMinAndMaxForSliderShouldBeNumbers(setting)
    if setting.Options and (type(setting.Options.Min) ~= "number" or type(setting.Options.Max) ~= "number") then
        MCMWarn(0,
            "Slider setting '%s' must have 'Options.Min' and 'Options.Max' defined as numbers.", setting:GetId())
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintMinIsLessThanMaxForSlider(setting)
    if not setting then
        MCMWarn(0, "Slider setting is missing")
        return false
    end

    if not setting.Options then
        MCMWarn(0, "Slider setting '%s' is missing Options", setting:GetId())
        return false
    end

    if not setting.Options.Min or not setting.Options.Max then
        MCMWarn(0, "Slider setting '%s' is missing Options.Min or Options.Max", setting:GetId())
        return false
    end

    if setting.Options.Min >= setting.Options.Max then
        MCMWarn(0, "Slider setting '%s' must have 'Options.Min' less than 'Options.Max'.", setting:GetId())
        return false
    end

    return true
end

--- Sanitizes blueprint data by removing elements without SchemaVersions and converting string booleans
---@param blueprint Blueprint The blueprint data to sanitize
---@param modUUID string The mod's unique identifier
function BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    self.currentmodUUID = modUUID
    if not self:HasSchemaVersionsEntry(blueprint) then
        return
    end

    if self:HasIncorrectStructure(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '%s' has incorrect structure and can't be used. Please contact %s about this issue.",
            Ext.Mod.GetMod(modUUID).Info.Name,
            Ext.Mod.GetMod(modUUID).Info.Author)
        return
    end

    if not self:VerifyIDUniqueness(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '%s' has duplicate IDs and can't be used. Please contact %s about this issue.",
            Ext.Mod.GetMod(modUUID).Info.Name,
            Ext.Mod.GetMod(modUUID).Info.Author)
        return
    end

    if not self:ValidateBlueprintSettings(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '%s' has invalid settings and can't be used. Please contact %s about this issue.",
            Ext.Mod.GetMod(modUUID).Info.Name,
            Ext.Mod.GetMod(modUUID).Info.Author)
        return
    end

    table.convertStringBooleans(blueprint)
    return blueprint
end

--- Sanitize all blueprints for a given set of mods
---@param mods table<string, table> The mods data to sanitize
function BlueprintPreprocessing:SanitizeBlueprints(mods)
    for modUUID, mcmTable in pairs(mods) do
        if not self:SanitizeBlueprint(mcmTable.blueprint, modUUID) then
            mods[modUUID] = nil
            MCMWarn(0,
                "Blueprint validation failed for mod: %s. Please contact %s about this issue.",
                Ext.Mod.GetMod(modUUID).Info.Name,
                Ext.Mod.GetMod(modUUID).Info.Author)
        end
    end
end

--- Check if the data table has a SchemaVersions table and validate its contents
---@param data table The item data to check
---@return boolean True if the data table has a SchemaVersions table and it is valid, false otherwise
function BlueprintPreprocessing:HasSchemaVersionsEntry(data)
    if not data.SchemaVersion then
        MCMWarn(0,
            "No 'SchemaVersion' section found in data for mod: %s. Please contact %s about this issue.",
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name,
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author)
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: %s. Please contact %s about this issue.",
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name,
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author)
        return false
    end
    return true
end
