while not Config do Wait(100) end
if not Config.Strings then Config.Strings = {} end
if Config.Language ~= 'en' then return end

Config.Strings['en'] = {
    ['error'] = 'Error',
    ['success'] = 'Success',

    ['invite_sent_title'] = 'Invite Sent',
    ['invite_sent_desc'] = 'Gang invite sent to player #%s',
    ['invite_failed'] = 'Failed to send gang invite: %s',

    ['already_in_gang'] = 'Player is already in a gang',
    ['invite_received_title'] = 'Gang Invite',
    ['invite_received_desc'] = '%s has invited you to join the gang "%s". You have %s seconds to respond.',
    ['invite_accept'] = 'Accept',
    ['invite_decline'] = 'Decline',
    ['invite_expired'] = 'Gang invite has expired',

    ['gangwar_invite_sent_title'] = 'Invite Sent',
    ['gangwar_invite_sent_desc'] = 'Gang war invite has been sent',

    ['failed_to_create_rank'] = 'Failed to create rank',
    ['max_ranks_reached'] = 'Maximum number of ranks reached',

    ['drugzone_npc_interact'] = '[E] - Start Drugzone',
    ['drugzone_npc_interact_ox_target'] = 'Start Drugzone'
}