if Config.Framework ~= 'standalone' and Config.Framework ~= 'auto' then return end

if GetResourceState('es_extended') == 'started' or GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
    if Config.Framework == 'auto' then return end
end

function GetPlayerData()
    return {}
end

function GetPlayerIdentifier()
    return nil
end

function SendNotification(data)
    if Config.Debug then
        print(json.encode(data))
    end
end

function GetNearbyPlayers()
    local coords = GetEntityCoords(cache.ped)
    local players = lib.getNearbyPlayers(coords, 20, true)
    local nearbyPlayers = {}

    for _, playerId in ipairs(players) do
        local ped = GetPlayerPed(playerId.id)
        local distance = #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId()))
        nearbyPlayers[#nearbyPlayers +1] = {
            id = GetPlayerServerId(playerId.id),
            name = GetPlayerName(playerId.id),
            distance = distance
        }
    end

    return nearbyPlayers
end

RegisterNetEvent('playerSpawned', function()
    TriggerEvent('trase_gangs:client:playerLoaded')
end)
