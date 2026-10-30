D.describe("PathValidator", { tags = { "validators", "unit" } }, function()
    local WINDOWS, UNIX = true, false

    --- Both return values of IsValidPathComponent, so tests assert the message the user sees.
    ---@param str string|nil
    ---@param isWindows boolean
    ---@return table result
    local function component(str, isWindows)
        return { PathValidator:IsValidPathComponent(str, isWindows) }
    end

    D.test("TestComponentAcceptsOrdinaryNames", function()
        for _, name in ipairs({ "Profile 1", "dynamic_settings.json", ".hidden", "CONSOLE", "COM10", "~a!" }) do
            D.expect(component(name, WINDOWS)).toEqual({ true })
            D.expect(component(name, UNIX)).toEqual({ true })
        end
    end)

    D.test("TestComponentRejectsEmpty", function()
        D.expect(component("", WINDOWS)).toEqual({ false, "Path component cannot be empty" })
        D.expect(component(nil, UNIX)).toEqual({ false, "Path component cannot be empty" })
    end)

    D.test("TestComponentRejectsLeadingOrTrailingWhitespace", function()
        local expected = { false, "Path component cannot start or end with whitespace" }
        D.expect(component(" name", WINDOWS)).toEqual(expected)
        D.expect(component("name ", UNIX)).toEqual(expected)
        D.expect(component("\tname", UNIX)).toEqual(expected)
    end)

    D.test("TestComponentRejectsDotNames", function()
        local expected = { false, "Path component cannot be '.' or '..'" }
        D.expect(component(".", UNIX)).toEqual(expected)
        D.expect(component("..", UNIX)).toEqual(expected)
        D.expect(component("..", WINDOWS)).toEqual(expected)
    end)

    D.test("TestComponentRejectsWindowsInvalidCharacters", function()
        for _, char in ipairs({ "<", ">", ":", '"', "/", "\\", "|", "?", "*" }) do
            D.expect(component("a" .. char .. "b", WINDOWS))
                .toEqual({ false, "Path contains invalid character: " .. char })
        end
    end)

    D.test("TestComponentRejectsOnlySlashOnUnix", function()
        D.expect(component("a/b", UNIX)).toEqual({ false, "Path contains invalid character: /" })
        D.expect(component("a:b", UNIX)).toEqual({ true })
        D.expect(component("a\\b", UNIX)).toEqual({ true })
    end)

    D.test("TestComponentRejectsNonPrintableAsciiBytes", function()
        local expected = { false, "Path can only contain ASCII letters, digits, and symbols" }
        D.expect(component("caf\195\169", WINDOWS)).toEqual(expected)
        D.expect(component("caf\195\169", UNIX)).toEqual(expected)
        D.expect(component("a\tb", WINDOWS)).toEqual(expected)
        D.expect(component("a\127b", UNIX)).toEqual(expected)
    end)

    D.test("TestComponentRejectsWindowsReservedNames", function()
        D.expect(component("CON", WINDOWS)).toEqual({ false, "Path cannot be a reserved name: CON" })
        D.expect(component("nul", WINDOWS)).toEqual({ false, "Path cannot be a reserved name: NUL" })
        D.expect(component("Lpt9.txt", WINDOWS)).toEqual({ false, "Path cannot be a reserved name: LPT9" })
        D.expect(component("com1.tar.gz", WINDOWS)).toEqual({ false, "Path cannot be a reserved name: COM1" })
        D.expect(component("CON", UNIX)).toEqual({ true })
    end)

    D.test("TestComponentRejectsTrailingPeriodOnWindows", function()
        D.expect(component("name.", WINDOWS)).toEqual({ false, "Path cannot end with a period" })
        D.expect(component("CON.", WINDOWS)).toEqual({ false, "Path cannot end with a period" })
        D.expect(component("name.", UNIX)).toEqual({ true })
    end)

    D.test("TestComponentLengthLimitIs255Bytes", function()
        local expected = { false, "Path component is too long (max 255 characters)" }
        D.expect(component(string.rep("a", 255), WINDOWS)).toEqual({ true })
        D.expect(component(string.rep("a", 256), WINDOWS)).toEqual(expected)
        D.expect(component(string.rep("a", 256), UNIX)).toEqual(expected)
    end)

    D.test("TestPathAcceptsNestedComponents", function()
        D.expect({ PathValidator:IsValidPath("Profiles/Default/file.json") }).toEqual({ true })
        D.expect({ PathValidator:IsValidPath("Profiles\\Default") }).toEqual({ true })
    end)

    D.test("TestPathRejectsEmptyOrInvalidComponent", function()
        D.expect({ PathValidator:IsValidPath("") }).toEqual({ false, "Path cannot be empty" })
        D.expect({ PathValidator:IsValidPath("Profiles/CON/file.json") }).toEqual({
            false,
            "Invalid path component for Windows: CON (Path cannot be a reserved name: CON)",
        })
    end)
end)
