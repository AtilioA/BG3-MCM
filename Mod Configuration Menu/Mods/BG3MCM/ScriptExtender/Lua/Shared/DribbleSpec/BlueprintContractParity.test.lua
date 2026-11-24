D.describe("BlueprintContract parity", { tags = { "contract", "unit" } }, function()
    D.test("SettingValidators keys equal BlueprintContract.SettingTypes union LegacyCompat.Types", function()
        local expected = {}
        for settingType, enabled in pairs(BlueprintContract.SettingTypes) do
            if enabled then
                expected[settingType] = true
            end
        end
        for legacyType, enabled in pairs(LegacyCompat.Types) do
            if enabled then
                expected[legacyType] = true
            end
        end

        for settingType, _ in pairs(expected) do
            D.expect(type(SettingValidators[settingType])).toBe("function")
        end
        for settingType, _ in pairs(SettingValidators) do
            D.expect(expected[settingType]).toBe(true)
        end
    end)
end)
