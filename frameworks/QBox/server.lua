if Config.Framework ~= 'qbox' and Config.Framework ~= 'auto' then return end

if GetResourceState('qbx_core') ~= 'started' then
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayer(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return {
            identifier = Player.PlayerData.citizenid,
            name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            job = Player.PlayerData.job.name,
            money = Player.Functions.GetMoney('cash'),
            accounts = Player.PlayerData.money,
            inventory = Player.PlayerData.items
        }
    else
        return nil
    end
end

function GetPlayerFromId(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local self = {}
        self.source = source
        self.identifier = Player.PlayerData.citizenid
        self.job = Player.PlayerData.job
        
        self.getName = function()
            return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        end
        
        self.getMoney = function()
            return Player.Functions.GetMoney('cash')
        end
        
        self.getGroup = function()
            return QBCore.Functions.GetPermission(source)
        end
        
        return self
    else
        return nil
    end
end

function GetPlayerFromIdentifier(identifier)
    local Player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if Player then
        return GetPlayerFromId(Player.PlayerData.source)
    end
    return nil
end

function GetPlayerIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.citizenid or nil
end

function GetPlayerName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or nil
end

function GetPlayerGroup(source)
    return QBCore.Functions.GetPermission(source)
end

function IsAdmin(source)
    return QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
end

function SendNotification(source, data)
    TriggerClientEvent('ox_lib:notify', source, data)
end

function GetPrimaryIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.citizenid or nil
end

function AlertServer(target, message)
    TriggerClientEvent('chat:addMessage', target or -1, {
        color = {255, 0, 0},
        multiline = true,
        args = {"SYSTEM", message}
    })
end

function GiveItem(source, item, amount)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(source, item, amount)
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if item == 'cash' or item == 'money' then
            Player.Functions.AddMoney('cash', 1000)
        else
            exports['qb-inventory']:AddItem(source, item, amount, false, false, 'trase_gangs:add')
        end
    end
end