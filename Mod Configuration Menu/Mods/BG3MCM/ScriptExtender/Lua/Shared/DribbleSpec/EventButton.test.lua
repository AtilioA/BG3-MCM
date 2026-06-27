D.describe("Event Button Validation", { tags = { "event-button", "unit" } }, function()
    D.test("TestValidEventButtonMinimal", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-minimal",
            Type = "event_button",
            Options = {}
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeTruthy()
    end)

    D.test("TestValidEventButtonWithAllOptions", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-all-options",
            Type = "event_button",
            Options = {
                Cooldown = 5.0,
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
        D.expect(isValid).toBeTruthy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestInvalidEventButtonConfirmDialogFields", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-confirm-fields",
            Type = "event_button",
            Options = {
                ConfirmDialog = {
                    Title = 123,
                    Message = true,
                    ConfirmText = 456,
                    CancelText = 789
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestInvalidEventButtonConfirmDialogIncomplete", function(ctx)
        local setting = BlueprintSetting:New({
            Id = "test-event-button-invalid-confirm-incomplete",
            Type = "event_button",
            Options = {
                ConfirmDialog = {
                    Title = "Confirm Action",
                    Message = "Are you sure you want to perform this action?",
                }
            }
        })

        local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
        D.expect(isValid).toBeFalsy()
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
        D.expect(isValid).toBeTruthy()
    end)
end)
