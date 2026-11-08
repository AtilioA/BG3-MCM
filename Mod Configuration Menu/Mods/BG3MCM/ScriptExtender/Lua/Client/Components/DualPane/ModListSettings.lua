------------------------------------------------------------
-- ModListSettings
-- The Mod list section of MCM's Sidebar tab; rendered in code because blueprint settings are profile-scoped and server-routed.
------------------------------------------------------------

local FEEDBACK_SUCCESS = Color.NormalizedRGBA(0, 200, 0, 1)

-- Display order, starting with the default
local SORT_CHOICES = {
    { mode = "alphabetical", handle = "h5a10c3e1d2f84b6e9a7c1f0e3b5d7a01b2c3" },
    { mode = "manual", handle = "h5a10c3e1d2f84b6e9a7c1f0e3b5d7a02b2c3" },
    { mode = "recent", handle = "h5a10c3e1d2f84b6e9a7c1f0e3b5d7a03b2c3" },
    { mode = "frequent", handle = "h5a10c3e1d2f84b6e9a7c1f0e3b5d7a04b2c3" },
}

---@class ModListSettings
---@field leftPane LeftPane
---@field preferences ModListPreferences
---@field group ExtuiGroup
---@field radios ExtuiRadioButton[]
---@field foldersFirst ExtuiCheckbox
---@field feedback ExtuiText
ModListSettings = _Class:Create("ModListSettings", nil, {
    leftPane = nil,
    preferences = nil,
    group = nil,
    radios = nil,
    foldersFirst = nil,
    feedback = nil,
})

--- Render the section and let the left pane keep its controls in sync.
---@param parent ExtuiTreeParent
---@param leftPane LeftPane
---@return ModListSettings
function ModListSettings:New(parent, leftPane)
    local obj = setmetatable({}, ModListSettings)
    obj.leftPane = leftPane
    obj.preferences = leftPane.visibility.preferences
    obj.group = parent:AddGroup("MCM_ModListSettings")
    obj:renderHeader()
    obj:renderOrderChoices()
    obj:renderActions()
    parent:AddDummy(0, 5)
    leftPane.listSettings = obj
    return obj
end

---@private
function ModListSettings:renderHeader()
    local header = self.group:AddSeparatorText(Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a00b2c3"))
    header:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    header:SetColor("Separator", Color.NormalizedRGBA(255, 255, 255, 0.33))
    local description = self.group:AddText(Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a05b2c3"))
    description.TextWrapPos = 0
    description:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
    self.group:AddDummy(0, 2)
end

---@private
function ModListSettings:renderOrderChoices()
    local mode = self.preferences:GetSortMode()
    self.radios = {}
    for _, choice in ipairs(SORT_CHOICES) do
        local radio = self.group:AddRadioButton(Ext.Loca.GetTranslatedString(choice.handle), choice.mode == mode)
        radio.IDContext = "MCM_ModListSort_" .. choice.mode
        radio.UserData = { mode = choice.mode }
        radio.OnChange = function() self:SelectMode(choice.mode) end
        table.insert(self.radios, radio)
    end
end

---@private
function ModListSettings:renderActions()
    self.foldersFirst = self.group:AddCheckbox(Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a06b2c3"),
        self.preferences:GetFoldersFirst())
    self.foldersFirst.OnChange = function(checkbox) self:SelectFoldersFirst(checkbox.Checked) end
    self.group:AddDummy(0, 5)
    local clear = self.group:AddButton(Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a07b2c3"))
    clear.OnClick = function() self:ConfirmClearUsage() end
    self.feedback = self.group:AddText("")
    self.feedback.TextWrapPos = 0
    self:showFeedback(nil)
end

--- Match the controls to the saved preferences.
function ModListSettings:Sync()
    local mode = self.preferences:GetSortMode()
    for _, radio in ipairs(self.radios) do
        radio.Active = radio.UserData.mode == mode
    end
    self.foldersFirst.Checked = self.preferences:GetFoldersFirst()
end

--- Show a result under the actions; an invalid file stays explained, and otherwise no message hides the empty area.
---@private
---@param message string|nil
---@param color vec4|nil
function ModListSettings:showFeedback(message, color)
    if self.preferences:IsInvalid() then
        message = Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a0ab2c3")
        color = UIStyle.TextStyles.Error
    end
    self.feedback.Visible = message ~= nil
    self.feedback.Label = message or ""
    if color then
        self.feedback:SetColor("Text", color)
    end
end

--- Rebuild after a saved change; a refused save restores the controls and explains the failure.
---@private
---@param saved boolean
---@param successMessage string|nil
function ModListSettings:finishChange(saved, successMessage)
    self:Sync()
    if saved then
        self:showFeedback(successMessage, FEEDBACK_SUCCESS)
        self.leftPane:RebuildModEntries(self.leftPane.mods)
    else
        self:showFeedback(Ext.Loca.GetTranslatedString("h07852b32f9c54a09a559289344164f8ag005"), UIStyle.TextStyles.Error)
    end
end

---@param mode ModListSortMode
function ModListSettings:SelectMode(mode)
    if mode == self.preferences:GetSortMode() then
        self:Sync()
        return
    end
    self:finishChange(self.preferences:SetSortMode(mode))
end

---@param enabled boolean
function ModListSettings:SelectFoldersFirst(enabled)
    self:finishChange(self.preferences:SetFoldersFirst(enabled))
end

--- Ask before clearing, using MCM's stacked confirmation dialog.
function ModListSettings:ConfirmClearUsage()
    self:showFeedback(nil)
    local dialog = DialogService:Confirm(ModuleUUID, "MCM_ClearModListUsage", self.group,
        Ext.Loca.GetTranslatedString("h652b98e111884533a0ec00fd94ecc386f717"),
        Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a08b2c3"),
        function()
            self:finishChange(self.preferences:ClearUsage(),
                Ext.Loca.GetTranslatedString("h5a10c3e1d2f84b6e9a7c1f0e3b5d7a09b2c3"))
        end,
        function() end)
    dialog:SetOkLabel(Ext.Loca.GetTranslatedString("hf03356ba46684764b32d26ff28d3e709af5a"))
    dialog:SetCancelLabel(Ext.Loca.GetTranslatedString("he43ef9b250584bc2840b8b291c73e4b53cb4"))
    dialog:Show(self.group)
end
