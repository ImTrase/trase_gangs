local Drugzones = {}

local function DebugPrint(...)
    if Config.Debug then
        print(...)
    end
end

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
Drugzones.activeZone = nil
Drugzones.zoneData = {}
Drugzones.lastZoneTime = {}

function Drugzones:StartZone(zoneName, zoneConfig)
    if self.activeZone then
        return false, 'zone_already_active'
    end
    if self.isStarting then return false, 'zone_starting' end

    local lastTime = self.lastZoneTime[zoneName]
    if lastTime then
        local diff = os.time() - lastTime
        if diff < Config.Features.Drugzones.Cooldown then
            return false, 'zone_cooldown'
        end
    end

    if Config.Debug then
        DebugPrint('[Drugzones Server] Starting drug zone sequence: ' .. zoneName)
    end

    self.isStarting = true
    if AlertServer then
        AlertServer(-1, zoneName .. " DrugZone is starting in 10 Seconds get there now and take it over")
    end

    if zoneConfig.WinnerRewards.Enabled then
        self.winnerRewards = zoneConfig.WinnerRewards.Rewards
    end

    SetTimeout(10000, function()
        self.isStarting = false
        if self.activeZone then return end

        self.activeZone = zoneName
        self.zoneData = {
            name = zoneName,
            coords = zoneConfig.coords,
            radius = zoneConfig.radius,
            startTime = os.time(),
            duration = Config.Features.Drugzones.Duration,
            gangs = {},
            players = {},
            playersInside = {},
            winner = nil,
        }

        if AlertServer then
            AlertServer(-1, zoneName .. " DrugZone has started!")
        end

        TriggerClientEvent('trase_gangs:drugzone:start', -1, {
            name = zoneName,
            coords = zoneConfig.coords,
            radius = zoneConfig.radius,
            duration = Config.Features.Drugzones.Duration,
            startTime = self.zoneData.startTime
        })

        self:StartPointAccumulation()

        SetTimeout(Config.Features.Drugzones.Duration * 1000, function()
            self:EndZone()
        end)

        if Config.Debug then
            DebugPrint('[Drugzones Server] Drug zone started successfully')
        end
    end)


    return true, { message = "DrugZone starting in 10 seconds" }
end

function Drugzones:EndZone()
    if not self.activeZone then
        return false, 'no_active_zone'
    end

    if Config.Debug then
        DebugPrint('[Drugzones Server] Ending drug zone: ' .. self.activeZone)
        DebugPrint('[Drugzones Server] Final statistics:', json.encode(self.zoneData, { indent = true }))
    end

    TriggerClientEvent('trase_gangs:drugzone:end', -1)


    local zoneName = self.activeZone
    self.lastZoneTime[zoneName] = os.time()
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

    local player = Player(playerId)
    local gangTbl = player and player.state and player.state.gang or nil
    local gangId = gangTbl and gangTbl.id or nil
    local gangLabel = gangTbl and (gangTbl.label or gangTbl.name) or nil

    self.zoneData.playersInside[playerId] = true

    if not self.zoneData.players[playerId] then
        self.zoneData.players[playerId] = {
            kills = 0,
            gangId = gangId,
            identifier = identifier,
            isDead = false
        }
    else
        self.zoneData.players[playerId].isDead = false
    end

    if gangId and not self.zoneData.gangs[gangId] then
        self.zoneData.gangs[gangId] = {
            name = gangLabel or ('Gang ' .. tostring(gangId)),
            kills = 0,
            points = 0,
            players = {}
        }
    end

    if gangId then
        self.zoneData.gangs[gangId].players[playerId] = true
    end

    if Config.Debug then
        DebugPrint(('[Drugzones Server] Player %d entered zone. Gang ID: %s Label: %s'):format(
            playerId,
            tostring(gangId or 'none'),
            tostring(gangLabel or 'n/a')
        ))
        DebugPrint('[Drugzones Server] Current gangs in zone:', json.encode(self.zoneData.gangs))
    end

    self:BroadcastStats()
end

function Drugzones:PlayerLeaveZone(playerId)
    if not self.activeZone then return end

    self.zoneData.playersInside[playerId] = nil

    local playerData = self.zoneData.players[playerId]
    if playerData and playerData.gangId then
        local gangData = self.zoneData.gangs[playerData.gangId]
        if gangData then
            gangData.players[playerId] = nil
            -- Remove gang if no alive players AND no points
            if self:CountGangPlayersInZone(playerData.gangId) == 0 and gangData.points == 0 then
                self.zoneData.gangs[playerData.gangId] = nil
            end
        end
    end

    self:BroadcastStats()

    if Config.Debug then
        DebugPrint(('[Drugzones Server] Player %d left zone'):format(playerId))
    end
end

function Drugzones:PlayerDied(playerId)
    if not self.activeZone then return end

    local playerData = self.zoneData.players[playerId]
    if playerData then
        playerData.isDead = true
        if playerData.gangId then
            local gangData = self.zoneData.gangs[playerData.gangId]
            if gangData then
                -- Remove gang if no alive players AND no points
                if self:CountGangPlayersInZone(playerData.gangId) == 0 and gangData.points == 0 then
                    self.zoneData.gangs[playerData.gangId] = nil
                end
            end
        end
        self:BroadcastStats()
    end
end

function Drugzones:RecordKill(killerId, victimId)
    if not self.activeZone then return end

    local killerData = self.zoneData.players[killerId]
    if not killerData then return end

    killerData.kills = killerData.kills + 1

    if killerData.gangId then
        local gangData = self.zoneData.gangs[killerData.gangId]
        if gangData then
            gangData.kills = gangData.kills + 1
        end
    end

    TriggerClientEvent('trase_gangs:drugzone:playerKill', killerId)

    self:BroadcastStats()

    if Config.Debug then
        DebugPrint(('[Drugzones Server] Kill recorded - Killer: %d (%d kills), Gang: %s'):format(
            killerId,
            killerData.kills,
            killerData.gangId or 'none'
        ))
    end
end

function Drugzones:BroadcastStats()
    if not self.activeZone then 
        if Config.Debug then
            DebugPrint('[Drugzones Server] Cannot broadcast - no active zone')
        end
        return 
    end

    local gangStats = {}
    local gangCount = 0
    for gangId, gangData in pairs(self.zoneData.gangs) do
        gangCount = gangCount + 1
        gangStats[gangId] = {
            name = gangData.name or ('Gang ' .. tostring(gangId)),
            kills = gangData.kills,
            points = gangData.points,
            playerCount = self:CountGangPlayersInZone(gangId),
            color = self:GetGangColor(gangId)
        }
        
        if Config.Debug then
            DebugPrint(('[Drugzones Server] Gang %s (ID: %s): %d points, %d players'):format(
                tostring(gangStats[gangId].name),
                tostring(gangId),
                gangStats[gangId].points,
                gangStats[gangId].playerCount
            ))
        end
    end

    if Config.Debug then
        DebugPrint(('[Drugzones Server] Total gangs to broadcast: %d'):format(gangCount))
        DebugPrint('[Drugzones Server] Gang stats JSON:', json.encode(gangStats))
    end

    local playerCount = 0
    for playerId, _ in pairs(self.zoneData.playersInside) do
        playerCount = playerCount + 1
        TriggerClientEvent('trase_gangs:drugzone:updateStats', playerId, gangStats)
        if Config.Debug then
            DebugPrint(('[Drugzones Server] Sent stats to player %d'):format(playerId))
        end
    end
    
    if Config.Debug then
        DebugPrint(('[Drugzones Server] Finished broadcasting stats to %d player(s)'):format(playerCount))
    end
end

function Drugzones:CountGangPlayersInZone(gangId)
    local count = 0
    local gangData = self.zoneData.gangs[gangId]
    if gangData and gangData.players then
        for playerId, _ in pairs(gangData.players) do
            local p = self.zoneData.players[playerId]
            if p and not p.isDead and self.zoneData.playersInside[playerId] then
                count = count + 1
            end
        end
    end
    return count
end

function Drugzones:GetGangColor(gangId)
    local colors = {
        '#ef4444',
        '#3b82f6',
        '#10b981',
        '#f59e0b',
        '#8b5cf6',
        '#ec4899',
    }
    local idx = tonumber(gangId) or 0
    return colors[(idx % #colors) + 1]
end

function Drugzones:StartPointAccumulation()
    if not self.activeZone then return end

    CreateThread(function()
        while self.activeZone and not self.zoneData.winner do
            Wait(1000)

            if not self.activeZone then break end

            for gangId, gangData in pairs(self.zoneData.gangs) do
                local playerCount = self:CountGangPlayersInZone(gangId)
                
                if playerCount > 0 then
                    gangData.points = gangData.points + (Config.Features.Drugzones.PointsPerSecond or 1)
                    
                    if Config.Debug then
                        DebugPrint(('[Drugzones Server] Gang %s earned %d point(s). Total: %d'):format(
                            gangId,
                            Config.Features.Drugzones.PointsPerSecond or 1,
                            gangData.points
                        ))
                    end

                    if gangData.points >= Config.Features.Drugzones.WinningPoints then
                        self:DeclareWinner(gangId)
                        break
                    end
                end
            end

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
        DebugPrint(('[Drugzones Server] Gang %s has won the drug zone with %d points!'):format(
            gangName,
            self.zoneData.gangs[gangId].points
        ))
    end

    if AlertServer then
        AlertServer(-1, "DrugZone " .. self.activeZone .. " ended! Winner: " .. gangName)
    end

    local Handler = exports['trase_gangs']:GetHandler()
    if Handler then
        Handler:UpdateGangStats(gangId, 'drugzone_wins', 1)
        for gid, _ in pairs(self.zoneData.gangs) do
            if gid ~= gangId then
                Handler:UpdateGangStats(gid, 'drugzone_losses', 1)
            end
        end
    end

    if self.winnerRewards then 
        local OnlineGangMembers = Handler:GetOnlineGangMembers(gangId)
        for _, id in pairs(OnlineGangMembers) do -- k2
            for item, amount in pairs(self.winnerRewards) do
                GiveItem(id, item, amount)
            end
        end
    end

    TriggerClientEvent('trase_gangs:drugzone:winner', -1, {
        gangId = gangId,
        gangName = gangName,
        points = self.zoneData.gangs[gangId].points
    })


    SetTimeout(5000, function()
        self:EndZone()
    end)
end

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

RegisterNetEvent('trase_gangs:drugzone:playerDied', function()
    local source = source
    Drugzones:PlayerDied(source)
end)

if Config.Debug then
    DebugPrint('[Drugzones Server] Initialized')
end