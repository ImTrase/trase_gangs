local Handler = {}
Handler.currentGang = nil
Handler.onlineMembers = {}
Handler.activeStashInteraction = nil
Handler.stashMarkerThreadRunning = false

local function DebugPrint(...)
    if Config.Debug then
        print(...)
    end
end

function Handler:Init()
    if Config.Debug then
        DebugPrint('[Handler Client] Initializing...')
    end
    
    self:RequestGangData()
    
    RegisterNetEvent('trase_gangs:client:playerLoaded', function()
        Wait(1000)
        self:RequestGangData()
    end)
    
    RegisterNetEvent('trase_gangs:client:gangUpdated', function(gangData)
        self.currentGang = gangData
        self:UpdateStashInteraction()
        if Config.Debug then
            DebugPrint('[Handler Client] Gang data updated')
        end
    end)
    
    RegisterNetEvent('trase_gangs:client:gangRemoved', function()
        self.currentGang = nil
        self:UpdateStashInteraction()
        if Config.Debug then
            DebugPrint('[Handler Client] Player removed from gang')
        end
    end)

    RegisterNetEvent('trase_gangs:client:serverReady', function()
        if Config.Debug then
            DebugPrint('[Handler Client] Server reported ready, refreshing gang data...')
        end
        self:RequestGangData()
        
        -- Send UI Config
        if Config.UI and Config.UI.Colors then
            SendNUIMessage({
                action = 'updateTheme',
                data = Config.UI.Colors
            })
        end
    end)
end

function Handler:RequestGangData()
    lib.callback('trase_gangs:server:getPlayerGang', false, function(gang)
        self.currentGang = gang
        self:UpdateStashInteraction()
        if gang then
            if Config.Debug then
                DebugPrint('[Handler Client] Loaded gang: ' .. gang.label)
            end
        end
    end)
end

function Handler:UpdateStashInteraction()
    -- Remove active interaction if it exists
    if self.activeStashInteraction then
        RemoveInteraction(self.activeStashInteraction)
        self.activeStashInteraction = nil
    end
    
    if self.currentGang and self.currentGang.stash_coords then
        local coords = self.currentGang.stash_coords
        
        if Config.Debug then
            DebugPrint('[Handler Client] Updating stash interaction. Coords type: ' .. type(coords))
        end

        -- Ensure coords is a vector3 or table with x,y,z
        if (type(coords) == 'table' or type(coords) == 'vector3') and coords.x and coords.y and coords.z then
            local vecCoords = vector3(coords.x, coords.y, coords.z)
            local interactionId = 'gang_stash_' .. (self.currentGang.name or 'unknown')
            
            if Config.Debug then
                DebugPrint('[Handler Client] Adding interaction at: ' .. vecCoords)
            end

            AddInteraction(interactionId, {
                label = '[E] - Open Stash',
                coords = vecCoords,
                distance = 2.0,
                onInteract = function()
                    if self:HasPermission('access_stash') then
                        exports.ox_inventory:openInventory('stash', 'gang_' .. self.currentGang.id)
                    else
                        lib.notify({
                            title = 'Error',
                            description = 'You do not have permission to access the stash',
                            type = 'error'
                        })
                    end
                end
            })
            
            self.activeStashInteraction = interactionId

            -- Start marker thread
            if not self.stashMarkerThreadRunning then
                self.stashMarkerThreadRunning = true
                CreateThread(function()
                    while self.currentGang and self.currentGang.stash_coords do
                        local sleep = 1000
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        local stashCoords = vector3(self.currentGang.stash_coords.x, self.currentGang.stash_coords.y, self.currentGang.stash_coords.z)
                        local dist = #(playerCoords - stashCoords)

                        if dist < 10.0 then
                            sleep = 0
                            DrawMarker(2, stashCoords.x, stashCoords.y, stashCoords.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 200, false, true, 2, false, nil, nil, false)
                            DrawMarker(29, stashCoords.x, stashCoords.y, stashCoords.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 72, 187, 120, 200, false, true, 2, false, nil, nil, false)
                        end
                        Wait(sleep)
                    end
                    self.stashMarkerThreadRunning = false
                end)
            end
        else
            if Config.Debug then
                DebugPrint('[Handler Client] Invalid stash coords format. Type: ' .. type(coords))
            end
        end
    else
        if Config.Debug then
            if not self.currentGang then
                DebugPrint('[Handler Client] No gang data found (self.currentGang is nil)')
            else
                DebugPrint('[Handler Client] No stash coords found for gang: ' .. (self.currentGang.label or 'unknown'))
                DebugPrint('[Handler Client] stash_coords value: ' .. tostring(self.currentGang.stash_coords))
            end
        end
    end
end

function Handler:GetCurrentGang()
    return self.currentGang
end

function Handler:IsInGang()
    return self.currentGang ~= nil
end

function Handler:HasPermission(permission)
    if not self:IsInGang() then
        return false
    end
    
    return lib.callback.await('trase_gangs:server:hasPermission', false, permission)
end

function Handler:IsOwner()
    if not self:IsInGang() then
        return false
    end
    
    local playerData = GetPlayerData()
    return self.currentGang.owner_identifier == playerData.identifier
end

function Handler:AdminCreateGang(data, callback)
    lib.callback('trase_gangs:server:admin:createGang', false, function(success, result)
        if callback then
            callback(success, result)
        end
    end, data)
end

function Handler:AdminDeleteGang(gangId, callback)
    lib.callback('trase_gangs:server:admin:deleteGang', false, function(success, result)
        if callback then
            callback(success, result)
        end
    end, gangId)
end

function Handler:AdminUpdateGangSettings(gangId, data, callback)
    lib.callback('trase_gangs:server:admin:updateGangSettings', false, function(success, result)
        if callback then
            callback(success, result)
        end
    end, gangId, data)
end

function Handler:AdminGetAllGangs()
    local gangs = lib.callback.await('trase_gangs:server:admin:getAllGangs', false)
    DebugPrint('[Client Handler] AdminGetAllGangs received:', json.encode(gangs))
    DebugPrint('[Client Handler] Gangs type:', type(gangs))
    if gangs then
        DebugPrint('[Client Handler] Number of gangs:', #gangs)
    end
    return gangs or {}
end

function Handler:InviteMember(targetServerId, callback)
    lib.callback('trase_gangs:server:inviteMember', false, function(success, result)
        if callback then
            callback(success, result)
        end
    end, targetServerId)
end

function Handler:KickMember(identifier, callback)
    lib.callback('trase_gangs:server:kickMember', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('member_kicked_title'),
                description = locale('member_kicked_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('kick_failed', result),
                type = 'error'
            })
        end
    end, identifier)
end

function Handler:SetMemberRank(identifier, rankGrade, callback)
    lib.callback('trase_gangs:server:setMemberRank', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('rank_changed_title'),
                description = locale('rank_changed_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('rank_change_failed', result),
                type = 'error'
            })
        end
    end, identifier, rankGrade)
end

function Handler:UpdateGangInfo(data, callback)
    lib.callback('trase_gangs:server:updateGangInfo', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('gang_updated_title'),
                description = locale('gang_updated_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('update_failed', result),
                type = 'error'
            })
        end
    end, data)
end

function Handler:SaveRank(rankData, callback)
    lib.callback('trase_gangs:server:saveRank', false, function(success, result)
        DebugPrint('daddy madde it here')
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('rank_saved_title'),
                description = locale('rank_saved_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('rank_save_failed', result),
                type = 'error'
            })
        end
    end, rankData)
end

function Handler:DeleteRank(rankId, callback)
    lib.callback('trase_gangs:server:deleteRank', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('rank_deleted_title'),
                description = locale('rank_deleted_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('rank_delete_failed', result),
                type = 'error'
            })
        end
    end, rankId)
end

function Handler:GetMemberStats(identifier, callback)
    lib.callback('trase_gangs:server:getMemberStats', false, function(stats)
        if callback then
            callback(stats)
        end
    end, identifier)
end

function Handler:GetAuditLogs(limit, callback)
    lib.callback('trase_gangs:server:getAuditLogs', false, function(logs)
        if callback then
            callback(logs)
        end
    end, limit)
end

function Handler:AcceptInvite(inviteId, callback)
    lib.callback('trase_gangs:server:acceptInvite', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('invite_accepted_title'),
                description = locale('invite_accepted_desc'),
                type = 'success'
            })
            self:RequestGangData()
        else
            lib.notify({
                title = locale('error'),
                description = locale('invite_accept_failed', result),
                type = 'error'
            })
        end
    end, inviteId)
end

function Handler:DeclineInvite(inviteId, callback)
    lib.callback('trase_gangs:server:declineInvite', false, function(success)
        if callback then
            callback(success)
        end
        
        if success then
            lib.notify({
                title = locale('invite_declined_title'),
                description = locale('invite_declined_desc'),
                type = 'info'
            })
        end
    end, inviteId)
end

function Handler:GetPendingInvites(callback)
    lib.callback('trase_gangs:server:getPendingInvites', false, function(invites)
        if callback then
            callback(invites)
        end
    end)
end

function Handler:LeaveGang(callback)
    lib.callback('trase_gangs:server:leaveGang', false, function(success, result)
        if callback then
            callback(success, result)
        end
        
        if success then
            lib.notify({
                title = locale('left_gang_title'),
                description = locale('left_gang_desc'),
                type = 'info'
            })
            self.currentGang = nil
        else
            lib.notify({
                title = locale('error'),
                description = locale('leave_failed', result),
                type = 'error'
            })
        end
    end)
end

function Handler:GetOnlineMembers(callback)
    lib.callback('trase_gangs:server:getOnlineMembers', false, function(members)
        if callback then
            callback(members)
        end
    end)
end

function Handler:GetLeaderboard(category, callback)
    lib.callback('trase_gangs:server:getLeaderboard', false, function(leaderboard)
        if callback then
            callback(leaderboard)
        end
    end, category)
end

RegisterNetEvent('trase_gangs:client:openDashboard', function(data)
    DebugPrint('[Client] openDashboard received data:', json.encode(data))
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'dashboard:open',
        data = data or {}
    })
end)

RegisterNetEvent('trase_gangs:client:openServerManagement', function()
    local gangs = Handler:AdminGetAllGangs()
    DebugPrint('[Client] Received gangs from server:', json.encode(gangs))
    DebugPrint('[Client] Number of gangs:', gangs and #gangs or 0)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'serverManagement:open',
        data = {
            gangs = gangs or {}
        }
    })
end)

RegisterNetEvent('trase_gangs:client:openLeaderboard', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'leaderboard:open',
        data = {}
    })
end)

RegisterNUICallback('dashboard:closeUI', function(_, cb)
    SetNuiFocus(false, false)
    if cb then cb(1) end
end)

RegisterNUICallback('serverManagement:closeUI', function(_, cb)
    SetNuiFocus(false, false)
    if cb then cb(1) end
end)

RegisterNUICallback('serverManagement:createGang', function(data, cb)
    Handler:AdminCreateGang(data, function(success, result)
        if success then
            local gangs = Handler:AdminGetAllGangs()
            SendNUIMessage({
                action = 'serverManagement:updateGangs',
                data = {
                    gangs = gangs
                }
            })
            SendNUIMessage({
                action = 'serverManagement:notify',
                data = {
                    type = 'success',
                    title = 'Gang Created',
                    message = 'Gang has been successfully created!'
                }
            })
            SendNUIMessage({
                action = 'serverManagement:gangCreated',
                data = {
                    gangId = result
                }
            })
        else
            local errorMessages = {
                player_not_online = 'Owner ID is not online or invalid',
                invalid_server_id = 'Invalid server ID provided',
                gang_name_exists = 'A gang with this name already exists',
                database_error = 'Database error occurred',
                no_permission = 'You do not have permission'
            }
            local errorMsg = errorMessages[result] or 'Failed to create gang'
            
            SendNUIMessage({
                action = 'serverManagement:notify',
                data = {
                    type = 'error',
                    title = 'Creation Failed',
                    message = errorMsg
                }
            })
        end
        cb(success)
    end)
end)

RegisterNUICallback('serverManagement:deleteGang', function(data, cb)
    Handler:AdminDeleteGang(data.gangId, function(success, result)
        if success then
            local gangs = Handler:AdminGetAllGangs()
            SendNUIMessage({
                action = 'serverManagement:updateGangs',
                data = {
                    gangs = gangs
                }
            })
            SendNUIMessage({
                action = 'serverManagement:notify',
                data = {
                    type = 'success',
                    title = 'Gang Deleted',
                    message = 'Gang has been successfully deleted'
                }
            })
        else
            SendNUIMessage({
                action = 'serverManagement:notify',
                data = {
                    type = 'error',
                    title = 'Deletion Failed',
                    message = 'Failed to delete gang'
                }
            })
        end
        cb(success)
    end)
end)

RegisterNUICallback('serverManagement:updateGang', function(data, cb)
    Handler:AdminUpdateGangSettings(data.id, data, function(success, result)
        if success then
            local gangs = Handler:AdminGetAllGangs()
            SendNUIMessage({
                action = 'serverManagement:updateGangs',
                data = {
                    gangs = gangs
                }
            })
        end
        cb(success)
    end)
end)

RegisterNUICallback('notify', function(data, cb)
    DebugPrint(json.encode(data))
    cb('ok')
end)

RegisterNUICallback('createRank', function(data, cb)
    DebugPrint('[createRank] Callback triggered with data:', json.encode(data))
    local success, result = lib.callback.await('trase_gangs:server:saveRank', false, {
        name = data.name,
        grade = data.grade or 1,
        permissions = data.permissions or {}
    })
    DebugPrint('[createRank] Server response - success:', success, 'result:', type(result) == 'table' and json.encode(result) or result)
    cb({ success = success, result = result, newRank = result })
end)

RegisterNUICallback('updateRankPermissions', function(data, cb)
    local success, result = lib.callback.await('trase_gangs:server:saveRank', false, {
        id = data.rankId,
        name = data.name,
        grade = data.grade,
        permissions = data.permissions
    })
    DebugPrint('[updateRankPermissions] Server response - success:', success, 'result:', type(result) == 'table' and json.encode(result) or result)
    cb({ success = success, result = result, updatedRank = result })
end)

RegisterNUICallback('renameRank', function(data, cb)
    local success, result = lib.callback.await('trase_gangs:server:saveRank', false, {
        id = data.rankId,
        name = data.name,
        grade = data.grade,
        permissions = data.permissions
    })
    DebugPrint('[renameRank] Server response - success:', success, 'result:', type(result) == 'table' and json.encode(result) or result)
    cb({ success = success, result = result, updatedRank = result })
end)

RegisterNUICallback('deleteRank', function(data, cb)
    local success, result = lib.callback.await('trase_gangs:server:deleteRank', false, data.rankId)
    DebugPrint('[deleteRank] Server response - success:', success, 'updated ranks:', result and #result or 0)
    cb({ success = success, result = result, updatedRanks = result })
end)

RegisterNUICallback('reorderRank', function(data, cb)
    local response = lib.callback.await('trase_gangs:server:reorderRank', false, data.rankId, data.direction)
    if response then
        DebugPrint('[reorderRank] Server response - success:', response.success, 'updated ranks:', response.updatedRanks and #response.updatedRanks or 0)
        cb(response)
    else
        DebugPrint('[reorderRank] Server response was nil')
        cb({success = false, result = 'server_error'})
    end
end)

RegisterNUICallback('refreshGangData', function(_, cb)
    DebugPrint('[Client] refreshGangData callback triggered')
    local gangData = lib.callback.await('trase_gangs:server:getGangDataForUI', false)
    DebugPrint('[Client] refreshGangData received data:', gangData and 'YES' or 'NO')
    if gangData then
        DebugPrint('[Client] refreshGangData ranks count:', gangData.ranks and #gangData.ranks or 0)
        cb({ success = true, data = gangData })
    else
        DebugPrint('[Client] refreshGangData failed - no data')
        cb({ success = false })
    end
end)

RegisterNUICallback('getAuditLogs', function(data, cb)
    local limit = data.limit or 50
    local logs = lib.callback.await('trase_gangs:server:getAuditLogs', false, limit)
    DebugPrint('[Client] getAuditLogs received', logs and #logs or 0, 'logs')
    cb(logs or {})
end)

RegisterNUICallback('getNearbyPlayers', function(data, cb)
    local players = GetNearbyPlayers()
    DebugPrint('[Client] getNearbyPlayers received', players and #players or 0, 'players')
    cb({ players = players or {} })
end)

RegisterNUICallback('inviteMember', function(data, cb)
    DebugPrint('[Client] inviteMember callback triggered with targetServerId:', data.targetServerId)
    local success, result = lib.callback.await('trase_gangs:server:inviteMember', false, data.targetServerId)
    DebugPrint('[Client] inviteMember response - success:', success, 'result:', result)
    cb({ success = success, result = result })
end)

RegisterNUICallback('getGangWarData', function(data, cb)
    local warData = lib.callback.await('trase_gangs:server:getGangWarData', false)
    DebugPrint('[Client] getGangWarData received', warData and 'data' or 'nil')
    cb(warData or {})
end)

RegisterNUICallback('sendGangWarInvite', function(data, cb)
    DebugPrint('[Client] sendGangWarInvite callback with gangId:', data.gangId)
    local response = lib.callback.await('trase_gangs:server:sendGangWarInvite', false, data)
    DebugPrint('[Client] sendGangWarInvite response:', json.encode(response))
    cb(response)
end)

RegisterNUICallback('acceptGangWarRequest', function(data, cb)
    DebugPrint('[Client] acceptGangWarRequest callback with requestId:', data.requestId)
    local success, result = lib.callback.await('trase_gangs:server:acceptGangWarRequest', false, data)
    DebugPrint('[Client] acceptGangWarRequest response - success:', success, 'result:', result)
    cb({ success = success, result = result })
end)

RegisterNUICallback('declineGangWarRequest', function(data, cb)
    DebugPrint('[Client] declineGangWarRequest callback with requestId:', data.requestId)
    local success, result = lib.callback.await('trase_gangs:server:declineGangWarRequest', false, data)
    DebugPrint('[Client] declineGangWarRequest response - success:', success, 'result:', result)
    cb({ success = success, result = result })
end)

RegisterNUICallback('cancelGangWarInvite', function(data, cb)
    DebugPrint('[Client] cancelGangWarInvite callback with requestId:', data.requestId)
    local success, result = lib.callback.await('trase_gangs:server:cancelGangWarInvite', false, data)
    DebugPrint('[Client] cancelGangWarInvite response - success:', success, 'result:', result)
    cb({ success = success, result = result })
end)

function Handler:StartStashPlacement(gangId)
    SetNuiFocus(false, false)
    -- Small delay to ensure NUI focus is fully cleared before checking controls
    Wait(200)
    
    if not gangId then
        lib.notify({
            title = 'Error',
            description = 'Invalid gang ID for stash placement',
            type = 'error'
        })
        return
    end
    
    local placing = true
    local coords = GetEntityCoords(PlayerPedId())
    
    lib.showTextUI('Press [Enter] to confirm placement  \nPress [Backspace] to cancel', {
        position = "top-center",
        icon = "box",
        style = {
            borderRadius = 0,
            backgroundColor = '#48BB78',
            color = 'white'
        }
    })

    CreateThread(function()
        while placing do
            -- Disable Enter key in game to prevent other interactions while placing
            DisableControlAction(0, 191, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 201, true)
            
            local hit, _, endCoords, _, _ = lib.raycast.cam(1, PlayerPedId())
            
            if hit then
                coords = endCoords
            end
            
            DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 200, false, true, 2, false, nil, nil, false)
            DrawMarker(29, coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 72, 187, 120, 200, false, true, 2, false, nil, nil, false)
            
            -- Check for disabled controls since we disabled them
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 18) or IsDisabledControlJustPressed(0, 201) then -- Enter
                placing = false
                lib.hideTextUI()
                
                lib.callback('trase_gangs:server:admin:updateGangStash', false, function(success, result)
                    if success then
                        lib.notify({
                            title = 'Stash Placed',
                            description = 'Gang stash location has been updated',
                            type = 'success'
                        })
                        
                        -- Re-open the menu
                        TriggerEvent('trase_gangs:client:openServerManagement')
                    else
                        lib.notify({
                            title = 'Error',
                            description = result or 'Failed to update stash',
                            type = 'error'
                        })
                        TriggerEvent('trase_gangs:client:openServerManagement')
                    end
                end, gangId, coords)
            end
            
            if IsControlJustPressed(0, 177) then -- Backspace
                placing = false
                lib.hideTextUI()
                TriggerEvent('trase_gangs:client:openServerManagement')
            end
            
            Wait(0)
        end
    end)
end

RegisterNUICallback('serverManagement:placeStash', function(data, cb)
    Handler:StartStashPlacement(data.gangId)
    cb('ok')
end)

Handler:Init()

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('trase_gangs:server:playerReady')
end)

exports('GetClientHandler', function()
    return Handler
end)

RegisterNUICallback('leaderboard:getAll', function(data, cb)
    local result = lib.callback.await('trase_gangs:server:getLeaderboards', false, { limit = (data and data.limit) or 25 })
    cb(result or { drugzones = {}, turfs = {}, gangwars = {}, reputation = {} })
end)

RegisterNUICallback('leaderboard:closeUI', function(_, cb)
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('fetchTheme', function(_, cb)
    if Config.UI and Config.UI.Colors then
        cb(Config.UI.Colors)
    else
        cb({})
    end
end)

RegisterCommand('debuggang', function()
    if Handler.currentGang then
        print('^2[DebugGang] ^7Current Gang: ' .. (Handler.currentGang.label or 'Unknown') .. ' (ID: ' .. (Handler.currentGang.id or 'nil') .. ')')
        print('^2[DebugGang] ^7Stash Coords: ' .. json.encode(Handler.currentGang.stash_coords))
        if Handler.currentGang.stash_coords then
            print('^2[DebugGang] ^7Coords Type: ' .. type(Handler.currentGang.stash_coords))
        end
    else
        print('^2[DebugGang] ^7Not in a gang or gang data not loaded.')
    end
end, false)

return Handler