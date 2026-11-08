------------------------------------------------------------
-- LeftPane Component
-- Manages the left pane (menu) of the dual-pane layout.
------------------------------------------------------------
---@class ModListDragPayload
---@field kind "mod"|"folder"|"group"
---@field id string
---@field group string
---@field section boolean|nil True for a Pinned heading or boundary, whose reference entry only positions the drop

---@class LeftPane
---@field parent ExtuiStyledRenderable
---@field modEntriesGroup ExtuiGroup|nil Holds only mod entries, so they can be rebuilt without touching other entries
---@field hiddenModsHeader ExtuiTree|nil Hidden mods header inside modEntriesGroup
---@field modEntryMenu ExtuiPopup|nil Right-click menu shared by all mod entries
---@field mods table<string, ModSettings>|nil Mods from the last RebuildModEntries call
---@field visibility ModListState
---@field activeUUID string|nil UUID of the highlighted entry
---@field mainDropTargets table<string, ExtuiButton> Main-list destinations placed after their source groups
---@field newFolderId string|nil Folder created last; its header blinks once on the next render
---@field listSettings ModListSettings|nil Mod list section on MCM's Sidebar tab, once rendered
LeftPane = _Class:Create("LeftPane", nil, {
    parent = nil,
    modEntriesGroup = nil,
    hiddenModsHeader = nil,
    modEntryMenu = nil,
    mods = nil,
    visibility = nil,
    activeUUID = nil,
})
LeftPane.__index = LeftPane

-- Template that marks the menu item matching the author default, such as "Hide (Default)"
local DEFAULT_SUFFIX_HANDLE = "hcb10ab3d15cd177683b0b8c2076b4499ccdc"

function LeftPane:New(parent)
    local self = setmetatable({}, LeftPane)
    self.parent = parent -- Should:tm: be the menuScrollChildWindow
    self.expandedGroups = {}
    self.entryButtons = {}
    self.visibility = ModListState:New(MCM.Store)
    return self
end

function LeftPane:AddMenuSeparator(text)
    self.parent:AddSeparatorText(text)
end

---@param text string
---@param description string|nil
---@param uuid string
---@param parent ExtuiTreeParent|nil Container for the button. Defaults to self.parent
---@return ExtuiButton
function LeftPane:CreateMenuButton(text, description, uuid, parent)
    local button = (parent or self.parent):AddButton(text)
    button.Size = { -2, 50 }
    button:SetStyle("ButtonTextAlign", 0, 0.5)
    button.IDContext = "MenuButton_" .. text .. "_" .. uuid
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    button.OnClick = function() self:OpenFromList(button, uuid) end
    if description and description ~= "" then
        IMGUIHelpers.AddTooltip(button, description, "MenuButton_" .. text .. "_" .. uuid .. "_TOOLTIP")
    end
    return button
end

--- The player's activation of a list entry; IMGUI runs OnClick for mouse, keyboard and controller alike.
--- API and restoration navigation skip this path, so only this path counts usage.
---@param button ExtuiButton
---@param uuid string
function LeftPane:OpenFromList(button, uuid)
    local changesPage = self.activeUUID ~= uuid
    -- Auto-reattach if mod is currently detached
    if DualPane.rightPane.detachedWindows[uuid] then
        DualPane.rightPane:ReattachModGroup(uuid)
    end
    DualPane:SwitchVisibleContent(button, uuid)
    -- Tools such as Hotkeys and Profiles have no entry in self.mods.
    if not changesPage or uuid == ModuleUUID or not (self.mods and self.mods[uuid]) then
        return
    end
    local preferences = self.visibility.preferences
    -- Frequently used reorders at once; Recently used keeps the list still until MCM closes or hides.
    if preferences:RecordOpen(uuid) and preferences:GetSortMode() == "frequent" and preferences:RefreshRanks() then
        self:RebuildModEntries(self.mods)
    end
end

--- Apply the usage of the ended session; Recently used stays as it is until MCM closes or the visibility hotkey hides it.
function LeftPane:StartRankingSession()
    if self.visibility.preferences:RefreshRanks() and self.mods then
        self:RebuildModEntries(self.mods)
    end
end

-- Width of the folder name input
local FOLDER_NAME_INPUT_WIDTH = 320

---@param key string
---@param held boolean
local function holdSidebar(key, held)
    if DualPane and DualPane.HoldSidebar then DualPane:HoldSidebar(key, held) end
end

--- Keep the sidebar open while the pointer is on a popup widget; a popup can extend outside the sidebar.
---@param widget ExtuiStyledRenderable
local function holdSidebarWhileHovered(widget)
    widget.OnHoverEnter = function() holdSidebar("menuRow", true) end
    widget.OnHoverLeave = function() holdSidebar("menuRow", false) end
end

--- A click can close the popup without a hover leave, so the hold also ends with the click.
---@param row ExtuiStyledRenderable
---@param action fun()
local function setPopupRowAction(row, action)
    holdSidebarWhileHovered(row)
    row.OnClick = function()
        holdSidebar("menuRow", false)
        action()
    end
end

--- Create a sidebar popup with the MCM tooltip frame, so all sidebar popovers read as one family
---@param parent ExtuiTreeParent
---@param id string
---@return ExtuiPopup
local function addStyledPopup(parent, id)
    local popup = parent:AddPopup(id)
    popup:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
    -- Match the configured window opacity while avoiding the sidebar fade
    popup:SetStyle("Alpha", DualPane and DualPane.windowOpacity or 1)
    popup:SetStyle("PopupBorderSize", 2)
    popup:SetStyle("WindowPadding", 12, 10)
    popup:SetStyle("ItemSpacing", 8, 6)
    popup:SetSizeConstraints({ 200, 0 })
    return popup
end

---@param folderId string|nil
---@param modUUID string|nil
function LeftPane:OpenFolderNamePopup(folderId, modUUID)
    if self.namePopup then self.namePopup:Destroy() end
    local popup = addStyledPopup(self.parent, "MCM_FolderName")
    self.namePopup = popup
    local initial = ""
    local selectedFolder
    for _, folder in ipairs((self.resolved or {}).main or {}) do
        if folder.id == folderId then
            initial = folder.name
            selectedFolder = folder
        end
    end
    local title = popup:AddText(Ext.Loca.GetTranslatedString(folderId and "h24ca58cb5e534e658e3ff773c73b12c4e522" or
        "h3528e5d91a66432f89f8a43cf3c33feac579"))
    title:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    popup:AddSeparator()
    popup:AddText(Ext.Loca.GetTranslatedString("h77a53621d61b4a3d92c841adaec0a86be116"))
    local input = popup:AddInputText("##MCM_FolderNameInput", initial)
    input.ItemWidth = FOLDER_NAME_INPUT_WIDTH
    input.EnterReturnsTrue = true
    -- Keep the sidebar open while the player types; the popup can close without an event, so the hold ends with the input focus
    input.OnActivate = function() holdSidebar("folderName", true) end
    input.OnDeactivate = function() holdSidebar("folderName", false) end
    local errorText = popup:AddText("")
    errorText:SetColor("Text", UIStyle.TextStyles.Error)
    errorText.Visible = false
    local function submit()
        local saved, message = self:SaveFolderName(input.Text, folderId, modUUID, selectedFolder)
        if not saved then
            errorText.Label = message
            errorText.Visible = true
            return
        end
        holdSidebar("folderName", false)
        popup:Destroy()
        self.namePopup = nil
        self:RebuildModEntries(self.mods)
    end
    input.OnChange = submit
    local save = popup:AddButton(Ext.Loca.GetTranslatedString("h7c4ad5e52894403493e8470672f35ebe429c"))
    save.Size = { -1, 0 }
    setPopupRowAction(save, submit)
    local cancel = popup:AddButton(Ext.Loca.GetTranslatedString("hb2cb29912b4449e29cf5f44be0101b2c311f"))
    cancel.Size = { -1, 0 }
    setPopupRowAction(cancel, function()
        holdSidebar("folderName", false)
        popup:Destroy()
        self.namePopup = nil
    end)
    popup:Open()
    input:Activate()
end

--- Validate and save a folder name without closing the editor on failure.
---@param text string
---@param folderId string|nil
---@param modUUID string|nil
---@param selectedFolder ResolvedModListEntry|nil
---@return boolean saved
---@return string|nil message
function LeftPane:SaveFolderName(text, folderId, modUUID, selectedFolder)
    local name = text:gsub("#", ""):match("^%s*(.-)%s*$")
    if name == "" then
        return false, Ext.Loca.GetTranslatedString("hc2051a2144174d438a0acb3adf71ff909a10")
    end
    for _, folder in ipairs((self.resolved or {}).main or {}) do
        if folder.kind == "folder" and folder.id ~= folderId and folder.name:lower() == name:lower() then
            return false, Ext.Loca.GetTranslatedString("h2c86290fc915472a86f8bc681f6b485d253b")
        end
    end
    local saved
    if folderId then
        saved = self.visibility:RenameFolder(folderId, name, selectedFolder)
    else
        local id = self.visibility:NextFolderId(self.resolved)
        if not id then
            return false, Ext.Loca.GetTranslatedString("h3f26d5e1a4c74fd19a2b3c4d5e6f7890abcd")
        end
        saved = self.visibility:CreateFolder(id, name, nil, modUUID)
        if saved then
            -- This window may still remember a failed close for a deleted folder that had this ID.
            self.expandedGroups[id] = nil
            self.newFolderId = id
        end
    end
    return saved, not saved and Ext.Loca.GetTranslatedString("h3f26d5e1a4c74fd19a2b3c4d5e6f7890abcd") or nil
end

--- Return the shared right-click menu, emptied
---@return ExtuiPopup
function LeftPane:resetEntryMenu()
    if not self.modEntryMenu then
        self.modEntryMenu = addStyledPopup(self.parent, "MCM_ModEntryMenu")
    end
    IMGUIHelpers.DestroyChildren(self.modEntryMenu)
    return self.modEntryMenu
end

--- Rebuild navigation after a menu action, or warn when its save was refused; the open settings page stays intact.
---@param saved boolean|nil False when the save was refused
function LeftPane:FinishModListChange(saved)
    if saved ~= false then
        self:RebuildModEntries(self.mods)
        return
    end
    NotificationManager:CreateIMGUINotification("MCM_ModListSave", "warning",
        Ext.Loca.GetTranslatedString("h3f26d5e1a4c74fd19a2b3c4d5e6f7890abcd"),
        Ext.Loca.GetTranslatedString("h07852b32f9c54a09a559289344164f8ag005"),
        { duration = 5, dontShowAgainButton = false }, ModuleUUID)
end

---@param folder ResolvedModListEntry
function LeftPane:OpenFolderMenu(folder)
    local popup = self:resetEntryMenu()
    local name = folder.name
    if folder.id ~= "Main" then
        name = VCString:InterpolateLocalizedMessage("h28a91f4d4dcb4a7ea27baed764cc50c8g001", name)
    end
    local title = popup:AddText(name)
    title:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    holdSidebarWhileHovered(title)
    popup:AddSeparator()
    local function item(label, action)
        popup:AddBulletText("")
        local row = popup:AddSelectable(label, nil, { 0, 28 })
        row.SameLine = true
        setPopupRowAction(row, action)
        return row
    end
    local function change(action)
        self:FinishModListChange(action())
    end
    if folder.id == "Main" then
        item(Ext.Loca.GetTranslatedString("h2e65dd988a5e44f38060c645f30dd7c53fa1"),
            function() self:OpenFolderNamePopup(nil, nil) end)
    else
        item(Ext.Loca.GetTranslatedString("h5387de4db5e84639ba0b992e7358f5de9bb1"),
            function() self:OpenFolderNamePopup(folder.id, nil) end)
        item(Ext.Loca.GetTranslatedString("hd504cdce3ff34f55a7fc0718b6788648a37e"), function()
            change(function()
                local ids = {}
                for _, id in ipairs(folder.members or {}) do table.insert(ids, id) end
                local deleted = self.visibility:DeleteFolder(folder.id, ids)
                if deleted then self.expandedGroups[folder.id] = nil end
                return deleted
            end)
        end)
        item(
            Ext.Loca.GetTranslatedString(folder.pinned and "h145bc3f780224f429de5914b2c83fe2ef99b" or
                "h9a9e01f5b3e7445da14639b5f43a0416bf07"), function()
                change(function()
                    return self.visibility:SetPinned(folder.id, not folder.pinned, "folder", folder)
                end)
            end)
    end
    popup:Open()
end

--- Show the right-click menu for one mod entry; opening it does not select the mod
---@param modUUID string
---@param isHidden boolean Whether the entry is in Hidden mods
function LeftPane:OpenModEntryMenu(modUUID, isHidden)
    self:resetEntryMenu()
    local title = self.modEntryMenu:AddText(self.mods[modUUID].blueprint:GetModName())
    title:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    holdSidebarWhileHovered(title)
    self.modEntryMenu:AddSeparator()
    local isDetached = DualPane.rightPane.detachedWindows[modUUID] ~= nil
    self:AddModMenuAction(
        Ext.Loca.GetTranslatedString(isDetached and "h70c2cfe1a408491b8190b0bdfe7be9eb7116" or
            "hee272f8489fe4bc7a5591935c5710013efc0"), function()
            if isDetached then
                DualPane.rightPane:ReattachModGroup(modUUID)
            else
                DualPane.rightPane:DetachModGroup(modUUID)
            end
        end)
    if modUUID ~= ModuleUUID then
        self.modEntryMenu:AddSeparator()
        self:AddVisibilityAction(modUUID, isHidden)
        self:AddOrganizationActions(modUUID, isHidden)
    end
    self.modEntryMenu:Open()
end

--- Add a menu row that finishes the mod-list change its action makes.
---@param label string
---@param action fun(): boolean|nil
---@param selected boolean|nil
function LeftPane:AddModMenuAction(label, action, selected)
    self.modEntryMenu:AddBulletText("")
    local item = self.modEntryMenu:AddSelectable(label, nil, { 0, 28 })
    item.SameLine = true
    item.Selected = selected == true
    item.Disabled = selected == true
    item:SetStyle("SelectableTextAlign", 0, 0.5)
    setPopupRowAction(item, function()
        self:FinishModListChange(action())
    end)
end

--- Returning to the author default removes the explicit player override.
---@param modUUID string
---@param isHidden boolean
function LeftPane:AddVisibilityAction(modUUID, isHidden)
    local targetHidden = not isHidden
    local authorHidden = self.mods[modUUID].blueprint:GetHiddenFromList() == true
    local matchesDefault = targetHidden == authorHidden
    local label = Ext.Loca.GetTranslatedString(targetHidden and "h31655a10d04449dfb90946ebe22da383f8a2" or
        "h541de1bd8d8d4be8a188742c9011da27b110")
    if matchesDefault then
        label = VCString:InterpolateLocalizedMessage(DEFAULT_SUFFIX_HANDLE, label)
    end
    self:AddModMenuAction(label, function()
        if matchesDefault then
            return self.visibility:UseDefault(modUUID)
        else
            return self.visibility:SetHidden(modUUID, targetHidden)
        end
    end)
end

--- Find the current displayed group, including the Hidden group before folder membership.
---@param modUUID string
---@return ResolvedModListEntry|nil entry
---@return string groupId
function LeftPane:FindModGroup(modUUID)
    for _, entry in ipairs((self.resolved or {}).main or {}) do
        if entry.id == modUUID then
            return entry, "Main"
        end
        for _, child in ipairs(entry.items or {}) do
            if child.id == modUUID then
                return child, entry.id
            end
        end
    end
    for _, entry in ipairs((self.resolved or {}).hidden or {}) do
        if entry.id == modUUID then
            return entry, "Hidden"
        end
    end
    return nil, "Main"
end

--- Offer pinning and membership actions for the selected mod's displayed group.
---@param modUUID string
---@param isHidden boolean
function LeftPane:AddOrganizationActions(modUUID, isHidden)
    local current, currentGroup = self:FindModGroup(modUUID)
    if not current and isHidden then
        currentGroup = "Hidden"
    end
    local pinned = current and current.pinned == true
    self:AddModMenuAction(
        Ext.Loca.GetTranslatedString(pinned and "h145bc3f780224f429de5914b2c83fe2ef99b" or
            "h9a9e01f5b3e7445da14639b5f43a0416bf07"), function()
            return self.visibility:SetPinned(modUUID, not pinned)
        end)
    self.modEntryMenu:AddText(Ext.Loca.GetTranslatedString("ha573c62e2a4a4da1889f6c01adcb3d18e044"))
    self:AddModMenuAction(Ext.Loca.GetTranslatedString("hb06aed8109a44f689d9351a1c469d09ae769"), function()
        return self.visibility:SetFolder(modUUID, false)
    end, currentGroup == "Main")
    for _, folder in ipairs((self.resolved or {}).main or {}) do
        if folder.kind == "folder" then
            self:AddModMenuAction(folder.name .. "##folder_" .. folder.id,
                function() return self.visibility:SetFolder(modUUID, folder.id, folder) end, currentGroup == folder.id)
        end
    end
    self.modEntryMenu:AddBulletText("")
    local newFolder = self.modEntryMenu:AddSelectable(
        Ext.Loca.GetTranslatedString("h2e65dd988a5e44f38060c645f30dd7c53fa1"), nil, { 0, 28 })
    newFolder.SameLine = true
    setPopupRowAction(newFolder, function() self:OpenFolderNamePopup(nil, modUUID) end)
end

--- Connect a sidebar item to the resolved state at the time of the drop.
---@param widget ExtuiStyledRenderable
---@param kind string
---@param id string
---@param groupId string
function LeftPane:ConfigureModListDrag(widget, kind, id, groupId)
    self:ConfigureModListDropTarget(widget, kind, id, groupId)
    widget.CanDrag = kind ~= "group" and not (kind == "mod" and id == ModuleUUID)
    local generation = self.listGeneration
    local dropTarget
    if widget.CanDrag then
        widget.OnDragStart = function(_, preview)
            holdSidebar("drag", true)
            preview:AddText((widget.Label:gsub("^> ", ""):gsub("##.*$", "")))
            -- Place the escape destination below its source group, keeping the dragged row in place.
            if kind == "mod" then
                dropTarget = self.mainDropTargets[groupId]
                if dropTarget then dropTarget.Visible = true end
            end
        end
        widget.OnDragEnd = function()
            holdSidebar("drag", false)
            if dropTarget and self.listGeneration == generation then
                dropTarget.Visible = false
            end
        end
    end
end

--- Non-draggable section labels and empty rows use the same destination rules as entries.
---@param widget ExtuiStyledRenderable
---@param kind string
---@param id string
---@param groupId string
---@param section boolean|nil Whether the entry only positions a drop on a section divider
function LeftPane:ConfigureModListDropTarget(widget, kind, id, groupId, section)
    widget.UserData = { kind = kind, id = id, group = groupId, section = section }
    widget.DragDropType = "MCM_ModList"
    widget.CanDrag = false
    local generation = self.listGeneration
    widget.OnDragDrop = function(_, source)
        if source.UserData then
            self:ApplyModListDrop(widget, source.UserData, generation)
        end
    end
end

-- REFACTOR: Handle loca just not unlike CPF
local DROP_REASON_HANDLES = {
    nested = "h07852b32f9c54a09a559289344164f8ag002",
    unchanged = "h07852b32f9c54a09a559289344164f8ag003",
    save = "h07852b32f9c54a09a559289344164f8ag005",
    unavailable = "h07852b32f9c54a09a559289344164f8ag006",
    partial = "h07852b32f9c54a09a559289344164f8ag008",
}


--- Fade a border in and out once, unless the list rebuilds first.
---@param widget ExtuiStyledRenderable
---@param color vec4
---@param generation integer
function LeftPane:FlashBorder(widget, color, generation)
    -- Total length of one border blink
    local FLASH_DURATION_MS = 2000
    -- SE returns only explicit overrides; absent values need the sidebar's normal border style.
    local originalColor = widget:GetColor("Border")
    local originalSize = widget:GetStyle("FrameBorderSize")
    widget:SetStyle("FrameBorderSize", 1)
    local startTime = Ext.Timer.MonotonicTime()
    local function step()
        if self.listGeneration ~= generation then return end
        local progress = math.min((Ext.Timer.MonotonicTime() - startTime) / FLASH_DURATION_MS, 1)
        if progress < 1 then
            -- Ease in and out on each half
            local half = progress < 0.5 and progress * 2 or (1 - progress) * 2
            widget:SetColor("Border", { color[1], color[2], color[3], color[4] * Animation.EaseOutQuad(half) })
            Ext.Timer.WaitFor(0, step)
        else
            widget:SetColor("Border", originalColor or UIStyle.UnofficialColors["TooltipBorder"])
            widget:SetStyle("FrameBorderSize", originalSize or 0)
        end
    end
    step()
end

--- Explain a refused move and flash only the current generation of its target.
---@param widget ExtuiStyledRenderable
---@param generation integer
---@param reason ModListMoveFailure
function LeftPane:RefuseModListDrop(widget, generation, reason)
    NotificationManager:CreateIMGUINotification("MCM_ModListDrop", "warning",
        Ext.Loca.GetTranslatedString("h07852b32f9c54a09a559289344164f8ag007"),
        Ext.Loca.GetTranslatedString(DROP_REASON_HANDLES[reason]),
        { duration = 5, dontShowAgainButton = false }, ModuleUUID)
    self:FlashBorder(widget, UIStyle.TextStyles.Error, generation)
end

--- Find an entry from the drag payload in the current resolved list.
---@param data ModListDragPayload
---@return ResolvedModListEntry|nil entry
function LeftPane:FindDropEntry(data)
    local items
    if data.group == "Main" then
        items = self.resolved.main
    elseif data.group == "Hidden" then
        items = self.resolved.hidden
    else
        for _, folder in ipairs(self.resolved.main) do
            if folder.kind == "folder" and folder.id == data.group then
                items = folder.items
                break
            end
        end
    end
    for _, entry in ipairs(items or {}) do
        if entry.id == data.id and entry.kind == data.kind then
            return entry
        end
    end
end

--- Interpret header drops before asking the state owner to save the move.
---@param widget ExtuiStyledRenderable
---@param source ModListDragPayload
---@param generation integer
function LeftPane:ApplyModListDrop(widget, source, generation)
    -- Resolve payload IDs again: the navigation may have rebuilt since dragging started.
    local destinationData = widget.UserData
    local dragged = self:FindDropEntry(source)
    local target = self:FindDropEntry(destinationData)
    if not dragged or (destinationData.kind ~= "group" and not target) then
        return
    end
    local destination = destinationData.group
    -- A mod can enter a folder through its header; a section divider or folder drop reorders in the current group.
    local entersFolder = destinationData.kind == "folder" and dragged.kind == "mod" and not destinationData.section
    if destinationData.kind == "group" or entersFolder then
        destination = destinationData.id
        target = nil
    end
    if dragged.kind == "folder" and destination ~= "Main" then
        self:RefuseModListDrop(widget, generation, "nested")
        return
    end
    local _, reason = self.visibility:Move(dragged, source.group, destination, target, self.resolved)
    if reason then
        self:RefuseModListDrop(widget, generation, reason)
    end
    -- Rebuild only for saved layouts, including a partial save; the current settings page stays intact.
    if not reason or reason == "partial" then
        self:RebuildModEntries(self.mods)
        if self.listSettings then self.listSettings:Sync() end
    end
end

--- Create mod entries in the given order
---@private
---@param modUUIDs string[]
---@param container ExtuiTreeParent
---@param isHidden boolean Whether the entries go in Hidden mods
---@param createdUUIDs table<string, boolean> Receives the UUIDs whose entry was created
---@param groupId string
function LeftPane:createModEntries(modUUIDs, container, isHidden, createdUUIDs, groupId)
    for _, modUUID in ipairs(modUUIDs) do
        local success, err = xpcall(function()
            local blueprint = self.mods[modUUID].blueprint
            local modDescription = VCString:AddNewlinesAfterPeriods(blueprint:GetModDescription())
            local button = self:CreateMenuButton(blueprint:GetModName(), modDescription, modUUID, container)
            self.entryButtons[modUUID] = button
            self:ConfigureModListDrag(button, "mod", modUUID, groupId)
            button.OnRightClick = function()
                self:OpenModEntryMenu(modUUID, isHidden)
            end
        end, debug.traceback)
        if success then
            createdUUIDs[modUUID] = true
        else
            MCMWarn(0, "Error creating mod entry for %s: %s", modUUID, err)
        end
    end
end

--- Resolve navigation entries from blueprint defaults and saved player choices.
---@param mods table<string, ModSettings>
---@return ResolvedModList result
function LeftPane:ResolveModEntries(mods)
    local authorDefaults = {}
    for modUUID, modSettings in pairs(mods) do
        authorDefaults[modUUID] = {
            HiddenFromList = modSettings.blueprint and modSettings.blueprint:GetHiddenFromList(),
            ListFolder =
                modSettings.blueprint and modSettings.blueprint:GetListFolder()
        }
    end
    local entries = {}
    for _, id in ipairs(MCMUtils.SortModsByName(mods)) do
        table.insert(entries, { id = id, name = mods[id].blueprint:GetModName() })
    end
    return self.visibility:Resolve(entries, authorDefaults)
end

--- Rebuild navigation while preserving the active settings page and group expansion.
---@param mods table<string, ModSettings>
---@return table<string, boolean> createdUUIDs
function LeftPane:RebuildModEntries(mods)
    if not self.modEntriesGroup then
        self.modEntriesGroup = self.parent:AddGroup("MCM_ModEntries")
    end
    local result = self:ResolveModEntries(mods)
    self.listGeneration = (self.listGeneration or 0) + 1
    IMGUIHelpers.DestroyChildren(self.modEntriesGroup)
    self.hiddenModsHeader = nil
    self.mods = mods
    self.resolved = result
    local createdUUIDs = {}
    self.entryButtons = {}
    self.mainDropTargets = {}
    -- A rebuild can destroy a drag source before its drag end event arrives
    holdSidebar("drag", false)
    -- Drop targets otherwise use the near-black style color, which is invisible on the sidebar
    self.modEntriesGroup:SetColor("DragDropTarget", UIStyle.UnofficialColors["TooltipBorder"])
    self:RenderModListItems(self.modEntriesGroup, result.main, "Main", false, createdUUIDs)
    self:RenderHiddenGroup(result.hidden, createdUUIDs)
    self:CreateBlankSpaceMenuTarget()
    if self.activeUUID then
        self:SetActiveItem(self.activeUUID)
    end
    return createdUUIDs
end

--- Keep the draggable header childless; SE checks container drops after rendering children.
--- Folders open as saved; Hidden mods and this window's own changes come from the window's state.
---@param id string
---@return boolean
function LeftPane:isGroupExpanded(id)
    local current = self.expandedGroups[id]
    if current ~= nil or id == "Hidden" then
        return current == true
    end
    return self.visibility.preferences:IsFolderExpanded(id)
end

--- Apply a player's open or close at once, and save it for folders.
--- A refused save keeps what the player sees for this window and warns that it will not last.
---@param id string
---@param expanded boolean
function LeftPane:setGroupExpanded(id, expanded)
    self.expandedGroups[id] = expanded
    if id ~= "Hidden" and not self.visibility.preferences:SetFolderExpanded(id, expanded) then
        self:FinishModListChange(false)
    end
end

---@param id string
---@param label string
---@param items ResolvedModListEntry[]
---@param hidden boolean
---@param createdUUIDs table<string, boolean>
---@return ExtuiTree header
function LeftPane:RenderModListGroup(id, label, items, hidden, createdUUIDs)
    local header = self.modEntriesGroup:AddTree(label)
    header.CollapsingHeader = true
    local expanded = self:isGroupExpanded(id)
    if expanded then
        header:SetStyle("ItemSpacing", 8, 2)
    end
    local box = self.modEntriesGroup:AddTable("MCM_Group_" .. id, 1)
    box.BordersOuter = true
    box.RowBg = true
    box:SetColor("TableBorderStrong", UIStyle.UnofficialColors["GroupBoxBorder"])
    box:SetColor("TableRowBg", UIStyle.UnofficialColors["GroupBoxBg"])
    box:SetStyle("CellPadding", hidden and 2 or 4, 6)
    box.Visible = expanded
    header:SetOpen(expanded, "Always")
    header.OnExpand = function()
        self:setGroupExpanded(id, true)
        header:SetStyle("ItemSpacing", 8, 2)
        box.Visible = true
    end
    header.OnCollapse = function()
        self:setGroupExpanded(id, false)
        box.Visible = false
        -- Recreate the header to restore inherited spacing; SE cannot unset the override.
        self:RebuildModEntries(self.mods)
    end
    local cell = box:AddRow():AddCell()
    if not hidden and #items == 0 then
        self:CreateEmptyFolderDropTarget(cell, id)
    end
    self:RenderModListItems(cell, items, id, hidden, createdUUIDs)
    self:CreateMainDropTarget(id)
    if id == self.newFolderId then
        self.newFolderId = nil
        self:FlashBorder(header, UIStyle.UnofficialColors["TooltipBorder"], self.listGeneration)
    end
    return header
end

--- Give the entire empty-folder row a drop target
---@param cell ExtuiTreeParent
---@param folderId string
function LeftPane:CreateEmptyFolderDropTarget(cell, folderId)
    -- Selectable uses zero for available width; negative widths collapse its hit area.
    local target = cell:AddSelectable(Ext.Loca.GetTranslatedString("hb54d982efdb448d18ff18a5930b68857g892"), nil,
        { 0, 50 })
    target.IDContext = "MCM_EmptyFolder_" .. folderId
    target:SetColor("Text", UIStyle.TextStyles.SettingDescription)
    self:ConfigureModListDropTarget(target, "group", folderId, folderId)
end

--- Add the styled label above a group's pinned entries.
---@param container ExtuiTreeParent
---@return ExtuiSeparatorText pinnedHeader
local function addPinnedHeader(container)
    local pinnedHeader = container:AddSeparatorText(Ext.Loca.GetTranslatedString(
        "h3cccb7751f1e4b80955f55634c6a55fc524c"))
    pinnedHeader.PositionOffset = { 0, -1 }
    pinnedHeader:SetColor("Separator", UIStyle.UnofficialColors.PinnedHeaderSeparator)
    pinnedHeader:SetStyle("SeparatorTextBorderSize", 1)
    pinnedHeader:SetStyle("SeparatorTextPadding", UIStyle.Styles.SeparatorTextPadding[1], 0)
    pinnedHeader:SetStyle("ItemSpacing", 8, 3)
    return pinnedHeader
end

--- Separate pinned entries only when unpinned entries follow in this group.
---@param container ExtuiTreeParent
---@param items ResolvedModListEntry[]
---@param groupId string
---@param hidden boolean
---@param createdUUIDs table<string, boolean>
function LeftPane:RenderModListItems(container, items, groupId, hidden, createdUUIDs)
    for i, item in ipairs(items) do
        if item.pinned and i == 1 then
            self:ConfigureModListDropTarget(addPinnedHeader(container), item.kind, item.id, groupId, true)
        end
        if item.kind == "folder" then
            local header = self:RenderModListGroup(item.id, item.name:gsub("#", "") .. "##folder_" .. item.id,
                item.items, false, createdUUIDs)
            self:ConfigureModListDrag(header, "folder", item.id, groupId)
            header.OnRightClick = function() self:OpenFolderMenu(item) end
        else
            self:createModEntries({ item.id }, container, hidden, createdUUIDs, groupId)
        end
        if item.pinned and items[i + 1] and not items[i + 1].pinned then
            local separator = container:AddSeparator()
            local nextItem = items[i + 1]
            self:ConfigureModListDropTarget(separator, nextItem.kind, nextItem.id, groupId, true)
        end
    end
end

--- Append a hidden destination after each folder or Hidden group, revealed only for its own drag.
---@param sourceGroup string
function LeftPane:CreateMainDropTarget(sourceGroup)
    local target = self.modEntriesGroup:AddButton(Ext.Loca.GetTranslatedString("hb06aed8109a44f689d9351a1c469d09ae769"))
    target.IDContext = "MCM_MainDrop_" .. sourceGroup
    target.Size = { -2, 50 }
    target.Visible = false
    target:SetColor("Button", UIStyle.Colors["FrameBg"])
    target:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
    target:SetStyle("FrameBorderSize", 1)
    self:ConfigureModListDropTarget(target, "group", "Main", "Main")
    self.mainDropTargets[sourceGroup] = target
end

--- Hidden mods always follow all ordinary groups.
---@param items ResolvedModListEntry[]
---@param createdUUIDs table<string, boolean>
function LeftPane:RenderHiddenGroup(items, createdUUIDs)
    if #items > 0 then
        self.modEntriesGroup:AddSeparator()
        self.hiddenModsHeader = self:RenderModListGroup("Hidden", VCString:InterpolateLocalizedMessage(
            "h31b35bbef8544e26b213f5a93c926ecc7865", #items), items, true, createdUUIDs)
        self:ConfigureModListDrag(self.hiddenModsHeader, "group", "Hidden", "Hidden")
    else
        self.expandedGroups.Hidden = false
    end
end

--- A childless item receives its own right click; containers see their last child instead.
function LeftPane:CreateBlankSpaceMenuTarget()
    local blank = self.modEntriesGroup:AddButton("##MCM_SidebarBlank")
    blank.Size = { -1, -1 }
    blank:SetColor("Button", { 0, 0, 0, 0 })
    blank:SetColor("ButtonHovered", { 0, 0, 0, 0 })
    blank:SetColor("ButtonActive", { 0, 0, 0, 0 })
    blank.OnRightClick = function()
        self:OpenFolderMenu(
            { kind = "folder", id = "Main", name = Ext.Loca.GetTranslatedString("hb06aed8109a44f689d9351a1c469d09ae769") })
    end
end

--- Highlight the entry if its IDContext ends with the UUID; otherwise restore its normal look
---@param entry ExtuiStyledRenderable A menu entry, a mod entry, or a Hidden mods entry
---@param uuid string
---@return nil
local function applyActiveState(entry, uuid)
    if not entry.UserData then
        entry.UserData = {}
    end
    if entry.IDContext and entry.IDContext:sub(- #uuid) == uuid then
        if not entry.UserData.originalText then
            entry.UserData.originalText = entry.Label
        end
        entry.Label = "> " .. entry.UserData.originalText
        entry:SetColor("Button", UIStyle.Colors["ButtonActive"])
    else
        if entry.UserData.originalText then
            entry.Label = entry.UserData.originalText
        end
        entry:SetColor("Button", UIStyle.Colors["Button"])
    end
end

---@param uuid string
function LeftPane:SetActiveItem(uuid)
    self.activeUUID = uuid
    for _, child in ipairs(self.parent.Children or {}) do
        if child ~= self.modEntriesGroup and child ~= self.modEntryMenu then
            applyActiveState(child, uuid)
        end
    end
    for _, button in pairs(self.entryButtons or {}) do
        applyActiveState(button, uuid)
    end
end
