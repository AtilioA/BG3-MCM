UIStyle = {}
-- Thanks Aahz for the original code

UIStyle.UnofficialColors = {
    ["TooltipBorder"] = Color.HEXToRGBA("#99724c"),
    ["BoxColor"] = Color.NormalizedRGBA(46, 38, 38, 1),
    ["BoxHoverColor"] = Color.NormalizedRGBA(97, 66, 54, 0.78),
    ["BoxActiveColor"] = Color.NormalizedRGBA(30.60, 204, 237.15, 0.33),
}

UIStyle.Colors = {
    ["Border"] = Color.NormalizedRGBA(82, 60, 40, 0.1),
    ["BorderShadow"] = Color.NormalizedRGBA(18, 18, 18, 0.78),
    ["Button"] = Color.NormalizedRGBA(117, 102, 74, 0.5),
    ["ButtonActive"] = Color.NormalizedRGBA(183, 122, 81, 0.7),
    ["ButtonHovered"] = Color.NormalizedRGBA(163, 102, 71, 0.5),
    ["CheckMark"] = Color.NormalizedRGBA(219, 201, 173, 0.78),
    ["ChildBg"] = Color.NormalizedRGBA(29, 27, 27, 0.4),
    ["DragDropTarget"] = Color.NormalizedRGBA(18, 18, 18, 0.78),
    ["FrameBg"] = Color.NormalizedRGBA(24, 19, 17, 1),
    ["FrameBgActive"] = Color.NormalizedRGBA(34, 27, 22, 1),
    ["FrameBgHovered"] = Color.NormalizedRGBA(34, 27, 22, 1),
    ["Header"] = Color.NormalizedRGBA(92, 76, 69, 0.76),
    ["HeaderActive"] = UIStyle.UnofficialColors.BoxActiveColor,
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
    ["ResizeGripActive"] = UIStyle.UnofficialColors.BoxActiveColor,
    ["ResizeGripHovered"] = UIStyle.UnofficialColors.BoxHoverColor,
    ["ScrollbarBg"] = UIStyle.UnofficialColors.BoxColor,
    ["ScrollbarGrab"] = Color.NormalizedRGBA(92, 76, 69, 0.76),
    ["ScrollbarGrabActive"] = UIStyle.UnofficialColors.BoxActiveColor,
    ["ScrollbarGrabHovered"] = Color.NormalizedRGBA(120, 89, 71, 0.86),
    ["Separator"] = Color.NormalizedRGBA(82, 60, 40, 1),
    ["SeparatorActive"] = Color.NormalizedRGBA(175, 135, 104, 1),
    ["SeparatorHovered"] = Color.NormalizedRGBA(125, 96, 74, 1),
    ["SliderGrab"] = Color.NormalizedRGBA(242, 209, 153, 0.14),
    ["SliderGrabActive"] = Color.NormalizedRGBA(133, 133, 64, 0.3),
    ["Tab"] = UIStyle.UnofficialColors.BoxColor,
    ["TabActive"] = UIStyle.UnofficialColors.BoxActiveColor,
    ["TabHovered"] = UIStyle.UnofficialColors.BoxHoverColor,
    ["TableBorderLight"] = Color.NormalizedRGBA(143, 117, 66, 0.78),
    ["TableBorderStrong"] = Color.NormalizedRGBA(168, 94, 23, 0.78),
    ["TableHeaderBg"] = Color.NormalizedRGBA(184, 158, 110, 0.47),
    ["TableRowBg"] = Color.NormalizedRGBA(161, 176, 87, 0.25),
    ["TableRowBgAlt"] = Color.NormalizedRGBA(133, 74, 38, 0.25),
    ["TabUnfocused"] = Color.NormalizedRGBA(13, 13, 13, 0.78),
    ["TabUnfocusedActive"] = Color.NormalizedRGBA(13, 13, 13, 0.78),
    ["Text"] = Color.NormalizedRGBA(219, 201, 173, 0.78),
    ["TextDisabled"] = Color.NormalizedRGBA(219, 201, 173, 0.18),
    ["TextSelectedBg"] = Color.NormalizedRGBA(145, 54, 54, 0.43),
    ["TitleBg"] = Color.NormalizedRGBA(18, 18, 18, 1.0),
    ["TitleBgActive"] = UIStyle.UnofficialColors.BoxColor,
    ["TitleBgCollapsed"] = Color.NormalizedRGBA(13, 13, 13, 0.75),
    ["WindowBg"] = Color.NormalizedRGBA(18, 18, 18, 0.9),
}

UIStyle.Colors["Border"] = UIStyle.Colors["ScrollbarGrab"]

UIStyle.TextStyles = {
    ["SettingTitle"] = Color.NormalizedRGBA(250, 240, 220, 1.0),
    ["SettingDescription"] = Color.NormalizedRGBA(190, 170, 150, 1.0),
}

-- Applied locally so the global frame style remains unchanged.
UIStyle.InputStyles = {
    ["default"] = {
        ["FrameBorderSize"] = 1.0,
    },
    ["checkbox"] = {
        ["FrameBorderSize"] = 1.0,
        ["FrameRounding"] = 0.0,
    },
    ["combo"] = {
        ["FrameBorderSize"] = 1.0,
        ["FrameRounding"] = 50.0,
        ["FramePadding"] = { 8.0, 4.0 },
    },
    ["slider_int"] = {
        ["FrameBorderSize"] = 1.0,
        ["FrameRounding"] = 50.0,
        ["GrabRounding"] = 50.0,
    },
}

UIStyle.InputStyleByType = {
    int = "default",
    float = "default",
    checkbox = "checkbox",
    text = "default",
    enum = "combo",
    slider_int = "slider_int",
    slider_float = "default",
    drag_int = "default",
    drag_float = "default",
    color_picker = "default",
    color_edit = "default",
}

UIStyle.Styles = {
    ["Alpha"]                   = 1.0,
    ["ButtonTextAlign"]         = 0.5, -- vec2?
    ["CellPadding"]             = 4.0, -- vec2?
    ["ChildBorderSize"]         = 1.0,
    ["ChildRounding"]           = 4.0,
    ["DisabledAlpha"]           = 0.5,
    ["FrameBorderSize"]         = 0.0,
    ["FramePadding"]            = 4.0, -- vec2?
    ["FrameRounding"]           = 3.0,
    ["GrabMinSize"]             = 20.0,
    ["GrabRounding"]            = 4.0,
    ["IndentSpacing"]           = 21.0,
    ["ItemInnerSpacing"]        = 4.0, -- vec2?
    ["ItemSpacing"]             = 8.0, -- vec2?
    ["PopupBorderSize"]         = 1.0,
    ["PopupRounding"]           = 2.0,
    ["ScrollbarRounding"]       = 9.0,
    ["ScrollbarSize"]           = 10.0,
    ["SelectableTextAlign"]     = 0.0, -- vec2?
    ["SeparatorTextAlign"]      = { 0.0, 0.5 },
    ["SeparatorTextBorderSize"] = 3,
    ["SeparatorTextPadding"]    = { 28.0, 6.0 },
    ["TabBarBorderSize"]        = 1.0,
    ["TabRounding"]             = 6.0,
    ["WindowBorderSize"]        = 2,
    ["WindowMinSize"]           = 32.0, -- vec2?
    ["WindowPadding"]           = 3.0,
    ["WindowRounding"]          = 4.0,
    ["WindowTitleAlign"]        = 0.5, -- vec2?
}

return UIStyle
