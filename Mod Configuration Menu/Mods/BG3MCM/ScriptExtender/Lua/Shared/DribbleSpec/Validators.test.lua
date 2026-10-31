local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("Setting validators", { tags = { "validators", "unit" } }, function()
    -- Mutation runs list "client": a mutant can reach any write or send, so both are sandboxed deny-by-default.
    local sandbox = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        sandbox:Isolate(ctx)
    end)

    D.afterEach(function()
        sandbox:Restore()
    end)

    local previousModUUID

    D.beforeEach(function()
        previousModUUID = BlueprintPreprocessing.currentmodUUID
    end)

    D.afterEach(function()
        BlueprintPreprocessing.currentmodUUID = previousModUUID
    end)

    D.test("TestValidateIntSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-int",
            Type = "int",
            Default = 42
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 42)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 42.5)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "42")).toBe(false)
    end)

    D.test("TestValidateFloatSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-float",
            Type = "float",
            Default = 3.14,
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 3.14)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 3)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "3.14")).toBe(false)
    end)

    D.test("TestValidateIntRejectsNonNumericString", function(ctx)
        local setting = BlueprintSetting:New({ Id = "test-int", Type = "int", Default = 1 })

        D.expect(IntValidator.Validate(setting, "abc")).toBe(false)
        D.expect(IntValidator.Validate(setting, {})).toBe(false)
    end)

    D.test("TestValidateFloatAcceptsValuesWithinEpsilonOfBounds", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-float-epsilon",
            Type = "float",
            Default = 0.5,
            Options = { Min = 0, Max = 1 }
        })
        local eps = FloatUtils.EPSILON

        D.expect(DataPreprocessing:ValidateSetting(setting, 0 - eps)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 1 + eps)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 0 - 2 * eps)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, 1 + 2 * eps)).toBe(false)
    end)

    D.test("TestValidateCheckboxAcceptsBooleanTrue", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-checkbox",
            Type = "checkbox",
            Default = true,
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, true)).toBe(true)
    end)

    D.test("TestValidateCheckboxAcceptsBooleanFalse", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-checkbox",
            Type = "checkbox",
            Default = true,
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, false)).toBe(true)
    end)

    D.test("TestValidateCheckboxRejectsNonBooleanTypes", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-checkbox",
            Type = "checkbox",
            Default = true,
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "true")).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "false")).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, 0)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, 1)).toBe(false)

        -- Presence on the boolean inputs the same setting accepts
        D.expect(DataPreprocessing:ValidateSetting(setting, true)).toBe(true)
    end)

    D.test("TestValidateTextSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-text",
            Type = "text",
            Default = "hello",
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "hello")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 42)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, true)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, false)).toBe(false)
    end)

    D.test("TestValidateEnumSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-enum",
            Type = "enum",
            Default = "option-1",
            Options = {
                Choices = { "option-1", "option-2", "option-3" }
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "option-1")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "option-3")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, 1)).toBe(false)
    end)

    D.test("TestValidateDynamicEnumSettingWithoutChoices", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-dynamic-enum",
            Type = "enum",
            Default = "runtime-default",
            Options = {
                Choices = {}
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "runtime-value")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 42)).toBe(false)
    end)

    D.test("TestValidateDynamicEnumSettingWithChoices", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-dynamic-enum-with-choices",
            Type = "enum",
            Default = "No change",
            Options = {
                Dynamic = true,
                Choices = { "No change" }
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "Karlach AEE")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, true)).toBe(false)
    end)

    D.test("TestValidateRadioSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-radio",
            Type = "radio",
            Default = "option-1",
            Options = {
                Choices = { "option-1", "option-2", "option-3" }
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, "option-1")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "option-3")).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)
    end)

    D.test("TestValidateSliderIntSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-slider-int",
            Type = "slider_int",
            Default = 50,
            Options = {
                Min = 0,
                Max = 100
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 0)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 50)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 100)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 101)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, -1)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, 50.5)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "50")).toBe(false)
        D.expect(SliderIntValidator.Validate(setting, "abc")).toBe(false)
    end)

    D.test("TestValidateSliderFloatSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-slider-float",
            Type = "slider_float",
            Default = 3.14,
            Options = {
                Min = 0,
                Max = 10
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 3.14)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 3)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 10.1)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, -0.1)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "3.14")).toBe(false)
    end)

    D.test("TestValidateDragIntSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-drag-int",
            Type = "drag_int",
            Default = 50,
            Options = {
                Min = 0,
                Max = 100
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 0)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 50)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 100)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 101)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, -1)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "50")).toBe(false)
    end)

    D.test("TestValidateDragFloatSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-drag-float",
            Type = "drag_float",
            Default = 3.14,
            Options = {
                Min = 0,
                Max = 10
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, 3.14)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 3)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, 10.1)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, -0.5)).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "3.14")).toBe(false)
    end)

    D.test("TestValidateColorPickerSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "color-picker",
            Type = "color_picker",
            Default = { 1, 0, 0, 1 }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 0, 0.5, 1, 0.25 })).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)

        -- Test non-normalized RGB inputs
        D.expect(DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })).toBe(false)

        -- Test RGB (without alpha) inputs
        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })).toBe(false)
    end)

    D.test("TestValidateColorEditSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "color-edit",
            Type = "color_edit",
            Default = { 1, 0, 0, 1 }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 0, 0.5, 1, 0.25 })).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)

        -- Test non-normalized RGB inputs
        D.expect(DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })).toBe(false)

        -- Test RGB (without alpha) inputs
        D.expect(DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })).toBe(false)
        D.expect(DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })).toBe(false)
    end)

    D.test("TestValidateColorRejectsWrongLengthAndNonNumericChannels", function(ctx)
        D.expect(ColorValidator.Validate(nil, { 1, 0, 0, 1, 1 })).toBe(false)
        D.expect(ColorValidator.Validate(nil, { "a", 0, 0, 1 })).toBe(false)
        D.expect(ColorValidator.Validate(nil, { -0.1, 0, 0, 1 })).toBe(false)
    end)

    D.test("TestValidateKeybindingV2Keyboard", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-kb-binding",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "INSERT", ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "A", ModifierKeys = { "LCTRL", "LSHIFT" } },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "LCtrl", "LShift" } },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "", ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "NOTAKEY", ModifierKeys = {} },
            Enabled = true
        })).toBe(false)

        -- Scan codes are uppercase only
        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "insert", ModifierKeys = {} },
            Enabled = true
        })).toBe(false)
    end)

    D.test("TestValidateKeybindingV2KeyboardModifierVariants", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-kb-binding-variants",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local validModifierVariants = {
            "LCTRL",
            "LCtrl",
            "lctrl",
            "LSHIFT",
            "LShift",
            "lshift",
            "RALT",
            "ralt",
            "NONE",
            "none",
        }

        for _, modifier in ipairs(validModifierVariants) do
            D.expect(KeybindingV2Validator.Validate(setting, {
                Keyboard = { Key = "P", ModifierKeys = { modifier } },
                Enabled = true
            })).toBe(true)
        end

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "lctrl", "LShift" } },
            Enabled = true
        })).toBe(true)
    end)

    D.test("TestValidateKeybindingV2MouseModifierVariants", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-mouse-binding-variants",
            Type = "keybinding_v2",
            Default = {
                Mouse = { Button = 3, ModifierKeys = {} },
                Enabled = true
            }
        })

        local validModifierVariants = {
            "LCTRL",
            "LCtrl",
            "lctrl",
            "LSHIFT",
            "LShift",
            "lshift",
            "RALT",
            "ralt",
            "NONE",
            "none",
        }

        for _, modifier in ipairs(validModifierVariants) do
            D.expect(KeybindingV2Validator.Validate(setting, {
                Mouse = { Button = 3, ModifierKeys = { modifier } },
                Enabled = true
            })).toBe(true)
        end
    end)

    D.test("TestValidateKeybindingV2InvalidModifier", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-kb-invalid-modifier",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "LCTRL_BAD" } },
            Enabled = true
        })).toBe(false)

        -- Presence on a supported modifier
        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "LCTRL" } },
            Enabled = true
        })).toBe(true)
    end)

    D.test("TestValidateKeybindingV2InvalidModifierVariants", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-kb-invalid-modifier-variants",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local invalidModifierVariants = {
            "LCTRL_BAD",
            "CTRL",
            "LeftCtrl",
            "LGUI",
            "lgui",
            "RGUI",
            "CAPS",
            "",
            123,
            true,
            {},
        }

        for _, modifier in ipairs(invalidModifierVariants) do
            D.expect(KeybindingV2Validator.Validate(setting, {
                Keyboard = { Key = "P", ModifierKeys = { modifier } },
                Enabled = true
            })).toBe(false)

            D.expect(KeybindingV2Validator.Validate(setting, {
                Mouse = { Button = 3, ModifierKeys = { modifier } },
                Enabled = true
            })).toBe(false)
        end
    end)

    D.test("TestValidateKeybindingV2Mouse", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-mouse-binding",
            Type = "keybinding_v2",
            Default = {
                Mouse = { Button = 1, ModifierKeys = {} },
                Enabled = true
            }
        })

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 3, ModifierKeys = { "LCTRL" } },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 10, ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        -- Button 0 means unassigned, which is a legal stored value
        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 0, ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 11, ModifierKeys = {} },
            Enabled = true
        })).toBe(false)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = "3", ModifierKeys = {} },
            Enabled = true
        })).toBe(false)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 1.5, ModifierKeys = {} },
            Enabled = true
        })).toBe(false)
    end)

    D.test("TestValidateKeybindingV2OptionalFields", function(ctx)
        D.expect(KeybindingV2Validator.Validate(nil, { Keyboard = { ModifierKeys = {} } })).toBe(true)
        D.expect(KeybindingV2Validator.Validate(nil, { Keyboard = { Key = "A" } })).toBe(true)
        D.expect(KeybindingV2Validator.Validate(nil, { Mouse = { ModifierKeys = {} } })).toBe(true)
        D.expect(KeybindingV2Validator.Validate(nil, { Mouse = { Button = 3 } })).toBe(true)
    end)

    D.test("TestValidateKeybindingV2RejectsWrongFieldTypes", function(ctx)
        D.expect(KeybindingV2Validator.Validate(nil, nil)).toBe(false)
        D.expect(KeybindingV2Validator.Validate(nil, 5)).toBe(false)
        D.expect(KeybindingV2Validator.Validate(nil, { Keyboard = { Key = 5 } })).toBe(false)
        D.expect(KeybindingV2Validator.Validate(nil, { Keyboard = { Key = "A", ModifierKeys = "LCTRL" } })).toBe(false)
        D.expect(KeybindingV2Validator.Validate(nil, { Mouse = { Button = "x" } })).toBe(false)
        D.expect(KeybindingV2Validator.Validate(nil, { Mouse = { Button = 3, ModifierKeys = "LCTRL" } })).toBe(false)
    end)

    D.test("TestValidateKeybindingV2XOR", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-xor-binding",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "INSERT", ModifierKeys = {} },
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })).toBe(false)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "", ModifierKeys = {} },
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "A", ModifierKeys = {} },
            Mouse = { Button = 0, ModifierKeys = {} },
            Enabled = true
        })).toBe(true)

        D.expect(KeybindingV2Validator.Validate(setting, {
            Enabled = true
        })).toBe(false)
    end)

    D.test("TestValidateListV2Setting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-list-v2",
            Type = "list_v2",
            Default = {
                enabled = true,
                elements = {}
            }
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, {
            enabled = true,
            elements = {
                {
                    name = "A",
                    enabled = true
                }
            }
        })).toBe(true)

        D.expect(DataPreprocessing:ValidateSetting(setting, {
            enabled = "yes",
            elements = {}
        })).toBe(false)

        D.expect(DataPreprocessing:ValidateSetting(setting, {
            enabled = true,
            elements = {
                {
                    name = "",
                    enabled = true
                }
            }
        })).toBe(false)

        D.expect(DataPreprocessing:ValidateSetting(setting, {
            enabled = true
        })).toBe(false)
    end)

    D.test("TestValidateListV2RejectsWrongShapes", function(ctx)
        D.expect(ListV2Validator.Validate(nil, 5)).toBe(false)
        D.expect(ListV2Validator.Validate(nil, { enabled = true, elements = "x" })).toBe(false)
        D.expect(ListV2Validator.Validate(nil, { enabled = true, elements = { 5 } })).toBe(false)
        D.expect(ListV2Validator.Validate(nil, { enabled = true, elements = { { name = "A", enabled = "yes" } } })).toBe(false)
        D.expect(ListV2Validator.Validate(nil, { enabled = true, elements = { { name = 5, enabled = true } } })).toBe(false)
    end)

    D.test("TestValidateEventButtonSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-setting",
            Type = "event_button"
        })

        D.expect(DataPreprocessing:ValidateSetting(setting, nil)).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, { metadata = "ok" })).toBe(true)
        D.expect(DataPreprocessing:ValidateSetting(setting, "invalid")).toBe(false)
    end)

    D.test("TestNonExistentSetting", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "non-existent",
            Type = "unknown",
            Default = "unknown",
        })

        BlueprintPreprocessing.currentmodUUID = ModuleUUID
        local isValid = DataPreprocessing:ValidateSetting(setting, "unknown")

        D.expect(isValid).toBe(false)
    end)
end)
