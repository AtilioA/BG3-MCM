local ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")

---@class KeybindingSearchBar
--- Handles search functionality for keybindings UI
---@field SearchSubject ReplaySubject
---@field _searchText string
---@field _debounceTimer any
KeybindingSearchBar = _Class:Create("KeybindingSearchBar", {})

KeybindingSearchBar.SearchSubject = nil

---Creates a new instance of KeybindingSearchBar
---@param onSearchChanged? function Optional callback when search text changes
---@return KeybindingSearchBar
function KeybindingSearchBar:new(onSearchChanged)
    local instance = setmetatable({}, KeybindingSearchBar)

    instance._searchText = ""
    instance.SearchSubject = ReplaySubject.Create(1)

    -- Setup debounced search
    instance._debounceTimer = VCTimer:Debounce(50, function()
        if onSearchChanged then
            onSearchChanged(instance._searchText)
        end
        instance.SearchSubject:OnNext(instance._searchText)
    end)

    return instance
end

---Gets the current search text
---@return string
function KeybindingSearchBar:GetSearchText()
    return self._searchText
end

---Sets the search text and triggers updates
---@param text string
function KeybindingSearchBar:SetSearchText(text)
    self._searchText = text
    self._debounceTimer()
end

---Renders the search bar UI
---@param group ExtuiGroup The IMGUI group to render into
function KeybindingSearchBar:Render(group)
    group:AddSpacing()
    group:AddText(Ext.Loca.GetTranslatedString("ha01f9dde75564cd7902c5056f1f3d03ba1ea"))
    group:AddSpacing()
    local searchLabel = group:AddText(Ext.Loca.GetTranslatedString("h2f1eda98ddb949d09792e1e1bc45ecddg446"))
    searchLabel.SameLine = true

    local searchInput = group:AddInputText("", self._searchText)
    searchInput.IDContext = "SearchInput"
    searchInput.AutoSelectAll = true
    searchInput.OnChange = function(input)
        self:SetSearchText(input.Text)
    end
    searchInput.SameLine = true

    group:AddSeparator()

    return searchInput
end

return KeybindingSearchBar
