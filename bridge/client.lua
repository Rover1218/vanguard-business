-- Vanguard Business - client bridge: ox_target / qb-target zones or [E] prompts, and character events.

ClientBridge = { target = nil }

if Config.UseTarget then
    if GetResourceState('ox_target') == 'started' then
        ClientBridge.target = 'ox'
    elseif GetResourceState('qb-target') == 'started' then
        ClientBridge.target = 'qb'
    end
end

local prompts = {} -- name -> { coords, option }

--- Draws text at a world position.
function ClientBridge.drawText3d(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

--- Adds one interaction at coords. option: { label, icon, action(), canInteract() }.
--- Returns a handle for ClientBridge.removeZone.
function ClientBridge.addZone(name, coords, radius, option)
    if ClientBridge.target == 'ox' then
        local id = exports.ox_target:addSphereZone({
            coords = coords, radius = radius, debug = false,
            options = { {
                name = name, label = option.label, icon = option.icon, distance = Config.InteractDistance,
                onSelect = function() option.action() end,
                canInteract = function() return option.canInteract() end,
            } },
        })
        return { kind = 'ox', id = id }
    elseif ClientBridge.target == 'qb' then
        exports['qb-target']:AddCircleZone(name, coords, radius, { name = name, debugPoly = false, useZ = true }, {
            options = { {
                label = option.label, icon = option.icon,
                action = function() option.action() end,
                canInteract = function() return option.canInteract() end,
            } },
            distance = Config.InteractDistance,
        })
        return { kind = 'qb', id = name }
    end
    prompts[name] = { coords = coords, option = option }
    return { kind = 'prompt', id = name }
end

function ClientBridge.removeZone(handle)
    if not handle then return end
    if handle.kind == 'ox' then
        exports.ox_target:removeZone(handle.id)
    elseif handle.kind == 'qb' then
        exports['qb-target']:RemoveZone(handle.id)
    else
        prompts[handle.id] = nil
    end
end

-- [E] prompts for servers without a target script.
CreateThread(function()
    while true do
        local sleep = 500
        if next(prompts) then
            local position = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance = nil, Config.InteractDistance
            for _, prompt in pairs(prompts) do
                local distance = #(position - prompt.coords)
                if distance <= nearestDistance and prompt.option.canInteract() then
                    nearest, nearestDistance = prompt, distance
                end
            end
            if nearest then
                sleep = 0
                ClientBridge.drawText3d(nearest.coords, ('[E] %s'):format(nearest.option.label))
                if IsControlJustReleased(0, Config.PromptKey) then nearest.option.action() end
            end
        end
        Wait(sleep)
    end
end)

-- Ask the server for our jobs whenever a character loads.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('vanguard-business:hello') end)
RegisterNetEvent('esx:playerLoaded', function() TriggerServerEvent('vanguard-business:hello') end)
