Config = { Strings = {} }

Config.Language = 'en' -- Default language for the script
Config.Debug = true
Config.InteractionType = 'ox_target' -- Options: 'ox_lib', 'ox_target', 'draw3d', 'native'

Config.Framework = 'auto' -- 'auto', 'esx', 'qbcore', 'qbx' | Recomended to use 'auto' for automatic detection

-- Commands
Config.Commands = {
    GangManage = 'gangmanage', -- Command for gang owners to open their dashboard
    ServerManagement = 'gangs', -- Command for admins to open server management panel
    GangLeaderboard = 'gangleaderboard', -- Command for anyone to open the gang leaderboards
}

-- Handler Configuration
Config.Handler = {
    DefaultMaxMembers = 10,
    DefaultMaxRanks = 5,
    InviteExpiryTime = 3600, -- 1 hour in seconds
    
    -- Reputation system
    ReputationEnabled = true,
    ReputationRewards = {
        TurfWin = 100,
        DrugzoneWin = 75,
        GangWarWin = 150,
    },
    
    -- Gang unlocks (requires reputation)
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
    Duration = 300, -- Duration in seconds (300 = 5 minutes)
    WinningPoints = 250, -- First gang to reach this many points wins
    PointsPerSecond = 1, -- Points awarded per second to gangs with players in the zone
    MarkerType = 1, -- Cylinder marker
    MarkerColor = { r = 255, g = 0, b = 0, a = 100 }, -- Red with transparency
    Zones = {
        ['Testing Zone'] = {
            coords = vector3(398.6851, -1996.0840, 22.1991),
            radius = 50.0, -- Zone radius
            NPC = {
                model = 's_m_m_chemsec_01',
                coords = vector4(398.6851, -1996.0840, 22.1991, 192.3332),
                scenario = 'WORLD_HUMAN_GUARD_PATROL',
                spawnRadius = 50.0, -- Distance at which the NPC spawns/despawns
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
    Duration = 300, -- seconds turf stays active when started
    MarkerType = 1, -- marker type for passive display
    MarkerColor = { r = 0, g = 120, b = 255, a = 90 }, -- passive marker color
    ActiveMarkerColor = { r = 0, g = 200, b = 255, a = 120 }, -- big circle color when turf active
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
    KillFeed = true, -- Show kill feed to players in gang war
    MinWager = 0,
    MaxWager = 100000,
    TargetKills = 50 -- First gang to reach this many kills wins
}

Config.Features.Leaderboards = {
    Enabled = true,
}