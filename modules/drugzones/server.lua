local Drugzones = {}

-- Helper: get primary identifier (license preferred)
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
Drugzones.activeZone = nil -- Only one active zone at a time
Drugzones.zoneData = {} -- Track zone statistics

function Drugzones:StartZone(zoneName, zoneConfig)
    if self.activeZone then
        return false, 'zone_already_active'
    end

    if Config.Debug then
        print('[Drugzones Server] Starting drug zone: ' .. zoneName)
    end

    -- Initialize zone data
    self.activeZone = zoneName
    self.zoneData = {
        name = zoneName,
        coords = zoneConfig.coords,
        radius = zoneConfig.radius,
        startTime = os.time(),
        duration = Config.Features.Drugzones.Duration,
        gangs = {}, -- { [gangId:number] = { name = string, kills = 0, points = 0, players = { [playerId] = true } } }
        players = {}, -- { [playerId] = { kills = 0, gangId = nil, identifier = '' } }
        playersInside = {}, -- { [playerId] = true }
        winner = nil -- Gang ID of the winner
    }

    -- Notify all clients to start the zone
    TriggerClientEvent('trase_gangs:drugzone:start', -1, {
        name = zoneName,
        coords = zoneConfig.coords,
        radius = zoneConfig.radius,
        duration = Config.Features.Drugzones.Duration
    })

    -- Start point accumulation timer
    self:StartPointAccumulation()

    -- Schedule zone end
    SetTimeout(Config.Features.Drugzones.Duration * 1000, function()
        self:EndZone()
    end)

    if Config.Debug then
        print('[Drugzones Server] Drug zone started successfully')
    end

    return true, self.zoneData
end

function Drugzones:EndZone()
    if not self.activeZone then
        return false, 'no_active_zone'
    end

    if Config.Debug then
        print('[Drugzones Server] Ending drug zone: ' .. self.activeZone)
        print('[Drugzones Server] Final statistics:', json.encode(self.zoneData, { indent = true }))
    end

    -- Notify all clients to end the zone
    TriggerClientEvent('trase_gangs:drugzone:end', -1)

    -- TODO: Calculate winners, distribute rewards, etc.

    -- Reset zone data
    local zoneName = self.activeZone
    self.activeZone = nil
    self.zoneData = {}

    return true
end

function Drugzones:GetActiveZone()
    return self.activeZone, self.zoneData
end

function Drugzones:PlayerEnterZone(playerId)
    if not self.activeZone then return end

    local identifier = GetPrimaryIdentifier(playerId)
    if not identifier then return end

    -- Get player's gang from player state (expecting a table with id/label)
    local player = Player(playerId)
    local gangTbl = player and player.state and player.state.gang or nil
    local gangId = gangTbl and gangTbl.id or nil
    local gangLabel = gangTbl and (gangTbl.label or gangTbl.name) or nil

    self.zoneData.playersInside[playerId] = true

    -- Initialize player data if not exists
    if not self.zoneData.players[playerId] then
        self.zoneData.players[playerId] = {
            kills = 0,
            gangId = gangId,
            identifier = identifier
        }
    end

    -- Initialize gang data if player has a gang
    if gangId and not self.zoneData.gangs[gangId] then
        self.zoneData.gangs[gangId] = {
            name = gangLabel or ('Gang ' .. tostring(gangId)),
            kills = 0,
            points = 0,
            players = {}
        }
    end

    -- Add player to gang's player list
    if gangId then
        self.zoneData.gangs[gangId].players[playerId] = true
    end

    if Config.Debug then
        print(('[Drugzones Server] Player %d entered zone. Gang ID: %s Label: %s'):format(
            playerId,
            tostring(gangId or 'none'),
            tostring(gangLabel or 'n/a')
        ))
        print('[Drugzones Server] Current gangs in zone:', json.encode(self.zoneData.gangs))
    end

    -- Broadcast updated stats (includes the new player)
    self:BroadcastStats()
end

function Drugzones:PlayerLeaveZone(playerId)
    if not self.activeZone then return end

    self.zoneData.playersInside[playerId] = nil

    -- Remove from gang's active players list (but keep in players table for stats)
    local playerData = self.zoneData.players[playerId]
    if playerData and playerData.gangId then
        local gangData = self.zoneData.gangs[playerData.gangId]
        if gangData then
            gangData.players[playerId] = nil
        end
    end

    -- Broadcast updated stats to remaining players
    self:BroadcastStats()

    if Config.Debug then
        print(('[Drugzones Server] Player %d left zone'):format(playerId))
    end
end

function Drugzones:RecordKill(killerId, victimId)
    if not self.activeZone then return end

    local killerData = self.zoneData.players[killerId]
    if not killerData then return end

    -- Increment player kills
    killerData.kills = killerData.kills + 1

    -- Increment gang kills if player is in a gang
    if killerData.gangId then
        local gangData = self.zoneData.gangs[killerData.gangId]
        if gangData then
            gangData.kills = gangData.kills + 1
        end
    end

    -- Notify killer of their kill
    TriggerClientEvent('trase_gangs:drugzone:playerKill', killerId)

    -- Broadcast updated stats to all players in zone
    self:BroadcastStats()

    if Config.Debug then
        print(('[Drugzones Server] Kill recorded - Killer: %d (%d kills), Gang: %s'):format(
            killerId,
            killerData.kills,
            killerData.gangId or 'none'
        ))
    end
end

function Drugzones:BroadcastStats()
    if not self.activeZone then 
        if Config.Debug then
            print('[Drugzones Server] Cannot broadcast - no active zone')
        end
        return 
    end

    -- Build gang stats for clients
    local gangStats = {}
    local gangCount = 0
    for gangId, gangData in pairs(self.zoneData.gangs) do
        gangCount = gangCount + 1
        -- Use stored gang name collected from player state
        gangStats[gangId] = {
            name = gangData.name or ('Gang ' .. tostring(gangId)),
            kills = gangData.kills,
            points = gangData.points,
            playerCount = self:CountGangPlayersInZone(gangId),
            color = self:GetGangColor(gangId)
        }
        
        if Config.Debug then
            print(('[Drugzones Server] Gang %s (ID: %s): %d points, %d players'):format(
                tostring(gangStats[gangId].name),
                tostring(gangId),
                gangStats[gangId].points,
                gangStats[gangId].playerCount
            ))
        end
    end

    if Config.Debug then
        print(('[Drugzones Server] Total gangs to broadcast: %d'):format(gangCount))
        print('[Drugzones Server] Gang stats JSON:', json.encode(gangStats))
    end

    -- Send to all players in the zone
    local playerCount = 0
    for playerId, _ in pairs(self.zoneData.playersInside) do
        playerCount = playerCount + 1
        TriggerClientEvent('trase_gangs:drugzone:updateStats', playerId, gangStats)
        if Config.Debug then
            print(('[Drugzones Server] Sent stats to player %d'):format(playerId))
        end
    end
    
    if Config.Debug then
        print(('[Drugzones Server] Finished broadcasting stats to %d player(s)'):format(playerCount))
    end
end

function Drugzones:CountGangPlayersInZone(gangId)
    local count = 0
    local gangData = self.zoneData.gangs[gangId]
    if gangData and gangData.players then
        for _ in pairs(gangData.players) do
            count = count + 1
        end
    end
    return count
end

function Drugzones:GetGangColor(gangId)
    -- You can customize this to get actual gang colors from your database
    local colors = {
        '#ef4444', -- red
        '#3b82f6', -- blue
        '#10b981', -- green
        '#f59e0b', -- yellow
        '#8b5cf6', -- purple
        '#ec4899', -- pink
    }
    local idx = tonumber(gangId) or 0
    return colors[(idx % #colors) + 1]
end

function Drugzones:StartPointAccumulation()
    if not self.activeZone then return end

    CreateThread(function()
        while self.activeZone and not self.zoneData.winner do
            Wait(1000) -- Wait 1 second

            if not self.activeZone then break end

            -- Award points to gangs with players in the zone
            for gangId, gangData in pairs(self.zoneData.gangs) do
                local playerCount = self:CountGangPlayersInZone(gangId)
                
                -- Only award points if gang has at least one player in the zone
                if playerCount > 0 then
                    gangData.points = gangData.points + (Config.Features.Drugzones.PointsPerSecond or 1)
                    
                    if Config.Debug then
                        print(('[Drugzones Server] Gang %s earned %d point(s). Total: %d'):format(
                            gangId,
                            Config.Features.Drugzones.PointsPerSecond or 1,
                            gangData.points
                        ))
                    end

                    -- Check if this gang has won
                    if gangData.points >= Config.Features.Drugzones.WinningPoints then
                        self:DeclareWinner(gangId)
                        break
                    end
                end
            end

            -- Broadcast updated stats
            if not self.zoneData.winner then
                self:BroadcastStats()
            end
        end
    end)
end

function Drugzones:DeclareWinner(gangId)
    if not self.activeZone or self.zoneData.winner then return end

    self.zoneData.winner = gangId
    local gangEntry = self.zoneData.gangs[gangId]
    local gangName = (gangEntry and gangEntry.name) or ('Gang ' .. tostring(gangId))

    if Config.Debug then
        print(('[Drugzones Server] Gang %s has won the drug zone with %d points!'):format(
            gangName,
            self.zoneData.gangs[gangId].points
        ))
    end

    -- Notify all players
    TriggerClientEvent('trase_gangs:drugzone:winner', -1, {
        gangId = gangId,
        gangName = gangName,
        points = self.zoneData.gangs[gangId].points
    })

    -- End the zone after a short delay
    SetTimeout(5000, function()
        self:EndZone()
    end)
end

-- Callbacks
lib.callback.register('trase_gangs:drugzone:checkActive', function(source)
    return Drugzones.activeZone ~= nil, Drugzones.activeZone, Drugzones.zoneData
end)

lib.callback.register('trase_gangs:drugzone:start', function(source, zoneName)
    local zoneConfig = Config.Features.Drugzones.Zones[zoneName]
    if not zoneConfig then
        return false, 'zone_not_found'
    end

    return Drugzones:StartZone(zoneName, zoneConfig)
end)

-- Events
RegisterNetEvent('trase_gangs:drugzone:playerEnter', function()
    local source = source
    Drugzones:PlayerEnterZone(source)
end)

RegisterNetEvent('trase_gangs:drugzone:playerLeave', function()
    local source = source
    Drugzones:PlayerLeaveZone(source)
end)

RegisterNetEvent('trase_gangs:drugzone:recordKill', function(victimId)
    local source = source
    Drugzones:RecordKill(source, victimId)
end)

if Config.Debug then
    print('[Drugzones Server] Initialized')
end
