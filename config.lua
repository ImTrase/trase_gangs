Config = { Strings = {} }

Config.Language = 'en'
Config.Debug = true
Config.InteractionType = 'ox_target'

Config.Framework = 'auto'

Config.Commands = {
    GangManage = 'gangmanage',
    ServerManagement = 'gangs',
    GangLeaderboard = 'gangleaderboard',
}

Config.Handler = {
    DefaultMaxMembers = 10,
    DefaultMaxRanks = 5,
    InviteExpiryTime = 3600,
    
    ReputationEnabled = true,
    ReputationRewards = {
        TurfWin = 100,
        DrugzoneWin = 75,
        GangWarWin = 150,
    },
    
    UnlocksEnabled = true,
    Unlocks = {
        storage_upgrade_1 = { cost = 500, label = 'Storage Upgrade Tier 1' },
        storage_upgrade_2 = { cost = 1000, label = 'Storage Upgrade Tier 2' },
        storage_upgrade_3 = { cost = 2000, label = 'Storage Upgrade Tier 3' },
        member_slots_1 = { cost = 750, label = '+5 Member Slots' },
        member_slots_2 = { cost = 1500, label = '+10 Member Slots' },
    },
}

Config.Features = {}
Config.Features.Drugzones = {
    Enabled = true,
    Duration = 300,
    WinningPoints = 250,
    PointsPerSecond = 1,
    MarkerType = 1,
    MarkerColor = { r = 255, g = 0, b = 0, a = 100 },
    Zones = {
        ['Testing Zone'] = {
            coords = vector3(398.6851, -1996.0840, 22.1991),
            radius = 50.0,
            NPC = {
                model = 's_m_m_chemsec_01',
                coords = vector4(398.6851, -1996.0840, 22.1991, 192.3332),
                scenario = 'WORLD_HUMAN_GUARD_PATROL',
                spawnRadius = 50.0,
            },
            KillRewards = {
                Enabled = true,
                Rewards = {
                    [1] = { label = 'First Kill', rewards = { ['money'] = 5000 }},
                    [3] = { label = 'Third Kill', rewards = { ['money'] = 15000 }},
                    [5] = { label = 'Fifth Kill', rewards = { ['money'] = 30000 }},
                }
            }
        }
    },
}

Config.Features.Turfs = {
    Enabled = true,
    Duration = 300,
    MarkerType = 1,
    MarkerColor = { r = 0, g = 120, b = 255, a = 90 },
    ActiveMarkerColor = { r = 0, g = 200, b = 255, a = 120 },
    Zones = {
        ['Testing Turf'] = {
            coords = vec3(418.3423, -1933.1086, 24.0848),
            radius = 40.0,
        }
    },
    KillRewards = {
        Enabled = true,
        Rewards = {
            [1] = { label = 'First Kill', rewards = { ['money'] = 5000 }},
            [3] = { label = 'Third Kill', rewards = { ['money'] = 15000 }},
            [5] = { label = 'Fifth Kill', rewards = { ['money'] = 30000 }},
        }
    }
}

Config.Features.GangWars = {
    Enabled = true,
    KillFeed = true,
    MinWager = 0,
    MaxWager = 100000,
    TargetKills = 50
}

Config.Features.Leaderboards = {
    Enabled = true,
}