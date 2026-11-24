-- Server-only tests; Shared/DribbleSpec/_Init.lua registers the D globals first.
if Mods.Dribbles then
    Ext.Require("Server/DribbleSpec/MCMAPIServer.test.lua")
    Ext.Require("Server/DribbleSpec/StorageSyncServer.test.lua")
end
