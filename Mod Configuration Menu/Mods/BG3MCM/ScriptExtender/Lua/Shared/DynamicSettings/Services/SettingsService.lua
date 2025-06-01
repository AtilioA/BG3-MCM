-- Central façade for discovering, promoting, reading, and writing module‐scoped variables.

local AdapterFactory = require("Shared/DynamicSettings/Factories/AdapterFactory")

---@class SettingsService
local SettingsService = {
  -- Example:
  -- -- schema[moduleUUID] = {
  -- --   ModVar = {
  -- --     [varName] = { type=<string or nil>, default=<any>, validate=<fn>|nil }
  -- --   },
  -- --   ModConfig = {
  -- --     [varName] = { ... }
  -- --   }
  -- -- }
  schema = {}
}

--------------------------------------------------------------------------------
-- INTERNAL: Coerce a rawValue into the declared type (if promoted), or accept raw.
--------------------------------------------------------------------------------
local function coerceAndValidate(entry, rawValue)
  if entry.type then
    if entry.type == "boolean" then
      if type(rawValue) ~= "boolean" then
        error("Expected boolean, got " .. type(rawValue))
      end
      return rawValue
    elseif entry.type == "number" then
      if type(rawValue) ~= "number" then
        error("Expected number, got " .. type(rawValue))
      end
      return rawValue
    elseif entry.type == "table" then
      if type(rawValue) ~= "table" then
        error("Expected table, got " .. type(rawValue))
      end
      return rawValue
    elseif entry.type == "string" then
      if type(rawValue) ~= "string" then
        error("Expected string, got " .. type(rawValue))
      end
      return rawValue
    else
      error("Unknown promoted type: " .. tostring(entry.type))
    end
  else
    -- No promotion: return whatever SE stored (any Lua type)
    return rawValue
  end
end

--------------------------------------------------------------------------------
-- DISCOVERY: Register every discovered (moduleUUID, varName, storageType).
--------------------------------------------------------------------------------
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
function SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, storageType)
  if not SettingsService.schema[moduleUUID] then
    SettingsService.schema[moduleUUID] = { ModVar = {}, ModConfig = {} }
  end

  local bucket = SettingsService.schema[moduleUUID][storageType]
  if bucket[varName] then
    return -- already registered
  end

  bucket[varName] = {
    type     = nil, -- will be set if/when user promotes
    default  = nil,
    validate = nil
  }
end

--------------------------------------------------------------------------------
-- PROMOTION: Turn an untyped variable into a typed setting.
--------------------------------------------------------------------------------
--- Promote an untyped variable to a typed setting
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@param definition table { type=<"boolean"|"number"|"string"|"table">, default=<any>, validate=<fn>|nil }
function SettingsService.PromoteVariable(moduleUUID, varName, storageType, definition)
  local modSchema = SettingsService.schema[moduleUUID]
  if not modSchema then
    error("No variables known for module " .. moduleUUID)
  end

  local bucket = modSchema[storageType]
  if not bucket or not bucket[varName] then
    error(("Cannot promote '%s' under %s for module %s; not discovered"):format(
      varName, storageType, moduleUUID))
  end

  -- Assign metadata
  bucket[varName].type     = definition.type
  bucket[varName].default  = definition.default
  bucket[varName].validate = definition.validate

  -- Immediately write default if no value exists
  local adapter            = AdapterFactory.GetAdapter(storageType)
  local raw                = adapter:GetValue(moduleUUID, varName)
  if raw == nil and definition.default ~= nil then
    adapter:SetValue(moduleUUID, varName, definition.default)
  else
    local ok, val = pcall(coerceAndValidate, bucket[varName], raw)
    if not ok then
      adapter:SetValue(moduleUUID, varName, definition.default)
    end
  end
end

--------------------------------------------------------------------------------
-- GET: Retrieve the current Lua value for (moduleUUID, varName, storageType).
--------------------------------------------------------------------------------
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@return any value The value of the variable
function SettingsService.Get(moduleUUID, varName, storageType)
  local modSchema = SettingsService.schema[moduleUUID]
  if not modSchema then
    error("No variables known for module " .. moduleUUID)
  end

  local bucket = modSchema[storageType]
  if not bucket or not bucket[varName] then
    error(("Get: '%s' under %s not discovered for module %s"):format(
      varName, storageType, moduleUUID))
  end

  local entry = bucket[varName]
  local adapter = AdapterFactory.GetAdapter(storageType)
  local raw = adapter:GetValue(moduleUUID, varName)

  if raw == nil then
    return nil
  end

  local ok, val = pcall(coerceAndValidate, entry, raw)
  if not ok then
    error(("Get: coercion failed for %s:%s in %s: %s"):format(
      moduleUUID, varName, storageType, val))
  end

  return val
end

-- Retrieve the current value of all variables for a module
function SettingsService.GetAll(moduleUUID)
  local modSchema = SettingsService.schema[moduleUUID]
  if not modSchema then
    error("No variables known for module " .. moduleUUID)
  end

  local result = {}
  for storageType, bucket in pairs(modSchema) do
    result[storageType] = {}
    local adapter = AdapterFactory.GetAdapter(storageType)
    for varName, entry in pairs(bucket) do
      local raw = adapter:GetValue(moduleUUID, varName)
      if raw ~= nil then
        local ok, val = pcall(coerceAndValidate, entry, raw)
        if ok then
          result[storageType][varName] = val
        else
          error(("GetAll: coercion failed for %s:%s in %s: %s"):format(
            moduleUUID, varName, storageType, val))
        end
      end
    end
  end

  return result
end

--------------------------------------------------------------------------------
-- SET: Write a new Lua value for (moduleUUID, varName, storageType), then emit event.
--------------------------------------------------------------------------------
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@param newValue any The new value to set
function SettingsService.Set(moduleUUID, varName, storageType, newValue)
  local modSchema = SettingsService.schema[moduleUUID]
  if not modSchema then
    error("No variables known for module " .. moduleUUID)
  end

  local bucket = modSchema[storageType]
  if not bucket or not bucket[varName] then
    error(("Set: '%s' under %s not discovered for module %s"):format(
      varName, storageType, moduleUUID))
  end

  local entry = bucket[varName]
  if entry.validate then
    local ok, errMsg = entry.validate(newValue)
    if not ok then
      error(("Validation failed for %s:%s in %s: %s"):format(
        moduleUUID, varName, storageType, errMsg))
    end
  end

  local ok, val = pcall(coerceAndValidate, entry, newValue)
  if not ok then
    error(("Set: coercion failed for %s:%s in %s: %s"):format(
      moduleUUID, varName, storageType, val))
  end

  local adapter = AdapterFactory.GetAdapter(storageType)
  adapter:SetValue(moduleUUID, varName, val)

  -- Emit a single event for any listener (no need for internal subscribe/unsubscribe):
  ModEventManager:Emit(
    "SettingsChanged",
    {
      Module = moduleUUID,
      Key    = varName,
      Store  = storageType,
      Value  = val
    },
    true
  )
end

return SettingsService
