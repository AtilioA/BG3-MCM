RequireFiles("Shared/Helpers/MCM/GlobalTable/", {
  "MetatableInjection",
  "TableInjector",
  "MCMAPIMethods"
})

local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")
TableInjector.Initialize()
