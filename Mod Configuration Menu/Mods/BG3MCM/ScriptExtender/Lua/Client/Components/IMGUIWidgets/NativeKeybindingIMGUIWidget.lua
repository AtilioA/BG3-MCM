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

--- Sorts categories by their translated names
---@param categories table List of category objects
---@return table Sorted list of categories with translated names
function NativeKeybindingIMGUIWidget:SortCategoriesByTranslatedName(categories)
    local sortedCategories = {}
    for _, category in ipairs(categories) do
        local catName = "Uncategorized"
        if category.CategoryName and category.CategoryName ~= "" then
            catName = NativeKeybindingsTranslator.GetCategoryString(category.CategoryName) or category.CategoryName
        end
        table.insert(sortedCategories, {
            original = category,
            translatedName = catName
        })
    end

    table.sort(sortedCategories, function(a, b)
        return VCString.NaturalOrderCompare(a.translatedName, b.translatedName)
    end)

    return sortedCategories
end

--- Sorts actions by their translated names
---@param actions table List of action objects
---@return table Sorted list of actions with display names
function NativeKeybindingIMGUIWidget:SortActionsByTranslatedName(actions)
    local sortedActions = {}
    for _, action in ipairs(actions) do
        table.insert(sortedActions, {
            action = action,
            displayName = action.ActionName and
                NativeKeybindingsTranslator.GetEventString(action.ActionName) or ""
        })
    end

    table.sort(sortedActions, function(a, b)
        return VCString.NaturalOrderCompare(a.displayName, b.displayName)
    end)

    return sortedActions
end

--- Renders the keybinding cell for an action
---@param cell any The IMGUI cell to render into
---@param action table The action to render bindings for
function NativeKeybindingIMGUIWidget:RenderKeybindingCell(cell, action)
    if not action.Bindings or #action.Bindings == 0 then
        -- Show unassigned state if no bindings at all
        local kbButton = cell:AddButton(ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING)
        kbButton.SameLine = false
        kbButton:SetColor("Button", Color.NormalizedRGBA(18, 18, 18, 1))
        kbButton:SetColor("Text", Color.HEXToRGBA("#777777"))
        kbButton.IDContext = "Native_KBMouse_" .. (action.ActionId or action.ActionName or "") .. "_unassigned"
        return
    end

    -- Render each binding
    local firstButton = true
    for i, binding in ipairs(action.Bindings) do
        local bindingText = ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING

        if binding.InputId then
            bindingText = KeyPresentationMapping:GetKBViewKey({
                Key = tostring(binding.InputId),
                ModifierKeys = binding.Modifiers
            })
        end

        -- Only add spacing if this isn't the first button
        if not firstButton then
            cell:AddDummy(0, 1)
        end

        local kbButton = cell:AddButton(bindingText)
        kbButton.SameLine = false
        kbButton:SetColor("Button", Color.NormalizedRGBA(18, 18, 18, 1))
        kbButton:SetColor("ButtonActive", Color.NormalizedRGBA(18, 18, 18, 1))
        kbButton:SetColor("ButtonHovered", Color.NormalizedRGBA(18, 18, 18, 1))
        kbButton.IDContext = string.format("Native_KBMouse_%s_%d",
            action.ActionId or action.ActionName or "", i)

        firstButton = false
    end
end

--- Renders a single category with its actions
---@param nativeHeader any The parent header to add the category to
---@param categoryItem table The category item to render
function NativeKeybindingIMGUIWidget:RenderCategory(nativeHeader, categoryItem)
    local category = categoryItem.original
    local catName = categoryItem.translatedName

    if not (category.Actions and #category.Actions > 0) then
        return
    end

    -- Add category header as a collapsible header
    local categoryHeader = nativeHeader:AddCollapsingHeader(catName)
    categoryHeader.DefaultOpen = false
    categoryHeader:AddDummy(5, 5)
    table.insert(self.Widget.DynamicElements.ModHeaders, categoryHeader)

    xpcall(function()
        -- Sort actions by translated names
        local sortedActions = self:SortActionsByTranslatedName(category.Actions)

        -- Create table for this category
        local imguiTable = categoryHeader:AddTable(catName .. "_table", 2)
        imguiTable.BordersOuter = true
        imguiTable.BordersInner = true
        imguiTable.RowBg = true

        -- Define the columns
        imguiTable:AddColumn("Action", "WidthStretch")
        imguiTable:AddColumn("Keybinding", "WidthStretch")

        -- Render sorted actions
        for _, item in ipairs(sortedActions) do
            local action = item.action
            local row = imguiTable:AddRow()

            -- Render action name cell
            local nameCell = row:AddCell()
            local nameText = nameCell:AddText(item.displayName)
            nameText:SetColor("Text", Color.HEXToRGBA("#EEEEEE"))

            if action.Description and action.Description ~= "" then
                local descriptionText = nameCell:AddText(action.Description)
                nameText.TextWrapPos = 0
                descriptionText.TextWrapPos = 0
                nameText.IDContext = "Native_ActionName_" .. (action.ActionId or action.ActionName or "")
                descriptionText.IDContext = "Native_ActionDesc_" .. (action.ActionId or action.ActionName or "")
            end

            -- Render keybinding cell
            local kbCell = row:AddCell()
            self:RenderKeybindingCell(kbCell, action)
        end
    end, function(err)
        if not categoryHeader then return end
        MCMError(0, "Error rendering category " .. tostring(catName) .. ": " .. tostring(err))
        local errorText = categoryHeader:AddText("Error: " .. tostring(err))
        errorText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    end)
end

--- Renders the native keybinding tables grouped by category
function NativeKeybindingIMGUIWidget:RenderKeybindingTables()
    local group = self.Widget.Group
    self:ClearDynamicElements()

    -- Get native keybindings
    local categories = KeybindingsUI.GetNativeKeybindings()

    -- Apply search filter if any
    if self.Widget.SearchText and self.Widget.SearchText ~= "" then
        categories = self:FilterCategories(categories)
    end

    -- Show message if no keybindings found
    if not categories or #categories == 0 then
        local msg = (self.Widget.SearchText and self.Widget.SearchText ~= "") and
            ("No native keybindings found for '" .. self.Widget.SearchText .. "'.") or
            "No native keybindings found."
        local noResults = group:AddText(msg)
        self.Widget.DynamicElements.NoResultsText = noResults
        return
    end

    -- Create a collapsible header for native keybindings
    local nativeHeader = group:AddCollapsingHeader("h692c5bc059d841ccba0bc66c92f5bb09e53g")
    nativeHeader.DefaultOpen = false
    nativeHeader:AddText("hef97155533604ba6adf42a09c666469c0c4c")
    table.insert(self.Widget.DynamicElements.ModHeaders, nativeHeader)

    -- Sort and render categories
    local sortedCategories = self:SortCategoriesByTranslatedName(categories)
    for _, categoryItem in ipairs(sortedCategories) do
        self:RenderCategory(nativeHeader, categoryItem)
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
