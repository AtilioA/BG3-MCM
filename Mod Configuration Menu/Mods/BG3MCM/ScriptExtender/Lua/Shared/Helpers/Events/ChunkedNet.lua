-- Reusable chunked net messaging utilities for large payloads.
-- Provides server-side send helpers, client-side reassembly with handler dispatch, and request/reply support.

---@class MCMChunkInitPayload
---@field id string
---@field targetChannel string
---@field totalSize integer
---@field chunkSize integer
---@field totalChunks integer

---@class MCMChunkPartPayload
---@field id string
---@field index integer
---@field data string

---@class MCMChunkEndPayload
---@field id string

---@class MCMChunkTransferState
---@field parts table<integer, string>
---@field received integer
---@field targetChannel? string
---@field totalSize? integer
---@field chunkSize? integer
---@field totalChunks? integer

---@alias MCMChunkedHandler fun(payload:string)

ChunkedNet = ChunkedNet or {}

-- Conservative thresholds to avoid Script Extender ~1MB cap
ChunkedNet.DIRECT_THRESHOLD_BYTES = 800 * 1024
ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES = 800 * 1024

---Generate a transfer identifier.
---@return string
local function _makeTransferId()
  ChunkedNet._counter = (ChunkedNet._counter or 0) + 1
  -- TODO: use a better random prefix (UUID?)
  return tostring(math.random(1000000000000)) .. "-" .. tostring(ChunkedNet._counter)
end

---Convert a payload into a JSON string when needed.
---@param payload table
---@param callerName string
---@return string|nil
local function _coerceJSONString(payload, callerName)
  if type(payload) == "string" then
    return payload
  end

  local ok, jsonStr = pcall(Ext.Json.Stringify, payload)
  if not ok or type(jsonStr) ~= "string" then
    MCMWarn(0, "%s: failed to serialize payload to JSON", callerName)
    return nil
  end

  return jsonStr
end

---Resolve a NetChannel object to its canonical channel identifier.
---@param channel any
---@param callerName string
---@return string|nil
local function _getChannelId(channel, callerName)
  if type(channel) == "string" then
    MCMWarn(0,
      "%s: expected NetChannel object from Ext.Net.CreateChannel(), got legacy string '%s'", callerName, channel)
    return nil
  end

  local channelType = type(channel)
  if channelType ~= "table" and channelType ~= "userdata" then
    MCMWarn(0, "%s: expected NetChannel object, got %s", callerName, channelType)
    return nil
  end

  if not VCString:IsNonEmptyString(channel.Channel) then
    MCMWarn(0, "%s: NetChannel is missing a valid Channel field", callerName)
    return nil
  end

  if not VCString:IsNonEmptyString(channel.Module) then
    MCMWarn(0, "%s: NetChannel '%s' is missing a valid Module field", callerName, channel.Channel)
  end

  return channel.Channel
end

---Build an internal handler id for chunked request/reply responses.
---@param channelId string
---@param transferId string
---@return string
local function _makeRequestReplyHandlerId(channelId, transferId)
  return "ChunkedNet_RequestReply:" .. channelId .. ":" .. transferId
end

---Compute total chunk count and log a level-1 debug message in KB.
---@param targetChannelId string
---@param totalSize integer
---@param chunkSize integer
---@param isBroadcast boolean
---@return integer
local function _computeAndLogChunking(targetChannelId, totalSize, chunkSize, isBroadcast)
  local totalChunks = math.ceil(totalSize / chunkSize)
  local totalSizeKB = totalSize / 1024
  local chunkSizeKB = chunkSize / 1024

  if isBroadcast then
    MCMDebug(1,
      "ChunkedNet: Broadcast payload for '%s' is %.1f KB; chunking into %d parts (chunkSize=%.1f KB).",
      targetChannelId,
      totalSizeKB,
      totalChunks,
      chunkSizeKB
    )
  else
    MCMDebug(1,
      "ChunkedNet: Payload for '%s' is %.1f KB; chunking into %d parts (chunkSize=%.1f KB).",
      targetChannelId,
      totalSizeKB,
      totalChunks,
      chunkSizeKB
    )
  end

  return totalChunks
end

---Send a chunked payload to a specific user.
---@param userID integer
---@param targetChannelId string
---@param jsonStr string
---@param transferId? string
---@return boolean
local function _sendChunkedToUser(userID, targetChannelId, jsonStr, transferId)
  local id = transferId or _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(targetChannelId, totalSize, chunkSize, false)

  -- INIT
  NetChannels.MCM_CHUNK_INIT:SendToClient({
    id = id,
    targetChannel = targetChannelId,
    totalSize = totalSize,
    chunkSize = chunkSize,
    totalChunks = totalChunks,
  }, userID)

  -- PARTS
  local index = 1
  local pos = 1
  while pos <= totalSize do
    local nextPos = math.min(pos + chunkSize - 1, totalSize)
    local data = string.sub(jsonStr, pos, nextPos)

    NetChannels.MCM_CHUNK_PART:SendToClient({
      id = id,
      index = index,
      data = data,
    }, userID)

    index = index + 1
    pos = nextPos + 1
  end

  NetChannels.MCM_CHUNK_END:SendToClient({ id = id }, userID)
  return true
end

---Broadcast a chunked payload to all clients.
---@param targetChannelId string
---@param jsonStr string
---@param transferId? string
---@return boolean
local function _broadcastChunked(targetChannelId, jsonStr, transferId)
  local id = transferId or _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(targetChannelId, totalSize, chunkSize, true)

  NetChannels.MCM_CHUNK_INIT:Broadcast({
    id = id,
    targetChannel = targetChannelId,
    totalSize = totalSize,
    chunkSize = chunkSize,
    totalChunks = totalChunks,
  })

  local index = 1
  local pos = 1
  while pos <= totalSize do
    local nextPos = math.min(pos + chunkSize - 1, totalSize)
    local data = string.sub(jsonStr, pos, nextPos)

    NetChannels.MCM_CHUNK_PART:Broadcast({
      id = id,
      index = index,
      data = data,
    })

    index = index + 1
    pos = nextPos + 1
  end

  NetChannels.MCM_CHUNK_END:Broadcast({ id = id })
  return true
end

---Send a JSON string or table payload to a specific user, chunking if too large.
---@param userID integer
---@param targetChannel NetChannel
---@param payload table
---@return boolean
function ChunkedNet.SendJSONToUser(userID, targetChannel, payload)
  if type(userID) ~= "number" then
    MCMWarn(0, "ChunkedNet.SendJSONToUser: expected numeric userID")
    return false
  end

  local channelId = _getChannelId(targetChannel, "ChunkedNet.SendJSONToUser")
  if not channelId then
    return false
  end

  local jsonStr = _coerceJSONString(payload, "ChunkedNet.SendJSONToUser")
  if not jsonStr then
    return false
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    targetChannel:SendToClient(jsonStr, userID)
    return true
  end

  return _sendChunkedToUser(userID, channelId, jsonStr)
end

---Broadcast a JSON string or table payload to all clients, chunking if too large.
---@param targetChannel NetChannel
---@param payload table
---@return boolean
function ChunkedNet.SendJSONToAll(targetChannel, payload)
  local channelId = _getChannelId(targetChannel, "ChunkedNet.SendJSONToAll")
  if not channelId then
    return false
  end

  local jsonStr = _coerceJSONString(payload, "ChunkedNet.SendJSONToAll")
  if not jsonStr then
    return false
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    targetChannel:Broadcast(jsonStr)
    return true
  end

  return _broadcastChunked(channelId, jsonStr)
end

-- Request/Reply pattern for large payloads.
-- Server collects all chunks, then returns complete response via SetRequestHandler.
ChunkedNet.RequestReply = ChunkedNet.RequestReply or {}

---Set up a request handler that can send chunked responses.
---@param channel NetChannel
---@param handlerFn fun(requestData:any, userID:integer):any
function ChunkedNet.RequestReply.SetHandler(channel, handlerFn)
  local channelId = _getChannelId(channel, "ChunkedNet.RequestReply.SetHandler")
  if not channelId then
    return
  end

  if type(handlerFn) ~= "function" then
    MCMWarn(0, "ChunkedNet.RequestReply.SetHandler: handlerFn must be a function")
    return
  end

  channel:SetRequestHandler(function(requestData, userID)
    local ok, result = xpcall(function()
      return handlerFn(requestData, userID)
    end, function(err)
      return { success = false, error = tostring(err) }
    end)

    if not ok then
      return { success = false, error = tostring(result) }
    end

    if type(result) == "string" and #result > ChunkedNet.DIRECT_THRESHOLD_BYTES then
      local transferId = _makeTransferId()
      local responseHandlerId = _makeRequestReplyHandlerId(channelId, transferId)
      local sent = _sendChunkedToUser(userID, responseHandlerId, result, transferId)

      if not sent then
        return { success = false, error = "Failed to send chunked response" }
      end

      return {
        success = true,
        chunked = true,
        transferId = transferId,
        handlerId = responseHandlerId,
        totalChunks = math.ceil(#result / ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES),
      }
    end

    if type(result) == "table" and result.success ~= nil then
      return result
    end

    return { success = true, data = result }
  end)
end

---Request data that may be chunked.
---@param channel NetChannel
---@param requestData any
---@param onResponse fun(response:any)
function ChunkedNet.RequestReply.Request(channel, requestData, onResponse)
  local channelId = _getChannelId(channel, "ChunkedNet.RequestReply.Request")
  if not channelId then
    if type(onResponse) == "function" then
      onResponse({ success = false, error = "Invalid request channel" })
    end
    return
  end

  if type(onResponse) ~= "function" then
    MCMWarn(0, "ChunkedNet.RequestReply.Request: onResponse must be a function")
    return
  end

  channel:RequestToServer(requestData, function(response)
    if type(response) ~= "table" then
      MCMWarn(0, "ChunkedNet.RequestReply.Request: received invalid response payload")
      onResponse({ success = false, error = "Invalid response payload" })
      return
    end

    if response.chunked then
      local handlerId = response.handlerId
      if not VCString:IsNonEmptyString(handlerId) and VCString:IsNonEmptyString(response.transferId) then
        handlerId = _makeRequestReplyHandlerId(channelId, response.transferId)
      end

      if not VCString:IsNonEmptyString(handlerId) then
        MCMWarn(0, "ChunkedNet.RequestReply.Request: chunked response is missing handler metadata")
        onResponse({ success = false, error = "Missing chunked response handler metadata" })
        return
      end

      local didRegister = ChunkedNet.Client._RegisterInternalHandler(handlerId, function(assembledData)
        ChunkedNet.Client._handlers[handlerId] = nil
        local ok, data = pcall(Ext.Json.Parse, assembledData)
        if ok then
          onResponse({ success = true, data = data })
        else
          MCMWarn(0, "ChunkedNet.RequestReply.Request: failed to parse chunked response JSON")
          onResponse({ success = false, error = "Failed to parse chunked response" })
        end
      end)

      if not didRegister then
        onResponse({ success = false, error = "Failed to register chunked response handler" })
      end
    else
      onResponse(response)
    end
  end)
end

-- Client-side reassembly API
ChunkedNet.Client = ChunkedNet.Client or {}
local Client = ChunkedNet.Client

---@type table<string, MCMChunkTransferState>
Client._transfers = Client._transfers or {}
---@type table<string, MCMChunkedHandler>
Client._handlers = Client._handlers or {}

---Register a handler by its resolved handler id.
---@param handlerId string
---@param fn MCMChunkedHandler
---@param callerName string
---@return boolean
local function _registerHandlerById(handlerId, fn, callerName)
  if not VCString:IsNonEmptyString(handlerId) then
      MCMWarn(0, "%s: handler id must be a non-empty string", callerName)
    return false
  end

  if type(fn) ~= "function" then
      MCMWarn(0, "%s: handler must be a function", callerName)
    return false
  end

  if Client._handlers[handlerId] ~= nil then
      MCMWarn(0, "%s: overwriting existing ChunkedNet handler for '%s'", callerName, handlerId)
  end

  Client._handlers[handlerId] = fn
  return true
end

---Register a handler for a real NetChannel target.
---@param targetChannel NetChannel
---@param fn MCMChunkedHandler
---@return boolean
function Client.RegisterHandler(targetChannel, fn)
  local channelId = _getChannelId(targetChannel, "ChunkedNet.Client.RegisterHandler")
  if not channelId then
    return false
  end

  return _registerHandlerById(channelId, fn, "ChunkedNet.Client.RegisterHandler")
end

---Register an internal handler for synthetic chunk-routing keys.
---@param handlerId string
---@param fn MCMChunkedHandler
---@return boolean
function Client._RegisterInternalHandler(handlerId, fn)
  return _registerHandlerById(handlerId, fn, "ChunkedNet.Client._RegisterInternalHandler")
end

---Ensure a transfer record exists.
---@param id string
---@return MCMChunkTransferState
local function _ensureTransfer(id)
  Client._transfers[id] = Client._transfers[id] or { parts = {}, received = 0 }
  return Client._transfers[id]
end

---Initialize transfer metadata.
---@param payload table
function Client._onInit(payload)
  if type(payload) ~= "table" then
    MCMWarn(0, "ChunkedNet.Client._onInit: expected table payload")
    return
  end

  if not VCString:IsNonEmptyString(payload.id) then
    MCMWarn(0, "ChunkedNet.Client._onInit: missing transfer id")
    return
  end

  if not VCString:IsNonEmptyString(payload.targetChannel) then
    MCMWarn(0, "ChunkedNet.Client._onInit: missing targetChannel")
    return
  end

  if type(payload.totalChunks) ~= "number" or payload.totalChunks < 1 then
    MCMWarn(0, "ChunkedNet.Client._onInit: invalid totalChunks for transfer '%s'", payload.id)
    return
  end

  local transfer = _ensureTransfer(payload.id)
  transfer.targetChannel = payload.targetChannel
  transfer.totalSize = payload.totalSize
  transfer.chunkSize = payload.chunkSize
  transfer.totalChunks = payload.totalChunks
end

---Store a chunk part.
---@param payload table
function Client._onPart(payload)
  if type(payload) ~= "table" then
    MCMWarn(0, "ChunkedNet.Client._onPart: expected table payload")
    return
  end

  if not VCString:IsNonEmptyString(payload.id) then
    MCMWarn(0, "ChunkedNet.Client._onPart: missing transfer id")
    return
  end

  if type(payload.index) ~= "number" or payload.index < 1 then
    MCMWarn(0, "ChunkedNet.Client._onPart: invalid chunk index for transfer '%s'", payload.id)
    return
  end

  if type(payload.data) ~= "string" then
    MCMWarn(0, "ChunkedNet.Client._onPart: invalid chunk data for transfer '%s'", payload.id)
    return
  end

  local transfer = Client._transfers[payload.id]
  if not transfer then
    MCMWarn(0, "ChunkedNet.Client._onPart: received chunk before init for transfer '%s'", payload.id)
    transfer = _ensureTransfer(payload.id)
  end

  if transfer.parts[payload.index] == nil then
    transfer.parts[payload.index] = payload.data
    transfer.received = transfer.received + 1
  end
end

---Finalize a transfer and dispatch its payload.
---@param id string
---@return boolean
local function _finalize(id)
  local transfer = Client._transfers[id]
  if not transfer then
    MCMWarn(0, "ChunkedNet: received transfer end for unknown id '%s'", id)
    return false
  end

  if not VCString:IsNonEmptyString(transfer.targetChannel) then
    MCMWarn(0, "ChunkedNet: transfer '%s' is missing targetChannel metadata", id)
    Client._transfers[id] = nil
    return false
  end

  if type(transfer.totalChunks) ~= "number" then
    MCMWarn(0, "ChunkedNet: transfer '%s' ended without totalChunks metadata", id)
    Client._transfers[id] = nil
    return false
  end

  if transfer.received < transfer.totalChunks then
    MCMWarn(0,
      "ChunkedNet: transfer '%s' ended early for '%s' (%d/%d chunks received)",
      id,
      transfer.targetChannel,
      transfer.received,
      transfer.totalChunks
    )
    Client._transfers[id] = nil
    return false
  end

  local assembled = table.concat(transfer.parts, "")
  if type(transfer.totalSize) == "number" and #assembled ~= transfer.totalSize then
    MCMWarn(0,
      "ChunkedNet: transfer '%s' for '%s' assembled to %d bytes; expected %d",
      id,
      transfer.targetChannel,
      #assembled,
      transfer.totalSize
    )
  end

  local handler = Client._handlers[transfer.targetChannel]
  if not handler then
    MCMWarn(0, "No ChunkedNet handler registered for channel '%s'", transfer.targetChannel)
    Client._transfers[id] = nil
    return false
  end

  local ok, err = pcall(handler, assembled)
  if not ok then
    MCMError(0, "ChunkedNet handler error for channel '%s': %s", transfer.targetChannel, err)
    Client._transfers[id] = nil
    return false
  end

  Client._transfers[id] = nil
  return true
end

---Finalize a transfer when the END packet arrives.
---@param payload table
function Client._onEnd(payload)
  if type(payload) ~= "table" then
    MCMWarn(0, "ChunkedNet.Client._onEnd: expected table payload")
    return
  end

  if not VCString:IsNonEmptyString(payload.id) then
    MCMWarn(0, "ChunkedNet.Client._onEnd: missing transfer id")
    return
  end

  _finalize(payload.id)
end

---Register the generic chunk listeners once.
function Client.RegisterNetListeners()
  if Client._registered then
    return
  end

  Client._registered = true

  NetChannels.MCM_CHUNK_INIT:SetHandler(function(payload)
    Client._onInit(payload)
  end)

  NetChannels.MCM_CHUNK_PART:SetHandler(function(payload)
    Client._onPart(payload)
  end)

  NetChannels.MCM_CHUNK_END:SetHandler(function(payload)
    Client._onEnd(payload)
  end)
end
