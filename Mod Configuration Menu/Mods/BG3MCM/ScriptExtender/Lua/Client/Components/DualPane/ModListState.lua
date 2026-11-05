------------------------------------------------------------
-- ModListState
-- Splits present mod entries into the main list and Hidden mods: player choice, then author default, then visible.
-- Only player choices are saved in the MCM state document, so updated author defaults still apply.
-- An invalid document resolves as empty and refuses changes; Store refuses writes to an unreadable file.
------------------------------------------------------------

---@class SavedModListChoice
---@field HiddenFromList? boolean
---@field Pinned? boolean
---@field Folder? string|false

---@class SavedModListFolder
---@field Name string
---@field Suggested? string
---@field Pinned? boolean

---@class SavedModListUI
---@field Mods? table<string, SavedModListChoice>
---@field Folders? table<string, SavedModListFolder>
---@field Order? table<string, string[]>

---@class ModListInput
---@field id string
---@field name string

---@class ModListAuthorDefaults
---@field HiddenFromList? boolean
---@field ListFolder? string

---@class ResolvedModListEntry: ModListInput
---@field kind "mod"|"folder"
---@field pinned? boolean
---@field suggested? string
---@field virtual? boolean
---@field items? ResolvedModListEntry[] Folder contents
---@field members? string[] Folder members, including hidden mods

---@class ResolvedModList
---@field main ResolvedModListEntry[]
---@field hidden ResolvedModListEntry[]

---@alias ModListMoveFailure "nested"|"unchanged"|"unavailable"|"save"

--- Validate a saved mod choice without coercing invalid fields.
---@param mod unknown
---@return boolean
local function validModChoice(mod)
    if type(mod) ~= "table" then
        return false
    end
    return (mod.HiddenFromList == nil or type(mod.HiddenFromList) == "boolean")
        and (mod.Pinned == nil or type(mod.Pinned) == "boolean")
        and (mod.Folder == nil or type(mod.Folder) == "string" or mod.Folder == false)
end

--- Validate a saved folder definition.
---@param folder unknown
---@return boolean
local function validFolder(folder)
    if type(folder) ~= "table" or type(folder.Name) ~= "string" then
        return false
    end
    return (folder.Suggested == nil or type(folder.Suggested) == "string")
        and (folder.Pinned == nil or type(folder.Pinned) == "boolean")
end

--- Saved orders must be dense arrays of entry IDs.
---@param order unknown
---@return boolean
local function validOrder(order)
    if type(order) ~= "table" then
        return false
    end
    local count = 0
    for index, entry in pairs(order) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or type(entry) ~= "string" then
            return false
        end
        count = count + 1
    end
    return count == #order
end

--- Validate the persisted mod-list fields without changing the document.
---@param ui unknown
---@return boolean
local function validSavedUI(ui)
    if ui == nil then
        return true
    end
    if type(ui) ~= "table" then
        return false
    end
    for _, key in ipairs({ "Mods", "Folders", "Order" }) do
        if ui[key] ~= nil and type(ui[key]) ~= "table" then
            return false
        end
    end
    for id, mod in pairs(ui.Mods or {}) do
        if type(id) ~= "string" or not validModChoice(mod) then
            return false
        end
    end
    for id, folder in pairs(ui.Folders or {}) do
        if type(id) ~= "string" or not validFolder(folder) then
            return false
        end
    end
    for id, order in pairs(ui.Order or {}) do
        if type(id) ~= "string" or not validOrder(order) then
            return false
        end
    end
    return true
end

-- Client-only: local menu preferences never sync to the server or to other players
---@type MCMStoreRegisterOptions
local STATE_VAR_OPTIONS = {
    storage = "json",
    storageConfig = { fileName = "MCM_state.json", SyncToClient = false, SyncToServer = false },
}

---@class ModListState
---@field private store MCMStoreAPI MCM.Store, or an in-memory stand-in in tests
ModListState = _Class:Create("ModListState", nil, {
    store = nil,
})

--- Register the MCM state document variable; no default, because Store writes defaults to the file immediately
---@param store MCMStoreAPI
---@return ModListState
function ModListState:New(store)
    local obj = setmetatable({}, ModListState)
    obj.store = store
    store.RegisterVar("UI", STATE_VAR_OPTIONS)
    return obj
end

--- Read the player's saved choice for one mod
---@private
---@param modUUID string
---@return boolean|nil hidden The player's explicit choice, or nil when there is none
function ModListState:getChoice(modUUID)
    local ui = self.store.Get("UI")
    if not validSavedUI(ui) or not ui or not ui.Mods then
        return nil
    end
    local choice = ui.Mods[modUUID]
    return choice and choice.HiddenFromList
end

---@class ModListResolution
---@field result ResolvedModList
---@field groups table<string, ResolvedModListEntry[]>
---@field folders table<string, ResolvedModListEntry>

--- Build the visible folder catalog without changing saved definitions.
---@param folders table<string, SavedModListFolder>
---@return ModListResolution
local function beginResolution(folders)
    local result = { main = {}, hidden = {} }
    local context = { result = result, groups = { Main = result.main, Hidden = result.hidden }, folders = {} }
    for id, folder in pairs(folders) do
        local item = {
            kind = "folder",
            id = id,
            name = folder.Name,
            pinned = folder.Pinned == true,
            suggested = folder.Suggested,
            items = {},
            members = {},
        }
        context.folders[id] = item
        context.groups[id] = item.items
        table.insert(result.main, item)
    end
    return context
end

--- Reuse persisted associations before matching names or creating a virtual folder.
---@param context ModListResolution
---@param suggested string
---@return string folderId
local function resolveSuggestedFolder(context, suggested)
    for id, folder in pairs(context.folders) do
        if folder.suggested == suggested then
            return id
        end
    end
    for id, folder in pairs(context.folders) do
        if folder.name:lower() == suggested:lower() then
            folder.suggested = suggested
            return id
        end
    end
    for id, folder in pairs(context.folders) do
        if folder.suggested and folder.suggested:lower() == suggested:lower() then
            return id
        end
    end
    local id = "suggested:" .. suggested:lower()
    local folder = {
        kind = "folder",
        id = id,
        name = suggested,
        suggested = suggested,
        virtual = true,
        items = {},
        members = {},
    }
    context.folders[id] = folder
    context.groups[id] = folder.items
    table.insert(context.result.main, folder)
    return id
end

--- Place one mod using player choices before author defaults.
---@param context ModListResolution
---@param mod ModListInput
---@param choice SavedModListChoice
---@param defaults ModListAuthorDefaults
local function assignMod(context, mod, choice, defaults)
    local folderId = choice.Folder
    if folderId == nil and defaults.ListFolder then
        folderId = resolveSuggestedFolder(context, defaults.ListFolder)
    end
    local folder = context.folders[folderId]
    if folder then
        table.insert(folder.members, mod.id)
    end
    local hidden = choice.HiddenFromList
    if hidden == nil then
        hidden = defaults.HiddenFromList
    end
    local group = hidden and context.result.hidden or (context.groups[folderId] or context.result.main)
    table.insert(group, {
        kind = "mod",
        id = mod.id,
        name = mod.name,
        pinned = choice.Pinned == true,
    })
end

--- Pinned entries precede manual order; entries without a position sort by name.
---@param items ResolvedModListEntry[]
---@param order string[]
local function sortResolvedGroup(items, order)
    local positions = {}
    for index, id in ipairs(order) do
        positions[id] = index
    end
    table.sort(items, function(a, b)
        if (a.pinned == true) ~= (b.pinned == true) then
            return a.pinned == true
        end
        local aPosition, bPosition = positions[a.id], positions[b.id]
        if aPosition and bPosition then
            return aPosition < bPosition
        end
        if aPosition or bPosition then
            return aPosition ~= nil
        end
        local aName, bName = a.name:lower(), b.name:lower()
        if aName == bName then
            return a.id < b.id
        end
        return aName < bName
    end)
end

--- Resolve present mods into ordered main and hidden groups.
---@param mods ModListInput[]
---@param authorDefaults? table<string, ModListAuthorDefaults>
---@return ResolvedModList result
function ModListState:Resolve(mods, authorDefaults)
    local ui = self.store.Get("UI")
    if not validSavedUI(ui) then
        ui = nil
    end
    ui = ui or {}
    local choices = ui.Mods or {}
    local orders = ui.Order or {}
    local context = beginResolution(ui.Folders or {})
    for _, mod in ipairs(mods) do
        local defaults = authorDefaults and authorDefaults[mod.id] or {}
        assignMod(context, mod, choices[mod.id] or {}, defaults)
    end
    for index = #context.result.main, 1, -1 do
        local folder = context.result.main[index]
        if folder.virtual and #folder.items == 0 then
            table.remove(context.result.main, index)
        end
    end
    for id, items in pairs(context.groups) do
        sortResolvedGroup(items, orders[id] or {})
    end
    return context.result
end

--- Save an explicit Hide (true) or Show (false) choice for one mod; choices for other mods, present or not, stay in the document
---@param modUUID string
---@param hidden boolean
---@return boolean saved False when the save was refused
function ModListState:SetHidden(modUUID, hidden)
    return self:change(function(ui)
        ui.Mods = ui.Mods or {}
        ui.Mods[modUUID] = ui.Mods[modUUID] or {}
        ui.Mods[modUUID].HiddenFromList = hidden
    end)
end

--- Check whether the player saved Hide or Show for one mod
---@param modUUID string
---@return boolean hasChoice Whether the player saved Hide or Show for the mod
function ModListState:HasChoice(modUUID)
    return self:getChoice(modUUID) ~= nil
end

--- Remove the player's choice so the mod follows its author default again; other fields and mods stay in the document
---@param modUUID string
---@return boolean saved False when the save was refused
function ModListState:UseDefault(modUUID)
    if not self:HasChoice(modUUID) then
        return true
    end
    return self:change(function(ui)
        ui.Mods[modUUID].HiddenFromList = nil
        if next(ui.Mods[modUUID]) == nil then
            ui.Mods[modUUID] = nil
        end
    end)
end

--- Apply a change to a copy of the state document.
---@private
---@param change fun(ui: SavedModListUI)
---@return boolean saved False when the document is invalid or Store refuses the write
function ModListState:change(change)
    local saved = self.store.Get("UI")
    if not validSavedUI(saved) then
        return false
    end
    local ui = table.deepcopy(saved or {})
    change(ui)
    return self.store.Set("UI", ui)
end

--- Reserve a new folder ID without reusing references belonging to unloaded mods.
---@param resolved ResolvedModList|nil
---@return string|nil id Nil when the saved document is invalid
function ModListState:NextFolderId(resolved)
    local ui = self.store.Get("UI")
    if not validSavedUI(ui) then
        return nil
    end
    ui = ui or {}
    local used = {}
    for _, folder in ipairs(resolved and resolved.main or {}) do
        used[folder.id] = true
    end
    for id in pairs(ui.Folders or {}) do
        used[id] = true
    end
    for _, choice in pairs(ui.Mods or {}) do
        if choice.Folder then
            used[choice.Folder] = true
        end
    end
    for group, order in pairs(ui.Order or {}) do
        used[group] = true
        for _, id in ipairs(order) do
            used[id] = true
        end
    end
    local number = 1
    while used["folder-" .. number] do
        number = number + 1
    end
    return "folder-" .. number
end

--- Apply a pin change inside the caller's state transaction.
---@param ui SavedModListUI
---@param id string
---@param pinned boolean
---@param kind "mod"|"folder"|nil
---@param folder ResolvedModListEntry|nil Required when materializing an unsaved folder
local function applyPinnedChoice(ui, id, pinned, kind, folder)
    if kind == "folder" then
        ui.Folders = ui.Folders or {}
        ui.Folders[id] = ui.Folders[id] or { Name = folder.name, Suggested = folder.suggested }
        ui.Folders[id].Pinned = pinned and true or nil
    else
        ui.Mods = ui.Mods or {}
        ui.Mods[id] = ui.Mods[id] or {}
        ui.Mods[id].Pinned = pinned and true or nil
    end
end

---@param id string
---@param pinned boolean
---@param kind? "mod"|"folder"
---@param folder? ResolvedModListEntry Resolved folder metadata
---@return boolean
function ModListState:SetPinned(id, pinned, kind, folder)
    return self:change(function(ui)
        applyPinnedChoice(ui, id, pinned, kind, folder)
    end)
end

---@param id string
---@param folder string|false
---@param folderItem? ResolvedModListEntry Resolved folder metadata
---@return boolean
function ModListState:SetFolder(id, folder, folderItem)
    return self:change(function(ui)
        ui.Mods = ui.Mods or {}
        ui.Mods[id] = ui.Mods[id] or {}
        ui.Mods[id].Folder = folder
        ui.Mods[id].HiddenFromList = false
        local suggested = folderItem and folderItem.suggested
        if suggested then
            ui.Folders = ui.Folders or {}
            ui.Folders[folder] = ui.Folders[folder] or { Name = folderItem.name, Suggested = suggested }
        end
    end)
end

---@param id string
---@param name string
---@param suggested? string
---@param modUUID? string
---@return boolean
function ModListState:CreateFolder(id, name, suggested, modUUID)
    return self:change(function(ui)
        ui.Folders = (ui.Folders or {})
        ui.Folders[id] = { Name = name, Suggested = suggested }
        if modUUID then
            ui.Mods = (ui.Mods or {})
            ui.Mods[modUUID] = (ui.Mods[modUUID] or {})
            ui.Mods[modUUID].Folder = id
            ui.Mods[modUUID].HiddenFromList = false
        end
        ui.Order = (ui.Order or {})
        ui.Order.Main = (ui.Order.Main or {})
        table.insert(ui.Order.Main, 1, id)
    end)
end

---@param id string
---@param name string
---@param folder? ResolvedModListEntry Resolved folder metadata
---@return boolean
function ModListState:RenameFolder(id, name, folder)
    return self:change(function(ui)
        ui.Folders = ui.Folders or {}
        local suggested = folder and folder.suggested
        ui.Folders[id] = ui.Folders[id] or { Suggested = suggested }
        ui.Folders[id].Name = name
        if suggested then
            ui.Folders[id].Suggested = suggested
        end
    end)
end

---@param id string
---@param mods? string[] Mods resolved into this folder, including author defaults
---@return boolean
function ModListState:DeleteFolder(id, mods)
    return self:change(function(ui)
        ui.Mods = (ui.Mods or {})
        for _, choice in pairs(ui.Mods) do
            if type(choice) == "table" and choice.Folder == id then choice.Folder = false end
        end
        for _, mod in ipairs(mods or {}) do
            ui.Mods[mod] = (ui.Mods[mod] or {})
            ui.Mods[mod].Folder = false
        end
        if type(ui.Folders) == "table" then ui.Folders[id] = nil end
        if type(ui.Order) == "table" then
            ui.Order[id] = nil
            if type(ui.Order.Main) == "table" then
                for i = #ui.Order.Main, 1, -1 do if ui.Order.Main[i] == id then table.remove(ui.Order.Main, i) end end
            end
        end
    end)
end

--- Locate a destination group and its folder metadata, if it is a custom folder.
---@param resolved ResolvedModList
---@param destination string
---@return ResolvedModListEntry[]|nil items
---@return ResolvedModListEntry|nil folder
local function destinationGroup(resolved, destination)
    if destination == "Main" then
        return resolved.main
    end
    if destination == "Hidden" then
        return resolved.hidden
    end
    for _, folder in ipairs(resolved.main) do
        if folder.kind == "folder" and folder.id == destination then
            return folder.items, folder
        end
    end
end

--- Return the visible position of an entry within a group.
---@param entries ResolvedModListEntry[]
---@param wanted ResolvedModListEntry
---@return integer|nil
local function entryPosition(entries, wanted)
    for index, entry in ipairs(entries) do
        if entry.id == wanted.id and entry.kind == wanted.kind then
            return index
        end
    end
end

---@class ModListMovePlan
---@field item ResolvedModListEntry
---@field source string
---@field destination string
---@field entries ResolvedModListEntry[]
---@field target? ResolvedModListEntry
---@field folder? ResolvedModListEntry
---@field insertAfter boolean
---@field pinned? boolean New pin value for a same-group drop across pin sections

--- Validate the drop before creating a copy of saved state.
---@param item ResolvedModListEntry
---@param source string
---@param destination string
---@param target ResolvedModListEntry|nil
---@param resolved ResolvedModList
---@return ModListMovePlan|nil plan
---@return ModListMoveFailure|nil reason
local function planMove(item, source, destination, target, resolved)
    if item.kind == "folder" and destination ~= "Main" then
        return nil, "nested"
    end
    if source == destination and not target then
        return nil, "unchanged"
    end
    local entries, folder = destinationGroup(resolved, destination)
    if not entries or (target and not entryPosition(entries, target)) then
        return nil, "unavailable"
    end
    local sameGroup = source == destination
    local pinned = item.pinned == true
    local changedPin
    if target and pinned ~= (target.pinned == true) and sameGroup then
        changedPin = target.pinned == true
    elseif target and pinned ~= (target.pinned == true) then
        -- Moving between groups preserves the source pin instead of adopting the target's section.
        target = nil
    end
    if target and item.id == target.id then
        return nil, "unchanged"
    end
    local sourcePosition = source == destination and entryPosition(entries, item)
    local targetPosition = target and entryPosition(entries, target)
    return {
        item = item,
        source = source,
        destination = destination,
        entries = entries,
        target = target,
        folder = folder,
        pinned = changedPin,
        insertAfter = sourcePosition and targetPosition and sourcePosition < targetPosition or false,
    }
end

--- Keep unloaded entries while moving relative to the visible target.
---@param ui SavedModListUI
---@param plan ModListMovePlan
local function applyMoveOrder(ui, plan)
    ui.Order = ui.Order or {}
    local order = ui.Order[plan.destination] or {}
    local present = {}
    for _, id in ipairs(order) do
        present[id] = true
    end
    for _, entry in ipairs(plan.entries) do
        if not present[entry.id] then
            table.insert(order, entry.id)
        end
    end
    for index = #order, 1, -1 do
        if order[index] == plan.item.id then
            table.remove(order, index)
        end
    end
    local insertionIndex = #order + 1
    if plan.target then
        for index, id in ipairs(order) do
            if id == plan.target.id then
                insertionIndex = index
                break
            end
        end
        if plan.insertAfter then
            insertionIndex = insertionIndex + 1
        end
    end
    table.insert(order, insertionIndex, plan.item.id)
    ui.Order[plan.destination] = order
end

--- Moving to Hidden retains folder membership; other destinations reveal the mod.
---@param ui SavedModListUI
---@param plan ModListMovePlan
local function applyMoveMembership(ui, plan)
    local folder = plan.folder
    if folder and folder.suggested then
        ui.Folders = ui.Folders or {}
        ui.Folders[plan.destination] = ui.Folders[plan.destination]
            or { Name = folder.name, Suggested = folder.suggested }
    end
    if plan.item.kind ~= "mod" or plan.source == plan.destination then
        return
    end
    ui.Mods = ui.Mods or {}
    local choice = ui.Mods[plan.item.id] or {}
    ui.Mods[plan.item.id] = choice
    choice.HiddenFromList = plan.destination == "Hidden"
    if plan.destination ~= "Hidden" then
        choice.Folder = plan.destination ~= "Main" and plan.destination or false
    end
end

--- Move an item using resolved group entries; target is nil to append.
---@param item ResolvedModListEntry
---@param source string
---@param destination string
---@param target? ResolvedModListEntry
---@param resolved ResolvedModList
---@return boolean saved
---@return ModListMoveFailure|nil reason
function ModListState:Move(item, source, destination, target, resolved)
    local plan, reason = planMove(item, source, destination, target, resolved)
    if not plan then
        return false, reason
    end
    local saved = self:change(function(ui)
        applyMoveOrder(ui, plan)
        applyMoveMembership(ui, plan)
        if plan.pinned ~= nil then
            applyPinnedChoice(ui, item.id, plan.pinned, item.kind, item)
        end
    end)
    if not saved then
        return false, "save"
    end
    return true
end

---@param group string
---@return boolean
function ModListState:SortGroup(group)
    return self:change(function(ui) if type(ui.Order) == "table" then ui.Order[group] = nil end end)
end

--- Group visible folders before loose mods, retaining relative order and unloaded references.
---@param resolved ResolvedModList
---@return boolean saved
function ModListState:SortFoldersFirst(resolved)
    return self:change(function(ui)
        local order, present = {}, {}
        for _, kind in ipairs({ "folder", "mod" }) do
            for _, entry in ipairs(resolved.main) do
                if entry.kind == kind then
                    table.insert(order, entry.id)
                    present[entry.id] = true
                end
            end
        end
        ui.Order = ui.Order or {}
        for _, id in ipairs(ui.Order.Main or {}) do
            if not present[id] then
                table.insert(order, id)
            end
        end
        ui.Order.Main = order
    end)
end
