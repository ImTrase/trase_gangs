if not Config.Features.Drugzones.Enabled then return end
local Drugzones = lib.class('Drugzones')

function Drugzones:constructor()
    if Config.Debug then
        print('[Drugzones] Initializing Drugzones...')
    end
    self.zones = {}
    self.activeNPCs = {}
    self.activeDrugZone = nil
    self.drugZonePoint = nil
    self.isInDrugZone = false
    self.overlay = ActivityOverlay:new()
    self.currentKillstreak = 0
    self.gangStats = {}
    
    if Config.Debug then
        print('[Drugzones] Activity Overlay created:', self.overlay ~= nil)
    end
    
    self:loadZones()
    self:registerEvents()
end

function Drugzones:spawnNPC(zoneName, npcData)
    if Config.Debug then
        print('[Drugzones] Spawning NPC for zone: ' .. zoneName)
    end

    lib.requestModel(npcData.model, 10000)

    print('made it here')
    local ped = CreatePed(4, GetHashKey(npcData.model), npcData.coords.x, npcData.coords.y, npcData.coords.z, npcData.coords.w, false, false)

    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    if npcData.scenario then
        TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
    end

    self.activeNPCs[zoneName] = ped

    local interactionId = 'drugzone_npc_' .. zoneName
    AddInteraction(interactionId, {
        coords = vector3(npcData.coords.x, npcData.coords.y, npcData.coords.z),
        localeKey = 'drugzone_npc_interact',
        distance = 2.0,
        entity = ped,
        onInteract = function()
            self:onNPCInteract(zoneName)
        end
    })

    if Config.Debug then
        print('[Drugzones] Successfully spawned NPC (ID: ' .. ped .. ') for zone: ' .. zoneName)
    end

    return ped
end

function Drugzones:onNPCInteract(zoneName)
    if Config.Debug then
        print('[Drugzones] Player interacted with NPC in zone: ' .. zoneName)
    end

    local gang = LocalPlayer.state.gang
    if not gang then
        lib.notify({
            title = TranslateText('error', 'Error'),
            description = TranslateText('drugzone_not_in_gang', 'You must be in a gang to start a drug zone!'),
            type = 'error'
        })
        return
    end

    local hasActiveZone, activeZoneName = lib.callback.await('trase_gangs:drugzone:checkActive', false)
    
    if hasActiveZone then
        lib.notify({
            title = TranslateText('drugzone_active_title', 'Drug Zone Active'),
            description = TranslateText('drugzone_already_active_desc', 'There is already an active drug zone: %s. Please wait for it to finish.'):format(activeZoneName),
            type = 'error'
        })
        return
    end

    local success, result = lib.callback.await('trase_gangs:drugzone:start', false, zoneName)
    
    if success then
        lib.notify({
            title = TranslateText('drugzone_started_title', 'Drug Zone Started'),
            description = TranslateText('drugzone_started_desc', 'The drug zone "%s" has been started!'):format(zoneName),
            type = 'success'
        })
    else
        lib.notify({
            title = TranslateText('error', 'Error'),
            description = TranslateText('drugzone_start_failed', 'Failed to start drug zone: %s'):format(tostring(result)),
            type = 'error'
        })
    end
end

function Drugzones:deleteNPC(zoneName)
    local ped = self.activeNPCs[zoneName]
    if ped and DoesEntityExist(ped) then
        if Config.Debug then
            print('[Drugzones] Deleting NPC (ID: ' .. ped .. ') for zone: ' .. zoneName)
        end
        
        local interactionId = 'drugzone_npc_' .. zoneName
        RemoveInteraction(interactionId)
        
        DeleteEntity(ped)
        self.activeNPCs[zoneName] = nil
        if Config.Debug then
            print('[Drugzones] Successfully deleted NPC for zone: ' .. zoneName)
        end
    else
        if Config.Debug then
            print('[Drugzones] Warning: Attempted to delete non-existent NPC for zone: ' .. zoneName)
        end
    end
end

function Drugzones:loadZones()
    if Config.Debug then
        print('[Drugzones] Loading Drugzones...')
    end

    for zoneName, zoneData in pairs(Config.Features.Drugzones.Zones) do
        self.zones[zoneName] = zoneData

        if zoneData.NPC then
            local npcData = zoneData.NPC
            local radius = npcData.spawnRadius or 50.0

            if Config.Debug then
                print('[Drugzones] Creating zone: ' .. zoneName .. ' with radius: ' .. radius)
            end

            local zone = lib.zones.sphere({
                coords = vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z),
                radius = radius,
                debug = Config.Debug,
                onEnter = function() -- onenter2
                    if Config.Debug then
                        print('[Drugzones] Player entered zone: ' .. zoneName)
                    end
                    -- am i in a gang and how can i find out if im not?
                    self:spawnNPC(zoneName, npcData)
                end,
                onExit = function()
                    if Config.Debug then
                        print('[Drugzones] Player exited zone: ' .. zoneName)
                    end
                    self:deleteNPC(zoneName)
                end
            })

            zoneData.zoneObject = zone

            if Config.Debug then
                print('[Drugzones] Successfully created zone: ' .. zoneName)
            end
        end
    end

    if Config.Debug then
        print('[Drugzones] Finished loading all zones')
    end
end

function Drugzones:startDrugZone(zoneData)
    if Config.Debug then
        print('[Drugzones] Starting drug zone: ' .. zoneData.name)
    end

    self.activeDrugZone = zoneData
    
    if Config.Debug then
        print('[Drugzones] activeDrugZone set to: ' .. tostring(self.activeDrugZone ~= nil))
    end

    self.drugZonePoint = lib.points.new({
        coords = zoneData.coords,
        distance = zoneData.radius,
    })

    local drugzonesInstance = self
    
    function self.drugZonePoint:onEnter() -- onenter2
        if Config.Features.TeleportNonMembers then
            local gang = LocalPlayer.state.gang
            if not gang then
                local center = vector3(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z)
                local coords = GetEntityCoords(PlayerPedId())
                local dir = coords - center
                local dist = #dir
                if dist < 0.1 then dir = vector3(1, 0, 0) end
                local newPos = center + (dir / #dir) * (zoneData.radius + 5.0)
                SetEntityCoords(PlayerPedId(), newPos.x, newPos.y, newPos.z, false, false, false, false)
                if lib and lib.notify then
                    lib.notify({ type = 'error', description = 'You must be in a gang to enter this zone!' })
                end
                return
            end
        end
        if Config.Debug then
            print('Entered Drug Zone')
            print('[Drugzones] Instance check - activeDrugZone exists: ' .. tostring(drugzonesInstance.activeDrugZone ~= nil))
            print('[Drugzones] Player gang ID:', LocalPlayer.state.gang)
        end
        drugzonesInstance.isInDrugZone = true
        TriggerServerEvent('trase_gangs:drugzone:playerEnter')
        
        SetTimeout(500, function()
            if Config.Debug then
                print('[Drugzones] About to show overlay, gangStats:', json.encode(drugzonesInstance.gangStats))
            end
            drugzonesInstance:showOverlay()
        end)
    end

    function self.drugZonePoint:onExit()
        if Config.Debug then
            print('Left Drug Zone')
        end
        drugzonesInstance.isInDrugZone = false
        TriggerServerEvent('trase_gangs:drugzone:playerLeave')
        drugzonesInstance:hideOverlay()
    end

    CreateThread(function()
        while self.activeDrugZone do
            Wait(0)
            local markerColor = Config.Features.Drugzones.MarkerColor
            local distance = #(GetEntityCoords(PlayerPedId()) - vector3(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z))
            if distance <= Config.Features.Drugzones.DrawDistance then
                DrawMarker(
                    Config.Features.Drugzones.MarkerType,
                    zoneData.coords.x,
                    zoneData.coords.y,
                    zoneData.coords.z - 50.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    zoneData.radius * 2.0, zoneData.radius * 2.0, zoneData.radius * 2.0,
                    markerColor.r, markerColor.g, markerColor.b, markerColor.a,
                    false, false, 2, false, nil, nil, false
                )
            end
        end
    end)

    SetTimeout(zoneData.duration * 1000, function()
        lib.notify({
            title = TranslateText('drugzone_title', 'Drug Zone'),
            description = TranslateText('drugzone_ended', 'The drug zone has ended!'),
            type = 'info'
        })
    end)

    lib.notify({
        title = TranslateText('drugzone_active_title', 'Drug Zone Active'),
        description = TranslateText('drugzone_started_info', 'A drug zone has started at %s for %s seconds!'):format(zoneData.name, tostring(zoneData.duration)),
        type = 'info'
    })
end

function Drugzones:endDrugZone()
    if Config.Debug then
        print('[Drugzones] Ending drug zone')
    end

    if self.drugZonePoint then
        self.drugZonePoint:remove()
        self.drugZonePoint = nil
    end

    if self.isInDrugZone then
        TriggerServerEvent('trase_gangs:drugzone:playerLeave')
        self.isInDrugZone = false
    end

    self:hideOverlay()
    self.currentKillstreak = 0
    self.gangStats = {}
    self.activeDrugZone = nil
end

function Drugzones:showOverlay()
    if not self.activeDrugZone then 
        if Config.Debug then
            print('[Drugzones] Cannot show overlay - no active drug zone')
        end
        return 
    end
    
    if Config.Debug then
        print('[Drugzones] Showing overlay for zone: ' .. self.activeDrugZone.name)
        print('[Drugzones] Current killstreak: ' .. self.currentKillstreak)
        print('[Drugzones] Gang stats count: ' .. #self.gangStats)
    end
    
    local nextReward = self:getNextKillReward()
    
    local playerGangPoints = 0
    local gangTbl = LocalPlayer.state.gang

    local playerGangId = gangTbl and gangTbl.id or nil
    if playerGangId and self.gangStats[playerGangId] then
        playerGangPoints = self.gangStats[playerGangId].points or 0
    end
    
    local stats = {
        {
            label = 'Your Gang Points',
            value = tostring(playerGangPoints) .. ' / ' .. Config.Features.Drugzones.WinningPoints
        },
        {
            label = 'Current Killstreak',
            value = tostring(self.currentKillstreak)
        }
    }
    
    if nextReward then
        stats[#stats + 1] = {
            label = 'Next Kill Reward',
            value = nextReward.label .. ' (' .. nextReward.kills .. ' kills)'
        }
    end
    
    local leaderboard = {}
    local gangCount = 0

    for gangId, gangData in pairs(self.gangStats) do
        gangCount = gangCount + 1
        local gangName = gangData.name or ('Gang ' .. gangId)
        local points = gangData.points or 0
        leaderboard[#leaderboard + 1] = {
            position = #leaderboard + 1,
            name = gangName,
            value = points .. ' Points',
            color = gangData.color or '#6b7280',
            points = points
        }
    end
    
    if Config.Debug then
        print('[Drugzones] Building leaderboard with ' .. gangCount .. ' gangs')
        for gangId, gangData in pairs(self.gangStats) do
            print('  Gang: ' .. (gangData.name or gangId) .. ' - Points: ' .. (gangData.points or 0))
        end
    end
    
    table.sort(leaderboard, function(a, b)
        return (a.points or 0) > (b.points or 0)
    end)
    
    for i, entry in ipairs(leaderboard) do
        entry.position = i
        entry.points = nil
    end
    
    if Config.Debug then
        print('[Drugzones] Showing overlay with data:')
        print('  Title: ' .. (self.activeDrugZone.name or 'DRUG ZONE'))
        print('  Stats count: ' .. #stats)
        print('  Leaderboard count: ' .. #leaderboard)
    end
    
    local remainingTime = self.activeDrugZone.duration or Config.Features.Drugzones.Duration
    if self.activeDrugZone.startTime then
        local elapsed = GetCloudTimeAsInt() - self.activeDrugZone.startTime
        remainingTime = math.max(0, remainingTime - elapsed)
    end

    if Config.Debug then
        print('[Drugzones] Overlay:Show() called successfully with ' .. remainingTime .. 's timer')
    end

    if self.overlay:IsVisible() then
        self.overlay:UpdateStats(stats)
        self.overlay:UpdateLeaderboard(leaderboard)
    else
        self.overlay:Show({
            title = self.activeDrugZone.name or 'DRUG ZONE',
            description = 'First gang to ' .. Config.Features.Drugzones.WinningPoints .. ' points wins',
            stats = stats,
            leaderboard = leaderboard,
            showTimer = true,
            timerDuration = remainingTime,
            totalDuration = self.activeDrugZone.duration or Config.Features.Drugzones.Duration,
            timerLabel = 'TIME REMAINING'
        })
    end
end

function Drugzones:hideOverlay()
    if Config.Debug then
        print('[Drugzones] Hiding overlay')
    end
    self.overlay:Hide()
end

function Drugzones:updateOverlay()
    if self.isInDrugZone and self.overlay:IsVisible() then
        self:showOverlay()
    end
end

function Drugzones:getNextKillReward()
    if not self.activeDrugZone then return nil end
    
    local zoneConfig = Config.Features.Drugzones.Zones[self.activeDrugZone.name]
    if not zoneConfig or not zoneConfig.KillRewards or not zoneConfig.KillRewards.Enabled then
        return nil
    end
    
    local rewards = zoneConfig.KillRewards.Rewards
    for kills, rewardData in pairs(rewards) do
        if self.currentKillstreak < kills then
            return {
                kills = kills,
                label = rewardData.label,
                rewards = rewardData.rewards
            }
        end
    end
    
    return nil
end

function Drugzones:onKill()
    self.currentKillstreak = self.currentKillstreak + 1
    self:updateOverlay()
end

function Drugzones:onDeath()
    self.currentKillstreak = 0
    self:updateOverlay()
end

function Drugzones:registerEvents()
    RegisterNetEvent('trase_gangs:drugzone:start', function(zoneData)
        self:startDrugZone(zoneData)
    end)

    RegisterNetEvent('trase_gangs:drugzone:end', function()
        self:endDrugZone()
    end)
    
    RegisterNetEvent('trase_gangs:drugzone:updateStats', function(gangStats)
        if Config.Debug then
            print('[Drugzones] Received gang stats update:', json.encode(gangStats))
        end
        self.gangStats = gangStats
        self:updateOverlay()
    end)
    
    RegisterNetEvent('trase_gangs:drugzone:playerKill', function()
        self:onKill()
    end)
    
    RegisterNetEvent('trase_gangs:drugzone:playerDeath', function()
        self:onDeath()
    end)
    
    RegisterNetEvent('trase_gangs:drugzone:winner', function(winnerData)
        lib.notify({
            title = 'Drug Zone Complete',
            description = winnerData.gangName .. ' has won with ' .. winnerData.points .. ' points!',
            type = 'success',
            duration = 7000
        })
    end)

    AddEventHandler('gameEventTriggered', function(name, args)
        if name == 'CEventNetworkEntityDamage' then
            local victim = args[1]
            local attacker = args[2]
            local isFatal = args[6] == 1

            -- If we are the victim and died, notify server of our death
            if self.isInDrugZone and victim == PlayerPedId() and isFatal then
                self:onDeath()
                TriggerServerEvent('trase_gangs:drugzone:playerDied')
            end

            -- If we are the attacker and killed another player while in the drug zone, record the kill
            if self.activeDrugZone and attacker == PlayerPedId() and IsPedAPlayer(victim) and isFatal then
                local victimId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(victim))
                if victimId and victimId > 0 then
                    TriggerServerEvent('trase_gangs:drugzone:recordKill', victimId)
                    if Config.Debug then print('[Drugzones] Recorded kill against playerId:', victimId) end
                end
            end
        end
    end)
end

Drugzones:new()