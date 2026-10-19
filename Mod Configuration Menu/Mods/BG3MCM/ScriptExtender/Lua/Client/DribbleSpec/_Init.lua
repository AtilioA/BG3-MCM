-- Client-only tests; Shared/DribbleSpec/_Init.lua registers the D globals first.
if Mods.Dribbles then
    Ext.Require("Client/DribbleSpec/KeybindingCaptureSession.test.lua")
    Ext.Require("Client/DribbleSpec/KeybindingConflicts.test.lua")
    Ext.Require("Client/DribbleSpec/SettingWrite.test.lua")
    Ext.Require("Client/DribbleSpec/Keybindings.test.lua")
    Ext.Require("Client/DribbleSpec/VisibilityManager.test.lua")
end
