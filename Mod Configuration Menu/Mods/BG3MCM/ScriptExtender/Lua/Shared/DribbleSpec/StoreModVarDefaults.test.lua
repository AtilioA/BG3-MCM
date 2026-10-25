local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local AdapterFactory = Ext.Require("Shared/DynamicSettings/Factories/AdapterFactory.lua")

D.describe("Store ModVar defaults", { tags = { "store", "unit" } }, function()
    local VAR_NAME = "dribblespec_modvar_defaults"
    local previousSchema
    local previousStorageTypes

    D.beforeEach(function()
        previousSchema = SettingsService.schema[ModuleUUID]
        previousStorageTypes = SettingsService.varToStorageType[ModuleUUID]
        SettingsService.schema[ModuleUUID] = nil
        SettingsService.varToStorageType[ModuleUUID] = nil
    end)

    D.afterEach(function()
        SettingsService.schema[ModuleUUID] = previousSchema
        SettingsService.varToStorageType[ModuleUUID] = previousStorageTypes
    end)

    --- Isolate storage I/O while retaining the real client/server context.
    ---@param ctx table
    ---@param storageType string
    ---@param initialValue StorageValue
    ---@return table state
    local function isolateStorage(ctx, storageType, initialValue)
        local state = { value = initialValue, writes = 0, pending = {} }
        local adapter = AdapterFactory.GetAdapter(storageType)
        ctx.stub(adapter, "EnsureRegistered", function() return true end)
        ctx.stub(adapter, "RunWhenReady", function(_, fn)
            table.insert(state.pending, fn)
        end)
        ctx.stub(adapter, "GetValue", function() return state.value end)
        ctx.stub(adapter, "SetValue", function(_, _, value)
            state.writes = state.writes + 1
            state.value = value
        end)
        return state
    end

    for _, operation in ipairs({ "register", "promote" }) do
        local function initialize(storageType, storageConfig)
            local definition = { type = "boolean", default = true, storageConfig = storageConfig or { SyncToServer = true } }
            if operation == "register" then
                D.expect(SettingsService.Register(ModuleUUID, VAR_NAME, storageType, definition)).toBe(true)
            else
                SettingsService.RegisterDiscoveredVariable(ModuleUUID, VAR_NAME, storageType)
                SettingsService.PromoteVariable(ModuleUUID, VAR_NAME, storageType, definition)
            end
        end

        D.test(operation .. " seeds missing ModVars only on the server", function(ctx)
            local state = isolateStorage(ctx, "modvar", nil)
            initialize("modvar")
            D.expect(state.writes).toBe(0)
            for _, fn in ipairs(state.pending) do fn() end
            D.expect(state.writes).toBe(Ext.IsServer() and 1 or 0)
            if Ext.IsServer() then
                D.expect(state.value).toBe(true)
            else
                D.expect(state.value).toBeNil()
                D.expect(SettingsService.Get(ModuleUUID, VAR_NAME)).toBe(true)
            end
        end)

        D.test(operation .. " preserves restored false ModVars", function(ctx)
            local state = isolateStorage(ctx, "modvar", false)
            initialize("modvar")
            for _, fn in ipairs(state.pending) do fn() end
            D.expect(state.writes).toBe(0)
            D.expect(state.value).toBe(false)
        end)

        D.test(operation .. " preserves values restored before readiness", function(ctx)
            local state = isolateStorage(ctx, "modvar", nil)
            initialize("modvar")
            state.value = false
            for _, fn in ipairs(state.pending) do fn() end
            D.expect(state.writes).toBe(0)
            D.expect(state.value).toBe(false)
        end)

        D.test(operation .. " seeds client-only ModVars only on the client", function(ctx)
            local state = isolateStorage(ctx, "modvar", nil)
            initialize("modvar", { Server = false })
            for _, fn in ipairs(state.pending) do fn() end
            D.expect(state.writes).toBe(Ext.IsServer() and 0 or 1)
        end)

        D.test(operation .. " still seeds JSON defaults in both contexts", function(ctx)
            local state = isolateStorage(ctx, "json", nil)
            initialize("json")
            for _, fn in ipairs(state.pending) do fn() end
            D.expect(state.writes).toBe(1)
            D.expect(state.value).toBe(true)
        end)
    end

    D.test("promotion repairs invalid ModVars only on the server", function(ctx)
        local state = isolateStorage(ctx, "modvar", "invalid-boolean")
        SettingsService.RegisterDiscoveredVariable(ModuleUUID, VAR_NAME, "modvar")
        SettingsService.PromoteVariable(ModuleUUID, VAR_NAME, "modvar", { type = "boolean", default = true })
        for _, fn in ipairs(state.pending) do fn() end
        D.expect(state.writes).toBe(Ext.IsServer() and 1 or 0)
        D.expect(state.value).toBe(Ext.IsServer() and true or "invalid-boolean")
    end)
end)
