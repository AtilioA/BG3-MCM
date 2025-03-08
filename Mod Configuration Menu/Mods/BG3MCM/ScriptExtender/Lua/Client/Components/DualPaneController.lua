--------------------------------------------
-- DualPaneController:
-- This module manages a dual-pane interface within the MCM window.
-- It provides functionalities to initialize and layout a two-column pane structure with collapsible and expandable behavior,
-- allowing for dynamic adjustments based on user interactions.
-- It supports adding mod-specific content and menu sections, facilitating a structured presentation of mod configurations.
--------------------------------------------
DualPaneController = {}
DualPaneController.__index = DualPaneController

-- Constants for dual-pane expand/collapse
local ICON_TOGGLE_COLLAPSE = "panner_left_d"
local ICON_TOGGLE_EXPAND = "ico_menu_h"
local STEP_DELAY = 1 / 60
local TARGET_WIDTH_EXPANDED = 500
local TARGET_WIDTH_COLLAPSED = 10
local STEP_FACTOR = 0.1

-- Initialize DualPaneController using an existing window.
function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self.contentGroups = {} -- groups for each mod's content
    self:initLayout()
    self.isCollapsed = false
    return self
end

-- Build the dual-pane layout (menu pane and content pane)
function DualPaneController:initLayout()
    self.mainLayoutTable = self.window:AddTable("MainLayout", 2)
    local function GetMenuColumnWidth()
        return Ext.IMGUI.GetViewportSize()[2] / 4.8
    end
    local function GetContentColumnWidth()
        return Ext.IMGUI.GetViewportSize()[1]
    end
    self.mainLayoutTable:AddColumn("Menu", "WidthFixed", GetMenuColumnWidth())
    self.mainLayoutTable:AddColumn("Content", "WidthFixed", GetContentColumnWidth())
    local row                        = self.mainLayoutTable:AddRow()
    self.menuCell                    = row:AddCell()
    self.contentCell                 = row:AddCell()

    -- Add dual pane buttons to the content cell (these can later trigger collapse/expand)
    self.dualpaneCollapseBtn         = self:createImageButton(self.contentCell, "Toggle", ICON_TOGGLE_COLLAPSE,
        "Hide the sidebar")
    self.dualpaneExpandBtn           = self:createImageButton(self.contentCell, "Toggle", ICON_TOGGLE_EXPAND,
        "Expand the sidebar containing keybindings, mods, etc")
    self.dualpaneCollapseBtn.Visible = true
    self.dualpaneExpandBtn.Visible   = false

    self.dualpaneCollapseBtn.OnClick = function() self:Toggle() end
    self.dualpaneExpandBtn.OnClick   = function() self:Toggle() end

    -- Create scroll windows for menu and content areas
    self.menuScrollWindow            = self.menuCell:AddChildWindow("MenuScrollWindow")
    -- self.menuScrollWindow.ResizeX = true
    -- self.menuScrollWindow.AlwaysUseWindowPadding = true
    -- self.menuScrollWindow.ChildAlwaysAutoResize = true
    self.contentScrollWindow         = self.contentCell:AddChildWindow("ContentScrollWindow")
end

function DualPaneController:createImageButton(parent, text, icon, tooltip)
    local button = parent:AddImageButton(text, icon, IMGUIWidget:GetIconSizes(1.25))
    MCMRendering:AddTooltip(button, tooltip, "DualPaneButton_" .. text)
    return button
end

-- API: Add a menu section header in the menu pane.
function DualPaneController:AddMenuSection(text)
    self.menuScrollWindow:AddSeparatorText(text)
end

-- API: Create a menu button (with tooltip) in the menu pane.
function DualPaneController:CreateMenuButton(text, uuid)
    local button = self.menuScrollWindow:AddButton(text)
    button.IDContext = "MenuButton_" .. text .. "_" .. uuid
    button.OnClick = function()
        self:setVisibleFrame(uuid)
        for _, c in ipairs(self.menuScrollWindow.Children) do
            if c == button then
                c:SetColor("Button", UIStyle.Colors["ButtonActive"])
            else
                c:SetColor("Button", UIStyle.Colors["Button"])
            end
        end
        if not MCMProxy.IsMainMenu() then
            ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ACTIVATED, { modUUID = uuid })
        end
        -- TODO: Optionally collapse the menu pane after a selection.
        self:Collapse()
    end
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    return button
end

-- API: Create a mod entry in the menu and return its tab bar for content.
function DualPaneController:addButtonAndGetModTabBar(modName, modDescription, modUUID)
    if not modName or not modUUID then
        MCMWarn(0, "addButtonAndGetModTabBar called with invalid parameters")
        return
    end

    modName = VCString:Wrap(modName, 33)
    local menuButton = self:CreateMenuButton(modName, modUUID)
    if modDescription then
        MCMRendering:AddTooltip(menuButton, modDescription, modUUID)
    end

    local uiGroupMod = self.contentScrollWindow:AddGroup(modUUID)
    uiGroupMod:AddSeparatorText(modName)
    if modDescription then
        local modDescriptionText = VCString:AddFullStop(modDescription)
        local descriptionTextObject = uiGroupMod:AddText(modDescriptionText)
        descriptionTextObject.TextWrapPos = 0
        uiGroupMod:AddDummy(0, 5)
    end

    self.contentGroups[modUUID] = uiGroupMod
    local modTabs = uiGroupMod:AddTabBar(modUUID .. "_TABS")
    modTabs.IDContext = modUUID .. "_TABS"
    return modTabs
end

-- API: Return the content group for a given mod UUID.
function DualPaneController:GetGroup(modUUID)
    return self.contentGroups[modUUID]
end

-- API: Return the tab bar for a given mod UUID.
function DualPaneController:GetModTabBar(modUUID)
    if not self.contentGroups or not self.contentGroups[modUUID] then return nil end
    if table.isEmpty(self.contentGroups[modUUID].Children) then return nil end
    for _, child in ipairs(self.contentGroups[modUUID].Children) do
        if child.IDContext and child.IDContext:sub(-5) == "_TABS" then
            return child
        end
    end
    return nil
end

-- API: Set which mod's content is visible.
function DualPaneController:setVisibleFrame(uuidToShow)
    for uuid, group in pairs(self.contentGroups) do
        if group then
            group.Visible = (uuidToShow == uuid)
        end
    end
end

--------------------------------------------
-- Expand/Collapse Functionality
--------------------------------------------
function DualPaneController:Expand()
    if self.dualpaneExpandBtn then self.dualpaneExpandBtn.Visible = false end
    if self.dualpaneCollapseBtn then self.dualpaneCollapseBtn.Visible = true end

    self.menuScrollWindow:SetStyle("Alpha", 0)
    self.menuScrollWindow.Visible = true

    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width

    local function stepExpand()
        if cWidth < TARGET_WIDTH_EXPANDED then
            cWidth = math.min(TARGET_WIDTH_EXPANDED, cWidth + (TARGET_WIDTH_EXPANDED * STEP_FACTOR))
            self.mainLayoutTable.ColumnDefs[1].Width = cWidth
            local newAlpha = math.min(1, (self.menuScrollWindow:GetStyle("Alpha") or 0) + STEP_FACTOR)
            self.menuScrollWindow:SetStyle("Alpha", newAlpha)
            Ext.Timer.WaitFor(STEP_DELAY, stepExpand)
        else
            self.isCollapsed = false
        end
    end
    stepExpand()
end

function DualPaneController:Collapse()
    if self.isCollapsed then return end

    if self.dualpaneExpandBtn then self.dualpaneExpandBtn.Visible = true end
    if self.dualpaneCollapseBtn then self.dualpaneCollapseBtn.Visible = false end

    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width

    local function stepCollapse()
        if cWidth > TARGET_WIDTH_COLLAPSED then
            cWidth = math.max(TARGET_WIDTH_COLLAPSED, cWidth - (cWidth * STEP_FACTOR))
            self.mainLayoutTable.ColumnDefs[1].Width = cWidth
            self.menuScrollWindow:SetStyle("Alpha",
                math.max(0, (self.menuScrollWindow:GetStyle("Alpha") or 1) - STEP_DELAY))
            Ext.Timer.WaitFor(STEP_DELAY, stepCollapse)
        else
            self.menuScrollWindow.Visible = false
            self.isCollapsed = true
        end
    end
    stepCollapse()
end

function DualPaneController:Toggle()
    if self.isCollapsed then
        self:Expand()
    else
        self:Collapse()
    end
end

function DualPaneController:CreateModTab(modUUID, tabName)
    if not MCM_WINDOW then return nil end

    local modTabBar = self:GetModTabBar(modUUID)
    if not modTabBar then
        local modData = Ext.Mod.GetMod(modUUID)
        MCMWarn(1, "Tab creation called before any modTabBar created: " ..
            modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return nil
    end

    local newTab = modTabBar:AddTabItem(tabName)
    newTab.IDContext = modUUID .. "_" .. tabName
    newTab.UserData = newTab.UserData or {}
    newTab.OnActivate = function()
        MCMDebug(3, "Activating tab " .. tabName)
        ModEventManager:Emit(EventChannels.MCM_MOD_SUBTAB_ACTIVATED, {
            modUUID = modUUID,
            tabName = tabName
        })
    end
    return newTab
end

function DualPaneController:CreateTabWithDisclaimer(modUUID, tabName, disclaimerLocaKey)
    local newTab = self:CreateModTab(modUUID, tabName)
    if not newTab then return nil end
    local tempTextDisclaimer = Ext.Loca.GetTranslatedString(disclaimerLocaKey)
    local addTempText = newTab:AddText(tempTextDisclaimer)
    addTempText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    addTempText.TextWrapPos = 0
    return newTab
end

-- Insert a tab with a callback
function DualPaneController:InsertModTab(modUUID, tabName, tabCallback)
    local newTab = self:CreateModTab(modUUID, tabName)
    if not newTab then return nil end

    -- Apply the callback if provided
    if tabCallback and not newTab.UserData["Callback"] then
        newTab.UserData.Callback = tabCallback
        tabCallback(newTab)
        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ADDED, {
            modUUID = modUUID,
            tabName = tabName,
        })
    end
    return newTab
end

--[[
    -- Documentation button
    local docButton = cellGroup:AddImageButton("Documentation", ICON_DOC, { 40, 40 })
    docButton.SameLine = true
    docButton.OnClick = function()
        local docWindow = Ext.IMGUI.NewWindow("docWindow")
        docWindow.AlwaysAutoResize = true
        docWindow.Closeable = true
        docWindow:AddText(DOC_TEXT)
    end

    -- Detach mod button
    local detachMod = cellGroup:AddButton("Detach mod")
    detachMod.SameLine = true
--]]
