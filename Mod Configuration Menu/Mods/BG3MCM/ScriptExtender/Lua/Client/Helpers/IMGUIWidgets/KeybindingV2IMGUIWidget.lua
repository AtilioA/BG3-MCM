---@class KeybindingV2IMGUIWidget: IMGUIWidget
KeybindingV2IMGUIWidget = _Class:Create("KeybindingV2IMGUIWidget", IMGUIWidget)

LISTENING_INPUT_STRING = Ext.Loca.GetTranslatedString("h2ea690497b1a4ffea4b2ed480df3654c486f")
UNASSIGNED_KEYBOARD_MOUSE_STRING = Ext.Loca.GetTranslatedString("h08c75c996813442bb40fa085f1ecec07f14e")

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

function KeybindingV2IMGUIWidget:StoreKeybinding(modData, action, payload)
    local success = KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, payload)
    if not success then
        MCMWarn(0,
            "Failed to update binding in registry for mod '" ..
            modData.ModName .. "', action '" .. action.ActionId .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    end
    return success
end

-- Filters actions using the centralized registry.
function KeybindingV2IMGUIWidget:FilterActions()
    local filteredMods = {}
    local searchText = self.Widget.SearchText:upper()
    local registry = KeybindingsRegistry.GetRegistry()

    for modUUID, actions in pairs(registry) do
        local modName = MCMClientState:GetModName(modUUID)
        local filteredActions = {}
        for actionId, binding in pairs(actions) do
            local matchesModName = VCString:FuzzyMatch(modName:upper(), searchText)
            local matchesActionName = VCString:FuzzyMatch(binding.actionName:upper(), searchText)
            -- local matchesDescription = VCString:FuzzyMatch(binding.description:upper(), searchText)
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
                    KeyboardMouseBinding = binding.keyboardBinding or UNASSIGNED_KEYBOARD_MOUSE_STRING,
                    DefaultKeyboardMouseBinding = binding.defaultKeyboardBinding,
                    Description = binding.description,
                    Tooltip = binding.tooltip
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
        group:AddText(Ext.Loca.GetTranslatedString("h2f1eda98ddb949d09792e1e1bc45ecddg446"))
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
        local noResultsText = group:AddText(Ext.Loca.GetTranslatedString("h7e9b6453340548c29a8f3add8a402bedbe8g"))
        self.Widget.DynamicElements.NoResultsText = noResultsText
        return
    end

    for _, mod in ipairs(self.Widget.FilteredActions) do
        -- TODO: fetch name elsewhere
        local modHeader = group:AddCollapsingHeader(MCMClientState:GetModName(mod.ModUUID))
        modHeader.DefaultOpen = true
        modHeader.IDContext = mod.ModName .. "_CollapsingHeader"
        self:RenderKeybindingTable(modHeader, mod)
        table.insert(self.Widget.DynamicElements.ModHeaders, modHeader)
    end
end

function KeybindingV2IMGUIWidget:RenderKeybindingTable(modGroup, mod)
    local columns = 4 -- Changed from 3 to 5 to add the enabled column.
    local imguiTable = modGroup:AddTable("", columns)
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    -- Define the columns: Enabled, Action, Description, Keybinding, and Reset.
    imguiTable:AddColumn("Enabled", "WidthFixed", 100)
    imguiTable:AddColumn("Action", "WidthFixed", 700)
    imguiTable:AddColumn("Keybinding", "WidthFixed", 600)
    imguiTable:AddColumn("Reset", "WidthFixed", 100)

    for _, action in ipairs(mod.Actions) do
        local row = imguiTable:AddRow()

        -- Enabled checkbox cell.
        local enabledCell = row:AddCell()
        local enabledCheckbox = enabledCell:AddCheckbox("")
        MCMRendering:AddTooltip(enabledCheckbox,
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
                Enabled = checkbox.Checked
            })
            self:RefreshUI()
        end

        -- Action Name cell.
        local nameCell = row:AddCell()
        local nameText = nameCell:AddText(action.ActionName)
        nameText:SetColor("Text", Color.HEXToRGBA("#EEEEEE"))
        local descriptionText = nameCell:AddText(VCString:ReplaceBrWithNewlines(action.Description))
        nameText.TextWrapPos = 0
        descriptionText.TextWrapPos = 0
        nameText.IDContext = mod.ModName .. "_ActionName_" .. action.ActionId
        descriptionText.IDContext = mod.ModName .. "_ActionDesc_" .. action.ActionId
        MCMRendering:AddTooltip(nameText,
            VCString:ReplaceBrWithNewlines(action.Tooltip ~= "" and action.Tooltip or action.Description),
            mod.ModName .. "_ActionName_" .. action.ActionId .. "_TOOLTIP")


        -- Keybinding cell.
        local kbCell = row:AddCell()
        local kbButton = kbCell:AddButton(KeyPresentationMapping:GetKBViewKey(action.KeyboardMouseBinding) or
            UNASSIGNED_KEYBOARD_MOUSE_STRING)
        kbButton.IDContext = mod.ModName .. "_KBMouse_" .. action.ActionId
        kbButton.OnClick = function()
            self:StartListeningForInput(mod, action, "KeyboardMouse", kbButton)
        end
        MCMRendering:AddTooltip(kbButton, Ext.Loca.GetTranslatedString("h232887313a904f9b8a0818632bb3a418ad0e"),
            mod.ModName .. "_KBMouse_" .. action.ActionId .. "_TOOLTIP")

        -- Reset button cell.
        local resetCell = row:AddCell()
        local resetButton = resetCell:AddButton(Ext.Loca.GetTranslatedString("hf6cf844cd5fb40d3aca640d5584ed6d47459"))
        resetButton.IDContext = mod.ModName .. "_Reset_" .. action.ActionId
        resetButton.OnClick = function()
            self:ResetBinding(mod.ModUUID, action.ActionId)
        end
        MCMRendering:AddTooltip(resetButton, Ext.Loca.GetTranslatedString("h497bb04f93734d52a265956df140e77a7add"),
            mod.ModName .. "_Reset_" .. action.ActionId .. "_TOOLTIP")

        -- If there is a conflict, color the keybinding button red.
        local conflictKB = self:CheckForConflicts(action.KeyboardMouseBinding, mod, action, "KeyboardMouse")
        if conflictKB then
            kbButton:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
        end
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
end

function KeybindingV2IMGUIWidget:HandleKeyInput(e)
    if not self.Widget.ListeningForInput then
        return
    end

    if KeybindingManager:ShouldPreventAction(e) then
        e:PreventAction()
        e:StopPropagation()
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

            KeybindingsRegistry.UpdateBinding(modData.ModUUID, action.ActionId, { Keyboard = "" })
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
        local keybindingStr = KeyPresentationMapping:GetKBViewKey(keybinding) or ""
        KeybindingsRegistry.NotifyConflict(keybindingStr)
    end

    local registry = KeybindingsRegistry.GetRegistry()
    local currentBinding = (registry[modData.ModUUID] and registry[modData.ModUUID][action.ActionId]) or {}

    local newPayload = KeybindingsRegistry.BuildKeyboardPayload(keybinding, currentBinding.Enabled)

    xpcall(function()
        if self:StoreKeybinding(modData, action, newPayload) then
            if inputType == "KeyboardMouse" and type(keybinding) == "table" and buttonElement then
                buttonElement.Label = KeyPresentationMapping:GetKBViewKey(keybinding) or UNASSIGNED_KEYBOARD_MOUSE_STRING
            else
                buttonElement.Label = UNASSIGNED_KEYBOARD_MOUSE_STRING
            end
            buttonElement.Disabled = false
        else
            MCMError(0, "Failed to update binding in registry for mod '" ..
                modData.ModName .. "', action '" .. action.ActionId .. "'.")
        end
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
        end
        buttonElement.Disabled = false
    end
end

function KeybindingV2IMGUIWidget:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    local registry = KeybindingsRegistry.GetRegistry()
    local _currentModUUID = currentMod.ModUUID
    local currentActionId = currentAction.ActionId
    local isKeyboardMouse = (inputType == "KeyboardMouse")
    local normalizedNewBinding

    if isKeyboardMouse then
        normalizedNewBinding = KeybindingsRegistry.NormalizeKeyboardBinding(keybinding)
    else
        return nil
    end

    for _modUUID, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if actionId ~= currentActionId then
                if isKeyboardMouse then
                    local existing = binding.keyboardBinding
                    if existing and existing ~= "" then
                        local normalizedExisting = KeybindingsRegistry.NormalizeKeyboardBinding(existing)
                        if normalizedExisting and normalizedExisting == normalizedNewBinding then
                            return { ActionName = binding.actionName }
                        end
                    end
                end
            end
        end
    end

    return nil
end

function KeybindingV2IMGUIWidget:ResetBinding(modUUID, actionId)
    local registry = KeybindingsRegistry.GetRegistry()
    local binding = registry[modUUID] and registry[modUUID][actionId]
    if binding then
        local resetKeybinding = binding.defaultKeyboardBinding
        local resetPayload = KeybindingsRegistry.BuildKeyboardPayload(resetKeybinding, binding.defaultEnabled)
        local success = KeybindingsRegistry.UpdateBinding(modUUID, actionId, resetPayload)
        if not success then
            MCMError(0,
                "Failed to reset binding for mod '" .. modUUID .. "', action '" .. actionId .. "'. Please contact " ..
                Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
            self:RefreshUI()
        end
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
