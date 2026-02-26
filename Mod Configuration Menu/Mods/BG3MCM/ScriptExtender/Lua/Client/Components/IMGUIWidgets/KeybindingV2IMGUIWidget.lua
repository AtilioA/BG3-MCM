-- TODO: add another column to 'ignore conflicts'?

---@class KeybindingV2IMGUIWidget: IMGUIWidget
---@field Widget table
---@field PressedKeys table<string, boolean>
---@field AllPressedKeys table<string, boolean>
---@field _registrySubscription any
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)


---Creates a new instance of KeybindingV2IMGUIWidget
---@param group ExtuiGroup The IMGUI group to attach this widget to
---@return KeybindingV2IMGUIWidget
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
            NoResultsText = nil,
            ModPageHintText = nil
        }
    }
    instance.PressedKeys = {}
    instance.AllPressedKeys = {}

    -- Use the global search subject if available
    instance.SearchSubject = KeybindingsUI.SearchBar and KeybindingsUI.SearchBar.SearchSubject

    if instance.SearchSubject then
        -- Subscribe to search text changes
        instance._searchSubscription = instance.SearchSubject:Subscribe(function(searchText)
            instance.Widget.SearchText = searchText or ""
            instance:FilterActions()
            instance:RefreshUI()
        end)
    end

    -- Subscribe to registry changes so UI updates automatically.
    instance._registrySubscription = KeybindingsRegistry:GetSubject():Subscribe(function(newRegistry)
        instance:FilterActions()
        instance:RefreshUI()
    end)

    return instance
end

---Stores a keybinding in the registry
---@param modData table The mod data containing ModUUID and ModName
---@param action table The action data containing ActionId
---@param payload table The payload containing the keybinding data
---@return boolean success Whether the operation was successful
function KeybindingV2IMGUIWidget:StoreKeybinding(modData, action, payload)
    local success = KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, payload, true)
    if not success then
        MCMWarn(0,
            "Failed to update binding in registry for mod '" ..
            modData.ModName .. "', action '" .. action.ActionId .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    end
    return success
end

---Filters actions using the centralized registry based on the current search text
function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:upper()
    local registry = KeybindingsRegistry.GetFilteredRegistry()

    for modUUID, actions in pairs(registry) do
        local sortMode = actions._keybindingSortMode or "alphabetical"
        local modName = MCMClientState:GetModName(modUUID)
        if not modName then
            MCMWarn(0, string.format("Mod name not found for UUID: %s", modUUID))
            modName = "MISSING_NAME"
        end
        local filteredActions = {}
        for actionId, binding in pairs(actions) do
            if actionId ~= "_keybindingSortMode" then
                local matchesModName = VCString:FuzzyMatch(modName:upper(), searchText)
                local matchesActionName = VCString:FuzzyMatch(binding.actionName:upper(), searchText)
                local matchesTooltip = VCString:FuzzyMatch(binding.tooltip:upper(), searchText)
                local matchesKeyboard = binding.keyboardBinding and binding.keyboardBinding.Key and
                    VCString:FuzzyMatch(binding.keyboardBinding.Key:upper(), searchText) and
                    binding.keyboardBinding.ModifierKeys
                local matchesPresentationKeyboard = binding.keyboardBinding and binding.keyboardBinding.Key and
                    VCString:FuzzyMatch(KeyPresentationMapping:GetKBViewKey(binding.keyboardBinding):upper(), searchText)
                if searchText == "" or matchesModName or matchesActionName or matchesKeyboard or matchesPresentationKeyboard or matchesTooltip then
                    table.insert(filteredActions, {
                        ModUUID = modUUID,
                        ActionName = binding.actionName,
                        ActionId = actionId,
                        Enabled = binding.enabled,
                        DefaultEnabled = binding.defaultEnabled,
                        KeyboardMouseBinding = binding.keyboardBinding or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING,
                        DefaultKeyboardMouseBinding = binding.defaultKeyboardBinding,
                        MouseBinding = binding.mouseBinding or { Button = 0, ModifierKeys = {} },
                        DefaultMouseBinding = binding.defaultMouseBinding or { Button = 0, ModifierKeys = {} },
                        Description = binding.description,
                        AllowConflict = binding.allowConflict,
                        Tooltip = binding.tooltip,
                        SortOrder = binding.sortOrder
                    })
                end
            end
        end

        if #filteredActions > 0 then
            table.insert(filteredMods, {
                ModName = modName,
                ModUUID = modUUID,
                Actions = filteredActions,
                KeybindingSortMode = sortMode
            })
        end
    end

    self.Widget.FilteredActions = filteredMods
end

---Sorts the filtered actions with MCM first, then alphabetically by mod name
function KeybindingV2IMGUIWidget:SortFilteredActions()
    table.sort(self.Widget.FilteredActions, function(a, b)
        if a.ModUUID == ModuleUUID then
            return true
        elseif b.ModUUID == ModuleUUID then
            return false
        else
            local modAName = MCMClientState:GetModName(a.ModUUID) or ""
            local modBName = MCMClientState:GetModName(b.ModUUID) or ""
            return modAName < modBName
        end
    end)

    -- For each mod, sort its actions by ActionName or index.
    for _, mod in ipairs(self.Widget.FilteredActions) do
        local sortMode = mod.KeybindingSortMode or "alphabetical"
        if sortMode == "blueprint_order" then
            table.sort(mod.Actions, function(a, b)
                local orderA = a.SortOrder or math.huge
                local orderB = b.SortOrder or math.huge
                return orderA < orderB
            end)
        else
            table.sort(mod.Actions, function(a, b)
                return a.ActionName < b.ActionName
            end)
        end
    end
end

---Renders the keybinding tables for all filtered mods
function KeybindingV2IMGUIWidget:RenderKeybindingTables()
    local group = self.Widget.Group
    self:ClearDynamicElements()

    if #self.Widget.FilteredActions == 0 then
        -- FIXME: display a "No results" message
        -- local noResultsText = group:AddText(Ext.Loca.GetTranslatedString("hd3bbec3b1be2455986b5da92492f445d4296"))
        -- noResultsText.TextWrapPos = 0
    end

    self:SortFilteredActions()

    -- Add hint text before rendering MCM keybindings (no native keybindings here)
    if #self.Widget.FilteredActions > 0 then
        local hintText = group:AddText(Ext.Loca.GetTranslatedString("haafdc7e359944b89905c4d536bfed7cda1gf"))
        hintText.TextWrapPos = 0
        self.Widget.DynamicElements.ModPageHintText = hintText
    end

    for _, mod in ipairs(self.Widget.FilteredActions) do
        local modHeader = group:AddCollapsingHeader(MCMClientState:GetModName(mod.ModUUID))
        modHeader.DefaultOpen = true
        modHeader.IDContext = mod.ModName .. "_CollapsingHeader"
        modHeader.OnRightClick = function()
            IMGUIAPI:OpenModPage(nil, mod.ModUUID, true)
        end
        self:RenderKeybindingTable(modHeader, mod)
        table.insert(self.Widget.DynamicElements.ModHeaders, modHeader)
    end
end

---Renders the keybinding table for a specific mod
---@param modGroup ExtuiGroup The IMGUI group to render the table in
---@param mod table The mod data containing actions to render
function KeybindingV2IMGUIWidget:RenderKeybindingTable(modGroup, mod)
    xpcall(function()
        local columns = 4
        local imguiTable = modGroup:AddTable("", columns)
        imguiTable.BordersOuter = true
        imguiTable.BordersInner = true
        imguiTable.RowBg = true

        -- Define the columns: Enabled, Action, Description, Keybinding, Conflict, and Reset.
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("ha7d3826dfe234bf3955d5b2306057c33gbc4") or "Enabled",
            "WidthFixed", 80)
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h037fe64fb38a45dfb6e3d27ad038f48028a3") or "Action",
            "WidthStretch")
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h68057d690e2f44ae98c31cb07f8074fb7134") or "Keybinding",
            "WidthStretch")
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("hdf6d7d2620f041c2afc116ebf15accc1be5g") or "Conflict",
            "WidthFixed", 280)

        for _, action in ipairs(mod.Actions) do
            local row = imguiTable:AddRow()

            -- Enabled checkbox cell.
            local enabledCell = row:AddCell()
            local enabledCheckbox = enabledCell:AddCheckbox("")
            IMGUIHelpers.AddTooltip(enabledCheckbox,
                Ext.Loca.GetTranslatedString(
                    "h6fd6de5f403d4d5b8a7ba0a8b353b97f7b09"),
                mod.ModName .. "_Enabled_" .. action.ActionId .. "_TOOLTIP")
            enabledCheckbox.Checked = action.Enabled ~= false
            enabledCheckbox.IDContext = mod.ModName .. "_Enabled_" .. action.ActionId
            enabledCheckbox.OnChange = function(checkbox)
                action.Enabled = checkbox.Checked
                -- TODO: refactor back-end to allow partial updates
                self:StoreKeybinding(mod, action, {
                    Keyboard =
                        action.KeyboardMouseBinding,
                    Enabled = checkbox.Checked,
                    AllowConflict = action.AllowConflict
                })
                self:RefreshUI()
            end

            -- Action Name cell.
            local nameCell = row:AddCell()
            local nameText = nameCell:AddText(action.ActionName)
            nameText:SetColor("Text", Color.HEXToRGBA("#EEEEEE"))

            if action.Description and action.Description ~= "" then
                local descriptionText = nameCell:AddText(VCString:ReplaceBrWithNewlines(action.Description))
                nameText.TextWrapPos = 0
                descriptionText.TextWrapPos = 0
                nameText.IDContext = mod.ModName .. "_ActionName_" .. action.ActionId
                descriptionText.IDContext = mod.ModName .. "_ActionDesc_" .. action.ActionId
            end

            IMGUIHelpers.AddTooltip(nameText,
                VCString:ReplaceBrWithNewlines(action.Tooltip ~= "" and action.Tooltip or action.Description),
                mod.ModName .. "_ActionName_" .. action.ActionId .. "_TOOLTIP")

            -- Keybinding cell.
            local kbCell = row:AddCell()
            local bindingLabel = self:GetBindingLabel(action)
            local kbButton = kbCell:AddButton(bindingLabel)
            kbButton:SetColor("Button", Color.NormalizedRGBA(18, 18, 18, 0.8))
            kbButton:SetColor("ButtonActive", Color.NormalizedRGBA(18, 18, 18, 1))
            kbButton:SetColor("ButtonHovered", Color.NormalizedRGBA(18, 18, 18, 0.5))

            kbButton.IDContext = mod.ModName .. "_KBMouse_" .. action.ActionId
            kbButton.OnClick = function()
                self:StartListeningForInput(mod, action, "KeyboardMouse", kbButton)
            end
            -- kbButton.SameLine = true
            IMGUIHelpers.AddTooltip(kbButton, Ext.Loca.GetTranslatedString("h232887313a904f9b8a0818632bb3a418ad0e"),
                mod.ModName .. "_KBMouse_" .. action.ActionId .. "_TOOLTIP")

            -- AllowConflict checkbox cell.
            local conflictCell = row:AddCell()
            local conflictCheckbox = conflictCell:AddCheckbox(Ext.Loca.GetTranslatedString(
                "ha7dbcb7a64404859b1f9c8a6efa96b304d06"))

            IMGUIHelpers.AddTooltip(conflictCheckbox,
                Ext.Loca.GetTranslatedString("h35a1d92d0e8e404f906a4b087020f9e6g3dg"),
                mod.ModName .. "_Conflict_" .. action.ActionId .. "_TOOLTIP")

            conflictCheckbox.Checked = action.AllowConflict == true
            conflictCheckbox.IDContext = mod.ModName .. "_Conflict_" .. action.ActionId
            conflictCheckbox.OnChange = function(checkbox)
                action.AllowConflict = checkbox.Checked
                self:StoreKeybinding(mod, action, {
                    Keyboard = action.KeyboardMouseBinding,
                    Enabled = action.Enabled,
                    AllowConflict = action.AllowConflict
                })
                self:RefreshUI()
            end

            -- Reset button cell.
            -- local resetCell = row:AddCell()
            local resetButton = kbCell:AddImageButton(
                Ext.Loca.GetTranslatedString("hf6cf844cd5fb40d3aca640d5584ed6d47459"),
                ClientGlobals.RESET_SETTING_BUTTON_ICON,
                IMGUIWidget:GetIconSizes())
            resetButton.IDContext = mod.ModName .. "_Reset_" .. action.ActionId
            resetButton.OnClick = function()
                self:ResetBinding(mod.ModUUID, action.ActionId)
            end
            resetButton.SameLine = true

            -- Hide reset button if the binding is set to default
            resetButton.Visible = not self:IsDefaultBinding(action)

            IMGUIHelpers.AddTooltip(resetButton,
                VCString:InterpolateLocalizedMessage(
                    "h497bb04f93734d52a265956df140e77a7add",
                    self:GetDefaultBindingLabel(action),
                    { updateHandle = false }
                ),
                mod.ModName .. "_Reset_" .. action.ActionId .. "_TOOLTIP")

            -- If there is a conflict, color the keybinding button red and show conflict details
            -- Don't show red text if AllowConflict is enabled for this keybinding
            local conflictKB = KeybindingConflictService:CheckForConflicts(action.KeyboardMouseBinding, mod, action,
                "KeyboardMouse")
            if conflictKB and not action.AllowConflict then
                kbButton:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))

                -- Add conflict text below the button
                local conflictText = VCString:InterpolateLocalizedMessage(
                    "h919dc9b46db144ed8c330d1abb728459aea3",
                    conflictKB.ActionName
                )

                -- Add the conflict text below the keybinding button
                local conflictLabel = kbCell:AddText(conflictText)
                conflictLabel.TextWrapPos = 0
                conflictLabel:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
            end
        end
    end, function(err)
        if not modGroup or not err then return end

        MCMError(0, "Error in RenderKeybindingTable: " .. tostring(err))

        local errorText = modGroup:AddText(VCString:InterpolateLocalizedMessage("hd8524a99cb1f41059b7e2aa9c543e68ad7g7",
            tostring(err)))
        errorText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    end)
end

---Starts listening for input for a specific keybinding
---@param mod table The mod data
---@param action table The action data
---@param inputType string The type of input to listen for ("KeyboardMouse")
---@param button ExtuiButton The button element that triggered the input listening
function KeybindingV2IMGUIWidget:StartListeningForInput(mod, action, inputType, button)
    self.Widget.ListeningForInput = true
    self.Widget.CurrentListeningAction = { Mod = mod, Action = action, InputType = inputType, Button = button }
    self:RegisterInputEvents()
    button.Label = ClientGlobals.LISTENING_INPUT_STRING
    button.Disabled = true
end

---Registers input event handlers for key and mouse input
function KeybindingV2IMGUIWidget:RegisterInputEvents()
    self.Widget.InputEventSubscriptions = {
        KeyInput = Ext.Events.KeyInput:Subscribe(function(e)
            self:HandleKeyInput(e)
        end),
        MouseButtonInput = Ext.Events.MouseButtonInput:Subscribe(function(e)
            self:HandleMouseInput(e)
        end)
    }
end

---Unregisters all input event handlers
function KeybindingV2IMGUIWidget:UnregisterInputEvents()
    local subs = self.Widget.InputEventSubscriptions
    if subs.KeyInput then
        Ext.Events.KeyInput:Unsubscribe(subs.KeyInput); subs.KeyInput = nil
    end
    if subs.MouseButtonInput then
        Ext.Events.MouseButtonInput:Unsubscribe(subs.MouseButtonInput); subs.MouseButtonInput = nil
    end
end

---Handles keyboard input events
---@param e table The key input event
function KeybindingV2IMGUIWidget:HandleKeyInput(e)
    if not self.Widget.ListeningForInput then
        return
    end

    if KeybindingsRegistry.ShouldPreventAction(e) then
        e:PreventAction()
        e:StopPropagation()
    end

    self.PressedKeys = self.PressedKeys or {}
    self.AllPressedKeys = self.AllPressedKeys or {}

    if e.Event == "KeyDown" and not e.Repeat then
        if e.Key == "ESCAPE" then
            -- Cancel listening without updating the binding.
            self:CancelKeybinding()
            e:PreventAction()
            e:StopPropagation()
            return
        elseif e.Key == "BACKSPACE" then
            -- Remove/clear both keyboard and mouse bindings.
            local modData = self.Widget.CurrentListeningAction.Mod
            local action = self.Widget.CurrentListeningAction.Action

            self.Widget.ListeningForInput = false
            self.Widget.CurrentListeningAction = nil
            self:UnregisterInputEvents()

            KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId,
                { Keyboard = "", Mouse = { Button = 0, ModifierKeys = {} } }, true)
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

---Handles mouse input events
---@param e table The mouse input event
function KeybindingV2IMGUIWidget:HandleMouseInput(e)
    if not self.Widget.ListeningForInput or not e.Pressed then return end

    local modifierKeys = {}
    if self.AllPressedKeys then
        for pressedKey, _ in pairs(self.AllPressedKeys) do
            if KeybindingManager:IsActiveModifier(pressedKey) then
                table.insert(modifierKeys, pressedKey)
            end
        end
    end

    local mouseBinding = {
        Button = e.Button,
        ModifierKeys = modifierKeys
    }
    self:AssignMouseBinding(mouseBinding)
end

---Assigns a keybinding to the current action
---@param keybinding table The keybinding to assign (string for mouse, table for keyboard)
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

    local conflictAction = KeybindingConflictService:CheckForConflicts({
        Key = keybinding.Key or keybinding,
        ModifierKeys = keybinding.ModifierKeys or {},
        AllowConflict = action.AllowConflict
    }, modData, action, inputType)
    if conflictAction then
        -- TODO: reduce duplication with KeybindingV2IMGUIWidget
        local conflictTitle = VCString:InterpolateLocalizedMessage("hac5a1fd7d223410b8a5fab04951eb428adde",
            action.ActionName)
        local conflictStr = VCString:InterpolateLocalizedMessage("h0f52923132fa41c1a269a7eb647068d8d2ee",
            KeyPresentationMapping:GetKBViewKey(keybinding) or "", action.ActionName, conflictAction.ActionName)
        KeybindingsRegistry.NotifyConflict(conflictTitle, conflictStr)
    end

    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local currentBinding = (registry[modData.ModUUID] and registry[modData.ModUUID][action.ActionId]) or {}

    local newPayload = KeybindingsRegistry.BuildKeyboardPayload(keybinding, currentBinding.Enabled)
    newPayload.AllowConflict = action.AllowConflict

    xpcall(function()
        if self:StoreKeybinding(modData, action, newPayload) then
            if inputType == "KeyboardMouse" and type(keybinding) == "table" and buttonElement then
                buttonElement.Label = KeyPresentationMapping:GetKBViewKey(keybinding) or
                    ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
            else
                buttonElement.Label = ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
            end
            buttonElement.Disabled = false
        else
            MCMError(0, "Failed to update binding in registry for mod '" ..
                modData.ModName .. "', action '" .. action.ActionId .. "'.")
        end
    end, function(err)
    end)
end

---Assigns a mouse binding to the current action
---@param mouseBinding table The mouse binding to assign { Button: number, ModifierKeys: string[] }
function KeybindingV2IMGUIWidget:AssignMouseBinding(mouseBinding)
    if not self.Widget.CurrentListeningAction then
        return
    end

    local modData = self.Widget.CurrentListeningAction.Mod
    local action = self.Widget.CurrentListeningAction.Action
    local buttonElement = self.Widget.CurrentListeningAction.Button

    self.Widget.ListeningForInput = false
    self.Widget.CurrentListeningAction = nil
    self:UnregisterInputEvents()

    self.PressedKeys = {}
    self.AllPressedKeys = {}

    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local currentBinding = (registry[modData.ModUUID] and registry[modData.ModUUID][action.ActionId]) or {}

    local newPayload = KeybindingsRegistry.BuildMousePayload(mouseBinding, currentBinding.Enabled)
    newPayload.AllowConflict = action.AllowConflict

    xpcall(function()
        if self:StoreKeybinding(modData, action, newPayload) then
            buttonElement.Label = KeyPresentationMapping:GetMouseViewKey(mouseBinding) or
                ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
            buttonElement.Disabled = false
        else
            MCMError(0, "Failed to update mouse binding in registry for mod '" ..
                modData.ModName .. "', action '" .. action.ActionId .. "'.")
        end
    end, function(err)
        MCMError(0, "Error in AssignMouseBinding: " .. tostring(err))
    end)
end

---Cancels the current keybinding operation
function KeybindingV2IMGUIWidget:CancelKeybinding()
    if self.Widget.CurrentListeningAction then
        local buttonElement = self.Widget.CurrentListeningAction.Button
        local action = self.Widget.CurrentListeningAction.Action

        self.Widget.ListeningForInput = false
        self.Widget.CurrentListeningAction = nil
        self:UnregisterInputEvents()

        buttonElement.Label = self:GetBindingLabel(action)
        buttonElement.Disabled = false
    end
end

---Gets the display label for a binding (keyboard or mouse)
---@param action table The action containing binding data
---@return string The display label
function KeybindingV2IMGUIWidget:GetBindingLabel(action)
    if action.MouseBinding and action.MouseBinding.Button and action.MouseBinding.Button > 0 then
        return KeyPresentationMapping:GetMouseViewKey(action.MouseBinding)
            or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
    end
    return KeyPresentationMapping:GetKBViewKey(action.KeyboardMouseBinding)
        or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
end

---Gets the display label for a default binding (keyboard or mouse)
---@param action table The action containing default binding data
---@return string The display label
function KeybindingV2IMGUIWidget:GetDefaultBindingLabel(action)
    if action.DefaultMouseBinding and action.DefaultMouseBinding.Button and action.DefaultMouseBinding.Button > 0 then
        return KeyPresentationMapping:GetMouseViewKey(action.DefaultMouseBinding)
            or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
    end
    return KeyPresentationMapping:GetKBViewKey(action.DefaultKeyboardMouseBinding)
        or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
end

---Checks if a keybinding is set to its default value
---@param action table The action to check
---@return boolean True if the binding is set to its default value, false otherwise
function KeybindingV2IMGUIWidget:IsDefaultBinding(action)
    local kbEqual = KeybindingConflictService:AreKeybindingsEqual(action.KeyboardMouseBinding, action.DefaultKeyboardMouseBinding)
    local mouseEqual = self:AreMouseBindingsEqual(action.MouseBinding, action.DefaultMouseBinding)
    return kbEqual and mouseEqual
end

---Checks if two mouse bindings are equal
---@param binding1 table|nil The first mouse binding
---@param binding2 table|nil The second mouse binding
---@return boolean True if equal, false otherwise
function KeybindingV2IMGUIWidget:AreMouseBindingsEqual(binding1, binding2)
    if not binding1 and not binding2 then return true end
    if not binding1 or not binding2 then return false end

    local button1 = binding1.Button or 0
    local button2 = binding2.Button or 0
    if button1 ~= button2 then return false end

    local mods1 = binding1.ModifierKeys or {}
    local mods2 = binding2.ModifierKeys or {}
    if #mods1 ~= #mods2 then return false end

    for _, mod in ipairs(mods1) do
        if not table.contains(mods2, mod) then return false end
    end

    return true
end

---Compares two keybindings for equality after normalization
---@param binding1 Keybinding The first keybinding to compare
---@param binding2 Keybinding The second keybinding to compare
---@return boolean True if the keybindings are equal, false otherwise
function KeybindingV2IMGUIWidget:AreKeybindingsEqual(binding1, binding2)
    if binding1 == nil or binding2 == nil then
        return false
    end

    local normalized1 = KeybindingsRegistry.NormalizeKeyboardBinding(binding1)
    local normalized2 = KeybindingsRegistry.NormalizeKeyboardBinding(binding2)

    return normalized1 ~= nil and normalized1 == normalized2
end

---Checks if a keybinding conflicts with an existing action
---@param keybinding Keybinding The keybinding to check
---@param action table The action to check against
---@param actionId string The ID of the action to check
---@param currentActionId string The ID of the current action (to skip)
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingV2IMGUIWidget:CheckActionForConflict(keybinding, action, actionId, currentActionId)
    if actionId == currentActionId or not action.keyboardBinding or action.keyboardBinding == "" then
        return nil
    end

    if self:AreKeybindingsEqual(keybinding, action.keyboardBinding) then
        return { ActionName = action.actionName }
    end

    return nil
end

---Checks if a keybinding conflicts with any existing bindings in a mod
---@param keybinding Keybinding The keybinding to check
---@param actions table The actions to check against
---@param currentActionId string The ID of the current action (to skip)
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingV2IMGUIWidget:CheckModForConflicts(keybinding, actions, currentActionId)
    for actionId, action in pairs(actions) do
        local conflict = self:CheckActionForConflict(keybinding, action, actionId, currentActionId)
        if conflict then
            return conflict
        end
    end
    return nil
end

---Checks if a keybinding conflicts with existing bindings
---@param keybinding Keybinding The keybinding to check
---@param currentMod table The current mod data
---@param currentAction table The current action data
---@param inputType string The type of input ("KeyboardMouse")
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingV2IMGUIWidget:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    if inputType ~= "KeyboardMouse" then
        return nil
    end

    -- If no keybinding is assigned (e.g. using UNASSIGNED_KEYBOARD_MOUSE_STRING or nil),
    -- skip conflict detection entirely.
    if type(keybinding) ~= "table" or keybinding.Key == "" then
        return nil
    end

    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local currentActionId = currentAction.ActionId

    for _modUUID, actions in pairs(registry) do
        local conflict = self:CheckModForConflicts(keybinding, actions, currentActionId)
        if conflict then
            return conflict
        end
    end

    return nil
end

---Resets a binding to its default value
---@param modUUID string The UUID of the mod
---@param actionId string The ID of the action to reset
function KeybindingV2IMGUIWidget:ResetBinding(modUUID, actionId)
    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local binding = registry[modUUID] and registry[modUUID][actionId]
    if binding then
        local resetPayload

        if binding.defaultMouseBinding and binding.defaultMouseBinding.Button and binding.defaultMouseBinding.Button > 0 then
            resetPayload = KeybindingsRegistry.BuildMousePayload(binding.defaultMouseBinding, binding.defaultEnabled)
        else
            local resetKeybinding = binding.defaultKeyboardBinding
            resetPayload = KeybindingsRegistry.BuildKeyboardPayload(resetKeybinding, binding.defaultEnabled)
        end

        local success = KeybindingsRegistry.UpdateBinding(modUUID, actionId, resetPayload, true)
        if not success then
            MCMError(0,
                "Failed to reset binding for mod '" .. modUUID .. "', action '" .. actionId .. "'.")
            self:RefreshUI()
        end
    end
end

---Refreshes the UI to reflect the current state
function KeybindingV2IMGUIWidget:RefreshUI()
    self:RenderKeybindingTables()
end

---Clears all dynamically created UI elements
function KeybindingV2IMGUIWidget:ClearDynamicElements()
    for _, modHeader in ipairs(self.Widget.DynamicElements.ModHeaders) do
        modHeader:Destroy()
    end
    self.Widget.DynamicElements.ModHeaders = {}
    if self.Widget.DynamicElements.NoResultsText then
        self.Widget.DynamicElements.NoResultsText:Destroy()
        self.Widget.DynamicElements.NoResultsText = nil
    end
    if self.Widget.DynamicElements.ModPageHintText then
        self.Widget.DynamicElements.ModPageHintText:Destroy()
        self.Widget.DynamicElements.ModPageHintText = nil
    end
end

---Cleans up resources when the widget is destroyed
function KeybindingV2IMGUIWidget:Destroy()
    self:UnregisterInputEvents()
    self:ClearDynamicElements()
    if self._registrySubscription then
        self._registrySubscription:unsubscribe()
        self._registrySubscription = nil
    end
    self.Widget.Group:Destroy()
end

---Updates the current value (not used)
---@param value any The new value (unused)
function KeybindingV2IMGUIWidget:UpdateCurrentValue(value)
    -- Not used.
end

return KeybindingV2IMGUIWidget
