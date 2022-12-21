local json = require("json")

local spawnPos = vector3(-1587.612, -3032.406, 14)
RegisterNetEvent("OnReceivedChatMessage")
RegisterNetEvent('onHuntingPackStart')
RegisterNetEvent('OnGameEnded')
RegisterNetEvent('OnUpdateRanks')
RegisterNetEvent('OnClearRanks')

local ourTeamType = ''
local ourDriverVehicle = 0
local startTime = 0
local startLocation = vector3(0, 0, 0)
local endLocation = vector3(0, 0, 0)
local totalLife = 0
local lifeStart = GetGameTimer()
local lastVehicle = "FBI"
local lastSpawnCoords = vector3(0, 0, 0)
local gameStarted = false
local minSpeedInKMH = 45
local maxTimeBelowSpeed = 12
local timeBelowSpeed = 0
local shouldNotifyBelowSpeed = true
local shouldNotifyAboveSpeed = false
local shouldNotifyAboutDeath = true
local firstStart = false
local driverName = ''
local defenderName = ''
local driverPed = 0
local afkTime = 0
local isMarkedAfk = false
local respawnCooldown = 0
local currentSpawnConfig = {name = 'None', driverSpawnVec = vector3(0,0,0), driverSpawnRot = 0, attackerSpawnVec = vector3(0,0,0), attackerSpawnRot = 0, defenderSpawnVec = vector3(0,0,0), defenderSpawnRot = 0}
local selectedSpawn = nil
local showScoreboard = false
local endPoint = vector3(-1657.05, -3155.652, 13) -- airport final location
local totalPlayers = 0
local currentRank = -1
local scoreToBeat = -1
local timeRemainingOnFoot = 30
local isLocalPlayerInVehicle = false
local timeDead = 0
local oldVehicle = nil

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local speedinKMH = GetEntitySpeed(GetPlayerPed(-1)) * 3.6
        if speedinKMH < 1.0 then
            afkTime = afkTime + 1.0
            if afkTime > 35 and isMarkedAfk == false then
                TriggerServerEvent('OnMarkedAFK', true)
                isMarkedAfk = true
            end
        else
            afkTime = 0.0
            if isMarkedAfk == true then
                isMarkedAfk = false
                TriggerServerEvent('OnMarkedAFK', false)
            end
        end
    end

end)

Citizen.CreateThread(function()
    while true do
        -- These natives has to be called every frame.
        SetVehicleDensityMultiplierThisFrame(1.0)
        SetPedDensityMultiplierThisFrame(1.0)
        SetRandomVehicleDensityMultiplierThisFrame(1.0)
        SetParkedVehicleDensityMultiplierThisFrame(1.0)
        SetScenarioPedDensityMultiplierThisFrame(1.0, 1.0)
        local playerPed = GetPlayerPed(-1)
        local currentVehicleId = GetVehiclePedIsIn(playerPed, false)

        

        if GetEntityHealth(playerPed) <= 0 and gameStarted then
            timeDead = timeDead + 0.1
            if ourTeamType == 'driver' then
                TriggerServerEvent('OnNotifyKilled', GetPlayerName(PlayerId()), totalLife)
            else
                if timeDead > 10 then
                    exports.spawnmanager:forceRespawn()        
                    respawnCooldown = 30            
                    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
                end
            end
        end


        if currentVehicleId == 0 then
            isLocalPlayerInVehicle = false
            timeRemainingOnFoot = timeRemainingOnFoot - 0.1
            if timeRemainingOnFoot <= 0 and ourTeamType == 'driver' then
                SetEntityHealth(GetPlayerPed(-1), 0)
            end
            SetEntityInvincible(GetPlayerPed(-1), false)
            if HasPedGotWeapon(playerPed,0xBFE256D4, false) == false then
                GiveWeaponToPed(playerPed, 0xBFE256D4, 30, false, true)
            end
        else
            if currentVehicleId ~= ourDriverVehicle and ourTeamType == 'driver' then
                oldVehicle = ourDriverVehicle
                timeBelowSpeed = 0
                SetEntityAsMissionEntity(currentVehicleId, false, false) 
                DeleteVehicle(currentVehicleId)
                TriggerEvent('SpawnVehicle', 'firetruk', GetEntityCoords(PlayerPedId()) + vector3(0,0,0), GetEntityHeading(PlayerPedId())) 
            end
            isLocalPlayerInVehicle = true
            timeRemainingOnFoot = 30
            SetEntityInvincible(GetPlayerPed(-1), true)
            RemoveAllPedWeapons(playerPed)
        end
        -- local pos = GetEntityCoords(playerPed) 
        -- RemoveVehiclesFromGeneratorsInArea(pos['x'] - 500.0, pos['y'] - 500.0, pos['z'] - 500.0, pos['x'] + 500.0, pos['y'] + 500.0, pos['z'] + 500.0);

        -- These natives do not have to be called everyframe.
        -- SetGarbageTrucks(0)
        -- SetRandomBoats(0)
       
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
        ]] --

        if respawnCooldown > 0 then
            respawnCooldown = respawnCooldown - 0.1
        end

        if ourTeamType == 'driver' then
            if lastVehicle == 'Firetruk' then
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
            if lastVehicle == 'Riot' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 10.0)
            elseif lastVehicle == 'Ambulance' then
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.6)
            else
                SetVehicleCheatPowerIncrease(ourDriverVehicle, 1.3)
            end
        end
        car = GetVehiclePedIsIn(GetPlayerPed(-1), false)

        if car then
            Citizen.InvokeNative(0xB736A491E64A32CF,
                                 Citizen.PointerValueIntInitialized(car))
        end
        Citizen.Wait(100)
    end

end)

Citizen.CreateThread(function()

    timestart = GetGameTimer()
    tick = GetGameTimer()
    while true do
        delta_time = (GetGameTimer() - tick) / 1000
        tick = GetGameTimer()
        Citizen.Wait(100) -- check all 15 seconds
        if (GetGameTimer() - startTime) / 1000 < 5 then
            shouldNotifyAboutDeath = true
            shouldNotifyAboveSpeed = false
        end
        if ourTeamType == 'driver' then
            if (GetGameTimer() - startTime) / 1000 > 15 then
                totalLife = (GetGameTimer() - lifeStart) / 1000
            else
                lifeStart = GetGameTimer()
            end
        end
        if ourDriverVehicle ~= 0 then
            SetVehicleFuelLevel(ourDriverVehicle, 100.0)
        end
        SetEnableVehicleSlipstreaming(true)
        local speedinKMH = GetEntitySpeed(driverPed) * 3.6
        local distanceToFinalLocation = #(GetEntityCoords(PlayerPedId()) - endPoint)
        local wantedLevel = 0
        if distanceToFinalLocation < 500 and ourTeamType == 'driver' then
            wantedLevel = 5
        end
        if GetPlayerWantedLevel(PlayerId()) ~= wantedLevel then
            SetPlayerWantedLevel(PlayerId(), wantedLevel, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end

        if distanceToFinalLocation < 40 and ourTeamType == 'driver' and gameStarted then
            gameStarted = false
            TriggerServerEvent('OnNotifyHighScore', GetPlayerName(PlayerId()), totalLife)
            timeBelowSpeed = 0
            TriggerEvent('SpawnVehicle', 'miljet', GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()) + 180.0)
        end

        for player = 0, 64 do
            if player ~= currentPlayer and NetworkIsPlayerActive(player) then
                local playerPed = GetPlayerPed(player)
                local playerName = GetPlayerName(player)

                if driverName == playerName then
                    driverPed = playerPed
                end
            end
        end
        if speedinKMH < minSpeedInKMH and (GetGameTimer() - startTime) / 1000 >
            15 and ourTeamType == 'driver' then
            timeBelowSpeed = timeBelowSpeed + delta_time
            timeBelowSpeed = math.clamp(timeBelowSpeed, 0, maxTimeBelowSpeed)
            if shouldNotifyBelowSpeed and ourTeamType == 'driver' then
                TriggerServerEvent('OnNotifyBelowSpeed',
                                   GetPlayerName(PlayerId()))
                shouldNotifyBelowSpeed = false
                shouldNotifyAboveSpeed = true
            end
            if timeBelowSpeed >= maxTimeBelowSpeed and ourTeamType == 'driver' then
                -- blow up
                SetEntityInvincible(GetVehiclePedIsIn(GetPlayerPed(-1), false), false)
                SetEntityInvincible(GetVehiclePedIsIn(GetPlayerPed(-1), true), false)
                NetworkExplodeVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false), true, true, true)
                NetworkExplodeVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), true), true, true, true)
                timeBelowSpeed = 0
                SetEntityInvincible(GetPlayerPed(-1), false)
                EndLocation = GetEntityCoords(PlayerPedId())
                if shouldNotifyAboutDeath then
                    if defenderName ~= '' then
                        --TriggerServerEvent('OnNotifyBlownUp',
                        --                   GetPlayerName(PlayerId()), totalLife)
                    else
                        --TriggerServerEvent('OnNotifyBlownUp',
                       --                    GetPlayerName(PlayerId()), totalLife)
                    end
                    shouldNotifyAboutDeath = false
                end
            end
        else
            if shouldNotifyAboveSpeed then
                TriggerServerEvent('OnNotifyAboveSpeed',
                                   GetPlayerName(PlayerId()), timeBelowSpeed)
                shouldNotifyAboveSpeed = false
            end
            shouldNotifyBelowSpeed = true
            timestart = GetGameTimer()
            timeBelowSpeed = math.clamp(timeBelowSpeed - delta_time, 0,
                                        maxTimeBelowSpeed)
        end
    end
end)

Citizen.CreateThread(function()
    local previousLocation = vector3(0, 0, 0)
    while true do
        if ourTeamType == 'driver' and gameStarted then
            previousLocation = GetEntityCoords(GetPlayerPed(-1))
            local rot = GetEntityHeading(PlayerPedId())
            Wait(2500)
            TriggerServerEvent('OnNewRespawnPoint', previousLocation, rot)
        end
        Wait(1000)
    end
end)
Citizen.CreateThread(function()
    local previousLocation = vector3(0, 0, 0)
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
                SetTextProportional(1)
                SetTextScale(0.0, 0.5)
                SetTextColour(0, 128, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                SetTextCentre(1)
                local distanceToFinalLocation = #(GetEntityCoords(PlayerPedId()) - endPoint)
                local currentScore = totalLife * (totalPlayers * 1.68 - 1)
                if currentScore < scoreToBeat then
                    SetTextColour(128, 0, 0, 255)
                end
                local rankString = ''
                local scoreToBeatString = ''
                if currentRank ~= -1 then
                    rankString = 'Rank #' .. currentRank .. (" (%.0f)"):format(scoreToBeat)
                end
                AddTextComponentString(
                    ("Survived\n%.1f Seconds\n %.0f Score\n%s\n%s"):format(totalLife,
                                                                   currentScore, rankString, scoreToBeatString))
                DrawText(0.9, 0.1)
            end
            local speedinKMH = GetEntitySpeed(driverPed) * 3.6
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 1.0)
            if (GetGameTimer() - startTime) / 1000 < 15 or speedinKMH >=
                minSpeedInKMH then
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
            if (GetGameTimer() - startTime) / 1000 < 15 and ourTeamType ==
                'driver' and showScoreboard == false then
                AddTextComponentString(("Run From The Police\n Get to the airport to set a score!\nIf you explode your score is VOID!\n%.1f"):format(
                                           15 - (GetGameTimer() - startTime) /
                                               1000))
                DrawText(0.5, 0.2)
            else
                if ourTeamType == 'driver' then
                    if isLocalPlayerInVehicle == false then
                        AddTextComponentString(
                            ("%.1f"):format(timeRemainingOnFoot))
                        DrawText(0.5, 0.25)
                    end
                    if timeBelowSpeed > 0 then
                        AddTextComponentString(
                            ("%.1f"):format(maxTimeBelowSpeed - timeBelowSpeed))
                        DrawText(0.5, 0.25)
                    end
                end
                

            end
            if 15 - (GetGameTimer() - startTime) / 1000 > 0 and totalLife < 15 and
                ourTeamType ~= 'driver' and showScoreboard == false then
                SetTextFont(1)
                SetTextProportional(1)
                SetTextScale(0.0, 1.0)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                SetTextCentre(1)
                if defenderName == GetPlayerName(PlayerId()) then
                    AddTextComponentString(
                        ("Do Anything You Want!\n%.1f"):format(15 -
                                                                   (GetGameTimer() -
                                                                       startTime) /
                                                                   1000))
                elseif showScoreboard == false then
                    AddTextComponentString(
                        ("Stop the truck from extracing at the airport!\n%.1f"):format(15 -
                                                             (GetGameTimer() -
                                                                 startTime) /
                                                             1000))
                end
                DrawText(0.5, 0.4)
            end
        end
    end
end)

RegisterNetEvent("baseevents:onPlayerKilled")
AddEventHandler('baseevents:onPlayerKilled', function(killer, reason)
   
end)

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        exports.spawnmanager:spawnPlayer({
            x = spawnPos.x,
            y = spawnPos.y,
            z = spawnPos.z,
            model = 's_m_y_fireman_01'
        }, function()
            TriggerEvent('chat:addMessage', {
                args = {
                    '^5MOTD: ^12 Players minimum ^5required to start the game. ^2If you are blown up/disabled then you can use ^1F1^2 to respawn.'
                }
            })
        end)
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    TriggerServerEvent('OnPlayerSpawned')
    local ped = PlayerPedId()
	SetCanAttackFriendly(ped, true, true)
	NetworkSetFriendlyFireOption(true)

end)

RegisterCommand('areas', function(source, args)
    -- tell the player
    TriggerEvent('chat:addMessage',
                 {args = {'Possible Maps are \nairport\nairport_north\ndock'}})
end, false)

RegisterCommand('highscore', function(source, args)
    -- tell the player
    if (GetPlayerName(PlayerId()) ~= '886 // RyroNZ') then return end
    TriggerServerEvent('OnNotifyBlownUp', GetPlayerName(PlayerId()),
                       tonumber(args[1]))
end, false)

RegisterCommand('start', function(source, args)
    TriggerServerEvent('OnRequestedStart')
end, false)

RegisterCommand('coord', function(source, args)
    local pos = GetEntityCoords(PlayerPedId()) -- get the position of the local player ped
    local rot = GetEntityHeading(PlayerPedId())
    -- tell the player
    TriggerEvent('chat:addMessage', {args = {'Pos: ' .. pos .. ' Rot: ' .. rot}})
end, false)

RegisterCommand('setspawn', function(source, args)
    local pos = GetEntityCoords(PlayerPedId())
    local rot = GetEntityHeading(PlayerPedId())
    print(args, count_array(args))
    local spawnName = args[1]
    currentSpawnConfig.name = spawnName
    local teamName = args[2]
    if args[2] == 'driver' then
        currentSpawnConfig.driverSpawnVec = pos
        currentSpawnConfig.driverSpawnRot = rot
        TriggerEvent('OnReceivedChatMessage', 'Set Driver Data for ' .. spawnName .. ' to ' .. pos .. ' / ' .. rot)
    elseif args[2] == 'attacker' then
        currentSpawnConfig.attackerSpawnVec = pos
        currentSpawnConfig.attackerSpawnRot = rot
        TriggerEvent('OnReceivedChatMessage', 'Set Attacker Data for ' .. spawnName .. ' to ' .. pos .. ' / ' .. rot)
    elseif args[2] == 'defender' then
        currentSpawnConfig.defenderSpawnVec = pos
        currentSpawnConfig.defenderSpawnRot = rot
        TriggerEvent('OnReceivedChatMessage', 'Set Defender Data for ' .. spawnName .. ' to ' .. pos .. ' / ' .. rot)
    end
end, false)

RegisterCommand('uploadspawn', function(source, args)
    local pos = GetEntityCoords(PlayerPedId())
    local rot = GetEntityHeading(PlayerPedId())
    if currentSpawnConfig.name == "None" then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn no name set for spawn data')
        --return
    end
    if currentSpawnConfig.driverSpawnVec == vector3(0,0,0) then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn driver data set (Position/Rotation)')
        --return
    end
    if currentSpawnConfig.attackerSpawnVec == vector3(0,0,0) then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn attacker data set (Position/Rotation)')
        --return
    end
    if currentSpawnConfig.defenderSpawnVec == vector3(0,0,0) then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn defender data set (Position/Rotation)')
        --return
    end

    TriggerEvent('OnReceivedChatMessage', 'Sent Spawn Data to the server')
    TriggerServerEvent('OnUploadSpawnPoint', currentSpawnConfig)
end, false)

AddEventHandler('OnReceivedChatMessage', function(text)
    TriggerEvent('chat:addMessage', {args = {text}})
end)

AddEventHandler('OnGameEnded', function() gameStarted = false end)

RegisterNetEvent('OnUpdateMinSpeed')
AddEventHandler('OnUpdateMinSpeed', function(NewMinSpeed, newMaxTimeBelowSpeed)
    minSpeedInKMH = NewMinSpeed
    maxTimeBelowSpeed = newMaxTimeBelowSpeed
end)

RegisterNetEvent('OnUpdateTotalPlayers')
AddEventHandler('OnUpdateTotalPlayers',
                function(inTotalPlayers) totalPlayers = inTotalPlayers end)

RegisterNetEvent('OnUpdateDefender')
AddEventHandler('OnUpdateDefender',
                function(NewDefender) defenderName = NewDefender end)

AddEventHandler('onHuntingPackStart',
                function(teamtype, spawnPos, spawnRot, driver, inSelectedSpawn)
    print("Client_HuntingPackStart")
    SetEntityHealth(GetPlayerPed(-1), 1000)
    local model = 'a_f_m_beach_01'
    if teamtype == 'driver' then
        model = 's_m_y_fireman_01'
    elseif teamtype == 'defender' then
        model = 's_m_m_paramedic_01'
    else
        model = 's_m_y_cop_01'
    end
    if IsModelInCdimage(model) and IsModelValid(model) then
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(0)
    end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    end
   
    -- account for the argument not being passed
    timeRemainingOnFoot = 30
    currentRank = -1
    scoreToBeat = -1
    selectedSpawn = inSelectedSpawn
    totalLife = 0
    respawnCooldown = 30
    lifeStart = GetGameTimer()
    driverName = driver
    gameStarted = true
    local vehicleName = 'Sheriff2'
    ourTeamType = teamtype
    print(teamtype)
    startTime = GetGameTimer()
    possibleDriverVehicles = {'Firetruk'}
    possibleAttackerVehicles = {
        'FBI', 'FBI2', 'Police3', 'Sheriff2', 'Police2', 'Police', 'Police4',
        'Pranger', 'Sheriff'
    }
    possibleDefenderVehicles = {'Ambulance'}
    if math.random() < 0.01 then possibleAttackerVehicles = {'Riot'} end

    RemoveAllPedWeapons(GetPlayerPed(-1), true)
    if totalPlayers <= 1 then
        possibleDriverVehicles = {'Firetruk'}
    elseif totalPlayers <= 2 then
        --possibleDriverVehicles = {'camper'}
    elseif totalPlayers <= 5 then
        possibleDriverVehicles = {'Firetruk'}
    end

    selectedRandomCar = math.random(1, #possibleAttackerVehicles)
    if teamtype == 'defender' then
        selectedRandomCar = math.random(1, #possibleDefenderVehicles)
        vehicleName = possibleDefenderVehicles[selectedRandomCar]
    elseif teamtype == 'driver' then
        -- GiveWeaponToPed(GetPlayerPed(-1), 1198879012, 20, false, true)
        selectedRandomCar = math.random(1, #possibleDriverVehicles)
        vehicleName = possibleDriverVehicles[selectedRandomCar]
    else
        -- GiveWeaponToPed(GetPlayerPed(-1), 453432689, 9999, false, true)
        vehicleName = possibleAttackerVehicles[selectedRandomCar]
    end

    startLocation = spawnPos
    TriggerEvent('SpawnVehicle', vehicleName, spawnPos, spawnRot)
   

end)


AddEventHandler('SpawnVehicle', function(vehicleName, inSpawnPos, inSpawnRot)

    car = GetVehiclePedIsUsing(GetPlayerPed(-1), false)
    print(car)
    if car ~= 0 then
        SetEntityAsMissionEntity(car, false, false) 
        DeleteVehicle(car)
    end
    lastVehicle = vehicleName
     -- check if the vehicle actually exists
     if not IsModelInCdimage(vehicleName) or not IsModelAVehicle(vehicleName) then
        TriggerEvent('chat:addMessage', {
            args = {
                'It might have been a good thing that you tried to spawn a ' ..
                    vehicleName ..
                    '. Who even wants their spawning to actually ^*succeed?'
            }
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
    local pos = inSpawnPos -- get the position of the local player ped
    lastSpawnCoords = spawnPos
    -- create the vehicle
    local vehicle = CreateVehicle(vehicleName, pos.x, pos.y, pos.z, inSpawnRot,
                                  true, false)
    ourDriverVehicle = vehicle
    SetPedIntoVehicle(playerPed, vehicle, -1)

    --SetVehicleDoorsLocked(vehicle, 4)
    --SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)

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
        if NetworkIsPlayerActive(i) then table.insert(players, i) end
    end

    return players
end

Citizen.CreateThread(function()
    local blips = {}
    local currentPlayer = PlayerId()
    SetGpsActive(true)
    StartGpsMultiRoute(25, true, true)
    AddPointToGpsMultiRoute(endPoint.x, endPoint.y, endPoint.z)
    SetGpsMultiRouteRender(true)
    local destinationBlip = AddBlipForCoord(endPoint.x, endPoint.y, endPoint.z)
	SetBlipColour(destinationBlip2, 25)
    while true do
        Wait(100)
        local players = GetPlayers()

        for player = 0, 64 do
            if player ~= currentPlayer and NetworkIsPlayerActive(player) then
                local playerPed = GetPlayerPed(player)
                local playerName = GetPlayerName(player)

                RemoveBlip(blips[player])
                gamerTag = Citizen.InvokeNative(0xBFEFE3321A3F5015, playerPed,
                                                playerName, false, false, '',
                                                false)
                if ourTeamType ~= 'driver' then
                    local new_blip = AddBlipForEntity(playerPed)

                    -- Add player name to blip
                    SetBlipNameToPlayerName(new_blip, player)

                    -- Make blip white
                    if playerName == defenderName or defenderName ==
                        GetPlayerName(PlayerId()) then
                        SetBlipColour(new_blip, 64)
                        SetBlipCategory(new_blip, 380)
                    elseif playerName == driverName or driverName ==
                        GetPlayerName(PlayerId()) then
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
    if ourTeamType ~= 'driver' then totalLife = newTotalLife end
end)

ranks = {
    {rank = 1, name = 'None', points = 0, players = 0},
    {rank = 2, name = 'None', points = 0, players = 0},
    {rank = 3, name = 'None', points = 0, players = 0},
    {rank = 4, name = 'None', points = 0, players = 0},
    {rank = 5, name = 'None', points = 0, players = 0},
    {rank = 6, name = 'None', points = 0, players = 0},
    {rank = 7, name = 'None', points = 0, players = 0},
    {rank = 8, name = 'None', points = 0, players = 0},
    {rank = 9, name = 'None', points = 0, players = 0},
    {rank = 10, name = 'None', points = 0, players = 0}
}

AddEventHandler('OnClearRanks', function()
    ranks = {
        {rank = 1, name = 'None', points = 0, players = 0},
        {rank = 2, name = 'None', points = 0, players = 0},
        {rank = 3, name = 'None', points = 0, players = 0},
        {rank = 4, name = 'None', points = 0, players = 0},
        {rank = 5, name = 'None', points = 0, players = 0},
        {rank = 6, name = 'None', points = 0, players = 0},
        {rank = 7, name = 'None', points = 0, players = 0},
        {rank = 8, name = 'None', points = 0, players = 0},
        {rank = 9, name = 'None', points = 0, players = 0},
        {rank = 10, name = 'None', points = 0, players = 0}
    }
end)

AddEventHandler('OnUpdateRanks', function(name, lifetime, players, rank)
    if name == GetPlayerName(PlayerId()) then
        scoreToBeat = lifetime * (players * 1.68 - 1)
        currentRank = rank
    end
    for _, player in pairs(ranks) do
        if lifetime * (players * 1.68 - 1) > player.points *
            (player.players * 1.68 - 1) then
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
        if showScoreboard and selectedSpawn ~= nil then
            SetTextFont(1)
            SetTextProportional(0)
            SetTextScale(0.0, 1.0)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(selectedSpawn.name .. " Player Leaderboard \n(" .. totalPlayers .. " Players In Game)")
            DrawText(0.5, 0.1)
            DrawPlayers()
        end
    end
end)

function DrawPlayers()
    for _, player in pairs(ranks) do
        if player.points ~= 0 then
            local Yoffset = 0.04
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
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
            DrawText(0.35, 0.2 + Yoffset * player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.25)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then 
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%.0f Seconds\n%i Attackers"):format(
                                       player.points, player.players - 1))
            DrawText(0.50, 0.2 + Yoffset * player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%0.0f Score"):format(player.points *
                                                              (player.players *
                                                                  1.68 - 1)))
            DrawText(0.65, 0.2 + Yoffset * player.rank)
        end
    end
end

RegisterCommand('respawnbtn', function(source, args, rawcommand)

    if ourTeamType == 'driver' then
        TriggerEvent('chat:addMessage',
                     {args = {'Unable to respawn.... you are the driver!'}})
        return
    end
    if respawnCooldown > 0 then
        TriggerEvent('chat:addMessage', {
            args = {
                'You must wait ' .. respawnCooldown ..
                    ' seconds until respawn is available'
            }
        })
        return
    end

    respawnCooldown = 30
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))

end, false)

RegisterCommand('scoreboard', function(source, args, rawcommand)
    if showScoreboard then
        showScoreboard = false
    else
        showScoreboard = true
    end
    
end, false)

RegisterKeyMapping('respawnbtn', 'Respawn', "keyboard", "F1")
RegisterKeyMapping('scoreboard', 'Scoreboard', 'keyboard', 'CAPITAL')
