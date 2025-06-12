---@enum MessageBoxMode
MessageBoxMode = {
    Ok = "ok",
    OkCancel = "okcancel",
    YesNo = "yesno",
    YesNoCancel = "yesnocancel",
}

---@class MessageBox
---@field Title string The title of the message box
---@field Message string The message to display
---@field Mode MessageBoxMode The mode of the message box (determines which buttons are shown)
---@field PopupDialog any The IMGUI popup group
---@field OkCallback function|nil Callback function for the OK button
---@field CancelCallback function|nil Callback function for the Cancel button
---@field YesCallback function|nil Callback function for the Yes button
---@field NoCallback function|nil Callback function for the No button
---@field OkLabel string|nil The text for the OK button
---@field CancelLabel string|nil The text for the Cancel button
---@field YesLabel string|nil The text for the Yes button
---@field NoLabel string|nil The text for the No button
---@field ModUUID string|nil The UUID of the mod that owns this message box (for context ID generation)
---@field ContextId string|nil A custom context ID for this message box
MessageBox = {}

---Creates a new MessageBox instance
---@param title string The title of the message box
---@param message string The message to display
---@param mode MessageBoxMode The mode of the message box (determines which buttons are shown)
---@param modUUID string|nil The UUID of the mod that owns this message box
---@param contextId string|nil A custom context ID for this message box
---@return MessageBox
function MessageBox:Create(title, message, mode, modUUID, contextId)
    local instance = {
        Title = title or "Confirmation",
        Message = message or "",
        Mode = mode or MessageBoxMode.Ok,
        PopupGroup = nil,
        OkCallback = nil,
        CancelCallback = nil,
        YesCallback = nil,
        NoCallback = nil,
        OkLabel = nil,
        CancelLabel = nil,
        YesLabel = nil,
        NoLabel = nil,
        ModUUID = modUUID or ModuleUUID,
        ContextId = contextId or "MessageBox_" .. tostring(math.random(1000000)),
    }

    setmetatable(instance, { __index = self })
    return instance
end

---Sets the callback function for the OK button
---@param callback function The callback function
---@return MessageBox
function MessageBox:SetOkCallback(callback)
    self.OkCallback = callback
    return self
end

---Sets the callback function for the Cancel button
---@param callback function The callback function
---@return MessageBox
function MessageBox:SetCancelCallback(callback)
    self.CancelCallback = callback
    return self
end

---Sets the callback function for the Yes button
---@param callback function The callback function
---@return MessageBox
function MessageBox:SetYesCallback(callback)
    self.YesCallback = callback
    return self
end

---Sets the callback function for the No button
---@param callback function The callback function
---@return MessageBox
function MessageBox:SetNoCallback(callback)
    self.NoCallback = callback
    return self
end

---@param label string The text for the OK button
---@return MessageBox
function MessageBox:SetOkLabel(label)
    if not label or label == "" then return self end
    self.OkLabel = label
    return self
end

---@param label string The text for the Cancel button
---@return MessageBox
function MessageBox:SetCancelLabel(label)
    if not label or label == "" then return self end
    self.CancelLabel = label
    return self
end

---@param label string The text for the Yes button
---@return MessageBox
function MessageBox:SetYesLabel(label)
    if not label or label == "" then return self end
    self.YesLabel = label
    return self
end

---@param label string The text for the No button
---@return MessageBox
function MessageBox:SetNoLabel(label)
    if not label or label == "" then return self end
    self.NoLabel = label
    return self
end

---Shows the message box
---@param parentGroup any|nil The parent IMGUI group to attach the popup to
---@return MessageBox|nil
function MessageBox:Show(parentGroup)
    -- FIXME: If a popup is already shown, destroy it first (not working)
    xpcall(function()
        if self.PopupDialog then
            self.PopupDialog:Destroy()
        end
    end, function(err) end)

    -- Create the popup group - either attached to a parent or as a standalone popup
    local group = parentGroup
    if not group then
        MCMError(0, "No parent group provided for MessageBox.")
        return nil
    end

    self.PopupDialog = group:AddPopup(self.ContextId .. "_Popup")
    self.PopupDialog:SetSizeConstraints({ 600, 600 })
    self.PopupDialog.IDContext = self.ModUUID .. "_" .. self.ContextId

    -- Add title text
    local titleText = self.PopupDialog:AddText(self.Title)
    titleText:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    titleText.TextWrapPos = 0

    -- Add separator
    self.PopupDialog:AddSeparator()

    -- Add message text
    local messageText = self.PopupDialog:AddText(self.Message)
    messageText:SetColor("Text", Color.NormalizedRGBA(200, 200, 200, 0.9))
    messageText.TextWrapPos = 0

    self.PopupDialog:AddDummy(0, 5)

    -- Add buttons based on mode
    if self.Mode == MessageBoxMode.Ok then
        self:AddOkButton()
    elseif self.Mode == MessageBoxMode.OkCancel then
        self:AddOkButton()
        self:AddCancelButton(true) -- true means same line
    elseif self.Mode == MessageBoxMode.YesNo then
        self:AddYesButton()
        self:AddNoButton(true) -- true means same line
    elseif self.Mode == MessageBoxMode.YesNoCancel then
        self:AddYesButton()
        self:AddNoButton(true)
        self:AddCancelButton(true)
    end

    -- Open the popup
    self.PopupDialog:Open()

    return self
end

---Adds an OK button to the popup
---@return any The button object
function MessageBox:AddOkButton()
    local buttonText = self.OkLabel or Ext.Loca.GetTranslatedString("hf03356ba46684764b32d26ff28d3e709af5a") or "OK"
    local button = self.PopupDialog:AddButton(buttonText)
    button.IDContext = self.ModUUID .. "_" .. self.ContextId .. "_OkButton"
    button:SetColor("Button", Color.NormalizedRGBA(117, 140, 74, 0.33))
    button.OnClick = function()
        if self.OkCallback then
            self.OkCallback()
        end
        self:Close()
    end
    return button
end

---Adds a Cancel button to the popup
---@param sameLine boolean|nil Whether the button should be on the same line as the previous element
---@return any The button object
function MessageBox:AddCancelButton(sameLine)
    local buttonText = self.CancelLabel or Ext.Loca.GetTranslatedString("he43ef9b250584bc2840b8b291c73e4b53cb4") or
        "Cancel"
    local button = self.PopupDialog:AddButton(buttonText)
    button.IDContext = self.ModUUID .. "_" .. self.ContextId .. "_CancelButton"
    if sameLine then
        button.SameLine = true
    end
    button.OnClick = function()
        if self.CancelCallback then
            self.CancelCallback()
        end
        self:Close()
    end
    return button
end

---Adds a Yes button to the popup
---@return any The button object
function MessageBox:AddYesButton()
    local buttonText = self.YesLabel or Ext.Loca.GetTranslatedString("ha639028d9ca54b76a72e88059e3d24acd9a7") or "Yes"
    local button = self.PopupDialog:AddButton(buttonText)
    button.IDContext = self.ModUUID .. "_" .. self.ContextId .. "_YesButton"
    button.OnClick = function()
        if self.YesCallback then
            self.YesCallback()
        end
        self:Close()
    end
    return button
end

---Adds a No button to the popup
---@param sameLine boolean|nil Whether the button should be on the same line as the previous element
---@return any The button object
function MessageBox:AddNoButton(sameLine)
    local buttonText = self.NoLabel or Ext.Loca.GetTranslatedString("h2f7a7913be50404cbbdd9878ee774cca2113") or "No"
    local button = self.PopupDialog:AddButton(buttonText)
    button.IDContext = self.ModUUID .. "_" .. self.ContextId .. "_NoButton"
    if sameLine then
        button.SameLine = true
    end
    button.OnClick = function()
        if self.NoCallback then
            self.NoCallback()
        end
        self:Close()
    end
    return button
end

---Closes the message box
function MessageBox:Close()
    if self.PopupDialog then
        xpcall(function()
            self.PopupDialog:Destroy()
            self.PopupDialog = nil
        end, function(err) end)
    end
end

return MessageBox
