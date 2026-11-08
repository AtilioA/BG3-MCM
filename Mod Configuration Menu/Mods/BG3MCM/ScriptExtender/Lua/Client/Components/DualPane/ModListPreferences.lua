------------------------------------------------------------
-- ModListPreferences
-- Personal list order, grouping and usage history, kept apart from MCM_state.json so collections never ship them.
-- Recently used and Frequently used re-rank after each counted opening, when MCM closes or hides, and when the player changes the order.
------------------------------------------------------------

---@alias ModListSortMode "alphabetical"|"manual"|"recent"|"frequent"

---@class ModListUsageRecord
---@field Count integer Times the player opened the mod's page from the list
---@field Last integer Global sequence of the latest opening

---@class ModListUsage
---@field Sequence? integer
---@field Mods? table<string, ModListUsageRecord>

---@class SavedModListPreferences
---@field SortMode? ModListSortMode
---@field FoldersFirst? boolean
---@field Usage? ModListUsage
---@field CollapsedFolders? table<string, true> Folder IDs the player closed; any other folder, including a new one, opens

---@class ModListView
---@field mode ModListSortMode
---@field foldersFirst boolean
---@field usage ModListUsage Ranks frozen for this session

local VAR_NAME = "ModListPreferences"

local SORT_MODES = { alphabetical = true, manual = true, recent = true, frequent = true }

-- Client-only: personal preferences never sync to the server or to other players
---@type MCMStoreRegisterOptions
local VAR_OPTIONS = {
    storage = "json",
    storageConfig = { fileName = "MCM_mod_list_preferences.json", SyncToClient = false, SyncToServer = false },
}

--- Counters and sequence positions are whole numbers from zero up.
---@param value unknown
---@return boolean
local function validCounter(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

--- Validate saved usage without coercing invalid fields.
---@param usage unknown
---@return boolean
local function validUsage(usage)
    if type(usage) ~= "table" then
        return false
    end
    if usage.Sequence ~= nil and not validCounter(usage.Sequence) then
        return false
    end
    if usage.Mods ~= nil and type(usage.Mods) ~= "table" then
        return false
    end
    for id, record in pairs(usage.Mods or {}) do
        if type(id) ~= "string" or type(record) ~= "table"
            or not validCounter(record.Count) or not validCounter(record.Last)
            or record.Last > (usage.Sequence or 0) then
            return false
        end
    end
    return true
end

--- Only closed folders are listed, so every value is true.
---@param folders unknown
---@return boolean
local function validCollapsedFolders(folders)
    if type(folders) ~= "table" then
        return false
    end
    for id, open in pairs(folders) do
        if type(id) ~= "string" or open ~= true then
            return false
        end
    end
    return true
end

--- Validate the saved document without changing it.
---@param saved unknown
---@return boolean
local function validPreferences(saved)
    if saved == nil then
        return true
    end
    if type(saved) ~= "table" then
        return false
    end
    return (saved.SortMode == nil or SORT_MODES[saved.SortMode] == true)
        and (saved.FoldersFirst == nil or type(saved.FoldersFirst) == "boolean")
        and (saved.Usage == nil or validUsage(saved.Usage))
        and (saved.CollapsedFolders == nil or validCollapsedFolders(saved.CollapsedFolders))
end

---@class ModListPreferences
---@field private store MCMStoreAPI MCM.Store, or an in-memory stand-in in tests
---@field private frozenUsage ModListUsage|nil
---@field private warnedInvalid boolean
ModListPreferences = _Class:Create("ModListPreferences", nil, {
    store = nil,
    frozenUsage = nil,
    warnedInvalid = false,
})

--- Register the preferences variable; no default, because Store writes defaults to the file immediately
---@param store MCMStoreAPI
---@return ModListPreferences
function ModListPreferences:New(store)
    local obj = setmetatable({}, ModListPreferences)
    obj.store = store
    store.RegisterVar(VAR_NAME, VAR_OPTIONS)
    return obj
end

--- Whether the saved document is unreadable or has values MCM cannot use; absent fields are valid.
---@return boolean
function ModListPreferences:IsInvalid()
    return not self.store.IsWritable(VAR_NAME) or not validPreferences(self.store.Get(VAR_NAME))
end

--- An invalid document stays on disk unchanged and reads as empty; the first read logs the recovery steps.
---@private
---@return SavedModListPreferences
function ModListPreferences:read()
    if not self:IsInvalid() then
        return self.store.Get(VAR_NAME) or {}
    end
    if not self.warnedInvalid then
        self.warnedInvalid = true
        MCMWarn(0, "ModListPreferences: %s has invalid values. MCM keeps the file unchanged and refuses changes. Repair or delete the file, then reload.",
            VAR_OPTIONS.storageConfig.fileName)
    end
    return {}
end

--- Apply a change to a copy of the document.
---@private
---@param change fun(saved: SavedModListPreferences)
---@return boolean saved False when the document is invalid or Store refuses the write
function ModListPreferences:change(change)
    local saved = self.store.Get(VAR_NAME)
    if not validPreferences(saved) then
        return false
    end
    local copy = table.deepcopy(saved or {})
    change(copy)
    return self.store.Set(VAR_NAME, copy)
end

---@return ModListSortMode
function ModListPreferences:GetSortMode()
    return self:read().SortMode or "alphabetical"
end

---@return boolean
function ModListPreferences:GetFoldersFirst()
    return self:read().FoldersFirst == true
end

--- Read the view that orders the list; this never writes.
---@return ModListView
function ModListPreferences:GetView()
    if not self.frozenUsage then
        self.frozenUsage = table.deepcopy(self:read().Usage or {})
    end
    return { mode = self:GetSortMode(), foldersFirst = self:GetFoldersFirst(), usage = self.frozenUsage }
end

--- Save an explicit player change and rank from current usage on the next read.
---@private
---@param change fun(saved: SavedModListPreferences)
---@return boolean saved
function ModListPreferences:changeView(change)
    local saved = self:change(change)
    if saved then
        self.frozenUsage = nil
    end
    return saved
end

---@param mode ModListSortMode
---@return boolean saved
function ModListPreferences:SetSortMode(mode)
    return self:changeView(function(preferences) preferences.SortMode = mode end)
end

---@param enabled boolean
---@return boolean saved
function ModListPreferences:SetFoldersFirst(enabled)
    return self:changeView(function(preferences) preferences.FoldersFirst = enabled end)
end

--- Save what a reorder changes in the view, in one write.
---@param switchToManual boolean
---@param clearFoldersFirst boolean
---@return boolean saved
function ModListPreferences:ApplyReorder(switchToManual, clearFoldersFirst)
    if not switchToManual and not clearFoldersFirst then
        return true
    end
    return self:changeView(function(preferences)
        if switchToManual then preferences.SortMode = "manual" end
        if clearFoldersFirst then preferences.FoldersFirst = false end
    end)
end

--- Remove only usage; the mode, grouping and layout stay.
---@return boolean saved
function ModListPreferences:ClearUsage()
    return self:changeView(function(preferences) preferences.Usage = nil end)
end

--- Folders open unless the player closed them, so new and author-suggested folders start open.
---@param folderId string
---@return boolean
function ModListPreferences:IsFolderExpanded(folderId)
    return (self:read().CollapsedFolders or {})[folderId] ~= true
end


--- Save whether a folder is open; an unchanged state writes nothing.
---@param folderId string
---@param expanded boolean
---@return boolean saved
function ModListPreferences:SetFolderExpanded(folderId, expanded)
    if self:IsFolderExpanded(folderId) == expanded then
        return true
    end
    return self:change(function(preferences)
        preferences.CollapsedFolders = preferences.CollapsedFolders or {}
        preferences.CollapsedFolders[folderId] = (not expanded) or nil
        if next(preferences.CollapsedFolders) == nil then preferences.CollapsedFolders = nil end
    end)
end

--- Count one page opening; frozen ranks stay unchanged.
---@param modUUID string
---@return boolean saved
function ModListPreferences:RecordOpen(modUUID)
    return self:change(function(preferences)
        local usage = preferences.Usage or {}
        preferences.Usage = usage
        usage.Sequence = (usage.Sequence or 0) + 1
        usage.Mods = usage.Mods or {}
        local record = usage.Mods[modUUID] or { Count = 0 }
        record.Count = record.Count + 1
        record.Last = usage.Sequence
        usage.Mods[modUUID] = record
    end)
end

--- Start a new ranking session.
---@return boolean changed True when the new ranks can change the displayed order
function ModListPreferences:RefreshRanks()
    local preferences = self:read()
    local mode = preferences.SortMode
    local sequence = (preferences.Usage or {}).Sequence or 0
    local changed = (mode == "recent" or mode == "frequent")
        and sequence ~= ((self.frozenUsage or {}).Sequence or 0)
    self.frozenUsage = nil
    return changed
end
