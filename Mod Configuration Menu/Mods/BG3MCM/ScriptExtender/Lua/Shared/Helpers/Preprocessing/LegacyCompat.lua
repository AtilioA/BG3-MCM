---@class LegacyCompat
LegacyCompat = {
    Types = {
        list = true,
        keybinding = true,
    },
    CanonicalTypeAliases = {
        bool = "checkbox",
    },
    CoercedBooleanFields = {
        Optional = true,
        HiddenFromList = true,
        IsCollapsible = true,
        InlineTitle = true,
        Dynamic = true,
        Multiline = true,
        ShowSearchBar = true,
        ReadOnly = true,
        AllowReordering = true,
        ShouldTriggerOnKeyDown = true,
        ShouldTriggerOnKeyUp = true,
        ShouldTriggerOnRepeat = true,
        IsDeveloperOnly = true,
        BlockIfLevelNotStarted = true,
        PreventAction = true,
        AllowConflict = true,
        SkipCallback = true,
    },
}

return LegacyCompat
