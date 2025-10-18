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

--- Add a tooltip to a button
---@param imguiObject ExtuiStyledRenderable
---@param tooltipText string
---@param uuid string
---@return ExtuiStyledRenderable | nil
function IMGUIHelpers.AddTooltip(imguiObject, tooltipText, uuid)
    if not imguiObject then
        MCMWarn(1, "Tried to add a tooltip to a nil object")
        return nil
    end
    if not tooltipText then
        tooltipText = ""
        return nil
    end
    if not uuid then
        MCMWarn(1, "Mod UUID not provided for tooltip")
        return nil
    end
    if not imguiObject.Tooltip then
        MCMWarn(1, "Tried to add a tooltip to an object with no tooltip support")
        return nil
    end

    local success, imguiObjectTooltip = xpcall(function()
        local tt = imguiObject:Tooltip()
        tt.IDContext = uuid .. "_TOOLTIP"
        local preprocessedTooltip = VCString:ReplaceBrWithNewlines(VCString:AddNewlinesAfterPeriods(tooltipText))
        tt:AddText(preprocessedTooltip)
        tt:SetColor("Border", UIStyle.UnofficialColors["TooltipBorder"])
        tt:SetStyle("WindowPadding", 15, 15)
        tt:SetStyle("PopupBorderSize", 2)
        tt:SetColor("BorderShadow", { 0, 0, 0, 0.4 })
        return tt
    end, function(err)
        MCMError(1, "Error creating tooltip: " .. tostring(err))
        return nil
    end)

    if not success then
        imguiObjectTooltip = nil
    end

    return imguiObjectTooltip
end
