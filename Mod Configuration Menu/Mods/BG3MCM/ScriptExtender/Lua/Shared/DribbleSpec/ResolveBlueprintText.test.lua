local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewSandbox = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("VCString:ResolveBlueprintText", { tags = { "vcstring", "unit" } }, function()
    local sandbox = NewSandbox(StorageSyncService, JsonAdapter, SettingsService)
    local originalMods
    -- Real MCM handle for the setting's own name.
    local handle = "hea1f7a28g08d8g4fabga873gf7a6f364731e"
    local translated = Ext.Loca.GetTranslatedString(handle)

    D.beforeEach(function(ctx)
        originalMods = MCMAPI.mods
        sandbox:Isolate(ctx)
    end)

    D.afterEach(function()
        MCMAPI.mods = originalMods
        sandbox:Restore()
    end)

    D.test("returns translated handle when ignore_localization is false", function()
        D.expect(type(translated)).toBe("string")
        D.expect(translated).Not.toBe("")
        D.expect(translated).Not.toBe("Default Text")
        MCMAPI.mods = { [ModuleUUID] = { settingsValues = { ignore_localization = false } } }
        D.expect(VCString:ResolveBlueprintText(handle, "Default Text")).toBe(translated)
    end)

    D.test("returns fallback when ignore_localization is true and fallback is non-empty", function()
        MCMAPI.mods = { [ModuleUUID] = { settingsValues = { ignore_localization = true } } }
        D.expect(VCString:ResolveBlueprintText(handle, "Default Text")).toBe("Default Text")
    end)

    D.test("returns translated handle when ignore_localization is true but fallback is empty", function()
        MCMAPI.mods = { [ModuleUUID] = { settingsValues = { ignore_localization = true } } }
        D.expect(VCString:ResolveBlueprintText(handle, "")).toBe(translated)
        D.expect(VCString:ResolveBlueprintText(handle, nil)).toBe(translated)
    end)

    D.test("falls back to default text when handle is missing or untranslated", function()
        MCMAPI.mods = { [ModuleUUID] = { settingsValues = { ignore_localization = false } } }
        D.expect(VCString:ResolveBlueprintText(nil, "Default Text")).toBe("Default Text")
        D.expect(VCString:ResolveBlueprintText("h_missing", "Default Text")).toBe("Default Text")
    end)
end)
