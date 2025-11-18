local Drugzones = lib.class('Drugzones')
local ActivityOverlay = require('client.activity_overlay')

function Drugzones:constructor()
    if Config.Debug then
        print('[Drugzones] Initializing Drugzones...')
    end
    self.zones = {}
    self.activeNPCs = {}
    self.activeDrugZone = nil -- Currently active drug zone
    self.drugZonePoint = nil -- ox_lib point for zone detection
    self.isInDrugZone = false
    self.overlay = ActivityOverlay:new()
    self.currentKillstreak = 0
    self.gangStats = {} -- Updated from server
    
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

    local ped = CreatePed(4, GetHashKey(npcData.model), npcData.coords.x, npcData.coords.y, npcData.coords.z, npcData.coords.w, false, true)

    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    if npcData.scenario then
        TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
    end

    self.activeNPCs[zoneName] = ped

    -- Add interaction to the NPC
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

    -- Check if there's already an active zone
    local hasActiveZone, activeZoneName = lib.callback.await('trase_gangs:drugzone:checkActive', false)
    
    if hasActiveZone then
        lib.notify({
            title = 'Drug Zone Active',
            description = 'There is already an active drug zone: ' .. activeZoneName .. '. Please wait for it to finish.',
            type = 'error'
        })
        return
    end

    -- Start the drug zone
    local success, result = lib.callback.await('trase_gangs:drugzone:start', false, zoneName)
    
    if success then
        lib.notify({
            title = 'Drug Zone Started',
            description = 'The drug zone "' .. zoneName .. '" has been started!',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Error',
            description = 'Failed to start drug zone: ' .. tostring(result),
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
        
        -- Remove interaction
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
                onEnter = function()
                    if Config.Debug then
                        print('[Drugzones] Player entered zone: ' .. zoneName)
                    end
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

    -- Set active drug zone FIRST before creating the point
    self.activeDrugZone = zoneData
    
    if Config.Debug then
        print('[Drugzones] activeDrugZone set to: ' .. tostring(self.activeDrugZone ~= nil))
    end

    -- Create point for zone detection using ox_lib
    self.drugZonePoint = lib.points.new({
        coords = zoneData.coords,
        distance = zoneData.radius,
    })

    local drugzonesInstance = self
    
    function self.drugZonePoint:onEnter()
        if Config.Debug then
            print('Entered Drug Zone')
            print('[Drugzones] Instance check - activeDrugZone exists: ' .. tostring(drugzonesInstance.activeDrugZone ~= nil))
            print('[Drugzones] Player gang ID:', LocalPlayer.state.gang)
        end
        drugzonesInstance.isInDrugZone = true
        TriggerServerEvent('trase_gangs:drugzone:playerEnter')
        
        -- Wait longer for server to process and send stats back
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

    -- Start drawing marker
    CreateThread(function()
        while self.activeDrugZone do
            Wait(0)
            local markerColor = Config.Features.Drugzones.MarkerColor
            DrawMarker(
                Config.Features.Drugzones.MarkerType,
                zoneData.coords.x,
                zoneData.coords.y,
                zoneData.coords.z - 1.0,
                0.0, 0.0, 0.0, -- direction
                0.0, 0.0, 0.0, -- rotation
                zoneData.radius * 2.0, zoneData.radius * 2.0, zoneData.radius * 2.0, -- scale
                markerColor.r, markerColor.g, markerColor.b, markerColor.a,
                false, false, 2, false, nil, nil, false
            )
        end
    end)

    -- Schedule zone end notification
    SetTimeout(zoneData.duration * 1000, function()
        lib.notify({
            title = 'Drug Zone',
            description = 'The drug zone has ended!',
            type = 'info'
        })
    end)

    lib.notify({
        title = 'Drug Zone Active',
        description = 'A drug zone has started at ' .. zoneData.name .. ' for ' .. zoneData.duration .. ' seconds!',
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

    -- Hide overlay and reset stats
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
    
    -- Get next kill reward if enabled
    local nextReward = self:getNextKillReward()
    
    -- Get player's gang points
    local playerGangPoints = 0
    local gangTbl = LocalPlayer.state.gang

    local playerGangId = gangTbl and gangTbl.id or nil
    if playerGangId and self.gangStats[playerGangId] then
        playerGangPoints = self.gangStats[playerGangId].points or 0
    end
    
    -- Build stats array
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
    
    -- Add next reward if available
    if nextReward then
        stats[#stats + 1] = {
            label = 'Next Kill Reward',
            value = nextReward.label .. ' (' .. nextReward.kills .. ' kills)'
        }
    end
    
    -- Build leaderboard from gang stats
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
            points = points -- Store for sorting
        }
    end
    
    if Config.Debug then
        print('[Drugzones] Building leaderboard with ' .. gangCount .. ' gangs')
        for gangId, gangData in pairs(self.gangStats) do
            print('  Gang: ' .. (gangData.name or gangId) .. ' - Points: ' .. (gangData.points or 0))
        end
    end
    
    -- Sort leaderboard by points
    table.sort(leaderboard, function(a, b)
        return (a.points or 0) > (b.points or 0)
    end)
    
    -- Update positions
    for i, entry in ipairs(leaderboard) do
        entry.position = i
        entry.points = nil -- Remove temporary sorting field
    end
    
    if Config.Debug then
        print('[Drugzones] Showing overlay with data:')
        print('  Title: ' .. (self.activeDrugZone.name or 'DRUG ZONE'))
        print('  Stats count: ' .. #stats)
        print('  Leaderboard count: ' .. #leaderboard)
    end
    
    self.overlay:Show({
        title = self.activeDrugZone.name or 'DRUG ZONE',
        description = 'First gang to ' .. Config.Features.Drugzones.WinningPoints .. ' points wins',
        stats = stats,
        leaderboard = leaderboard,
        showTimer = true,
        timerDuration = self.activeDrugZone.duration or Config.Features.Drugzones.Duration,
        timerLabel = 'TIME REMAINING'
    })
    
    if Config.Debug then
        print('[Drugzones] Overlay:Show() called successfully with ' .. (self.activeDrugZone.duration or Config.Features.Drugzones.Duration) .. 's timer')
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
    
    -- Find next reward milestone
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
end

Drugzones:new()