------------------------------------------------------------
-- LeftPane Component
-- Manages the left pane (menu) of the dual-pane layout.
------------------------------------------------------------
---@class LeftPane
---@field parent ExtuiStyledRenderable
---@field modEntriesGroup ExtuiGroup|nil Holds only mod entries, so they can be rebuilt without touching other entries
---@field activeUUID string|nil UUID of the highlighted entry
LeftPane = _Class:Create("LeftPane", nil, {
    parent = nil,
    modEntriesGroup = nil,
    activeUUID = nil,
})
LeftPane.__index = LeftPane

function LeftPane:New(parent)
    local self = setmetatable({}, LeftPane)
    self.parent = parent -- Should:tm: be the menuScrollChildWindow
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

--- Destroy and recreate the mod entries in name order; other entries and the right pane are not touched
---@param mods table<string, ModSettings>
---@return table<string, boolean> createdUUIDs Mod UUIDs whose entry was created
function LeftPane:RebuildModEntries(mods)
    if not self.modEntriesGroup then
        self.modEntriesGroup = self.parent:AddGroup("MCM_ModEntries")
    end
    local oldEntries = {}
    for _, child in ipairs(self.modEntriesGroup.Children or {}) do
        table.insert(oldEntries, child)
    end
    for _, child in ipairs(oldEntries) do
        child:Destroy()
    end

    local createdUUIDs = {}
    for _, modUUID in ipairs(MCMUtils.SortModsByName(mods)) do
        local success, err = xpcall(function()
            local blueprint = mods[modUUID].blueprint
            local modDescription = VCString:AddNewlinesAfterPeriods(blueprint:GetModDescription())
            self:CreateMenuButton(blueprint:GetModName(), modDescription, modUUID, self.modEntriesGroup)
        end, debug.traceback)
        if success then
            createdUUIDs[modUUID] = true
        else
            MCMWarn(0, "Error creating mod entry for %s: %s", modUUID, err)
        end
    end

    if self.activeUUID then
        self:SetActiveItem(self.activeUUID)
    end
    return createdUUIDs
end

--- Highlight the entry if its IDContext ends with the UUID; otherwise restore its normal look
---@param entry ExtuiStyledRenderable A child of the menu or of the mod entries group
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
        if child ~= self.modEntriesGroup then
            applyActiveState(child, uuid)
        end
    end
    if self.modEntriesGroup then
        for _, child in ipairs(self.modEntriesGroup.Children or {}) do
            applyActiveState(child, uuid)
        end
    end
end
