-- 'Internal' file handler
-- Handles the I/O for a single specific file.

---@class SettingsFile
---@field ModuleUUID string
---@field FilePath string
---@field Data table<string, any>
---@field Loaded boolean
---@field AutoSave boolean
local SettingsFile = {}
SettingsFile.__index = SettingsFile

function SettingsFile:new(moduleUUID, autoSave)
    local o = setmetatable({}, self)
    o.ModuleUUID = moduleUUID
    o.Data = {}
    o.Loaded = false
    -- Default to true if nil (sigh)
    o.AutoSave = (autoSave == nil) and true or autoSave
    o.FilePath = o:_generatePath()
    return o
end

---Generates a file path based on the mod's directory.
function SettingsFile:_generatePath()
    local modInfo = Ext.Mod.GetMod(self.ModuleUUID)
    local name = "UnknownMod"
    local directory = "UnknownDirectory"
    if modInfo and modInfo.Info and modInfo.Info.Directory then
        directory = modInfo.Info.Directory
        name = modInfo.Info.Name
    else
        MCMWarn(0, "JsonAdapter: No mod info found for UUID: " .. self.ModuleUUID)
    end
    -- Sanitize name for filesystem (basic)
    name = name:gsub("[\\/:*?\"<>|]", "_")

    -- REFACTOR: allow proper Profile integration
    return Ext.Mod.GetMod(ModuleUUID).Info.Directory ..
        "/Profiles/Default/" .. directory .. "/" .. "dynamic_settings.json"
end

--- Loads the file from disk if not already loaded.
function SettingsFile:Load()
    if self.Loaded then return end

    local content = Ext.IO.LoadFile(self.FilePath)
    if content and content ~= "" then
        local ok, parsed = pcall(Ext.Json.Parse, content)
        if ok and parsed then
            self.Data = parsed
        else
            MCMWarn(0, "JsonAdapter: Failed to parse JSON for: " .. self.FilePath)
            self.Data = {}
        end
    else
        -- File doesn't exist yet, start empty
        self.Data = {}
    end
    self.Loaded = true
end

--- Saves the current data to disk.
function SettingsFile:Save()
    local content = Ext.Json.Stringify(self.Data)
    Ext.IO.SaveFile(self.FilePath, content)
end

function SettingsFile:Get(key)
    self:Load()
    return self.Data[key]
end

function SettingsFile:Set(key, value)
    self:Load()
    if value == nil then
        self.Data[key] = nil
    else
        self.Data[key] = value
    end

    if self.AutoSave then
        self:Save()
    end
end

-- =============================================================================
-- The Adapter implementation
-- Manages multiple file handlers, keyed by UUID.
-- =============================================================================

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class JsonStorageManager : IStorageAdapter
local JsonStorageManager = {}
setmetatable(JsonStorageManager, { __index = IStorageAdapter })
JsonStorageManager.__index = JsonStorageManager
JsonStorageManager._cache = {} -- table<string, SettingsFile>

-- Default configuration for JSON storage
JsonStorageManager.DEFAULTS = {
    -- AutoSave = true?
}

---Internal helper to retrieve or create the file handler for a UUID
---@param uuid string
---@return SettingsFile
function JsonStorageManager:_getFileHandler(uuid)
    if not self._cache[uuid] then
        self._cache[uuid] = SettingsFile:new(uuid, true)
    end
    return self._cache[uuid]
end

--- Read the raw Lua value
---@param key string
---@param moduleUUID string
---@param storageConfig? table Optional storage-specific configuration
---@return any
function JsonStorageManager:GetValue(key, moduleUUID, storageConfig)
    if not moduleUUID then return nil end
    local handler = self:_getFileHandler(moduleUUID)
    return handler:Get(key)
end

--- Write the raw Lua value
---@param key string
---@param value any
---@param moduleUUID string
---@param storageConfig? table Optional storage configuration (unused for JSON)
function JsonStorageManager:SetValue(key, value, moduleUUID, storageConfig)
    if not moduleUUID then return end

    local handler = self:_getFileHandler(moduleUUID)

    -- Merge defaults with provided config using IStorageAdapter logic
    local config = self:ResolveConfig(storageConfig)

    -- Write value to memory
    handler:Load()
    if value == nil then
        handler.Data[key] = nil
    else
        handler.Data[key] = value
    end
end

--- Force save all loaded files
function JsonStorageManager:SaveAll()
    for _, handler in pairs(self._cache) do
        handler:Save()
    end
end

return JsonStorageManager
