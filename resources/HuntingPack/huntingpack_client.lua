local json = require("json")

local spawnPos = vector3(-1587.612, -3032.406, 14)
RegisterNetEvent("OnReceivedChatMessage")
RegisterNetEvent('onHuntingPackStart')
RegisterNetEvent('OnGameEnded')
RegisterNetEvent('OnUpdateRanks')
RegisterNetEvent('OnClearRanks')

local function has_value(tab, val)
    for index, value in ipairs(tab) do if value == val then return true end end

    return false
end

local warmupTime = 15
local distanceForExtraction = 10.0
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
local maxSpeedInKMH = 150
local maxTimeBelowSpeed = 12
local timeBelowSpeed = 0
local shouldNotifyBelowSpeed = true
local shouldNotifyAboveSpeed = false
local shouldNotifyAboutDeath = true
local firstStart = false
local drivers = {}
local defenderName = ''
local driverPed = 0
local afkTime = 0
local isMarkedAfk = false
local respawnCooldown = 0
local currentSpawnConfig = {name = 'None', driverSpawnVec = vector3(0,0,0), driverSpawnRot = 0, attackerSpawnVec = vector3(0,0,0), attackerSpawnRot = 0, defenderSpawnVec = vector3(0,0,0), defenderSpawnRot = 0}
local selectedSpawn = nil
local showScoreboard = false
local distanceToFinalLocation = -1
local endPoints = {
    {name = 'Airport', destination = vector3(-1657.05, -3155.652, 13), vehicleModel = 'miljet', vehicleSpawnLocation = vector3(-1583,-2999,14), vehicleSpawnRotation = 240.0},
    {name = 'Ocean South', destination = vector3(1793.05, -2725.652, 1.5), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(1804.1, -2759.189, -1.85), vehicleSpawnRotation = 205.0},
    {name = 'Ocean North', destination = vector3(-1610.05, 5261.652, 4.2), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(-1601.945,5265.29,0), vehicleSpawnRotation = 358.0},
    {name = 'Beach', destination = vector3(-1841.05, -1254.652, 9), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(-1859.0, -1268.0,3.3), vehicleSpawnRotation = 204.0}
}
local selectedEndPoint = nil
local totalPlayers = 0
local currentRank = -1
local scoreToBeat = -1
local timeRemainingOnFoot = 60
local isLocalPlayerInVehicle = false
local timeDead = 0
local oldVehicle = nil
local possibleDriverVehicles = {'Firetruk', 'stockade', 'stockade3', 'terbyte', 'pounder2', 
'flatbed', 'rubble', 'mixer', 'hotknife', 'patriot2', 'airbus', 'coach', 
'banshee', 'futo', 'tourbus', 'trash', 'lguard'}
local possibleAttackerVehicles = {
        'FBI', 'FBI2', 'Police3', 'Sheriff2', 'Police2', 'Police', 'Police4',
        'Pranger', 'Sheriff'
    }
local possibleDefenderVehicles  = {'futo', 'banshee'} --{'Ambulance'}
local forceDriverBlipVisible = {}
local needsResetHealth = false
local createdBlipForRadius = false
local driverBlip = {}
local isInExtraction = false
local currentScore = 0
local extractionBlip = nil
local hasExtracted = false
local isExtracting = false
local extractionTimeRemaining = 20
local possiblePoliceWeapons = { {model = 'pumpshotgun', ammo = 10, equip = false}, { model = 'pistol_mk2', ammo = 30, equip = true} }
local possibleDriverWeapons = { {model = 'minismg', ammo = 60, equip = false} , {model = 'Pistol50', ammo = 18, equip = true} , {model = 'sniperrifle', ammo = 5, equip = false} }
local weaponHash = nil

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local speedinKMH = GetEntitySpeed(GetPlayerPed(-1)) * 3.6
        local currentVehicleId = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        if speedinKMH < 1.0 and GetEntityHealth(GetPlayerPed(-1)) > 0 and currentVehicleId ~= 0 then
            afkTime = afkTime + 1.0
            if afkTime > 35 and isMarkedAfk == false and ourTeamType ~= 'driver' then
                TriggerServerEvent('OnMarkedAFK', true)
                isMarkedAfk = true
            end
        else
            afkTime = 0.0
            if isMarkedAfk == true then
                isMarkedAfk = false
                TriggerServerEvent('OnMarkedAFK', false)
                if not gameStarted then
                    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
                end
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
        local isDriver = GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId()), -1) == PlayerPedId()
        driverPed = playerPed

        SetCanAttackFriendly(playerPed, true, true)
        NetworkSetFriendlyFireOption(true)

        

        if GetEntityHealth(playerPed) <= 0 then
            respawnCooldown = 10
            timeDead = timeDead + 0.1
            if ourTeamType == 'driver' and gameStarted and totalLife > 0 then
                TriggerServerEvent('OnNotifyKilled', GetPlayerName(PlayerId()), totalLife)
            else
                if timeDead > 10 and ourTeamType ~= 'driver' then
                    respawnCooldown = 5          
                    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
                end
            end
        else
            timeDead = 0
        end

        local giveWeapon = currentVehicleId == 0 or not isDriver

        if giveWeapon then
            local weapons = possiblePoliceWeapons
            if ourTeamType == 'driver' then
                weapons = possibleDriverWeapons
            end
            for _, weapon in pairs(weapons) do
                weaponHash = GetHashKey("WEAPON_".. weapon.model)
                if not HasPedGotWeapon(playerPed, weaponHash, false) then
                    GiveWeaponToPed(playerPed, weaponHash, weapon.ammo, false, weapon.equip)
                end
            end
        else
            RemoveAllPedWeapons(playerPed)
        end

        local playerName = GetPlayerName(PlayerId())
        if currentVehicleId == 0 then
            local coords = GetEntityCoords(PlayerPedId())
        
            if forceDriverBlipVisible[playerName] and ourTeamType == 'driver' then
                TriggerEvent('OnNotifyDriversBlipVisible', GetPlayerName(PlayerId()), false)
                TriggerServerEvent('OnNotifyDriverBlipVisible', GetPlayerName(PlayerId()),  false) 
            end  
            if ourTeamType == 'driver' and not createdBlipForRadius then
                createdBlipForRadius = true

                TriggerServerEvent('OnNotifyDriverBlipArea', playerName, true, coords.x, coords.y, coords.z)
            end
            needsResetHealth = true
            isLocalPlayerInVehicle = false
            if not isExtracting then
                timeRemainingOnFoot = timeRemainingOnFoot - 0.1
            end
            if timeRemainingOnFoot <= 0 and ourTeamType == 'driver' then
                SetEntityHealth(GetPlayerPed(-1), 0)
            end
           
            SetEntityInvincible(GetPlayerPed(-1), false)
            
        else
            if not forceDriverBlipVisible[playerName] and ourTeamType == 'driver' then
                TriggerEvent('OnNotifyDriversBlipVisible', playerName, true)
                TriggerServerEvent('OnNotifyDriverBlipVisible', playerName, true) 
            end   

            if createdBlipForRadius then
                createdBlipForRadius = false             
                TriggerServerEvent('OnNotifyDriverBlipArea', playerName, false, 0, 0, 0)
            end

            local vehicleClass = GetVehicleClass(currentVehicleId)
            -- 14 = Boats 15 - Helicopter 16 - Plane
            if (vehicleClass == 14 or vehicleClass == 15 or vehicleClass == 16) then

                if ourTeamType == 'driver' and not hasExtracted then
                    SetEntityAsMissionEntity(car, false, false) 
                    DeleteVehicle(car)
                end
            end
            if needsResetHealth then
                needsResetHealth = false
                if ourTeamType == 'driver' then
                    SetPedMaxHealth(GetPlayerPed(-1), 400)
                    SetEntityHealth(GetPlayerPed(-1), 400)
                    SetPedArmour(GetPlayerPed(-1), 100)
                else
                    SetPedMaxHealth(GetPlayerPed(-1), 200)
                    SetEntityHealth(GetPlayerPed(-1), 200)
                    SetPedArmour(GetPlayerPed(-1), 0)
                end
            end

            SetVehicleEngineCanDegrade(currentVehicleId, false)
            
            if currentVehicleId ~= ourDriverVehicle then
                print(currentVehicleId)
                oldVehicle = ourDriverVehicle
                ourDriverVehicle = currentVehicleId
                if ourTeamType == 'driver' then
                    timeBelowSpeed = 0
                end
                --TriggerEvent('SpawnVehicle', 'firetruk', GetEntityCoords(PlayerPedId()) + vector3(0,0,0), GetEntityHeading(PlayerPedId())) 
	            
            end
            isLocalPlayerInVehicle = true
            timeRemainingOnFoot = math.clamp(timeRemainingOnFoot + 0.1, 0, 60)
            if ourTeamType == 'driver' then
                SetEntityInvincible(GetPlayerPed(-1), true)
            else
                SetVehicleFuelLevel(currentVehicleId, 100.0)
                SetEntityInvincible(GetPlayerPed(-1), false)
            end
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
          
        else
          
        end
        ]] --
        SetPoliceRadarBlips(false)
        if respawnCooldown > 0 then
            respawnCooldown = respawnCooldown - 0.1
        end

        if ourTeamType == 'driver' then
            SetVehicleCheatPowerIncrease(ourDriverVehicle, 0.6)
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
            if (GetGameTimer() - startTime) / 1000 > warmupTime then
                totalLife = (GetGameTimer() - lifeStart) / 1000
            else
                lifeStart = GetGameTimer()
            end
        end
        if selectedEndPoint ~= nil then
            distanceToFinalLocation = #(GetEntityCoords(PlayerPedId()) - selectedEndPoint.destination)
        end
        SetEnableVehicleSlipstreaming(true)
        local speedinKMH = GetEntitySpeed(driverPed) * 3.6
        local wantedLevel = 0
        if distanceToFinalLocation < 500 and ourTeamType == 'driver' then
            wantedLevel = 5
        end
        if GetPlayerWantedLevel(PlayerId()) ~= wantedLevel then
            SetPlayerWantedLevel(PlayerId(), wantedLevel, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
        local currentVehicleId = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        if distanceToFinalLocation < distanceForExtraction and ourTeamType == 'driver' and gameStarted and currentVehicleId == 0  then
            isExtracting = true
            extractionTimeRemaining = extractionTimeRemaining - 0.1
            if extractionTimeRemaining <= 0  and not hasExtracted then
                TriggerServerEvent('OnNotifyHighScore', GetPlayerName(PlayerId()), totalLife)
                Wait(1000)
                if #drivers == 0 then
                    TriggerEvent('SpawnVehicle', selectedEndPoint.vehicleModel, selectedEndPoint.vehicleSpawnLocation, selectedEndPoint.vehicleSpawnRotation)
                end
                hasExtracted = true
            end
        else
            isExtracting = false
            extractionTimeRemaining = 20
        end

        if (speedinKMH < minSpeedInKMH or speedinKMH > maxSpeedInKMH)  and (GetGameTimer() - startTime) / 1000 >
            warmupTime and ourTeamType == 'driver' and not hasExtracted and not isExtracting then
            timeBelowSpeed = timeBelowSpeed + delta_time
            timeBelowSpeed = 0
            timeBelowSpeed = math.clamp(timeBelowSpeed, 0, maxTimeBelowSpeed)
            if shouldNotifyBelowSpeed and ourTeamType == 'driver' then
                TriggerServerEvent('OnNotifyBelowSpeed',
                                   GetPlayerName(PlayerId()))
                shouldNotifyBelowSpeed = false
                shouldNotifyAboveSpeed = true
            end

            local currentVehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
            local isVehicleDead = IsEntityDead(currentVehicle) and currentVehicle
            if (timeBelowSpeed >= maxTimeBelowSpeed or isVehicleDead == true) and ourTeamType == 'driver' then
                -- blow up
                SetEntityInvincible(GetVehiclePedIsIn(GetPlayerPed(-1), false), false)
                SetEntityInvincible(GetVehiclePedIsIn(GetPlayerPed(-1), true), false)
                SetEntityInvincible(GetPlayerPed(-1), false)
                NetworkExplodeVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false), true, true, true)
                NetworkExplodeVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), true), true, true, true)
                timeBelowSpeed = 0
                print('Exploding vehicle ' .. timeBelowSpeed .. ' IsEntityDead? ' .. tostring(isVehicleDead) .. ' MaxTimeBlowSpeed? ' .. maxTimeBelowSpeed)
                
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
            if maxTimeBelowSpeed - timeBelowSpeed > 5 then
                timeBelowSpeed = timeBelowSpeed + delta_time * 0.1
            end
            if shouldNotifyAboveSpeed then
                TriggerServerEvent('OnNotifyAboveSpeed',
                                   GetPlayerName(PlayerId()), timeBelowSpeed)
                shouldNotifyAboveSpeed = false
            end
            shouldNotifyBelowSpeed = true
            timestart = GetGameTimer()
        end
    end
end)

Citizen.CreateThread(function()
    local previousLocation = vector3(0, 0, 0)
    while true do
        if ourTeamType == 'driver' and gameStarted then
            local speedinKMH = GetEntitySpeed(driverPed) * 3.6
            if speedinKMH > 80 then
                previousLocation = GetEntityCoords(GetPlayerPed(-1))
                local rot = GetEntityHeading(PlayerPedId())
                Wait(5000)
                TriggerServerEvent('OnNewRespawnPoint', previousLocation, rot)
            end
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
        SetTextFont(0)
        SetTextProportional(0)
        SetTextScale(0.0, 0.5)
        SetTextColour(0, 128, 0, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 500)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        if gameStarted then
            if startTime > warmupTime then

                local extractionText = ''
                local visibilityText = ''
                local healthText = ''
                if ourTeamType == 'driver' then
                    extractionText = '~r~Extraction Locked!'
                    if extractionBlip then
                        extractionText = '~g~Extract at ' .. selectedEndPoint.name
                    end
                    local currentVehicleId = GetVehiclePedIsIn(GetPlayerPed(-1), false)
                    if currentVehicleId == 0 then
                        visibilityText  = '~g~Hidden '
                        healthText = '~r~Killable'
                    else
                        visibilityText = '~r~Visible '
                        healthText ='~g~Immune'
                    end
                else
                    extractionText = '~r~Extraction Locked!'
                    if extractionBlip then
                        extractionText = '~g~Extract at ' .. selectedEndPoint.name
                    end
                end
               
                currentScore = totalLife * (totalPlayers * 1.68 - 1)

                local rankString = ''
                local scoreToBeatString = ''
                if currentRank ~= -1 then
                    if currentScore < scoreToBeat then
                        rankString = '~r~Rank #' .. currentRank .. (" (%.0f)"):format(scoreToBeat)
                    else
                        rankString = '~g~Rank #' .. currentRank .. (" (%.0f)"):format(scoreToBeat)
                    end
                end
                rankString = ''
                AddTextComponentString(
                    ("~g~%.1f ~s~Seconds\n ~g~%.0f ~s~Score\n%s\n%s\n%s\n\n%s\n%s\n~y~%s Drivers"):format(totalLife,
                                                                   currentScore, rankString, scoreToBeatString, extractionText, visibilityText, healthText, #drivers))

                DrawText(0.8, 0.1)                                                  
            end
            local speedinKMH = GetEntitySpeed(driverPed) * 3.6
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.65)
            if (GetGameTimer() - startTime) / 1000 < warmupTime or (speedinKMH >=
                minSpeedInKMH and speedinKMH < maxSpeedInKMH) then
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
            if (GetGameTimer() - startTime) / 1000 < warmupTime and ourTeamType ==
                'driver' and showScoreboard == false then
                AddTextComponentString(("~y~Run From The Police\n Get to the extraction point to set a score!\n%.1f"):format(
                                           warmupTime - (GetGameTimer() - startTime) /
                                               1000))
                DrawText(0.5, 0.2)
            else
                if ourTeamType == 'driver' then
                    if isExtracting then
                        AddTextComponentString(
                            ("~y~Extracting\n%.1f"):format(math.clamp(extractionTimeRemaining, 0, 999)))
                        DrawText(0.5, 0.25)
                    elseif isLocalPlayerInVehicle == false then
                        AddTextComponentString(
                            ("~y~%.1f"):format(math.clamp(timeRemainingOnFoot, 0, 60)))
                        DrawText(0.5, 0.25)
                    end
                    if timeBelowSpeed > 0 then
                        AddTextComponentString(
                            ("%.1f"):format(maxTimeBelowSpeed - timeBelowSpeed))
                        DrawText(0.5, 0.25)
                    end
                end
                

            end
            if warmupTime - (GetGameTimer() - startTime) / 1000 > 0 and totalLife < warmupTime and
                ourTeamType ~= 'driver' and showScoreboard == false then
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.0, 0.65)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                SetTextCentre(1)
                if defenderName == GetPlayerName(PlayerId()) then
                    AddTextComponentString(
                        ("~y~Do Anything You Want!\n%.1f"):format(warmupTime -
                                                                   (GetGameTimer() -
                                                                       startTime) /
                                                                   1000))
                else
                    AddTextComponentString(
                        ("~y~Stop the truck from extracting!\n%.1f"):format(warmupTime -
                                                             (GetGameTimer() -
                                                                 startTime) /
                                                             1000))
                end
                DrawText(0.5, 0.4)
            end
        else
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.5)
            SetTextColour(255, 165, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            if totalPlayers <= 1 then
                AddTextComponentString("Waiting For Players\n Game will commence when 2 Players are ready!")
            else
                AddTextComponentString("Get Ready!\n Game will begin shortly")
            end
            DrawText(0.5, 0.4)
        end
    end
end)

RegisterNetEvent("baseevents:onPlayerKilled")
AddEventHandler('baseevents:onPlayerKilled', function(killer, reason)
    TriggerEvent('OnReceivedChatMessage', 'Killer: ' .. killer .. ' Reason: ' .. reason)
   
end)

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        local inModels = {'g_m_m_chicold_01'}
        if ourTeamType  == 'driver' then
            inModels = { 'g_m_m_chicold_01', 's_m_m_movspace_01', 's_m_y_robber_01', 's_m_y_prisoner_01', 's_m_y_prismuscl_01', 's_m_y_factory_01' }
        elseif ourTeamType  == 'defender' then
            inModels = {'s_m_m_armoured_01', 's_m_m_armoured_02', 's_m_m_chemsec_01', 's_m_m_highsec_01', 's_m_y_uscg_01' }
        else
            inModels = { 's_m_y_cop_01', 's_m_y_hwaycop_01', 's_m_y_sheriff_01', 's_m_y_ranger_01' }
        end
        exports.spawnmanager:spawnPlayer({
            x = spawnPos.x,
            y = spawnPos.y,
            z = spawnPos.z,
            model = inModels[math.random(1, #inModels)],
            skipFade = true
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
    ShutdownLoadingScreen()
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    TriggerServerEvent('OnPlayerSpawned')
end)

RegisterCommand('areas', function(source, args)
    -- tell the player
    TriggerEvent('chat:addMessage',
                 {args = {'Possible Maps are \nairport\nairport_north\ndock'}})
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
                function(teamtype, spawnPos, spawnRot, inDrivers, inSelectedSpawn, isGameStarted)
    print("Client_HuntingPackStart")
    car = GetVehiclePedIsUsing(GetPlayerPed(-1), false)
    if car ~= 0 and not gameStarted then
        SetEntityAsMissionEntity(car, false, false) 
        DeleteVehicle(car)
    end
    -- account for the argument not being passed
    totalLife = 0
    timeBelowSpeed = 0
    extractionTimeRemaining = 20
    isExtracting = false
    hasExtracted = false
    timeRemainingOnFoot = 60

    if teamtype == 'driver' then
        selectedEndPoint = endPoints[math.random(1, #endPoints)]
    end
    
    currentRank = -1
    scoreToBeat = -1
    selectedSpawn = inSelectedSpawn
    totalLife = 0
    respawnCooldown = 5
    lifeStart = GetGameTimer()
    drivers = inDrivers
    if isGameStarted then
        print('game started')
        gameStarted = true
    else
        print('game stopped')
        gameStarted = false
    end
    local vehicleName = 'Sheriff2'
    ourTeamType = teamtype
    DoScreenFadeOut(0)
    exports.spawnmanager:forceRespawn()    
    Wait(1000)
    if GetEntityHealth(GetPlayerPed(-1)) <= 0 then
        ClearPedTasksImmediately(GetPlayerPed(-1))
    end
    startTime = GetGameTimer()

    if ourTeamType == 'driver' then
        SetPedArmour(GetPlayerPed(-1), 100)
    else
        SetPedArmour(GetPlayerPed(-1), 0)
    end

    RemoveAllPedWeapons(GetPlayerPed(-1), true)  

    startLocation = spawnPos
    if ourTeamType ~= 'driver' or drivers[1] == GetPlayerName(PlayerId()) then
        TriggerEvent('SpawnTeamGroundVehicle', spawnPos, spawnRot)
    end

    Wait(500)
    DoScreenFadeIn(500)

end)

AddEventHandler('SpawnTeamGroundVehicle', function(inSpawnPos, inSpawnRot)
    selectedRandomCar = math.random(1, #possibleAttackerVehicles)
    if ourTeamType == 'defender' then
        selectedRandomCar = math.random(1, #possibleDefenderVehicles)
        vehicleName = possibleDefenderVehicles[selectedRandomCar]
    elseif ourTeamType == 'driver' then
        selectedRandomCar = math.random(1, #possibleDriverVehicles)
        vehicleName = possibleDriverVehicles[selectedRandomCar]
    else
        vehicleName = possibleAttackerVehicles[selectedRandomCar]
    end
    TriggerEvent('SpawnVehicle', vehicleName, inSpawnPos, inSpawnRot)
end)


AddEventHandler('SpawnVehicle', function(vehicleName, inSpawnPos, inSpawnRot)

    car = GetVehiclePedIsUsing(GetPlayerPed(-1), false)
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

    while not NetworkGetEntityIsNetworked(vehicle) do
        NetworkRegisterEntityAsNetworked(vehicle)
        Citizen.Wait(0)
    end
    local id = NetworkGetNetworkIdFromEntity(vehicle)
    ourDriverVehicle = vehicle
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)

    --SetVehicleDoorsLocked(vehicle, 4)
    --SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)

    -- give the vehicle back to the game (this'll make the game decide when to despawn the vehicle)
    SetEntityAsNoLongerNeeded(vehicle)

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetNetworkIdExistsOnAllMachines(id, true)
    SetNetworkIdCanMigrate(id, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, false)
    SetEntityAsMissionEntity(vehicle, true, true)

    -- release the model
    SetModelAsNoLongerNeeded(vehicleName)

    --SetPedCoordsKeepVehicle(GetPlayerPed(-1),  inSpawnPos.x, inSpawnPos.y, inSpawnPos.z)
    --TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    SetPedIntoVehicle(playerPed, vehicle, -1)

    seatPosition = 0
    print(drivers[1], GetPlayerName(PlayerId()))
    if drivers[1] == GetPlayerName(PlayerId()) then
        for i, driver in ipairs(drivers) do
            if driver ~= GetPlayerName(PlayerId()) then
                TriggerServerEvent('OnNotifyDriversVehicleSpawned', GetEntityCoords(vehicle),  id, seatPosition)
                seatPosition = seatPosition + 1
            end
        end
    end

end)

RegisterNetEvent('OnNotifyDriversVehicleSpawned')
AddEventHandler('OnNotifyDriversVehicleSpawned', function(spawnPos, vehicleNetId, seatPosition)
   
    SetPedCoordsKeepVehicle(GetPlayerPed(-1),  spawnPos.x, spawnPos.y, spawnPos.z)
    while  NetworkGetEntityFromNetworkId(vehicleNetId) == 0 do
        Wait(10)
    end

    while GetVehiclePedIsIn(playerPed, false) == 0 do
        Wait(1)
        local playerPed = PlayerPedId()
        print('Spawning Ped ' .. GetPlayerName(PlayerId()) .. ' into drivers vehicle ' .. NetworkGetEntityFromNetworkId(vehicleNetId) .. ' seat position ' .. seatPosition)
        --TaskWarpPedIntoVehicle(playerPed, NetworkGetEntityFromNetworkId(vehicleNetId), seatPosition)
        SetPedIntoVehicle(playerPed, NetworkGetEntityFromNetworkId(vehicleNetId), seatPosition)
    end
end)

function GetPlayers()
    local players = {}

    for i = 0, 31 do
        if NetworkIsPlayerActive(i) then table.insert(players, i) end
    end

    return players
end

CreateThread(function()
	while true do
		-- draw every frame
        Wait(0)
        if selectedEndPoint ~= nil  then
            if distanceToFinalLocation < 500 then
            else
                Wait(1000)
            end
            DrawMarker(1, selectedEndPoint.destination.x, selectedEndPoint.destination.y, selectedEndPoint.destination.z + 2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, distanceForExtraction, distanceForExtraction, distanceForExtraction, 255, 128, 0, 50, false, true, 2, nil, nil, false)            
        end
	end
end)

Citizen.CreateThread(function()
    local blips = {}
    local gamerTags = {}
    local currentPlayer = PlayerId()
   
    while true do
        Wait(100)
        local players = GetPlayers()

        if ourTeamType == 'driver' then
            TriggerServerEvent('OnUpdateEndPoint', selectedEndPoint)
        end
        if currentScore > scoreToBeat and gameStarted and totalLife > 0 then
            if not extractionBlip then
                print('creating extraction blip')
                SetGpsActive(true)
                StartGpsMultiRoute(25, true, true)
                AddPointToGpsMultiRoute(selectedEndPoint.destination.x, selectedEndPoint.destination.y, selectedEndPoint.destination.z)
                SetGpsMultiRouteRender(true)
                extractionBlip = AddBlipForCoord(selectedEndPoint.destination.x, selectedEndPoint.destination.y, selectedEndPoint.destination.z)
                SetBlipColour(destinationBlip, 25)
            end
        else
            SetGpsActive(false)
            SetGpsMultiRouteRender(false)
            RemoveBlip(extractionBlip)
            extractionBlip = nil
        end

        for player = 0, 64 do
            if player ~= currentPlayer and NetworkIsPlayerActive(player) then
                local playerPed = GetPlayerPed(player)
                local playerName = GetPlayerName(player)

                
                RemoveBlip(blips[player])
                local currentVehicleId = GetVehiclePedIsIn(playerPed, false)
                local shouldCreateBlip = true
                if has_value(drivers, playerName) then
                    if currentVehicleId == 0 and not forceDriverBlipVisible[playerName] then
                        shouldCreateBlip = false
                    end
                elseif playerName == defenderName then
                    shouldCreateBlip = false
                end

                if ourTeamType == 'driver' then
                    shouldCreateBlip = false
                end


                gamerTag = Citizen.InvokeNative(0xBFEFE3321A3F5015, playerPed,
                playerName, false, false, '',
                false)
                gamerTags[player] = gamerTag

               
                
                if shouldCreateBlip then
                    local new_blip = AddBlipForEntity(playerPed)

                    -- Add player name to blip
                    SetBlipNameToPlayerName(new_blip, player)

                    -- Make blip white
                    if playerName == defenderName or (defenderName ==
                        GetPlayerName(PlayerId()) and playerName ~= driverName) then
                        SetBlipColour(new_blip, 64)
                        SetBlipCategory(new_blip, 380)
                        SetMpGamerTagColour(gamerTag, 0, 39)
                    elseif has_value(drivers, playerName) then
                        SetBlipColour(new_blip, 1)
                        SetBlipCategory(new_blip, 380)
                        SetMpGamerTagColour(gamerTag, 0, 208)
                    else
                        SetBlipColour(new_blip, 2)
                        SetBlipCategory(new_blip, 56)
                        SetMpGamerTagColour(gamerTag, 0, 18)
                    end

                    -- Set the blip to shrink when not on the minimap
                    -- Citizen.InvokeNative(0x2B6D467DAB714E8D, new_blip, true)

                    -- Shrink player blips slightly
                    SetBlipScale(new_blip, 0.9)

                    -- Record blip so we don't keep recreating it
                    blips[player] = new_blip

                    -- Add nametags above head
                    if not has_value(drivers, playerName) then
                        SetMpGamerTagVisibility(gamerTag, 0, true)
                    else
                        SetMpGamerTagVisibility(gamerTag, 0, false)
                    end
                    
                else
                    SetMpGamerTagVisibility(gamerTag, 0, false)
                end
            end
        end
    end

end)

RegisterNetEvent("OnUpdateLifeTimers")
AddEventHandler('OnUpdateLifeTimers', function(newTotalLife)
    if ourTeamType ~= 'driver' then totalLife = newTotalLife end
end)

RegisterNetEvent("OnUpdateDrivers")
AddEventHandler('OnUpdateDrivers', function(inDrivers)
   drivers = inDrivers
end)


RegisterNetEvent("OnUpdateEndPoint")
AddEventHandler('OnUpdateEndPoint', function(inSelectedEndPoint)
    selectedEndPoint = inSelectedEndPoint
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
    if name == driverName then
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
            AddTextComponentString(selectedSpawn.name .. " Leaderboard \n(" .. totalPlayers .. " Players In Game)")
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

RegisterCommand('respawngroundbtn', function(source, args, rawcommand)

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

    respawnCooldown = 5
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    local currentCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))

end, false)

RegisterNetEvent('OnNotifyDriverBlipVisible')
AddEventHandler('OnNotifyDriverBlipVisible', function(driverName, isVisible)
    forceDriverBlipVisible[driverName] = isVisible
end)

RegisterNetEvent('OnNotifyDriverBlipArea')
AddEventHandler('OnNotifyDriverBlipArea', function(driverName, enabled, posX, posY, posZ)
    if enabled then
        RemoveBlip(driverBlip[driverName])
        driverBlip[driverName] = AddBlipForRadius(posX, posY, posZ, 50.0)
        SetBlipColour(driverBlip[driverName], 1)
        SetBlipAlpha(driverBlip[driverName], 128)
    else
        RemoveBlip(driverBlip[driverName])
    end
end)

RegisterCommand('respawnairbtn', function(source, args, rawcommand)
--[[
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

    respawnCooldown = 5
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerEvent('SpawnVehicle', 'polmav', GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()))
      ]]--
end, false)

RegisterCommand('scoreboard', function(source, args, rawcommand)
    if showScoreboard then
        showScoreboard = false
    else
        showScoreboard = true
    end
  
end, false)

RegisterCommand('debug', function(source, args, rawcommand)
   if GetPlayerName(PlayerId()) == '886 // RyroNZ' then
        SetPedCoordsKeepVehicle(GetPlayerPed(-1),  selectedEndPoint.destination.x+5, selectedEndPoint.destination.y+5, selectedEndPoint.destination.z)
   end
  
end, false)

RegisterKeyMapping('respawngroundbtn', 'Respawn Land Vehicle', "keyboard", "F1")
RegisterKeyMapping('respawnairbtn', 'Respawn Air Vehicle', "keyboard", "F2")
RegisterKeyMapping('debug', 'Debug', "keyboard", "F3")
RegisterKeyMapping('scoreboard', 'Scoreboard', 'keyboard', 'CAPITAL')
