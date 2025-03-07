RequireFiles("Client/", {
    "MCMProxy",
    "Helpers/_Init",
    "Components/_Init",
    "MCMRendering",
    "IMGUIAPI",
    "SubscribedEvents",
})

local disabledMCMDefaultLabelHandle = "h6e8c611890eb4a589f1777131bebe79a2fcd"
local MCMActualLabel = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")
Ext.Loca.UpdateTranslatedString(disabledMCMDefaultLabelHandle, MCMActualLabel)

Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.ToState == Ext.Enums.ClientGameState["Menu"] then
        MCMDependencies:WarnAboutLoadOrderDependencies()
        MCMDependencies:WarnAboutNPAKM()
    end
end)
