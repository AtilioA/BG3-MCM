IMGUIHelpers = {}

--- Set the font for a window
--- @param window ExtuiWindow The window to set the font for
--- @param family string|nil The font family
--- @param size string|nil The font size
function IMGUIHelpers.SetFont(window, family, size)
    if not window then
        MCMWarn(1, "Window is nil, skipping font setting.")
        return
    end
    if not family or not size then
        MCMWarn(1, "Family or size is nil, skipping font setting.")
        return
    end

    local fontName = Font.GetFontNameWithSizeSuffix(family, size)
    if not fontName then
        MCMWarn(1, "Failed to get font name for " .. family .. " " .. size)
        return
    end

    Font.EnsureFontLoaded(family, size)
    window.Font = fontName
end
