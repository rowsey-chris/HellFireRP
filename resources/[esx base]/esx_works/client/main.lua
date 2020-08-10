local Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX                             = nil
local PlayerData                = {}
local GUI                       = {}
GUI.Time                        = 0
local HasAlreadyEnteredMarker   = false
local LastZone                  = nil
local CurrentAction             = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}
local onDuty                    = false
local BlipCloakRoom             = nil
local BlipVehicle               = nil
local BlipVehicleDeleter		= nil
local Blips                     = {}
local OnJob                     = false
local Done 						= false

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(10)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
	onDuty = false
    CreateBlip()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
	onDuty = false
    CreateBlip()
end)

-- NPC MISSIONS

function SelectPool()
    local index = GetRandomIntInRange(1,  #Config.Pool)

    for k,v in pairs(Config.Zones) do
      if v.Pos.x == Config.Pool[index].x and v.Pos.y == Config.Pool[index].y and v.Pos.z == Config.Pool[index].z then
        return k
      end
    end
end

function StartNPCJob()
    NPCTargetPool     = SelectPool()
    local zone            = Config.Zones[NPCTargetPool]

    Blips['NPCTargetPool'] = AddBlipForCoord(zone.Pos.x,  zone.Pos.y,  zone.Pos.z)
    SetBlipRoute(Blips['NPCTargetPool'], true)
	exports['mythic_notify']:DoHudText('inform', 'A new job has been highlighted on your GPS', 2500, { ['background-color'] = '#5D00BF', ['color'] = '#ffffff' })
--    ESX.ShowNotification(_U('GPS_info'))
    Done = true
end

function StopNPCJob(cancel)

    if Blips['NPCTargetPool'] ~= nil then
      RemoveBlip(Blips['NPCTargetPool'])
      Blips['NPCTargetPool'] = nil
	end

	OnJob = false

    if cancel then
	exports['mythic_notify']:DoHudText('inform', 'You have cancelled the mission', 2500, { ['background-color'] = '#5D00BF', ['color'] = '#ffffff' })
--	  ESX.ShowNotification(_U('cancel_mission'))
	else
		TriggerServerEvent('esx_cityworks:GiveItem')
		StartNPCJob()
		Done = true
	end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)

        if NPCTargetPool ~= nil then

            local coords = GetEntityCoords(GetPlayerPed(-1))
            local zone   = Config.Zones[NPCTargetPool]
            local playerPed = GetPlayerPed(-1)

           	if GetDistanceBetweenCoords(coords, zone.Pos.x, zone.Pos.y, zone.Pos.z, true) < 3 then

                HelpPromt(_U('pickup'))

                if IsControlJustReleased(1, Keys["E"]) and PlayerData.job ~= nil then
					TaskStartScenarioInPlace(playerPed, "CODE_HUMAN_POLICE_INVESTIGATE", 0, true)
					exports['progressBars']:startUI(10000,"Identificando la falla")
					FreezeEntityPosition(PlayerPedId(), true)
					Wait(10000)
					ClearPedTasksImmediately(playerPed)
					FreezeEntityPosition(PlayerPedId(), false)
        --[[            TaskStartScenarioInPlace(playerPed, "CODE_HUMAN_POLICE_INVESTIGATE", 0, true)
					exports['progressBars']:startUI(12000,"Quitando uniforme") ]]--
					Wait(1000)
					
                    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)
					exports['progressBars']:startUI(20000,"Reparando")
                    Wait(17000)
                    StopNPCJob()
                    Wait(3000)
                    ClearPedTasksImmediately(playerPed)
                    Done = false
                end
            end
        end
    end
end)





-- Prise de service
function CloakRoomMenu()
local playerPed  = GetPlayerPed(-1)
local lib, anim = 'clothingshirt', 'try_shirt_positive_d' -- TODO better animations

	local elements = {}

	if onDuty then
		table.insert(elements, {label = _U('end_service'), value = 'citizen_wear'})
	else
		table.insert(elements, {label = _U('take_service'), value = 'job_wear'})
	end

    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'cloakroom',
        {
            title = 'Electricista',
			align    = 'bottom',
            elements = elements
        },
        function(data, menu)

            if data.current.value == 'citizen_wear' then
				RemoveBlip(Blips['NPCTargetPool'])
				Onjob = false
				onDuty = false
				CreateBlip()
				menu.close()
        --        ESX.ShowNotification(_U('end_service_notif'))
				exports['mythic_notify']:DoHudText('inform', 'Ended service', 2500, { ['background-color'] = '#5D00BF', ['color'] = '#ffffff' })
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
				  local model = nil

				  if skin.sex == 0 then
					model = GetHashKey("mp_m_freemode_01")
				  else
					model = GetHashKey("mp_f_freemode_01")
				  end

				  RequestModel(model)
				  while not HasModelLoaded(model) do
					RequestModel(model)
					Citizen.Wait(1)
				  end
				  
				  ESX.Streaming.RequestAnimDict(lib, function()
			TaskPlayAnim(playerPed, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
			exports['progressBars']:startUI(10000,"Taking off uniform")
			Citizen.Wait(500)
			DoScreenFadeOut(10)
			
			
			while IsEntityPlayingAnim(playerPed, lib, anim, 3) do
				Citizen.Wait(0)
				DisableAllControlActions(0)
			end 
				  
				  
				  SetPlayerModel(PlayerId(), model)
				  SetModelAsNoLongerNeeded(model)

				  TriggerEvent('skinchanger:loadSkin', skin)
				  TriggerEvent('esx:restoreLoadout')
				  
				  DoScreenFadeIn(10)
				end)
    	end)
				  
				  local playerPed = GetPlayerPed(-1)
				  -- SetPedArmour(playerPed, 0)
				  ClearPedBloodDamage(playerPed)
				  ResetPedVisibleDamage(playerPed)
				  ClearPedLastWeaponDamage(playerPed)
				end
           

            if data.current.value == 'job_wear' then
				
				onDuty = true
				CreateBlip()
                menu.close()
--				ESX.ShowNotification(_U('take_service_notif'))
--				exports['mythic_notify']:DoHudText('inform', 'Servicio iniciado', 2500, { ['background-color'] = '#5D00BF', ['color'] = '#ffffff' })
				
--				exports['mythic_notify']:DoHudText('inform', 'Presiona F6 arriba del camion para iniciar el trabajo', 12500, { ['background-color'] = '#42CE00', ['color'] = '#ffffff' })
--				ESX.ShowNotification(_U('start_job'))
				local playerPed = GetPlayerPed(-1)
				
				ESX.Streaming.RequestAnimDict(lib, function()
			TaskPlayAnim(playerPed, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
			exports['progressBars']:startUI(10000,"Putting the uniform")
			Citizen.Wait(500)
			DoScreenFadeOut(10)
			
			
			while IsEntityPlayingAnim(playerPed, lib, anim, 3) do
				Citizen.Wait(0)
				DisableAllControlActions(0)
			end 
				
				
				setUniform(data.current.value, playerPed)
				DoScreenFadeIn(10)
				-- SetPedArmour(playerPed, 0)
				ClearPedBloodDamage(playerPed)
				ResetPedVisibleDamage(playerPed)
				ClearPedLastWeaponDamage(playerPed)
				StartNPCJob()
				Onjob = true
            end)
			end
            CurrentAction     = 'cloakroom_menu'
            CurrentActionMsg  = Config.Zones.Cloakroom.hint
            CurrentActionData = {}
        end,
        function(data, menu)

            menu.close()

			CurrentAction     = 'cloakroom_menu'
			CurrentActionMsg  = Config.Zones.Cloakroom.hint
            CurrentActionData = {}
        end
    )

end

-- Prise du véhicule
function VehicleMenu()

    local elements = {
        {label = Config.Vehicles.Truck.Label, value = Config.Vehicles.Truck}
    }

    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'spawn_vehicle',
        {
            title    = _U('Vehicle_Menu_Title'),
            elements = elements
        },
        function(data, menu)
            for i=1, #elements, 1 do
				menu.close()
				local playerPed = GetPlayerPed(-1)
				local coords    = Config.Zones.VehicleSpawnPoint.Pos
				local Heading    = Config.Zones.VehicleSpawnPoint.Heading
				local platenum = math.random(1000, 9999)
				local platePrefix = Config.platePrefix
				ESX.Game.SpawnVehicle(data.current.value.Hash, coords, Heading, function(vehicle)
					TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
					SetVehicleNumberPlateText(vehicle, platePrefix .. platenum)
					plate = GetVehicleNumberPlateText(vehicle)
					plate = string.gsub(plate, " ", "")
					name = 'Véhicule de '..platePrefix
					
				end)
				break
            end
            menu.close()

    end,
function(data, menu)
    menu.close()
    CurrentAction     = 'vehiclespawn_menu'
    CurrentActionMsg  = Config.Zones.VehicleSpawner.hint
    CurrentActionData = {}
end
)
end 

-- Quand le joueur entre dans la zone
AddEventHandler('esx_cityworks:hasEnteredMarker', function(zone)

    if zone == 'Cloakroom' then
        CurrentAction        = 'cloakroom_menu'
        CurrentActionMsg     = Config.Zones.Cloakroom.hint
        CurrentActionData    = {}
    end

    if zone == 'VehicleSpawner' then
        CurrentAction        = 'vehiclespawn_menu'
        CurrentActionMsg     = Config.Zones.VehicleSpawner.hint
        CurrentActionData    = {}
    end 

    if zone == 'VehicleDeleter' then
        local playerPed = GetPlayerPed(-1)
        if IsPedInAnyVehicle(playerPed,  false) then
          CurrentAction        = 'delete_vehicle'
          CurrentActionMsg     = Config.Zones.VehicleDeleter.hint
          CurrentActionData    = {}
        end
    end

    
end)



function CreateBlip()
    if PlayerData.job ~= nil and PlayerData.job.name == Config.nameJob then

		if BlipCloakRoom == nil then
			BlipCloakRoom = AddBlipForCoord(Config.Zones.Cloakroom.Pos.x, Config.Zones.Cloakroom.Pos.y, Config.Zones.Cloakroom.Pos.z)
			SetBlipSprite(BlipCloakRoom, Config.Zones.Cloakroom.BlipSprite)
			SetBlipColour(BlipCloakRoom, Config.Zones.Cloakroom.BlipColor)
			SetBlipAsShortRange(BlipCloakRoom, true)
			BeginTextCommandSetBlipName("STRING")
			AddTextComponentString(Config.Zones.Cloakroom.BlipName)
			EndTextCommandSetBlipName(BlipCloakRoom)
		end
	else

        if BlipCloakRoom ~= nil then
            RemoveBlip(BlipCloakRoom)
            BlipCloakRoom = nil
        end
	end

	if PlayerData.job ~= nil and PlayerData.job.name == Config.nameJob and onDuty then

        BlipVehicle = AddBlipForCoord(Config.Zones.VehicleSpawner.Pos.x, Config.Zones.VehicleSpawner.Pos.y, Config.Zones.VehicleSpawner.Pos.z)
        SetBlipSprite(BlipVehicle, Config.Zones.VehicleSpawner.BlipSprite)
        SetBlipColour(BlipVehicle, Config.Zones.VehicleSpawner.BlipColor)
        SetBlipAsShortRange(BlipVehicle, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Zones.VehicleSpawner.BlipName)
        EndTextCommandSetBlipName(BlipVehicle)

       

        BlipVehicleDeleter = AddBlipForCoord(Config.Zones.VehicleDeleter.Pos.x, Config.Zones.VehicleDeleter.Pos.y, Config.Zones.VehicleDeleter.Pos.z)
        SetBlipSprite(BlipVehicleDeleter, Config.Zones.VehicleDeleter.BlipSprite)
        SetBlipColour(BlipVehicleDeleter, Config.Zones.VehicleDeleter.BlipColor)
        SetBlipAsShortRange(BlipVehicleDeleter, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Zones.VehicleDeleter.BlipName)
        EndTextCommandSetBlipName(BlipVehicleDeleter)
    else

        if BlipVehicle ~= nil then
            RemoveBlip(BlipVehicle)
            BlipVehicle = nil
        end

       

        if BlipVehicleDeleter ~= nil then
            RemoveBlip(BlipVehicleDeleter)
            BlipVehicleDeleter = nil
        end
    end 
end

-- Activation du marker au sol
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if PlayerData.job ~= nil then
			local coords = GetEntityCoords(GetPlayerPed(-1))

			if PlayerData.job.name == Config.nameJob then
				if onDuty then

					for k,v in pairs(Config.Zones) do
						if v ~= Config.Zones.Cloakroom then
							if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
								DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
							end
						end
					end

				end

				local Cloakroom = Config.Zones.Cloakroom
				if(Cloakroom.Type ~= -1 and GetDistanceBetweenCoords(coords, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, true) < Config.DrawDistance) then
					DrawMarker(Cloakroom.Type, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Cloakroom.Size.x, Cloakroom.Size.y, Cloakroom.Size.z, Cloakroom.Color.r, Cloakroom.Color.g, Cloakroom.Color.b, 100, false, true, 2, false, false, false, false)
				end
			end
		end
	end
end)

-- Detection de l'entrer/sortie de la zone du joueur
Citizen.CreateThread(function()
	while true do
		Wait(1)
		if PlayerData.job ~= nil then
			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil

			if PlayerData.job.name == Config.nameJob then
				if onDuty then
					for k,v in pairs(Config.Zones) do
						if v ~= Config.Zones.Cloakroom then
							if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) <= v.Size.x) then
								isInMarker  = true
								currentZone = k
							end
						end
					end
				end

				local Cloakroom = Config.Zones.Cloakroom
				if(GetDistanceBetweenCoords(coords, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, true) <= Cloakroom.Size.x) then
					isInMarker  = true
					currentZone = "Cloakroom"
				end
			end

			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone                = currentZone
				TriggerEvent('esx_cityworks:hasEnteredMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_cityworks:hasExitedMarker', LastZone)
			end
		end
	end
end)

-- Action après la demande d'accés
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)
        if CurrentAction ~= nil then
            SetTextComponentFormat('STRING')
            AddTextComponentString(CurrentActionMsg)
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            if (IsControlJustReleased(1, Keys["E"]) or IsControlJustReleased(2, Keys["RIGHT"])) and PlayerData.job ~= nil then
				local playerPed = GetPlayerPed(-1)
				if PlayerData.job.name == Config.nameJob then
					if CurrentAction == 'cloakroom_menu' then
						if IsPedInAnyVehicle(playerPed, 0) then
					--		ESX.ShowNotification(_U('in_vehicle'))
							exports['mythic_notify']:DoHudText('inform', 'You must be out of your vehicle', 2500, { ['background-color'] = '#BF0000', ['color'] = '#ffffff' })
							
						else
							CloakRoomMenu()
						end
					end
					if CurrentAction == 'vehiclespawn_menu' then
						if IsPedInAnyVehicle(playerPed, 0) then
		--					ESX.ShowNotification(_U('in_vehicle'))
							exports['mythic_notify']:DoHudText('inform', 'You must be out of your vehicle', 2500, { ['background-color'] = '#BF0000', ['color'] = '#ffffff' })
						else
							VehicleMenu()
						end
					end
					
					if CurrentAction == 'delete_vehicle' then
					  local playerPed = GetPlayerPed(-1)
					  local vehicle   = GetVehiclePedIsIn(playerPed,  false)
					  local hash      = GetEntityModel(vehicle)
					  local plate = GetVehicleNumberPlateText(vehicle)
					  local plate = string.gsub(plate, " ", "")
					  local platePrefix = Config.platePrefix

					  if string.find (plate, platePrefix) then
						local truck = Config.Vehicles.Truck

						if hash == GetHashKey(truck.Hash) then
							if GetVehicleEngineHealth(vehicle) <= 500 or GetVehicleBodyHealth(vehicle) <= 500 then
						--		ESX.ShowNotification(_U('vehicle_broken'))
								exports['mythic_notify']:DoHudText('inform', 'You need to repair the vehicle before continuing', 5500, { ['background-color'] = '#BF0000', ['color'] = '#ffffff' })
							else
								TriggerServerEvent('esx_vehiclelock:vehjobSup', plate, 'no')
								DeleteVehicle(vehicle)
							end
						end
					  else
				--		ESX.ShowNotification(_U('bad_vehicle'))
						exports['mythic_notify']:DoHudText('inform', 'You can only store the Service Vehicle', 5500, { ['background-color'] = '#BF0000', ['color'] = '#ffffff' })
					  end
					end
               	    CurrentAction = nil
				end
			end
		end
	end
end)

--[[
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)

		if IsControlJustReleased(1, Keys["F6"]) and PlayerData.job ~= nil and PlayerData.job.name == Config.nameJob then

			if Onjob then
				StopNPCJob(true)
				RemoveBlip(Blips['NPCTargetPool'])
				Onjob = false
			else
				local playerPed = GetPlayerPed(-1)

				if IsPedInAnyVehicle(playerPed,  false) and IsVehicleModel(GetVehiclePedIsIn(playerPed,  false), GetHashKey("UtilliTruck3")) then
					StartNPCJob()
					Onjob = true
				else
				--	ESX.ShowNotification(_U('not_good_veh'))
					exports['mythic_notify']:DoHudText('inform', 'Debes estar en el camión de servicio', 5500, { ['background-color'] = '#BF0000', ['color'] = '#ffffff' })
				end
			end
		end
	end
end) ]]--

function setUniform(job, playerPed)
  TriggerEvent('skinchanger:getSkin', function(skin)

    if skin.sex == 0 then
      if Config.Uniforms[job].male ~= nil then
        TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms[job].male)
      else
        ESX.ShowNotification(_U('no_outfit'))
      end
    else
      if Config.Uniforms[job].female ~= nil then
        TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms[job].female)
      else
        ESX.ShowNotification(_U('no_outfit'))
      end
    end

  end)
end

function HelpPromt(text)
	Citizen.CreateThread(function()
		SetTextComponentFormat("STRING")
		AddTextComponentString(text)
		DisplayHelpTextFromStringLabel(0, state, 0, -1)

	end)
end

-- Quand le joueur sort de la zone
AddEventHandler('esx_cityworks:hasExitedMarker', function(zone)

--[[	if zone == 'Vente' then
		TriggerServerEvent('esx_cityworks:stopVente')
	end ]]--
    CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)
