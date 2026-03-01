---@class OpenOnStartHelper
OpenOnStartHelper = {}

--- Checks if the Character Creation system/UI is currently active on the client.
--- @return boolean
function OpenOnStartHelper:IsCharacterCreationSystemActive()
    local ccStates = Ext.Entity.GetAllEntitiesWithComponent("ClientCCDefinitionState")
    return ccStates ~= nil and #ccStates > 0
end

--- Returns whether MCM should auto-open on startup.
--- Respects open_on_start and suppresses auto-open during character creation while in-game.
--- @return boolean
function OpenOnStartHelper:ShouldOpenOnStart()
    local shouldOpenOnStart = MCMAPI:GetSettingValue("open_on_start", ModuleUUID)
    if shouldOpenOnStart == nil then
        shouldOpenOnStart = true
    end

    if not shouldOpenOnStart then
        return false
    end

    if Ext.Utils.GetGameState() ~= Ext.Enums.ClientGameState["Menu"] and self:IsCharacterCreationSystemActive() then
        return false
    end

    return true
end

return OpenOnStartHelper
