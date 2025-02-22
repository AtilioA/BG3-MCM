---@class KeybindingV2IMGUIWidget: IMGUIWidget
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)

LISTENING_INPUT_STRING = "Press keys to assign [ESC to cancel | BACKSPACE to clear]"
UNASSIGNED_CONTROLLER_BUTTON_STRING = "Unassigned controller button"
-- UNASSIGNED_KEYBOARD_MOUSE_STRING = "Unassigned KB or Mouse keybinding"
UNASSIGNED_KEYBOARD_MOUSE_STRING = "Unassigned keyboard keybinding"

function KeybindingV2IMGUIWidget:new(group)
    local instance = setmetatable({}, { __index = KeybindingV2IMGUIWidget })
    instance.Widget = {
        Group = group,
        SearchText = "",
        FilteredActions = {},
        CollapsedMods = {},
        ListeningForInput = false,
        CurrentListeningAction = nil,
        InputEventSubscriptions = {},
        DynamicElements = {
            ModHeaders = {},
            SearchInput = nil,
            NoResultsText = nil
        }
    }
    instance.PressedKeys = {}
    instance.AllPressedKeys = {}

    instance.Widget.DebounceSearch = VCTimer:Debounce(50, function()
        instance:FilterActions()
        instance:RefreshUI()
    end)

    -- Subscribe to registry changes so UI updates automatically.
    instance._registrySubscription = KeybindingsRegistry:GetSubject():Subscribe(function(newRegistry)
        instance:FilterActions()
        instance:RefreshUI()
    end)

    return instance
end

-- Filters actions using the centralized registry.
function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:upper()
    local registry = KeybindingsRegistry.GetRegistry()

    for modUUID, actions in pairs(registry) do
        local modName = Ext.Mod.GetMod(modUUID).Info.Name
        local filteredActions = {}
        for actionId, binding in pairs(actions) do
            local matchesModName = VCString:FuzzyMatch(modName:upper(), searchText)
            local matchesActionName = VCString:FuzzyMatch(actions[actionId].actionName:upper(), searchText)
            -- TODO: fix fuzzy search with keybindings
            -- _D(binding.keyboardBinding)
            local matchesKeyboard = binding.keyboardBinding and binding.keyboardBinding.Key and
                VCString:FuzzyMatch(binding.keyboardBinding.Key:upper(), searchText) and
                binding.keyboardBinding.ModifierKeys --and
            -- VCString:FuzzyMatch(binding.keyboardBinding.ModifierKeys:upper(), searchText)
            -- local matchesController = binding.controllerBinding and
            --     VCString:FuzzyMatch(binding.controllerBinding:upper(), searchText)
            if searchText == "" or matchesModName or matchesActionName or matchesKeyboard then
                table.insert(filteredActions, {
                    ModUUID = modUUID,
                    ActionName = binding.actionName,
                    ActionId = actionId,
                    KeyboardMouseBinding = binding.keyboardBinding or UNASSIGNED_KEYBOARD_MOUSE_STRING,
                    ControllerBinding = binding.controllerBinding or UNASSIGNED_CONTROLLER_BUTTON_STRING,
                    DefaultKeyboardMouseBinding = binding.defaultKeyboardBinding,
                    DefaultControllerBinding = binding.defaultControllerBinding
                })
            end
        end

        if #filteredActions > 0 then
            table.insert(filteredMods, {
                ModName = modName,
                ModUUID = modUUID,
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
        -- TODO: fetch name elsewhere
        local modHeader = group:AddCollapsingHeader(Ext.Mod.GetMod(mod.ModUUID).Info.Name)
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

    imguiTable:AddColumn("Action Name", "WidthFixed", 250)
    imguiTable:AddColumn("Keyboard/Mouse Input", "WidthFixed", 550)
    imguiTable:AddColumn("Controller Input", "WidthFixed", 400)
    imguiTable:AddColumn("Reset", "WidthFixed", 100)

    for _, action in ipairs(mod.Actions) do
        local row = imguiTable:AddRow()
        local nameCell = row:AddCell()
        local nameText = nameCell:AddText(action.ActionName)
        nameText.IDContext = mod.ModName .. "_ActionName_" .. action.ActionId
        nameText:Tooltip():AddText("Action: " .. action.ActionName)

        local kbCell = row:AddCell()
        local kbButton = kbCell:AddButton(KeyPresentationMapping:GetKBViewKey(action.KeyboardMouseBinding) or
            UNASSIGNED_KEYBOARD_MOUSE_STRING)
        kbButton.IDContext = mod.ModName .. "_KBMouse_" .. action.ActionId
        kbButton.OnClick = function()
            self:StartListeningForInput(mod, action, "KeyboardMouse", kbButton)
        end
        kbButton:Tooltip():AddText("Click to assign a new key/mouse button.")

        local ctrlCell = row:AddCell()
        local ctrlBinding = action.ControllerBinding
        if type(ctrlBinding) == "table" then
            ctrlBinding = ctrlBinding[1]
        end
        local ctrlButton = ctrlCell:AddButton(KeyPresentationMapping:GetViewKey(ctrlBinding) or
            UNASSIGNED_CONTROLLER_BUTTON_STRING)
        ctrlButton.IDContext = mod.ModName .. "_Controller_" .. action.ActionId
        ctrlButton.OnClick = function()
            self:StartListeningForInput(mod, action, "Controller", ctrlButton)
        end
        ctrlButton:Tooltip():AddText("Click to assign a new controller button.")

        local resetCell = row:AddCell()
        local resetButton = resetCell:AddButton("Reset")
        resetButton.IDContext = mod.ModName .. "_Reset_" .. action.ActionId
        resetButton.OnClick = function()
            self:ResetBinding(mod.ModUUID, action.ActionId)
        end
        resetButton:Tooltip():AddText("Reset to default binding.")
    end
end

function KeybindingV2IMGUIWidget:StartListeningForInput(mod, action, inputType, button)
    self.Widget.ListeningForInput = true
    self.Widget.CurrentListeningAction = { Mod = mod, Action = action, InputType = inputType, Button = button }
    self:RegisterInputEvents()
    button.Label = LISTENING_INPUT_STRING
    button.Disabled = true
end

function KeybindingV2IMGUIWidget:RegisterInputEvents()
    self.Widget.InputEventSubscriptions = {
        KeyInput = Ext.Events.KeyInput:Subscribe(function(e)
            self:HandleKeyInput(e)
        end),
        -- MouseButtonInput = Ext.Events.MouseButtonInput:Subscribe(function(e)
        --     self:HandleMouseInput(e)
        -- end),
        ControllerButtonInput = Ext.Events.ControllerButtonInput:Subscribe(function(e)
            e.PreventAction()
            self:HandleControllerInput(e)
        end)
    }
end

function KeybindingV2IMGUIWidget:UnregisterInputEvents()
    local subs = self.Widget.InputEventSubscriptions
    if subs.KeyInput then
        Ext.Events.KeyInput:Unsubscribe(subs.KeyInput); subs.KeyInput = nil
    end
    if subs.MouseButtonInput then
        Ext.Events.MouseButtonInput:Unsubscribe(subs.MouseButtonInput); subs.MouseButtonInput = nil
    end
    if subs.ControllerButtonInput then
        Ext.Events.ControllerButtonInput:Unsubscribe(subs.ControllerButtonInput); subs.ControllerButtonInput = nil
    end
end

function KeybindingV2IMGUIWidget:HandleKeyInput(e)
    if not self.Widget.ListeningForInput then
        return
    end
    self.PressedKeys = self.PressedKeys or {}
    self.AllPressedKeys = self.AllPressedKeys or {}

    if e.Event == "KeyDown" and not e.Repeat then
        if e.Key == "ESCAPE" then
            -- Cancel listening without updating the binding.
            self:CancelKeybinding()
            return
        elseif e.Key == "BACKSPACE" then
            -- Remove/clear the binding.
            local modData = self.Widget.CurrentListeningAction.Mod
            local action = self.Widget.CurrentListeningAction.Action
            local inputType = self.Widget.CurrentListeningAction.InputType

            self.Widget.ListeningForInput = false
            self.Widget.CurrentListeningAction = nil
            self:UnregisterInputEvents()

            if inputType == "KeyboardMouse" then
                KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, "", "KeyboardMouse")
            else
                KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, "", "Controller")
            end
            return
        end

        -- Otherwise, record keys.
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
            local key = ""
            local modifierKeys = {}
            for pressedKey, _ in pairs(self.AllPressedKeys) do
                if KeybindingManager:IsActiveModifier(pressedKey) then
                    table.insert(modifierKeys, pressedKey)
                else
                    -- REVIEW: Not sure how I feel about multi-key support. Probably overkill.
                    -- table.insert(keys, key)
                    key = pressedKey:upper()
                end
            end
            self.PressedKeys = {}
            self.AllPressedKeys = {}
            local newKeybinding = {
                Key = key,
                ModifierKeys = modifierKeys
            }
            self:AssignKeybinding(newKeybinding)
        end
    end
end

function KeybindingV2IMGUIWidget:HandleControllerInput(e)
    if not self.Widget.ListeningForInput or not e.Pressed then
        return
    end
    local button = "Controller" .. tostring(e.Button)
    self:AssignKeybinding(button)
end

function KeybindingV2IMGUIWidget:HandleMouseInput(e)
    if not self.Widget.ListeningForInput or not e.Pressed then return end
    local button = "Mouse" .. tostring(e.Button)
    self:AssignKeybinding(button)
end

function KeybindingV2IMGUIWidget:AssignKeybinding(keybinding)
    if not self.Widget.CurrentListeningAction then
        return
    end

    local modData = self.Widget.CurrentListeningAction.Mod
    local action = self.Widget.CurrentListeningAction.Action
    local inputType = self.Widget.CurrentListeningAction.InputType
    local buttonElement = self.Widget.CurrentListeningAction.Button

    self.Widget.ListeningForInput = false
    self.Widget.CurrentListeningAction = nil
    self:UnregisterInputEvents()

    local conflictAction = self:CheckForConflicts(keybinding, modData, action, inputType)
    if conflictAction then
        NotificationManager:CreateIMGUINotification("Keybinding_Conflict", 'warning', "Keybinding Conflict",
            "Keybinding conflict with action: " .. conflictAction.ActionName, {}, ModuleUUID)
    end

    local registry = KeybindingsRegistry.GetRegistry()
    local currentBinding = (registry[modData.ModUUID] and registry[modData.ModUUID][action.ActionId]) or {}

    local newPayload = {}
    if inputType == "KeyboardMouse" then
        newPayload.Keyboard = {
            Key = keybinding.Key or keybinding,
            ModifierKeys = keybinding.ModifierKeys or {}
        }
        newPayload.Controller = {
            Buttons = { currentBinding.controllerBinding or modData.DefaultControllerBinding }
        }
    else
        newPayload.Controller = {
            Buttons = { keybinding }
        }
        newPayload.Keyboard = currentBinding.keyboardBinding or modData.DefaultKeyboardBinding or
            { Key = "", ModifierKeys = {} }
    end

    local success = KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, keybinding, inputType)
    if success then
        MCMAPI:SetSettingValue(action.ActionId, newPayload, modData.ModUUID)
    else
        print("Failed to update binding in registry for mod '" ..
            modData.ModName .. "', action '" .. action.ActionId .. "'.")
    end

    xpcall(function()
        if inputType == "KeyboardMouse" and type(keybinding) == "table" and buttonElement then
            buttonElement.Label = KeyPresentationMapping:GetKBViewKey(keybinding) or UNASSIGNED_KEYBOARD_MOUSE_STRING
        elseif inputType == "Controller" then
            buttonElement.Label = keybinding
        else
            buttonElement.Label = UNASSIGNED_KEYBOARD_MOUSE_STRING
        end
        buttonElement.Disabled = false
    end, function(err)
    end)
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
            buttonElement.Label = KeyPresentationMapping:GetKBViewKey(action.KeyboardMouseBinding) or
                UNASSIGNED_KEYBOARD_MOUSE_STRING
        else
            buttonElement.Label = KeyPresentationMapping:GetViewKey(action.ControllerBinding) or
                UNASSIGNED_CONTROLLER_BUTTON_STRING
        end
        buttonElement.Disabled = false
    end
end

function KeybindingV2IMGUIWidget:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    -- Could probably use a lookup table for this.
    local registry = KeybindingsRegistry.GetRegistry()
    local currentModName = currentMod.ModName
    local currentActionId = currentAction.ActionId
    local isKeyboardMouse = (inputType == "KeyboardMouse")

    for modName, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if modName ~= currentModName or actionId ~= currentActionId then
                local existing = isKeyboardMouse and binding.keyboardBinding or binding.controllerBinding
                if existing ~= "" and existing == keybinding then
                    return { ActionName = binding.actionName }
                end
            end
        end
    end

    return nil
end

function KeybindingV2IMGUIWidget:ResetBinding(modUUID, actionId)
    local registry = KeybindingsRegistry.GetRegistry()
    if registry[modUUID] and registry[modUUID][actionId] then
        local binding = registry[modUUID][actionId]
        KeybindingsRegistry.UpdateBinding(modUUID, actionId, binding.defaultKeyboardBinding, "KeyboardMouse")
        KeybindingsRegistry.UpdateBinding(modUUID, actionId, binding.defaultControllerBinding, "Controller")
        self:RefreshUI()
    end
end

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

function KeybindingV2IMGUIWidget:Destroy()
    self:UnregisterInputEvents()
    self:ClearDynamicElements()
    if self._registrySubscription then
        self._registrySubscription:unsubscribe()
        self._registrySubscription = nil
    end
    self.Widget.Group:Destroy()
end

function KeybindingV2IMGUIWidget:UpdateCurrentValue(value)
    -- Not used.
end

return KeybindingV2IMGUIWidget
