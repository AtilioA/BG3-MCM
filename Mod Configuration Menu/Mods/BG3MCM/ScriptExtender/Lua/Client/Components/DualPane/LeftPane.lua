------------------------------------------------------------
-- LeftPane Component
-- Manages the left pane (menu) of the dual-pane layout.
------------------------------------------------------------
---@class LeftPane
---@field parent ExtuiStyledRenderable
LeftPane = _Class:Create("LeftPane", nil, {
    parent = nil,
})
LeftPane.__index = LeftPane

function LeftPane:New(parent)
    local self = setmetatable({}, LeftPane)
    self.parent = parent -- Typically the menuScrollWindow
    return self
end

function LeftPane:AddMenuSeparator(text)
    self.parent:AddSeparatorText(text)
end

function LeftPane:CreateMenuButton(text, description, uuid)
    local button = self.parent:AddButton(text)
    button.IDContext = "MenuButton_" .. text .. "_" .. uuid
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    button.OnClick = function()
        -- Auto-reattach if mod is currently detached
        if DualPane and DualPane.rightPane and DualPane.rightPane.detachedWindows and DualPane.rightPane.detachedWindows[uuid] then
            DualPane.rightPane:ReattachModGroup(uuid)
        end
        DualPane:SwitchVisibleContent(button, uuid)
        if MCMAPI:GetSettingValue("enable_auto_collapse", ModuleUUID) then
            DualPane:ToggleSidebar()
        end
    end
    MCMRendering:AddTooltip(button, description, "MenuButton_" .. text .. "_" .. uuid .. "_TOOLTIP")
    return button
end

function LeftPane:SetActiveItem(uuid)
    for _, child in ipairs(self.parent.Children) do
        if child.IDContext and child.IDContext:find(uuid) then
            child:SetColor("Button", UIStyle.Colors["ButtonActive"])
        else
            child:SetColor("Button", UIStyle.Colors["Button"])
        end
    end
end
