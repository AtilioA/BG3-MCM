---@alias BlueprintSettingId string
---@alias BlueprintSettingPath string[]

---@class BlueprintCacheIndex
---@field byId table<BlueprintSettingId, BlueprintSetting> Direct setting lookup by ID, scoped to this blueprint or subtree. IDs are validated unique per mod blueprint, not globally.
---@field entries BlueprintShapeEntry[] Ordered traversal entries for save output and any order-sensitive callers.
---@field containerPathById table<BlueprintSettingId, BlueprintSettingPath> Parent-container path by setting ID, used to re-nest flat values when saving to JSON.
---@field hasAnySettings boolean

---@class BlueprintCache
BlueprintCache = _Class:Create("BlueprintCache", nil)

local cacheEnabled = true
local caches = setmetatable({}, { __mode = "k" })

---@param value boolean
function BlueprintCache:SetCacheEnabled(value)
    local nextValue = value == true
    if cacheEnabled == nextValue then
        return
    end

    cacheEnabled = nextValue
    if not cacheEnabled then
        self:InvalidateAll()
    end
end

---@return boolean
function BlueprintCache:IsCacheEnabled()
    return cacheEnabled
end

---@param root table
---@param buildFn fun(root: table): BlueprintCacheIndex
---@return BlueprintCacheIndex
function BlueprintCache:GetOrBuild(root, buildFn)
    if not cacheEnabled then
        return buildFn(root)
    end

    local cached = caches[root]
    if cached then
        return cached
    end

    cached = buildFn(root)
    caches[root] = cached
    return cached
end

---@param root table|nil
function BlueprintCache:Invalidate(root)
    if root then
        caches[root] = nil
    end
end

function BlueprintCache:InvalidateAll()
    caches = setmetatable({}, { __mode = "k" })
end

function BlueprintCache:ApplyMCMSettings()
    if not MCMAPI then
        return
    end

    local debugLevel = MCMAPI:GetSettingValue("debug_level", ModuleUUID) or 0
    local userEnabledCache = MCMAPI:GetSettingValue("enable_blueprint_cache", ModuleUUID)
    self:SetCacheEnabled(debugLevel < 1 or userEnabledCache ~= false)
end

Ext.ModEvents['BG3MCM'][EventChannels.MCM_INTERNAL_SETTING_SAVED]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "debug_level" or payload.settingId == "enable_blueprint_cache" then
        BlueprintCache:ApplyMCMSettings()
    end
end)

return BlueprintCache
