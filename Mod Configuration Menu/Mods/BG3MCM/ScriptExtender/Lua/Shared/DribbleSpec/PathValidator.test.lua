local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("PathValidator", { tags = { "validators", "unit" } }, function()
    -- Mutation runs list "client": a mutant can reach any write or send, so both are sandboxed deny-by-default.
    local sandbox = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        sandbox:Isolate(ctx)
    end)

    D.afterEach(function()
        sandbox:Restore()
    end)

    --- Both return values of IsValidPathComponent, so tests assert the message the user sees.
    ---@param str string|nil
    ---@return table result
    local function component(str)
        return { PathValidator:IsValidPathComponent(str) }
    end

    D.test("TestComponentAcceptsOrdinaryNames", function()
        for _, name in ipairs({ "Profile 1", "dynamic_settings.json", ".hidden", "CONSOLE", "COM10", "~a!" }) do
            D.expect(component(name)).toEqual({ true })
        end
    end)

    D.test("TestComponentRejectsEmpty", function()
        D.expect(component("")).toEqual({ false, "Path component cannot be empty" })
        D.expect(component(nil)).toEqual({ false, "Path component cannot be empty" })
    end)

    D.test("TestComponentRejectsLeadingOrTrailingWhitespace", function()
        local expected = { false, "Path component cannot start or end with whitespace" }
        D.expect(component(" name")).toEqual(expected)
        D.expect(component("name ")).toEqual(expected)
        D.expect(component("\tname")).toEqual(expected)
    end)

    D.test("TestComponentRejectsDotNames", function()
        local expected = { false, "Path component cannot be '.' or '..'" }
        D.expect(component(".")).toEqual(expected)
        D.expect(component("..")).toEqual(expected)
    end)

    D.test("TestComponentRejectsWindowsInvalidCharacters", function()
        for _, char in ipairs({ "<", ">", ":", '"', "/", "\\", "|", "?", "*" }) do
            D.expect(component("a" .. char .. "b"))
                .toEqual({ false, "Path contains invalid character: " .. char })
        end
    end)

    D.test("TestComponentRejectsNonPrintableAsciiBytes", function()
        local expected = { false, "Path can only contain ASCII letters, digits, and symbols" }
        D.expect(component("caf\195\169")).toEqual(expected)
        D.expect(component("a\tb")).toEqual(expected)
        D.expect(component("a\127b")).toEqual(expected)
    end)

    D.test("TestComponentRejectsWindowsReservedNames", function()
        D.expect(component("CON")).toEqual({ false, "Path cannot be a reserved name: CON" })
        D.expect(component("nul")).toEqual({ false, "Path cannot be a reserved name: NUL" })
        D.expect(component("Lpt9.txt")).toEqual({ false, "Path cannot be a reserved name: LPT9" })
        D.expect(component("com1.tar.gz")).toEqual({ false, "Path cannot be a reserved name: COM1" })
    end)

    D.test("TestComponentRejectsTrailingPeriod", function()
        D.expect(component("name.")).toEqual({ false, "Path cannot end with a period" })
        D.expect(component("CON.")).toEqual({ false, "Path cannot end with a period" })
    end)

    D.test("TestComponentLengthLimitIs255Bytes", function()
        D.expect(component(string.rep("a", 255))).toEqual({ true })
        D.expect(component(string.rep("a", 256)))
            .toEqual({ false, "Path component is too long (max 255 characters)" })
    end)
end)
