RequireFiles("Shared/Helpers/MCM/GlobalTable/", {
  "MetatableInjection",
  "TableInjector",
  "MCMAPIMethods"
})

local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")
TableInjector.Initialize()

local InternalAPIGuard = Ext.Require("Shared/Helpers/MCM/GlobalTable/InternalAPIGuard.lua")
InternalAPIGuard.Activate()
