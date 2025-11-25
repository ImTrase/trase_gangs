if Config.Framework ~= 'standalone' and Config.Framework ~= 'auto' then return end

if GetResourceState('es_extended') == 'started' or GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
    if Config.Framework == 'auto' then return end
end

function GetPrimaryIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return identifiers[1]
end

function GetPlayer(source)
    return {
        identifier = GetPrimaryIdentifier(source),
        name = GetPlayerName(source),
        job = 'unemployed',
        money = 0,
        accounts = {},
        inventory = {}
    }
end

function GetPlayerFromId(source)
    local self = {}
    self.source = source
    self.identifier = GetPrimaryIdentifier(source)
    self.job = { name = 'unemployed', label = 'Unemployed' }
    
    self.getName = function()
        return GetPlayerName(source)
    end
    
    self.getMoney = function()
        return 0
    end
    
    self.getGroup = function()
        return 'user'
    end
    
    return self
end

function GetPlayerFromIdentifier(identifier)
    for _, src in ipairs(GetPlayers()) do
        if GetPrimaryIdentifier(tonumber(src)) == identifier then
            return GetPlayerFromId(tonumber(src))
        end
    end
    return nil
end

function GetPlayerIdentifier(source)
    return GetPrimaryIdentifier(source)
end

function GetPlayerName(source)
    return GetPlayerName(source)
end

function GetPlayerGroup(source)
    return IsPlayerAceAllowed(source, 'command') and 'admin' or 'user'
end

function IsAdmin(source)
    return IsPlayerAceAllowed(source, 'command')
end

function SendNotification(source, data)
    TriggerClientEvent('ox_lib:notify', source, data)
end

function AlertServer(target, message)
    TriggerClientEvent('chat:addMessage', target or -1, {
        color = {255, 0, 0},
        multiline = true,
        args = {"SYSTEM", message}
    })
end
