------------------------------------------------------------
-- ModListVisibility
-- Splits present mod entries into the main list and Hidden mods: player choice, then author default, then visible.
-- Only player choices are saved in the MCM state document, so updated author defaults still apply.
-- An unreadable document, or one with a newer Version, is protected: MCM keeps it unchanged and saves no choices.
------------------------------------------------------------

local STATE_VERSION = 1

-- Client-only: local menu preferences never sync to the server or to other players
---@type MCMStoreRegisterOptions
local STATE_VAR_OPTIONS = {
    storage = "json",
    storageConfig = { fileName = "MCM_state.json", SyncToClient = false, SyncToServer = false },
}

---@class ModListVisibility
---@field private store MCMStoreAPI MCM.Store, or an in-memory stand-in in tests
ModListVisibility = _Class:Create("ModListVisibility", nil, {
    store = nil,
})

--- Register the MCM state document variables; no defaults, because Store writes defaults to the file immediately
---@param store MCMStoreAPI
---@return ModListVisibility
function ModListVisibility:New(store)
    local obj = setmetatable({}, ModListVisibility)
    obj.store = store
    store.RegisterVar("Version", STATE_VAR_OPTIONS)
    store.RegisterVar("UI", STATE_VAR_OPTIONS)
    if obj:IsProtected() then
        MCMWarn(0, "MCM_state.json is unreadable or from a newer MCM version; mod-list choices will not be saved until it is repaired or deleted")
    end
    return obj
end

--- Check whether choices cannot be saved, because the document is unreadable or has a newer Version than MCM supports
---@return boolean protected
function ModListVisibility:IsProtected()
    if not self.store.IsWritable("UI") then
        return true
    end
    local version = self.store.Get("Version")
    return version ~= nil and not (type(version) == "number" and version <= STATE_VERSION)
end

--- Read the player's saved choice for one mod
---@private
---@param modUUID string
---@return boolean|nil hidden The player's explicit choice, or nil when there is none
function ModListVisibility:getChoice(modUUID)
    local ui = self.store.Get("UI")
    local mods = type(ui) == "table" and ui.Mods
    local mod = type(mods) == "table" and mods[modUUID]
    local hidden = type(mod) == "table" and mod.HiddenFromList
    if type(hidden) == "boolean" then
        return hidden
    end
    return nil
end

--- Split present mod entries; both lists keep the input order
---@param modUUIDs string[] Present mod UUIDs, already sorted for the mod list
---@param authorDefaults? table<string, boolean> Mod UUID -> blueprint HiddenFromList; a missing value means visible
---@return string[] main
---@return string[] hidden
---@return integer hiddenCount
function ModListVisibility:Resolve(modUUIDs, authorDefaults)
    authorDefaults = authorDefaults or {}
    local main, hidden = {}, {}
    for _, modUUID in ipairs(modUUIDs) do
        local isHidden = self:getChoice(modUUID)
        if isHidden == nil then
            isHidden = authorDefaults[modUUID]
        end
        if isHidden == true then
            table.insert(hidden, modUUID)
        else
            table.insert(main, modUUID)
        end
    end
    return main, hidden, #hidden
end

--- Save an explicit Hide (true) or Show (false) choice for one mod; choices for other mods, present or not, stay in the document
---@param modUUID string
---@param hidden boolean
---@return boolean saved False when the document is protected
function ModListVisibility:SetHidden(modUUID, hidden)
    if self:IsProtected() then
        return false
    end
    local ui = table.deepcopy(self.store.Get("UI") or {})
    ui.Mods = ui.Mods or {}
    ui.Mods[modUUID] = ui.Mods[modUUID] or {}
    ui.Mods[modUUID].HiddenFromList = hidden
    if self.store.Get("Version") == nil then
        self.store.Set("Version", STATE_VERSION)
    end
    return self.store.Set("UI", ui)
end

--- Check whether the player saved Hide or Show for one mod
---@param modUUID string
---@return boolean hasChoice Whether the player saved Hide or Show for the mod
function ModListVisibility:HasChoice(modUUID)
    return self:getChoice(modUUID) ~= nil
end

--- Remove the player's choice so the mod follows its author default again; other fields and mods stay in the document
---@param modUUID string
---@return boolean saved False when the document is protected
function ModListVisibility:UseDefault(modUUID)
    if self:IsProtected() then
        return false
    end
    if not self:HasChoice(modUUID) then
        return true
    end
    local ui = table.deepcopy(self.store.Get("UI"))
    ui.Mods[modUUID].HiddenFromList = nil
    if next(ui.Mods[modUUID]) == nil then
        ui.Mods[modUUID] = nil
    end
    return self.store.Set("UI", ui)
end
