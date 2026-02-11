-- Reusable chunked net messaging utilities for large payloads
-- Provides server-side send helpers, client-side reassembly with handler dispatch, and request/reply support.

ChunkedNet = ChunkedNet or {}

-- Conservative thresholds to avoid Script Extender ~1MB cap (include JSON overhead)
ChunkedNet.DIRECT_THRESHOLD_BYTES = 700 * 1024
ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES = 700 * 1024

local function _makeTransferId()
  ChunkedNet._counter = (ChunkedNet._counter or 0) + 1
  -- TODO: use a better random prefix (UUID?)
  return tostring(math.random(1000000000)) .. "-" .. tostring(ChunkedNet._counter)
end

-- Compute totalChunks and log a level-1 debug message in KB
local function _computeAndLogChunking(targetChannel, totalSize, chunkSize, isBroadcast)
  local totalChunks = math.ceil(totalSize / chunkSize)
  local totalSizeKB = totalSize / 1024
  local chunkSizeKB = chunkSize / 1024
  if isBroadcast then
    MCMDebug(1, string.format(
      "ChunkedNet: Broadcast payload for '%s' is %.1f KB; chunking into %d parts (chunkSize=%.1f KB).",
      tostring(targetChannel), totalSizeKB, totalChunks, chunkSizeKB
    ))
  else
    MCMDebug(1, string.format(
      "ChunkedNet: Payload for '%s' is %.1f KB; chunking into %d parts (chunkSize=%.1f KB).",
      tostring(targetChannel), totalSizeKB, totalChunks, chunkSizeKB
    ))
  end
  return totalChunks
end

-- Server-side: send a JSON string to a specific user, chunking if too large
-- targetChannel can be either a NetChannel object or a string channel name
function ChunkedNet.SendJSONToUser(userID, targetChannel, jsonStr)
  if type(jsonStr) ~= "string" then
    jsonStr = Ext.Json.Stringify(jsonStr)
  end

  -- Resolve targetChannel to a channel object
  local channelObj = targetChannel
  local channelName = targetChannel
  if type(targetChannel) == "string" then
    channelObj = NetChannels[targetChannel]
    channelName = targetChannel
  else
    -- Extract channel name from channel object for serialization
    -- NetChannel objects have a Name property
    channelName = targetChannel.Name or tostring(targetChannel)
  end

  if not channelObj then
    MCMError(0, "ChunkedNet.SendJSONToUser: channel '" .. tostring(targetChannel) .. "' was not found")
    return
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    -- Use NetChannel API: SendToClient for specific user
    channelObj:SendToClient(jsonStr, userID)
    return
  end

  local id = _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(channelName, totalSize, chunkSize, false)

  -- INIT
  NetChannels.MCM_CHUNK_INIT:SendToClient({
    id = id,
    targetChannel = channelName,
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

  -- END
  NetChannels.MCM_CHUNK_END:SendToClient({ id = id }, userID)
end

-- Server-side: convenience to send a table (will be JSON stringified first)
function ChunkedNet.SendTableToUser(userID, targetChannel, tbl)
  local json = Ext.Json.Stringify(tbl)
  return ChunkedNet.SendJSONToUser(userID, targetChannel, json)
end

-- Server-side: broadcast a JSON string to all clients, chunking if too large
-- targetChannel can be either a NetChannel object or a string channel name
function ChunkedNet.SendJSONToAll(targetChannel, jsonStr)
  if type(jsonStr) ~= "string" then
    jsonStr = Ext.Json.Stringify(jsonStr)
  end

  -- Resolve targetChannel to a channel object
  local channelObj = targetChannel
  local channelName = targetChannel
  if type(targetChannel) == "string" then
    channelObj = NetChannels[targetChannel]
  else
    -- Extract channel name from channel object for serialization
    channelName = targetChannel.Name or tostring(targetChannel)
  end

  if not channelObj then
    MCMError(0, "ChunkedNet.SendJSONToAll: channel '" .. tostring(targetChannel) .. "' was not found")
    return
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    -- Use NetChannel API: Broadcast
    channelObj:Broadcast(jsonStr)
    return
  end

  local id = _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(channelName, totalSize, chunkSize, true)

  -- INIT
  NetChannels.MCM_CHUNK_INIT:Broadcast({
    id = id,
    targetChannel = channelName,
    totalSize = totalSize,
    chunkSize = chunkSize,
    totalChunks = totalChunks,
  })

  -- PARTS
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

  -- END
  NetChannels.MCM_CHUNK_END:Broadcast({ id = id })
end

function ChunkedNet.SendTableToAll(targetChannel, tbl)
  local json = Ext.Json.Stringify(tbl)
  return ChunkedNet.SendJSONToAll(targetChannel, json)
end

-- Request/Reply pattern for large payloads
-- Server collects all chunks, then returns complete response via RequestHandler
ChunkedNet.RequestReply = ChunkedNet.RequestReply or {}

-- Server-side: Set up a request handler that can send chunked responses
-- The handler should return the data to be sent (will be chunked automatically if needed)
function ChunkedNet.RequestReply.SetHandler(channel, handlerFn)
  channel:SetRequestHandler(function(requestData, userID)
    local ok, result = xpcall(function()
      return handlerFn(requestData, userID)
    end, function(err)
      return { success = false, error = tostring(err) }
    end)

    if not ok then
      return { success = false, error = tostring(result) }
    end

    -- If result is a string and needs chunking, chunk it and return metadata
    if type(result) == "string" and #result > ChunkedNet.DIRECT_THRESHOLD_BYTES then
      local transferId = _makeTransferId()
      local totalSize = #result
      local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
      local totalChunks = math.ceil(totalSize / chunkSize)

      -- Send chunked data directly to user (not as reply)
      ChunkedNet.SendJSONToUser(userID, channel, result)

      -- Return metadata indicating chunked transfer
      return {
        success = true,
        chunked = true,
        transferId = transferId,
        totalChunks = totalChunks
      }
    end

    -- Return standard response
    if type(result) == "table" and result.success ~= nil then
      return result
    else
      return { success = true, data = result }
    end
  end)
end

-- Client-side: Request data that may be chunked
-- Automatically handles chunked responses
function ChunkedNet.RequestReply.Request(channel, requestData, onResponse)
  channel:RequestToServer(requestData, function(response)
    if response.chunked then
      -- Set up handler to receive chunked data
      local handlerKey = tostring(channel) .. "_" .. response.transferId
      ChunkedNet.Client.RegisterHandler(handlerKey, function(assembledData)
        local ok, data = pcall(Ext.Json.Parse, assembledData)
        if ok then
          onResponse({ success = true, data = data })
        else
          onResponse({ success = false, error = "Failed to parse chunked response" })
        end
      end)
    else
      onResponse(response)
    end
  end)
end

-- Client-side reassembly API
ChunkedNet.Client = ChunkedNet.Client or {}
local Client = ChunkedNet.Client

Client._transfers = Client._transfers or {}
Client._handlers = Client._handlers or {}

function Client.RegisterHandler(targetChannel, fn)
  -- Handle both channel objects and string names
  local channelName = targetChannel
  if type(targetChannel) ~= "string" then
    -- It's a channel object, extract the name
    channelName = targetChannel.Name or tostring(targetChannel)
  end
  Client._handlers[channelName] = fn
end

local function _ensureTransfer(id)
  Client._transfers[id] = Client._transfers[id] or { parts = {}, received = 0 }
  return Client._transfers[id]
end

function Client._onInit(payload)
  local t = _ensureTransfer(payload.id)
  t.targetChannel = payload.targetChannel
  t.totalSize = payload.totalSize
  t.chunkSize = payload.chunkSize
  t.totalChunks = payload.totalChunks
end

function Client._onPart(payload)
  local t = _ensureTransfer(payload.id)
  if t.parts[payload.index] == nil then
    t.parts[payload.index] = payload.data or ""
    t.received = t.received + 1
  end
end

local function _finalize(id)
  local t = Client._transfers[id]
  if not t or not t.totalChunks then
    return false
  end
  if t.received < t.totalChunks then
    return false
  end

  local assembled = table.concat(t.parts, "")
  local handler = Client._handlers[t.targetChannel]
  if handler then
    local ok, err = pcall(handler, assembled)
    if not ok then
      MCMError(0, "ChunkedNet handler error for channel '" .. tostring(t.targetChannel) .. "': " .. tostring(err))
    end
  else
    MCMDebug(1, "No ChunkedNet handler registered for channel '" .. tostring(t.targetChannel) .. "'")
  end

  Client._transfers[id] = nil
  return true
end

function Client._onEnd(payload)
  _finalize(payload.id)
end

function Client.RegisterNetListeners()
  if Client._registered then return end
  Client._registered = true

  -- INIT - Use NetChannel SetHandler
  NetChannels.MCM_CHUNK_INIT:SetHandler(function(payload)
    Client._onInit(payload)
  end)

  -- PART - Use NetChannel SetHandler
  NetChannels.MCM_CHUNK_PART:SetHandler(function(payload)
    Client._onPart(payload)
  end)

  -- END - Use NetChannel SetHandler
  NetChannels.MCM_CHUNK_END:SetHandler(function(payload)
    Client._onEnd(payload)
  end)
end
