---@class HelperBlueprintPreprocessing
BlueprintPreprocessing = _Class:Create("HelperBlueprintPreprocessing", nil)
-- The current mod GUID being processed
BlueprintPreprocessing.currentModGuid = nil


--- Validate the structure of the blueprint data
---@param blueprint table The blueprint data to validate
---@return boolean True if the blueprint data is correct, false otherwise
function BlueprintPreprocessing:HasIncorrectStructure(blueprint)
    --- Check if blueprint has at least one tab
    local hasTabs = blueprint.Tabs and #blueprint.Tabs > 0

    --- Check if blueprint has at least one setting
    local hasSettings = blueprint.Settings and #blueprint.Settings > 0

    --- Check if blueprint does NOT have both tabs and settings
    if not hasTabs and not hasSettings then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
            "' does not have any tabs or settings. Please contact " ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return true
    elseif hasTabs and hasSettings then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
            "' has both tabs and settings. Please contact " ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return true
    end

    --- Check if blueprint does NOT have sections directly at the top level
    local hasSections = blueprint.Sections and #blueprint.Sections > 0
    if hasSections then
        MCMWarn(0,
            "Sections found directly in blueprint for mod '" ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
            "'. Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
                Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
                "'. Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
                    Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
                    "'. Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
                        Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
                        "'. Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
---@param blueprint table The blueprint data to validate
function BlueprintPreprocessing:ValidateBlueprintSettings(blueprint)
    local isValid = true
    local blueprintSettingsDefinitions = blueprint:GetAllSettings()

    if blueprintSettingsDefinitions then
        for _, setting in pairs(blueprintSettingsDefinitions) do
            if not self:BlueprintCheckDefaultType(setting) then
                return false
            end

            local settingType = setting.Type
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
            end
        end
    end

    return isValid
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

function BlueprintPreprocessing:BlueprintCheckDefaultType(setting)
    if setting.Default == nil then
        MCMWarn(0,
            "Setting '" ..
            setting.Id ..
            "' is missing a 'Default' value. Please contact " ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return false
    end

    if setting.Type == "bool" then
        if type(setting.Default) ~= "boolean" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a boolean. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "int" then
        if type(setting.Default) ~= "number" or math.floor(setting.Default) ~= setting.Default then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be an integer. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "float" then
        if type(setting.Default) ~= "number" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a number. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "text" then
        if type(setting.Default) ~= "string" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a string. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    -- TODO: add list type
    elseif setting.Type == "checkbox" then
        if type(setting.Default) ~= "boolean" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a boolean. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "enum" or setting.Type == "radio" then
        if type(setting.Default) ~= "string" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a string. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "slider_int" or setting.Type == "drag_int" then
        if type(setting.Default) ~= "number" or math.floor(setting.Default) ~= setting.Default then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be an integer. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "slider_float" or setting.Type == "drag_float" then
        if type(setting.Default) ~= "number" then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a number. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
        end
    elseif setting.Type == "color_picker" or setting.Type == "color_edit" then
        if type(setting.Default) ~= "table" or #setting.Default ~= 4 or not (type(setting.Default[1]) == "number" and type(setting.Default[2]) == "number" and type(setting.Default[3]) == "number" and type(setting.Default[4]) == "number") then
            MCMWarn(0,
                "Default value for setting '" ..
                setting.Id ..
                "' must be a table of 4 numbers. Please contact " ..
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
            return false
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
                Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return false
    end

    if not table.contains(setting.Options.Choices, setting.Default) then
        MCMWarn(0,
            "Enum setting '" ..
            setting.Id ..
            "' must have a 'Default' value that is one of the 'Options.Choices'. Please contact " ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
            Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
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
---@param blueprint table The blueprint data to sanitize
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    self.currentModGuid = modGUID
    if not self:HasSchemaVersionsEntry(blueprint) then
        return
    end

    if self:HasIncorrectStructure(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            "' has incorrect structure anda can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    if not self:VerifyIDUniqueness(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            "' has duplicate IDs and can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    if not self:ValidateBlueprintSettings(blueprint) then
        MCMWarn(0,
            "Blueprint for mod '" ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            "' has invalid settings and can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    table.convertStringBooleans(blueprint)
    return blueprint
end

--- Sanitize all blueprints for a given set of mods
---@param mods table<string, table> The mods data to sanitize
function BlueprintPreprocessing:SanitizeBlueprints(mods)
    for modGUID, mcmTable in pairs(mods) do
        if not self:SanitizeBlueprint(mcmTable.blueprint, modGUID) then
            mods[modGUID] = nil
            MCMWarn(0,
                "Blueprint validation failed for mod: " ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
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
            Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: " ..
            Ext.Mod.GetMod(self.currentModGuid).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(self.currentModGuid).Info.Author .. " about this issue.")
        return false
    end
    return true
end
