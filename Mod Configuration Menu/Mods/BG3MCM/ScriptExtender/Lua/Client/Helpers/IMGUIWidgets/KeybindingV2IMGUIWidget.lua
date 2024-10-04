---@class KeybindingV2IMGUIWidget: IMGUIWidget
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)

---@class KeybindingAction
---@field ActionName string
---@field KeyboardMouseBinding string
---@field ControllerBinding string
---@field DefaultKeyboardMouseBinding string
---@field DefaultControllerBinding string
---@field OnBindingChanged fun(action: KeybindingAction) Callback when binding changes

---@class ModKeybindings
---@field ModName string
---@field Actions KeybindingAction[]

function KeybindingV2IMGUIWidget:new(group)
    local instance = setmetatable({}, { __index = KeybindingV2IMGUIWidget })
    instance.Widget = {}
    instance.Widget.Group = group
    instance.Widget.ModKeybindings = {}
    instance.Widget.SearchText = ""
    instance.Widget.FilteredActions = {}
    instance.Widget.CollapsedMods = {}
    instance.Widget.ListeningForInput = false
    self.PressedKeys = {}
    self.AllPressedKeys = {}
    instance.Widget.CurrentListeningAction = nil
    instance.Widget.InputEventSubscriptions = {}
    instance.Widget.DebounceSearch = VCTimer:Debounce(50, function()
        instance:FilterActions()
        instance:RefreshUI()
    end)
    -- TODO: refactor this garbage
    instance.Widget.DynamicElements = {
        ModHeaders = {},
        SearchInput = nil,
        NoResultsText = nil
    }
    return instance
end

--- Registers keybindings from mods
--- @param modKeybindings ModKeybindings[]
function KeybindingV2IMGUIWidget:RegisterModKeybindings(modKeybindings)
    for _, mod in ipairs(modKeybindings) do
        table.insert(self.Widget.ModKeybindings, mod)
    end
    self:FilterActions()
    self:RefreshUI()
end

function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:lower()
    for _, mod in ipairs(self.Widget.ModKeybindings) do
        local filteredActions = {}
        for _, action in ipairs(mod.Actions) do
            local actionNameLower = action.ActionName:lower()
            local keyboardBindingLower = (action.KeyboardMouseBinding or ""):lower()
            local controllerBindingLower = (action.ControllerBinding or ""):lower()
            if searchText == "" or
                VCString:FuzzyMatch(actionNameLower, searchText) or
                VCString:FuzzyMatch(keyboardBindingLower, searchText) or
                VCString:FuzzyMatch(controllerBindingLower, searchText) then
                table.insert(filteredActions, action)
            end
        end
        if #filteredActions > 0 then
            table.insert(filteredMods, { ModName = mod.ModName, Actions = filteredActions })
        end
    end
    self.Widget.FilteredActions = filteredMods
end

function KeybindingV2IMGUIWidget:RenderSearchBar()
    local group = self.Widget.Group

    -- Create the search bar only if it doesn't exist
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

        -- Store the search input for later reference
        self.Widget.DynamicElements.SearchInput = searchInput
    end
end

function KeybindingV2IMGUIWidget:RenderKeybindingTables()
    local group = self.Widget.Group

    -- Clear previous dynamic elements
    self:ClearDynamicElements()

    -- Render Search Bar
    self:RenderSearchBar()

    if #self.Widget.FilteredActions == 0 then
        local noResultsText = group:AddText("No matching keybindings found.")
        self.Widget.DynamicElements.NoResultsText = noResultsText
        return
    end

    for _, mod in ipairs(self.Widget.FilteredActions) do
        -- Use CollapsingHeader for each mod
        local modHeader = group:AddCollapsingHeader(mod.ModName)
        modHeader.DefaultOpen = true
        modHeader.IDContext = mod.ModName .. "_CollapsingHeader"

        self:RenderKeybindingTable(modHeader, mod)

        -- Keep track of mod headers for cleanup
        table.insert(self.Widget.DynamicElements.ModHeaders, modHeader)
    end
end

function KeybindingV2IMGUIWidget:RenderKeybindingTable(modGroup, mod)
    local columns = 4 -- Action Name, Keyboard/Mouse Input, Controller Input, Reset Button
    local imguiTable = modGroup:AddTable("", columns)
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    -- Add Columns with fixed widths
    imguiTable:AddColumn("Action Name", "WidthStretch")
    imguiTable:AddColumn("Keyboard/Mouse Input", "WidthFixed", 300)
    imguiTable:AddColumn("Controller Input", "WidthFixed", 150)
    imguiTable:AddColumn("Reset", "WidthFixed", 50)

    -- Add rows for each action
    for _, action in ipairs(mod.Actions) do
        local row = imguiTable:AddRow()
        -- Action Name
        local actionNameCell = row:AddCell()
        local actionNameText = actionNameCell:AddText(action.ActionName)
        actionNameText.IDContext = mod.ModName .. "_ActionName_" .. action.ActionName
        actionNameText:Tooltip():AddText("Action: " .. action.ActionName)

        -- Keyboard/Mouse Input
        local kbMouseCell = row:AddCell()
        local kbMouseButton = kbMouseCell:AddButton(action.KeyboardMouseBinding or "Unassigned")
        kbMouseButton.IDContext = mod.ModName .. "_KBMouse_" .. action.ActionName
        kbMouseButton.OnClick = function()
            self:StartListeningForInput(mod, action, "KeyboardMouse", kbMouseButton)
        end
        kbMouseButton:Tooltip():AddText("Click to assign a new key or mouse button.")

        -- Controller Input
        local controllerCell = row:AddCell()
        local controllerButton = controllerCell:AddButton(action.ControllerBinding or "Unassigned")
        controllerButton.IDContext = mod.ModName .. "_Controller_" .. action.ActionName
        controllerButton.OnClick = function()
            self:StartListeningForInput(mod, action, "Controller", controllerButton)
        end
        controllerButton:Tooltip():AddText("Click to assign a new controller button.")

        -- Reset Button
        local resetCell = row:AddCell()
        local resetButton = resetCell:AddButton("Reset")
        resetButton.IDContext = mod.ModName .. "_Reset_" .. action.ActionName
        resetButton.OnClick = function()
            self:ResetBinding(action)
        end
        resetButton:Tooltip():AddText("Reset to default binding.")
    end
end

function KeybindingV2IMGUIWidget:StartListeningForInput(mod, action, inputType, button)
    self.Widget.ListeningForInput = true
    self.Widget.CurrentListeningAction = { Mod = mod, Action = action, InputType = inputType, Button = button }

    -- Subscribe to input events
    self:RegisterInputEvents()

    -- Update the UI to reflect the listening state
    button.Label = "Listening..."
    button.Disabled = true
end

function KeybindingV2IMGUIWidget:RegisterInputEvents()
    -- Subscribe to key input events
    local keyInputIndex = Ext.Events.KeyInput:Subscribe(function(e)
        self:HandleKeyInput(e)
    end)
    -- Subscribe to mouse button events
    local mouseButtonIndex = Ext.Events.MouseButtonInput:Subscribe(function(e)
        self:HandleMouseInput(e)
    end)
    -- Subscribe to controller button events
    local controllerButtonIndex = Ext.Events.ControllerButtonInput:Subscribe(function(e)
        self:HandleControllerInput(e)
    end)
    -- Store subscription indices for cleanup
    self.Widget.InputEventSubscriptions = {
        KeyInput = keyInputIndex,
        MouseButtonInput = mouseButtonIndex,
        ControllerButtonInput = controllerButtonIndex
    }
end

function KeybindingV2IMGUIWidget:UnregisterInputEvents()
    -- Unsubscribe from all input events
    if self.Widget.InputEventSubscriptions.KeyInput then
        Ext.Events.KeyInput:Unsubscribe(self.Widget.InputEventSubscriptions.KeyInput)
        self.Widget.InputEventSubscriptions.KeyInput = nil
    end
    if self.Widget.InputEventSubscriptions.MouseButtonInput then
        Ext.Events.MouseButtonInput:Unsubscribe(self.Widget.InputEventSubscriptions.MouseButtonInput)
        self.Widget.InputEventSubscriptions.MouseButtonInput = nil
    end
    if self.Widget.InputEventSubscriptions.ControllerButtonInput then
        Ext.Events.ControllerButtonInput:Unsubscribe(self.Widget.InputEventSubscriptions.ControllerButtonInput)
        self.Widget.InputEventSubscriptions.ControllerButtonInput = nil
    end
end

function KeybindingV2IMGUIWidget:HandleKeyInput(e)
    if not self.Widget.ListeningForInput then
        return
    end

    -- Initialize the tracking tables if not already
    self.PressedKeys = self.PressedKeys or {}
    self.AllPressedKeys = self.AllPressedKeys or {}

    if e.Event == "KeyDown" and not e.Repeat then
        if e.Key == "ESCAPE" then
            self:CancelKeybinding()
            return
        end

        -- Add the key to the currently pressed keys
        self.PressedKeys[e.Key] = true
        self.AllPressedKeys[e.Key] = true
    elseif e.Event == "KeyUp" then
        -- Remove the key from currently pressed keys
        self.PressedKeys[e.Key] = nil

        -- Check if all keys have been released
        local allReleased = true
        for _ in pairs(self.PressedKeys) do
            allReleased = false
            break
        end

        if allReleased then
            -- Collect all keys that were pressed, ensuring modifiers are listed first
            local keys = {}

            for key, _ in pairs(self.AllPressedKeys) do
                if KeybindingManager:IsActiveModifier(key) then
                    table.insert(keys, 1, key)
                else
                    table.insert(keys, key)
                end
            end

            -- Reset the tracking tables
            self.PressedKeys = {}
            self.AllPressedKeys = {}

            -- Format and assign the keybinding
            local keybinding = self:FormatKeybinding(keys)
            self:AssignKeybinding(keybinding)
        end
    end
end

function KeybindingV2IMGUIWidget:HandleMouseInput(e)
    if self.Widget.ListeningForInput and e.Pressed then
        local button = "Mouse" .. tostring(e.Button)
        self:AssignKeybinding(button)
    end
end

function KeybindingV2IMGUIWidget:HandleControllerInput(e)
    if self.Widget.ListeningForInput and e.Pressed then
        local button = "Controller" .. tostring(e.Button)
        self:AssignKeybinding(button)
    end
end

function KeybindingV2IMGUIWidget:FormatKeybinding(pressedKeys)
    local modStrings = {}
    for _, modifier in ipairs(pressedKeys) do
        table.insert(modStrings, tostring(modifier))
    end
    local pressedKeysStr = table.concat(modStrings, "+")
    return pressedKeysStr
end

function KeybindingV2IMGUIWidget:AssignKeybinding(keybinding)
    if not self.Widget.CurrentListeningAction then return end

    local mod = self.Widget.CurrentListeningAction.Mod
    local action = self.Widget.CurrentListeningAction.Action
    local inputType = self.Widget.CurrentListeningAction.InputType
    local button = self.Widget.CurrentListeningAction.Button

    -- Exit listening state before checking conflicts to avoid recursion
    self.Widget.ListeningForInput = false
    self.Widget.CurrentListeningAction = nil

    -- Unsubscribe from input events
    self:UnregisterInputEvents()

    -- Check for conflicts
    local conflictAction = self:CheckForConflicts(keybinding, mod, action, inputType)
    if conflictAction then
        -- Show warning message using NotificationManager
        -- NotificationManager:ShowWarning("Keybinding conflict detected with action: " .. conflictAction.ActionName)
        -- Optionally, color the conflicting key/button in red
    else
        -- Assign the keybinding
        if inputType == "KeyboardMouse" then
            action.KeyboardMouseBinding = tostring(keybinding)
        elseif inputType == "Controller" then
            action.ControllerBinding = tostring(keybinding)
        end

        -- Call the OnBindingChanged callback if provided
        if action.OnBindingChanged then
            action.OnBindingChanged(action)
        end

        -- Provide visual feedback
        -- NotificationManager:ShowInfo("Keybinding assigned successfully.")
    end

    -- Update the button label back to the assigned keybinding
    if inputType == "KeyboardMouse" then
        button.Label = action.KeyboardMouseBinding or "Unassigned"
    else
        button.Label = action.ControllerBinding or "Unassigned"
    end
    button.Disabled = false
end

function KeybindingV2IMGUIWidget:CancelKeybinding()
    if self.Widget.CurrentListeningAction then
        local button = self.Widget.CurrentListeningAction.Button
        local action = self.Widget.CurrentListeningAction.Action
        local inputType = self.Widget.CurrentListeningAction.InputType

        -- Exit listening state
        self.Widget.ListeningForInput = false
        self.Widget.CurrentListeningAction = nil

        -- Unsubscribe from input events
        self:UnregisterInputEvents()

        -- Revert the button label
        if inputType == "KeyboardMouse" then
            button.Label = action.KeyboardMouseBinding or "Unassigned"
        else
            button.Label = action.ControllerBinding or "Unassigned"
        end
        button.Disabled = false
    end
end

function KeybindingV2IMGUIWidget:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    for _, mod in ipairs(self.Widget.ModKeybindings) do
        for _, action in ipairs(mod.Actions) do
            if action ~= currentAction then
                local existingBinding = inputType == "KeyboardMouse" and action.KeyboardMouseBinding or
                    action.ControllerBinding
                if existingBinding == keybinding then
                    return action -- Return the conflicting action
                end
            end
        end
    end
    return nil
end

function KeybindingV2IMGUIWidget:ResetBinding(action)
    action.KeyboardMouseBinding = action.DefaultKeyboardMouseBinding
    action.ControllerBinding = action.DefaultControllerBinding
    -- Call the OnBindingChanged callback if provided
    if action.OnBindingChanged then
        action.OnBindingChanged(action)
    end
    -- Refresh the UI
    self:RefreshUI()
end

function KeybindingV2IMGUIWidget:RefreshUI()
    -- Re-render the keybinding tables
    self:RenderKeybindingTables()
end

function KeybindingV2IMGUIWidget:ClearDynamicElements()
    -- Destroy mod headers
    for _, modHeader in ipairs(self.Widget.DynamicElements.ModHeaders) do
        modHeader:Destroy()
    end
    self.Widget.DynamicElements.ModHeaders = {}

    -- Destroy 'No matching keybindings' text
    if self.Widget.DynamicElements.NoResultsText then
        self.Widget.DynamicElements.NoResultsText:Destroy()
        self.Widget.DynamicElements.NoResultsText = nil
    end

    -- Clear the group to ensure all dynamic elements are removed
    -- self.Widget.Group:Destroy()
end

-- Clean up when the widget is destroyed
function KeybindingV2IMGUIWidget:Destroy()
    self:UnregisterInputEvents()
    self:ClearDynamicElements()
    self.Widget.Group:Destroy()
end
