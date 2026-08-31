-- TODO: add another column to 'ignore conflicts'?

---@class KeybindingV2IMGUIWidget: IMGUIWidget
---@field Widget table
---@field _registrySubscription any
---@field _captureSession KeybindingCaptureSession|nil
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)

---@param action KeybindingUIAction
---@return KeybindingKeyboardBinding|KeybindingMouseBinding|nil
local function getActiveActionBinding(action)
    return KeybindingManager:GetActiveV2Binding({
        Keyboard = action.KeyboardMouseBinding,
        Mouse = action.MouseBinding
    })
end


---Creates a new instance of KeybindingV2IMGUIWidget
---@param group ExtuiGroup The IMGUI group to attach this widget to
---@return KeybindingV2IMGUIWidget
function KeybindingV2IMGUIWidget:new(group)
    ---@type KeybindingV2IMGUIWidget
    local instance = setmetatable({}, { __index = KeybindingV2IMGUIWidget })
    instance.Widget = {
        Group = group,
        SearchText = "",
        FilteredActions = {},
        CollapsedMods = {},
        DynamicElements = {
            ModHeaders = {},
            NoResultsText = nil,
            ModPageHintText = nil
        }
    }
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
        if instance._captureSession then return end
        instance:FilterActions()
        instance:RefreshUI()
    end)

    return instance
end

---Stores a keybinding in the registry
---@param modData KeybindingUIMod The mod data containing ModUUID and ModName
---@param action KeybindingUIAction The action data containing ActionId
---@param payload KeybindingV2Value The payload containing the keybinding data
---@return boolean success Whether the operation was successful
function KeybindingV2IMGUIWidget:StoreKeybinding(modData, action, payload)
    local success = KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, payload, true)
    if not success then
        MCMWarn(0,
            "Failed to update binding in registry for mod '%s', action '%s'. Please contact %s about this issue.",
            modData.ModName, action.ActionId, Ext.Mod.GetMod(ModuleUUID).Info.Author)
    end
    return success
end

---Builds a complete value for an action while changing its flags.
---@param action KeybindingUIAction
---@param enabled boolean
---@param allowConflict boolean
---@return KeybindingV2Value
function KeybindingV2IMGUIWidget:BuildActionValue(action, enabled, allowConflict)
    if KeybindingManager:IsMouseBindingAssigned(action.MouseBinding) then
        return KeybindingsRegistry.BuildMousePayload(action.MouseBinding, enabled, allowConflict)
    end
    return KeybindingsRegistry.BuildKeyboardPayload(
        action.KeyboardMouseBinding or { Key = "", ModifierKeys = {} }, enabled, allowConflict)
end

---Filters actions using the centralized registry based on the current search text
function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:upper()
    local registry = KeybindingsRegistry.GetFilteredRegistry()

    for modUUID, actions in pairs(registry) do
        local sortMode = actions._keybindingSortMode or KeybindingSortMode.DEFAULT
        local modName = MCMClientState:GetModName(modUUID)
        if not modName then
            MCMWarn(0, "Mod name not found for UUID: %s", modUUID)
            modName = "MISSING_NAME"
        end
        local filteredActions = {}
        for actionId, binding in pairs(actions) do
            if actionId ~= "_keybindingSortMode" then
                local matchesModName = VCString:FuzzyMatch(modName:upper(), searchText)
                local matchesActionName = VCString:FuzzyMatch(binding.actionName:upper(), searchText)
                local matchesTooltip = VCString:FuzzyMatch((binding.tooltip or ""):upper(), searchText)
                local matchesKeyboard = binding.keyboardBinding and binding.keyboardBinding.Key and
                    VCString:FuzzyMatch(binding.keyboardBinding.Key:upper(), searchText) and
                    binding.keyboardBinding.ModifierKeys
                local matchesPresentationKeyboard = binding.keyboardBinding and binding.keyboardBinding.Key and
                    VCString:FuzzyMatch(KeyPresentationMapping:GetKBViewKey(binding.keyboardBinding):upper(), searchText)
                local matchesMouse = binding.mouseBinding and binding.mouseBinding.Button and
                    VCString:FuzzyMatch(KeyPresentationMapping:GetMouseViewKey(binding.mouseBinding):upper(), searchText)
                if searchText == "" or matchesModName or matchesActionName or matchesKeyboard or matchesPresentationKeyboard or matchesMouse or matchesTooltip then
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
                        DefaultAllowConflict = binding.defaultAllowConflict,
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
        local sortMode = mod.KeybindingSortMode or KeybindingSortMode.DEFAULT
        if sortMode == KeybindingSortMode.BLUEPRINT then
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
---@param mod KeybindingUIMod The mod data containing actions to render
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
            local isDisabled = action.Enabled == false

            -- Enabled checkbox cell.
            local enabledCell = row:AddCell()
            local enabledCheckbox = enabledCell:AddCheckbox("")
            IMGUIHelpers:ApplyInputStyle(enabledCheckbox, "checkbox")
            IMGUIHelpers.AddTooltip(enabledCheckbox,
                Ext.Loca.GetTranslatedString(
                    "h6fd6de5f403d4d5b8a7ba0a8b353b97f7b09"),
                mod.ModName .. "_Enabled_" .. action.ActionId .. "_TOOLTIP")
            enabledCheckbox.Checked = action.Enabled ~= false
            enabledCheckbox.IDContext = mod.ModName .. "_Enabled_" .. action.ActionId
            enabledCheckbox.OnChange = function(checkbox)
                self:StoreKeybinding(mod, action,
                    self:BuildActionValue(action, checkbox.Checked, action.AllowConflict))
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
                if isDisabled then
                    self:ApplyDisabledStyle(descriptionText, row)
                end
            end

            if isDisabled then
                self:ApplyDisabledStyle(nameText, row)
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

            if isDisabled then
                self:ApplyDisabledStyle(kbButton, row)
            end

            -- AllowConflict checkbox cell.
            local conflictCell = row:AddCell()
            local conflictCheckbox = conflictCell:AddCheckbox(Ext.Loca.GetTranslatedString(
                "ha7dbcb7a64404859b1f9c8a6efa96b304d06"))
            IMGUIHelpers:ApplyInputStyle(conflictCheckbox, "checkbox")

            IMGUIHelpers.AddTooltip(conflictCheckbox,
                Ext.Loca.GetTranslatedString("h35a1d92d0e8e404f906a4b087020f9e6g3dg"),
                mod.ModName .. "_Conflict_" .. action.ActionId .. "_TOOLTIP")

            conflictCheckbox.Checked = action.AllowConflict == true
            conflictCheckbox.IDContext = mod.ModName .. "_Conflict_" .. action.ActionId
            conflictCheckbox.OnChange = function(checkbox)
                self:StoreKeybinding(mod, action,
                    self:BuildActionValue(action, action.Enabled, checkbox.Checked))
            end

            if isDisabled then
                self:ApplyDisabledStyle(conflictCheckbox, row)
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

            if isDisabled then
                self:ApplyDisabledStyle(resetButton, row)
            end

            -- If there is a conflict, color the keybinding button red and show conflict details
            -- Don't show red text if AllowConflict is enabled for this keybinding
            if not isDisabled then
                local conflictKB = KeybindingConflictService:CheckForConflicts(getActiveActionBinding(action), mod, action,
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
        end
    end, function(err)
        if not modGroup or not err then return end

        MCMError(0, "Error in RenderKeybindingTable: %s", err)

        local errorText = modGroup:AddText(VCString:InterpolateLocalizedMessage("hd8524a99cb1f41059b7e2aa9c543e68ad7g7",
            err))
        errorText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    end)
end

---Starts one keyboard or mouse capture session.
---@param mod KeybindingUIMod
---@param action KeybindingUIAction
---@param inputType string
---@param button ExtuiButton
function KeybindingV2IMGUIWidget:StartListeningForInput(mod, action, inputType, button)
    if self._captureSession or KeybindingCaptureSession.IsActive() then return end

    local session
    session = KeybindingCaptureSession.Start({
        OnComplete = function(outcome)
            if self._captureSession ~= session then return end
            self._captureSession = nil

            if outcome.kind == "binding" and outcome.binding then
                local binding = outcome.binding
                self:NotifyAssignmentConflict(binding, mod, action, inputType)
                local registryAction = getRegistryAction({ Mod = mod, Action = action })
                local enabled = registryAction and registryAction.enabled
                if enabled == nil then enabled = action.Enabled end
                local allowConflict = registryAction and registryAction.allowConflict
                if allowConflict == nil then allowConflict = action.AllowConflict end
                local payload = binding.Button
                    and KeybindingsRegistry.BuildMousePayload(binding, enabled, allowConflict)
                    or KeybindingsRegistry.BuildKeyboardPayload(binding, enabled, allowConflict)
                self:StoreKeybinding(mod, action, payload)
            end

            if outcome.reason ~= "destroyed" then
                self:FilterActions()
                self:RefreshUI()
            end
        end
    })
    if not session then return end

    self._captureSession = session
    button.Label = ClientGlobals.LISTENING_INPUT_STRING
    button.Disabled = true
end

---Cancels this widget's active capture session.
function KeybindingV2IMGUIWidget:CancelKeybinding()
    if self._captureSession then self._captureSession:Cancel("cancelled") end
end

---Resolves the live registry entry for the action being captured, if any. Capture must read `enabled`/`allowConflict` from the registry
---@param current table|nil
---@return KeybindingRegistryEntry|nil
local function getRegistryAction(current)
    if not current or not current.Mod or not current.Action then return nil end
    local modRegistry = KeybindingsRegistry.GetRegistry()[current.Mod.ModUUID]
    return modRegistry and modRegistry[current.Action.ActionId]
end

---Warns when a newly selected combo exactly conflicts with another action.
---@param binding KeybindingKeyboardBinding|KeybindingMouseBinding
---@param modData KeybindingUIMod
---@param action KeybindingUIAction
---@param inputType string
function KeybindingV2IMGUIWidget:NotifyAssignmentConflict(binding, modData, action, inputType)
    local registryAction = KeybindingsRegistry.GetRegistry()[modData.ModUUID]
        and KeybindingsRegistry.GetRegistry()[modData.ModUUID][action.ActionId]
    local effectiveAction = {
        ActionId = action.ActionId,
        ActionName = action.ActionName,
        AllowConflict = registryAction and registryAction.allowConflict or false
    }
    local conflictAction = KeybindingConflictService:CheckForConflicts(binding, modData, effectiveAction, inputType)
    if not conflictAction then return end
    local conflictTitle = VCString:InterpolateLocalizedMessage("hac5a1fd7d223410b8a5fab04951eb428adde",
        action.ActionName)
    local conflictStr = VCString:InterpolateLocalizedMessage("h0f52923132fa41c1a269a7eb647068d8d2ee",
        KeyPresentationMapping:GetKBViewKey(binding) or "", action.ActionName, conflictAction.ActionName)
    KeybindingsRegistry.NotifyConflict(conflictTitle, conflictStr)
end

---Gets the display label for a binding (keyboard or mouse)
---@param action table The action containing binding data
---@return string The display label
function KeybindingV2IMGUIWidget:GetBindingLabel(action)
    if KeybindingManager:IsMouseBindingAssigned(action.MouseBinding) then
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
    if KeybindingManager:IsMouseBindingAssigned(action.DefaultMouseBinding) then
        return KeyPresentationMapping:GetMouseViewKey(action.DefaultMouseBinding)
            or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
    end
    return KeyPresentationMapping:GetKBViewKey(action.DefaultKeyboardMouseBinding)
        or ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING
end

---Checks if a keybinding is set to its default value.
---@param action table The action to check
---@return boolean True if the binding is set to its default value, false otherwise
function KeybindingV2IMGUIWidget:IsDefaultBinding(action)
    local currentValue = {
        Keyboard = action.KeyboardMouseBinding,
        Mouse = action.MouseBinding
    }
    local defaultValue = {
        Keyboard = action.DefaultKeyboardMouseBinding,
        Mouse = action.DefaultMouseBinding
    }
    return KeybindingManager:AreBindingsEqual(currentValue, defaultValue)
        and action.Enabled == action.DefaultEnabled
        and action.AllowConflict == action.DefaultAllowConflict
end

---Resets a binding to its default value
---@param modUUID string The UUID of the mod
---@param actionId string The ID of the action to reset
function KeybindingV2IMGUIWidget:ResetBinding(modUUID, actionId)
    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local binding = registry[modUUID] and registry[modUUID][actionId]
    if binding then
        local resetPayload

        if KeybindingManager:IsMouseBindingAssigned(binding.defaultMouseBinding) then
            resetPayload = KeybindingsRegistry.BuildMousePayload(binding.defaultMouseBinding, binding.defaultEnabled,
                binding.defaultAllowConflict)
        else
            local resetKeybinding = binding.defaultKeyboardBinding
            resetPayload = KeybindingsRegistry.BuildKeyboardPayload(resetKeybinding, binding.defaultEnabled,
                binding.defaultAllowConflict)
        end

        local success = KeybindingsRegistry.UpdateBinding(modUUID, actionId, resetPayload, true)
        if not success then
            MCMError(0, "Failed to reset binding for mod '%s', action '%s'.", modUUID, actionId)
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
    if self._captureSession then self._captureSession:Cancel("destroyed") end
    self:ClearDynamicElements()
    if self._registrySubscription then
        self._registrySubscription:Unsubscribe()
        self._registrySubscription = nil
    end
    if self._searchSubscription then
        self._searchSubscription:Unsubscribe()
        self._searchSubscription = nil
    end
    self.Widget.Group:Destroy()
end

---Updates the current value (not used)
---@param value unknown The new value (unused)
function KeybindingV2IMGUIWidget:UpdateCurrentValue(value)
    -- Not used.
end

function KeybindingV2IMGUIWidget:ApplyDisabledStyle(element, row)
    element:SetColor("Text", Color.NormalizedRGBA(140, 140, 140, 1))
    if row then
        row:SetColor("TableRowBg", Color.NormalizedRGBA(50, 50, 50, 1))
        row:SetColor("TableRowBgAlt", Color.NormalizedRGBA(50, 50, 50, 1))
    end
end

return KeybindingV2IMGUIWidget
