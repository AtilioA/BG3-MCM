-- Handles gamepad input for MCM navigation
-- TODO: delegate to dualpane

---@class GamepadInputHandler
GamepadInputHandler = _Class:Create("GamepadInputHandler", nil, {})
GamepadInputHandler.__index = GamepadInputHandler

function GamepadInputHandler:New()
    local self = setmetatable({}, GamepadInputHandler)
    self:RegisterGamepadHandlers()
    return self
end

function GamepadInputHandler:RegisterGamepadHandlers()
    Ext.Events.ControllerButtonInput:Subscribe(function(e)
        if not IMGUIAPI:IsMCMWindowOpen() then
            return
        end

        if e.Event == "KeyDown" and e.Pressed then
            self:HandleGamepadInput(e)
        end
    end)
end

function GamepadInputHandler:HandleGamepadInput(e)
    -- Handle Back button to toggle sidebar
    if e.Button == "Back" then
        self:HandleBackButton(e)
        return
    end

    -- Handle shoulder buttons for tab navigation
    if e.Button == "LeftShoulder" then
        self:HandleLeftShoulder(e)
        return
    end

    if e.Button == "RightShoulder" then
        self:HandleRightShoulder(e)
        return
    end
end

function GamepadInputHandler:HandleBackButton(e)
    e:PreventAction()

    if DualPane then
        DualPane:ToggleSidebar()
        MCMDebug(2, "Gamepad: Toggled sidebar with Back button")
    end
end

function GamepadInputHandler:GetCurrentModTabBar()
    if not DualPane or not DualPane.rightPane then
        return nil
    end

    local currentMod = DualPane.rightPane.currentMod
    if not currentMod or not currentMod.modUUID then
        return nil
    end

    return DualPane.rightPane:GetModTabBar(currentMod.modUUID)
end

function GamepadInputHandler:GetActiveTabIndex(tabBar)
    -- FIXME: not working with subtab restoration

    if not tabBar or not tabBar.Children then
        return nil, nil
    end

    for index, tab in ipairs(tabBar.Children) do
        if tab.SetSelected == true then
            _P("Found:" .. index)
            return index, tab
        end
    end

    return nil, nil
end

function GamepadInputHandler:NavigateToTab(tabBar, newIndex)
    if not tabBar or not tabBar.Children or newIndex < 1 or newIndex > #tabBar.Children then
        return false
    end

    local targetTab = tabBar.Children[newIndex]
    if not targetTab then
        return false
    end

    -- Deselect all tabs first
    for _, tab in ipairs(tabBar.Children) do
        tab.SetSelected = false
    end

    -- Select the target tab
    targetTab.SetSelected = true

    -- Set focus on the tab (IMGUI object doesn't have that method)
    -- if targetTab.SetFocus then
    -- targetTab:SetFocus()
    if targetTab.StatusFlags then
        targetTab.StatusFlags = { "Focused" }
    end

    -- Trigger the tab's OnActivate callback if it exists
    if targetTab.OnActivate then
        targetTab.OnActivate()
    end

    MCMDebug(2, "Gamepad: Navigated to tab index " .. newIndex)
    return true
end

function GamepadInputHandler:HandleLeftShoulder(e)
    e:PreventAction()

    local tabBar = self:GetCurrentModTabBar()
    if not tabBar then
        MCMDebug(2, "Gamepad: No tab bar found for current mod")
        return
    end

    local currentIndex, _ = self:GetActiveTabIndex(tabBar)
    if not currentIndex then
        -- No tab selected, select the first one
        self:NavigateToTab(tabBar, 1)
        return
    end

    -- Navigate to previous tab (wrap around to end if at first tab)
    local newIndex = currentIndex - 1
    if newIndex < 1 then
        newIndex = #tabBar.Children
    end

    self:NavigateToTab(tabBar, newIndex)
end

function GamepadInputHandler:HandleRightShoulder(e)
    e:PreventAction()

    local tabBar = self:GetCurrentModTabBar()
    if not tabBar then
        MCMDebug(2, "Gamepad: No tab bar found for current mod")
        return
    end

    local currentIndex, _ = self:GetActiveTabIndex(tabBar)
    if not currentIndex then
        -- No tab selected, select the first one
        self:NavigateToTab(tabBar, 1)
        return
    end

    -- Navigate to next tab (wrap around to start if at last tab)
    local newIndex = currentIndex + 1
    if newIndex > #tabBar.Children then
        newIndex = 1
    end

    self:NavigateToTab(tabBar, newIndex)
end

-- Initialize the gamepad input handler
GamepadHandler = GamepadInputHandler:New()

return GamepadHandler
