UIStyle = {}
-- Thanks Aahz for the original code

UIStyle.Colors = {
    ["Border"]                = Color.NormalizedRGBA(61.20, 38.25, 20.40, 0.00),
    ["BorderShadow"]          = Color.NormalizedRGBA(17.85, 17.85, 17.85, 0.78),
    ["Button"]                = Color.NormalizedRGBA(242.25, 209.1, 153, 0.14),
    ["ButtonActive"]          = Color.NormalizedRGBA(12.75, 73.95, 96.9, 1.00),
    ["ButtonHovered"]         = Color.NormalizedRGBA(30.60, 204, 237.15, 0.86),
    ["CheckMark"]             = Color.NormalizedRGBA(255, 180, 120, 1.00),
    ["ChildBg"]               = Color.NormalizedRGBA(51, 33.15, 63.75, 0.78),
    ["DragDropTarget"]        = Color.NormalizedRGBA(17.85, 17.85, 17.85, 0.78),
    ["FrameBg"]               = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.2),
    ["FrameBgActive"]         = Color.NormalizedRGBA(81.60, 61.20, 40.80, 0.75),
    ["FrameBgHovered"]        = Color.NormalizedRGBA(147.9, 114.75, 73.95, 1.0),
    ["Header"]                = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.20),
    ["HeaderActive"]          = Color.NormalizedRGBA(81.60, 61.20, 40.80, 1.00),
    ["HeaderHovered"]         = Color.NormalizedRGBA(140.25, 0, 0, 0.78),
    ["MenuBarBg"]             = Color.NormalizedRGBA(17.85, 17.85, 17.85, 0.47),
    ["ModalWindowDimBg"]      = Color.NormalizedRGBA(51, 33.15, 63.75, 0.73),
    ["NavHighlight"]          = Color.NormalizedRGBA(140.25, 0, 0, 0.78),
    ["NavWindowingDimBg"]     = Color.NormalizedRGBA(17.85, 17.85, 17.85, 0.78),
    ["NavWindowingHighlight"] = Color.NormalizedRGBA(140.25, 0, 0, 0.78),
    ["PlotHistogram"]         = Color.NormalizedRGBA(219.3, 201.45, 173.4, 0.63),
    ["PlotHistogramHovered"]  = Color.NormalizedRGBA(147.9, 114.75, 73.95, 1.00),
    ["PlotLines"]             = Color.NormalizedRGBA(219.3, 201.45, 173.4, 0.63),
    ["PlotLinesHovered"]      = Color.NormalizedRGBA(147.9, 114.75, 73.95, 1.00),
    ["PopupBg"]               = Color.NormalizedRGBA(17.85, 17.85, 17.85, 0.86),
    ["ResizeGrip"]            = Color.NormalizedRGBA(242.25, 209.1, 153, 0.04),
    ["ResizeGripActive"]      = Color.NormalizedRGBA(81.60, 61.20, 40.80, 1.00),
    ["ResizeGripHovered"]     = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.78),
    ["ScrollbarBg"]           = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.20),
    ["ScrollbarGrab"]         = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.75),
    ["ScrollbarGrabActive"]   = Color.NormalizedRGBA(147.9, 114.75, 73.95, 1.00),
    ["ScrollbarGrabHovered"]  = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.9),
    ["Separator"]             = Color.NormalizedRGBA(147.9, 114.75, 73.95, 1.00),
    ["SeparatorActive"]       = Color.NormalizedRGBA(81.60, 61.20, 40.80, 1.00),
    ["SeparatorHovered"]      = Color.NormalizedRGBA(147.9, 114.75, 73.95, 0.28),
    ["SliderGrab"]            = Color.NormalizedRGBA(242.25, 209.1, 153, 0.14),
    ["SliderGrabActive"]      = Color.NormalizedRGBA(81.60, 61.20, 40.80, 1.00),
    ["Tab"]                   = Color.NormalizedRGBA(81.60, 61.20, 40.80, 0.75),
    ["TabActive"]             = Color.NormalizedRGBA(12.75, 73.95, 96.9, 1),
    ["TabHovered"]            = Color.NormalizedRGBA(30.60, 204, 237.15, 0.78),
    ["TableBorderLight"]      = Color.NormalizedRGBA(142.8, 117.30, 66.3, 0.78),
    ["TableBorderStrong"]     = Color.NormalizedRGBA(168.3, 94.35, 22.95, 0.78),
    ["TableHeaderBg"]         = Color.NormalizedRGBA(209.1, 175.95, 119.85, 0.47),
    ["TableRowBg"]            = Color.NormalizedRGBA(160.65, 175.95, 86.7, 0.43),
    ["TableRowBgAlt"]         = Color.NormalizedRGBA(132.6, 73.95, 38.25, 0.43),
    ["TabUnfocused"]          = Color.NormalizedRGBA(12.75, 12.75, 12.75, 0.78),
    ["TabUnfocusedActive"]    = Color.NormalizedRGBA(12.75, 12.75, 12.75, 0.78),
    ["Text"]                  = Color.NormalizedRGBA(219.3, 201.45, 173.4, 1),
    ["TextDisabled"]          = Color.NormalizedRGBA(219.3, 201.45, 173.4, 0.28),
    ["TextSelectedBg"]        = Color.NormalizedRGBA(145.35, 53.55, 53.55, 0.43),
    ["TitleBg"]               = Color.NormalizedRGBA(17.85, 17.85, 17.85, 1.00),
    ["TitleBgActive"]         = Color.NormalizedRGBA(120.00, 90.00, 60.00, 0.90),
    ["TitleBgCollapsed"]      = Color.NormalizedRGBA(12.75, 12.75, 12.75, 0.75),
    ["WindowBg"]              = Color.NormalizedRGBA(32.6, 23.95, 18.25, 0.85),
}
UIStyle.Styles = {
    ["Alpha"]                   = 1.0,
    ["ButtonTextAlign"]         = 0.5, -- vec2?
    ["CellPadding"]             = 4,   -- vec2?
    ["ChildBorderSize"]         = 1.0,
    ["ChildRounding"]           = 4.0,
    ["DisabledAlpha"]           = 0.6,
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
    ["TabBarBorderSize"]        = 0.0,
    ["TabRounding"]             = 6.0,
    ["WindowBorderSize"]        = 2,
    ["WindowMinSize"]           = 32.0, -- vec2?
    ["WindowPadding"]           = 8,    -- vec2? (10,8 better?)
    ["WindowRounding"]          = 4.0,
    ["WindowTitleAlign"]        = 0.5,  -- vec2?
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
