local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

local function preprocessAndSanitize(rawData, modUUID)
    local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
    local blueprint = Blueprint:New(preprocessedData)
    return BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID), blueprint
end

---@param fn fun()
---@return string[] warnings
local function captureMCMWarnings(fn)
    local warnings = {}
    local originalWarn = MCMWarn
    MCMWarn = function(_level, fmt, ...)
        local message = select("#", ...) > 0 and string.format(tostring(fmt), ...) or tostring(fmt)
        table.insert(warnings, message)
    end
    -- Restore MCMWarn even if the test callback throws.
    local ok, err = pcall(fn)
    MCMWarn = originalWarn
    if not ok then
        error(err)
    end
    return warnings
end

---@param warnings string[]
---@param needle string
---@return boolean
local function hasWarningMatching(warnings, needle)
    for _, msg in ipairs(warnings) do
        if string.find(msg, needle, 1, true) then
            return true
        end
    end
    return false
end

D.describe("Blueprint validation hardening (#58)", { tags = { "preprocessing", "validators", "unit" } }, function()
    local sandbox = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)
    local previousModUUID

    D.beforeEach(function(ctx)
        sandbox:Isolate(ctx)
        previousModUUID = BlueprintPreprocessing.currentmodUUID
    end)

    D.afterEach(function()
        BlueprintPreprocessing.currentmodUUID = previousModUUID
        sandbox:Restore()
    end)

    D.test("C7: hardened FloatValidator, DragIntValidator, KeybindingValidator, ListV2Validator", function()
        local floatSetting = BlueprintSetting:New({ Id = "f", Type = "float", Default = 1.0 })
        D.expect(FloatValidator.Validate(floatSetting, 2.5)).toBe(true)

        local badFloatOpts = BlueprintSetting:New({ Id = "f2", Type = "float", Default = 1.0, Options = { Min = "bad", Max = {} } })
        D.expect(FloatValidator.Validate(badFloatOpts, 2.5)).toBe(true)

        local dragIntSetting = BlueprintSetting:New({ Id = "di", Type = "drag_int", Default = 5, Options = { Min = 0, Max = 10 } })
        D.expect(DragIntValidator.Validate(dragIntSetting, 5)).toBe(true)
        D.expect(DragIntValidator.Validate(dragIntSetting, 1.5)).toBe(false)

        local badDragIntOpts = BlueprintSetting:New({ Id = "di2", Type = "drag_int", Default = 5, Options = { Min = "bad", Max = 10 } })
        D.expect(DragIntValidator.Validate(badDragIntOpts, 5)).toBe(false)

        local kbSetting = BlueprintSetting:New({ Id = "kb", Type = "keybinding", Default = {} })
        D.expect(SettingValidators.keybinding(kbSetting, "not-a-table")).toBe(false)
        D.expect(SettingValidators.keybinding(kbSetting, 123)).toBe(false)

        local listV2Setting = BlueprintSetting:New({ Id = "l2", Type = "list_v2", Default = { enabled = true, elements = {} } })
        local keyedElements = { enabled = true, elements = { foo = { name = "a", enabled = true } } }
        D.expect(ListV2Validator.Validate(listV2Setting, keyedElements)).toBe(false)

        local warnings = captureMCMWarnings(function()
            local badElement = { enabled = true, elements = { { name = "", enabled = true } } }
            D.expect(ListV2Validator.Validate(listV2Setting, badElement)).toBe(false)
        end)
        D.expect(hasWarningMatching(warnings, "name")).toBe(true)
        D.expect(hasWarningMatching(warnings, "enabled")).toBe(true)
    end)

    D.test("C7: SanitizeBlueprints isolates throwing mod blueprint from valid mod", function()
        local modA = TestConstants.ModuleUUIDs[1]
        local modB = TestConstants.ModuleUUIDs[2]
        local validBlueprint = Blueprint:New(DataPreprocessing:PreprocessData({
            SchemaVersion = 1,
            Settings = {
                { Id = "ok", Name = "Ok", Type = "checkbox", Default = true },
            },
        }, modB))

        local throwingBlueprint = {
            SchemaVersion = 1,
            GetTabs = function()
                error("boom")
            end,
        }

        local mods = {
            [modA] = { blueprint = throwingBlueprint },
            [modB] = { blueprint = validBlueprint },
        }

        local warnings = captureMCMWarnings(function()
            BlueprintPreprocessing:SanitizeBlueprints(mods)
        end)

        D.expect(mods[modA]).toBeNil()
        D.expect(mods[modB]).Not.toBeNil()
        D.expect(hasWarningMatching(warnings, "threw an error")).toBe(true)
    end)

    D.test("unknown setting Type warns only and keeps valid settings in the mod", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local sanitized
        local warnings = captureMCMWarnings(function()
            sanitized = preprocessAndSanitize({
                SchemaVersion = 1,
                Settings = {
                    { Id = "future_widget", Name = "Future", Type = "future_type", Default = "x" },
                    { Id = "valid_chk", Name = "Valid", Type = "checkbox", Default = true },
                },
            }, modUUID)
        end)

        D.expect(sanitized).Not.toBeNil()
        assert(sanitized)
        D.expect(sanitized:GetAllSettings()["valid_chk"]).Not.toBeNil()
        D.expect(hasWarningMatching(warnings, "unsupported type")).toBe(true)
    end)

    D.test("C9: legacy bool canonicalizes, soft float/color/keybinding warn only, event_button skips Default", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local sanitized
        local warnings = captureMCMWarnings(function()
            sanitized = preprocessAndSanitize({
                SchemaVersion = 1,
                Settings = {
                    { Id = "legacy_bool", Name = "Legacy Bool", Type = "bool", Default = true },
                    { Id = "legacy_kb", Name = "Legacy KB", Type = "keybinding", Default = "invalid" },
                    { Id = "legacy_list", Name = "Legacy List", Type = "list", Default = { "a" } },
                    { Id = "eb_scalar", Name = "Event Button", Type = "event_button", Default = 42 },
                    { Id = "color_oob", Name = "Color OOB", Type = "color_picker", Default = { 2.0, 0.5, 0.5, 1.0 } },
                    { Id = "float_oob", Name = "Float OOB", Type = "float", Default = 10.0, Options = { Min = 0.0, Max = 5.0 } },
                },
            }, modUUID)
        end)

        D.expect(sanitized).Not.toBeNil()
        assert(sanitized)
        local all = sanitized:GetAllSettings()
        D.expect(all["legacy_bool"]:GetType()).toBe("checkbox")
        D.expect(all["legacy_kb"]).Not.toBeNil()
        D.expect(all["legacy_list"]).Not.toBeNil()
        D.expect(all["eb_scalar"]).Not.toBeNil()
        D.expect(all["color_oob"]).Not.toBeNil()
        D.expect(all["float_oob"]).Not.toBeNil()
        D.expect(hasWarningMatching(warnings, "outside [0, 1]")).toBe(true)
        D.expect(hasWarningMatching(warnings, "outside its optional Min/Max")).toBe(true)
    end)

    D.test("C10: preserves literal 'true'/'false' strings while coercing list_v2 and legacy boolean flags", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local sanitized = preprocessAndSanitize({
            SchemaVersion = 1,
            Optional = "true",
            HiddenFromList = "false",
            Settings = {
                { Id = "txt", Name = "Text", Type = "text", Default = "true" },
                { Id = "enm", Name = "Enum", Type = "enum", Default = "false", Options = { Choices = { "true", "false" }, Dynamic = "false" } },
                { Id = "chk", Name = "Chk", Type = "checkbox", Default = true, Options = { InlineTitle = "false" } },
                {
                    Id = "vis",
                    Name = "Vis",
                    Type = "int",
                    Default = 1,
                    VisibleIf = {
                        Conditions = {
                            { SettingId = "txt", Operator = "==", ExpectedValue = "true" },
                        },
                    },
                },
                {
                    Id = "l2",
                    Name = "ListV2",
                    Type = "list_v2",
                    Default = {
                        Enabled = "true",
                        Elements = {
                            { name = "true", enabled = "false" },
                            { name = "false" },
                        },
                    },
                },
            },
        }, modUUID)

        D.expect(sanitized).Not.toBeNil()
        assert(sanitized)
        local all = sanitized:GetAllSettings()
        D.expect(sanitized:GetOptional()).toBe(true)
        D.expect(sanitized:GetHiddenFromList()).toBe(false)
        D.expect(all["txt"]:GetDefault()).toBe("true")
        D.expect(all["enm"]:GetDefault()).toBe("false")
        D.expect(all["enm"]:GetOptions().Choices[1]).toBe("true")
        D.expect(all["enm"]:GetOptions().Choices[2]).toBe("false")
        D.expect(all["enm"]:GetOptions().Dynamic).toBe(false)
        D.expect(all["chk"]:GetOptions().InlineTitle).toBe(false)
        D.expect(all["vis"]:GetVisibleIf().Conditions[1].ExpectedValue).toBe("true")
        D.expect(all["l2"]:GetDefault().enabled).toBe(true)
        D.expect(all["l2"]:GetDefault().elements[1].name).toBe("true")
        D.expect(all["l2"]:GetDefault().elements[1].enabled).toBe(false)
        D.expect(all["l2"]:GetDefault().elements[2].name).toBe("false")
        D.expect(all["l2"]:GetDefault().elements[2].enabled).toBe(true)
    end)

    D.test("C11: unknown keys warn without rejecting and root $schema is silent", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local sanitized
        local warnings = captureMCMWarnings(function()
            sanitized = preprocessAndSanitize({
                ["$schema"] = "../.vscode/schema.json",
                SchemaVersion = 1,
                UnknownRootKey = 123,
                Tabs = {
                    {
                        TabId = "t1",
                        TabName = "Tab 1",
                        UnknownTabKey = true,
                        Sections = {
                            {
                                SectionId = "s1",
                                SectionName = "Section 1",
                                UnknownSectionKey = true,
                                Settings = {
                                    {
                                        Id = "flag",
                                        Name = "Flag",
                                        Type = "checkbox",
                                        Default = true,
                                        UnknownSettingKey = "x",
                                        Options = {
                                            InlineTitle = true,
                                            UnknownOptionKey = 99,
                                        },
                                    },
                                    {
                                        Id = "dep",
                                        Name = "Dep",
                                        Type = "int",
                                        Default = 1,
                                        VisibleIf = {
                                            UnknownGroupKey = true,
                                            Conditions = {
                                                {
                                                    SettingId = "flag",
                                                    Operator = "==",
                                                    ExpectedValue = true,
                                                    UnknownCondKey = 1,
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            }, modUUID)
        end)

        D.expect(sanitized).Not.toBeNil()
        D.expect(hasWarningMatching(warnings, "$schema")).toBe(false)
        D.expect(hasWarningMatching(warnings, "UnknownRootKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownTabKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownSectionKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownSettingKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownOptionKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownGroupKey")).toBe(true)
        D.expect(hasWarningMatching(warnings, "UnknownCondKey")).toBe(true)
    end)
end)
