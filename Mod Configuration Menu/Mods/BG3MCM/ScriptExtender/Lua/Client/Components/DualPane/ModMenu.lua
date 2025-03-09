------------------------------------------------------------
-- ModMenu Component
-- Manages the left pane (menu) of the dual-pane layout.
------------------------------------------------------------
ModMenu = {}
ModMenu.__index = ModMenu

function ModMenu:new(parent)
    local self = setmetatable({}, ModMenu)
    self.parent = parent  -- Typically the menuScrollWindow
    return self
end

function ModMenu:AddMenuSeparator(text)
    self.parent:AddSeparatorText(text)
end

function ModMenu:CreateMenuButton(text, description, uuid)
    local button = self.parent:AddButton(text)
    button.IDContext = "MenuButton_" .. text .. "_" .. uuid
    button:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    button.OnClick = function()
        DualPane:SwitchVisibleContent(button, uuid)
        if AUTO_COLLAPSE_ON_MOD_CLICK then
            DualPane:ToggleSidebar()
        end
    end
    MCMRendering:AddTooltip(button, description, "MenuButton_" .. text .. "_" .. uuid .. "_TOOLTIP")
    return button
end

function ModMenu:SetActiveItem(uuid)
    for _, child in ipairs(self.parent.Children) do
        if child.IDContext and child.IDContext:find(uuid) then
            child:SetColor("Button", UIStyle.Colors["ButtonActive"])
        else
            child:SetColor("Button", UIStyle.Colors["Button"])
        end
    end
end
