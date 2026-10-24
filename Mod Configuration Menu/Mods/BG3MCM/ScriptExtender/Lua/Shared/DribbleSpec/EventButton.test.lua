D.describe("Event Button Validation", { tags = { "event-button", "unit" } }, function()
    local previousModUUID

    D.beforeEach(function()
        previousModUUID = BlueprintPreprocessing.currentmodUUID
        BlueprintPreprocessing.currentmodUUID = TestConstants.ModuleUUIDs[1]
    end)

    D.afterEach(function()
        BlueprintPreprocessing.currentmodUUID = previousModUUID
    end)

    D.test("TestValidEventButtonMinimal", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-minimal",
            Type = "event_button",
            Options = {}
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithCooldown", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-cooldown",
            Type = "event_button",
            Options = {
                Cooldown = 5.0
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithoutIcon", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-no-icon",
            Type = "event_button",
            Options = {
                Cooldown = 1.0,
                Label = "Run Action"
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithIcon", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-icon",
            Type = "event_button",
            Options = {
                Icon = {
                    Name = "Icon_Item_Scroll_01"
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithIconSize", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-icon-size",
            Type = "event_button",
            Options = {
                Icon = {
                    Name = "Icon_Item_Scroll_01",
                    Size = {
                        Width = 20,
                        Height = 20
                    }
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithConfirmDialog", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-confirm",
            Type = "event_button",
            Options = {
                ConfirmDialog = {
                    Title = "Confirm Action",
                    Message = "Are you sure you want to perform this action?",
                    ConfirmText = "Yes",
                    CancelText = "No"
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestValidEventButtonWithAllOptions", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-all-options",
            Type = "event_button",
            Options = {
                Cooldown = 5.0,
                Label = "Run Action",
                Icon = {
                    Name = "Icon_Item_Scroll_01"
                },
                ConfirmDialog = {
                    Title = "Confirm Action",
                    Message = "Are you sure you want to perform this action?",
                    ConfirmText = "Yes",
                    CancelText = "No"
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)

    D.test("TestInvalidEventButtonCooldownType", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-cooldown",
            Type = "event_button",
            Options = {
                Cooldown = "not-a-number"
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonIconType", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-icon",
            Type = "event_button",
            Options = {
                Icon = 12345
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonIconNameMissing", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-icon-name-missing",
            Type = "event_button",
            Options = {
                Icon = {
                    Size = {
                        Width = 20,
                        Height = 20
                    }
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonIconNameEmpty", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-icon-name-empty",
            Type = "event_button",
            Options = {
                Icon = {
                    Name = ""
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonIconSizeType", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-icon-size-type",
            Type = "event_button",
            Options = {
                Icon = {
                    Name = "Icon_Item_Scroll_01",
                    Size = "20x20"
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonIconSizeMissingFields", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-icon-size-fields",
            Type = "event_button",
            Options = {
                Icon = {
                    Name = "Icon_Item_Scroll_01",
                    Size = {
                        Width = 20
                    }
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    D.test("TestInvalidEventButtonConfirmDialogType", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-confirm-type",
            Type = "event_button",
            Options = {
                ConfirmDialog = "not-a-table"
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(false)
    end)

    local confirmDialogFields = { "Title", "Message", "ConfirmText", "CancelText" }
    local validConfirmDialog = {
        Title = "Confirm Action",
        Message = "Are you sure you want to perform this action?",
        ConfirmText = "Yes",
        CancelText = "No",
    }

    for _, field in ipairs(confirmDialogFields) do
        local fieldName = field

        D.test("TestInvalidEventButtonConfirmDialog" .. fieldName .. "Type", function()
            local dialog = table.deepcopy(validConfirmDialog)
            dialog[fieldName] = 123
            local setting = BlueprintSetting:New({
                Id = "test-event-button-invalid-confirm-" .. string.lower(fieldName) .. "-type",
                Type = "event_button",
                Options = { ConfirmDialog = dialog },
            })

            D.expect(BlueprintPreprocessing:ValidateEventButtonSetting(setting)).toBe(false)
        end)

        D.test("TestInvalidEventButtonConfirmDialogMissing" .. fieldName, function()
            local dialog = table.deepcopy(validConfirmDialog)
            dialog[fieldName] = nil
            local setting = BlueprintSetting:New({
                Id = "test-event-button-invalid-confirm-missing-" .. string.lower(fieldName),
                Type = "event_button",
                Options = { ConfirmDialog = dialog },
            })

            D.expect(BlueprintPreprocessing:ValidateEventButtonSetting(setting)).toBe(false)
        end)
    end

    D.test("TestSanitizeBlueprintDispatchesEventButtonValidation", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = "invalid-event-button-dispatch",
                    Type = "event_button",
                    Options = { Cooldown = "not-a-number" },
                }),
            },
        })

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)).toBeNil()
    end)

    D.test("TestEventButtonWithNegativeCooldown", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-negative-cooldown",
            Type = "event_button",
            Options = {
                Cooldown = -1.0
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBe(true)
    end)
end)
