---@class HelperMessages: Helper
Messages = _Class:Create("HelperMessages", Helper)

Messages.Handles = {
    -- mailbox_added_to_camp_chest = "h7b114c9fge69cg4fbfg9389g430a24de7726",
    -- mailbox_moved_to_camp_chest = "h7b114c9fge69cg4fbfg9389g430a24de7726",
    -- mod_shipped_item_to_mailbox = "h1baaa2bdgfce5g4685g9b67g9055ee45c1dc",
    -- uninstall_should_move_out_of_mailboxes = "h83df85eeg6476g4cf3g8c59g95499388910d",
    -- uninstall_confirmation_prompt = "h93f3b749g83deg4eaagb114g0bafaf8d15bc",
    -- uninstall_completed = "h5f8290f2gf829g4170gbf39gc6088811945a",
}

function Messages.ResolveMessagesHandles()
    local messages = {
        -- mailbox_added_to_camp_chest = Ext.Loca.GetTranslatedString("h7b114c9fge69cg4fbfg9389g430a24de7726"),
        -- mailbox_moved_to_camp_chest = Ext.Loca.GetTranslatedString("h7b114c9fge69cg4fbfg9389g430a24de7726"),
        -- uninstall_should_move_out_of_mailboxes = Ext.Loca.GetTranslatedString("h83df85eeg6476g4cf3g8c59g95499388910d"),
        -- uninstall_confirmation_prompt = Ext.Loca.GetTranslatedString("h93f3b749g83deg4eaagb114g0bafaf8d15bc"),
        -- uninstall_completed = Ext.Loca.GetTranslatedString("h5f8290f2gf829g4170gbf39gc6088811945a"),
    }
    return messages
end

Messages.ResolvedMessages = Messages.ResolveMessagesHandles()
