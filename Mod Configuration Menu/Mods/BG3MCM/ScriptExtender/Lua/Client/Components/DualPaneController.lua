--------------------------------------------
-- CONSTANTS & CONFIGURATION
--------------------------------------------
local ICON_TOGGLE_COLLAPSE = "panner_left_d"
local ICON_TOGGLE_EXPAND = "ico_menu_h"
local ICON_DOC = "ico_secret_h"
-- Stub mod documentation text
local DOC_TEXT = "Lorem ipsum dolor sit amet, consectetur adipiscing elit"

local TARGET_WIDTH_EXPANDED = 450
local TARGET_WIDTH_COLLAPSED = 10
local STEP_DELAY = 1 / 60
-- 10% adjustment per step
local STEP_FACTOR = 0.1

-- Stub config: If true, clicking a mod item will auto-collapse the dualpane.
local AUTO_COLLAPSE_ON_MOD_CLICK = true

-- Stub mod content text
local MOD_CONTENT_TEXTS = {
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
    "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
}

--------------------------------------------
-- DUALPANE CONTROLLER DEFINITION
--------------------------------------------
local DualPaneController = {}
DualPaneController.__index = DualPaneController

function DualPaneController:new(mainLayoutTable, leftCellGroup, dualpaneExpandBtn, dualpaneCollapseBtn)
    local self = setmetatable({}, DualPaneController)
    self.mainLayoutTable = mainLayoutTable
    self.leftCellGroup = leftCellGroup
    self.dualpaneExpandBtn = dualpaneExpandBtn
    self.dualpaneCollapseBtn = dualpaneCollapseBtn
    -- false means expanded, true means collapsed
    self.isCollapsed = false
    return self
end

function DualPaneController:Expand()
    if self.dualpaneExpandBtn then self.dualpaneExpandBtn.Visible = false end
    if self.dualpaneCollapseBtn then self.dualpaneCollapseBtn.Visible = true end

    -- Reset alpha to 0 before starting the expansion
    self.leftCellGroup:SetStyle("Alpha", 0)
    self.leftCellGroup.Visible = true

    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width

    local function stepExpand()
        if cWidth < TARGET_WIDTH_EXPANDED then
            cWidth = math.min(TARGET_WIDTH_EXPANDED, cWidth + (TARGET_WIDTH_EXPANDED * STEP_FACTOR))
            self.mainLayoutTable.ColumnDefs[1].Width = cWidth
            local newAlpha = math.min(1, (self.leftCellGroup:GetStyle("Alpha") or 0) + STEP_FACTOR)
            self.leftCellGroup:SetStyle("Alpha", newAlpha)
            Ext.Timer.WaitFor(STEP_DELAY, stepExpand)
        else
            self.isCollapsed = false
        end
    end
    stepExpand()
end

function DualPaneController:Collapse()
    -- If already collapsed, exit early.
    if self.isCollapsed then return end

    if self.dualpaneExpandBtn then self.dualpaneExpandBtn.Visible = true end
    if self.dualpaneCollapseBtn then self.dualpaneCollapseBtn.Visible = false end

    local cWidth = self.mainLayoutTable.ColumnDefs[1].Width

    local function stepCollapse()
        if cWidth > TARGET_WIDTH_COLLAPSED then
            cWidth = math.max(TARGET_WIDTH_COLLAPSED, cWidth - (cWidth * STEP_FACTOR))
            self.mainLayoutTable.ColumnDefs[1].Width = cWidth
            self.leftCellGroup:SetStyle("Alpha", math.max(0, (self.leftCellGroup:GetStyle("Alpha") or 1) - STEP_DELAY))
            Ext.Timer.WaitFor(STEP_DELAY, stepCollapse)
        else
            self.leftCellGroup.Visible = false
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

--------------------------------------------
-- UI CREATION
--------------------------------------------
local demoWindow = Ext.IMGUI.NewWindow("Demo 3")
local minSize = Ext.IMGUI.GetViewportSize()
demoWindow:SetStyle("WindowMinSize", minSize[1] / 3, minSize[2] / 3)

local mainLayoutTable = demoWindow:AddTable("demo", 2)
mainLayoutTable:AddColumn("LeftPane", "WidthFixed", TARGET_WIDTH_EXPANDED)
mainLayoutTable:AddColumn("RightPane", "WidthStretch")
local layoutRow = mainLayoutTable:AddRow()

-- LEFT CELL: Contains hotkeys and mod list
local leftCell = layoutRow:AddCell()
local leftCellGroup = leftCell:AddGroup("leftCellGroup")

-- leftCellGroup.OnHoverEnter = function() _D("leftCellGroup.OnHoverEnter") end

-- RIGHT CELL: Contains dualpane buttons and mod content
local rightCell = layoutRow:AddCell()
local rightCellGroup = rightCell:AddGroup("rightCellGroup")

-- Placeholders for UI elements (will be assigned in creation functions)
local modNameLabel = nil
local dualpaneCollapseBtn = nil
local dualpaneExpandBtn = nil
local dualpaneController = nil

-- Create left pane contents: hotkeys and mod list
local function createLeftCellContents(cellGroup)
    cellGroup:AddButton("Hotkeys")
    local leftWindow = cellGroup:AddChildWindow("leftWindow")
    for i = 1, 50 do
        local btn = leftWindow:AddButton("Mod Entry " .. i)
        btn.OnClick = function()
            if modNameLabel then
                modNameLabel.Label = btn.Label
            end
            -- Auto-collapse if the config is enabled
            if AUTO_COLLAPSE_ON_MOD_CLICK and dualpaneController then
                dualpaneController:Collapse()
            end
        end
    end
end

-- Create right pane contents: dualpane toggle buttons, documentation, detach mod, and mod content area
local function createRightCellContents(cellGroup)
    dualpaneCollapseBtn = cellGroup:AddImageButton("Toggle", ICON_TOGGLE_COLLAPSE, { 40, 40 })
    dualpaneExpandBtn = cellGroup:AddImageButton("Toggle", ICON_TOGGLE_EXPAND, { 40, 40 })
    dualpaneCollapseBtn.Visible = true
    dualpaneExpandBtn.Visible = false

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

    -- Mod content area
    local modContentGroup = cellGroup:AddGroup("modContentGroup")
    local modContentChildWindow = modContentGroup:AddChildWindow("modContentChildWindow")
    modNameLabel = modContentChildWindow:AddSeparatorText("<Mod Name>")

    for _i = 1, 10 do
        for _, text in ipairs(MOD_CONTENT_TEXTS) do
            modContentChildWindow:AddText(text)
        end
    end
    -- (Toggle events will be bound after controller instantiation)
end

-- Create UI elements for left and right cells.
createLeftCellContents(leftCellGroup)
createRightCellContents(rightCellGroup)

--------------------------------------------
-- DUALPANE CONTROLLER INITIALIZATION & BINDING
--------------------------------------------
dualpaneController = DualPaneController:new(mainLayoutTable, leftCellGroup, dualpaneExpandBtn, dualpaneCollapseBtn)

-- Bind toggle events using the controller.
dualpaneExpandBtn.OnClick = function() dualpaneController:Toggle() end
dualpaneCollapseBtn.OnClick = function() dualpaneController:Toggle() end
