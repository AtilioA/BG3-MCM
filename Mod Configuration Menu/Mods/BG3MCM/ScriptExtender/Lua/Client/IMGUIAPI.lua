---@class IMGUIAPI: MetaClass
---@field private _hiddenWindowVisibility table<ExtuiWindow, boolean>?
IMGUIAPI = _Class:Create("IMGUIAPI", nil, {})

IMGUIAPI.insertedTabs = {}

--- Returns live MCM-owned windows without retaining destroyed windows.
---@return ExtuiWindow[]
function IMGUIAPI:GetMCMWindows()
    local windows = NotificationManager:GetWindows()
    if MCM_WINDOW then
        table.insert(windows, MCM_WINDOW)
    end
    if DualPane and DualPane.rightPane then
        for _, window in pairs(DualPane.rightPane.detachedWindows) do
            table.insert(windows, window)
        end
    end
    return windows
end

--- Keeps new or reopened MCM windows hidden until the visibility hotkey is pressed again.
---@return nil
function IMGUIAPI:HideMCMWindows()
    local visibility = self._hiddenWindowVisibility
    if not visibility then return end

    local liveVisibility = {}
    for _, window in ipairs(self:GetMCMWindows()) do
        liveVisibility[window] = window.Visible or visibility[window] == true
        window.Visible = false
    end
    self._hiddenWindowVisibility = liveVisibility
end

--- Hides MCM windows or restores their visibility without changing their open state.
---@return nil
function IMGUIAPI:ToggleMCMWindowsVisibility()
    if self._hiddenWindowVisibility then
        for _, window in ipairs(self:GetMCMWindows()) do
            local visible = self._hiddenWindowVisibility[window]
            if visible ~= nil then
                window.Visible = visible or window.Visible
            end
        end
        self._hiddenWindowVisibility = nil
        return
    end

    self._hiddenWindowVisibility = {}
    self:HideMCMWindows()
end

--- Update values for the MCM window
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modUUID string The UUID of the mod
function IMGUIAPI:UpdateMCMWindowValues(settingId, value, modUUID)
    if modUUID ~= ModuleUUID then
        return
    end

    -- The font is global, so it must not depend on the MCM window existing
    if settingId == 'typeface' or settingId == 'font_size' or settingId == 'font_style_all_mods' then
        MCMClientState:ApplyFontSettings()
    end

    -- Apply window opacity setting
    if settingId == 'window_opacity' then
        MCMClientState:ApplyWindowOpacity()
    end

    if not MCM_WINDOW then
        return
    end

    -- if settingId == "toggle_mcm_sidebar_keybinding" then
    --     InitHandles:UpdateMCMSidebarKeybindingHandle()
    -- end
end

--- Insert a new tab for a mod in the MCM
---@param modUUID string The UUID of the mod
---@param tabName string|nil The name of the tab to be inserted, required only when the tab does not exist yet
---@param tabCallback function The callback function to create the tab
---@param skipDisclaimer? boolean If true, skip the disclaimer and render tab content immediately (default: false)
---@param tabId? string Blueprint TabId of the target tab; matches the tab regardless of language
---@return nil
function IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback, skipDisclaimer, tabId)
    if not self.insertedTabs[modUUID] then
        self.insertedTabs[modUUID] = {}
    end

    -- Check if the callback is already registered for this mod
    for _, existingCallback in ipairs(self.insertedTabs[modUUID]) do
        if existingCallback == tabCallback then
            return
        end
    end

    -- Register the new callback
    table.insert(self.insertedTabs[modUUID], tabCallback)

    MCMProxy:InsertModMenuTab(modUUID, tabName, tabCallback, skipDisclaimer, tabId)
end

--- Insert search results for a list_v2 setting in the MCM
---@param settingId string The ID of the list_v2 setting to insert search results for
---@param suggestions table The search results to insert
---@param modUUID string The UUID of the mod
---@return nil
function IMGUIAPI:InsertListV2Suggestions(settingId, suggestions, modUUID)
    MCMDebug(1, "IMGUIAPI:InsertListV2Suggestions - Starting to insert search results for settingId: %s and modUUID: %s", settingId, modUUID)

    -- Step 1: Find the widget corresponding to the setting
    local widget = self:findWidgetForSetting(settingId, modUUID)
    if not widget then
        MCMWarn(0, "IMGUIAPI:InsertListV2Suggestions - Widget not found for settingId: %s and modUUID: %s", settingId, modUUID)
        return
    end
    MCMDebug(1, "IMGUIAPI:InsertListV2Suggestions - Found widget for settingId: %s", settingId)

    widget.Widget.Suggestions = suggestions
    widget.Widget.instance:RenderSearchResults()
end

--- Send a message to update a setting value through the setting-write module.
---@param settingId string The ID of the setting to update
---@param value any The new value of the setting
---@param modUUID string The UUID of the mod
---@param setUIValue? fun(value: any) A callback used to reconcile the UI
---@param shouldEmitEvent? boolean Whether to emit the setting saved event
---@return SettingWriteReceipt receipt The immediate acceptance state
function IMGUIAPI:SetSettingValue(settingId, value, modUUID, setUIValue, shouldEmitEvent)
    return MCMProxy:SetSettingValue(settingId, value, modUUID, setUIValue, shouldEmitEvent)
end

--- Send a message to the server to reset a setting value
---@param settingId string The ID of the setting to reset
---@param modUUID string The UUID of the mod
---@return nil
function IMGUIAPI:ResetSettingValue(settingId, modUUID)
    MCMProxy:ResetSettingValue(settingId, modUUID)
end

function IMGUIAPI:IsMCMWindowOpen()
    return MCM_WINDOW and MCM_WINDOW.Open == true and MCM_WINDOW.Visible == true
end

--- Opens the MCM window.
--- @param playSound boolean Whether to play a sound effect when opening the window.
function IMGUIAPI:OpenMCMWindow(playSound)
    if not MCM_WINDOW then
        MCMWarn(0, "Tried to open MCM window, but it doesn't exist. Initializing MCM...")
        InitClientMCM()
        return
    end

    -- Ensure window is in visible area before showing it
    MCMClientState:EnsureWindowIsWithinViewport()

    MCM_WINDOW.Visible = true
    MCM_WINDOW.Open = true

    MCMClientState:EnsureWindowFocused()

    ModEventManager:Emit(EventChannels.MCM_WINDOW_OPENED, {
        playSound = playSound
    }, true)
end

--- Closes the MCM window.
--- @param playSound boolean Whether to play a sound effect when closing the window.
function IMGUIAPI:CloseMCMWindow(playSound)
    if not MCM_WINDOW then
        MCMWarn(0, "Tried to close MCM window, but it doesn't exist")
        return
    end

    MCM_WINDOW.Visible = false
    MCM_WINDOW.Open = false
    ModEventManager:Emit(EventChannels.MCM_WINDOW_CLOSED, {}, true)
end

--- Toggles the visibility of the MCM window.
--- @param playSound boolean Whether to play a sound effect when toggling the window.
function IMGUIAPI:ToggleMCMWindow(playSound)
    if not MCM_WINDOW then
        MCMWarn(0, "Tried to toggle MCM window, but it doesn't exist. Initializing configs...")
        InitClientMCM()
        return
    end

    if self:IsMCMWindowOpen() then
        self:CloseMCMWindow(playSound)
    else
        -- Ensure window is in visible area before showing it
        MCMClientState:EnsureWindowIsWithinViewport()
        self:OpenMCMWindow(playSound)
    end

    -- Toggle detached windows if the setting is enabled
    local toggleDetachedOpt = MCMAPI:GetSettingValue("toggle_detached_with_main", ModuleUUID)

    if not toggleDetachedOpt then
        return
    end

    for _, detachedWin in pairs(DualPane.rightPane.detachedWindows) do
        -- Set detached window visibility to match the new state of the main MCM window
        detachedWin.Visible = MCM_WINDOW.Visible
    end
end

function IMGUIAPI:OpenModPage(tabName, modUUID, shouldEmitEvent)
    if not DualPane then
        MCMError(0, "Tried to open mod page, but DualPane doesn't exist")
        return
    end

    DualPane:OpenModPage(modUUID, tabName, shouldEmitEvent)
end

-- --- Send a message to the server to set a profile
-- ---@param profileName string The name of the profile to set
-- ---@return nil
-- function IMGUIAPI:SetProfile(profileName)
--     Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE, Ext.Json.Stringify({
--         profileName = profileName
--     }))
-- end

--- TODO: move somewhere else probably
---@private lmao
function IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)
    -- Find the widget corresponding to the setting and update its value
    local widget = self:findWidgetForSetting(settingId, modUUID)
    if not widget then
        MCMWarn(2, "No widget found for setting " .. settingId)
        return
    end
    widget:UpdateCurrentValue(value)
end

--- Refresh enum choices for a widget.
---@param settingId string The ID of the setting to update
---@param value any The current authoritative value for the setting
---@param modUUID string The UUID of the mod
function IMGUIAPI:UpdateEnumSettingChoices(settingId, value, modUUID)
    local widget = self:findWidgetForSetting(settingId, modUUID)
    if not widget or not widget.RefreshChoices then
        return
    end

    widget:RefreshChoices(value)
end

--- Find the widget corresponding to a setting
--- TODO: perform a traversal of the window nodes to find the widget;
--- Storing references in a table is troublesome because they get lost for some reason
---@private
---@param modUUID string The UUID of the mod
---@param settingId string The ID of the setting to find the widget for
---@return any | nil - The widget corresponding to the setting, or nil if no widget was found
function IMGUIAPI:findWidgetForSetting(settingId, modUUID)
    -- Check if the mod has any registered widgets
    local widgets = self:GetModWidgets(modUUID)
    if widgets then
        return widgets[settingId]
    end
end

--- Get the widgets for a mod
---@private
---@param modUUID string The UUID of the mod
---@return table<string, any> | nil - widgets for the mod (keyed by setting ID), or nil if the mod has no widgets
function IMGUIAPI:GetModWidgets(modUUID)
    if not MCMClientState or not MCMClientState.mods then
        return nil
    end
    if not MCMClientState.mods[modUUID] then
        return nil
    end
    if not MCMClientState.mods[modUUID].widgets then
        return nil
    end

    return MCMClientState.mods[modUUID].widgets
end

function IMGUIAPI:ToggleMCMSidebar()
    if not MCM_WINDOW then
        MCMError(0, "Tried to toggle MCM sidebar, but it doesn't exist")
        return
    end

    if MCM_WINDOW.Visible or MCM_WINDOW.Open then
        DualPane:ToggleSidebar()
    end
end
