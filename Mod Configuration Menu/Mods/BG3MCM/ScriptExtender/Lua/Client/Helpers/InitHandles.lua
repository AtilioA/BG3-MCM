InitHandles = {}

local disabledMCMDefaultLabelHandle = "h6e8c611890eb4a589f1777131bebe79a2fcd"
local MCMActualLabel = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")
Ext.Loca.UpdateTranslatedString(disabledMCMDefaultLabelHandle, MCMActualLabel)

function InitHandles:UpdateDynamicMCMWindowHandles()
    local keybinding = MCMAPI:GetSettingValue("toggle_mcm_sidebar_keybinding", ModuleUUID)
    if not keybinding or not keybinding.Keyboard then
        return
    end

    VCString:InterpolateLocalizedMessage("h4f7f7d8278084ab49b90d31af3f3810eegc7",
        KeyPresentationMapping:GetKBViewKey(keybinding.Keyboard),
        { updateHandle = true })
end

return InitHandles
