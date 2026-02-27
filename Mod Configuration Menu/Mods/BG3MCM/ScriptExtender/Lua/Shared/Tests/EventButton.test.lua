TestSuite.RegisterTests("Event Button Validation", {
    "TestValidEventButtonMinimal",
    "TestValidEventButtonWithCooldown",
    "TestValidEventButtonWithoutIcon",
    "TestValidEventButtonWithIcon",
    "TestValidEventButtonWithIconSize",
    "TestValidEventButtonWithConfirmDialog",
    "TestValidEventButtonWithAllOptions",
    "TestInvalidEventButtonCooldownType",
    "TestInvalidEventButtonIconType",
    "TestInvalidEventButtonIconNameMissing",
    "TestInvalidEventButtonIconNameEmpty",
    "TestInvalidEventButtonIconSizeType",
    "TestInvalidEventButtonIconSizeMissingFields",
    "TestInvalidEventButtonConfirmDialogType",
    "TestInvalidEventButtonConfirmDialogIncomplete",
    "TestInvalidEventButtonConfirmDialogFields",
    "TestEventButtonWithNegativeCooldown"
})

--- Test a minimal valid event button with no options
function TestValidEventButtonMinimal()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-minimal",
        Type = "event_button",
        Options = {}
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertTrue(isValid, "Minimal event button should be valid")
end

--- Test event button with valid cooldown
function TestValidEventButtonWithCooldown()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-cooldown",
        Type = "event_button",
        Options = {
            Cooldown = 5.0
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertTrue(isValid, "Event button with cooldown should be valid")
end

--- Test event button remains valid when Icon is omitted
function TestValidEventButtonWithoutIcon()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-no-icon",
        Type = "event_button",
        Options = {
            Cooldown = 1.0,
            Label = "Run Action"
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertTrue(isValid, "Event button without icon should be valid")
end

--- Test event button with valid icon
function TestValidEventButtonWithIcon()
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
    TestSuite.AssertTrue(isValid, "Event button with icon should be valid")
end

--- Test event button with valid icon and explicit size
function TestValidEventButtonWithIconSize()
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
    TestSuite.AssertTrue(isValid, "Event button with icon size should be valid")
end

--- Test event button with valid confirm dialog
function TestValidEventButtonWithConfirmDialog()
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
    TestSuite.AssertTrue(isValid, "Event button with confirm dialog should be valid")
end

--- Test event button with all possible options
function TestValidEventButtonWithAllOptions()
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
    TestSuite.AssertTrue(isValid, "Event button with all options should be valid")
end

--- Test event button with invalid cooldown type
function TestInvalidEventButtonCooldownType()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-invalid-cooldown",
        Type = "event_button",
        Options = {
            Cooldown = "not-a-number"
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertFalse(isValid, "Event button with non-number cooldown should be invalid")
end

--- Test event button with invalid icon type
function TestInvalidEventButtonIconType()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-invalid-icon",
        Type = "event_button",
        Options = {
            Icon = 12345
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertFalse(isValid, "Event button with non-object icon should be invalid")
end

--- Test event button with icon object but missing Name
function TestInvalidEventButtonIconNameMissing()
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
    TestSuite.AssertFalse(isValid, "Event button with icon missing Name should be invalid")
end

--- Test event button with icon object and empty Name
function TestInvalidEventButtonIconNameEmpty()
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
    TestSuite.AssertFalse(isValid, "Event button with empty icon Name should be invalid")
end

--- Test event button with invalid icon size type
function TestInvalidEventButtonIconSizeType()
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
    TestSuite.AssertFalse(isValid, "Event button with non-object icon Size should be invalid")
end

--- Test event button with icon size missing required numeric fields
function TestInvalidEventButtonIconSizeMissingFields()
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
    TestSuite.AssertFalse(isValid, "Event button with incomplete icon Size should be invalid")
end

--- Test event button with invalid confirm dialog type
function TestInvalidEventButtonConfirmDialogType()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-invalid-confirm-type",
        Type = "event_button",
        Options = {
            ConfirmDialog = "not-a-table"
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertFalse(isValid, "Event button with non-table confirm dialog should be invalid")
end

--- Test event button with invalid confirm dialog fields
function TestInvalidEventButtonConfirmDialogFields()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-invalid-confirm-fields",
        Type = "event_button",
        Options = {
            ConfirmDialog = {
                Title = 123,       -- Invalid type
                Message = true,    -- Invalid type
                ConfirmText = 456, -- Invalid type
                CancelText = 789   -- Invalid type
            }
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertFalse(isValid, "Event button with invalid confirm dialog fields should be invalid")
end

--- Test event button with incomplete confirm dialog
function TestInvalidEventButtonConfirmDialogIncomplete()
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
    TestSuite.AssertFalse(isValid, "Event button with incomplete confirm dialog should be invalid")
end

--- Test event button with negative cooldown (should be valid as it disables the button)
function TestEventButtonWithNegativeCooldown()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-negative-cooldown",
        Type = "event_button",
        Options = {
            Cooldown = -1.0
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertTrue(isValid, "Event button with negative cooldown should be valid")
end
