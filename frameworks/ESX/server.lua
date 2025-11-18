if Config.Framework ~= 'esx' and Config.Framework ~= 'auto' then return end

if GetResourceState('es_extended') ~= 'started' then
    return
end

local ESX = exports['es_extended']:getSharedObject()

function GetPlayer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        return {
            identifier = xPlayer.identifier,
            name = xPlayer.getName(),
            job = xPlayer.job and xPlayer.job.name or 'unemployed',
            money = xPlayer.getMoney(),
            accounts = xPlayer.getAccounts(),
            inventory = xPlayer.getInventory()
        }
    else
        return nil
    end
end

function GetPlayerFromId(source)
    return ESX.GetPlayerFromId(source)
end

function GetPlayerFromIdentifier(identifier)
    return ESX.GetPlayerFromIdentifier(identifier)
end

function GetPlayerIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier or nil
end

function GetPlayerName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.getName() or nil
end

function GetPlayerGroup(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.getGroup() or nil
end

function IsAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local group = xPlayer.getGroup()
        return group == 'admin' or group == 'superadmin'
    end
    return false
end

function SendNotification(source, data)
    TriggerClientEvent('ox_lib:notify', source, data)
end