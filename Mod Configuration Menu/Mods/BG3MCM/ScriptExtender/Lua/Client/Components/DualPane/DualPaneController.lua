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

function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self:initLayout()
    self.modMenu = ModMenu:New(self.menuScrollWindow)
    self.modContent = ModContent:New(self.contentScrollWindow)
    self.isCollapsed = false
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

-- Expand/Collapse logic for the left (menu) pane.
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
        end
    end
    stepExpand()
end

-- 'Asynchronously' collapse the sidebar (menu pane)
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
        end
    end
    stepCollapse()
end

-- Toggle the sidebar and update header icons.
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
