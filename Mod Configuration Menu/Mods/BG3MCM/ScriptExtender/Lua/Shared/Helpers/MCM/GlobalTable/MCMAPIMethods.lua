-- Contains the API methods that will be injected into the MCM table

local MCMAPIImplementations = Ext.Require(
    "Shared/Helpers/MCM/GlobalTable/MCMAPIImplementations.lua")

local MCMAPIMethods = {}

--- Helper function to create a client-only method stub
---@param methodPath string The full path of the method (e.g., 'EventButton.SetDisabled')
---@return function - A function that throws an error if called on the server
local function createClientOnlyStub(methodPath)
    return function(...)
        if Ext.IsServer() then
            error(string.format(
                "MCM API Error: Method '%s' is client-side only and cannot be called from the server context. " ..
                "Please ensure this method is only called from client-side code.", methodPath), 2)
        end
        return nil
    end
end

--- Inject client-only method stubs into the mod table for server context
---@param modTable table The mod table to inject stubs into
---@param originalModUUID string The UUID of the mod
local function injectClientOnlyStubs(modTable, originalModUUID)
    if not Ext.IsServer() then return end

    for methodPath, _ in pairs(MCMAPIImplementations.CLIENT_ONLY_METHODS) do
        local parts = {}
        for part in string.gmatch(methodPath, "([^.]+)") do
            table.insert(parts, part)
        end

        local target = modTable.MCM or {}
        for i = 1, #parts - 1 do
            target[parts[i]] = target[parts[i]] or {}
            target = target[parts[i]]
        end

        target[parts[#parts]] = createClientOnlyStub(methodPath)
    end
end

--- Create and inject all MCM API methods into a mod's table
---@param originalModUUID string The UUID of the mod that will receive the API methods
---@param modTable? table Optional mod table to inject methods into directly
---@return table MCMInstance The table containing all API methods
function MCMAPIMethods.createMCMAPIMethods(originalModUUID, modTable)
    local MCMInstance = modTable and modTable.MCM or {}

    -- Initialize sub-tables
    MCMInstance.Keybinding = MCMInstance.Keybinding or {}
    MCMInstance.EventButton = MCMInstance.EventButton or {}
    MCMInstance.List = MCMInstance.List or {}
    MCMInstance.Choices = MCMInstance.Choices or {}
    MCMInstance.Validation = MCMInstance.Validation or {}

    -- Create and inject core methods
    local coreMethods = MCMAPIImplementations.createCoreMethods(originalModUUID)
    for k, v in pairs(coreMethods) do
        MCMInstance[k] = v
    end

    -- Create and inject API modules
    MCMInstance.Keybinding = MCMAPIImplementations.createKeybindingAPI(originalModUUID)
    MCMInstance.List = MCMAPIImplementations.createListAPI(originalModUUID)
    MCMInstance.Choices = MCMAPIImplementations.createChoicesAPI(originalModUUID)
    MCMInstance.Validation = MCMAPIImplementations.createValidationAPI(originalModUUID)
    MCMInstance.EventButton = MCMAPIImplementations.createEventButtonAPI(originalModUUID)
    MCMInstance.Store = MCMAPIImplementations.createStoreAPI(originalModUUID)

    -- Add deprecated methods for backward compatibility
    MCMAPIImplementations.addDeprecatedMethods(MCMInstance, originalModUUID)

    -- Add client-only methods
    MCMAPIImplementations.addClientOnlyMethods(MCMInstance, originalModUUID)

    -- Inject client-only stubs if on server
    injectClientOnlyStubs({ MCM = MCMInstance }, originalModUUID)

    return MCMInstance
end

return MCMAPIMethods
