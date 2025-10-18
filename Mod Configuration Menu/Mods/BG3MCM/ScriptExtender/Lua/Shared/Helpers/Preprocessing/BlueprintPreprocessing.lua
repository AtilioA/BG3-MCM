--- TODO: add exception handling

---@class HelperBlueprintPreprocessing
BlueprintPreprocessing = _Class:Create("HelperBlueprintPreprocessing", nil)
-- The UUID of the mod being currently processed
BlueprintPreprocessing.currentmodUUID = nil


--- TODO: clean this up, but currently better than nothing
--- Checks if all elements in the blueprint have valid IDs
---@param blueprint Blueprint The blueprint data
---@return boolean True if all elements have valid IDs, false otherwise
function BlueprintPreprocessing:CheckValidIDs(blueprint)
    local function checkValidID(element)
        if not element.GetId then
            return true
        end

        if not element:GetId() or element:GetId() == "" then
            return false
        end
        return true
    end

    local function traverseBlueprint(element)
        local isValid = true

        if not checkValidID(element) then
            isValid = false
        end

        -- Check tabs
        if element.GetTabs then
            local tabs = element:GetTabs()
            if tabs then
                for _, tab in ipairs(tabs) do
                    if not traverseBlueprint(tab) then
                        isValid = false
                    end
                end
            end
        end

        if element.GetSections then
            local sections = element:GetSections()
            if sections then
                for _, section in ipairs(sections) do
                    if not traverseBlueprint(section) then
                        isValid = false
                    end
                end
            end
        end

        if element.GetSettings then
            local settings = element:GetSettings()
            if settings then
                for _, setting in ipairs(settings) do
                    if not checkValidID(setting) then
                        isValid = false
                    end
                end
            end
        end

        if not isValid then
            MCMWarn(0,
                "Missing ID in element: " .. (element and element.GetLocaName and element:GetLocaName() or "Unknown"))
        end
        return isValid
    end

    return traverseBlueprint(blueprint)
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
    if not hasTabs and not hasSettings then
        -- _D(blueprint)
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "' does not have any tabs or settings. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    elseif hasTabs and hasSettings then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "' has both tabs and settings. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    end

    --- Check if blueprint does NOT have sections directly at the top level
    --- TODO: remove this stupid design decision, sections should be allowed at the top level. This was not possible before the 1.7 layout though.
    local hasSections = blueprint:GetSections() and #blueprint:GetSections() > 0
    if hasSections then
        MCMWarn(0,
            "Sections found directly in blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    end

    if not self:CheckValidIDs(blueprint) then
        MCMWarn(0,
            "Missing IDs in blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return true
    end

    return false
end

--- Verify that all tabs in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifyTabIDUniqueness(blueprint)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local tabIDs = {}

    for _, tab in ipairs(tabs) do
        if tabIDs[tab.TabId] then
            MCMWarn(0,
                "Duplicate tab ID found in blueprint for mod '" ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
        tabIDs[tab.TabId] = true
    end

    return true
end

--- Verify that all sections in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifySectionIDUniqueness(blueprint)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local sectionIDs = {}

    for _, tab in ipairs(tabs) do
        if tab.Sections == nil or table.isEmpty(tab.Sections) then goto continue end
        for _, section in ipairs(tab.Sections) do
            if sectionIDs[section.SectionId] then
                MCMWarn(0,
                    "Duplicate section ID found in blueprint for mod '" ..
                    Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                    "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                return false
            end
            sectionIDs[section.SectionId] = true
        end
        ::continue::
    end

    return true
end

--- Verify that all setting IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifySettingIDUniqueness(blueprint)
    local settingIDs = {}
    local isValid = true

    local function checkSettingIDUniqueness(settings)
        for _, setting in ipairs(settings) do
            if setting ~= nil then
                if settingIDs[setting.Id] then
                    MCMWarn(0,
                        "Duplicate setting ID " .. setting.Id .. " found in blueprint for mod '" ..
                        Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
                        "'. Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                    isValid = false
                    goto continue
                end
                settingIDs[setting.Id] = true
            end
            ::continue::
        end
    end

    local rootSettings = blueprint:GetSettings()
    if rootSettings ~= nil then
        checkSettingIDUniqueness(rootSettings)
    end

    local tabs = blueprint:GetTabs()
    if tabs == nil then
        return isValid
    end

    for _, tab in ipairs(tabs) do
        local tabSettings = tab:GetSettings()
        if tabSettings ~= nil then
            checkSettingIDUniqueness(tabSettings)
        end

        local tabSections = tab:GetSections()
        if tabSections == nil then
            goto continue
        end

        for _, section in ipairs(tabSections) do
            local sectionSettings = section:GetSettings()
            if sectionSettings == nil then
                goto continue_inner
            end
            checkSettingIDUniqueness(sectionSettings)
            ::continue_inner::
        end
        ::continue::
    end

    return isValid
end

--- Verify all IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
function BlueprintPreprocessing:VerifyIDUniqueness(blueprint)
    return self:VerifyTabIDUniqueness(blueprint) and
        self:VerifySectionIDUniqueness(blueprint) and
        self:VerifySettingIDUniqueness(blueprint)
end

-- REFACTOR: this is way uglier and repetitive than it needs to be. Especially since we have validation functions for each type already. However, I'm too tired to refactor this. It is just validation, it is kinda fine.
--- Validate the setting data in the blueprint (e.g.: ensure that all IDs are unique, default values are valid, etc.)
---@param blueprint Blueprint The blueprint data to validate
function BlueprintPreprocessing:ValidateBlueprintSettings(blueprint)
    local isValid = true
    local blueprintSettingsDefinitions = blueprint:GetAllSettings()

    if blueprintSettingsDefinitions then
        for _, setting in pairs(blueprintSettingsDefinitions) do
            if not self:BlueprintCheckDefaultType(setting) then
                return false
            end

            local settingType = setting:GetType()
            if settingType == "enum" then
                if not self:ValidateEnumSetting(setting) then
                    return false
                end
            elseif settingType == "radio" then
                if not self:ValidateRadioSetting(setting) then
                    return false
                end
            elseif self:IsSliderSetting(settingType) then
                if not self:ValidateSliderSetting(setting) then
                    return false
                end
            elseif settingType == "keybinding_v2" then
                if not self:ValidateKeybindingV2Setting(setting) then
                    return false
                end
            elseif settingType == "event_button" then
                if not self:ValidateEventButtonSetting(setting) then
                    return false
                end
            elseif settingType == "checkbox" then
                if not self:ValidateCheckboxSetting(setting) then
                    return false
                end
            end

            -- Validate VisibleIf for the setting
            if not self:ValidateVisibleIf(setting:GetVisibleIf(), blueprint, "Setting", setting:GetId()) then
                return false
            end
        end
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

    return true
end

--- Validates the options for an event_button setting
---@param setting BlueprintSetting The setting to validate
---@return boolean True if the setting is valid, false otherwise
function BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    local options = setting:GetOptions() or {}
    local isValid = true
    local settingId = setting:GetId()

    -- Validate Cooldown if present
    if options.Cooldown ~= nil then
        if type(options.Cooldown) ~= "number" then
            MCMWarn(0,
                "Options.Cooldown for event_button setting '" .. settingId .. "' must be a number. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
        end
    end

    -- Validate Icon if present
    if options.Icon ~= nil then
        if type(options.Icon) ~= "table" then
            MCMWarn(0,
                "Options.Icon for event_button setting '" .. settingId .. "' must be an object with a Name field. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
        else
            if type(options.Icon.Name) ~= "string" or options.Icon.Name == "" then
                MCMWarn(0,
                    "Options.Icon.Name for event_button setting '" .. settingId .. "' must be a non-empty string. " ..
                    "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                isValid = false
            end
            if options.Icon.Size ~= nil then
                if type(options.Icon.Size) ~= "table"
                    or type(options.Icon.Size.Width) ~= "number"
                    or type(options.Icon.Size.Height) ~= "number" then
                    MCMWarn(0,
                        "Options.Icon.Size for event_button setting '" ..
                        settingId .. "' must be a table with numeric Width and Height fields. " ..
                        "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                    isValid = false
                end
            end
        end
    end

    -- Validate Label if present
    if options.Label ~= nil then
        if type(options.Label) ~= "string" or options.Label == "" then
            MCMWarn(0,
                "Options.Label for event_button setting '" .. settingId .. "' must be a non-empty string. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
        end
    end

    -- Validate ConfirmDialog if present
    if options.ConfirmDialog ~= nil then
        if type(options.ConfirmDialog) ~= "table" then
            MCMWarn(0,
                "Options.ConfirmDialog for event_button setting '" ..
                settingId ..
                "' must be a table. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            isValid = false
        else
            -- Define required fields for ConfirmDialog
            local requiredFields = {
                "Title",
                "Message",
                "ConfirmText",
                "CancelText"
            }

            -- Get the dialog table
            local dialog = options.ConfirmDialog

            -- Check if all required fields are present
            for _, field in ipairs(requiredFields) do
                if dialog[field] == nil then
                    MCMWarn(0,
                        string.format(
                            "Missing required field 'Options.ConfirmDialog.%s' for event_button setting '%s'. ",
                            field, settingId) ..
                        "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                    return false
                end
            end

            -- Validate field types for all fields that are present
            local validFieldTypes = {
                Title = "string",
                Message = "string",
                ConfirmText = "string",
                CancelText = "string"
            }

            for field, expectedType in pairs(validFieldTypes) do
                if dialog[field] ~= nil and type(dialog[field]) ~= expectedType then
                    MCMWarn(0,
                        string.format("Options.ConfirmDialog.%s for event_button setting '%s' must be a %s. ",
                            field, settingId, expectedType) ..
                        "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                    isValid = false
                end
            end
        end
    end

    return isValid
end

function BlueprintPreprocessing:ValidateKeybindingV2Setting(setting)
    local options = setting:GetOptions() or {}
    local settingId = setting:GetId()

    if options.ShouldTriggerOnRepeat ~= nil and type(options.ShouldTriggerOnRepeat) ~= "boolean" then
        MCMWarn(0,
            "Options.ShouldTriggerOnRepeat for keybinding_v2 setting '" ..
            settingId .. "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if options.IsDeveloperOnly ~= nil and type(options.IsDeveloperOnly) ~= "boolean" then
        MCMWarn(0,
            "Options.IsDeveloperOnly for keybinding_v2 setting '" ..
            settingId ..
            "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if options.ShouldTriggerOnKeyUp ~= nil and type(options.ShouldTriggerOnKeyUp) ~= "boolean" then
        MCMWarn(0,
            "Options.ShouldTriggerOnKeyUp for keybinding_v2 setting '" ..
            settingId ..
            "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if setting.Options and setting.Options.ShouldTriggerOnKeyDown ~= nil and type(setting.Options.ShouldTriggerOnKeyDown) ~= "boolean" then
        MCMWarn(0,
            "Options.ShouldTriggerOnKeyDown for keybinding_v2 setting '" ..
            setting.Id ..
            "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if setting.Options and setting.Options.BlockIfLevelNotStarted ~= nil and type(setting.Options.BlockIfLevelNotStarted) ~= "boolean" then
        MCMWarn(0,
            "Options.BlockIfLevelNotStarted for keybinding_v2 setting '" ..
            setting.Id ..
            "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if setting.Options and setting.Options.PreventAction ~= nil and type(setting.Options.PreventAction) ~= "boolean" then
        MCMWarn(0,
            "Options.PreventAction for keybinding_v2 setting '" ..
            setting.Id ..
            "' must be a boolean. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end

--- Validates VisibleIf conditions for all tabs and their nested sections
---@param blueprint Blueprint The blueprint data
---@return boolean True if all VisibleIf conditions are valid, false otherwise
function BlueprintPreprocessing:ValidateTabsVisibleIf(blueprint)
    local function validateTabRecursive(tab)
        -- Validate the tab's VisibleIf
        if not self:ValidateVisibleIf(tab:GetVisibleIf(), blueprint, "Tab", tab:GetId()) then
            return false
        end

        -- Validate nested tabs
        if tab.GetTabs then
            local nestedTabs = tab:GetTabs()
            if nestedTabs then
                for _, nestedTab in ipairs(nestedTabs) do
                    if not validateTabRecursive(nestedTab) then
                        return false
                    end
                end
            end
        end

        -- Validate sections
        if tab.GetSections then
            local sections = tab:GetSections()
            if sections then
                for _, section in ipairs(sections) do
                    if not self:ValidateVisibleIf(section:GetVisibleIf(), blueprint, "Section", section:GetId()) then
                        return false
                    end
                    -- Validate nested tabs in sections
                    if section.GetTabs then
                        local sectionTabs = section:GetTabs()
                        if sectionTabs then
                            for _, sectionTab in ipairs(sectionTabs) do
                                if not validateTabRecursive(sectionTab) then
                                    return false
                                end
                            end
                        end
                    end
                end
            end
        end

        return true
    end

    local tabs = blueprint:GetTabs()
    if tabs then
        for _, tab in ipairs(tabs) do
            if not validateTabRecursive(tab) then
                return false
            end
        end
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
    -- VisibleIf is optional, so nil/empty is valid
    if not visibleIf or visibleIf == "" or (type(visibleIf) == "table" and next(visibleIf) == nil) then
        return true
    end

    -- Validate that VisibleIf is a table
    if type(visibleIf) ~= "table" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has invalid VisibleIf (not a table). " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate LogicalOperator if present
    if visibleIf.LogicalOperator ~= nil then
        if type(visibleIf.LogicalOperator) ~= "string" then
            MCMWarn(0,
                elementType .. " '" .. elementId .. "' has invalid VisibleIf.LogicalOperator (not a string). " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
        if visibleIf.LogicalOperator ~= "and" and visibleIf.LogicalOperator ~= "or" then
            MCMWarn(0,
                elementType .. " '" .. elementId .. "' has invalid VisibleIf.LogicalOperator ('" ..
                visibleIf.LogicalOperator .. "'). Must be 'and' or 'or'. " ..
                "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    end

    -- Validate Conditions array
    if not visibleIf.Conditions then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has VisibleIf without Conditions array. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if type(visibleIf.Conditions) ~= "table" then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has invalid VisibleIf.Conditions (not an array). " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if #visibleIf.Conditions == 0 then
        MCMWarn(0,
            elementType .. " '" .. elementId .. "' has empty VisibleIf.Conditions array. " ..
            "Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    -- Validate each condition
    for i, condition in ipairs(visibleIf.Conditions) do
        if not self:ValidateVisibilityCondition(condition, blueprint, elementType, elementId, i) then
            return false
        end
    end

    return true
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
    local allSettings = blueprint:GetAllSettings()
    local settingExists = false
    if allSettings then
        for _, setting in pairs(allSettings) do
            if setting:GetId() == condition.SettingId then
                settingExists = true
                break
            end
        end
    end

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

    local validOperators = { "==", "!=", ">", "<", ">=", "<=" }
    local operatorValid = false
    for _, validOp in ipairs(validOperators) do
        if condition.Operator == validOp then
            operatorValid = true
            break
        end
    end

    if not operatorValid then
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

    -- According to schema, ExpectedValue must be string or boolean
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

function BlueprintPreprocessing:BlueprintCheckDefaultType(setting)
    -- Skip Default validation for event_button type
    if setting.Type == "event_button" then
        return true
    end

    if setting.Default == nil then
        MCMWarn(0,
            "Setting '" ..
            setting.Id ..
            "' is missing a 'Default' value. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if setting.Type == "bool" then
        if type(setting.Default) ~= "boolean" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a boolean. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "int" then
        if type(setting.Default) ~= "number" or math.floor(setting.Default) ~= setting.Default then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be an integer. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "float" then
        if type(setting.Default) ~= "number" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a number. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "text" then
        if type(setting.Default) ~= "string" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a string. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
        -- TODO: add list type
    elseif setting.Type == "checkbox" then
        if type(setting.Default) ~= "boolean" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a boolean. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "enum" or setting.Type == "radio" then
        if type(setting.Default) ~= "string" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a string. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "slider_int" or setting.Type == "drag_int" then
        if type(setting.Default) ~= "number" or math.floor(setting.Default) ~= setting.Default then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be an integer. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "slider_float" or setting.Type == "drag_float" then
        if type(setting.Default) ~= "number" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a number. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "color_picker" or setting.Type == "color_edit" then
        if type(setting.Default) ~= "table" or #setting.Default ~= 4 or not (type(setting.Default[1]) == "number" and type(setting.Default[2]) == "number" and type(setting.Default[3]) == "number" and type(setting.Default[4]) == "number") then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a table of 4 numbers. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "keybinding_v2" then
        if type(setting.Default) == "table" then
            if setting.Default["Enabled"] ~= nil and type(setting.Default["Enabled"]) ~= "boolean" then
                MCMWarn(0,
                    "Default value for 'enabled' in keybinding_v2 setting '" ..
                    setting.Id ..
                    "' must be a boolean. Please contact " ..
                    Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                return false
            end

            if not (type(setting.Default["Keyboard"]) == "table") then
                MCMWarn(0,
                    "Default value for setting '" ..
                    setting.Id ..
                    "' must be a table containing a 'Keyboard' table. Please contact " ..
                    Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                return false
            end

            -- Validate Keyboard configuration
            local keyboard = setting.Default["Keyboard"]
            local key = keyboard.Key
            if type(key) ~= "string" or (key ~= "" and not table.contains(SDLKeys.ScanCodes, key)) then
                MCMWarn(0,
                    "Invalid key '" ..
                    key .. "' in Keyboard.Key for setting '" .. setting.Id .. "'. Valid keys are: " ..
                    table.concat(SDLKeys.ScanCodes, ", "))
                return false
            end

            -- Validate ModifierKeys if provided
            if keyboard.ModifierKeys then
                if type(keyboard.ModifierKeys) ~= "table" then
                    MCMWarn(0,
                        "Keyboard.ModifierKeys must be a table. Please contact " ..
                        Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
                    return false
                end
                for _, mod in ipairs(keyboard.ModifierKeys) do
                    if type(mod) ~= "string" or (mod ~= "" and not table.contains(SDLKeys.Modifiers, mod)) then
                        MCMWarn(0,
                            "Invalid modifier '" ..
                            mod ..
                            "' in Keyboard.ModifierKeys for setting '" .. setting.Id .. "'. Valid modifiers are: " ..
                            table.concat(SDLKeys.Modifiers, ", "))
                        return false
                    end
                end
            end
        end
    elseif setting.Type == "list_v2" then
        if type(setting.Default) ~= "table" or (setting.Default["enabled"] == nil and setting.Default["Enabled"] == nil) or (type(setting.Default.elements) ~= "table" and type(setting.Default.Elements) ~= "table") then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a table with 'Enabled' and 'Elements'. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end

        for _, element in ipairs(setting.Default.elements) do
            if type(element) ~= "table" or not element.name or type(element.name) ~= "string" or element.name == "" then
                MCMWarn(0,
                    "Element " ..
                    Ext.DumpExport(element) ..
                    " for setting '" ..
                    setting.Id .. "' must be a table with 'name' as a non-empty string and 'enabled' as a boolean.")
                return false
            end
            if element.enabled ~= nil and type(element.enabled) ~= "boolean" then
                MCMWarn(0,
                    "Element " ..
                    Ext.DumpExport(element) ..
                    " for setting '" ..
                    setting.Id .. "' must be a table with 'name' as a non-empty string and 'enabled' as a boolean.")
                return false
            end
        end
    end

    return true
end

function BlueprintPreprocessing:BlueprintDefaultShouldBeWithinRange(setting)
    if setting.Options and setting.Options.Min and setting.Options.Max then
        if setting.Default < setting.Options.Min or setting.Default > setting.Options.Max then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be within the range of 'Options.Min' and 'Options.Max'. Please contact " ..
                Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
            return false
        end
    end
    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveOptionsForEnum(setting)
    if not setting.Options or not setting.Options.Choices or #setting.Options.Choices == 0 then
        MCMWarn(0,
            "Enum setting '" ..
            setting.Id ..
            "' must have 'Options.Choices' defined. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    if not table.contains(setting.Options.Choices, setting.Default) then
        MCMWarn(0,
            "Enum setting '" ..
            setting.Id ..
            "' must have a 'Default' value that is one of the 'Options.Choices'. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveOptionsForRadio(setting)
    if not setting.Options or not setting.Options.Choices or #setting.Options.Choices == 0 then
        MCMWarn(0,
            "Radio setting '" .. setting.Id .. "' must have 'Options.Choices' defined.")
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings(setting)
    if setting.Options and setting.Options.Choices then
        for _, choice in ipairs(setting.Options.Choices) do
            if type(choice) ~= "string" then
                MCMWarn(0,
                    "Options.Choices for enum setting '" .. setting.Id .. "' must be an array of strings.")
                return false
            end
        end
    end
    return true
end

function BlueprintPreprocessing:BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings(setting)
    if not setting.Options or not setting.Options.Choices then
        MCMWarn(0,
            "Radio setting '" ..
            setting.Id ..
            "' must have 'Options.Choices' defined. Please contact " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end

    for _, choice in pairs(setting.Options.Choices) do
        if type(choice) ~= "string" then
            MCMWarn(0,
                "Options.Choices for radio setting '" .. setting.Id .. "' must be an array of strings.")
            return false
        end
    end

    return true
end

function BlueprintPreprocessing:BlueprintShouldHaveMinAndMaxForSlider(setting)
    if not setting.Options or not setting.Options.Min or not setting.Options.Max then
        MCMWarn(0,
            "Slider setting '" .. setting.Id .. "' must have 'Options.Min' and 'Options.Max' defined.")
        return false
    end
    return true
end

function BlueprintPreprocessing:BlueprintMinAndMaxForSliderShouldBeNumbers(setting)
    if setting.Options and (type(setting.Options.Min) ~= "number" or type(setting.Options.Max) ~= "number") then
        MCMWarn(0,
            "Slider setting '" .. setting.Id .. "' must have 'Options.Min' and 'Options.Max' defined as numbers.")
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
        MCMWarn(0, "Slider setting '" .. setting.Id .. "' is missing Options")
        return false
    end

    if not setting.Options.Min or not setting.Options.Max then
        MCMWarn(0, "Slider setting '" .. setting.Id .. "' is missing Options.Min or Options.Max")
        return false
    end

    if setting.Options.Min >= setting.Options.Max then
        MCMWarn(0, "Slider setting '" .. setting.Id .. "' must have 'Options.Min' less than 'Options.Max'.")
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
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            "' has incorrect structure and can't be used. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return
    end

    if not self:VerifyIDUniqueness(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            "' has duplicate IDs and can't be used. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return
    end

    if not self:ValidateBlueprintSettings(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            "' has invalid settings and can't be used. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
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
                "Blueprint validation failed for mod: " ..
                Ext.Mod.GetMod(modUUID).Info.Name ..
                ". Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        end
    end
end

--- Check if the data table has a SchemaVersions table and validate its contents
---@param data table The item data to check
---@return boolean True if the data table has a SchemaVersions table and it is valid, false otherwise
function BlueprintPreprocessing:HasSchemaVersionsEntry(data)
    if not data.SchemaVersion then
        MCMWarn(0,
            "No 'SchemaVersion' section found in data for mod: " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: " ..
            Ext.Mod.GetMod(self.currentmodUUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(self.currentmodUUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end
