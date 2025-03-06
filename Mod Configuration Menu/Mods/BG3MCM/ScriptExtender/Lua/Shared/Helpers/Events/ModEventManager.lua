ModEventManager = {}

local hasCheckedNetDeprecationWarning = false

local deprecatedEventNameMap = {
    MCM_Setting_Saved = "MCM_Saved_Setting",
    MCM_Setting_Reset = "MCM_Setting_Reset",
    MCM_All_Mod_Settings_Reset = "MCM_Reset_All_Mod_Settings",
    MCM_Profile_Created = "MCM_Created_Profile",
    MCM_Profile_Activated = "MCM_Set_Profile",
    MCM_Profile_Deleted = "MCM_Deleted_Profile",
    MCM_Mod_Tab_Added = "MCM_Mod_Tab_Added",
    MCM_Mod_Tab_Activated = "MCM_Mod_Tab_Activated",
    MCM_Mod_Subtab_Activated = "MCM_Mod_Subtab_Activated",
    MCM_Window_Ready = "MCM_Window_Ready",
    MCM_Window_Opened = "MCM_User_Opened_Window",
    MCM_Window_Closed = "MCM_User_Closed_Window"
}

--- Emits a mod event with the given data in the given event name. If bothContexts is true, the event will be emitted in both contexts.
--- @param eventName string The name of the event
--- @param eventData table The data to pass with the event
--- @param bothContexts? boolean Whether to emit the event in both contexts. Default is true.
local function emitModEvent(eventName, eventData, bothContexts)
    local function relayModEventEmissionToOtherContext(eventName, eventData)
        xpcall(function()
            if Ext.IsServer() then
                Ext.Net.BroadcastMessage(NetChannels.MCM_EMIT_ON_CLIENTS,
                    Ext.Json.Stringify({ eventName = eventName, eventData = eventData }))
            elseif Ext.IsClient() and not MCMProxy.IsMainMenu() then
                Ext.Net.PostMessageToServer(NetChannels.MCM_EMIT_ON_SERVER,
                    Ext.Json.Stringify({ eventName = eventName, eventData = eventData }))
            end
        end, function(err)
            MCMWarn(0, "Error while emitting mod event: " .. tostring(err))
        end)
    end

    if not ModEventManager:IsEventRegistered(eventName) then
        MCMWarn(0, "Event '" .. eventName .. "' is not registered.")
        MCMWarn(0, Ext.DumpExport(Ext.ModEvents['BG3MCM']))
        return
    end

    xpcall(function()
        MCMDebug(1, "Emitting mod event: " .. eventName .. " with data: " .. Ext.DumpExport(eventData))
    end, function(err)
        MCMWarn(0, "Error while emitting mod event: " .. tostring(err))
    end)

    Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)

    if bothContexts == true then
        relayModEventEmissionToOtherContext(eventName, eventData)
    end
end

local function broadcastDeprecatedNetMessage(eventName, eventData)
    local function createMetapayload(eventName, payload)
        return Ext.Json.Stringify({
            channel = eventName,
            payload = payload
        })
    end

    local function postNetMessageToServerAndClients(metapayload)
        local data = Ext.Json.Parse(metapayload)
        if not data or not data.channel or not data.payload then
            MCMWarn(0, "Invalid data received from metapayload.")
            return
        end

        -- Always be prepared for the worst
        xpcall(function()
            if Ext.IsServer() then
                Ext.Net.BroadcastMessage(data.channel, Ext.Json.Stringify(data.payload))
                Ext.Net.BroadcastMessage(NetChannels.MCM_RELAY_TO_SERVERS, metapayload)
            elseif Ext.IsClient() and not MCMProxy.IsMainMenu() then
                Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
                Ext.Net.PostMessageToServer(NetChannels.MCM_RELAY_TO_CLIENTS, metapayload)
            end
        end, function(err)
            MCMWarn(0, "Error while broadcasting or posting net message: " .. tostring(err))
        end)
    end

    local function prepareNetData(eventData)
        if not eventData or table.isEmpty(eventData) then
            eventData = {}
        end

        if not eventData.modUUID then
            eventData.modUUID = eventData.modGUID
        end

        if not eventData.modGUID then
            eventData.modGUID = eventData.modUUID
        end

        return eventData
    end

    ---
    local preparedNetData = prepareNetData(eventData)
    local deprecatedEventName = deprecatedEventNameMap[eventName] or eventName
    local metapayload = createMetapayload(deprecatedEventName, preparedNetData)

    if Ext.IsServer() then
        MCMDeprecation(2, "Broadcasting deprecated net message: " .. deprecatedEventName)
        postNetMessageToServerAndClients(metapayload)
    elseif not MCMProxy.IsMainMenu() then
        MCMDeprecation(2, "Posting deprecated net message to server: " .. deprecatedEventName)
        postNetMessageToServerAndClients(metapayload)
    end
end

function ModEventManager:IssueDeprecationWarning()
    if hasCheckedNetDeprecationWarning then return end

    -- Gets all the deprecated net listeners (e.g.: MCM_Saved_Setting) and their source files
    ---@return table<string, table<string, number>> listeners The mods using net listeners as mod events and the listeners' locations in the source files
    local function getDeprecatedNetListeners()
        local listeners = {}
        local deprecatedChannels = {
            -- Hardcoded because old mods will still use these even if I change in Channels.lua
            "MCM_Saved_Setting",
            "MCM_Setting_Updated",
            "MCM_Setting_Reset",
            "MCM_Reset_All_Mod_Settings",
            "MCM_Server_Created_Profile",
            "MCM_Server_Set_Profile",
            "MCM_Server_Deleted_Profile",
            "MCM_Mod_Tab_Added",
            "MCM_Window_Ready",
            "MCM_User_Opened_Window",
            "MCM_User_Closed_Window",
            "MCM_Mod_Tab_Activated",
            "MCM_Mod_Subtab_Activated"
        }

        for _, channel in ipairs(deprecatedChannels) do
            -- Thanks Norbyte for the industry secret
            for _i, listenerFunction in ipairs(Ext._Internal.EventManager.NetListeners[channel] or {}) do
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
            "%s, please update the code for %s in the following files:\n%s\n",
            modInfo.Author, modInfo.Name, table.concat(usageMessages, ",\n")
        )
    end

    local function handleDeprecatedNetListeners(deprecatedNetListeners)
        if table.isEmpty(deprecatedNetListeners) then return end

        local loadOrder = Ext.Mod.GetLoadOrder()
        if not loadOrder then return end

        local header =
        "Deprecated net message usage detected to simulate mod events. SE v18 introduced Mod Events for this purpose.\n"
        local footer =
        "See https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu#listening-to-mcm-events for more information.\n"
        local warningMessages = {}

        for _, modUUID in ipairs(loadOrder) do
            local modData = Ext.Mod.GetMod(modUUID)
            if not isValidModData(modData) then return end

            local modInfo = modData.Info
            local modDir = modInfo.Directory
            if deprecatedNetListeners[modDir] then
                table.insert(warningMessages, createWarningMessage(modInfo, deprecatedNetListeners[modDir]))
            end
        end

        if #warningMessages > 0 then
            MCMDeprecation(0, header .. table.concat(warningMessages, "\n") .. footer)
        end
    end

    handleDeprecatedNetListeners(getDeprecatedNetListeners())
end

--- Subscribe to a mod event
---@param eventName string The name of the event
---@param callback function The callback function to handle the event
function ModEventManager:Subscribe(eventName, callback)
    if not eventName or not callback then
        MCMWarn(0, "eventName and callback cannot be nil")
        error("eventName and callback cannot be nil")
    end
    if not Ext.ModEvents['BG3MCM'] or not Ext.ModEvents['BG3MCM'][eventName] then
        MCMWarn(0, "Event '" .. eventName .. "' is not registered.")
        error("Event '" .. eventName .. "' is not registered.")
    end

    MCMDebug(1, "Subscribing to mod event: " .. eventName)
    Ext.ModEvents['BG3MCM'][eventName]:Subscribe(callback)
end

function ModEventManager:IsEventRegistered(eventName)
    return Ext.ModEvents['BG3MCM'] and Ext.ModEvents['BG3MCM'][eventName]
end

--- Emit a mod event
---@param eventName string The name of the event
---@param eventData table The data to pass with the event
---@param bothContexts? boolean Whether to emit the event in both contexts. Default is true.
function ModEventManager:Emit(eventName, eventData, bothContexts)
    if not eventName then
        MCMWarn(0, "eventName cannot be nil")
        error("eventName cannot be nil")
    end

    emitModEvent(eventName, eventData, bothContexts)
    broadcastDeprecatedNetMessage(eventName, eventData)
end

return ModEventManager
