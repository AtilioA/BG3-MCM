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
        MCMWarn(1, "Failed to get font name for %s %s", family, size)
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
    if not tooltipText or tooltipText == "" then
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

    -- Blank space to offset from cursor
    tooltipText = "   " .. tooltipText

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
        MCMError(1, "Error creating tooltip: %s", err)
        return nil
    end)

    if not success then
        imguiObjectTooltip = nil
    end

    return imguiObjectTooltip
end

--- Apply a named input style without changing the global style.
---@param element ExtuiStyledRenderable
---@param styleName string
---@param onlyIfUnset? boolean
function IMGUIHelpers:ApplyInputStyle(element, styleName, onlyIfUnset)
    self:ApplyStyleVars(element, UIStyle.InputStyles[styleName], onlyIfUnset)
end

--- Apply style variables to an IMGUI element.
---@param element ExtuiStyledRenderable
---@param styles table|nil
---@param onlyIfUnset? boolean
function IMGUIHelpers:ApplyStyleVars(element, styles, onlyIfUnset)
    if not styles then
        return
    end

    for k, v in pairs(styles) do
        if not onlyIfUnset or element:GetStyle(k) == nil then
            if type(v) == "table" then
                element:SetStyle(k, v[1], v[2])
            else
                element:SetStyle(k, v)
            end
        end
    end
end

--- Apply a named text style.
---@param element ExtuiStyledRenderable
---@param styleName string
---@param onlyIfUnset? boolean
function IMGUIHelpers:ApplyTextStyle(element, styleName, onlyIfUnset)
    local color = UIStyle.TextStyles[styleName]
    if color and (not onlyIfUnset or element:GetColor("Text") == nil) then
        element:SetColor("Text", color)
    end
end

--- Apply MCM styles to controls created by a custom MCM tab.
---@param element ExtuiStyledRenderable|nil
function IMGUIHelpers:ApplyCustomTabStyles(element)
    if not element then
        return
    end

    local objectType = Ext.Types.GetObjectType(element) or ""
    local customTabStyles = UIStyle.CustomTabStyles
    local inputStyleName = customTabStyles.InputStyles[objectType]
    if inputStyleName then
        self:ApplyInputStyle(element, inputStyleName, true)
    end

    local textStyleName = customTabStyles.TextStyles[objectType] or (inputStyleName and "SettingTitle")
    if textStyleName then
        self:ApplyTextStyle(element, textStyleName, true)
    end

    if customTabStyles.ParentTypes[objectType] then
        for _, child in ipairs(element.Children) do
            self:ApplyCustomTabStyles(child)
        end
    end
end

--- Apply default styles to an IMGUI element
---@param element ExtuiStyledRenderable
function IMGUIHelpers:ApplyDefaultStylesToIMGUIElement(element)
    for k, v in pairs(UIStyle.Colors) do
        element:SetColor(k, v)
    end
    self:ApplyStyleVars(element, UIStyle.Styles)
end
