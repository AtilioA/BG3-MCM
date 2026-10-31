---@alias BlueprintSettingId string
---@alias BlueprintSettingPath string[]

---@class BlueprintCacheIndex
---@field byId table<BlueprintSettingId, BlueprintSetting> Direct setting lookup by ID, scoped to this blueprint or subtree. IDs are validated unique per mod blueprint, not globally.
---@field entries BlueprintShapeEntry[] Ordered traversal entries for save output and any order-sensitive callers.
---@field containerPathById table<BlueprintSettingId, BlueprintSettingPath> Parent-container path by setting ID, used to re-nest flat values when saving to JSON.
---@field hasAnySettings boolean

---@class BlueprintCache
---@field private enabled boolean
---@field private caches table<table, BlueprintCacheIndex>
BlueprintCache = _Class:Create("BlueprintCache", nil)

BlueprintCache.enabled = true
BlueprintCache.caches = setmetatable({}, { __mode = "k" })

---@param value boolean
function BlueprintCache:SetCacheEnabled(value)
    self.enabled = value == true
    self:InvalidateAll()
end

---@param root table
---@param buildFn fun(root: table): BlueprintCacheIndex
---@return BlueprintCacheIndex
function BlueprintCache:GetOrBuild(root, buildFn)
    if not self.enabled then
        return buildFn(root)
    end

    local cached = self.caches[root]
    if cached then
        return cached
    end

    cached = buildFn(root)
    self.caches[root] = cached
    return cached
end

function BlueprintCache:InvalidateAll()
    self.caches = setmetatable({}, { __mode = "k" })
end

function BlueprintCache:ApplyMCMSettings()
    if not MCMAPI then
        return
    end

    local debugLevel = MCMAPI:GetSettingValue("debug_level", ModuleUUID) or 0
    local userEnabledCache = MCMAPI:GetSettingValue("enable_blueprint_cache", ModuleUUID)
    self:SetCacheEnabled(debugLevel < 1 or userEnabledCache ~= false)
end

---@param payload table|nil
function BlueprintCache.OnInternalSettingSaved(payload)
    if not payload or payload.modUUID ~= ModuleUUID then
        return
    end

    if payload.settingId == "debug_level" or payload.settingId == "enable_blueprint_cache" then
        BlueprintCache:ApplyMCMSettings()
    end
end

Ext.ModEvents['BG3MCM'][EventChannels.MCM_INTERNAL_SETTING_SAVED]:Subscribe(BlueprintCache.OnInternalSettingSaved)

return BlueprintCache
