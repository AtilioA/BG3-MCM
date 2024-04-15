-- Ext.Require("Shared/_Init.lua")
-- Ext.Require("Client/_Init.lua")

Ext.RegisterNetListener("MCM", function(_, payload)
    _D("NetMessage:")
    _D(Ext.Json.Parse(payload))
end)
