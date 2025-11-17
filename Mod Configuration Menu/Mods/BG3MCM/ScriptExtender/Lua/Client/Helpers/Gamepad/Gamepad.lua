Gamepad = {}

function Gamepad.IsHostUsingGamepad()
    return Gamepad.IsPlayerUsingGamepad(0)
end

function Gamepad.IsPlayerUsingGamepad(playerIndex)
    local inputManager = Ext.Input.GetInputManager()
    if not inputManager then
        MCMWarn(1, "inputManager is nil")
        return false
    end
    playerIndex = playerIndex or 0 -- Default to host/player 1 (index 0)

    -- Check if player has a device assigned
    return inputManager.PlayerDevices[playerIndex + 1] == 1

    -- Check the device ID
    -- local deviceId = inputManager.PlayerDeviceIDs[playerIndex + 1]
    -- return deviceId ~= 65535 and deviceId ~= 256 and deviceId ~= 1
end

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
