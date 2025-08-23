---@class DialogService
DialogService = { cache = {} }

---Show or re-open a confirmation dialog
---@param modUUID string
---@param key string context key for caching
---@param parentGroup any
---@param title string
---@param message string
---@param onOk function
---@param onCancel function
---@return any MessageBox instance
function DialogService:Confirm(modUUID, key, parentGroup, title, message, onOk, onCancel)
    local id = modUUID .. "_" .. key
    local box = self.cache[id]
    if not box then
        box = MessageBox:Create(
            title or "Confirm",
            message or "",
            MessageBoxMode.OkCancel,
            modUUID,
            key
        )
        box:SetOkCallback(onOk)
           :SetCancelCallback(onCancel)
        self.cache[id] = box
    end
    box:Show(parentGroup)
    return box
end

---Destroy a confirmation dialog
---@param modUUID string
---@param key string
function DialogService:Destroy(modUUID, key)
    local id = modUUID .. "_" .. key
    local box = self.cache[id]
    if box then
        box:Close()
        self.cache[id] = nil
    end
end

return DialogService
