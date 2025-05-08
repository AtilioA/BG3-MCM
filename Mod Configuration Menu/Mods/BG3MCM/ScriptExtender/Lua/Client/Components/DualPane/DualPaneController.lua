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
---@field currentAnimationState string|nil
DualPaneController = _Class:Create("DualPaneController", nil, {
    window = nil,
    leftPane = nil,
    rightPane = nil,
    isCollapsed = false,
    isHovered = false,
    userHasInteracted = false,
    hoverSubscription = nil,
    currentAnimation = nil,
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

-- Get proportion of screen size based on working number for 4K
TARGET_WIDTH_EXPANDED = Ext.IMGUI.GetViewportSize()[1] / (3840 / 500)
TARGET_WIDTH_COLLAPSED = 5
STEP_DELAY = 1 / 60
STEP_FACTOR = 0.1
HOVER_DELAY_MS = 5000

HeaderActionsInstance = nil

local RX = {
    TimerScheduler = Ext.Require("Lib/reactivex/schedulers/timerscheduler.lua")
}

-- Helper: Generic animation for sidebar transitions
-- This function animates both the width (of the column) and the alpha (of the menuScrollWindow)
-- It stops if the current animation state no longer matches the expected state.
function DualPaneController:animateSidebar(targetWidth, targetAlpha, expectedState, onComplete)
    local colDef = self.mainLayoutTable.ColumnDefs[1]
    local currentWidth = colDef.Width
    local currentAlpha = self.menuScrollWindow:GetStyle("Alpha") or 0

    local function step()
        if self.currentAnimation ~= expectedState then
            return
        end

        local widthDelta = math.abs(currentWidth - targetWidth)
        local alphaDelta = math.abs(currentAlpha - targetAlpha)
        if widthDelta > 0.5 or alphaDelta > 0.01 then
            currentWidth = currentWidth + (targetWidth - currentWidth) * STEP_FACTOR
            colDef.Width = currentWidth

            currentAlpha = currentAlpha + (targetAlpha - currentAlpha) * STEP_FACTOR
            self.menuScrollWindow:SetStyle("Alpha", currentAlpha)

            Ext.Timer.WaitFor(STEP_DELAY, step)
        else
            colDef.Width = targetWidth
            self.menuScrollWindow:SetStyle("Alpha", targetAlpha)
            if onComplete then onComplete() end
        end
    end
    step()
end

-- Setup hover event handlers
function DualPaneController:setupHoverHandlers(targetWindow, onEnter, onLeave)
    targetWindow.OnHoverEnter = onEnter
    targetWindow.OnHoverLeave = onLeave
end

function DualPaneController:InitWithWindow(window)
    local self = setmetatable({}, DualPaneController)
    self.window = window
    self:initLayout()
    self.leftPane = LeftPane:New(self.menuScrollWindow)
    self.rightPane = RightPane:New(self.contentScrollWindow)

    -- Check if we should start collapsed
    local startCollapsed = MCMAPI:GetSettingValue("collapsed_by_default", ModuleUUID)
    self.isCollapsed = startCollapsed
    self.isHovered = false
    self.userHasInteracted = false
    self.hoverSubscription = nil
    self.currentAnimation = nil

    -- Initialize the UI state based on the collapsed setting
    if startCollapsed then
        self.menuScrollWindow.Visible = false
        self.mainLayoutTable.ColumnDefs[1].Width = TARGET_WIDTH_COLLAPSED
        self.menuScrollWindow:SetStyle("Alpha", 0)
    end

    -- Attach hover listeners initially (menu is expanded by default unless collapsed_by_default is true)
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
    self.mainLayoutTable.Resizable = true

    local row = self.mainLayoutTable:AddRow()
    self.menuCell = row:AddCell()
    self.contentCell = row:AddCell()

    self.menuScrollWindow = self.menuCell:AddChildWindow("MenuScrollWindow")

    -- Create header actions before creating the content scroll window.
    -- HeaderActionsInstance is used by RightPane later.
    HeaderActionsInstance = HeaderActions:New(self.contentCell)

    self.contentScrollWindow = self.contentCell:AddChildWindow("ContentScrollWindow")
end

local function normalizeString(str)
    if not str or str == "" then
        return ""
    end

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
        self:setupHoverHandlers(
            self.menuScrollWindow,
            function()
                self.isHovered = true
                self.userHasInteracted = true
                self:CancelAutoCollapse()
                self.menuScrollWindow:SetStyle("Alpha", 1)
            end,
            function()
                local enabledAutoCollapse = MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID)
                if not enabledAutoCollapse then return end
                self.isHovered = false
                self:ScheduleAutoCollapse()
                self:FadeSidebarOutAlpha(HOVER_DELAY_MS / 1000)
            end
        )
    else
        if HeaderActionsInstance.expandBtn then
            self:setupHoverHandlers(
                HeaderActionsInstance.expandBtn,
                function()
                    local enabledHover = MCMAPI:GetSettingValue("enable_hover", ModuleUUID)
                    if not enabledHover then return end
                    self.isHovered = true
                    self.userHasInteracted = true
                    self:CancelAutoCollapse()
                    self:Expand()
                end,
                nil
            )
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

-- Expand the sidebar (menu pane) 'asynchronously'
function DualPaneController:Expand()
    -- Set the current animation to "expand". This cancels any ongoing collapse animation.
    self.currentAnimation = "expand"
    HeaderActionsInstance:UpdateToggleButtons(false)
    self.menuScrollWindow.Visible = true

    self:animateSidebar(TARGET_WIDTH_EXPANDED, 1, "expand", function()
        self.isCollapsed = false
        HeaderActionsInstance:UpdateToggleButtons(self.isCollapsed)
        self:AttachHoverListeners()
        self.currentAnimation = nil
        self.mainLayoutTable.Resizable = true
    end)
end

function DualPaneController:Collapse()
    self.mainLayoutTable.Resizable = false
    self.currentAnimation = "collapse"
    HeaderActionsInstance:UpdateToggleButtons(true)

    self:animateSidebar(TARGET_WIDTH_COLLAPSED, 0, "collapse", function()
        self.menuScrollWindow.Visible = false
        self.isCollapsed = true
        HeaderActionsInstance:UpdateToggleButtons(self.isCollapsed)
        self:AttachHoverListeners()
        self.currentAnimation = nil
    end)
end

-- Toggle the sidebar, canceling any in-progress animation if needed.
function DualPaneController:ToggleSidebar()
    self.userHasInteracted = true

    -- If we are collapsing (:skull:), cancel and start expanding, vice versa
    if self.currentAnimation == "collapse" then
        self:Expand()
        return
    elseif self.currentAnimation == "expand" then
        self:Collapse()
        return
    end

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
    local disclaimerElement = nil

    if tab then
        local text = Ext.Loca.GetTranslatedString(disclaimerLocaKey)
        disclaimerElement = tab:AddText(text)
        disclaimerElement:SetColor("Text", Color.NormalizedRGBA(255, 165, 0, 1))
        disclaimerElement.TextWrapPos = 0
    end

    return tab, disclaimerElement
end

function DualPaneController:InsertModTab(modUUID, tabName, callback)
    return self.rightPane:InsertTab(modUUID, tabName, callback)
end

-- Sets the visible frame for a mod UUID
---@param modUUID string The UUID of the mod to show
---@param shouldEmitEvent boolean|nil If true (default), will emit events; if false, won't emit events (prevents recursive loops)
function DualPaneController:SetVisibleFrame(modUUID, shouldEmitEvent)
    -- Set the visible group in the right pane
    self.rightPane:SetVisibleGroup(modUUID)

    -- Default to true if not specified
    if shouldEmitEvent == nil then shouldEmitEvent = true end

    if shouldEmitEvent and not MCMProxy.IsMainMenu() then
        ModEventManager:Emit(EventChannels.MCM_MOD_TAB_ACTIVATED, { modUUID = modUUID }, true)
    end
end

-- Helper called from LeftPane buttons.
function DualPaneController:SwitchVisibleContent(button, uuid)
    self:SetVisibleFrame(uuid)
    self.leftPane:SetActiveItem(uuid)
end

function DualPaneController:DoesModPageExist(ID)
    local modTabBar = self.rightPane:GetModTabBar(ID)
    return modTabBar ~= nil
end

-- Open a specific page and optionally a subtab.
-- If tabName is provided, it activates that tab (by setting its SetSelected property to true).
---@param identifier string|nil The name of the tab to open
---@param modUUID string The UUID of the mod to open
---@param shouldEmitEvent boolean|nil If true (default), will emit events; if false, won't emit events (prevents recursive loops)
---@param keepSidebarState boolean|nil If true, won't modify the sidebar state (expanded/collapsed). Default is false (will collapse)
---@param shouldOpenWindow boolean|nil If true, will open the MCM window. Default is true.
-- FIXME: does not work with hotkeys and other non-mod pages because they are not registered in the right pane correctly
function DualPaneController:OpenModPage(identifier, modUUID, shouldEmitEvent, keepSidebarState, shouldOpenWindow)
    self:SetVisibleFrame(modUUID, shouldEmitEvent)

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
        -- Only open window if explicitly requested (default true)
        if shouldOpenWindow ~= false then
            IMGUIAPI:OpenMCMWindow(true)
        end
    else
        MCMWarn(0, "Tab not found for identifier: " .. identifier)
    end

    -- Handle sidebar state based on settings unless explicitly told to keep current state
    if keepSidebarState ~= true then
        local enableAutoCollapse = MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID)
        if enableAutoCollapse then
            self:Collapse()
        else
            self:Expand()
        end
    end

    -- Avoid select lockdown by unselecting the tab after a few ticks
    Ext.Timer.WaitFor(100, function()
        if not targetTab then return end
        targetTab.SetSelected = false
    end)
end
