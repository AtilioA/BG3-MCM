---@class KeybindingV2IMGUIWidget: IMGUIWidget
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)

---@class KeybindingAction
---@field ActionName string
---@field KeyboardMouseBinding string
---@field ControllerBinding string
---@field DefaultKeyboardMouseBinding string
---@field DefaultControllerBinding string
---@field OnBindingFired fun(action: KeybindingAction) -- Fired when the user actually presses this action in-game

---@class ModKeybindings
---@field ModName string
---@field Actions KeybindingAction[]

function KeybindingV2IMGUIWidget:new(group)
    local instance = setmetatable({}, { __index = KeybindingV2IMGUIWidget })
    instance.Widget = {
        Group                = group,
        ModKeybindings       = {},
        SearchText           = "",
        FilteredActions      = {},
        CollapsedMods        = {},
        ListeningForInput    = false,
        CurrentListeningAction = nil,
        InputEventSubscriptions = {},
        DynamicElements = {
            ModHeaders    = {},
            SearchInput   = nil,
            NoResultsText = nil
        }
    }
    instance.PressedKeys = {}
    instance.AllPressedKeys = {}

    -- Debounced searching
    instance.Widget.DebounceSearch = VCTimer:Debounce(50, function()
        instance:FilterActions()
        instance:RefreshUI()
    end)

    return instance
end

--------------------------------------------------------------------------------
-- 1. Register Mod Keybindings
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:RegisterModKeybindings(modKeybindings)
    for _, mod in ipairs(modKeybindings) do
        table.insert(self.Widget.ModKeybindings, mod)
    end
    self:FilterActions()
    self:RefreshUI()
end

--------------------------------------------------------------------------------
-- 2. Search + Filtering
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:lower()

    for _, mod in ipairs(self.Widget.ModKeybindings) do
        local filteredActions = {}
        for _, action in ipairs(mod.Actions) do
            local actionNameLower = action.ActionName:lower()
            local keyboardBindingLower = (action.KeyboardMouseBinding or ""):lower()
            local controllerBindingLower = (action.ControllerBinding or ""):lower()

            -- Fuzzy match (or exact substring match) on action name or current bindings
            local matchesModname = VCString:FuzzyMatch(mod.ModName:lower(), searchText)
            local matchesActionName = VCString:FuzzyMatch(actionNameLower, searchText)
            local matchesKeyboard = VCString:FuzzyMatch(keyboardBindingLower, searchText)
            local matchesController = VCString:FuzzyMatch(controllerBindingLower, searchText)

            if searchText == "" or matchesModname or matchesActionName or matchesKeyboard or matchesController then
                table.insert(filteredActions, action)
            end
        end

        if #filteredActions > 0 then
            table.insert(filteredMods, {
                ModName = mod.ModName,
                Actions = filteredActions
            })
        end
    end

    self.Widget.FilteredActions = filteredMods
end

function KeybindingV2IMGUIWidget:RenderSearchBar()
    local group = self.Widget.Group
    if not self.Widget.DynamicElements.SearchInput then
        group:AddSpacing()
        group:AddText("Search:")
        local searchInput = group:AddInputText("", self.Widget.SearchText)
        searchInput.IDContext = "SearchInput"
        searchInput.AutoSelectAll = true
        searchInput.OnChange = function(input)
            self.Widget.SearchText = input.Text
            self.Widget.DebounceSearch()
        end
        group:AddSeparator()
        self.Widget.DynamicElements.SearchInput = searchInput
    end
end

--------------------------------------------------------------------------------
-- 3. Main Rendering Logic
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:RenderKeybindingTables()
    local group = self.Widget.Group
    self:ClearDynamicElements()
    self:RenderSearchBar()

    if #self.Widget.FilteredActions == 0 then
        local noResultsText = group:AddText("No matching keybindings found.")
        self.Widget.DynamicElements.NoResultsText = noResultsText
        return
    end

    for _, mod in ipairs(self.Widget.FilteredActions) do
        local modHeader = group:AddCollapsingHeader(mod.ModName)
        modHeader.DefaultOpen = true
        modHeader.IDContext = mod.ModName .. "_CollapsingHeader"

        self:RenderKeybindingTable(modHeader, mod)
        table.insert(self.Widget.DynamicElements.ModHeaders, modHeader)
    end
end

function KeybindingV2IMGUIWidget:RenderKeybindingTable(modGroup, mod)
    local columns = 4
    local imguiTable = modGroup:AddTable("", columns)
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    imguiTable:AddColumn("Action Name", "WidthStretch")
    imguiTable:AddColumn("Keyboard/Mouse Input", "WidthFixed", 400)
    imguiTable:AddColumn("Controller Input", "WidthFixed", 400)
    imguiTable:AddColumn("Reset", "WidthFixed", 100)

    for _, action in ipairs(mod.Actions) do
        local row = imguiTable:AddRow()
        -- Action Name
        local nameCell = row:AddCell()
        local nameText = nameCell:AddText(action.ActionName)
        nameText.IDContext = mod.ModName .. "_ActionName_" .. action.ActionName
        nameText:Tooltip():AddText("Action: " .. action.ActionName)

        -- Keyboard
        local kbCell = row:AddCell()
        local kbButton = kbCell:AddButton(action.KeyboardMouseBinding or "Unassigned")
        kbButton.IDContext = mod.ModName .. "_KBMouse_" .. action.ActionName
        kbButton.OnClick = function()
            self:StartListeningForInput(mod, action, "KeyboardMouse", kbButton)
        end
        kbButton:Tooltip():AddText("Click to assign a new key/mouse button.")

        -- Controller
        local ctrlCell = row:AddCell()
        local ctrlButton = ctrlCell:AddButton(action.ControllerBinding or "Unassigned")
        ctrlButton.IDContext = mod.ModName .. "_Controller_" .. action.ActionName
        ctrlButton.OnClick = function()
            self:StartListeningForInput(mod, action, "Controller", ctrlButton)
        end
        ctrlButton:Tooltip():AddText("Click to assign a new controller button.")

        -- Reset
        local resetCell = row:AddCell()
        local resetButton = resetCell:AddButton("Reset")
        resetButton.IDContext = mod.ModName .. "_Reset_" .. action.ActionName
        resetButton.OnClick = function()
            self:ResetBinding(action)
        end
        resetButton:Tooltip():AddText("Reset to default binding.")
    end
end

--------------------------------------------------------------------------------
-- 4. Entering/Exiting "Listening" State
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:StartListeningForInput(mod, action, inputType, button)
    self.Widget.ListeningForInput = true
    self.Widget.CurrentListeningAction = { Mod = mod, Action = action, InputType = inputType, Button = button }

    self:RegisterInputEvents()

    button.Label = "Listening..."
    button.Disabled = true
end

function KeybindingV2IMGUIWidget:RegisterInputEvents()
    self.Widget.InputEventSubscriptions = {
        KeyInput = Ext.Events.KeyInput:Subscribe(function(e)
            self:HandleKeyInput(e)
        end),
        MouseButtonInput = Ext.Events.MouseButtonInput:Subscribe(function(e)
            self:HandleMouseInput(e)
        end),
        ControllerButtonInput = Ext.Events.ControllerButtonInput:Subscribe(function(e)
            self:HandleControllerInput(e)
        end)
    }
end

function KeybindingV2IMGUIWidget:UnregisterInputEvents()
    local subs = self.Widget.InputEventSubscriptions
    if subs.KeyInput then Ext.Events.KeyInput:Unsubscribe(subs.KeyInput); subs.KeyInput = nil end
    if subs.MouseButtonInput then Ext.Events.MouseButtonInput:Unsubscribe(subs.MouseButtonInput); subs.MouseButtonInput = nil end
    if subs.ControllerButtonInput then Ext.Events.ControllerButtonInput:Unsubscribe(subs.ControllerButtonInput); subs.ControllerButtonInput = nil end
end

--------------------------------------------------------------------------------
-- 5. Handling Inputs
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:HandleKeyInput(e)
    if not self.Widget.ListeningForInput then return end
    self.PressedKeys = self.PressedKeys or {}
    self.AllPressedKeys = self.AllPressedKeys or {}

    if e.Event == "KeyDown" and not e.Repeat then
        if e.Key == "BACKSPACE" then
            -- User canceled the binding
            self:CancelKeybinding()
            return
        end

        self.PressedKeys[e.Key] = true
        self.AllPressedKeys[e.Key] = true

    elseif e.Event == "KeyUp" then
        self.PressedKeys[e.Key] = nil
        local allReleased = true
        for _ in pairs(self.PressedKeys) do
            allReleased = false
            break
        end

        if allReleased then
            local keys = {}
            for key, _ in pairs(self.AllPressedKeys) do
                table.insert(keys, key)
            end
            self.PressedKeys = {}
            self.AllPressedKeys = {}
            local keybinding = self:FormatKeybinding(keys)
            self:AssignKeybinding(keybinding)
        end
    end
end

function KeybindingV2IMGUIWidget:HandleMouseInput(e)
    if not self.Widget.ListeningForInput or not e.Pressed then return end
    local button = "Mouse" .. tostring(e.Button)
    self:AssignKeybinding(button)
end

function KeybindingV2IMGUIWidget:HandleControllerInput(e)
    if not self.Widget.ListeningForInput or not e.Pressed then return end
    local button = "Controller" .. tostring(e.Button)
    self:AssignKeybinding(button)
end

function KeybindingV2IMGUIWidget:FormatKeybinding(pressedKeys)
    return table.concat(pressedKeys, "+")
end

--------------------------------------------------------------------------------
-- 6. Assigning the Keybinding (No 'OnBindingChanged')
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:AssignKeybinding(keybinding)
    if not self.Widget.CurrentListeningAction then return end
    local modData = self.Widget.CurrentListeningAction.Mod
    local action = self.Widget.CurrentListeningAction.Action
    local inputType = self.Widget.CurrentListeningAction.InputType
    local buttonElement = self.Widget.CurrentListeningAction.Button

    self.Widget.ListeningForInput = false
    self.Widget.CurrentListeningAction = nil
    self:UnregisterInputEvents()

    -- Conflict check
    local conflictAction = self:CheckForConflicts(keybinding, modData, action, inputType)
    if conflictAction then
        NotificationManager:CreateIMGUINotification("Keybinding_Conflict", 'warning', "Keybinding Conflict",
            "Keybinding conflict with action: " .. conflictAction.ActionName, {}, ModuleUUID)
    end

    -- Assign the new binding
    if inputType == "KeyboardMouse" then
        action.KeyboardMouseBinding = keybinding
    else
        action.ControllerBinding = keybinding
    end

    NotificationManager:CreateIMGUINotification("Keybinding_Assigned", 'info', "Keybinding Assigned",
        "Keybinding assigned to: " .. keybinding, {}, ModuleUUID)

    -- Update UI
    buttonElement.Label = keybinding
    buttonElement.Disabled = false
end

function KeybindingV2IMGUIWidget:CancelKeybinding()
    if self.Widget.CurrentListeningAction then
        local buttonElement = self.Widget.CurrentListeningAction.Button
        local action = self.Widget.CurrentListeningAction.Action
        local inputType = self.Widget.CurrentListeningAction.InputType

        self.Widget.ListeningForInput = false
        self.Widget.CurrentListeningAction = nil
        self:UnregisterInputEvents()

        if inputType == "KeyboardMouse" then
            buttonElement.Label = action.KeyboardMouseBinding or "Unassigned"
        else
            buttonElement.Label = action.ControllerBinding or "Unassigned"
        end
        buttonElement.Disabled = false
    end
end

function KeybindingV2IMGUIWidget:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    for _, mod in ipairs(self.Widget.ModKeybindings) do
        for _, action in ipairs(mod.Actions) do
            if action ~= currentAction then
                local existing = (inputType == "KeyboardMouse") and action.KeyboardMouseBinding or action.ControllerBinding
                if existing == keybinding and existing ~= "" then
                    return action
                end
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- 7. Resetting Bindings to Default
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:ResetBinding(action)
    action.KeyboardMouseBinding = action.DefaultKeyboardMouseBinding
    action.ControllerBinding = action.DefaultControllerBinding
    self:RefreshUI()
end

--------------------------------------------------------------------------------
-- 8. Refresh + Clear UI
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:RefreshUI()
    self:RenderKeybindingTables()
end

function KeybindingV2IMGUIWidget:ClearDynamicElements()
    for _, modHeader in ipairs(self.Widget.DynamicElements.ModHeaders) do
        modHeader:Destroy()
    end
    self.Widget.DynamicElements.ModHeaders = {}

    if self.Widget.DynamicElements.NoResultsText then
        self.Widget.DynamicElements.NoResultsText:Destroy()
        self.Widget.DynamicElements.NoResultsText = nil
    end
end

--------------------------------------------------------------------------------
-- 9. Cleanup on Widget Destruction
--------------------------------------------------------------------------------
function KeybindingV2IMGUIWidget:Destroy()
    self:UnregisterInputEvents()
    self:ClearDynamicElements()
    self.Widget.Group:Destroy()
end
