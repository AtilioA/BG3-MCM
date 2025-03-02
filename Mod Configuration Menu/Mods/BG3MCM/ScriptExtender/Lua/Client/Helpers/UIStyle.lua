UIStyle = {}
-- Thanks Aahz for the original code

local BoxColor = Color.NormalizedRGBA(46, 38, 38, 0.78)
local BoxHoverColor = Color.NormalizedRGBA(97, 66, 54, 0.78);
local BoxActiveColor = Color.NormalizedRGBA(30.60, 204, 237.15, 0.33)

UIStyle.UnofficialColors = {
    ["TooltipBorder"] = Color.HEXToRGBA("#99724c"),
}

UIStyle.Colors = {
    ["Border"] = Color.NormalizedRGBA(61, 38, 20, 0.2),
    ["BorderShadow"] = Color.NormalizedRGBA(18, 18, 18, 0.78),
    ["Button"] = Color.NormalizedRGBA(117, 102, 74, 0.5),
    ["ButtonActive"] = Color.NormalizedRGBA(183, 122, 81, 0.7),
    ["ButtonHovered"] = Color.NormalizedRGBA(163, 102, 71, 0.5),
    ["CheckMark"] = Color.NormalizedRGBA(219, 201, 173, 0.78),
    ["ChildBg"] = Color.NormalizedRGBA(31, 28, 28, 0.4),
    ["DragDropTarget"] = Color.NormalizedRGBA(18, 18, 18, 0.78),
    ["FrameBg"] = BoxColor,
    ["FrameBgActive"] = BoxActiveColor,
    ["FrameBgHovered"] = BoxHoverColor,
    ["Header"] = Color.NormalizedRGBA(92, 76, 69, 0.76),
    ["HeaderActive"] = BoxActiveColor,
    ["HeaderHovered"] = Color.NormalizedRGBA(105, 71, 56, 0.86),
    ["MenuBarBg"] = Color.NormalizedRGBA(18, 18, 18, 0.47),
    ["ModalWindowDimBg"] = Color.NormalizedRGBA(46, 38, 38, 0.73),
    ["NavHighlight"] = Color.NormalizedRGBA(140, 0, 0, 0.78),
    ["NavWindowingDimBg"] = Color.NormalizedRGBA(18, 18, 18, 0.78),
    ["NavWindowingHighlight"] = Color.NormalizedRGBA(140, 0, 0, 0.78),
    ["PlotHistogram"] = Color.NormalizedRGBA(219, 201, 173, 0.63),
    ["PlotHistogramHovered"] = Color.NormalizedRGBA(105, 71, 56, 1.0),
    ["PlotLines"] = Color.NormalizedRGBA(219, 201, 173, 0.63),
    ["PlotLinesHovered"] = Color.NormalizedRGBA(105, 71, 56, 1.0),
    ["PopupBg"] = Color.HEXToRGBA("#1A1A1A"),
    ["ResizeGrip"] = Color.NormalizedRGBA(242, 209, 153, 0.15),
    ["ResizeGripActive"] = BoxActiveColor,
    ["ResizeGripHovered"] = BoxHoverColor,
    ["ScrollbarBg"] = BoxColor,
    ["ScrollbarGrab"] = Color.NormalizedRGBA(92, 76, 69, 0.76),
    ["ScrollbarGrabActive"] = BoxActiveColor,
    ["ScrollbarGrabHovered"] = Color.NormalizedRGBA(120, 89, 71, 0.86),
    ["Separator"] = BoxColor,
    ["SeparatorActive"] = BoxActiveColor,
    ["SeparatorHovered"] = BoxHoverColor,
    ["SliderGrab"] = Color.NormalizedRGBA(242, 209, 153, 0.14),
    ["SliderGrabActive"] = Color.NormalizedRGBA(133, 133, 64, 0.3),
    ["Tab"] = BoxColor,
    ["TabActive"] = BoxActiveColor,
    ["TabHovered"] = BoxHoverColor,
    ["TableBorderLight"] = Color.NormalizedRGBA(143, 117, 66, 0.78),
    ["TableBorderStrong"] = Color.NormalizedRGBA(168, 94, 23, 0.78),
    ["TableHeaderBg"] = Color.NormalizedRGBA(184, 158, 110, 0.47),
    ["TableRowBg"] = Color.NormalizedRGBA(161, 176, 87, 0.43),
    ["TableRowBgAlt"] = Color.NormalizedRGBA(133, 74, 38, 0.43),
    ["TabUnfocused"] = Color.NormalizedRGBA(13, 13, 13, 0.78),
    ["TabUnfocusedActive"] = Color.NormalizedRGBA(13, 13, 13, 0.78),
    ["Text"] = Color.NormalizedRGBA(219, 201, 173, 0.78),
    ["TextDisabled"] = Color.NormalizedRGBA(219, 201, 173, 0.18),
    ["TextSelectedBg"] = Color.NormalizedRGBA(145, 54, 54, 0.43),
    ["TitleBg"] = Color.NormalizedRGBA(18, 18, 18, 1.0),
    ["TitleBgActive"] = BoxColor,
    ["TitleBgCollapsed"] = Color.NormalizedRGBA(13, 13, 13, 0.75),
    ["WindowBg"] = Color.NormalizedRGBA(18, 18, 18, 0.9),
}

UIStyle.Styles = {
    ["Alpha"]                   = 1.0,
    ["ButtonTextAlign"]         = 0.5, -- vec2?
    ["CellPadding"]             = 4,   -- vec2?
    ["ChildBorderSize"]         = 1.0,
    ["ChildRounding"]           = 4.0,
    ["DisabledAlpha"]           = 0.5,
    ["FrameBorderSize"]         = 0.0,
    ["FramePadding"]            = 4.0, -- vec2?
    ["FrameRounding"]           = 3.0,
    ["GrabMinSize"]             = 16.0,
    ["GrabRounding"]            = 4.0,
    ["IndentSpacing"]           = 21.0,
    ["ItemInnerSpacing"]        = 4.0, -- vec2?
    ["ItemSpacing"]             = 8.0, -- vec2?
    ["PopupBorderSize"]         = 1.0,
    ["PopupRounding"]           = 2.0,
    ["ScrollbarRounding"]       = 9.0,
    ["ScrollbarSize"]           = 10.0,
    ["SelectableTextAlign"]     = 0.0,  -- vec2?
    ["SeparatorTextAlign"]      = 0.5,  -- vec2?
    ["SeparatorTextBorderSize"] = 4.0,
    ["SeparatorTextPadding"]    = 20.0, -- vec2?
    ["TabBarBorderSize"]        = 1.0,
    ["TabRounding"]             = 6.0,
    ["WindowBorderSize"]        = 2,
    ["WindowMinSize"]           = 32.0, -- vec2?
    -- ["WindowPadding"]           = { 10.0, 8.0 },
    ["WindowRounding"]          = 4.0,
    ["WindowTitleAlign"]        = 0.5, -- vec2?
}

function UIStyle:ApplyStyleToIMGUIElement(element)
    for k, v in pairs(self.Colors) do
        element:SetColor(k, v)
    end
    for k, v in pairs(self.Styles) do
        element:SetStyle(k, v)
    end
end

return UIStyle
