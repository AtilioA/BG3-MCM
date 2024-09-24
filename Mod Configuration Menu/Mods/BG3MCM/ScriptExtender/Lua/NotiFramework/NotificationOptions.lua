NotificationOptions = {}

---@alias NotificationSeverity
---| 'info'
---| 'success'
---| 'warning'
---| 'error'

---@class NotificationOptions
---@field duration integer|nil? The duration in seconds the notification will be displayed
---@field dontShowAgainButton boolean? If true, a 'Don't show again' button will be displayed
---@field dontShowAgainButtonCountdownInSec integer? The countdown time in seconds for the 'Don't show again' button
---@field showOnce boolean? If true, the notification will only be shown once

--- Preprocesses options to ensure they are valid and consistent
--- e.g.: duration should be at least the same as the countdown, showOnce should not be enabled if the button is enabled
---@param options NotificationOptions The options to preprocess
---@return NotificationOptions options The processed options
function NotificationOptions:PreprocessOptions(options)
    if not options then return {} end
    if options.duration and options.dontShowAgainButtonCountdownInSec then
        options.duration = math.max(options.duration, options.dontShowAgainButtonCountdownInSec)
    end

    options.showOnce = options.showOnce and not options.dontShowAgainButton
    return options
end

return NotificationOptions
