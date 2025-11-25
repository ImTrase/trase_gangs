if Config.Framework ~= 'qbcore' and Config.Framework ~= 'auto' then return end

if GetResourceState('qb-core') ~= 'started' then
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayerData()
    return QBCore.Functions.GetPlayerData()
end

function GetPlayerIdentifier()
    local playerData = QBCore.Functions.GetPlayerData()
    return playerData and playerData.citizenid or nil
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

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('trase_gangs:client:playerLoaded')
end)
