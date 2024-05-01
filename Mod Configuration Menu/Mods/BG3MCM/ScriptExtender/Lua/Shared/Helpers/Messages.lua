-- NOTE: this might be used to handle localization in the future, but at least during the alpha it won't be used. (this is taken from ISF)

---@class HelperMessages: Helper
Messages = _Class:Create("HelperMessages", Helper)

Messages.Handles = {
    -- mailbox_added_to_camp_chest = "h7b114c9fge69cg4fbfg9389g430a24de7726",
}

function Messages.ResolveMessagesHandles()
    local messages = {
        -- mailbox_added_to_camp_chest = Ext.Loca.GetTranslatedString("h7b114c9fge69cg4fbfg9389g430a24de7726"),
    }
    return messages
end

Messages.ResolvedMessages = Messages.ResolveMessagesHandles()
