-- Reusable chunked net messaging utilities for large payloads
-- Provides server-side send helpers and client-side reassembly with handler dispatch.

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
function ChunkedNet.SendJSONToUser(userID, targetChannel, jsonStr)
  if type(jsonStr) ~= "string" then
    jsonStr = Ext.Json.Stringify(jsonStr)
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    Ext.ServerNet.PostMessageToUser(userID, targetChannel, jsonStr)
    return
  end

  local id = _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(targetChannel, totalSize, chunkSize, false)

  -- INIT
  Ext.ServerNet.PostMessageToUser(userID, NetChannels.MCM_CHUNK_INIT, Ext.Json.Stringify({
    id = id,
    targetChannel = targetChannel,
    totalSize = totalSize,
    chunkSize = chunkSize,
    totalChunks = totalChunks,
  }))

  -- PARTS
  local index = 1
  local pos = 1
  while pos <= totalSize do
    local nextPos = math.min(pos + chunkSize - 1, totalSize)
    local data = string.sub(jsonStr, pos, nextPos)
    Ext.ServerNet.PostMessageToUser(userID, NetChannels.MCM_CHUNK_PART, Ext.Json.Stringify({
      id = id,
      index = index,
      data = data,
    }))
    index = index + 1
    pos = nextPos + 1
  end

  -- END
  Ext.ServerNet.PostMessageToUser(userID, NetChannels.MCM_CHUNK_END, Ext.Json.Stringify({ id = id }))
end

-- Server-side: convenience to send a table (will be JSON stringified first)
function ChunkedNet.SendTableToUser(userID, targetChannel, tbl)
  local json = Ext.Json.Stringify(tbl)
  return ChunkedNet.SendJSONToUser(userID, targetChannel, json)
end

-- Server-side: broadcast a JSON string to all clients, chunking if too large
function ChunkedNet.SendJSONToAll(targetChannel, jsonStr)
  if type(jsonStr) ~= "string" then
    jsonStr = Ext.Json.Stringify(jsonStr)
  end

  if #jsonStr <= ChunkedNet.DIRECT_THRESHOLD_BYTES then
    Ext.Net.BroadcastMessage(targetChannel, jsonStr)
    return
  end

  local id = _makeTransferId()
  local totalSize = #jsonStr
  local chunkSize = ChunkedNet.CHUNK_PAYLOAD_SIZE_BYTES
  local totalChunks = _computeAndLogChunking(targetChannel, totalSize, chunkSize, true)

  -- INIT
  Ext.Net.BroadcastMessage(NetChannels.MCM_CHUNK_INIT, Ext.Json.Stringify({
    id = id,
    targetChannel = targetChannel,
    totalSize = totalSize,
    chunkSize = chunkSize,
    totalChunks = totalChunks,
  }))

  -- PARTS
  local index = 1
  local pos = 1
  while pos <= totalSize do
    local nextPos = math.min(pos + chunkSize - 1, totalSize)
    local data = string.sub(jsonStr, pos, nextPos)
    Ext.Net.BroadcastMessage(NetChannels.MCM_CHUNK_PART, Ext.Json.Stringify({
      id = id,
      index = index,
      data = data,
    }))
    index = index + 1
    pos = nextPos + 1
  end

  -- END
  Ext.Net.BroadcastMessage(NetChannels.MCM_CHUNK_END, Ext.Json.Stringify({ id = id }))
end

function ChunkedNet.SendTableToAll(targetChannel, tbl)
  local json = Ext.Json.Stringify(tbl)
  return ChunkedNet.SendJSONToAll(targetChannel, json)
end

-- Client-side reassembly API
ChunkedNet.Client = ChunkedNet.Client or {}
local Client = ChunkedNet.Client

Client._transfers = Client._transfers or {}
Client._handlers = Client._handlers or {}

function Client.RegisterHandler(targetChannel, fn)
  Client._handlers[targetChannel] = fn
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
  -- INIT
  Ext.RegisterNetListener(NetChannels.MCM_CHUNK_INIT, function(_, metapayload)
    local ok, payload = pcall(Ext.Json.Parse, metapayload)
    if ok and type(payload) == "table" then
      Client._onInit(payload)
    end
  end)

  -- PART
  Ext.RegisterNetListener(NetChannels.MCM_CHUNK_PART, function(_, metapayload)
    local ok, payload = pcall(Ext.Json.Parse, metapayload)
    if ok and type(payload) == "table" then
      Client._onPart(payload)
    end
  end)

  -- END
  Ext.RegisterNetListener(NetChannels.MCM_CHUNK_END, function(_, metapayload)
    local ok, payload = pcall(Ext.Json.Parse, metapayload)
    if ok and type(payload) == "table" then
      Client._onEnd(payload)
    end
  end)
end
