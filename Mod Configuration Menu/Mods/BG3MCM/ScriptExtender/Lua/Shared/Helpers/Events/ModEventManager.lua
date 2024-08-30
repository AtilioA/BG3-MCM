ModEventManager = {}

local hasCheckedNetDeprecationWarning = false

function ModEventManager:IssueDeprecationWarning()
    if hasCheckedNetDeprecationWarning then return end

    -- Gets all the deprecated net listeners (MCM_Saved_Setting) and their source files
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

--- Preprocess the event data for (deprecated) net messages
--- Currently, only makes sure modUUID and modGUID are present, for backwards compatibility
local function prepareNetData(eventData)
    if not eventData then
        eventData = {}
    end

    if not eventData.modUUID then
        eventData.modUUID = eventData.modGUID
    end

    if not eventData.modGUID then
        eventData.modGUID = eventData.modUUID
    end
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

function ModEventManager:IsEventRegistered(eventName)
    return Ext.ModEvents['BG3MCM'] and Ext.ModEvents['BG3MCM'][eventName]
end

--- Emit a mod event
---@param eventName string The name of the event
---@param eventData table The data to pass with the event
function ModEventManager:Emit(eventName, eventData)
    if not eventName then
        MCMDebug(0, "eventName cannot be nil")
        error("eventName cannot be nil")
    end

    if not self:IsEventRegistered(eventName) then
        MCMWarn(0, "Event '" .. eventName .. "' is not registered.")
        MCMWarn(0, Ext.DumpExport(Ext.ModEvents['BG3MCM']))
        return
    end

    MCMDebug(1, "Emitting mod event: " .. eventName)
    Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)

    local preparedNetData = prepareNetData(eventData)
    if (Ext.IsServer()) then
        MCMDebug(2, "Broadcasting deprecated net message: " .. eventName)
        Ext.Net.BroadcastMessage(eventName, Ext.Json.Stringify(preparedNetData))
    else
        MCMDebug(2, "Posting deprecated net message to server: " .. eventName)
        Ext.Net.PostMessageToServer(eventName, Ext.Json.Stringify(preparedNetData))
    end
end

return ModEventManager
