--------------------------------------------
-- DualPaneController (Facade)
-- Manages the dual-pane interface and wires together the left
-- and right panes.
-- It supports adding mod-specific content and menu sections, facilitating a structured presentation of mod configurations.
--------------------------------------------

---@class DualPaneController
---@field window any
---@field leftPane LeftPane
---@field rightPane RightPane
---@field isCollapsed boolean
---@field isHovered boolean
---@field userHasInteracted boolean
---@field hoverSubscription any
DualPaneController = _Class:Create("DualPaneController", nil, {
    window = nil,
    leftPane = nil,
    rightPane = nil,
    isCollapsed = false,
    isHovered = false,
    userHasInteracted = false,
    menuScrollWindow = nil,
    contentScrollWindow = nil,
    mainLayoutTable = nil,
    menuCell = nil,
    contentCell = nil,
})
DualPaneController.__index = DualPaneController

-- Constants
ICON_TOGGLE_COLLAPSE = "panner_left_d"
ICON_TOGGLE_EXPAND = "ico_menu_h"
ICON_DOCS = "ico_secret_h"
ICON_DETACH = "ico_popup_d"

TARGET_WIDTH_EXPANDED = 450
TARGET_WIDTH_COLLAPSED = 5
STEP_DELAY = 1 / 60
STEP_FACTOR = 0.1
HOVER_DELAY_MS = 5000

HeaderActionsInstance = nil

local RX = {
    TimerScheduler = Ext.Require("Lib/reactivex/schedulers/timerscheduler.lua")
}

function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self:initLayout()
    self.leftPane = LeftPane:New(self.menuScrollWindow)
    self.rightPane = RightPane:New(self.contentScrollWindow)
    self.isCollapsed = false
    self.isHovered = false
    self.userHasInteracted = false
    self.hoverSubscription = nil
    -- Attach hover listeners initially (menu is expanded by default)
    self:AttachHoverListeners()
    return self
end

function DualPaneController:initLayout()
    local function GetMenuColumnWidth()
        return Ext.IMGUI.GetViewportSize()[2] / 4.8
    end
    local function GetContentColumnWidth()
        return Ext.IMGUI.GetViewportSize()[1]
    end

    self.mainLayoutTable = self.window:AddTable("MainLayout", 2)
    self.mainLayoutTable:AddColumn("Menu", "WidthFixed", GetMenuColumnWidth())
    self.mainLayoutTable:AddColumn("Content", "WidthStretch")
    local row = self.mainLayoutTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()

    self.menuScrollWindow = self.menuCell:AddChildWindow("MenuScrollWindow")
    self.menuScrollWindow.AutoResizeY = true
    self.menuScrollWindow.ChildAlwaysAutoResize = true

    -- Create header actions before creating the content scroll window.
    -- HeaderActionsInstance is used by RightPane later.
    HeaderActionsInstance = HeaderActions:New(self.contentCell)

    self.contentScrollWindow = self.contentCell:AddChildWindow("ContentScrollWindow")
    self.contentScrollWindow.AutoResizeY = true
    self.contentScrollWindow.ChildAlwaysAutoResize = true
end

local function normalizeString(str)
    return string.lower(str:gsub(" ", "_"))
end

local function isMatchingTab(modUUID, identifier, tab)
    local storedId = tab.UserData and tab.UserData.tabId or ""
    local normalizedIdentifier = normalizeString(identifier)
    local normalizedTabIdSuffix = storedId:sub(#modUUID + 2)
    local normalizedStoredName = normalizeString(tab.UserData and tab.UserData.tabName or "")

    return normalizedTabIdSuffix == normalizedIdentifier
        or normalizedStoredName == normalizedIdentifier
        or storedId:find(normalizedIdentifier)
end

function DualPaneController:GenerateTabId(modUUID, tabName)
    return modUUID .. "_" .. normalizeString(tabName)
end

-- Attach hover listeners to either the menuScrollWindow (if expanded/visible) or the expand button (if collapsed)
function DualPaneController:AttachHoverListeners()
    local enabledHover = MCMAPI:GetSettingValue("enable_hover", ModuleUUID)
    if not enabledHover then return end
    if self.menuScrollWindow.Visible then
        self.menuScrollWindow.OnHoverEnter = function()
            self.isHovered = true
            self.userHasInteracted = true

            self:CancelAutoCollapse()
            self.menuScrollWindow:SetStyle("Alpha", 1)
        end
        self.menuScrollWindow.OnHoverLeave = function()
            local enabledAutoCollapse = MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID)
            if not enabledAutoCollapse then return end

            self.isHovered = false

            self:ScheduleAutoCollapse()
            self:FadeSidebarOutAlpha(HOVER_DELAY_MS / 1000)
        end
    else
        if HeaderActionsInstance.expandBtn then
            HeaderActionsInstance.expandBtn.OnHoverEnter = function()
                local enabledHover = MCMAPI:GetSettingValue("enable_hover", ModuleUUID)
                if not enabledHover then return end

                self.isHovered = true
                self.userHasInteracted = true
                self:CancelAutoCollapse()
                self:Expand()
            end
        end
    end
end

-- Gradually fade the menuScrollWindow's alpha to a target value over a given duration (in seconds)
function DualPaneController:FadeSidebarOutAlpha(durationInS)
    local targetAlpha = 0.33
    self.menuScrollWindow:SetStyle("Alpha", 0.8)
    local startAlpha = self.menuScrollWindow:GetStyle("Alpha")
    local steps = durationInS / STEP_DELAY
    local alphaStep = (startAlpha - targetAlpha) / steps

    local function stepFade()
        -- If the user re-enters before fade-out completes, cancel further fade steps.
        if self.isHovered then
            return
        end

        local currentAlpha = self.menuScrollWindow:GetStyle("Alpha") or startAlpha
        if currentAlpha > targetAlpha then
            local newAlpha = math.max(targetAlpha, currentAlpha - alphaStep)
            self.menuScrollWindow:SetStyle("Alpha", newAlpha)
            if newAlpha > targetAlpha then
                Ext.Timer.WaitFor(STEP_DELAY, stepFade)
            end
        end
    end

    stepFade()
end

function DualPaneController:CancelAutoCollapse()
    if self.hoverSubscription then
        -- REVIEW: Is this how you unsubscribe?
        self.hoverSubscription:_unsubscribe()
        self.hoverSubscription = nil
    end
end

-- Schedule auto-collapse after HOVER_DELAY_MS if not hovered and if the user has already interacted
function DualPaneController:ScheduleAutoCollapse()
    local enabledAutoCollapse = MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID)
    if not enabledAutoCollapse or (not self.userHasInteracted) then
        return
    end

    self:CancelAutoCollapse()

    local scheduler = RX.TimerScheduler.Create()
    self.hoverSubscription = scheduler:Schedule(function()
        if not self.isHovered then
            self:Collapse()
        end
    end, HOVER_DELAY_MS)
end

-- Internal method to update header toggle icons
---@param ignoreCollapsed? boolean Optional parameter to ignore the collapse state
function DualPaneController:UpdateToggleButtons(ignoreCollapsed)
    if not ignoreCollapsed then
        if self.isCollapsed then
            HeaderActionsInstance.expandBtn.Visible = true
            HeaderActionsInstance.collapseBtn.Visible = false
        else
            HeaderActionsInstance.expandBtn.Visible = false
            HeaderActionsInstance.collapseBtn.Visible = true
        end
    else
        HeaderActionsInstance.expandBtn.Visible = not HeaderActionsInstance.expandBtn.Visible
        HeaderActionsInstance.collapseBtn.Visible = not HeaderActionsInstance.collapseBtn.Visible
    end
end

-- Expand the sidebar (menu pane) 'asynchronously'
function DualPaneController:Expand()
    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width
    local selfRef = self
    HeaderActionsInstance:UpdateToggleButtons(false) -- show collapse button when expanded
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
            HeaderActionsInstance:UpdateToggleButtons(selfRef.isCollapsed)
            selfRef:AttachHoverListeners()
        end
    end
    stepExpand()
end

function DualPaneController:Collapse()
    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width
    local selfRef = self
    HeaderActionsInstance:UpdateToggleButtons(true) -- show expand button when collapsed
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
            HeaderActionsInstance:UpdateToggleButtons(selfRef.isCollapsed)
            selfRef:AttachHoverListeners()
        end
    end
    stepCollapse()
end

-- Toggle the sidebar
function DualPaneController:ToggleSidebar()
    self.userHasInteracted = true
    if self.isCollapsed then
        self:Expand()
    else
        self:Collapse()
    end
end

-- Tab management API; delegates to RightPane.
function DualPaneController:CreateModTab(modUUID, tabName)
    return self.rightPane:CreateTab(modUUID, tabName)
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
    return self.rightPane:InsertTab(modUUID, tabName, callback)
end

function DualPaneController:SetVisibleFrame(modUUID)
    self.rightPane:SetVisibleGroup(modUUID)
end

-- Helper called from LeftPane buttons.
function DualPaneController:SwitchVisibleContent(button, uuid)
    self:SetVisibleFrame(uuid)
    self.leftPane:SetActiveItem(uuid)
    if not MCMProxy.IsMainMenu() then
        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ACTIVATED, { modUUID = uuid })
    end
end

-- Open a specific page and optionally a subtab.
-- If tabName is provided, it activates that tab (by setting its SetSelected property to true).
---@param modUUID string The UUID of the mod to open
---@param tabName? string The name of the tab to open
function DualPaneController:OpenModPage(identifier, modUUID)
    -- IMGUIAPI:OpenMCMWindow(true)
    self:SetVisibleFrame(modUUID)

    local modTabBar = self.rightPane:GetModTabBar(modUUID)
    if not modTabBar then
        MCMError(0, "No tab bar found for mod " .. modUUID)
        return
    end

    local targetTab = nil

    for _, tab in ipairs(modTabBar.Children) do
        if isMatchingTab(modUUID, identifier, tab) then
            targetTab = tab
            break
        end
    end

    if targetTab then
        targetTab.SetSelected = true
        IMGUIAPI:OpenMCMWindow(true)
    else
        MCMWarn(0, "Tab not found for identifier: " .. identifier)
    end

    -- Collapse the sidebar when opening the specific page.
    self:Collapse()

    -- Avoid select lockdown by unselecting the tab after a few ticks
    Ext.Timer.WaitFor(100, function()
        if not targetTab then return end
        targetTab.SetSelected = false
    end)
end
