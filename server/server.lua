
function DoPrint(type, msg)
    if not Config.Debug then
        return
    end
    if type == "error" then
        print('^4[Trase_Gangs] ^1[ERROR]^0: ' .. msg)
    elseif type == "warn" then
        print("^3[Trase_Gangs] ^3[WARNING]^0: " .. msg)
    elseif type == "success" then
        print("^2[Trase_Gangs] ^2[SUCCESS]^0: " .. msg)
    elseif type == 'debug' then
        if Config.Debug then
            print("^2[Trase_Gangs] ^7[DEBUG]^0: " .. msg)
        end
    else
        print("^2[Trase_Gangs] ^6[INFO]^0: " .. msg)
    end
end

local function checkGangWarTables()
    DoPrint("info", "Checking gang war database tables...")
    
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_war_requests` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `challenger_gang_id` INT(11) NOT NULL,
            `target_gang_id` INT(11) NOT NULL,
            `wager_amount` INT(11) NOT NULL DEFAULT 0,
            `kills_to_win` INT(11) NOT NULL DEFAULT 50,
            `requested_by` VARCHAR(60) NOT NULL,
            `status` ENUM('pending', 'accepted', 'declined', 'expired') NOT NULL DEFAULT 'pending',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL 24 HOUR),
            PRIMARY KEY (`id`),
            KEY `challenger_gang_id` (`challenger_gang_id`),
            KEY `target_gang_id` (`target_gang_id`),
            KEY `status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_war_history` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `request_id` INT(11) DEFAULT NULL,
            `gang_1_id` INT(11) NOT NULL,
            `gang_2_id` INT(11) NOT NULL,
            `gang_1_score` INT(11) NOT NULL DEFAULT 0,
            `gang_2_score` INT(11) NOT NULL DEFAULT 0,
            `wager_amount` INT(11) NOT NULL DEFAULT 0,
            `winner_gang_id` INT(11) DEFAULT NULL,
            `status` ENUM('active', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
            `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `ended_at` TIMESTAMP NULL DEFAULT NULL,
            `duration_minutes` INT(11) NOT NULL DEFAULT 30,
            PRIMARY KEY (`id`),
            KEY `gang_1_id` (`gang_1_id`),
            KEY `gang_2_id` (`gang_2_id`),
            KEY `winner_gang_id` (`winner_gang_id`),
            KEY `status` (`status`),
            KEY `request_id` (`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `trase_gang_war_participants` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `war_id` INT(11) NOT NULL,
            `gang_id` INT(11) NOT NULL,
            `identifier` VARCHAR(60) NOT NULL,
            `kills` INT(11) NOT NULL DEFAULT 0,
            `deaths` INT(11) NOT NULL DEFAULT 0,
            `assists` INT(11) NOT NULL DEFAULT 0,
            `points_contributed` INT(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `war_participant` (`war_id`, `identifier`),
            KEY `war_id` (`war_id`),
            KEY `gang_id` (`gang_id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    DoPrint("success", "Gang war database tables verified/created")
end

local function beginSetup()
    local enabled = {
        handler = false,
        drugzones = false,
        turfs = false,
        gangwars = false,
        leaderboards = false
    }

    checkGangWarTables()

    enabled.handler = true

    if Config.Features.Drugzones.Enabled then
        enabled.drugzones = true
    end

    if Config.Features.Turfs.Enabled then
        enabled.turfs = true
    end

    if Config.Features.GangWars and Config.Features.GangWars.Enabled then
        enabled.gangwars = true
    end

    if Config.Features.Leaderboards and Config.Features.Leaderboards.Enabled then
        enabled.leaderboards = true
    end

    local enabledStr = [[
        • Drugzones: ]] .. tostring(enabled.drugzones and '^2Enabled^0' or '^1Disabled^0') .. [[ 
        • Turfs: ]] .. tostring(enabled.turfs and '^2Enabled^0' or '^1Disabled^0') .. [[
        • Gang Wars: ]] .. tostring(enabled.gangwars and '^2Enabled^0' or '^1Disabled^0') .. [[
        • Leaderboards: ]] .. tostring(enabled.leaderboards and '^2Enabled^0' or '^1Disabled^0') .. [[
    ]]

    DoPrint("success", string.format("Setup Complete \n %s", enabledStr))
end

beginSetup()

RegisterCommand('gang:addtest', function(source, args, rawCommand)
    local Handler = exports['trase_gangs']:GetServerHandler()
    
    local gangId = tonumber(args[1]) or 1
    local count = tonumber(args[2]) or 5
    
    local gang = Handler.gangs[gangId]
    if not gang then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {'[Gang System]', 'Gang ID ' .. gangId .. ' not found!'}
            })
        else
            DoPrint('error', 'Gang ID ' .. gangId .. ' not found!')
        end
        return
    end
    
    local lowestRank = nil
    local lowestGrade = 999
    for _, rank in pairs(gang.ranks) do
        if rank.grade < lowestGrade then
            lowestGrade = rank.grade
            lowestRank = rank
        end
    end
    
    if not lowestRank then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {'[Gang System]', 'No ranks found in this gang!'}
            })
        else
            DoPrint('error', 'No ranks found in this gang!')
        end
        return
    end
    
    local added = 0
    for i = 1, count do
        local identifier = 'test_member_' .. string.format('%03d', math.random(100, 999))
        
        if not Handler.playerGangs[identifier] then
            local testName = 'Test Member ' .. string.format('%03d', math.random(100, 999))
            MySQL.insert.await([[
                INSERT INTO trase_gang_members (gang_id, identifier, name, rank_id)
                VALUES (?, ?, ?, ?)
            ]], {gangId, identifier, testName, lowestRank.id})
            
            MySQL.insert.await([[
                INSERT INTO trase_gang_member_stats (gang_id, identifier, turf_kills, turf_deaths, drugzone_kills, drugzone_deaths, gangwar_kills, gangwar_deaths)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], {gangId, identifier, math.random(0, 20), math.random(0, 10), math.random(0, 15), math.random(0, 8), math.random(0, 25), math.random(0, 12)})
            
            gang.members[identifier] = {
                identifier = identifier,
                name = testName,
                rank_id = lowestRank.id,
                joined_at = os.date('%Y-%m-%d %H:%M:%S')
            }
            Handler.playerGangs[identifier] = gangId
            
            added = added + 1
        end
    end
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {'[Gang System]', 'Added ' .. added .. ' test members to ' .. gang.label}
        })
    else
        DoPrint('success', 'Added ' .. added .. ' test members to ' .. gang.label)
end
end, false)

local function GetPrimaryIdentifier(src)
    local ids = GetPlayerIdentifiers(src)
    local first
    for _, id in ipairs(ids) do
        first = first or id
        if id:find('license:', 1, true) == 1 then
            return id
        end
    end
    return first
end