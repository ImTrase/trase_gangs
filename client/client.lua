lib.locale()

function DebugPrint(message)
    if Config.Debug then
        print('^2[Trase_Gangs] ^6[DEBUG]^0: ' .. message .. '^0')
    end
end

local activeInteractions = {}

function AddInteraction(id, options)
    if activeInteractions[id] then
        DebugPrint('Interaction with id "' .. id .. '" already exists!')
        return false
    end

    local interactionType = Config.InteractionType or 'ox_lib'
    local coords = options.coords
    local distance = options.distance or 2.0
    local entity = options.entity
    local onInteract = options.onInteract
    
    local label
    if options.localeKey then
        local localeKey = options.localeKey .. '_' .. interactionType
        label = TranslateText(localeKey)
        if Config.Debug then
            DebugPrint('Using locale key: ' .. localeKey .. ' = "' .. label .. '"')
        end
    else
        label = options.label
    end

    DebugPrint('Creating interaction "' .. id .. '" with type: ' .. interactionType)

    if interactionType == 'ox_lib' then
        local point = lib.points.new({
            coords = coords,
            distance = distance,
        })

        function point:onEnter()
            lib.showTextUI(label)
        end

        function point:onExit()
            lib.hideTextUI()
        end

        function point:nearby()
            if self.currentDistance <= distance and IsControlJustReleased(0, 38) then
                onInteract()
            end
        end

        activeInteractions[id] = { type = 'ox_lib', point = point }

    elseif interactionType == 'ox_target' then
        if entity then
            exports.ox_target:addLocalEntity(entity, {
                {
                    name = id,
                    label = label,
                    icon = 'fas fa-hand',
                    distance = distance,
                    onSelect = function()
                        onInteract()
                    end
                }
            })
            activeInteractions[id] = { type = 'ox_target', entity = entity }
        else
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = distance,
                options = {
                    {
                        name = id,
                        label = label,
                        icon = 'fas fa-hand',
                        onSelect = function()
                            onInteract()
                        end
                    }
                }
            })
            activeInteractions[id] = { type = 'ox_target', coords = coords }
        end

    elseif interactionType == 'draw3d' then
        local thread = CreateThread(function()
            while activeInteractions[id] do
                local playerCoords = GetEntityCoords(PlayerPedId())
                local dist = #(playerCoords - coords)

                if dist <= distance then
                    DrawText3D(coords.x, coords.y, coords.z, label)
                    
                    if dist <= distance and IsControlJustReleased(0, 38) then
                        onInteract()
                    end
                end

                Wait(0)
            end
        end)

        activeInteractions[id] = { type = 'draw3d', thread = thread }

    elseif interactionType == 'native' then
        local thread = CreateThread(function()
            while activeInteractions[id] do
                local playerCoords = GetEntityCoords(PlayerPedId())
                local dist = #(playerCoords - coords)

                if dist <= distance then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(label)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    
                    if IsControlJustReleased(0, 38) then
                        onInteract()
                    end
                end

                Wait(0)
            end
        end)

        activeInteractions[id] = { type = 'native', thread = thread }
    else
        DebugPrint('Invalid interaction type: ' .. interactionType)
        return false
    end

    DebugPrint('Successfully created interaction: ' .. id)
    return true
end

function RemoveInteraction(id)
    local interaction = activeInteractions[id]
    if not interaction then
        DebugPrint('Interaction with id "' .. id .. '" does not exist!')
        return false
    end

    DebugPrint('Removing interaction: ' .. id)

    if interaction.type == 'ox_lib' then
        if interaction.point then
            lib.hideTextUI()
            interaction.point:remove()
        end
    elseif interaction.type == 'ox_target' then
        if interaction.entity then
            exports.ox_target:removeLocalEntity(interaction.entity, id)
        else
            exports.ox_target:removeZone(id)
        end
    elseif interaction.type == 'draw3d' or interaction.type == 'native' then
    end

    activeInteractions[id] = nil
    DebugPrint('Successfully removed interaction: ' .. id)
    return true
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

require 'modules.handler.client'

RegisterNUICallback('trase_gangs:notify', function(data, cb)
    SendNUIMessage({
        action = 'notify',
        data = {
            title = data.title,
            description = data.description,
            type = data.type
        }
    })
    cb('ok')
end)

RegisterNUICallback('trase:getLocale', function(data, cb)
    local translated = TranslateText(data.key, data.default)
    DebugPrint('Translated key: ' .. data.key .. ' = "' .. translated .. '"')
    cb(translated)
end)