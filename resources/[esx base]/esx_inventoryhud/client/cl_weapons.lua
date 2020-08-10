
---------------------------
-- Locals --
---------------------------
ESX = nil


---------------------------
-- ESX --
---------------------------
Citizen.CreateThread(function()
    while ESX == nil do
      TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
      Citizen.Wait(250)
    end
end)

RegisterNetEvent('dovux-ammo:useAmmoItem')
AddEventHandler('dovux-ammo:useAmmoItem', function(ammo)
    local playerPed = GetPlayerPed(-1)
    local weapon

    local found, currentWeapon = GetCurrentPedWeapon(playerPed, true)
    if found then
        for _, v in pairs(ammo.weapons) do
            if currentWeapon == v then
                weapon = v
                break
            end
        end
        if weapon ~= nil then
            local pedAmmo = GetAmmoInPedWeapon(playerPed, weapon)
            local newAmmo = pedAmmo + ammo.count
            ClearPedTasks(playerPed)
            local found, maxAmmo = GetMaxAmmo(playerPed, weapon)
            if newAmmo < maxAmmo then
                TaskReloadWeapon(playerPed)
                SetPedAmmo(playerPed, weapon, newAmmo)
                TriggerServerEvent('dovux-ammo:removeAmmoItem', ammo)
                exports['mythic_notify']:DoHudText('success', 'Recargada')
            else
                exports['mythic_notify']:DoHudText('error', 'Munición al máximo')
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local found, currentWeapon = GetCurrentPedWeapon(GetPlayerPed(-1))
        DisplayAmmoThisFrame(found)
    end
end)