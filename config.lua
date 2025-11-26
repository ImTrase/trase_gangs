Config = { Strings = {} }

Config.Language = 'en' -- Set the language locale here
Config.Debug = false -- Enable debug prints
Config.InteractionType = 'ox_lib' -- ox_lib or ox_target

Config.Framework = 'auto' -- 'esx', 'qbcore', 'standalone', or 'auto' to detect

Config.Commands = { -- Define command names here
    GangManage = 'gangmanage',
    ServerManagement = 'gangs',
    GangLeaderboard = 'gangleaderboard',
}

Config.Handler = { -- Settings for gang management
    DefaultMaxMembers = 10, -- Default maximum members in a gang
    DefaultMaxRanks = 5, -- Default maximum ranks in a gang
    InviteExpiryTime = 3600, -- Time in seconds before a gang invite expires

    ReputationEnabled = true, -- Enable reputation system
    ReputationRewards = { -- Rewards for various activities
        TurfWin = 100,
        DrugzoneWin = 75,
        GangWarWin = 150,
    },

    UnlocksEnabled = true, -- Enable gang unlocks (Coming Soon)
    Unlocks = {
        storage_upgrade_1 = { cost = 500, label = 'Storage Upgrade Tier 1' },
        storage_upgrade_2 = { cost = 1000, label = 'Storage Upgrade Tier 2' },
        storage_upgrade_3 = { cost = 2000, label = 'Storage Upgrade Tier 3' },
        member_slots_1 = { cost = 750, label = '+5 Member Slots' },
        member_slots_2 = { cost = 1500, label = '+10 Member Slots' },
    },
}

Config.Features = {}
Config.Features.TeleportNonMembers = true -- Teleport non-members out of zones
Config.Features.Drugzones = {
    Enabled = true,
    Duration = 300,
    WinningPoints = 250,
    PointsPerSecond = 1,
    DrawDistance = 100.0,
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
    Duration = 30,
    DrawDistance = 100.0,
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

Config.UI = {
    -- Main Theme: Blue
    Colors = {
        bg_dark = '#0f0f17',
        bg_panel = '#18181f',
        bg_sidebar = '#1a1a22',
        bg_elevated = '#20202a',
        accent = '#3b82f6',
        accent_hover = '#2563eb',
        accent_light = '#60a5fa',
        danger = '#ef4444',
        danger_hover = '#dc2626',
        text_primary = '#ffffff',
        text_secondary = '#a0a0ab',
        text_dim = '#71717a',
        border = '#27272f',
        border_light = '#3a3a44',
    },

    -- RED EXAMPLE
    -- Colors = {
    --     bg_dark = '#1f0f0f',
    --     bg_panel = '#2a1818',
    --     bg_sidebar = '#221a1a',
    --     bg_elevated = '#2a2020',
    --     accent = '#ef4444',
    --     accent_hover = '#dc2626',
    --     accent_light = '#f87171',
    --     danger = '#3b82f6',
    --     danger_hover = '#2563eb',
    --     text_primary = '#ffffff',
    --     text_secondary = '#a0a0ab',
    --     text_dim = '#71717a',
    --     border = '#27272f',
    --     border_light = '#3a3a44',
    -- },
}

