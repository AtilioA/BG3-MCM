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
---@param tooltipText string|nil Text to display; may be empty to create an unpopulated tooltip for callers that add children themselves
---@param uuid string
---@return ExtuiStyledRenderable | nil
function IMGUIHelpers.AddTooltip(imguiObject, tooltipText, uuid)
    if not imguiObject then
        MCMWarn(1, "Tried to add a tooltip to a nil object")
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
        if tooltipText and tooltipText ~= "" then
            -- Blank space to offset from cursor
            local preprocessedTooltip = VCString:ReplaceBrWithNewlines(VCString:AddNewlinesAfterPeriods("   " ..
            tooltipText))
            tt:AddText(preprocessedTooltip)
        end
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

--- Mod-scoped identity for a setting, used to namespace per-setting UI resources (tooltip windows), so mods with equal setting IDs do not collide.
---@param setting BlueprintSetting
---@return string
function IMGUIHelpers.GetModScopedSettingId(setting)
    local modUUID = setting:GetModUUID()
    return modUUID .. "_" .. setting:GetId()
end

--- Resolve the setting's tooltip text (localized when a handle is present) and attach it to the widget.
---@param widget ExtuiStyledRenderable
---@param setting BlueprintSetting
---@return ExtuiStyledRenderable|nil tooltip Nil when the setting has no tooltip
function IMGUIHelpers.AddSettingTooltip(widget, setting)
    if setting:GetTooltip() == nil or setting:GetTooltip() == "" then
        MCMDebug(2, "No tooltip found for setting: " .. setting:GetId())
        return
    end

    local tooltipText = setting:GetTooltip()
    local translatedTooltip = nil
    if setting:GetHandles().TooltipHandle ~= nil then
        translatedTooltip = Ext.Loca.GetTranslatedString(setting:GetHandles().TooltipHandle)
    end
    if translatedTooltip ~= nil and translatedTooltip ~= "" then
        tooltipText = translatedTooltip
    end

    return IMGUIHelpers.AddTooltip(widget, tooltipText, IMGUIHelpers.GetModScopedSettingId(setting) .. "_TOOLTIP")
end

--- Attach a tooltip to a slider/drag widget: the setting tooltip when present, otherwise an unpopulated tooltip that always receives the value range and the manual-input hint below.
---@param widget ExtuiStyledRenderable
---@param setting BlueprintSetting
---@param numberFormat string Lua format for Options.Min/Max, e.g. "%s" for integers or "%.2f" for floats
---@return ExtuiStyledRenderable|nil tooltip
function IMGUIHelpers.AddTooltipWithRange(widget, setting, numberFormat)
    local tt = IMGUIHelpers.AddSettingTooltip(widget, setting)

    if not tt then
        tt = IMGUIHelpers.AddTooltip(widget, "", IMGUIHelpers.GetModScopedSettingId(setting))
    end

    if not tt then
        return
    end

    -- Match AddTooltip cursor offset on first line
    local isFirstLine = table.isEmpty(tt.Children)

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", UIStyle.UnofficialColors["TooltipSeparator"])
    end

    local rangeText = VCString:InterpolateLocalizedMessage("h3914d63b7ccb425f950cea47eca955ad9788",
        string.format(numberFormat, setting:GetOptions().Min), string.format(numberFormat, setting:GetOptions().Max))
    tt:AddText((isFirstLine and "   " or "") .. rangeText)

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", UIStyle.UnofficialColors["TooltipSeparator"])
    end

    tt:AddText(Ext.Loca.GetTranslatedString("h0dfee4b6ba51423da77eaa53e1961ade059f"))

    return tt
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
