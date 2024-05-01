-- TODO: modularize this
Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")

IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Visible = true
IMGUI_WINDOW.NoBringToFrontOnFocus = true

IMGUI_WINDOW:SetColor("Border", Color.normalized_rgba(0, 0, 0, 1))
IMGUI_WINDOW:SetStyle("WindowBorderSize", 2)
IMGUI_WINDOW:SetStyle("WindowRounding", 2)

-- Set the window background color
IMGUI_WINDOW:SetColor("TitleBg", Color.normalized_rgba(36, 28, 68, 0.5))
IMGUI_WINDOW:SetColor("TitleBgActive", Color.normalized_rgba(36, 28, 68, 1))

IMGUI_WINDOW:SetStyle("ScrollbarSize", 10)

-- TODO: add stuff to the menu bar
m = IMGUI_WINDOW:AddMainMenu()

-- options = m:AddMenu("Options")
-- options:AddItem("Adjust Setting 1").OnClick = function()
--     MCMDebug(2, "Adjusting setting 1")
-- end
-- options:AddItem("Reset to Defaults").OnClick = function()
--     MCMDebug(2, "Resetting options to defaults")
-- end

help = m:AddMenu("Help")
help:AddItem("About").OnClick = function()
    -- Code to show about information
    MCMDebug(2, "Showing about information")
end
help:AddItem("Troubleshooting").OnClick = function()
    -- Code to show troubleshooting information
    MCMDebug(2, "Showing troubleshooting information")
end
