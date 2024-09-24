---@class NotificationStyle
---@field icon string The icon name to display in the notification
---@field borderColor table<number> The RGBA color of the border
---@field titleBgActive table<number> The RGBA color of the active title background
---@field titleBg table<number> The RGBA color of the title background
NotificationStyles =
{
    error = {
        icon = "ico_exclamation_01",
        borderColor = Color.HEXToRGBA("#FF2222"),
        titleBgActive = Color.NormalizedRGBA(255, 38, 38, 1),
        titleBg = Color.NormalizedRGBA(255, 10, 10, 0.67),
    },
    warning = {
        icon = "tutorial_warning_yellow",
        borderColor = Color.HEXToRGBA("#DD9922"),
        titleBgActive = Color.NormalizedRGBA(221, 153, 34, 1),
        titleBg = Color.NormalizedRGBA(255, 140, 0, 0.67)
    },
    info = {
        icon = "talkNotice_h",
        borderColor = Color.HEXToRGBA("#22CCFF"),
        titleBgActive = Color.NormalizedRGBA(0, 100, 255, 1),
        titleBg = Color.NormalizedRGBA(0, 125, 255, 0.67),
    },
    success = {
        icon = "ico_classRes_luck",
        borderColor = Color.HEXToRGBA("#22FF22"),
        titleBgActive = Color.NormalizedRGBA(0, 155, 0, 1),
        titleBg = Color.NormalizedRGBA(30, 155, 30, 0.67),
    }
}


--- Gets the border color style for the notification severity
---@param severity NotificationSeverity The severity of the notification
---@return table<number>
function NotificationStyles:GetStyleBorderColor(severity)
    local style = self[severity]
    return style.borderColor
end

--- Gets the icon style for the notification severity
---@param severity NotificationSeverity The severity of the notification
---@return string
function NotificationStyles:GetStyleIcon(severity)
    local style = self[severity]
    return style.icon
end

--- Gets the title background style for the notification severity
---@param severity NotificationSeverity The severity of the notification
---@return table<number>
function NotificationStyles:GetStyleTitleBg(severity)
    local style = self[severity]
    return style.titleBg
end

--- Gets the active title background style for the notification severity
---@param severity NotificationSeverity The severity of the notification
---@return table<number>
function NotificationStyles:GetStyleTitleBgActive(severity)
    local style = self[severity]
    return style.titleBgActive
end

return NotificationStyles
