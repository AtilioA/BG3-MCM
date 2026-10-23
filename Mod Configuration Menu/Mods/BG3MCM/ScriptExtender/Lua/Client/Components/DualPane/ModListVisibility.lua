------------------------------------------------------------
-- ModListVisibility
-- Splits present mod entries into the main list and Hidden mods, from the player's choices in the MCM state document.
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
    return obj
end

--- Split present mod entries; both lists keep the input order
---@param modUUIDs string[] Present mod UUIDs, already sorted for the mod list
---@return string[] main
---@return string[] hidden
---@return integer hiddenCount
function ModListVisibility:Resolve(modUUIDs)
    local ui = self.store.Get("UI")
    local choices = ui and ui.Mods or {}
    local main, hidden = {}, {}
    for _, modUUID in ipairs(modUUIDs) do
        local choice = choices[modUUID]
        if choice and choice.HiddenFromList == true then
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
function ModListVisibility:SetHidden(modUUID, hidden)
    local ui = table.deepcopy(self.store.Get("UI") or {})
    ui.Mods = ui.Mods or {}
    ui.Mods[modUUID] = ui.Mods[modUUID] or {}
    ui.Mods[modUUID].HiddenFromList = hidden
    if self.store.Get("Version") == nil then
        self.store.Set("Version", STATE_VERSION)
    end
    self.store.Set("UI", ui)
end
