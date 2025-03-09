--------------------------------------------
-- DualPaneController (Facade):
-- This module manages a dual-pane interface within the MCM window.
-- It wires together the ModMenu and ModContent components.
-- It provides functionalities to initialize and layout a two-column pane structure with collapsible and expandable behavior,
-- allowing for dynamic adjustments based on user interactions.
-- It supports adding mod-specific content and menu sections, facilitating a structured presentation of mod configurations.
--------------------------------------------

DualPaneController = {}
DualPaneController.__index = DualPaneController

-- Constants
ICON_TOGGLE_COLLAPSE = "panner_left_d"
ICON_TOGGLE_EXPAND = "ico_menu_h"
ICON_DOCS = "ico_secret_h"
ICON_DETACH = "ico_popup_d"
STEP_DELAY = 1 / 60
TARGET_WIDTH_EXPANDED = 500
TARGET_WIDTH_COLLAPSED = 5
STEP_FACTOR = 0.1
AUTO_COLLAPSE_ON_MOD_CLICK = true

-- Options from blueprint settings (defaults)
DISABLE_HOVER = false
DISABLE_AUTO_COLLAPSE = false
HOVER_DELAY = 3000

local RX = {
    TimerScheduler = Ext.Require("Lib/reactivex/schedulers/timerscheduler.lua")
}

function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self:initLayout()
    self.modMenu = ModMenu:New(self.menuScrollWindow)
    self.modContent = ModContent:New(self.contentScrollWindow)
    self.isCollapsed = false
    self.isHovered = false
    self.hoverSubscription = nil
    -- Attach hover listeners initially (menu is expanded by default)
    self:AttachHoverListeners()
    return self
end

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
    local row = self.mainLayoutTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()
    self.menuScrollWindow = self.menuCell:AddChildWindow("MenuScrollWindow")
    self.contentScrollWindow = self.contentCell:AddChildWindow("ContentScrollWindow")
end

-- Attach hover listeners to either the menuScrollWindow (if visible) or the expand button (if collapsed)
function DualPaneController:AttachHoverListeners()
    if DISABLE_HOVER then
        return
    end
    if self.menuScrollWindow.Visible then
        self.menuScrollWindow.OnHoverEnter = function()
            self.isHovered = true
            self:CancelAutoCollapse()
        end
        self.menuScrollWindow.OnHoverLeave = function()
            self.isHovered = false
            self:ScheduleAutoCollapse()
        end
    else
        -- When collapsed, attach hover to the expand button
        if self.modContent and self.modContent.headerActions and self.modContent.headerActions.expandBtn then
            self.modContent.headerActions.expandBtn.OnHoverEnter = function()
                self.isHovered = true
                self:CancelAutoCollapse()
                self:Expand()
            end
        end
    end
end

-- TODO: cancel any pending auto-collapse timer?
function DualPaneController:CancelAutoCollapse()
    self.hoverSubscription = nil
end

-- Schedule auto-collapse after a few seconds if not hovered
function DualPaneController:ScheduleAutoCollapse()
    if DISABLE_AUTO_COLLAPSE then
        return
    end
    self:CancelAutoCollapse()
    local scheduler = RX.TimerScheduler.Create()
    self.hoverSubscription = scheduler:Schedule(function()
        if not self.isHovered then
            self:Collapse()
        end
    end, HOVER_DELAY)
end

-- Internal method to update header toggle icons
---@param ignoreCollapsed? boolean Optional parameter to ignore the collapse state
function DualPaneController:UpdateToggleButtons(ignoreCollapsed)
    if not ignoreCollapsed then
        if self.isCollapsed then
            self.modContent.headerActions.expandBtn.Visible = true
            self.modContent.headerActions.collapseBtn.Visible = false
        else
            self.modContent.headerActions.expandBtn.Visible = false
            self.modContent.headerActions.collapseBtn.Visible = true
        end
    else
        self.modContent.headerActions.expandBtn.Visible = not self.modContent.headerActions.expandBtn.Visible
        self.modContent.headerActions.collapseBtn.Visible = not self.modContent.headerActions.collapseBtn.Visible
    end
end

-- Expand the sidebar (menu pane) 'asynchronously'
function DualPaneController:Expand()
    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width
    local selfRef = self
    selfRef:UpdateToggleButtons(true)
    local function stepExpand()
        if cWidth < TARGET_WIDTH_EXPANDED then
            cWidth = math.min(TARGET_WIDTH_EXPANDED, cWidth + (TARGET_WIDTH_EXPANDED * STEP_FACTOR))
            selfRef.mainLayoutTable.ColumnDefs[1].Width = cWidth
            local newAlpha = math.min(1, (selfRef.menuScrollWindow:GetStyle("Alpha") or 0) + STEP_FACTOR)
            selfRef.menuScrollWindow:SetStyle("Alpha", newAlpha)
            Ext.Timer.WaitFor(STEP_DELAY, stepExpand)
        else
            selfRef.isCollapsed = false
            selfRef.menuScrollWindow.Visible = true
            selfRef:UpdateToggleButtons()
            selfRef:AttachHoverListeners()
        end
    end
    stepExpand()
end

-- Collapse the sidebar 'asynchronously'
function DualPaneController:Collapse()
    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width
    local selfRef = self
    selfRef:UpdateToggleButtons(true)
    local function stepCollapse()
        if cWidth > TARGET_WIDTH_COLLAPSED then
            cWidth = math.max(TARGET_WIDTH_COLLAPSED, cWidth - (cWidth * STEP_FACTOR))
            selfRef.mainLayoutTable.ColumnDefs[1].Width = cWidth
            selfRef.menuScrollWindow:SetStyle("Alpha",
                math.max(0, (selfRef.menuScrollWindow:GetStyle("Alpha") or 1) - STEP_DELAY))
            Ext.Timer.WaitFor(STEP_DELAY, stepCollapse)
        else
            selfRef.menuScrollWindow.Visible = false
            selfRef.isCollapsed = true
            selfRef:UpdateToggleButtons()
            selfRef:AttachHoverListeners()
        end
    end
    stepCollapse()
end

-- Toggle the sidebar
function DualPaneController:ToggleSidebar()
    if self.isCollapsed then
        self:Expand()
    else
        self:Collapse()
    end
end

-- Tab management API; delegates to ModContent.
function DualPaneController:CreateModTab(modUUID, tabName)
    return self.modContent:CreateTab(modUUID, tabName)
end

function DualPaneController:CreateTabWithDisclaimer(modUUID, tabName, disclaimerLocaKey)
    local tab = self:CreateModTab(modUUID, tabName)
    if tab then
        local disclaimerText = Ext.Loca.GetTranslatedString(disclaimerLocaKey)
        local disclaimerElement = tab:AddText(disclaimerText)
        disclaimerElement:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
        disclaimerElement.TextWrapPos = 0
    end
    return tab
end

function DualPaneController:InsertModTab(modUUID, tabName, callback)
    return self.modContent:InsertTab(modUUID, tabName, callback)
end

function DualPaneController:SetVisibleFrame(modUUID)
    self.modContent:SetVisibleGroup(modUUID)
end

-- Helper called from ModMenu buttons.
function DualPaneController:SwitchVisibleContent(button, uuid)
    self:SetVisibleFrame(uuid)
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
end

-- Open a specific page and optionally a subtab.
-- If tabName is provided, it activates that tab (by setting its SetSelected property to true).
---@param modUUID string The UUID of the mod to open
---@param tabName? string The name of the tab to open
function DualPaneController:OpenModPage(modUUID, tabName)
    IMGUIAPI:OpenMCMWindow(true)

    self:SetVisibleFrame(modUUID)

    local modTabBar = self.modContent:GetModTabBar(modUUID)
    if not modTabBar then
        MCMError(0, "No page found for mod " .. modUUID)
        return
    end

    local tabFound = false
    for _, tab in ipairs(modTabBar.Children) do
        if tab.IDContext and tab.IDContext:find(tabName) then
            tab.SetSelected = true
            tabFound = true
        else
            tab.SetSelected = false
        end
    end

    if not tabFound then
        MCMWarn(0,
            "Tab provided " ..
            tabName ..
            " was not found for mod " ..
            modUUID ". Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
    end

    -- Collapse the sidebar when opening the specific page.
    self:Collapse()
end
