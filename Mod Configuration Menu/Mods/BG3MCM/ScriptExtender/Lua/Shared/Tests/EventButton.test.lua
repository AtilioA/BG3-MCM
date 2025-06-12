TestSuite.RegisterTests("Event Button Validation", {
    "TestValidEventButtonMinimal",
    "TestValidEventButtonWithCooldown",
    "TestValidEventButtonWithIcon",
    "TestValidEventButtonWithConfirmDialog",
    "TestValidEventButtonWithAllOptions",
    "TestInvalidEventButtonCooldownType",
    "TestInvalidEventButtonIconType",
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

--- Test event button with valid icon
function TestValidEventButtonWithIcon()
    local setting = BlueprintSetting:New({
        Id = "test-event-button-icon",
        Type = "event_button",
        Options = {
            Icon = "Icon_Item_Scroll_01"
        }
    })

    local isValid = BlueprintPreprocessing:ValidateEventButtonSetting(setting)
    TestSuite.AssertTrue(isValid, "Event button with icon should be valid")
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
            Icon = "Icon_Item_Scroll_01",
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
    TestSuite.AssertFalse(isValid, "Event button with non-string icon should be invalid")
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
