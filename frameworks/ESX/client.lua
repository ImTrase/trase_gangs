if Config.Framework ~= 'esx' and Config.Framework ~= 'auto' then return end

if GetResourceState('es_extended') ~= 'started' then
    return
end

local ESX = exports['es_extended']:getSharedObject()

function GetPlayerData()
    return ESX.GetPlayerData()
end

function GetPlayerIdentifier()
    local playerData = ESX.GetPlayerData()
    return playerData and playerData.identifier or nil
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

RegisterNetEvent('trase_gangs:framework:playerLoaded', function()
    TriggerEvent('trase_gangs:client:playerLoaded')
end)

RegisterNetEvent('esx:playerLoaded', function(playerData)
    TriggerEvent('trase_gangs:client:playerLoaded')
end)