-- Warn once when a mod reads MCM's internal API through Mods.BG3MCM.

local INTERNAL_API_KEYS = {
    MCMAPI = true,
    IMGUIAPI = true,
}

local warningShown = {}

---@param modUUID GUIDSTRING|nil
---@param key string|nil
local function warnOnce(modUUID, key)
    if not modUUID or modUUID == ModuleUUID then
        return
    end
    if not key then
        MCMWarn(0, "key is nil when checking for internal API access by mod '%s'.", modUUID)
        return
    end

    local shownForMod = warningShown[modUUID]
    if not shownForMod then
        shownForMod = {}
        warningShown[modUUID] = shownForMod
    end

    if shownForMod[key] then
        return
    end
    shownForMod[key] = true

    local info = Ext.Mod.GetMod(modUUID).Info
    local modAuthor = info.Author or "unknown author"
    MCMDeprecation(0,
        "Mod '%s' accessed MCM's internal API 'Mods.BG3MCM.%s'. Please contact %s about this issue. "
        .. "Use the global MCM.* public API instead (MCM.Get/Set, MCM.Keybinding, MCM.EventButton, MCM.List, etc). Check the wiki for more details."
        .. " If this is a workaround for a missing feature, please ask Volitio for a public API.",
        info.Name, key, modAuthor)
end

-- Level 3 is required because this helper is called from __index: 1=getCallingModUUID, 2=__index, 3=actual mod caller.
---@param modUUIDsByDirectory table<string, GUIDSTRING>
---@return GUIDSTRING|nil
local function getCallingModUUID(modUUIDsByDirectory)
    local caller = debug.getinfo(3, "S")
    if not caller or not caller.source then
        return nil
    end

    local source = caller.source:gsub("^@", "")
    local directory = source:match("^Mods/([^/]+)/") or source:match("^([^/]+)/")
    if not directory then
        return nil
    end

    return modUUIDsByDirectory[directory]
end

local function activate()
    local environment = Mods.BG3MCM
    local metatable = getmetatable(environment)
    local globals = metatable.__index
    local internalValues = {}
    local modUUIDsByDirectory = {}

    for _, modUUID in ipairs(Ext.Mod.GetLoadOrder()) do
        local info = Ext.Mod.GetMod(modUUID).Info
        modUUIDsByDirectory[info.Directory] = modUUID
    end

    -- Hide the real values so reads go through __index and can warn.
    for key in pairs(INTERNAL_API_KEYS) do
        internalValues[key] = rawget(environment, key)
        rawset(environment, key, nil)
    end

    metatable.__index = function(_, key)
        if not INTERNAL_API_KEYS[key] then
            return globals[key]
        end

        warnOnce(getCallingModUUID(modUUIDsByDirectory), key)
        return internalValues[key]
    end

    -- Keep internal keys
    metatable.__newindex = function(table, key, value)
        if INTERNAL_API_KEYS[key] then
            internalValues[key] = value
            return
        end

        rawset(table, key, value)
    end
end

return {
    Activate = activate,
}
