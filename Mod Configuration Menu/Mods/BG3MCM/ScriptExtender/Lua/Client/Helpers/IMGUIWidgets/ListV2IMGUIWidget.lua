---@class ListV2IMGUIWidget: IMGUIWidget
ListV2IMGUIWidget = _Class:Create("ListV2IMGUIWidget", IMGUIWidget)

function ListV2IMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = ListV2IMGUIWidget })
    instance.Widget = {}
    instance.Widget.Group = group
    instance.Widget.modUUID = modUUID
    instance.Widget.Setting = setting

    initialValue = initialValue or {}
    instance.Widget.Enabled = initialValue.enabled ~= false
    instance.Widget.Elements = initialValue.elements or {}

    instance.Widget.PageSize = (setting.Options and setting.Options.PageSize) or 10
    if instance.Widget.PageSize < 5 then instance.Widget.PageSize = 5 end
    instance.Widget.ShowSearchBar = (setting.Options and setting.Options.ShowSearchBar) ~= false

    instance.Widget.CurrentPage = 1
    instance.Widget.FilteredElements = {}
    instance.Widget.SearchText = ""

    -- Add groups
    instance.Widget.HeaderGroup = group:AddGroup("ListHeaderGroup_" .. setting.Id)
    instance.Widget.TableGroup = group:AddGroup("ListTableGroup_" .. setting.Id)
    instance.Widget.InputGroup = group:AddGroup("ListInputGroup_" .. setting.Id)

    instance:FilterElements()
    instance:RenderHeader()
    instance:RenderList()
    instance:AddInputAndAddButton()

    return instance
end

function ListV2IMGUIWidget:RenderHeader()
    local headerGroup = self.Widget.HeaderGroup

    -- Enable/disable entire list
    local enabledCheckbox = headerGroup:AddCheckbox("Enable list")
    enabledCheckbox:Tooltip():AddText(
        "Check to enable the list, uncheck to disable it, without removing/disabling any elements.")
    enabledCheckbox.Checked = self.Widget.Enabled
    enabledCheckbox.OnChange = function(checkbox)
        self.Widget.Enabled = checkbox.Checked
        local settingValue = {
            enabled = self.Widget.Enabled,
            elements = self.Widget.Elements
        }
        IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)
        self:Refresh()
    end
    enabledCheckbox.SameLine = false

    -- Search
    if self.Widget.ShowSearchBar then
        headerGroup:AddSpacing()
        headerGroup:AddText("Search by name:")
        if not self.Widget.SearchInput then
            self.Widget.SearchInput = headerGroup:AddInputText("", self.Widget.SearchText)
            self.Widget.SearchInput.OnChange = function(input)
                self.Widget.SearchText = input.Text
                self:FilterElements()
                self:RefreshList()
            end
            self.Widget.SearchInput.AutoSelectAll = true
            self.Widget.SearchInput.SameLine = true
        else
            self.Widget.SearchInput.Text = self.Widget.SearchText
        end
    end
end

function ListV2IMGUIWidget:ShowDeleteAllConfirmationPopup()
    -- Check if the popup group exists and destroy it if it does
    xpcall(function()
        if self.Widget.ConfirmationPopup then
            self.Widget.ConfirmationPopup:Destroy()
        end
    end, function(err) end)

    -- Create a new group for popup confirmation
    self.Widget.ConfirmationPopup = self.Widget.Group:AddPopup("ConfirmDeleteAllPopup")
    local text = self.Widget.ConfirmationPopup:AddText("Are you sure you want to delete all elements?")
    text:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    local confirmButton = self.Widget.ConfirmationPopup:AddButton("Yes")
    confirmButton.OnClick = function()
        self.Widget.Elements = {}
        local settingValue = {
            enabled = self.Widget.Enabled,
            elements = self.Widget.Elements
        }
        IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)
        self:FilterElements()
        self:Refresh()
        self.Widget.ConfirmationPopup:Destroy()
    end
    local cancelButton = self.Widget.ConfirmationPopup:AddButton("No")
    cancelButton.OnClick = function()
        self.Widget.ConfirmationPopup:Destroy()
    end
    self.Widget.ConfirmationPopup:Open()
end

function ListV2IMGUIWidget:FilterElements()
    local filtered = {}
    local searchText = self.Widget.SearchText:lower()

    for i, value in ipairs(self.Widget.Elements) do
        if searchText == "" or value.name:lower():find(searchText, 1, true) then
            table.insert(filtered, { element = value, indexInElements = i })
        end
    end

    self.Widget.FilteredElements = filtered
end

function ListV2IMGUIWidget:RenderList()
    local tableGroup = self.Widget.TableGroup
    local elements = self.Widget.FilteredElements

    local pageSize = self.Widget.PageSize
    local totalElements = #elements
    local totalPages = math.ceil(totalElements / pageSize)
    if totalPages == 0 then totalPages = 1 end
    local currentPage = self.Widget.CurrentPage
    if currentPage > totalPages then currentPage = totalPages end

    local columns = 4
    local imguiTable = tableGroup:AddTable("", columns)
    imguiTable.Sortable = true
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    -- Define the columns with their respective flags
    imguiTable:AddColumn("Enabled", "WidthFixed", IMGUIWidget:GetIconSizes()[0])
    imguiTable:AddColumn("Up/down", "WidthFixed", IMGUIWidget:GetIconSizes()[0]) -- Move Up/Down
    imguiTable:AddColumn("Name", "WidthStretch")
    imguiTable:AddColumn("Remove", "WidthFixed", IMGUIWidget:GetIconSizes()[0])  -- Move Up/Down

    -- Add a header row for the columns
    local headerRow = imguiTable:AddRow()
    headerRow:AddCell():AddText("Enabled")
    headerRow:AddCell():AddText("Move")
    headerRow:AddCell():AddText("Name")
    headerRow:AddCell():AddText("Remove")

    -- TODO: Handle sorting somehow

    for i = (currentPage - 1) * pageSize + 1, math.min(currentPage * pageSize, totalElements) do
        local entry = elements[i]
        local element = entry.element
        local indexInElements = entry.indexInElements

        local tableRow = imguiTable:AddRow()

        -- Enable/disable checkbox
        local checkboxCell = tableRow:AddCell()
        local enabledCheckbox = checkboxCell:AddCheckbox("")
        enabledCheckbox.Checked = element.enabled ~= false
        enabledCheckbox.OnChange = function(checkbox)
            element.enabled = checkbox.Checked
            local settingValue = {
                enabled = self.Widget.Enabled,
                elements = self.Widget.Elements
            }
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)
            self:RefreshList()
        end

        if element.enabled then
            enabledCheckbox:Tooltip():AddText("Click to disable '" ..
                element.name .. "' (without removing it from the list)")
        else
            enabledCheckbox:Tooltip():AddText("Click to enable '" ..
                element.name .. "' (without removing it from the list)")
        end

        -- Move up button
        local moveUpCell = tableRow:AddCell()
        local moveUpButton = moveUpCell:AddImageButton("", "panner_up_h", IMGUIWidget:GetIconSizes())
        if not moveUpButton.Image or moveUpButton.Image.Icon == "" then
            moveUpButton:Destroy()
            moveUpButton = moveUpCell:AddButton("Up")
        end
        moveUpButton.OnClick = function()
            self:MoveElement(indexInElements, -1)
        end
        local tooltipUp = moveUpButton:Tooltip()
        tooltipUp:AddText("Move '" .. element.name .. "' up in the list")

        -- Move down button
        -- local moveDownCell = tableRow:AddCell()
        local moveDownButton = moveUpCell:AddImageButton("", "panner_down_h", IMGUIWidget:GetIconSizes())
        if not moveDownButton.Image or moveDownButton.Image.Icon == "" then
            moveDownButton:Destroy()
            moveDownButton = moveUpCell:AddButton("Down")
        end
        moveDownButton.OnClick = function()
            self:MoveElement(indexInElements, 1)
        end
        local tooltipDown = moveDownButton:Tooltip()
        tooltipDown:AddText("Move '" .. element.name .. "' down in the list")

        -- Name text
        local nameCell = tableRow:AddCell()
        local nameText = nameCell:AddText(element.name)

        -- Remove button
        local removeCell = tableRow:AddCell()
        local removeButton = removeCell:AddImageButton("", "popin_closeIco_d", IMGUIWidget:GetIconSizes())
        if not removeButton.Image or removeButton.Image.Icon == "" then
            removeButton:Destroy()
            removeButton = removeCell:AddButton("Remove")
        end
        removeButton.OnClick = function()
            table.remove(self.Widget.Elements, indexInElements)
            local settingValue = {
                enabled = self.Widget.Enabled,
                elements = self.Widget.Elements
            }
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)
            self:FilterElements()
            self:Refresh()
        end
        local tooltipRemove = removeButton:Tooltip()
        tooltipRemove:AddText("Remove '" .. element.name .. "' from the list")
    end

    -- Pagination controls after the table
    local paginationGroup = tableGroup:AddGroup("PaginationGroup")
    paginationGroup:AddSpacing()
    if totalPages > 1 then
        local prevButton = paginationGroup:AddImageButton("<", "input_slider_arrowL_d", IMGUIWidget:GetIconSizes())
        if not prevButton.Image or prevButton.Image.Icon == "" then
            prevButton:Destroy()
            prevButton = paginationGroup:AddButton("<")
        end
        prevButton.OnClick = function()
            if self.Widget.CurrentPage > 1 then
                self.Widget.CurrentPage = self.Widget.CurrentPage - 1
                self:Refresh()
            end
        end
        prevButton.SameLine = true

        local function getPageText(widget)
            local isFiltered = widget.SearchText and widget.SearchText ~= ""
            local totalElementCount = isFiltered and #widget.FilteredElements or #widget.Elements
            local currentElementCount = math.min(widget.CurrentPage * widget.PageSize, totalElementCount)
            local filterText = isFiltered and " (filtered)" or ""
            totalPages = math.ceil(totalElementCount / widget.PageSize)
            widget.CurrentPage = math.min(widget.CurrentPage, totalPages)

            return string.format(
                "Page %d of %d%s | %d/%d elements",
                widget.CurrentPage,
                totalPages,
                filterText,
                currentElementCount,
                totalElementCount
            )
        end

        local pageText = paginationGroup:AddText(getPageText(self.Widget))
        pageText.SameLine = true

        local nextButton = paginationGroup:AddImageButton(">", "input_slider_arrowR_d", IMGUIWidget:GetIconSizes())
        if not nextButton.Image or nextButton.Image.Icon == "" then
            nextButton:Destroy()
            nextButton = paginationGroup:AddButton(">")
        end
        nextButton.OnClick = function()
            if self.Widget.CurrentPage < totalPages then
                self.Widget.CurrentPage = self.Widget.CurrentPage + 1
                self:Refresh()
            end
        end
        nextButton.SameLine = true
    end
end

function ListV2IMGUIWidget:MoveElement(index, direction)
    local newIndex = index + direction

    if newIndex < 1 or newIndex > #self.Widget.Elements then
        return
    end

    -- Swap elements
    self.Widget.Elements[index], self.Widget.Elements[newIndex] = self.Widget.Elements[newIndex],
        self.Widget.Elements[index]

    -- Update the setting value
    local settingValue = {
        enabled = self.Widget.Enabled,
        elements = self.Widget.Elements
    }
    IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)

    -- Refresh the widget
    self:FilterElements()
    self:RefreshList()
end

function ListV2IMGUIWidget:AddInputAndAddButton()
    local inputGroup = self.Widget.InputGroup
    local newElementName = ""
    inputGroup:AddText("Add new element: ")
    local textInput = inputGroup:AddInputText("", newElementName)
    textInput.AutoSelectAll = true
    textInput.SameLine = true
    textInput.OnChange = function(input)
        _DS(input)
        newElementName = input.Text
    end
    local addButton = inputGroup:AddImageButton("Add", "ico_plus_d", IMGUIWidget:GetIconSizes())
    if not addButton.Image or addButton.Image.Icon == "" then
        addButton:Destroy()
        addButton = inputGroup:AddButton("Add")
    end
    addButton.SameLine = true
    addButton.OnClick = function()
        if newElementName ~= "" then
            local newElement = { name = newElementName, enabled = true }
            table.insert(self.Widget.Elements, newElement)
            local settingValue = {
                enabled = self.Widget.Enabled,
                elements = self.Widget.Elements
            }
            IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.modUUID)
            self:FilterElements()
            self:Refresh()
            -- Reset input
            textInput.Text = ""
            newElementName = ""
        end
    end
end

function ListV2IMGUIWidget:ElementExists(name)
    for _, element in ipairs(self.Widget.Elements) do
        if element.name == name then
            return true
        end
    end
    return false
end

local function clearGroup(group)
    if not group then
        return
    end
    for _, child in ipairs(group.Children or {}) do
        child:Destroy()
    end
end

function ListV2IMGUIWidget:Refresh()
    clearGroup(self.Widget.TableGroup)
    clearGroup(self.Widget.InputGroup)
    self:RenderList()
    self:AddInputAndAddButton()
end

function ListV2IMGUIWidget:RefreshList()
    clearGroup(self.Widget.TableGroup)
    self:RenderList()
end

function ListV2IMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Enabled = value.enabled ~= false
    self.Widget.Elements = value.elements or {}
    self:FilterElements()
    self:Refresh()
end

--- Add reset and delete all buttons to the widget
---@param group any The IMGUI group to add the button to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param modUUID string The UUID of the mod that owns this widget
---@return nil
---@see IMGUIAPI:ResetSettingValue
function ListV2IMGUIWidget:AddResetButton(group, setting, modUUID)
    group:AddDummy(40, 0)
    local resetButton = group:AddButton("[Reset list]")
    resetButton.IDContext = modUUID .. "_" .. "ResetButton_" .. setting:GetId()
    resetButton:Tooltip():AddText("Reset this list to its default values")
    resetButton.OnClick = function()
        self:ShowResetConfirmationPopup(setting, modUUID)
    end

    self:AddDeleteAllButton(group, modUUID)
end

--- Add a delete all button to the widget
---@param group any The IMGUI group to add the button to
---@param modUUID string The UUID of the mod that owns this widget
---@return nil
function ListV2IMGUIWidget:AddDeleteAllButton(group, modUUID)
    local deleteAllButton = group:AddButton("[Delete all]")
    deleteAllButton.IDContext = modUUID .. "_" .. "DeleteAllButton"
    deleteAllButton:Tooltip():AddText("Delete all elements from the list")
    deleteAllButton.OnClick = function()
        self:ShowDeleteAllConfirmationPopup()
    end
    deleteAllButton.SameLine = true
end

function ListV2IMGUIWidget:ShowResetConfirmationPopup(setting, modUUID)
    -- Check if the popup group exists and destroy it if it does
    xpcall(function()
        if self.Widget.ResetConfirmationPopup then
            self.Widget.ResetConfirmationPopup:Destroy()
        end
    end, function(err) end)

    -- Create a new group for popup confirmation
    self.Widget.ResetConfirmationPopup = self.Widget.Group:AddPopup("ConfirmResetPopup")
    local text = self.Widget.ResetConfirmationPopup:AddText(
        "Are you sure you want to reset the list to its default values?")
    text:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
    local confirmButton = self.Widget.ResetConfirmationPopup:AddButton("Yes")
    confirmButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modUUID)
        self:UpdateCurrentValue({
            enabled = true,
            elements = setting:GetDefault().elements
        })
        self.Widget.ResetConfirmationPopup:Destroy()
    end
    local cancelButton = self.Widget.ResetConfirmationPopup:AddButton("No")
    cancelButton.OnClick = function()
        self.Widget.ResetConfirmationPopup:Destroy()
    end
    self.Widget.ResetConfirmationPopup:Open()
end
