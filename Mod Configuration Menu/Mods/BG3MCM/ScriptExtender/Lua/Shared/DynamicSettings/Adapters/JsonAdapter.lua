-- 'Internal' file handler
-- Handles the I/O for a single specific file.

local DEFAULT_FILE_NAME = "dynamic_settings.json"

---@class SettingsFile
---@field ModuleUUID string
---@field FileName string
---@field FilePath string
---@field Data table<string, StorageValue>
---@field Loaded boolean
---@field Unreadable boolean The file failed to parse; MCM keeps it unchanged and refuses writes
---@field AutoSave boolean
local SettingsFile = {}
SettingsFile.__index = SettingsFile

---@param moduleUUID string
---@param fileName string File name inside the mod's Store directory
---@param autoSave boolean
---@return SettingsFile
function SettingsFile:new(moduleUUID, fileName, autoSave)
    local o = setmetatable({}, self)
    o.ModuleUUID = moduleUUID
    o.FileName = fileName
    o.Data = {}
    o.Loaded = false
    o.Unreadable = false
    -- Default to true if nil (sigh)
    o.AutoSave = (autoSave == nil) and true or autoSave
    o.FilePath = o:_generatePath()
    return o
end

---Generates a file path based on the mod's directory.
function SettingsFile:_generatePath()
    local modInfo = Ext.Mod.GetMod(self.ModuleUUID)
    local mcmInfo = Ext.Mod.GetMod(ModuleUUID)
    local name = "UnknownMod"
    local directory = "UnknownDirectory"
    local mcmDirectory = "UnknownMCMDirectory"

    if mcmInfo and mcmInfo.Info and mcmInfo.Info.Directory then
        mcmDirectory = mcmInfo.Info.Directory
    end

    if modInfo and modInfo.Info and modInfo.Info.Directory then
        directory = modInfo.Info.Directory
        name = modInfo.Info.Name
    else
        MCMWarn(0, "JsonAdapter: No mod info found for UUID: %s", self.ModuleUUID)
    end
    -- Sanitize name for filesystem (basic)
    name = name:gsub("[\\/:*?\"<>|]", "_")

    -- REFACTOR: allow proper Profile integration
    return string.format("%s/Profiles/Default/%s/%s", mcmDirectory, directory, self.FileName)
end

--- Loads the file from disk if not already loaded.
function SettingsFile:Load()
    if self.Loaded then return end

    local content = Ext.IO.LoadFile(self.FilePath)
    if content and content ~= "" then
        local ok, parsed = pcall(Ext.Json.Parse, content)
        if ok and type(parsed) == "table" then
            self.Data = parsed
        else
            MCMWarn(0, "JsonAdapter: Failed to parse JSON for: %s. MCM keeps the file unchanged and does not save values to it. Repair or delete the file, then reload.", self.FilePath)
            self.Data = {}
            self.Unreadable = true
        end
    else
        -- File doesn't exist yet, start empty
        self.Data = {}
    end
    self.Loaded = true
end

--- Saves the current data to disk, unless the file is unreadable.
---@return boolean saved
function SettingsFile:Save()
    if self.Unreadable then
        MCMDebug(1, "JsonAdapter: Not saving to unreadable file: %s", self.FilePath)
        return false
    end
    local content = Ext.Json.Stringify(self.Data)
    Ext.IO.SaveFile(self.FilePath, content)
    return true
end

function SettingsFile:Get(key)
    self:Load()
    return self.Data[key]
end

---@return boolean saved False when the file is unreadable; the value is then not kept
function SettingsFile:Set(key, value)
    self:Load()
    if self.Unreadable then
        MCMDebug(1, "JsonAdapter: Not saving '%s' to unreadable file: %s", key, self.FilePath)
        return false
    end
    self.Data[key] = value

    if self.AutoSave then
        self:Save()
    end
    return true
end

-- =============================================================================
-- The Adapter implementation
-- Manages multiple file handlers, keyed by UUID and file name.
-- =============================================================================

local IStorageAdapter = Ext.Require("Shared/DynamicSettings/Adapters/IStorageAdapter.lua")
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")

---@class JsonStorageManager : IStorageAdapter
local JsonStorageManager = {}
setmetatable(JsonStorageManager, { __index = IStorageAdapter })
JsonStorageManager.__index = JsonStorageManager
JsonStorageManager._cache = {} -- table<string, table<string, SettingsFile>> cache[moduleUUID][fileName]
JsonStorageManager._fileNames = {} -- table<string, table<string, string>> fileNames[moduleUUID][varName]

-- Default configuration for JSON storage
JsonStorageManager.DEFAULTS = {
    Server = true,
    Client = true,
    WriteableOnServer = true,
    WriteableOnClient = true,
    Persistent = true,
    SyncToClient = true,
    SyncToServer = false,
}

---Internal helper to retrieve or create the file handler for a UUID and file name
---@param uuid string
---@param fileName string
---@return SettingsFile
function JsonStorageManager:_getFileHandler(uuid, fileName)
    self._cache[uuid] = self._cache[uuid] or {}
    if not self._cache[uuid][fileName] then
        self._cache[uuid][fileName] = SettingsFile:new(uuid, fileName, true)
    end
    return self._cache[uuid][fileName]
end

--- File that holds a variable: the registered file name, or dynamic_settings.json.
---@param moduleUUID string
---@param key string
---@return string fileName
function JsonStorageManager:_resolveFileName(moduleUUID, key)
    local byMod = self._fileNames[moduleUUID]
    return byMod and byMod[key] or DEFAULT_FILE_NAME
end

--- Record the file that holds a variable. Re-registering with a different file name is rejected and keeps the first file.
---@param key string
---@param moduleUUID string
---@param storageConfig? StorageConfig `fileName` selects a file in the mod's Store directory
---@return boolean success
---@return string? message
function JsonStorageManager:EnsureRegistered(key, moduleUUID, storageConfig)
    local fileName = storageConfig and storageConfig.fileName or DEFAULT_FILE_NAME
    -- Same rules as profile names (ProfileManager)
    local valid, reason
    if type(fileName) == "string" then
        valid, reason = PathValidator:IsValidPathComponent(fileName, true)
    else
        valid, reason = false, "must be a string"
    end
    if not valid then
        local message = string.format("JsonAdapter: rejected '%s' (module %s): fileName '%s' is invalid: %s", key,
            moduleUUID, tostring(fileName), reason)
        MCMWarn(0, "%s", message)
        return false, message
    end

    self._fileNames[moduleUUID] = self._fileNames[moduleUUID] or {}
    local registeredFileName = self._fileNames[moduleUUID][key]
    if registeredFileName and registeredFileName ~= fileName then
        local message = string.format("JsonAdapter: '%s' (module %s) is already registered in '%s'; ignoring fileName '%s'",
            key, moduleUUID, registeredFileName, fileName)
        MCMWarn(0, "%s", message)
        return false, message
    end

    self._fileNames[moduleUUID][key] = fileName
    return true
end

--- Whether the variable has a file on record from EnsureRegistered.
---@param key string
---@param moduleUUID string
---@return boolean registered
function JsonStorageManager:IsRegistered(key, moduleUUID)
    local byMod = self._fileNames[moduleUUID]
    return byMod ~= nil and byMod[key] ~= nil
end

--- Whether the variable's file accepts writes; false when the file failed to parse.
---@param key string
---@param moduleUUID string
---@return boolean writable
function JsonStorageManager:IsWritable(key, moduleUUID)
    local handler = self:_getFileHandler(moduleUUID, self:_resolveFileName(moduleUUID, key))
    handler:Load()
    return not handler.Unreadable
end

--- Read the raw Lua value
---@param key string
---@param moduleUUID string
---@param storageConfig? table Optional storage-specific configuration
---@return StorageValue
function JsonStorageManager:GetValue(key, moduleUUID, storageConfig)
    if not moduleUUID then return nil end

    local cached = StorageSyncService:GetCachedValue("json", moduleUUID, key)
    if cached ~= nil then
        return cached
    end

    local handler = self:_getFileHandler(moduleUUID, self:_resolveFileName(moduleUUID, key))
    return handler:Get(key)
end

--- Write the raw Lua value
---@param key string
---@param value StorageValue
---@param moduleUUID string
---@param storageConfig? table Optional storage configuration; the file comes from registration
---@return boolean saved False when the variable's file is unreadable
function JsonStorageManager:SetValue(key, value, moduleUUID, storageConfig)
    if not moduleUUID then return false end

    local handler = self:_getFileHandler(moduleUUID, self:_resolveFileName(moduleUUID, key))
    if not handler:Set(key, value) then
        return false
    end

    StorageSyncService:OnLocalSet("json", moduleUUID, key, value, self:ResolveConfig(storageConfig))
    return true
end

---@return table<string, table<string, any>>
function JsonStorageManager:GetAllValues()
    local result = {}

    for moduleUUID, handlers in pairs(self._cache) do
        result[moduleUUID] = result[moduleUUID] or {}
        for fileName, handler in pairs(handlers) do
            handler:Load()
            if type(handler.Data) == "table" then
                for key, value in pairs(handler.Data) do
                    -- Skip stale keys left in a file the variable is not registered to.
                    if self:_resolveFileName(moduleUUID, key) == fileName then
                        result[moduleUUID][key] = value
                    end
                end
            end
        end
    end

    return result
end

--- Force save all loaded files
function JsonStorageManager:SaveAll()
    for _, handlers in pairs(self._cache) do
        for _, handler in pairs(handlers) do
            handler:Save()
        end
    end
end

StorageSyncService:RegisterStorageAdapter("json", JsonStorageManager)

return JsonStorageManager
