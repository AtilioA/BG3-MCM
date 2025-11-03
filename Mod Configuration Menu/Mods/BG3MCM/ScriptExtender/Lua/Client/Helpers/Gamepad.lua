Gamepad = {}

function Gamepad.IsEntityControllerMode(entity)
    if not Ext.IsClient() then
        MCMWarn(1, "isEntityControllerMode called on server")
        return false
    end

    if not entity or not entity.ClientCharacter or not entity.ClientCharacter.InputController then
        MCMWarn(1, "isEntityControllerMode called on invalid entity")
        return false
    end

    local controllerFlag = Ext.Enums.ClientInputControllerFlags.ControllerMode[1]
    return entity.ClientCharacter.InputController.Flags[controllerFlag]
end

return Gamepad
