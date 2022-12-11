local json = require( "json" ) 

local spawnPos = vector3(-1587.612, -3032.406, 14)
RegisterNetEvent("OnReceivedChatMessage")
RegisterNetEvent('onHuntingPackStart')
RegisterNetEvent('OnGameEnded')
RegisterNetEvent('OnUpdateRanks')
RegisterNetEvent('OnClearRanks')

local ourTeamType = ''
local ourDriverVehicle = 0
local startTime = 0
local startLocation = vector3(0,0,0)
local endLocation = vector3(0,0,0)
local totalLife = 0
local lifeStart = GetGameTimer()
local lastVehicle = "FBI"
local lastSpawnCoords = vector3(0,0,0)
local gameStarted = false
local MinSpeedInKMH = 45
local maxTimeBelowSpeed = 12
local timeBelowSpeed = 0
local shouldNotifyBelowSpeed = true
local shouldNotifyAboveSpeed = false
local shouldNotifyAboutDeath = true
local firstStart = false
local driverName = ''
local defenderName = ''
local driverPed = 0
local afktime = 0
local isMarkedAFK = false

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do
        count = count + 1
    end

    return count
end


Citizen.CreateThread(function()
    while true 
    	do
    	-- These natives has to be called every frame.
    	SetVehicleDensityMultiplierThisFrame(1.0)
		SetPedDensityMultiplierThisFrame(1.0)
		SetRandomVehicleDensityMultiplierThisFrame(1.0)
		SetParkedVehicleDensityMultiplierThisFrame(1.0)
		SetScenarioPedDensityMultiplierThisFrame(1.0, 1.0)

		--local playerPed = GetPlayerPed(-1)
		--local pos = GetEntityCoords(playerPed) 
		--RemoveVehiclesFromGeneratorsInArea(pos['x'] - 500.0, pos['y'] - 500.0, pos['z'] - 500.0, pos['x'] + 500.0, pos['y'] + 500.0, pos['z'] + 500.0);
		
		-- These natives do not have to be called everyframe.
		--SetGarbageTrucks(0)
		--SetRandomBoats(0)
        SetEntityInvincible(GetPlayerPed(-1), true)
        --[[SetEntityInvincible(ourDriverVehicle, true)
        if ourTeamType == 'driver' then
           
            total_players = count_array(GetPlayers())
            if total_players <= 6 then
                if GetPlayerWantedLevel(PlayerId()) ~= 5 then
                    SetPlayerWantedLevel(PlayerId(),5, false)
                    SetPlayerWantedLevelNow(PlayerId(), false)
                end
            elseif GetPlayerWantedLevel(PlayerId()) ~= math.floor(totalLife/40) then
                SetPlayerWantedLevel(PlayerId(), math.floor(totalLife/40), false)
                SetPlayerWantedLevelNow(PlayerId(), false)
            end
            SetPoliceRadarBlips(false)
        else
            if GetPlayerWantedLevel(PlayerId()) ~= 0 then
                SetPlayerWantedLevel(PlayerId(), 0, false)
                SetPlayerWantedLevelNow(PlayerId(), false)
            end
        end
        ]]--
        if GetPlayerWantedLevel(PlayerId()) ~= 0 then
            SetPlayerWantedLevel(PlayerId(), 0, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end

        if ourTeamType == 'driver' then
            
            if lastVehicle == 'Firetruk' then
				if totalLife > 45.0 then
					SetVehicleMaxSpeed(100.0)
				end
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 0.7)
            elseif lastVehicle == 'Bus' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.5)
            elseif lastVehicle == 'Ambulance' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 0.7)
            elseif lastVehicle == 'Flatbed' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 0.9)
            elseif lastVehicle == 'Stretch' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.2)
            else
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.0)
            end 
        else 
            SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.3) 
        end
        car = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        
        if car then
            Citizen.InvokeNative(0xB736A491E64A32CF,Citizen.PointerValueIntInitialized(car))
        end
		Citizen.Wait(1)
	end

end)

Citizen.CreateThread(function()

    timestart = GetGameTimer()
	tick = GetGameTimer()
	while true do
		delta_time = (GetGameTimer() - tick)/1000
		tick = GetGameTimer()
		Citizen.Wait(100) -- check all 15 seconds
        if (GetGameTimer() - startTime)/1000 < 5 then
            shouldNotifyAboutDeath = true
            shouldNotifyAboveSpeed = false
        end
        if ourTeamType == 'driver' then
            if (GetGameTimer() - startTime)/1000 > 15 then
                totalLife = (GetGameTimer() - lifeStart)/1000
            else 
                lifeStart = GetGameTimer()
            end
        end
        if ourDriverVehicle ~= 0 then
            SetVehicleFuelLevel(ourDriverVehicle, 100.0)
        end
        SetEnableVehicleSlipstreaming(true)
		local speedinKMH = GetEntitySpeed(driverPed) * 3.6
		if speedinKMH < 1.0 then
			afktime = afktime + 0.1
			if afktime > 30 and isMarkedAFK == false then
				TriggerServerEvent('OnMarkedAFK', true)
				isMarkedAFK = true
			end
		else
			afktime = 0.0
			if isMarkedAFK == true then
				isMarkedAFK = false
				TriggerServerEvent('OnMarkedAFK', false)
			end
		end
		print(speedinKMH)
		if speedinKMH < MinSpeedInKMH and (GetGameTimer() - startTime)/1000 > 15 and ourTeamType == 'driver' then
			timeBelowSpeed = timeBelowSpeed + delta_time
			timeBelowSpeed = math.clamp(timeBelowSpeed, 0, maxTimeBelowSpeed)
			if shouldNotifyBelowSpeed and ourTeamType == 'driver' then
				TriggerServerEvent('OnNotifyBelowSpeed', GetPlayerName(PlayerId()))
				shouldNotifyBelowSpeed = false
				shouldNotifyAboveSpeed = true
			end
			if timeBelowSpeed >= maxTimeBelowSpeed and ourTeamType == 'driver' then
				-- blow up
				print("speed: " .. speedinKMH .. " uptime: " .. timeBelowSpeed)
				SetEntityInvincible(ourDriverVehicle, false)
				NetworkExplodeVehicle(ourDriverVehicle, true, true, true)
				EndLocation = GetEntityCoords(PlayerPedId())
				if shouldNotifyAboutDeath then
					if defenderName ~= '' then
						TriggerServerEvent('OnNotifyBlownUp', GetPlayerName(PlayerId()), totalLife)
					else
						TriggerServerEvent('OnNotifyBlownUp', GetPlayerName(PlayerId()), totalLife)
					end
					shouldNotifyAboutDeath = false
				end
			end
		else 
			if shouldNotifyAboveSpeed then
				TriggerServerEvent('OnNotifyAboveSpeed', GetPlayerName(PlayerId()), timeBelowSpeed)
				shouldNotifyAboveSpeed = false
			end
			shouldNotifyBelowSpeed = true
			timestart = GetGameTimer()
			timeBelowSpeed = math.clamp(timeBelowSpeed - delta_time, 0, maxTimeBelowSpeed)
		end
    end
end)

Citizen.CreateThread(function()
    local previousLocation = vector3(0,0,0)
    while true do
        if ourTeamType == 'driver' then
            previousLocation = GetEntityCoords(GetPlayerPed(-1))
            Wait(15000)
            TriggerServerEvent('OnNewRespawnPoint', previousLocation)
        end
        Wait(1000)
    end
end)
Citizen.CreateThread(function()
    local previousLocation = vector3(0,0,0)
    while true do
        Wait(100)
        if ourTeamType == 'driver' then
            TriggerServerEvent('OnUpdateLifeTimers', totalLife)
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        Wait(0)
        if gameStarted then 
		if startTime > 15 then
				SetTextFont(0)
				SetTextProportional(0)
				SetTextScale(0.0, 0.5)
				SetTextColour(0, 128, 0, 255)
				SetTextDropshadow(0, 0, 0, 0, 255)
				SetTextEdge(2, 0, 0, 0, 150)
				SetTextDropShadow()
				SetTextOutline()
				SetTextEntry("STRING")
				SetTextCentre(1)
				total_players = count_array(GetPlayers())
				AddTextComponentString(("Survived\n%.1f Seconds\n %.0f Score"):format(totalLife, totalLife * (total_players * 1.68 -1))) 
				DrawText(0.9,  0.1)
			end
			local speedinKMH = GetEntitySpeed(driverPed) * 3.6
			SetTextFont(1)
			SetTextProportional(0)
			SetTextScale(0.0, 1.0)
			if (GetGameTimer() - startTime)/1000 < 15 or speedinKMH >= MinSpeedInKMH then
				SetTextColour(0, 128, 0, 255)
			else
				SetTextColour(255, 0, 0, 255)
			end
			SetTextDropshadow(0, 0, 0, 0, 255)
			SetTextEdge(2, 0, 0, 0, 150)
			SetTextDropShadow()
			SetTextOutline()
			SetTextEntry("STRING")
			SetTextCentre(1)
			if (GetGameTimer() - startTime)/1000 < 15 and ourTeamType == 'driver' then
				AddTextComponentString(("Get Ready!\n%.1f"):format(15 - (GetGameTimer() - startTime)/1000)) 
				DrawText(0.5,  0.2)
			else			
				if timeBelowSpeed > 0 and ourTeamType == 'driver' then
					AddTextComponentString(("%.1f"):format(maxTimeBelowSpeed -timeBelowSpeed))
					DrawText(0.5,  0.25)
				end

			end
			if 15 - (GetGameTimer() - startTime)/1000 > 0 and totalLife < 15 and ourTeamType ~= 'driver' then
				SetTextFont(1)
				SetTextProportional(0)
				SetTextScale(0.0, 1.0)
				SetTextColour(255, 0, 0, 255)
				SetTextDropshadow(0, 0, 0, 0, 255)
				SetTextEdge(2, 0, 0, 0, 150)
				SetTextDropShadow()
				SetTextOutline()
				SetTextEntry("STRING")
				SetTextCentre(1)
				if defenderName == GetPlayerName(PlayerId()) then
					AddTextComponentString(("Do Anything You Want!\n%.1f"):format(15 - (GetGameTimer() - startTime)/1000)) 
				else
					AddTextComponentString(("Stop the truck!\n%.1f"):format(15 - (GetGameTimer() - startTime)/1000))
				end 
				DrawText(0.5,  0.4)
			end
        end
    end
end)

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        exports.spawnmanager:spawnPlayer({
            x = spawnPos.x,
            y = spawnPos.y,
            z = spawnPos.z,
            model = 's_m_y_cop_01'
        }, function()
            TriggerEvent('chat:addMessage', {
                args = { '^5MOTD: ^12 Players minimum ^5required to start the game. ^2If you are blown up/disabled then you can use /respawn.' }
            })
        end)
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
    print('Requesting Start for '.. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    TriggerServerEvent('OnPlayerSpawned')

end)

RegisterCommand('areas', function(source, args)
    -- tell the player
    TriggerEvent('chat:addMessage', {
		args = { 'Possible Maps are \nairport\nairport_north\ndock' }
	})
end, false)

RegisterCommand('highscore', function(source, args)
    -- tell the player
    if (GetPlayerName(PlayerId()) ~= '886 // RyroNZ') then return end
    TriggerServerEvent('OnNotifyBlownUp', GetPlayerName(PlayerId()), tonumber(args[1]))
end, false)


RegisterCommand('start', function(source, args)
    startPoints = {'airport_north', 'dock', 'beach', 'north', 'north_hollywood', 'paleto', 'airport', 'carpark', 'rng', 'dock2', 'dock22'}
    selectedRandomPoint = math.random(1, #startPoints)
    TriggerServerEvent('OnRequestedStart', startPoints[selectedRandomPoint])
end, false)

RegisterCommand('coord', function(source, args)
    local pos = GetEntityCoords(PlayerPedId()) -- get the position of the local player ped
    local rot = GetEntityHeading(PlayerPedId())
    -- tell the player
    TriggerEvent('chat:addMessage', {
		args = { 'Pos: ' .. pos .. ' Rot: ' .. rot }
	})
end, false)


AddEventHandler('OnReceivedChatMessage', function(text)
    TriggerEvent('chat:addMessage', {
		args = { text }
	})
end)

AddEventHandler('OnGameEnded', function()
    gameStarted = false
end)


RegisterNetEvent('OnUpdateMinSpeed')
AddEventHandler('OnUpdateMinSpeed', function(NewMinSpeed, newMaxTimeBelowSpeed)
    MinSpeedInKMH = NewMinSpeed
    maxTimeBelowSpeed = newMaxTimeBelowSpeed
end)

RegisterNetEvent('OnUpdateDefender')
AddEventHandler('OnUpdateDefender', function(NewDefender)
    defenderName = NewDefender
end)


AddEventHandler('onHuntingPackStart', function(teamtype, spawnPos, spawnRot, driver)
    print("Client_HuntingPackStart")
    -- account for the argument not being passed
    totalLife = 0
    lifeStart = GetGameTimer()
    driverName = driver
    gameStarted = true
    local vehicleName = 'Sheriff2'
    ourTeamType = teamtype
    print(teamtype)
    startTime = GetGameTimer()
    possibleDriverVehicles = {'Firetruk'}
    possibleAttackerVehicles = {'FBI', 'FBI2', 'Police3', 'Sheriff2', 'Police2', 'Police', 'Police4', 'Pranger', 'Sheriff' }
    possibleDefenderVehicles = {'Ambulance'}
	
	for player = 0, 64 do
		if player ~= currentPlayer and NetworkIsPlayerActive(player) then
			local playerPed = GetPlayerPed(player)
			local playerName = GetPlayerName(player)
			
			if driverName == playerName then
				driverPed = playerPed
			end
		end
	end


    RemoveAllPedWeapons(GetPlayerPed(-1), true)
    total_players = count_array(GetPlayers())
    if total_players <= 2 then
        possibleDriverVehicles = {'camper'}
    elseif total_players <= 5 then
        possibleDriverVehicles = {'Firetruk'}
    end

    selectedRandomCar = math.random(1, #possibleAttackerVehicles)
    if teamtype == 'defender' then
        selectedRandomCar = math.random(1, #possibleDefenderVehicles)
        vehicleName = possibleDefenderVehicles[selectedRandomCar]
    elseif teamtype == 'driver' then
        --GiveWeaponToPed(GetPlayerPed(-1), 1198879012, 20, false, true)
        selectedRandomCar = math.random(1, #possibleDriverVehicles)
        vehicleName = possibleDriverVehicles[selectedRandomCar]
    else
        --GiveWeaponToPed(GetPlayerPed(-1), 453432689, 9999, false, true)
        vehicleName = possibleAttackerVehicles[selectedRandomCar]
    end

    lastVehicle = vehicleName
    startLocation = spawnPos
  
    -- check if the vehicle actually exists
    if not IsModelInCdimage(vehicleName) or not IsModelAVehicle(vehicleName) then
        TriggerEvent('chat:addMessage', {
            args = { 'It might have been a good thing that you tried to spawn a ' .. vehicleName .. '. Who even wants their spawning to actually ^*succeed?' }
        })
  
        return
    end
  
    -- load the model
    RequestModel(vehicleName)
  
    -- wait for the model to load
    while not HasModelLoaded(vehicleName) do
        Wait(500) -- often you'll also see Citizen.Wait
    end
  
    -- get the player's position
    local playerPed = PlayerPedId() -- get the local player ped
    local pos = spawnPos -- get the position of the local player ped
    lastSpawnCoords = spawnPos
    -- create the vehicle
    local vehicle = CreateVehicle(vehicleName, pos.x, pos.y, pos.z, spawnRot, true, false)
    ourDriverVehicle = vehicle
    SetPedIntoVehicle(playerPed, vehicle, -1)
     --[[ 
    if ourTeamType ~= 'driver' then
        RequestModel('s_m_y_cop_01')

        -- load the model for this spawn
        while not HasModelLoaded('s_m_y_cop_01') do
            RequestModel('s_m_y_cop_01')

            Wait(0)
            -- release the player model
            SetModelAsNoLongerNeeded('s_m_y_cop_01')
        end
        passengerPed = CreatePed(6, 's_m_y_cop_01', pos.x, pos.y, pos.z, 0, true, false)
        GiveWeaponToPed(passengerPed, 453432689, 9999, false, true)
        SetPedIntoVehicle(passengerPed, vehicle, 0)
        SetPedCombatAttributes(passengerPed, 2, true)
        SetPedCombatAttributes(passengerPed, 3, false)

        if vehicleName == 'FBI2' or vehicleName == 'Sheriff2' or vehicleName == 'Pranger' then
            RequestModel('s_m_y_swat_01')

        -- load the model for this spawn
        while not HasModelLoaded('s_m_y_swat_01') do
            RequestModel('s_m_y_swat_01')

            Wait(0)
            -- release the player model
            SetModelAsNoLongerNeeded('s_m_y_swat_01')
        end
        passengerPed = CreatePed(6, 's_m_y_swat_01', pos.x, pos.y, pos.z, 0, true, false)
        GiveWeaponToPed(passengerPed, 453432689, 9999, false, true)
        SetPedIntoVehicle(passengerPed, vehicle, 3)
        SetPedCombatAttributes(passengerPed, 2, true)
        SetPedCombatAttributes(passengerPed, 3, false)
        passengerPed = CreatePed(6, 's_m_y_swat_01', pos.x, pos.y, pos.z, 0, true, false)
        GiveWeaponToPed(passengerPed, 453432689, 9999, false, true)
        SetPedIntoVehicle(passengerPed, vehicle, 4)
        SetPedCombatAttributes(passengerPed, 2, true)
        SetPedCombatAttributes(passengerPed, 3, false)
        end
    end
    --]]
    SetVehicleDoorsLocked(vehicle, 4)
    -- give the vehicle back to the game (this'll make the game decide when to despawn the vehicle)
    SetEntityAsNoLongerNeeded(vehicle)

    SetVehicleOnGroundProperly(vehicle)

    SetDisableVehiclePetrolTankDamage(ourDriverVehicle, true)
    SetVehicleEngineCanDegrade(ourDriverVehicle, false)
  
    -- release the model
    SetModelAsNoLongerNeeded(vehicleName)

  end)

  

  function GetPlayers()
	local players = {}

	for i = 0, 31 do
		if NetworkIsPlayerActive(i) then
			table.insert(players, i)
		end
	end

	return players
end

Citizen.CreateThread(function()
	local blips = {}
	local currentPlayer = PlayerId()

	while true do
		Wait(100)

       
		local players = GetPlayers()

		for player = 0, 64 do
			if player ~= currentPlayer and NetworkIsPlayerActive(player) then
				local playerPed = GetPlayerPed(player)
				local playerName = GetPlayerName(player)

				RemoveBlip(blips[player])
                gamerTag = Citizen.InvokeNative(0xBFEFE3321A3F5015, playerPed, playerName, false, false, '', false)
                if ourTeamType ~= 'driver' then
                    local new_blip = AddBlipForEntity(playerPed)

                    -- Add player name to blip
                    SetBlipNameToPlayerName(new_blip, player)

                    -- Make blip white
                    if playerName == defenderName or defenderName == GetPlayerName(PlayerId()) then
                        SetBlipColour(new_blip, 64)
                        SetBlipCategory(new_blip, 380)
                    elseif playerName == driverName or driverName == GetPlayerName(PlayerId()) then
                        SetBlipColour(new_blip, 1)
                        SetBlipCategory(new_blip, 380)
                    else 
                        SetBlipColour(new_blip, 2)
                        SetBlipCategory(new_blip, 56)
                    end

                    -- Set the blip to shrink when not on the minimap
                    -- Citizen.InvokeNative(0x2B6D467DAB714E8D, new_blip, true)

                    -- Shrink player blips slightly
                    SetBlipScale(new_blip, 0.9)

                    -- Record blip so we don't keep recreating it
                    blips[player] = new_blip

                    -- Add nametags above head
                    SetMpGamerTagVisibility(gamerTag, 0, true)
                else
                    SetMpGamerTagVisibility(gamerTag, 0, true)
                end
                 



			end
		end
	end
end)

RegisterNetEvent("OnUpdateLifeTimers")
AddEventHandler('OnUpdateLifeTimers', function(newTotalLife)
    if ourTeamType ~= 'driver' then
        totalLife = newTotalLife
    end
end)


RegisterCommand('respawn', function(source, args)
    if totalLife > 0 and ourTeamType ~= 'driver' then
        print('Requesting Start for '.. GetPlayerName(PlayerId()) .. ' in progress')
        TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    end
end, false)

ranks = {
                {rank=1,name='None',points=0,players=0},
                {rank=2,name='None',points=0,players=0},
                {rank=3,name='None',points=0,players=0},
                {rank=4,name='None',points=0,players=0},
                {rank=5,name='None',points=0,players=0},
                {rank=6,name='None',points=0,players=0},
                {rank=7,name='None',points=0,players=0},
                {rank=8,name='None',points=0,players=0},
                {rank=9,name='None',points=0,players=0},
                {rank=10,name='None',points=0,players=0},}

AddEventHandler('OnClearRanks', function()
    ranks = {
                {rank=1,name='None',points=0,players=0},
                {rank=2,name='None',points=0,players=0},
                {rank=3,name='None',points=0,players=0},
                {rank=4,name='None',points=0,players=0},
                {rank=5,name='None',points=0,players=0},
                {rank=6,name='None',points=0,players=0},
                {rank=7,name='None',points=0,players=0},
                {rank=8,name='None',points=0,players=0},
                {rank=9,name='None',points=0,players=0},
                {rank=10,name='None',points=0,players=0},}
end)

AddEventHandler('OnUpdateRanks', function(name, lifetime, players)
    for _,player in pairs(ranks) do
        if lifetime * (players * 1.68 -1) > player.points * (player.players * 1.68 - 1) then
            ranks[_].points = lifetime
            ranks[_].name = name
            ranks[_].players = players
            break
        end
    end    
end)


Citizen.CreateThread(function()
    while true do
        Wait(0)
        if not gameStarted or (GetGameTimer() - startTime)/1000 < 15 then 
            SetTextFont(1)
            SetTextProportional(0)
            SetTextScale(0.0, 1.0)
            SetTextColour(255, 255,255 , 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            total_players = count_array(GetPlayers())
            AddTextComponentString(total_players.. " Player Leaderboard")
            DrawText(0.80,  0.235)
            DrawPlayers()
        end
    end
end)

function DrawPlayers()
    for _,player in pairs(ranks) do
        if player.points ~= 0 then
            local Yoffset = 0.04
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255,215,0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(	205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(player.name)
            DrawText(0.65,  0.2685+Yoffset*player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.25)
            if player.rank == 1 then
                SetTextColour(255,215,0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(	205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%.0f Seconds\n%i Attackers"):format(player.points, player.players-1))
            DrawText(0.75,  0.2685+Yoffset*player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255,215,0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(	205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%0.0f Score"):format(player.points * (player.players * 1.68 - 1)))
            DrawText(0.94,  0.2685+Yoffset*player.rank)
        end
    end
end

RegisterCommand('respawnbtn', function(source, args, rawcommand)
    if totalLife > 0 and ourTeamType ~= 'driver' then
        print('Requesting Start for '.. GetPlayerName(PlayerId()) .. ' in progress')
        TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    end
end, false)


RegisterKeyMapping('respawnbtn', 'Respawn', "keyboard", "F1")
