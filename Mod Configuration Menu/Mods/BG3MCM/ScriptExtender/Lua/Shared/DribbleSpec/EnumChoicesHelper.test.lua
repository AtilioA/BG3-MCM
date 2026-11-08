local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewSandbox = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("Enum choices", { tags = { "enum-choices", "unit" } }, function()
    local sandbox = NewSandbox(StorageSyncService, JsonAdapter, SettingsService)
    D.beforeEach(function(ctx) sandbox:Isolate(ctx) end)
    D.afterEach(function() sandbox:Restore() end)

    D.test("validates and copies choice arrays", function()
        D.expect(EnumChoicesHelper.AreChoicesValid(nil)).toBe(false)
        D.expect(EnumChoicesHelper.AreChoicesValid({ key = "x" })).toBe(false)
        D.expect(EnumChoicesHelper.AreChoicesValid({ "a", 2 })).toBe(false)
        D.expect(EnumChoicesHelper.AreChoicesValid({})).toBe(true)
        local input = { "a", "b" }
        D.expect(EnumChoicesHelper.AreChoicesValid(input)).toBe(true)
        local copy = EnumChoicesHelper.CopyChoices(input)
        D.expect(copy[1]).toBe("a")
        D.expect(copy[2]).toBe("b")
        copy[1] = "changed"
        D.expect(input[1]).toBe("a")
        D.expect(#EnumChoicesHelper.CopyChoices(nil)).toBe(0)
    end)

    D.test("applies choices and matching handles without retaining input arrays", function()
        local setting = BlueprintSetting:New({ Type = "enum", Options = { Other = 7 }, Handles = { NameHandle = "name" } })
        local choices, handles = { "a", "b" }, { "ha", "hb" }
        D.expect(EnumChoicesHelper.ApplyChoices(setting, choices, handles)).toBe(true)
        choices[1], handles[1] = "changed", "changed"
        D.expect(setting:GetOptions().Choices[1]).toBe("a")
        D.expect(setting:GetOptions().Other).toBe(7)
        D.expect(setting:GetOptions()._RuntimeChoicesInjected).toBe(true)
        D.expect(setting:GetHandles().ChoicesHandles[1]).toBe("ha")
        D.expect(setting:GetHandles().NameHandle).toBe("name")
        D.expect(EnumChoicesHelper.ApplyChoices(setting, { "c" }, { "x", "y" })).toBe(true)
        D.expect(setting:GetHandles().ChoicesHandles).toBe(nil)
        D.expect(EnumChoicesHelper.ApplyChoices(setting, { "d" })).toBe(true)
        D.expect(setting:GetHandles().ChoicesHandles).toBe(nil)
    end)

    D.test("sets freshly created options and handles when absent", function()
        local setting = {
            GetType = function() return "enum" end,
            GetOptions = function(self) return self.options end,
            SetOptions = function(self, value) self.options = value end,
            GetHandles = function(self) return self.handles end,
            SetHandles = function(self, value) self.handles = value end,
        }
        D.expect(EnumChoicesHelper.ApplyChoices(setting, { "a" }, { "handle" })).toBe(true)
        D.expect(setting.options.Choices[1]).toBe("a")
        D.expect(setting.handles.ChoicesHandles[1]).toBe("handle")
    end)

    D.test("rejects invalid applications without changing options", function()
        local setting = BlueprintSetting:New({ Type = "enum", Options = { Choices = { "old" } } })
        D.expect(EnumChoicesHelper.ApplyChoices(nil, {})).toBe(false)
        D.expect(EnumChoicesHelper.ApplyChoices(BlueprintSetting:New({ Type = "text" }), {})).toBe(false)
        D.expect(EnumChoicesHelper.ApplyChoices(setting, { 1 })).toBe(false)
        D.expect(setting:GetOptions().Choices[1]).toBe("old")
    end)

    D.test("checks values against static and dynamic choices", function()
        D.expect(EnumChoicesHelper.IsValueValid(nil, "x")).toBe(false)
        local setting = BlueprintSetting:New({ Type = "enum", Options = {} })
        D.expect(EnumChoicesHelper.IsValueValid(setting, "x")).toBe(false)
        setting:SetOptions({ Choices = { "a", "b" } })
        D.expect(EnumChoicesHelper.IsValueValid(setting, "a")).toBe(true)
        D.expect(EnumChoicesHelper.IsValueValid(setting, "x")).toBe(false)
        D.expect(EnumChoicesHelper.IsValueValid(setting, 1)).toBe(false)
        setting:SetOptions({ Choices = {}, Dynamic = false })
        D.expect(EnumChoicesHelper.IsValueValid(setting, "x")).toBe(true)
        setting:SetOptions({ Choices = { "a" }, Dynamic = true })
        D.expect(EnumChoicesHelper.IsValueValid(setting, "x")).toBe(true)
        D.expect(EnumChoicesHelper.IsValueValid(setting, 1)).toBe(false)
    end)

    D.test("resolves missing values using default then first choice", function()
        local setting = BlueprintSetting:New({ Type = "enum", Default = "b", Options = { Choices = { "a", "b" } } })
        D.expect(EnumChoicesHelper.ResolveValue(setting, "a")).toBe("a")
        D.expect(EnumChoicesHelper.ResolveValue(setting, "missing")).toBe("b")
        setting:SetDefault("missing")
        D.expect(EnumChoicesHelper.ResolveValue(setting, "missing")).toBe("a")
        setting:SetDefault(1)
        D.expect(EnumChoicesHelper.ResolveValue(setting, "missing")).toBe("a")
        setting:SetOptions({ Choices = {} })
        D.expect(EnumChoicesHelper.ResolveValue(setting, "current")).toBe("current")
        setting:SetOptions({})
        D.expect(EnumChoicesHelper.ResolveValue(setting, "current")).toBe("current")
    end)
end)
