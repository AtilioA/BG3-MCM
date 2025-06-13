KeyPresentationMapping = {}

KeyPresentationMapping.Mapping = {
    -- Modifiers
    LALT           = "Left Alt",
    RALT           = "Right Alt",
    LCTRL          = "Left Ctrl",
    RCTRL          = "Right Ctrl",
    LSHIFT         = "Left Shift",
    RSHIFT         = "Right Shift",
    LGUI           = "Left Win/Meta",
    RGUI           = "Right Win/Meta",
    CAPSLOCK       = "Caps Lock",
    NUMLOCKCLEAR   = "Num Lock",
    SCROLLLOCK     = "Scroll Lock",

    -- Directional / Navigation
    LEFT           = "Left Arrow",
    RIGHT          = "Right Arrow",
    UP             = "Up Arrow",
    DOWN           = "Down Arrow",

    HOME           = "Home",
    END            = "End",
    PAGEUP         = "Page Up",
    PAGEDOWN       = "Page Down",
    INSERT         = "Insert",
    DELETE         = "Delete",
    DEL            = "Del",

    -- Function Keys
    F1             = "F1",
    F2             = "F2",
    F3             = "F3",
    F4             = "F4",
    F5             = "F5",
    F6             = "F6",
    F7             = "F7",
    F8             = "F8",
    F9             = "F9",
    F10            = "F10",
    F11            = "F11",
    F12            = "F12",
    F13            = "F13",
    F14            = "F14",
    F15            = "F15",
    F16            = "F16",
    F17            = "F17",
    F18            = "F18",
    F19            = "F19",
    F20            = "F20",
    F21            = "F21",
    F22            = "F22",
    F23            = "F23",
    F24            = "F24",

    -- Alphanumeric Keys
    A              = "A",
    B              = "B",
    C              = "C",
    D              = "D",
    E              = "E",
    F              = "F",
    G              = "G",
    H              = "H",
    I              = "I",
    J              = "J",
    K              = "K",
    L              = "L",
    M              = "M",
    N              = "N",
    O              = "O",
    P              = "P",
    Q              = "Q",
    R              = "R",
    S              = "S",
    T              = "T",
    U              = "U",
    V              = "V",
    W              = "W",
    X              = "X",
    Y              = "Y",
    Z              = "Z",

    -- Punctuation and Symbols
    BACKSLASH      = "\\",
    COMMA          = ",",
    PERIOD         = ".",
    MINUS          = "-",
    EQUALS         = "=",
    SEMICOLON      = ";",
    APOSTROPHE     = "'",
    LEFTBRACKET    = "[",
    RIGHTBRACKET   = "]",
    GRAVE          = "`",
    SLASH          = "/",
    NONUSBACKSLASH = "\\",

    -- Numbers
    NUM_0          = "0",
    NUM_1          = "1",
    NUM_2          = "2",
    NUM_3          = "3",
    NUM_4          = "4",
    NUM_5          = "5",
    NUM_6          = "6",
    NUM_7          = "7",
    NUM_8          = "8",
    NUM_9          = "9",

    -- Special Keys
    RETURN         = "Enter",
    ESCAPE         = "Esc",
    SPACE          = "Space",
    TAB            = "Tab",
    BACKSPACE      = "Backspace",
    PRINTSCREEN    = "Print Screen",
    PAUSE          = "Pause",
    APPLICATION    = "Menu",
    -- Additional SDL scan codes can be mapped as needed.

    -- Some AC keys (Application Control keys)
    AC_BACK        = "Back",
    AC_BOOKMARKS   = "Bookmarks",
    AC_FORWARD     = "Forward",
    AC_HOME        = "Home",
    AC_REFRESH     = "Refresh",
    AC_SEARCH      = "Search",
    AC_STOP        = "Stop",

    -- Keypad keys (commonly prefixed with KP_)
    KP_0           = "Keypad 0",
    KP_1           = "Keypad 1",
    KP_2           = "Keypad 2",
    KP_3           = "Keypad 3",
    KP_4           = "Keypad 4",
    KP_5           = "Keypad 5",
    KP_6           = "Keypad 6",
    KP_7           = "Keypad 7",
    KP_8           = "Keypad 8",
    KP_9           = "Keypad 9",
    KP_ENTER       = "Keypad Enter",
    KP_PLUS        = "Keypad +",
    KP_MINUS       = "Keypad -",
    KP_MULTIPLY    = "Keypad *",
    KP_DIVIDE      = "Keypad /",
    KP_PERIOD      = "Keypad .",
    KP_EQUALS      = "Keypad =",
}

--- Returns the presentation string for a given SDL key.
--- @param sdlKey string The raw SDL key value.
--- @return string The view string; if no mapping is found, returns the original value.
function KeyPresentationMapping:GetViewKey(sdlKey)
    if not sdlKey then
        MCMWarn(1, "No SDL key provided. Defaulting to unassigned.")
        return UNASSIGNED_KEYBOARD_MOUSE_STRING
    end

    return self.Mapping[sdlKey:upper()] or sdlKey
end

--- Returns the presentation string for a given SDL key.
--- @param keybinding table A table containing "Key" and "ModifierKeys".
--- @return string The view string; if no mapping is found, returns the original value.
function KeyPresentationMapping:GetKBViewKey(keybinding)
    if not keybinding or (not keybinding.Key and not keybinding.ModifierKeys) or
        (type(keybinding.Key) == "string" and keybinding.Key == "") then
        return UNASSIGNED_KEYBOARD_MOUSE_STRING
    end

    local keyStr = ""
    if keybinding.Key then
        keyStr = "[" .. (self.Mapping[keybinding.Key:upper()] or keybinding.Key) .. "]"
    end

    local modifiers = {}
    if keybinding.ModifierKeys then
        for _, modifier in ipairs(keybinding.ModifierKeys) do
            if modifier and modifier ~= "" then
                table.insert(modifiers, "[" .. (self.Mapping[modifier:upper()] or modifier) .. "]")
            end
        end
    end

    return table.concat(modifiers, " + ") .. (next(modifiers) and " + " or "") .. keyStr
end

function KeyPresentationMapping:GetKBViewKeyForSetting(keybinding_setting_id, modUUID)
    local keybinding = MCMAPI:GetSettingValue(keybinding_setting_id, modUUID)
    if not keybinding or not keybinding.Keyboard then
        return UNASSIGNED_KEYBOARD_MOUSE_STRING
    end
    return self:GetKBViewKey(keybinding.Keyboard)
end

function KeyPresentationMapping:GetViewKeyForSetting(settingId, modUUID)
    -- TODO: determine if this is a mouse or keyboard binding, etc and return the appropriate value
    return self:GetKBViewKeyForSetting(settingId, modUUID)
end

return KeyPresentationMapping
