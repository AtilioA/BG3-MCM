------------------------------------------------------------
-- LeftPane Component
-- Manages the left pane (menu) of the dual-pane layout.
------------------------------------------------------------
---@class LeftPane
---@field parent ExtuiStyledRenderable
---@field modEntriesGroup ExtuiGroup|nil Holds only mod entries, so they can be rebuilt without touching other entries
---@field hiddenModsGroup ExtuiGroup|nil Separator and Hidden mods header inside modEntriesGroup; nil when no present mod is hidden
---@field hiddenModsHeader ExtuiTree|nil Hidden mods header inside hiddenModsGroup
---@field hiddenModsExpanded boolean Hidden mods expanded state, kept across navigation rebuilds and not saved
---@field modEntryMenu ExtuiPopup|nil Right-click menu shared by all mod entries
---@field mods table<string, ModSettings>|nil Mods from the last RebuildModEntries call
---@field visibility ModListVisibility
---@field activeUUID string|nil UUID of the highlighted entry
LeftPane = _Class:Create("LeftPane", nil, {
    parent = nil,
    modEntriesGroup = nil,
    hiddenModsGroup = nil,
    hiddenModsHeader = nil,
    hiddenModsExpanded = false,
    modEntryMenu = nil,
    mods = nil,
    visibility = nil,
    activeUUID = nil,
})
LeftPane.__index = LeftPane

function LeftPane:New(parent)
    local self = setmetatable({}, LeftPane)
    self.parent = parent -- Should:tm: be the menuScrollChildWindow
    self.visibility = ModListVisibility:New(MCM.Store)
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
    button.OnClick = function()
        -- Auto-reattach if mod is currently detached
        if DualPane and DualPane.rightPane and DualPane.rightPane.detachedWindows and DualPane.rightPane.detachedWindows[uuid] then
            DualPane.rightPane:ReattachModGroup(uuid)
        end
        DualPane:SwitchVisibleContent(button, uuid)
        if MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID) then
            DualPane:ToggleSidebar()
        end
    end
    if description and description ~= "" then
        IMGUIHelpers.AddTooltip(button, description, "MenuButton_" .. text .. "_" .. uuid .. "_TOOLTIP")
    end
    return button
end

---@param container ExtuiTreeParent
local function destroyChildren(container)
    local oldChildren = {}
    for _, child in ipairs(container.Children or {}) do
        table.insert(oldChildren, child)
    end
    for _, child in ipairs(oldChildren) do
        child:Destroy()
    end
end

--- Show the right-click menu for one mod entry; opening it does not select the mod
---@param modUUID string
---@param isHidden boolean Whether the entry is in Hidden mods
function LeftPane:OpenModEntryMenu(modUUID, isHidden)
    if not self.modEntryMenu then
        -- Same frame as MCM tooltips, so both popovers read as one family
        self.modEntryMenu = self.parent:AddPopup("MCM_ModEntryMenu")
        self.modEntryMenu:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
        self.modEntryMenu:SetStyle("PopupBorderSize", 2)
        self.modEntryMenu:SetStyle("WindowPadding", 12, 10)
        self.modEntryMenu:SetStyle("ItemSpacing", 8, 6)
        self.modEntryMenu:SetSizeConstraints({ 200, 0 })
    end
    destroyChildren(self.modEntryMenu)

    -- Right-clicking does not select the entry, so name the mod the action applies to
    local modNameText = self.modEntryMenu:AddText(self.mods[modUUID].blueprint:GetModName())
    modNameText:SetColor("Text", UIStyle.TextStyles["SettingDescription"])
    self.modEntryMenu:AddSeparator()

    local handle = isHidden and "h541de1bd8d8d4be8a188742c9011da27b110" or "h31655a10d04449dfb90946ebe22da383f8a2"
    local item = self.modEntryMenu:AddSelectable(Ext.Loca.GetTranslatedString(handle), nil, { 0, 28 })
    item:SetStyle("SelectableTextAlign", 0, 0.5)
    item.OnClick = function()
        self:SetModHidden(modUUID, not isHidden)
    end
    self.modEntryMenu:Open()
end

--- Save a Hide or Show choice and rebuild only the mod-list navigation; the open page stays open
---@param modUUID string
---@param hidden boolean
function LeftPane:SetModHidden(modUUID, hidden)
    self.visibility:SetHidden(modUUID, hidden)
    self:RebuildModEntries(self.mods)
end

--- Create mod entries in the given order
---@private
---@param modUUIDs string[]
---@param container ExtuiTreeParent
---@param isHidden boolean Whether the entries go in Hidden mods
---@param createdUUIDs table<string, boolean> Receives the UUIDs whose entry was created
function LeftPane:createModEntries(modUUIDs, container, isHidden, createdUUIDs)
    for _, modUUID in ipairs(modUUIDs) do
        local success, err = xpcall(function()
            local blueprint = self.mods[modUUID].blueprint
            local modDescription = VCString:AddNewlinesAfterPeriods(blueprint:GetModDescription())
            local button = self:CreateMenuButton(blueprint:GetModName(), modDescription, modUUID, container)
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

--- Destroy and recreate the mod entries in name order, with hidden entries in a Hidden mods group that keeps its expanded state; other entries and the right pane are not touched
---@param mods table<string, ModSettings>
---@return table<string, boolean> createdUUIDs Mod UUIDs whose entry was created
function LeftPane:RebuildModEntries(mods)
    if not self.modEntriesGroup then
        self.modEntriesGroup = self.parent:AddGroup("MCM_ModEntries")
    end
    destroyChildren(self.modEntriesGroup)
    self.hiddenModsGroup = nil
    self.hiddenModsHeader = nil
    self.mods = mods

    local main, hidden, hiddenCount = self.visibility:Resolve(MCMUtils.SortModsByName(mods))
    local createdUUIDs = {}
    self:createModEntries(main, self.modEntriesGroup, false, createdUUIDs)
    if hiddenCount > 0 then
        -- The rule separates Hidden mods from the main list without repeating the header label
        self.hiddenModsGroup = self.modEntriesGroup:AddGroup("MCM_HiddenMods")
        self.hiddenModsGroup:AddSeparator()
        -- A tree in collapsing-header mode reports expand and collapse, so a rebuild can restore its state; AddCollapsingHeader cannot
        local header = self.hiddenModsGroup:AddTree(
            VCString:InterpolateLocalizedMessage("h31b35bbef8544e26b213f5a93c926ecc7865", hiddenCount))
        header.CollapsingHeader = true
        header:SetOpen(self.hiddenModsExpanded, "Always")
        header.OnExpand = function() self.hiddenModsExpanded = true end
        header.OnCollapse = function() self.hiddenModsExpanded = false end
        self.hiddenModsHeader = header
        self:createModEntries(hidden, header, true, createdUUIDs)
    else
        -- When the group comes back, it starts collapsed, so hiding the open mod never expands it
        self.hiddenModsExpanded = false
    end

    if self.activeUUID then
        self:SetActiveItem(self.activeUUID)
    end
    return createdUUIDs
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
    if self.modEntriesGroup then
        for _, child in ipairs(self.modEntriesGroup.Children or {}) do
            if child ~= self.hiddenModsGroup then
                applyActiveState(child, uuid)
            end
        end
    end
    if self.hiddenModsHeader then
        for _, child in ipairs(self.hiddenModsHeader.Children or {}) do
            applyActiveState(child, uuid)
        end
    end
end
