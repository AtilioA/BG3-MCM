ModEventManager = {}

local hasCheckedNetDeprecationWarning = false

function ModEventManager:IssueDeprecationWarning()
    if hasCheckedNetDeprecationWarning then return end

    -- Gets all the deprecated net listeners (MCM_Saved_Setting) and their source files
    ---@return table<string, table<string, number>> listeners The mods using net listeners as mod events and the listeners' locations in the source files
    local function getDeprecatedNetListeners()
        local listeners = {}
        -- Thanks Norbyte for the industry secret
        for _i, listenerFunction in ipairs(Ext._Internal.EventManager.NetListeners.MCM_Saved_Setting) do
            local listenerInfo = debug.getinfo(listenerFunction)

            local source = listenerInfo.source
            -- First directory is the mod directory
            local modDir = source:match("([^/]+)/")
            if not modDir then
                return listeners
            end
            if not listeners[modDir] then
                listeners[modDir] = {}
            end

            table.insert(listeners[modDir], {
                source = source,
                line = listenerInfo.linedefined
            })
        end
        return listeners
    end

    local function isValidModData(modData)
        return modData and modData.Info and modData.Info.Author and modData.Info.Name and modData.Info.Directory
    end

    local function createWarningMessage(modInfo, usages)
        local usageMessages = {}
        for _, usage in ipairs(usages) do
            table.insert(usageMessages, string.format("source: %s | line: %d", usage.source, usage.line))
        end
        return string.format(
            "Deprecated net message usage detected to simulate mod events. SE v18 introduced Mod Events for this purpose.\n%s, please update the code for %s in the following files:\n%s\nSee https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu#listening-to-mcm-events for more information.\n",
            modInfo.Author, modInfo.Name, table.concat(usageMessages, ",\n")
        )
    end

    local function handleDeprecatedNetListeners(deprecatedNetListeners)
        if table.isEmpty(deprecatedNetListeners) then return end

        local loadOrder = Ext.Mod.GetLoadOrder()
        if not loadOrder then return end

        for _, modUUID in ipairs(loadOrder) do
            local modData = Ext.Mod.GetMod(modUUID)
            if not isValidModData(modData) then return end

            local modInfo = modData.Info
            local modDir = modInfo.Directory
            if deprecatedNetListeners[modDir] then
                local warningMessage = createWarningMessage(modInfo, deprecatedNetListeners[modDir])
                MCMWarn(0, warningMessage)
            end
        end
    end

    handleDeprecatedNetListeners(getDeprecatedNetListeners())
end

-- Ext.Timer.WaitFor(2000, function()
--     ModEventManager:IssueDeprecationWarning()
-- end)

--- Register a new mod event
---@param eventName string The name of the event
function ModEventManager:RegisterEvent(eventName)
    if not eventName then
        MCMDebug(0, "eventName cannot be nil")
        error("eventName cannot be nil")
    end
    MCMDebug(1, "Registering mod event: " .. eventName)
    Ext.RegisterModEvent('BG3MCM', eventName)
end

--- Subscribe to a mod event
---@param eventName string The name of the event
---@param callback function The callback function to handle the event
function ModEventManager:Subscribe(eventName, callback)
    if not eventName or not callback then
        MCMDebug(0, "eventName and callback cannot be nil")
        error("eventName and callback cannot be nil")
    end
    if not Ext.ModEvents['BG3MCM'] or not Ext.ModEvents['BG3MCM'][eventName] then
        MCMDebug(0, "Event '" .. eventName .. "' is not registered.")
        error("Event '" .. eventName .. "' is not registered.")
    end

    MCMDebug(1, "Subscribing to mod event: " .. eventName)
    Ext.ModEvents['BG3MCM'][eventName]:Subscribe(callback)
end

--- Trigger a mod event
---@param eventName string The name of the event
---@param eventData table The data to pass with the event
function ModEventManager:Trigger(eventName, eventData)
    if not eventName then
        MCMDebug(0, "eventName cannot be nil")
        error("eventName cannot be nil")
    end
    if not Ext.ModEvents['BG3MCM'] or not Ext.ModEvents['BG3MCM'][eventName] then
        MCMDebug(1, "Registering event '" .. eventName .. "' because it was not found.")
        -- Register the event if it does not exist
        self:RegisterEvent(eventName)
    end

    MCMDebug(1, "Triggering mod event: " .. eventName .. " with data:" .. Ext.DumpExport(eventData))
    Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)

    -- DEPRECATED: Use net messages for backward compatibility
    local deprecatedEventData = setmetatable(eventData, {
        __index = function(t, key)
            print("Metamethod __index is being called for key:", key)
            MCMWarn(0,
                "Net messages usage for mod events is deprecated. SE v18 introduced Mod Events for this purpose. Please update your code.\nSee https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu#listening-to-mcm-events for more information.")
            return rawget(t, key)
        end
    })

    if (Ext.IsServer()) then
        MCMDebug(1, "Broadcasting deprecated net message: " .. eventName)
        MCMDebug(1, Ext.DumpExport(deprecatedEventData))
        Ext.Net.BroadcastMessage(eventName, Ext.Json.Stringify(deprecatedEventData))
    else
        MCMDebug(1, "Posting deprecated net message to server: " .. eventName)
        MCMDebug(1, Ext.DumpExport(deprecatedEventData))
        Ext.Net.PostMessageToServer(eventName, Ext.Json.Stringify(deprecatedEventData))
    end
end

-- -- Table to keep track of functions that have already been warned
-- local warnedFunctions = {}

-- -- Function to wrap the original listener with a deprecation warning
-- ---@param originalFunction function The original listener function
-- local function wrapWithDeprecationWarning(originalFunction)
--     return function(...)
--         _D(
--             "Net messages usage for mod events is deprecated. SE v18 introduced Mod Events for this purpose. Please update your code.\nSee https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu#listening-to-mcm-events for more information.")
--         return originalFunction(...)
--     end
-- end

-- Ext.Timer.WaitFor(1000, function()
--     -- Iterate over all net listeners
--     for i, listenerFunction in ipairs(Ext._Internal.EventManager.NetListeners.MCM_Saved_Setting) do
--         -- Wrap the original function with the deprecation warning
--         local wrappedFunction = wrapWithDeprecationWarning(listenerFunction)
--         Ext._Internal.EventManager.NetListeners.MCM_Saved_Setting[i] = wrappedFunction
--         -- Check if the function has actually changed
--         if wrappedFunction == Ext._Internal.EventManager.NetListeners.MCM_Saved_Setting[i] then
--             print("Function at index " .. i .. " has changed.")
--             Ext._Internal.EventManager.NetListeners.MCM_Saved_Setting[i] = wrappedFunction
--         else
--             print("Function at index " .. i .. " has not changed.")
--         end
--     end
-- end)

return ModEventManager
