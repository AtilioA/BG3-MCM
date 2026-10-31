--- Create a test sandbox that isolates storage-sync state, file writes, network sends, notifications, timers, and ModVars.
--- Writes are deny-by-default: every Ext.IO write goes to an in-memory map, whatever the path.
---@param storageSyncService StorageSyncService
---@param jsonAdapter JsonStorageManager
---@param settingsService SettingsService
---@return table fixture
return function(storageSyncService, jsonAdapter, settingsService)
    local previousState
    local fixture = {}

    --- Replace test-owned state and stub writes, sends, mod events, notifications, timers, and ModVars for the current test.
    --- The test sandbox restores the stubs after afterEach, even when the test fails.
    ---@param ctx table DribbleSpec test context
    ---@return nil
    -- bg3-lint: allow BG3-ENGINE-WRITE -- a mutant can move a write to any path, so no wrapper or path prefix can contain it
    function fixture:Isolate(ctx)
        previousState = {
            cache = storageSyncService._cache,
            applyingRemote = storageSyncService._applyingRemote,
            jsonCache = jsonAdapter._cache,
            jsonFileNames = jsonAdapter._fileNames,
            settingsSchema = settingsService.schema,
            settingsVarToStorageType = settingsService.varToStorageType,
        }

        storageSyncService._cache = {}
        storageSyncService._applyingRemote = false
        jsonAdapter._cache = {}
        jsonAdapter._fileNames = {}
        settingsService.schema = {}
        settingsService.varToStorageType = {}

        local files = {}
        local realLoadFile = Ext.IO.LoadFile
        self.files = files
        self.sentToClients = {}
        self.sentToServer = {}
        self.bootstrapSends = {}
        self.emittedEvents = {}

        ctx.stub(Ext.IO, "SaveFile", function(path, content)
            files[path] = content
            return true
        end)
        ctx.stub(Ext.IO, "AppendFile", function(path, content)
            files[path] = (files[path] or realLoadFile(path) or "") .. content
            return true
        end)
        ctx.stub(Ext.IO, "LoadFile", function(path, ...)
            if files[path] ~= nil then
                return files[path]
            end
            return realLoadFile(path, ...)
        end)
        -- Sends are deny-by-default too: every channel's low-level sends and every raw Ext.Net post drop the message.
        local function drop() end
        for _, channel in pairs(NetChannels) do
            if type(channel) == "table" and channel.DoSendToServer then
                ctx.stub(channel, "DoSendToServer", drop)
                ctx.stub(channel, "DoSendToClient", drop)
            end
        end
        for name, fn in pairs(Ext.Net) do
            if type(fn) == "function" and (name:find("^Post") or name:find("^Broadcast")) then
                ctx.stub(Ext.Net, name, drop)
            end
        end
        ctx.stub(NetChannels.MCM_SERVER_SYNC_STORE_VALUE, "SendToClient", function(_channel, payload, userID)
            table.insert(self.sentToClients, { payload = payload, userID = userID })
        end)
        ctx.stub(NetChannels.MCM_CLIENT_SET_STORE_VALUE, "SendToServer", function(_channel, payload)
            table.insert(self.sentToServer, payload)
        end)
        ctx.stub(ChunkedNet, "SendJSONToUser", function(userID, channel, payload)
            table.insert(self.bootstrapSends, { userID = userID, channel = channel, payload = payload })
        end)
        ctx.stub(ModEventManager, "Emit", function(_manager, eventName, eventData, bothContexts)
            table.insert(self.emittedEvents, { name = eventName, data = eventData, bothContexts = bothContexts })
        end)

        self.notifications = {}
        ctx.stub(NotificationManager, "CreateIMGUINotification", function(_manager, id, severity, title, message, options)
            table.insert(self.notifications, { id = id, severity = severity, title = title, message = message, options = options })
        end)
        -- Timers are dropped so no callback outlives the test.
        -- Ext.OnNextTick sits on each mod's Ext proxy, which drops writes, so it cannot be stubbed.
        ctx.stub(Ext.Timer, "WaitFor", drop)
        ctx.stub(Ext.Timer, "WaitForRealtime", drop)

        -- ModVars live in a fake table per module.
        local modVars = {}
        self.modVars = modVars
        ctx.stub(Ext.Vars, "RegisterModVariable", function(moduleUUID)
            modVars[moduleUUID] = modVars[moduleUUID] or {}
        end)
        ctx.stub(Ext.Vars, "GetModVariables", function(moduleUUID)
            modVars[moduleUUID] = modVars[moduleUUID] or {}
            return modVars[moduleUUID]
        end)
        ctx.stub(Ext.Vars, "DirtyModVariables", drop)
        ctx.stub(Ext.Vars, "SyncModVariables", drop)
    end

    --- Stub connected users as users 1, 1, and 2, plus entities without a valid user ID.
    ---@param ctx table DribbleSpec test context
    ---@return nil
    -- bg3-lint: allow BG3-ENGINE-WRITE -- the user list is the engine read that getConnectedUserIDs filters; a single-user session cannot supply duplicates or invalid entities
    function fixture:StubConnectedUsers(ctx)
        ctx.stub(Ext.Entity, "GetAllEntitiesWithComponent", function()
            return {
                { UserReservedFor = { UserID = 1 } },
                { UserReservedFor = { UserID = 1 } },
                {},
                { UserReservedFor = { UserID = "x" } },
                { UserReservedFor = { UserID = 2 } },
            }
        end)
    end

    --- User IDs of the sends to clients, in send order.
    ---@return integer[] userIDs
    function fixture:SentUserIDs()
        local userIDs = {}
        for _, send in ipairs(self.sentToClients) do
            table.insert(userIDs, send.userID)
        end
        return userIDs
    end

    --- Restore live state.
    ---@return nil
    function fixture:Restore()
        if not previousState then
            return
        end

        storageSyncService._cache = previousState.cache
        storageSyncService._applyingRemote = previousState.applyingRemote
        jsonAdapter._cache = previousState.jsonCache
        jsonAdapter._fileNames = previousState.jsonFileNames
        settingsService.schema = previousState.settingsSchema
        settingsService.varToStorageType = previousState.settingsVarToStorageType
        previousState = nil
    end

    return fixture
end
