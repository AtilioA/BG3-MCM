---@class HelperBlueprintPreprocessing
BlueprintPreprocessing = _Class:Create("HelperBlueprintPreprocessing", nil)


--- Validate the structure of the blueprint data
---@param blueprint table The blueprint data to validate
---@param modGUID string The mod's unique identifier
---@return boolean True if the blueprint data is correct, false otherwise
function BlueprintPreprocessing:HasIncorrectStructure(blueprint, modGUID)
    --- Check if blueprint has at least one tab
    local hasTabs = blueprint.Tabs and #blueprint.Tabs > 0

    --- Check if blueprint has at least one setting
    local hasSettings = blueprint.Settings and #blueprint.Settings > 0

    --- Check if blueprint does NOT have both tabs and settings
    if not hasTabs and not hasSettings then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " does not have any tabs or settings. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    elseif hasTabs and hasSettings then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has both tabs and settings. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    end

    --- Check if blueprint does NOT have sections directly at the top level
    local hasSections = blueprint.Sections and #blueprint.Sections > 0
    if hasSections then
        MCMWarn(0,
            "Sections found directly in blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    end

    return false
end

--- Verify that all tabs in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:VerifyTabIDUniqueness(blueprint, modGUID)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local tabIDs = {}

    for _, tab in ipairs(tabs) do
        if tabIDs[tab.TabId] then
            MCMWarn(0,
                "Duplicate tab ID found in blueprint for mod: " ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            return false
        end
        tabIDs[tab.TabId] = true
    end

    return true
end

--- Verify that all sections in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:VerifySectionIDUniqueness(blueprint, modGUID)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local sectionIDs = {}

    for _, tab in ipairs(tabs) do
        if tab.Sections ~= nil then
            for _, section in ipairs(tab.Sections) do
                if sectionIDs[section.SectionId] then
                    MCMWarn(0,
                        "Duplicate section ID found in blueprint for mod: " ..
                        Ext.Mod.GetMod(modGUID).Info.Name ..
                        ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
                    return false
                end
                sectionIDs[section.SectionId] = true
            end
        end
    end

    return true
end

--- Verify that all setting IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:VerifySettingIDUniqueness(blueprint, modGUID)
    local settingIDs = {}
    local isValid = true

    local function checkSettingIDUniqueness(settings)
        for _, setting in ipairs(settings) do
            if setting ~= nil then
                if settingIDs[setting.Id] then
                    MCMWarn(0,
                        "Duplicate setting ID found in blueprint for mod: " ..
                        Ext.Mod.GetMod(modGUID).Info.Name ..
                        ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
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
        local tabSettingIDs = tab:GetSettings()
        if tabSettingIDs ~= nil then
            checkSettingIDUniqueness(tabSettingIDs)
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
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:VerifyIDUniqueness(blueprint, modGUID)
    return self:VerifyTabIDUniqueness(blueprint, modGUID) and
        self:VerifySectionIDUniqueness(blueprint, modGUID) and
        self:VerifySettingIDUniqueness(blueprint, modGUID)
end

--- Validate the setting data in the blueprint (e.g.: ensure that all IDs are unique, default values are valid, etc.)
---@param blueprint table The blueprint data to validate
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:ValidateBlueprintSettings(blueprint, modGUID)
    local isValid = true

    local blueprintSettingsDefinitions = blueprint:GetAllSettings()
    if blueprintSettingsDefinitions then
        for _, setting in ipairs(blueprintSettingsDefinitions) do
            if setting.Type == "enum" then
                if not self:BlueprintShouldHaveOptionsForEnum(setting) then
                    isValid = false
                end
            elseif setting.Type == "radio" then
                if not self:BlueprintShouldHaveOptionsForRadio(setting) then
                    isValid = false
                end
            elseif setting.Type == "slider" or setting.Type == "slider_int" or setting.Type == "slider_float" then
                if not self:BlueprintShouldHaveMinAndMaxForSlider(setting) then
                    isValid = false
                end
                if not self:BlueprintMinAndMaxForSliderShouldBeNumbers(setting) then
                    isValid = false
                end
                if not self:BlueprintMinIsLessThanMaxForSlider(setting) then
                    isValid = false
                end
            end
        end
    end

    return isValid
end

function BlueprintPreprocessing:BlueprintShouldHaveOptionsForEnum(setting)
    if not setting.Options or not setting.Options.Choices or #setting.Options.Choices == 0 then
        MCMWarn(0,
            "Enum setting '" .. setting.Id .. "' must have 'Options.Choices' defined.")
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
    if setting.Options and setting.Options.Choices then
        for _, choice in ipairs(setting.Options.Choices) do
            if type(choice) ~= "string" then
                MCMWarn(0,
                    "Options.Choices for radio setting '" .. setting.Id .. "' must be an array of strings.")
                return false
            end
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

--- TODO: validate if blueprint is correct, e.g. settings have unique IDs, etc.
--- Sanitizes blueprint data by removing elements without SchemaVersions and converting string booleans
---@param blueprint table The blueprint data to sanitize
---@param modGUID string The mod's unique identifier
function BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    if not self:HasSchemaVersionsEntry(blueprint, modGUID) then
        return
    end

    if self:HasIncorrectStructure(blueprint, modGUID) then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has incorrect structure anda can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    if not self:VerifyIDUniqueness(blueprint, modGUID) then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has duplicate IDs and can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    if not self:ValidateBlueprintSettings(blueprint, modGUID) then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has invalid settings and can't be used. Please contact " ..
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
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a SchemaVersions table and it is valid, false otherwise
function BlueprintPreprocessing:HasSchemaVersionsEntry(data, modGUID)
    if not data.SchemaVersion then
        MCMWarn(0,
            "No 'SchemaVersion' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end
    return true
end

--- Check if the data table has a Sections table
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a Sections table, false otherwise
function BlueprintPreprocessing:HasSectionsEntry(data, modGUID)
    if not data.Sections then
        MCMDebug(2,
            "No 'Sections' section found in data for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
        return false
    end
    return true
end
