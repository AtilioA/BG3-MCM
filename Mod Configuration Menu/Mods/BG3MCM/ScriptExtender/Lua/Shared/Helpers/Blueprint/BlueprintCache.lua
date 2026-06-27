---@class BlueprintCacheIndex
---@field byId table<string, BlueprintSetting>
---@field entries BlueprintShapeEntry[]
---@field pathById table<string, string[]>
---@field hasAnySettings boolean

---@class BlueprintCache
BlueprintCache = _Class:Create("BlueprintCache", nil)

local enabled = true
local caches = setmetatable({}, { __mode = "k" })

---@param value boolean
function BlueprintCache:SetEnabled(value)
    enabled = value == true
    if not enabled then
        self:InvalidateAll()
    end
end

---@return boolean
function BlueprintCache:IsEnabled()
    return enabled
end

---@param root table
---@param buildFn fun(root: table): BlueprintCacheIndex
---@return BlueprintCacheIndex
function BlueprintCache:GetOrBuild(root, buildFn)
    if not enabled then
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
    local shouldDisable = debugLevel >= 1 and MCMAPI:GetSettingValue("enable_blueprint_cache", ModuleUUID) == false
    self:SetEnabled(not shouldDisable)
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
