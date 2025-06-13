---@class NativeKeybindingIMGUIWidget: IMGUIWidget
NativeKeybindingIMGUIWidget = _Class:Create("NativeKeybindingIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup The IMGUI group to attach this widget to
---@return NativeKeybindingIMGUIWidget
function NativeKeybindingIMGUIWidget:new(group)
    local instance = setmetatable({}, { __index = NativeKeybindingIMGUIWidget })
    instance.Widget = {
        Group = group,
        DynamicElements = { ModHeaders = {}, NoResultsText = nil }
    }
    -- subscribe to search subject for dynamic filtering
    instance.Widget.SearchText = ""
    if KeybindingsUI.SearchBar and KeybindingsUI.SearchBar.SearchSubject then
        instance._searchSubscription = KeybindingsUI.SearchBar.SearchSubject:Subscribe(function(searchText)
            instance.Widget.SearchText = searchText
            instance:RefreshUI()
        end)
    end
    return instance
end

--- Clears dynamically created UI elements
function NativeKeybindingIMGUIWidget:ClearDynamicElements()
    if not self.Widget or not self.Widget.DynamicElements then
        return
    end
    local headers = self.Widget.DynamicElements.ModHeaders or {}
    local noResults = self.Widget.DynamicElements.NoResultsText
    -- Reset dynamic lists to avoid reentrancy
    self.Widget.DynamicElements.ModHeaders = {}
    self.Widget.DynamicElements.NoResultsText = nil
    -- Destroy headers silently
    for _, header in ipairs(headers) do
        pcall(function() header:Destroy() end)
    end
    -- Destroy no-results text silently
    if noResults then
        pcall(function() noResults:Destroy() end)
    end
end

--- Refreshes the UI to reflect current state
function NativeKeybindingIMGUIWidget:RefreshUI()
    self:RenderKeybindingTables()
end

--- Renders the native keybinding tables grouped by category
function NativeKeybindingIMGUIWidget:RenderKeybindingTables()
    local group = self.Widget.Group
    -- group:AddDummy(0, 5)
    self:ClearDynamicElements()

    -- get native keybindings
    local categories = KeybindingsUI.GetNativeKeybindings()
    -- apply search filter from KeybindingV2IMGUIWidget
    if self.Widget.SearchText and self.Widget.SearchText ~= "" then
        categories = self:FilterCategories(categories)
    end
    if not categories or #categories == 0 then
        local msg = (self.Widget.SearchText and self.Widget.SearchText ~= "") and
            ("No native keybindings found for '" .. self.Widget.SearchText .. "'.") or
            "No native keybindings found."
        local noResults = group:AddText(msg)
        self.Widget.DynamicElements.NoResultsText = noResults
        return
    end

    -- create a collapsible header for native keybindings
    local nativeHeader = group:AddCollapsingHeader("Vanilla keybindings")
    nativeHeader.DefaultOpen = false
    nativeHeader:AddText("Vanilla/Native keybindings are read-only and will not update when you change them in-game.")
    table.insert(self.Widget.DynamicElements.ModHeaders, nativeHeader)

    -- process each category under the collapse header
    for _, category in ipairs(categories) do
        if category.Actions and #category.Actions > 0 then
            -- determine display name
            local catName = (category.CategoryName and category.CategoryName ~= "") and category.CategoryName or
                "Uncategorized"

            -- add category header as a collapsible header
            local categoryHeader = nativeHeader:AddCollapsingHeader(catName)
            categoryHeader.DefaultOpen = false
            categoryHeader:AddDummy(5, 5)
            table.insert(self.Widget.DynamicElements.ModHeaders, categoryHeader)

            xpcall(function()
                -- create table for this category
                local imguiTable = categoryHeader:AddTable(catName .. "_table", 2)
                imguiTable.BordersOuter = true
                imguiTable.BordersInner = true
                imguiTable.RowBg = true

                -- Define the columns
                -- imguiTable:AddColumn("Enabled", "WidthFixed", 100)
                imguiTable:AddColumn("Action", "WidthStretch")
                imguiTable:AddColumn("Keybinding", "WidthStretch")

                for _, action in ipairs(category.Actions) do
                    local row = imguiTable:AddRow()

                    -- Enabled checkbox cell (TODO: allow ignoring conflict)
                    -- local enabledCell = row:AddCell()
                    -- local enabledCheckbox = enabledCell:AddCheckbox("")
                    -- enabledCheckbox.Checked = true
                    -- enabledCheckbox.IDContext = "Native_Enabled_" .. (action.ActionId or action.ActionName or "")

                    -- Action Name cell
                    local nameCell = row:AddCell()
                    local nameText = nameCell:AddText(action.ActionName or "")
                    nameText:SetColor("Text", Color.HEXToRGBA("#EEEEEE"))

                    if action.Description and action.Description ~= "" then
                        local descriptionText = nameCell:AddText(action.Description)
                        nameText.TextWrapPos = 0
                        descriptionText.TextWrapPos = 0
                        nameText.IDContext = "Native_ActionName_" .. (action.ActionId or action.ActionName or "")
                        descriptionText.IDContext = "Native_ActionDesc_" .. (action.ActionId or action.ActionName or "")
                    end

                    -- Keybinding cell
                    local kbCell = row:AddCell()

                    -- Format bindings
                    local bindingText = UNASSIGNED_KEYBOARD_MOUSE_STRING or "Unassigned"
                    if action.Bindings and #action.Bindings > 0 then
                        local bindingStrings = {}
                        for _, binding in ipairs(action.Bindings) do
                            if binding.InputId then
                                table.insert(bindingStrings,
                                    KeyPresentationMapping:GetKBViewKey({
                                        Key = tostring(binding.InputId),
                                        ModifierKeys = binding.Modifiers
                                    }))
                            end
                        end
                        if #bindingStrings > 0 then
                            bindingText = table.concat(bindingStrings, ", ")
                        end
                    end

                    local kbButton = kbCell:AddButton(bindingText)
                    kbButton:SetColor("Button", Color.NormalizedRGBA(18, 18, 18, 1))
                    kbButton:SetColor("ButtonActive", Color.NormalizedRGBA(18, 18, 18, 1))
                    kbButton:SetColor("ButtonHovered", Color.NormalizedRGBA(18, 18, 18, 1))
                    kbButton.IDContext = "Native_KBMouse_" .. (action.ActionId or action.ActionName or "")
                end
            end, function(err)
                if not categoryHeader then return end
                MCMError(0, "Error in RenderKeybindingTables: " .. tostring(err))
                local errorText = categoryHeader:AddText("Error in RenderKeybindingTables: " .. tostring(err))
                errorText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
            end)
        end
    end

    -- group:AddDummy(0, 5)

    -- group:AddSeparator()
end

--- filters native categories based on search text
function NativeKeybindingIMGUIWidget:FilterCategories(categories)
    local filtered = {}
    local searchText = (self.Widget.SearchText or ""):upper()
    for _, category in ipairs(categories) do
        local catNameUp = (category.CategoryName or ""):upper()
        if VCString:FuzzyMatch(catNameUp, searchText) then
            table.insert(filtered, category)
        else
            local filteredActions = {}
            for _, action in ipairs(category.Actions) do
                local nameUp = (action.ActionName or ""):upper()
                local idUp = (action.ActionId or ""):upper()
                local matchesName = VCString:FuzzyMatch(nameUp, searchText)
                local matchesId = VCString:FuzzyMatch(idUp, searchText)
                local matchesBinding = false
                if action.Bindings then
                    for _, b in ipairs(action.Bindings) do
                        matchesBinding = matchesBinding or
                            VCString:FuzzyMatch((tostring(b.InputId) or ""):upper(), searchText)
                    end
                end
                if matchesName or matchesId or matchesBinding then
                    table.insert(filteredActions, action)
                end
            end
            if #filteredActions > 0 then
                table.insert(filtered, { CategoryName = category.CategoryName, Actions = filteredActions })
            end
        end
    end
    return filtered
end

return NativeKeybindingIMGUIWidget
