---@alias MoveDirection
---| 'up'
---| 'down'

---@class ElementTable
---@field enabled boolean
---@field name string

---@class FilteredElements
---@field element ElementTable
---@field indexInElements number

---@class ListV2SettingValue
---@field enabled boolean
---@field elements ElementTable[]

---@class ListV2IMGUIWidget: IMGUIWidget
ListV2IMGUIWidget = _Class:Create("ListV2IMGUIWidget", IMGUIWidget)

---@class ListV2IMGUIWidget.Widget
---@field Group ExtuiGroup The main IMGUI group for the widget
---@field ModUUID string The UUID of the mod owning this widget
---@field Setting BlueprintSetting The setting associated with this widget
---@field Enabled boolean Indicates if the list is enabled
---@field Elements ElementTable[] The list of elements
---@field PageSize number Number of elements per page
---@field ShowSearchBar boolean Indicates if the search bar is shown
---@field AllowReordering boolean Indicates if elements can be reordered
---@field ReadOnly boolean Indicates if the list is read-only
---@field CurrentPage number The current page number
---@field FilteredElements FilteredElements[] The filtered elements based on search
---@field SearchText string The current search text
---@field HeaderGroup ExtuiGroup The header group
---@field TableGroup ExtuiGroup The table group
---@field InputGroup ExtuiGroup|nil The input group (nil if ReadOnly)
---@field ResetGroup ExtuiGroup|nil The reset group (nil if ReadOnly)
---@field ConfirmationPopup ExtuiGroup|nil The confirmation popup group (if open)

---Creates a new instance of ListV2IMGUIWidget
---@param group ExtuiGroup The parent IMGUI group
---@param setting BlueprintSetting The setting associated with this widget
---@param initialValue ListV2SettingValue|nil The initial value for the widget
---@param ModUUID string The UUID of the mod owning this widget
---@return ListV2IMGUIWidget instance The new instance of ListV2IMGUIWidget
function ListV2IMGUIWidget:new(group, setting, initialValue, ModUUID)
    local instance = setmetatable({}, { __index = ListV2IMGUIWidget })
    instance.Widget = {}
    instance.Widget.instance = instance
    instance.Widget.Group = group
    instance.Widget.ModUUID = ModUUID
    instance.Widget.Setting = setting

    initialValue = initialValue or {}
    instance.Widget.Enabled = initialValue.enabled ~= false
    instance.Widget.Elements = initialValue.elements or {}

    instance.Widget.PageSize = math.min((setting:GetOptions() and setting:GetOptions().PageSize) or 5, 20)
    if instance.Widget.PageSize < 5 then instance.Widget.PageSize = 5 end
    instance.Widget.ShowSearchBar = (setting:GetOptions() and setting:GetOptions().ShowSearchBar) ~= false
    instance.Widget.AllowReordering = (setting:GetOptions() and setting:GetOptions().AllowReordering) == true
    instance.Widget.ReadOnly = (setting:GetOptions() and setting:GetOptions().ReadOnly) == true
    instance.Widget.Suggestions = (setting:GetOptions() and setting:GetOptions().Suggestions) or {}

    instance.Widget.CurrentPage = 1
    instance.Widget.FilteredElements = {}
    instance.Widget.SearchText = ""

    -- Add groups
    instance.Widget.HeaderGroup = group:AddGroup("ListHeaderGroup_" .. setting.Id)
    instance.Widget.TableGroup = group:AddGroup("ListTableGroup_" .. setting.Id)
    if not instance.Widget.ReadOnly then
        instance.Widget.InputGroup = group:AddGroup("ListInputGroup_" .. setting.Id)
        instance.Widget.ResetGroup = group:AddGroup("ListResetGroup_" .. setting.Id)
    end

    instance:FilterElements()
    instance:RenderHeader()
    instance:RenderList()
    if not instance.Widget.ReadOnly then
        instance:AddInputAndAddButton()
        -- Not needed since it's called by IMGUIWidget
        -- instance:AddResetButton(instance.Widget.ResetGroup, setting, ModUUID)
    end

    return instance
end

---Renders the header section of the widget, including the enable checkbox and search bar
---@return nil
function ListV2IMGUIWidget:RenderHeader()
    local headerGroup = self.Widget.HeaderGroup

    -- Enable/disable entire list
    local enabledCheckbox = headerGroup:AddCheckbox(Ext.Loca.GetTranslatedString("h4ffde733fba3492387caa52d9c585d57f177"))
    enabledCheckbox.IDContext = self.Widget.ModUUID .. "_EnableCheckbox_" .. self.Widget.Setting.Id
    IMGUIHelpers.AddTooltip(enabledCheckbox, Ext.Loca.GetTranslatedString("h17e2c93763d54f3f9b5da8722d09cf90fab9"),
        self.Widget.ModUUID .. "_EnableCheckbox_TOOLTIP")
    enabledCheckbox.Checked = self.Widget.Enabled
    enabledCheckbox.OnChange = function(checkbox)
        self.Widget.Enabled = checkbox.Checked
        local settingValue = {
            enabled = self.Widget.Enabled,
            elements = self.Widget.Elements
        }
        IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.ModUUID)
        self:Refresh()
    end
    enabledCheckbox.SameLine = false

    -- Search
    if self.Widget.ShowSearchBar then
        headerGroup:AddSpacing()
        headerGroup:AddText(Ext.Loca.GetTranslatedString("h9b0d0bba0bf64006a6dd8ed86a4d5353a3d8"))
        if not self.Widget.SearchInput then
            self.Widget.SearchInput = headerGroup:AddInputText("", self.Widget.SearchText)
            self.Widget.SearchInput.IDContext = self.Widget.ModUUID .. "_SearchInput_" .. self.Widget.Setting.Id
            self.Widget.SearchInput.OnChange = VCTimer:Debounce(50, function(input)
                self.Widget.SearchText = input.Text
                self:FilterElements()
                self:RefreshList()
            end)
            self.Widget.SearchInput.AutoSelectAll = true
            self.Widget.SearchInput.SameLine = true
        else
            self.Widget.SearchInput.Text = self.Widget.SearchText
        end
        if not self.Widget.Enabled then
            self:ApplyDisabledStyle(self.Widget.SearchInput)
            self.Widget.SearchInput.ReadOnly = true
        end
    end
end

---Displays a confirmation popup before deleting all elements
---@return nil
function ListV2IMGUIWidget:ShowDeleteAllConfirmationPopup()
    -- Check if the popup group exists and destroy it if it does
    xpcall(function()
        if self.Widget.ConfirmationPopup then
            self.Widget.ConfirmationPopup:Destroy()
        end
    end, function(err) end)

    -- Create a new group for popup confirmation
    self.Widget.ConfirmationPopup = self.Widget.Group:AddPopup("ConfirmDeleteAllPopup")
    self.Widget.ConfirmationPopup.IDContext = self.Widget.ModUUID .. "_ConfirmDeleteAllPopup_" .. self.Widget.Setting.Id

    local text = self.Widget.ConfirmationPopup:AddText(Ext.Loca.GetTranslatedString(
        "h60c5e6f97c914061887ad783cccf5ac3371f"))
    text:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))

    local confirmButton = self.Widget.ConfirmationPopup:AddButton(Ext.Loca.GetTranslatedString(
        "hb2adccb2f863414991f8475d5b394dbb5f65"))
    confirmButton.IDContext = self.Widget.ModUUID .. "_ConfirmDeleteAll_" .. self.Widget.Setting.Id
    IMGUIHelpers.AddTooltip(confirmButton, Ext.Loca.GetTranslatedString("he9e1eaf8a127430bba164fd001b3131aa5c1"),
        self.Widget.ModUUID .. "_ConfirmDeleteAll_" .. self.Widget.Setting.Id .. "_TOOLTIP")
    confirmButton.OnClick = function()
        self.Widget.Elements = {}
        local settingValue = {
            enabled = self.Widget.Enabled,
            elements = self.Widget.Elements
        }
        IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.ModUUID)
        self:FilterElements()
        self:Refresh()
        self.Widget.ConfirmationPopup:Destroy()
    end

    local cancelButton = self.Widget.ConfirmationPopup:AddButton(Ext.Loca.GetTranslatedString(
        "h3481631a19f94c1181c338b3ce88cfff5805"))
    cancelButton.IDContext = self.Widget.ModUUID .. "_CancelDeleteAll_" .. self.Widget.Setting.Id
    IMGUIHelpers.AddTooltip(cancelButton, Ext.Loca.GetTranslatedString("h390af8814d814ef89fd24feb697262452agc"),
        self.Widget.ModUUID .. "_CancelDeleteAll_" .. self.Widget.Setting.Id .. "_TOOLTIP")
    cancelButton.OnClick = function()
        self.Widget.ConfirmationPopup:Destroy()
    end
    cancelButton.SameLine = true

    self.Widget.ConfirmationPopup:Open()
end

---Filters elements based on the current search text (fuzzy)
---@return nil
function ListV2IMGUIWidget:FilterElements()
    local filtered = {}
    local searchText = self.Widget.SearchText:lower()

    for i, value in ipairs(self.Widget.Elements) do
        local elementName = value.name:lower()
        if searchText == "" or VCString:FuzzyMatch(elementName, searchText) then
            table.insert(filtered, { element = value, indexInElements = i })
        end
    end

    self.Widget.FilteredElements = filtered
end

---Renders the list of elements, including the table and pagination controls
---@return nil
function ListV2IMGUIWidget:RenderList()
    local tableGroup = self.Widget.TableGroup
    local elements = self.Widget.FilteredElements
    local pageSize = self.Widget.PageSize
    local totalElements = #elements
    local totalPages = math.ceil(totalElements / pageSize)
    if totalPages == 0 then totalPages = 1 end
    local currentPage = self.Widget.CurrentPage
    if currentPage > totalPages then currentPage = totalPages end

    local imguiTable = self:CreateTable(tableGroup)
    self:AddTableHeader(imguiTable)

    for i = (currentPage - 1) * pageSize + 1, math.min(currentPage * pageSize, totalElements) do
        self:RenderTableRow(imguiTable, elements[i])
    end

    self:RenderPaginationControls(tableGroup, totalPages)
end

---Creates the IMGUI table with appropriate columns
---@param tableGroup ExtuiGroup The group to which the table belongs
---@return ExtuiTable imguiTable The created IMGUI table
function ListV2IMGUIWidget:CreateTable(tableGroup)
    local columns = 4
    -- No 'Remove' column if the list is read-only
    if self.Widget.ReadOnly then
        columns = columns - 1
    end
    -- No 'Up/down' column if reordering is disabled
    if not self.Widget.AllowReordering then
        columns = columns - 1
    end

    local imguiTable = tableGroup:AddTable("", columns)
    imguiTable.Sortable = true
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    if not self.Widget.Enabled then
        imguiTable:SetColor("TableRowBg", Color.NormalizedRGBA(161, 176, 87, 0.15))
        imguiTable:SetColor("TableRowBgAlt", Color.NormalizedRGBA(133, 74, 38, 0.15))
    end

    imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h7268106aaf6f4d1d90f279554082e1faedbd"), "WidthFixed",
        IMGUIWidget:GetIconSizes()[0])
    if self.Widget.AllowReordering then
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h7b51e015aaa54af789c1ee0c3fbfa48eabb5"), "WidthFixed",
            IMGUIWidget:GetIconSizes()[0])
    end
    imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h917591f3d3984b62a13f0c6cd6a8d2710de6"), "WidthStretch")
    if not self.Widget.ReadOnly then
        imguiTable:AddColumn(Ext.Loca.GetTranslatedString("hc8ac6fff0508437d936bb1ae51e9a3dfc8a0"), "WidthFixed",
            IMGUIWidget:GetIconSizes()[0])
    end

    if not self.Widget.Enabled then
        self:ApplyDisabledStyle(imguiTable)
    end

    return imguiTable
end

---Adds the header row to the IMGUI table
---@param imguiTable any The IMGUI table to which the header is added (replace `any` with the actual table type if known)
---@return nil
function ListV2IMGUIWidget:AddTableHeader(imguiTable)
    local headerRow = imguiTable:AddRow()
    headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("h7268106aaf6f4d1d90f279554082e1faedbd"))
    if self.Widget.AllowReordering then
        headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("h7b51e015aaa54af789c1ee0c3fbfa48eabb5"))
    end
    headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("h917591f3d3984b62a13f0c6cd6a8d2710de6"))
    if not self.Widget.ReadOnly then
        headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("hc8ac6fff0508437d936bb1ae51e9a3dfc8a0"))
    end
end

---Renders a single table row for an element
---@param imguiTable any The IMGUI table to which the row is added (replace `any` with the actual table type if known)
---@param entry { element: ElementTable, indexInElements: number } The entry containing the element and its index
---@return nil
function ListV2IMGUIWidget:RenderTableRow(imguiTable, entry)
    local element = entry.element
    local indexInElements = entry.indexInElements
    local tableRow = imguiTable:AddRow()

    self:AddCheckboxCell(tableRow, element)

    if self.Widget.AllowReordering then
        self:AddMoveButtons(tableRow, indexInElements, element)
    end

    self:AddNameCell(tableRow, element)

    if not self.Widget.ReadOnly then
        self:AddRemoveButton(tableRow, indexInElements, element)
    end
end

---Adds the checkbox cell to a table row
---@param tableRow any The IMGUI table row (replace `any` with the actual table type if known)
---@param element ElementTable The element to which the checkbox corresponds
---@return nil
function ListV2IMGUIWidget:AddCheckboxCell(tableRow, element)
    local checkboxCell = tableRow:AddCell()
    local enabledCheckbox = checkboxCell:AddCheckbox("")
    enabledCheckbox.IDContext = self.Widget.ModUUID ..
        "_ElementEnabled_" .. self.Widget.Setting.Id .. "_" .. element.name
    enabledCheckbox.Checked = element.enabled ~= false
    enabledCheckbox.OnChange = function(checkbox)
        element.enabled = checkbox.Checked
        self:UpdateSettings()
        self:RefreshList()
    end

    local tooltipText = element.enabled and
        -- LOCA TODO VCString:InterpolateLocalizedMessage
        "Click to disable '" .. element.name .. "' (without removing it from the list)" or
        "Click to enable '" .. element.name .. "' (without removing it from the list)"
    IMGUIHelpers.AddTooltip(enabledCheckbox, tooltipText,
        self.Widget.ModUUID .. "_ElementEnabled_" .. self.Widget.Setting.Id .. "_" .. element.name .. "_TOOLTIP")

    if not self.Widget.Enabled then
        enabledCheckbox.Disabled = true
        self:ApplyDisabledStyle(enabledCheckbox)
    end
end

---Adds the move up and move down buttons to a table row
---@param tableRow any The IMGUI table row (replace `any` with the actual table type if known)
---@param indexInElements number The current index of the element in the list
---@param element ElementTable The element to move
---@return nil
function ListV2IMGUIWidget:AddMoveButtons(tableRow, indexInElements, element)
    local moveCell = tableRow:AddCell()

    -- Move up button
    local moveUpButton = moveCell:AddImageButton("", "panner_up_h", IMGUIWidget:GetIconSizes())
    moveUpButton.IDContext = self.Widget.ModUUID .. "_MoveUp_" .. self.Widget.Setting.Id .. "_" .. element.name
    if not moveUpButton.Image or moveUpButton.Image.Icon == "" then
        moveUpButton:Destroy()
        moveUpButton = moveCell:AddButton(Ext.Loca.GetTranslatedString("h9d7807ea594c4e5cb10d616f4a100c94341g"))
        moveUpButton.IDContext = self.Widget.ModUUID ..
            "_MoveUp_Button_" .. self.Widget.Setting.Id .. "_" .. element.name
    end
    moveUpButton.OnClick = function() self:MoveElement(indexInElements, 'up') end
    -- LOCA TODO VCString:InterpolateLocalizedMessage
    IMGUIHelpers.AddTooltip(moveUpButton, "Move '" .. element.name .. "' up in the list",
        self.Widget.ModUUID .. "_MoveUp_" .. self.Widget.Setting.Id .. "_" .. element.name .. "_TOOLTIP")

    -- Move down button
    local moveDownButton = moveCell:AddImageButton("", "panner_down_h", IMGUIWidget:GetIconSizes())
    moveDownButton.IDContext = self.Widget.ModUUID .. "_MoveDown_" .. self.Widget.Setting.Id .. "_" .. element.name
    moveDownButton.SameLine = true
    if not moveDownButton.Image or moveDownButton.Image.Icon == "" then
        moveDownButton:Destroy()
        moveDownButton = moveCell:AddButton(Ext.Loca.GetTranslatedString("h5259f8b44fdd4186bccca1948332cf250ac3"))
        moveDownButton.IDContext = self.Widget.ModUUID ..
            "_MoveDown_Button_" .. self.Widget.Setting.Id .. "_" .. element.name
    end
    moveDownButton.OnClick = function() self:MoveElement(indexInElements, 'down') end
    -- LOCA TODO VCString:InterpolateLocalizedMessage
    IMGUIHelpers.AddTooltip(moveDownButton, "Move '" .. element.name .. "' down in the list",
        self.Widget.ModUUID .. "_MoveDown_" .. self.Widget.Setting.Id .. "_" .. element.name .. "_TOOLTIP")

    if not self.Widget.Enabled then
        moveUpButton.Disabled = true
        moveDownButton.Disabled = true
        self:ApplyDisabledStyle(moveUpButton)
        self:ApplyDisabledStyle(moveDownButton)
    end
end

---Adds the name cell to a table row
---@param tableRow any The IMGUI table row (replace `any` with the actual table type if known)
---@param element ElementTable The element whose name is being displayed
---@return nil
function ListV2IMGUIWidget:AddNameCell(tableRow, element)
    local nameCell = tableRow:AddCell()
    local nameText = nameCell:AddText(element.name)
    nameText.IDContext = self.Widget.ModUUID .. "_ElementName_" .. self.Widget.Setting.Id .. "_" .. element.name
    if not self.Widget.Enabled then
        self:ApplyDisabledStyle(nameText)
    end
end

---Adds the remove button to a table row
---@param tableRow any The IMGUI table row (replace `any` with the actual table type if known)
---@param indexInElements number The current index of the element in the list
---@param element ElementTable The element to remove
---@return nil
function ListV2IMGUIWidget:AddRemoveButton(tableRow, indexInElements, element)
    local removeCell = tableRow:AddCell()
    local removeButton = removeCell:AddImageButton("", "popin_closeIco_d", IMGUIWidget:GetIconSizes())
    removeButton.IDContext = self.Widget.ModUUID .. "_Remove_" .. self.Widget.Setting.Id .. "_" .. element.name
    if not removeButton.Image or removeButton.Image.Icon == "" then
        removeButton:Destroy()
        removeButton = removeCell:AddButton(Ext.Loca.GetTranslatedString("hc8ac6fff0508437d936bb1ae51e9a3dfc8a0"))
        removeButton.IDContext = self.Widget.ModUUID ..
            "_Remove_Button_" .. self.Widget.Setting.Id .. "_" .. element.name
    end
    removeButton.OnClick = function()
        table.remove(self.Widget.Elements, indexInElements)
        self:UpdateSettings()
        self:FilterElements()
        self:Refresh()
    end

    -- LOCA TODO VCString:InterpolateLocalizedMessage
    IMGUIHelpers.AddTooltip(removeButton, "Remove '" .. element.name .. "' from the list",
        self.Widget.ModUUID .. "_Remove_" .. self.Widget.Setting.Id .. "_" .. element.name .. "_TOOLTIP")

    if not self.Widget.Enabled then
        removeButton.Disabled = true
        self:ApplyDisabledStyle(removeButton)
    end
end

---Renders the pagination controls below the table
---@param tableGroup ExtuiGroup The group to which pagination controls are added
---@param totalPages number The total number of pages
---@return nil
function ListV2IMGUIWidget:RenderPaginationControls(tableGroup, totalPages)
    local paginationGroup = tableGroup:AddGroup("PaginationGroup")
    paginationGroup.IDContext = self.Widget.ModUUID .. "_PaginationGroup_" .. self.Widget.Setting.Id
    paginationGroup:AddSpacing()
    if totalPages > 1 then
        self:AddPaginationButtons(paginationGroup, totalPages)
    end
end

---Adds pagination buttons to the pagination group
---@param paginationGroup ExtuiGroup The group to which pagination buttons are added
---@param totalPages number The total number of pages
---@return nil
function ListV2IMGUIWidget:AddPaginationButtons(paginationGroup, totalPages)
    local currentPage = self.Widget.CurrentPage
    local function addPageButton(label, pageNumber, disabled)
        local paddedLabel = " " .. label .. " "
        local button = paginationGroup:AddButton(paddedLabel)
        button.IDContext = self.Widget.ModUUID .. "_PageButton_" .. self.Widget.Setting.Id .. "_" .. pageNumber
        button.OnClick = function()
            self.Widget.CurrentPage = pageNumber
            self:Refresh()
        end
        if disabled then
            button.Disabled = true
            self:ApplyDisabledStyle(button)
        end
        button.SameLine = true
    end

    -- Previous Button
    local prevButton = paginationGroup:AddImageButton("<", "input_slider_arrowL_d", IMGUIWidget:GetIconSizes())
    prevButton.IDContext = self.Widget.ModUUID .. "_PrevPage_" .. self.Widget.Setting.Id
    if not prevButton.Image or prevButton.Image.Icon == "" then
        prevButton:Destroy()
        prevButton = paginationGroup:AddButton("<")
        prevButton.IDContext = self.Widget.ModUUID .. "_PrevPage_Button_" .. self.Widget.Setting.Id
    end
    prevButton.OnClick = function()
        if self.Widget.CurrentPage > 1 then
            self.Widget.CurrentPage = self.Widget.CurrentPage - 1
            self:Refresh()
        end
    end
    if currentPage == 1 then
        prevButton.Disabled = true
        self:ApplyDisabledStyle(prevButton)
    end
    prevButton.SameLine = true

    -- First Page
    addPageButton("1", 1, currentPage == 1)

    -- Input for page number
    if currentPage <= totalPages - 2 or currentPage >= 3 then
        local pageInput = paginationGroup:AddInputText("", tostring(currentPage))
        pageInput.IDContext = self.Widget.ModUUID .. "_PageInput_" .. self.Widget.Setting.Id
        pageInput.Text = tostring(currentPage or "...")
        pageInput.SizeHint = { IMGUIWidget:GetIconSizes()[1] * 1.5, 0 }
        pageInput:Tooltip():AddText(Ext.Loca.GetTranslatedString("hb22eb0c6c4ed41b28966287ab5b20c7b35a3"))
        pageInput.AutoSelectAll = true
        pageInput.EnterReturnsTrue = true
        pageInput.OnChange = function(input)
            local pageNumber = tonumber(input.Text)
            if not pageNumber then return end
            pageNumber = math.min(pageNumber, totalPages)
            pageNumber = math.max(pageNumber, 1)
            self.Widget.CurrentPage = pageNumber
            self:Refresh()
        end
        pageInput.SameLine = true
    end

    -- Current Page
    if currentPage > 1 and currentPage < totalPages then
        addPageButton(tostring(currentPage), currentPage, true)
    end

    -- Last Page
    if totalPages > 1 then
        addPageButton(tostring(totalPages), totalPages, currentPage == totalPages)
    end

    -- Next Button
    local nextButton = paginationGroup:AddImageButton(">", "input_slider_arrowR_d", IMGUIWidget:GetIconSizes())
    nextButton.IDContext = self.Widget.ModUUID .. "_NextPage_" .. self.Widget.Setting.Id
    if not nextButton.Image or nextButton.Image.Icon == "" then
        nextButton:Destroy()
        nextButton = paginationGroup:AddButton(">")
        nextButton.IDContext = self.Widget.ModUUID .. "_NextPage_Button_" .. self.Widget.Setting.Id
    end
    nextButton.OnClick = function()
        if self.Widget.CurrentPage < totalPages then
            self.Widget.CurrentPage = self.Widget.CurrentPage + 1
            self:Refresh()
        end
    end
    if currentPage == totalPages then
        nextButton.Disabled = true
        self:ApplyDisabledStyle(nextButton)
    end
    nextButton.SameLine = true
end

---Generates a status text showing the current page and element count
---@return string The formatted page status text
function ListV2IMGUIWidget:GetPageText()
    local isFiltered = self.Widget.SearchText and self.Widget.SearchText ~= ""
    local totalElementCount = isFiltered and #self.Widget.FilteredElements or #self.Widget.Elements
    local currentElementCount = math.min(self.Widget.CurrentPage * self.Widget.PageSize, totalElementCount)
    local filterText = isFiltered and Ext.Loca.GetTranslatedString("hb95bf2a27ec04873b561c53aa35066a75b83") or ""
    local totalPages = math.ceil(totalElementCount / self.Widget.PageSize)
    self.Widget.CurrentPage = math.min(self.Widget.CurrentPage, totalPages)

    -- LOCA TODO VCString:InterpolateLocalizedMessage
    return string.format(
        "Page %d of %d%s | %d/%d elements",
        self.Widget.CurrentPage,
        totalPages,
        filterText,
        currentElementCount,
        totalElementCount
    )
end

---Updates local state and settings in IMGUIAPI with the current widget state
---@return nil
function ListV2IMGUIWidget:UpdateSettings()
    local settingValue = {
        enabled = self.Widget.Enabled,
        elements = self.Widget.Elements
    }
    IMGUIAPI:SetSettingValue(self.Widget.Setting.Id, settingValue, self.Widget.ModUUID)
end

---Moves an element within the list
---@param index number The current index of the element
---@param direction MoveDirection The direction to move ('up' or 'down')
---@return nil
function ListV2IMGUIWidget:MoveElement(index, direction)
    local directionIncrement = -1
    if direction == 'down' then
        directionIncrement = 1
    end

    local newIndex = index + directionIncrement

    if newIndex < 1 or newIndex > #self.Widget.Elements then
        return
    end

    -- Swap elements
    self.Widget.Elements[index], self.Widget.Elements[newIndex] = self.Widget.Elements[newIndex],
        self.Widget.Elements[index]

    -- Update the setting value state
    self:UpdateSettings()

    -- Refresh the widget
    self:FilterElements()
    self:RefreshList()
end

---Adds the input field and add button to allow adding new elements
---@return nil
function ListV2IMGUIWidget:AddInputAndAddButton2()
    local inputGroup = self.Widget.InputGroup
    local newElementName = ""
    inputGroup:AddText(Ext.Loca.GetTranslatedString("hf10161d75da04360907b151e4eb07054f8cb"))
    local textInput = inputGroup:AddInputText("", newElementName)
    textInput.IDContext = self.Widget.ModUUID .. "_AddElementInput_" .. self.Widget.Setting.Id
    textInput.AutoSelectAll = true
    textInput.SameLine = true
    textInput.OnChange = function(input)
        newElementName = input.Text
    end
    local addButton = inputGroup:AddImageButton(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"),
        "ico_plus_d", IMGUIWidget:GetIconSizes())
    addButton.IDContext = self.Widget.ModUUID .. "_AddElementButton_" .. self.Widget.Setting.Id
    if not addButton.Image or addButton.Image.Icon == "" then
        addButton:Destroy()
        addButton = inputGroup:AddButton(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"))
        addButton.IDContext = self.Widget.ModUUID .. "_AddElement_Button_" .. self.Widget.Setting.Id
    end
    addButton.SameLine = true
    addButton.OnClick = function()
        xpcall(function()
            local ok = self:TryAddElement(newElementName)
            if ok then
                -- Reset input after adding
                textInput.Text = ""
                newElementName = ""
            end
        end, function(err)
            MCMDebug(1, "Error adding new element: " .. tostring(err))
        end)
    end

    if not self.Widget.Enabled then
        textInput.ReadOnly = true
        addButton.Disabled = true
        self:ApplyDisabledStyle(textInput)
        self:ApplyDisabledStyle(addButton)
    end
end

-- TODO: reduce code duplication (table + pagination), this is terrible

---Adds the input field and add button to allow adding new elements
---@return nil
---Adds the input field, add button, and the collapsible header for search results
---@return nil
function ListV2IMGUIWidget:AddInputAndAddButton()
    local inputGroup = self.Widget.InputGroup
    inputGroup:AddText(Ext.Loca.GetTranslatedString("hf10161d75da04360907b151e4eb07054f8cb"))

    xpcall(function()
        -- Input field for adding new elements
        if not self.Widget.NewElementInput then
            self.Widget.NewElementInput = inputGroup:AddInputText("", "")
            self.Widget.NewElementInput.IDContext = self.Widget.ModUUID .. "_AddElementInput_" .. self.Widget.Setting.Id
            self.Widget.NewElementInput.AutoSelectAll = true
            self.Widget.NewElementInput.SameLine = true
            self.Widget.NewElementInput.OnChange = function(input)
                self.Widget.NewElementName = input.Text
                -- Refresh search results when input changes
                self:FilterSearchResults()
                self:RefreshSearchResults()
            end
        else
            self.Widget.NewElementInput.Text = self.Widget.NewElementName or ""
        end
    end, function(err)
        MCMDebug(1, "Error in adding new element input: " .. tostring(err))
        self.Widget.NewElementInput = inputGroup:AddInputText("", "")
        self.Widget.NewElementInput.IDContext = self.Widget.ModUUID .. "_AddElementInput_" .. self.Widget.Setting.Id
        self.Widget.NewElementInput.AutoSelectAll = true
        self.Widget.NewElementInput.SameLine = true
        self.Widget.NewElementInput.OnChange = function(input)
            self.Widget.NewElementName = input.Text
            -- Refresh search results when input changes
            self:FilterSearchResults()
            self:RefreshSearchResults()
        end
    end)

    -- Add button
    local addButton = inputGroup:AddImageButton(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"),
        "ico_plus_d", IMGUIWidget:GetIconSizes())
    addButton.IDContext = self.Widget.ModUUID .. "_AddElementButton_" .. self.Widget.Setting.Id
    if not addButton.Image or addButton.Image.Icon == "" then
        addButton:Destroy()
        addButton = inputGroup:AddButton(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"))
        addButton.IDContext = self.Widget.ModUUID .. "_AddElement_Button_" .. self.Widget.Setting.Id
    end
    addButton.SameLine = true
    addButton.OnClick = function()
        xpcall(function()
            local ok = self:TryAddElement(self.Widget.NewElementName)
            if ok then
                -- Reset input after adding
                self.Widget.NewElementInput.Text = ""
                self.Widget.NewElementName = ""
            end
        end, function(err)
            MCMDebug(1, "Error adding new element: " .. tostring(err))
        end)
    end

    if not self.Widget.Enabled then
        self.Widget.NewElementInput.ReadOnly = true
        addButton.Disabled = true
        self:ApplyDisabledStyle(self.Widget.NewElementInput)
        self:ApplyDisabledStyle(addButton)
    end

    -- Add Collapsible Header for suggestions/search results
    if not self.Widget.SearchResultsGroup then
        self.Widget.SearchResultsGroup = inputGroup:AddGroup("SearchResultsGroup_" .. self.Widget.Setting.Id)
        self.Widget.SearchResultsGroup.IDContext = self.Widget.ModUUID ..
            "_SearchResultsGroup_" .. self.Widget.Setting.Id
    end

    self:RenderSearchResults()
end

---Creates the search results table
---@param parentGroup ExtuiGroup The parent group to which the table is added
---@return ExtuiTable imguiTable The created IMGUI table
function ListV2IMGUIWidget:CreateSearchResultsTable(parentGroup)
    local imguiTable = parentGroup:AddTable("", 2)
    imguiTable.Sortable = false
    imguiTable.BordersOuter = true
    imguiTable.BordersInner = true
    imguiTable.RowBg = true

    if not self.Widget.Enabled then
        self:ApplyDisabledStyle(imguiTable)
    end

    imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h917591f3d3984b62a13f0c6cd6a8d2710de6"), "WidthStretch")
    imguiTable:AddColumn(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"), "WidthFixed",
        IMGUIWidget:GetIconSizes()[0])

    return imguiTable
end

---Adds the header row to the search results table
---@param imguiTable any The IMGUI table to which the header is added
---@return nil
function ListV2IMGUIWidget:AddSearchResultsTableHeader(imguiTable)
    local headerRow = imguiTable:AddRow()
    headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("h917591f3d3984b62a13f0c6cd6a8d2710de6"))
    headerRow:AddCell():AddText(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"))
end

---Renders a single row in the search results table
---@param imguiTable any The IMGUI table to which the row is added
---@param result any The search result item
---@return nil
function ListV2IMGUIWidget:RenderSearchResultRow(imguiTable, result)
    local tableRow = imguiTable:AddRow()

    -- Name cell
    local nameCell = tableRow:AddCell()
    local nameText = nameCell:AddText(result)
    nameText.IDContext = self.Widget.ModUUID .. "_SearchResultName_" .. self.Widget.Setting.Id .. "_" .. result

    -- Add button cell
    local addCell = tableRow:AddCell()
    local addButton = addCell:AddImageButton("", "ico_plus_d", IMGUIWidget:GetIconSizes())
    addButton.IDContext = self.Widget.ModUUID .. "_AddSearchResult_" .. self.Widget.Setting.Id .. "_" .. result
    if not addButton.Image or addButton.Image.Icon == "" then
        addButton:Destroy()
        addButton = addCell:AddButton(Ext.Loca.GetTranslatedString("h4b543fe6f0fd4d8199950d7a16b3879ca7d1"))
        addButton.IDContext = self.Widget.ModUUID ..
            "_AddSearchResult_Button_" .. self.Widget.Setting.Id .. "_" .. result
    end

    addButton.OnClick = function()
        local ok, reason = self:TryAddElement(result)
        if not ok and reason == "duplicate" then
            addButton.Disabled = true
            addButton:Tooltip():AddText(Ext.Loca.GetTranslatedString("h35a4dfd6f3a54dc6a1ba9a4c90a4355a6ce6"))
        end
    end
    addButton:Tooltip():AddText(Ext.Loca.GetTranslatedString("h134c0b997c2c47b8a2fcb8975e164bd71e24"))

    if not self.Widget.Enabled then
        addButton.Disabled = true
        self:ApplyDisabledStyle(addButton)
    end
end

---Renders pagination controls for the search results
---@param parentGroup ExtuiGroup The parent group to which pagination controls are added
---@param totalPages number The total number of pages
---@return nil
function ListV2IMGUIWidget:RenderSearchResultsPagination(parentGroup, totalPages)
    local paginationGroup = parentGroup:AddGroup("SearchResultsPaginationGroup")
    paginationGroup.IDContext = self.Widget.ModUUID .. "_SearchResultsPaginationGroup_" .. self.Widget.Setting.Id
    paginationGroup:AddSpacing()
    if totalPages > 1 then
        self:AddSearchResultsPaginationButtons(paginationGroup, totalPages)
    end
end

---Adds pagination buttons to the search results pagination group
---@param paginationGroup ExtuiGroup The group to which pagination buttons are added
---@param totalPages number The total number of pages
---@return nil
function ListV2IMGUIWidget:AddSearchResultsPaginationButtons(paginationGroup, totalPages)
    local currentPage = self.Widget.SearchResultsCurrentPage
    local function addPageButton(label, pageNumber, disabled)
        local paddedLabel = " " .. label .. " "
        local button = paginationGroup:AddButton(paddedLabel)
        button.IDContext = self.Widget.ModUUID ..
            "_SearchResultsPageButton_" .. self.Widget.Setting.Id .. "_" .. pageNumber
        button.OnClick = function()
            self.Widget.SearchResultsCurrentPage = pageNumber
            self:RefreshSearchResults()
        end
        if disabled then
            button.Disabled = true
            self:ApplyDisabledStyle(button)
        end
        button.SameLine = true
    end

    -- Previous button
    local prevButton = paginationGroup:AddImageButton("<", "input_slider_arrowL_d", IMGUIWidget:GetIconSizes())
    prevButton.IDContext = self.Widget.ModUUID .. "_SearchResultsPrevPage_" .. self.Widget.Setting.Id
    if not prevButton.Image or prevButton.Image.Icon == "" then
        prevButton:Destroy()
        prevButton = paginationGroup:AddButton("<")
        prevButton.IDContext = self.Widget.ModUUID .. "_SearchResultsPrevPage_Button_" .. self.Widget.Setting.Id
    end
    prevButton.OnClick = function()
        if self.Widget.SearchResultsCurrentPage > 1 then
            self.Widget.SearchResultsCurrentPage = self.Widget.SearchResultsCurrentPage - 1
            self:RefreshSearchResults()
        end
    end
    if currentPage == 1 then
        prevButton.Disabled = true
        self:ApplyDisabledStyle(prevButton)
    end
    prevButton.SameLine = true

    -- Page buttons
    for page = 1, totalPages do
        addPageButton(tostring(page), page, currentPage == page)
    end

    -- Next button
    local nextButton = paginationGroup:AddImageButton(">", "input_slider_arrowR_d", IMGUIWidget:GetIconSizes())
    nextButton.IDContext = self.Widget.ModUUID .. "_SearchResultsNextPage_" .. self.Widget.Setting.Id
    if not nextButton.Image or nextButton.Image.Icon == "" then
        nextButton:Destroy()
        nextButton = paginationGroup:AddButton(">")
        nextButton.IDContext = self.Widget.ModUUID .. "_SearchResultsNextPage_Button_" .. self.Widget.Setting.Id
    end
    nextButton.OnClick = function()
        if self.Widget.SearchResultsCurrentPage < totalPages then
            self.Widget.SearchResultsCurrentPage = self.Widget.SearchResultsCurrentPage + 1
            self:RefreshSearchResults()
        end
    end
    if currentPage == totalPages then
        nextButton.Disabled = true
        self:ApplyDisabledStyle(nextButton)
    end
    nextButton.SameLine = true
end

---Fetches search results based on the input text using fuzzy search
---@param searchText string The search text input by the user
---@return table searchResults The list of search results
function ListV2IMGUIWidget:GetSearchResults(searchText)
    local results = {}
    local lowerSearchText = searchText:lower()
    for _, item in ipairs(self.Widget.Suggestions) do
        if not self:ElementExists(item) and VCString:FuzzyMatch(item:lower(), lowerSearchText) then
            table.insert(results, item)
        end
    end

    return results
end

---Filters the search results based on the new element input text
---@return nil
function ListV2IMGUIWidget:FilterSearchResults()
    if not self.Widget.NewElementName or self.Widget.NewElementName == "" then
        self.Widget.SearchResults = {}
    else
        self.Widget.SearchResults = self:GetSearchResults(self.Widget.NewElementName)
    end
    self.Widget.SearchResultsCurrentPage = 1
end

---Refreshes only the search results without re-rendering the entire widget
---@return nil
function ListV2IMGUIWidget:RefreshSearchResults()
    self:RenderSearchResults()
end

---Checks if an element with the given name exists in the list
---@param name string The name of the element to check
---@return boolean True if the element exists, false otherwise
function ListV2IMGUIWidget:ElementExists(name)
    for _, element in ipairs(self.Widget.Elements) do
        if element.name == name then
            return true
        end
    end
    return false
end

--- Normalizes a proposed element name (trims whitespace)
---@param name any
---@return string trimmedName
function ListV2IMGUIWidget:NormalizeName(name)
    local s = tostring(name or "")
    return s:gsub("^%s*(.-)%s*$", "%1")
end

--- Attempts to add an element to the list after validation (non-empty, non-duplicate)
---@param name any
---@return boolean ok, string|nil reason
function ListV2IMGUIWidget:TryAddElement(name)
    local trimmed = self:NormalizeName(name)
    if trimmed == "" then return false, "empty" end
    if self:ElementExists(trimmed) then return false, "duplicate" end

    table.insert(self.Widget.Elements, 1, { name = trimmed, enabled = true })
    self:UpdateSettings()
    self:FilterElements()
    self:Refresh()
    return true, "added"
end

---Clears all child elements from an IMGUI group
---@param group ExtuiGroup The group to clear
---@return nil
local function clearGroup(group)
    xpcall(function()
        if not group then
            return
        end
        for _, child in ipairs(group.Children or {}) do
            child:Destroy()
        end
    end, function(err)
        MCMDebug(1, "Error clearing group: " .. tostring(err))
    end)
end

---Refreshes the entire widget, re-rendering all components
---@return nil
function ListV2IMGUIWidget:Refresh()
    -- clearGroup(self.Widget.HeaderGroup)
    clearGroup(self.Widget.TableGroup)
    if not self.Widget.ReadOnly then
        clearGroup(self.Widget.InputGroup)
        clearGroup(self.Widget.ResetGroup)
    end
    -- self:RenderHeader()
    self:RenderList()
    if not self.Widget.ReadOnly then
        self:AddInputAndAddButton()
        -- self:AddResetButton(self.Widget.ResetGroup, self.Widget.Setting, self.Widget.ModUUID)
    end
end

---Refreshes only the list table without re-rendering the header or input sections
---@return nil
function ListV2IMGUIWidget:RefreshList()
    clearGroup(self.Widget.TableGroup)
    self:RenderList()
end

---Updates the current value of the widget with new data
---@param value ListV2SettingValue The new value to set
---@return nil
function ListV2IMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Enabled = value.enabled ~= false
    self.Widget.Elements = value.elements or {}
    self:FilterElements()
    self:Refresh()
end

--- Add reset and delete all buttons to the widget
---@param group ExtuiGroup  The IMGUI group to add the button to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param ModUUID string The UUID of the mod that owns this widget
---@return nil
---@see IMGUIAPI:ResetSettingValue
function ListV2IMGUIWidget:AddResetButton(group, setting, ModUUID)
    group:AddDummy(40, 0)
    local resetButton = group:AddButton(Ext.Loca.GetTranslatedString("hefc87cc64ef74547b4ccade4ff1676994d53"))
    resetButton.IDContext = ModUUID .. "_" .. "ResetButton_" .. setting:GetId()
    resetButton:Tooltip():AddText(Ext.Loca.GetTranslatedString("hd2a185ef63ff4c6695b20baf5fd6e08b2b8a"))
    resetButton.OnClick = function()
        self:ShowResetConfirmationPopup(setting, ModUUID)
    end

    if not self.Widget.ReadOnly then
        self:AddDeleteAllButton(group, ModUUID)
    end

    if not self.Widget.Enabled then
        self:ApplyDisabledStyle(resetButton)
    end
end

---Adds a "Delete All" button to the widget
---@param group ExtuiGroup The group to add the button to
---@param ModUUID string The UUID of the mod owning this widget
---@return nil
function ListV2IMGUIWidget:AddDeleteAllButton(group, ModUUID)
    local deleteAllButton = group:AddButton(Ext.Loca.GetTranslatedString("hfdeffc59d25b4fa0910682fd3bb78f7b4d04"))
    deleteAllButton.IDContext = ModUUID .. "_" .. "DeleteAllButton_" .. self.Widget.Setting.Id
    deleteAllButton:Tooltip():AddText(Ext.Loca.GetTranslatedString("he16594af5abf4f44b6545facfa654b669g0a"))
    deleteAllButton.OnClick = function()
        self:ShowDeleteAllConfirmationPopup()
    end
    deleteAllButton.SameLine = true

    if not self.Widget.Enabled then
        self:ApplyDisabledStyle(deleteAllButton)
    end
end

---Displays a confirmation popup before resetting the list to default values
---@param setting BlueprintSetting The setting associated with this widget
---@param ModUUID string The UUID of the mod owning this widget
---@return nil
function ListV2IMGUIWidget:ShowResetConfirmationPopup(setting, ModUUID)
    -- Check if the popup group exists and destroy it if it does
    xpcall(function()
        if self.Widget.ResetConfirmationPopup then
            self.Widget.ResetConfirmationPopup:Destroy()
        end
    end, function(err) end)

    -- Create a new group for popup confirmation
    self.Widget.ResetConfirmationPopup = self.Widget.Group:AddPopup("ConfirmResetPopup")
    self.Widget.ResetConfirmationPopup.IDContext = self.Widget.ModUUID .. "_ConfirmResetPopup_" .. self.Widget.Setting
        .Id

    local text = self.Widget.ResetConfirmationPopup:AddText(
        Ext.Loca.GetTranslatedString("h983f2fd776cd40ab844efcca6300d9c87eb5"))
    text:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))

    local confirmButton = self.Widget.ResetConfirmationPopup:AddButton(Ext.Loca.GetTranslatedString(
        "hc22c8995c3d34cb69b677e2c52a7ec3a4691"))
    confirmButton.IDContext = self.Widget.ModUUID .. "_ConfirmReset_" .. self.Widget.Setting.Id
    IMGUIHelpers.AddTooltip(confirmButton, Ext.Loca.GetTranslatedString("h6ca43c8ed1ec4292af8c51472528c21ed0gd"),
        self.Widget.ModUUID .. "_ConfirmReset_" .. self.Widget.Setting.Id .. "_TOOLTIP")
    confirmButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), ModUUID)

        self:UpdateCurrentValue({
            enabled = setting:GetDefault().enabled,
            elements = setting:GetDefault().elements
        })

        self.Widget.ResetConfirmationPopup:Destroy()

        self:FilterElements()
        self:Refresh()
    end

    local cancelButton = self.Widget.ResetConfirmationPopup:AddButton(Ext.Loca.GetTranslatedString(
        "h8886849a4a674633a14df972d408cb71d012"))
    cancelButton.IDContext = self.Widget.ModUUID .. "_CancelReset_" .. self.Widget.Setting.Id
    IMGUIHelpers.AddTooltip(cancelButton, Ext.Loca.GetTranslatedString("hdf197961585844d394b3e372417ac6fd66eg"),
        self.Widget.ModUUID .. "_CancelReset_" .. self.Widget.Setting.Id .. "_TOOLTIP")
    cancelButton.OnClick = function()
        self.Widget.ResetConfirmationPopup:Destroy()
    end
    cancelButton.SameLine = true

    self.Widget.ResetConfirmationPopup:Open()
end

---Applies a disabled style to an IMGUI element
---@param element ExtuiStyledRenderable The IMGUI element to style
---@return nil
function ListV2IMGUIWidget:ApplyDisabledStyle(element)
    element:SetColor("Text", Color.NormalizedRGBA(100, 100, 100, 1))
end

---Renders the search results below the input field
---@return nil
function ListV2IMGUIWidget:RenderSearchResults()
    clearGroup(self.Widget.SearchResultsGroup)

    -- Only render if there is search text
    if not self.Widget.NewElementName or self.Widget.NewElementName == "" then
        return
    end

    -- Prepare search results
    self.Widget.SearchResults = self:GetSearchResults(self.Widget.NewElementName)

    if not self.Widget.SearchResults or #self.Widget.SearchResults == 0 then
        return
    end

    self.Widget.SearchResultsGroup = self.Widget.InputGroup:AddGroup("SearchResultsGroup_" .. self.Widget.Setting.Id)


    local searchResultsGroup = self.Widget.SearchResultsGroup
    -- Add "suggestions" collapsing header
    -- LOCA TODO
    local collapsibleHeader = searchResultsGroup:AddCollapsingHeader("Suggestions")
    collapsibleHeader.DefaultOpen = true
    collapsibleHeader.IDContext = self.Widget.ModUUID .. "_SearchResultsHeader_" .. self.Widget.Setting.Id

    -- Pagination parameters
    local pageSize = self.Widget.PageSize
    local totalResults = #self.Widget.SearchResults
    local totalPages = math.ceil(totalResults / pageSize)
    if totalPages == 0 then totalPages = 1 end
    local currentPage = self.Widget.SearchResultsCurrentPage or 1
    if currentPage > totalPages then currentPage = totalPages end
    self.Widget.SearchResultsCurrentPage = currentPage

    -- Render the suggestions Table
    local imguiTable = self:CreateSearchResultsTable(collapsibleHeader)
    self:AddSearchResultsTableHeader(imguiTable)

    for i = (currentPage - 1) * pageSize + 1, math.min(currentPage * pageSize, totalResults) do
        self:RenderSearchResultRow(imguiTable, self.Widget.SearchResults[i])
    end

    -- Render pagination controls
    self:RenderSearchResultsPagination(collapsibleHeader, totalPages)
end
