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

local function add_value(tab, val)
    tab[#tab+1] = val
end

local warmupTime = 15
local distanceForExtraction = 20.0
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
local defenders = {}
local attackers = {}
local defenderName = ''
local driverPed = 0
local afkTime = 0
local isMarkedAfk = false
local respawnCooldown = 0
local currentSpawnConfig = {name = 'None', driverSpawnVec = vector3(0,0,0), driverSpawnRot = 0, attackerSpawnVec = vector3(0,0,0), attackerSpawnRot = 0, defenderSpawnVec = vector3(0,0,0), defenderSpawnRot = 0}
local selectedSpawn = nil
local showScoreboard = false
local showRules = false
local distanceToFinalLocation = -1
local endPoints = {
    {name = 'Airport', destination = vector3(-1657.05, -3155.652, 13), vehicleModel = 'miljet', vehicleSpawnLocation = vector3(-1583,-2999,14), vehicleSpawnRotation = 240.0},
    {name = 'Ocean South', destination = vector3(1793.05, -2725.652, 1.5), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(1804.1, -2759.189, -1.85), vehicleSpawnRotation = 205.0},
    {name = 'Ocean North', destination = vector3(-1610.05, 5261.652, 4.2), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(-1601.945,5265.29,0), vehicleSpawnRotation = 358.0},
    {name = 'Beach', destination = vector3(-1841.05, -1254.652, 9), vehicleModel = 'Jetmax', vehicleSpawnLocation = vector3(-1859.0, -1268.0,3.3), vehicleSpawnRotation = 204.0},
    {name = 'Central Hangar', destination = vector3(1732.11, 3310.439, 40.7), vehicleModel = 'nimbus', vehicleSpawnLocation = vector3(1691.0, 3250.113, 40.55), vehicleSpawnRotation = 108.0},
    {name = 'North Hangar', destination = vector3(2135.35, 4780.083, 40.7), vehicleModel = 'velum2', vehicleSpawnLocation = vector3(2109.68, 4801.245,40.71), vehicleSpawnRotation = 112.0}
}
local selectedEndPoint = nil
local totalPlayers = 0
local currentRank = {}
local scoreToBeat = {}
local timeRemainingOnFoot = 60
local isLocalPlayerInVehicle = false
local timeDead = 0
local oldVehicle = 0
local possibleDriverVehicles = {'Firetruk', 'stockade', 'stockade3', 'pounder2', 'coach', 
'banshee', 'futo', 'tourbus', 'trash', 'lguard', 'Comet3', 'Feltzer2', 'Elegy2', 'Kuruma', 'RapidGT'}
local possibleAttackerVehicles = {
        'FBI', 'FBI2', 'Police3', 'Sheriff2', 'Police2', 'Police', 'Police4',
        'Pranger', 'Sheriff', 'policeb', 'policet'
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
local possiblePoliceWeapons = {  { model = 'Nightstick', ammo = 1, equip = true, weaponLevel = 0}, { model = 'pistol_mk2', ammo = 18, equip = true, weaponLevel = 2}, {model = 'pumpshotgun', ammo = 24, equip = false, weaponLevel = 3}, {model = 'SpecialCarbine', ammo = 30, equip = false, weaponLevel = 4} }
local possibleDriverWeapons = { {model = 'knife', equip = false, ammo = 1, weaponLevel = 0},  { model = 'SNSPistol', ammo = 5, equip = true, weaponLevel = 0}, {model = 'Pistol50', ammo = 18, equip = true, weaponLevel = 1}, {model = 'microsmg', ammo = 48, equip = false, weaponLevel = 2} , {model = 'CompactRifle', ammo = 60, equip = false, weaponLevel = 3}, {model = 'sniperrifle', ammo = 15, equip = false, weaponLevel = 4} }
local weaponHash = nil
local currentVehicleId = 0
local triggeredLowTimeSound = false
local weaponUpgradeLevel = 0
local previousHealth = 0
local timeUntilHealthRegen = 0.0

local renderText = ''
local renderTextTime = 0.0

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end

function IsDriver()
    return ourTeamType == 'driver'
end

function IsPolice()
    return ourTeamType == 'attacker'
end

function IsImposter()
    return ourTeamType == 'defender'
end

function IsInVehicle()
    return currentVehicleId ~= 0
end

function drawProgressBar(x, y, width, height, colour, percent)
    local w = width * (percent/100)
    local x = (x - (width * (percent/100))/2)-width/2    
    DrawRect(x+w, y, w, height, colour[1], colour[2], colour[3], colour[4])
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local speedinKMH = GetEntitySpeed(GetPlayerPed(-1)) * 3.6
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

RegisterNetEvent('baseevents:leftVehicle')
AddEventHandler('baseevents:leftVehicle', function(currentvehicle, seat,name,netid)
    RemoveAllPedWeapons(GetPlayerPed(-1))
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
        currentVehicleId = GetVehiclePedIsIn(playerPed, false)
        local isDriver = GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId()), -1) == PlayerPedId()
        driverPed = playerPed

        SetCanAttackFriendly(playerPed, true, true)
        NetworkSetFriendlyFireOption(true)

        

        if GetEntityHealth(playerPed) <= 0 then
            respawnCooldown = 10
            timeDead = timeDead + 0.1
            if IsDriver() and gameStarted and totalLife > 0 and shouldNotifyAboutDeath then
                shouldNotifyAboutDeath = false
                TriggerServerEvent('OnNotifyKilled', GetPlayerName(PlayerId()), totalLife)
            end
            if timeDead > 10 then
                respawnCooldown = 5          
                TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
            end
        else
            timeDead = 0
        end

        local vehicleClass = GetVehicleClass(currentVehicleId)
        local giveWeapon = currentVehicleId == 0 or not isDriver
        if giveWeapon then
            local weapons = possiblePoliceWeapons
            if IsDriver() then
                weapons = possibleDriverWeapons
            end
            for _, weapon in pairs(weapons) do
                weaponHash = GetHashKey("WEAPON_".. weapon.model)
                if weaponUpgradeLevel >= weapon.weaponLevel then
                    if not HasPedGotWeapon(playerPed, weaponHash, false) then
                        GiveWeaponToPed(playerPed, weaponHash, weapon.ammo, false, weaponUpgradeLevel == weapon.weaponLevel)
                    end
                end
            end
            SetPlayerCanDoDriveBy(playerPed, true)
        else
            SetPlayerCanDoDriveBy(playerPed, false)
            RemoveAllPedWeapons(playerPed)
        end

        local playerName = GetPlayerName(PlayerId())
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
        local currentHealth = GetEntityHealth(GetPlayerPed(-1))
        if currentHealth < previousHealth then
            timeUntilHealthRegen = 10
        else
            timeUntilHealthRegen = timeUntilHealthRegen - 0.1
        end

        previousHealth = GetEntityHealth(GetPlayerPed(-1))

        if timeUntilHealthRegen <= 0 then
            local currentArmor = GetPedArmour(GetPlayerPed(-1))
            local maxHealth = 200
            local maxArmour = 50
            if IsDriver() then 
                maxHealth = 400
                maxArmour = 100
            end
            if currentHealth < maxHealth then
                SetPedMaxHealth(GetPlayerPed(-1), maxHealth)
                SetEntityHealth(GetPlayerPed(-1), currentHealth + 1)
            end
            if currentArmor < 100 then
                SetPedArmour(GetPlayerPed(-1), currentArmor + 1)
            end
        end

        if currentVehicleId == 0 then
            local coords = GetEntityCoords(PlayerPedId())
        
            if forceDriverBlipVisible[playerName] and IsDriver() then
                TriggerEvent('OnNotifyDriversBlipVisible', GetPlayerName(PlayerId()), false)
                TriggerServerEvent('OnNotifyDriverBlipVisible', GetPlayerName(PlayerId()),  false) 
            end  
            if IsDriver() and not createdBlipForRadius then
                createdBlipForRadius = true

                TriggerServerEvent('OnNotifyDriverBlipArea', playerName, true, coords.x, coords.y, coords.z)
            end
            needsResetHealth = true
            isLocalPlayerInVehicle = false
            if not isExtracting then
                timeRemainingOnFoot = timeRemainingOnFoot - 0.1
            end
            if timeRemainingOnFoot <= 9 and not triggeredLowTimeSound and IsDriver() then
                triggeredLowTimeSound = true
                PlaySoundFrontend(999, '10s', 'MP_MISSION_COUNTDOWN_SOUNDSET')               
            end
            if timeRemainingOnFoot <= 0 and IsDriver() then
                SetEntityHealth(GetPlayerPed(-1), 0)
            end
           
            SetEntityInvincible(GetPlayerPed(-1), false)
            
        else
            triggeredLowTimeSound = false
            StopSound(999)
            if not forceDriverBlipVisible[playerName] and IsDriver() then
                TriggerEvent('OnNotifyDriversBlipVisible', playerName, true)
                TriggerServerEvent('OnNotifyDriverBlipVisible', playerName, true) 
            end   

            if createdBlipForRadius then
                createdBlipForRadius = false             
                TriggerServerEvent('OnNotifyDriverBlipArea', playerName, false, 0, 0, 0)
            end

            SetVehicleEngineCanDegrade(currentVehicleId, false)
            
            if currentVehicleId ~= ourDriverVehicle then
                maxTimeBelowSpeed = math.random(0.0, 60.0)
                 -- 14 = Boats 15 - Helicopter 16 - Plane
                if (vehicleClass == 14 or vehicleClass == 15 or vehicleClass == 16) then
                    maxTimeBelowSpeed = math.random(0.0, 20.0)
                end
                oldVehicle = ourDriverVehicle
                ourDriverVehicle = currentVehicleId
                if IsDriver() then
                    timeBelowSpeed = 0
                end
                --TriggerEvent('SpawnVehicle', 'firetruk', GetEntityCoords(PlayerPedId()) + vector3(0,0,0), GetEntityHeading(PlayerPedId())) 
	            
            end
            isLocalPlayerInVehicle = true
            timeRemainingOnFoot = math.clamp(timeRemainingOnFoot + 0.1, 0, 60)
            if IsDriver() and timeBelowSpeed < maxTimeBelowSpeed then
                SetEntityInvincible(GetPlayerPed(-1), true)
            else
                if IsDriver() then
                    SetVehicleFuelLevel(currentVehicleId, 0.0)
                else
                    SetVehicleFuelLevel(currentVehicleId, 100.0)
                end
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
        if IsDriver() then
            SetVehicleCheatPowerIncrease(currentVehicleId, 0.6)
        elseif IsImposter() then
            SetVehicleCheatPowerIncrease(currentVehicleId, 0.6)
        else
            SetVehicleCheatPowerIncrease(currentVehicleId, 1.3)
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
    while true do
        Citizen.Wait(16)
        
        if IsDriver() then
            SetPedMoveRateOverride(PlayerPedId(), 0.25)
        else
            SetPedMoveRateOverride(PlayerPedId(), 0.5)
        end
        
    end
end)

Citizen.CreateThread(function()

    timestart = GetGameTimer()
    tick = GetGameTimer()
    while true do
        delta_time = (GetGameTimer() - tick) / 1000
        tick = GetGameTimer()
        Citizen.Wait(100) -- check all 15 seconds
        totalLife =  totalLife + delta_time
        if selectedEndPoint ~= nil then
            distanceToFinalLocation = #(GetEntityCoords(PlayerPedId()) - selectedEndPoint.destination)
        end

      
        SetEnableVehicleSlipstreaming(true)
        local speedinKMH = GetEntitySpeed(driverPed) * 3.6
        local wantedLevel = 0
        if distanceToFinalLocation < 500 and IsDriver() then
            wantedLevel = 5
        end
        if GetPlayerWantedLevel(PlayerId()) ~= wantedLevel then
            SetPlayerWantedLevel(PlayerId(), wantedLevel, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
        local finalDistanceCheck = distanceForExtraction - 10
        if distanceToFinalLocation < finalDistanceCheck and IsDriver() and gameStarted and currentVehicleId == 0 and extractionBlip and not IsPedSwimming(PlayerPedId())  then
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
            if extractionTimeRemaining <= 20 then
                extractionTimeRemaining = extractionTimeRemaining + 0.1
            end
        end

        if (GetGameTimer() - startTime) / 1000 >
            warmupTime and IsDriver() and not hasExtracted and not isExtracting then
            local currentVehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
            local isVehicleDead = IsEntityDead(currentVehicle) and currentVehicle
            if GetIsVehicleEngineRunning(currentVehicle) then
                timeBelowSpeed = timeBelowSpeed + (delta_time * (speedinKMH * 0.01))
                timeBelowSpeed = math.clamp(timeBelowSpeed, 0, maxTimeBelowSpeed)
            end
            if shouldNotifyBelowSpeed and IsDriver() then
                TriggerServerEvent('OnNotifyBelowSpeed',
                                   GetPlayerName(PlayerId()))
                shouldNotifyBelowSpeed = false
                shouldNotifyAboveSpeed = true
            end


            if timeBelowSpeed >= maxTimeBelowSpeed then
                SetEntityInvincible(GetVehiclePedIsIn(GetPlayerPed(-1), false), false)
                SetEntityInvincible(GetPlayerPed(-1), false)
                if GetIsVehicleEngineRunning(GetVehiclePedIsIn(GetPlayerPed(-1)), false) then
                    SetVehicleEngineOn(GetVehiclePedIsIn(GetPlayerPed(-1), false), false, true, false)
                end
            end
            if isVehicleDead == true and IsDriver() then
                -- blow up
                SetEntityInvincible(GetPlayerPed(-1), false)
                NetworkExplodeVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false), true, true, true)
                timeBelowSpeed = 0
                print('Exploding vehicle ' .. timeBelowSpeed .. ' IsEntityDead? ' .. tostring(isVehicleDead) .. ' MaxTimeBlowSpeed? ' .. maxTimeBelowSpeed)
                
                EndLocation = GetEntityCoords(PlayerPedId())
            end
        end
    end
end)

Citizen.CreateThread(function()
    local previousLocation = vector3(0, 0, 0)
    while true do
        if IsDriver() and gameStarted then
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
    while true do
        Wait(0)
        if gameStarted then
            if startTime > warmupTime then
                local textArray = {}
                
                local extractionText = ''
                local visibilityText = ''
                local healthText = ''

                if IsDriver() then
                    add_value(textArray, '~r~Driver')
                elseif IsPolice() then
                    add_value(textArray, '~b~Police')
                elseif IsImposter() then
                    add_value(textArray, '~y~Imposter')
                end
                
                if extractionBlip then
                    add_value(textArray, '~y~Extraction at ' .. selectedEndPoint.name)
                else
                    add_value(textArray, '~y~Extraction Locked!')
                end

                add_value(textArray, ('~g~%.1f ~s~Seconds' ):format(totalLife) )
                add_value(textArray, ('~g~%.0f ~s~Score'):format(currentScore))
                add_value(textArray,  '')
                if ourTeamType == 'driver' then
                    if currentVehicleId == 0 then
                        add_value(textArray,  '')
                        add_value(textArray,  '~g~Hidden From Radar')
                      
                    else
                        add_value(textArray,  '')
                        add_value(textArray,  '~r~Visible On Radar')
                    end

                    if currentVehicleId == 0 then
                        add_value(textArray,  '~r~Killable ~y~ (On Foot)')
                    elseif timeBelowSpeed >= maxTimeBelowSpeed then
                        add_value(textArray,  '~r~Killable ~y~(Vehicle Disabled)')
                    else
                        add_value(textArray, '~g~Immune To Damage')
                    end
                end

              
               
                currentScore = totalLife * (totalPlayers * 1.68 - 1)
                for i, text in pairs(textArray) do
                    SetTextFont(0)
                    SetTextProportional(0)
                    SetTextScale(0.0, 0.35)
                    SetTextColour(0, 128, 0, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 500)
                    SetTextDropShadow()
                    SetTextOutline()
                    SetTextEntry("STRING")
                    SetTextCentre(1)
                    AddTextComponentString(
                        ("%s"):format(text))
                        DrawText(0.85, 0.1 + (i * 0.03))
                end

                                                                  
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
            if IsDriver() and showScoreboard == false and showRules == false then
                if isExtracting then
                    AddTextComponentString(
                        ("~y~Extracting\n%.1f"):format(math.clamp(extractionTimeRemaining, 0, 999)))
                    DrawText(0.5, 0.25)
                end
                if timeBelowSpeed >= maxTimeBelowSpeed and IsInVehicle() then
                    AddTextComponentString("~r~Out Of Fuel")
                    DrawText(0.5, 0.15)
                end
                if not IsInVehicle() and timeRemainingOnFoot < 15.0 then
                    AddTextComponentString("~r~Find a vehicle!")
                    DrawText(0.5, 0.15)
                end
            end
        elseif showScoreboard == false and showRules == false then
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
                AddTextComponentString("Waiting For Players\n Game will commence when ~r~2~s~ players are ready!")
            else
                AddTextComponentString("Get Ready!\n Game will begin shortly")
            end
            DrawText(0.5, 0.4)
        end
    end
end)



AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        local inModels = {'g_m_m_chicold_01'}
        if ourTeamType  == 'driver' then
            inModels = { 'g_m_m_chicold_01', 's_m_m_movspace_01', 's_m_y_robber_01', 's_m_y_prisoner_01', 's_m_y_prismuscl_01', 's_m_y_factory_01', 'a_f_y_hippie_01', 's_m_y_dealer_01', 'u_m_y_mani' }
        elseif ourTeamType  == 'defender' then
            inModels = {'s_m_m_armoured_01', 's_m_m_armoured_02', 's_m_m_chemsec_01', 's_m_m_highsec_01', 's_m_y_uscg_01' }
        else
            inModels = { 's_m_y_cop_01', 's_m_y_hwaycop_01', 's_m_y_sheriff_01', 's_m_y_ranger_01', 's_m_m_fibsec_01' }
        end
        selectedModel = inModels[math.random(1, #inModels)]
        print('spawning as model ' .. selectedModel)
        exports.spawnmanager:spawnPlayer({
            x = spawnPos.x,
            y = spawnPos.y,
            z = spawnPos.z,
            model = selectedModel ,
            skipFade = true
        })
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

RegisterNetEvent('OnReceivedServerNotification')
AddEventHandler('OnReceivedServerNotification', function(text)
    print('Recevied text ' .. text)
    renderTextTime = 0
    renderText = text
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

AddEventHandler('onHuntingPackStart',
                function(teamtype, spawnPos, spawnRot, inDrivers, inSelectedSpawn, isGameStarted)
    print("Client_HuntingPackStart")
    car = GetVehiclePedIsUsing(GetPlayerPed(-1), false)
    if car ~= 0 and not gameStarted then
        SetEntityAsMissionEntity(car, false, false) 
        DeleteVehicle(car)
    end
    -- account for the argument not being passed
    startTime = GetGameTimer()
    totalLife = 0
    timeBelowSpeed = 0
    extractionTimeRemaining = 20
    isExtracting = false
    hasExtracted = false
    timeRemainingOnFoot = 60
    shouldNotifyAboutDeath = true
    drivers = inDrivers
    if teamtype == 'driver' and drivers[1] == GetPlayerName(PlayerId()) then
        selectedEndPoint = endPoints[math.random(1, #endPoints)]
        TriggerServerEvent('OnUpdateEndPoint', selectedEndPoint)
    end
    
    currentRank = {}
    scoreToBeat = {}
    selectedSpawn = inSelectedSpawn
    respawnCooldown = 5
    lifeStart = GetGameTimer()

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
    local playerPed = PlayerPedId()
    while GetVehiclePedIsIn(playerPed, false) == 0 do
        Wait(1)
       
        --print('Spawning Ped ' .. GetPlayerName(PlayerId()) .. ' into drivers vehicle ' .. NetworkGetEntityFromNetworkId(vehicleNetId) .. ' seat position ' .. seatPosition)
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
        local localScoreToBeat = 0
        if (scoreToBeat[GetPlayerName(PlayerId())] ~= nil) then
            localScoreToBeat = scoreToBeat[GetPlayerName(PlayerId())]
        end
        local shouldCreateExtraction = (currentScore > localScoreToBeat or ourTeamType ~= 'driver') and selectedEndPoint ~= nil and totalLife > 1
        if gameStarted and shouldCreateExtraction == true then
            if not extractionBlip then
                print('creating extraction blip')
                SetGpsActive(true)
                extractionBlip = AddBlipForCoord(selectedEndPoint.destination.x, selectedEndPoint.destination.y, selectedEndPoint.destination.z)
                SetBlipColour(destinationBlip, 25)
                SetBlipRoute(extractionBlip, true)
            end
        else
            RemoveBlip(extractionBlip)
            extractionBlip = nil
        end

        local localPlayerName =  GetPlayerName(PlayerId())

        for player = 0, 64 do
            if player ~= currentPlayer and NetworkIsPlayerActive(player) then
                local playerPed = GetPlayerPed(player)
                local playerName = GetPlayerName(player)
            
                local currentVehicleId = GetVehiclePedIsIn(playerPed, false)
                local shouldCreateBlip = true
                if has_value(drivers, playerName) and not has_value(drivers, localPlayerName) then
                    if currentVehicleId == 0 and not forceDriverBlipVisible[playerName] then
                        shouldCreateBlip = false
                    end
                end

                if has_value(defenders, playerName) and not has_value(defenders, localPlayerName) and not has_value(drivers, localPlayerName) then
                    shouldCreateBlip = false
                end



                if (not has_value(drivers, playerName) and not has_value(defenders, playerName)) and has_value(drivers, localPlayerName) then
                    shouldCreateBlip = false
                end


                gamerTag = Citizen.InvokeNative(0xBFEFE3321A3F5015, playerPed,
                playerName, false, false, '',
                false)
                gamerTags[player] = gamerTag

               
                
                if shouldCreateBlip then
                    local new_blip = blips[player]
                    if not DoesBlipExist(new_blip) then
                        new_blip = AddBlipForEntity(playerPed)
                    end

                    -- Add player name to blip
                    SetBlipNameToPlayerName(new_blip, player)

                    -- Make blip white
                    if has_value(defenders, playerName) and not has_value(defenders, localPlayerName) then
                        SetBlipColour(new_blip, 64)
                        SetBlipCategory(new_blip, 380)
                        SetMpGamerTagColour(gamerTag, 0, 39)
                    elseif has_value(drivers, playerName) and not has_value(drivers,  localPlayerName) then
                        SetBlipColour(new_blip, 1)
                        SetBlipCategory(new_blip, 380)
                        SetMpGamerTagColour(gamerTag, 0, 208)
                    elseif has_value(attackers, playerName) then
                        SetBlipColour(new_blip, 4)
                        SetBlipCategory(new_blip, 56)
                        SetMpGamerTagColour(gamerTag, 0, 9)
                    else
                        SetBlipColour(new_blip, 2)
                        SetBlipCategory(new_blip, 56)
                        SetMpGamerTagColour(gamerTag, 0, 18)
                    end

                    --if has_value(drivers, playerName) and not DoesBlipHaveGpsRoute(new_blip) then
                    --    SetBlipRoute(new_blip, true)
                    --    SetBlipRouteColour(new_blip, 6)
                    --end

                    -- Set the blip to shrink when not on the minimap
                    -- Citizen.InvokeNative(0x2B6D467DAB714E8D, new_blip, true)

                    -- Shrink player blips slightly
                    SetBlipScale(new_blip, 0.9)

                    -- Record blip so we don't keep recreating it
                    blips[player] = new_blip

                    -- Add nametags above head
                    if (not has_value(drivers, playerName) or (has_value(drivers, playerName) and has_value(drivers, localPlayerName))) or (not has_value(defenders, playerName)  or (has_value(defenders, playerName) and has_value(defenders, localPlayerName))) then
                        SetMpGamerTagVisibility(gamerTag, 0, true)
                    else
                        SetMpGamerTagVisibility(gamerTag, 0, false)
                    end

                    
                    
                else
                    RemoveBlip(blips[player])
                    SetMpGamerTagVisibility(gamerTag, 0, false)
                end
            end
        end
    end

end)

Citizen.CreateThread(function()
    local previousLocation = vector3(0, 0, 0)
    while true do
        Wait(1000)
        if drivers[1] ~= nil then
            if  drivers[1] == GetPlayerName(PlayerId()) then
                TriggerServerEvent('OnUpdateLifeTimers', totalLife)
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

RegisterNetEvent("OnUpdateAttackers")
AddEventHandler('OnUpdateAttackers', function(inAttackers)
   atackers = inAttackers
end)

RegisterNetEvent("OnUpdateDefenders")
AddEventHandler('OnUpdateDefenders', function(inDefenders)
   defenders = inDefenders
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
    scoreToBeat[name] = lifetime * (players * 1.68 - 1)
    currentRank[name] = rank
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
    local tick_start = GetGameTimer()
       
    while true do
        Wait(0)
        local dtime = (GetGameTimer() - tick_start) / 1000
        tick_start = GetGameTimer()
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
        if showRules then
            DrawRules(false)
        end

        if gameStarted and totalLife == 0 and not showRules then
            DrawRules(true)
        end
        DrawLatestServerText(dtime)


        if IsDriver() and totalLife > 0 then
            drawProgressBar(0.5, 0.85, 0.0730, 0.0185, {0, 0, 0, 128}, 100)
            local colorVehicleFuel = {}
            local colorOnFootTime = {}
            local currentPercentage = (maxTimeBelowSpeed-timeBelowSpeed)/60.0
            if  currentVehicleId == 0 then
                currentPercentage = (timeRemainingOnFoot/60.0)
            end
            currentPercentage = math.clamp(currentPercentage, 0.0, 100.0)
            if currentPercentage > 0.75 then
                color = {111,252,3,255}
            elseif currentPercentage > 0.5 then
                color = {252,232,3,255}
            elseif currentPercentage > 0.25 then
                color = {252,127,3,255}
            else
                color = {252,3,3,255}
            end
            drawProgressBar(0.5, 0.85, 0.0690, 0.0085, color, (currentPercentage * 100))
        end
    end
end)


function DrawLatestServerText(dtime)
    renderTextTime = renderTextTime + dtime
    if renderText ~= '' and renderTextTime < 10 then
        SetTextFont(0)
        SetTextProportional(0)
        SetTextScale(0.0, 0.28)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(10, 0, 0, 0, 255)
        SetTextEdge(2, 2, 2, 2, 500)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(
            ("%s"):format(renderText))
        DrawText(0.5, 0.01)
    end
end

function DrawRules(onlyTeamRules)

    textArray = {}

        if onlyTeamRules then
            add_value(textArray, '~g~Press F5 to view the full list of the game rules')
            add_value(textArray, '')
            if IsDriver() then
                add_value(textArray, '[~r~Driver~s~]')
                add_value(textArray, '~s~You must make it to the ~y~extraction point~s~ to set a score')
                add_value(textArray, '~s~You are ~y~immune~s~ to all damage while inside a vehicle')
                add_value(textArray, '~s~If you run out of ~y~fuel~s~, you\'ll need to find another vehicle to keep moving')
                add_value(textArray, '~s~You have a limited time on foot, if the timer reaches ~y~zero~s~ you die')
                add_value(textArray, '~s~While on foot you may be ~y~killed ~s~but you are ~y~hidden~s~ on radar from the ~b~Police')
                add_value(textArray, '~s~You may kill the ~y~Imposter if you wish') 
            end
            if IsPolice() then
                add_value(textArray, '[~b~Police~s~]')
                add_value(textArray, '~s~You must try and stop the ~r~Driver~s~ from reaching the extraction point by any means')
                add_value(textArray, '~s~You cannot kill the ~r~Driver~s~ while they are in any vehicle')
                add_value(textArray, '~s~You may kill the ~y~Imposter~s~ if you wish') 
            end
            if IsImposter() then
                add_value(textArray, '[~y~Imposter~s~]')
                add_value(textArray, '~s~You will respawn as the ~y~Imposter~s~ if you are killed as a ~r~Driver')
                add_value(textArray, '~s~You can do ~p~anything~s~ you want. ~p~No Rules.')
            end

        else
            add_value(textArray, '')
            add_value(textArray, '~r~[Driver]')
            add_value(textArray, '~s~You must make it to the ~y~extraction point~s~ to set a score')
            add_value(textArray, '~s~You are ~y~immune~s~ to all damage while inside a vehicle that has not run out ~y~fuel')
            add_value(textArray, '~s~If you run out of ~y~fuel~s~, you\'ll need to find another vehicle to keep moving')
            add_value(textArray, '~s~You have a limited time on foot, if the timer reaches ~y~zero~s~ you die')
            add_value(textArray, '~s~While on foot you may be ~y~killed ~s~but you are ~y~hidden~s~ on radar from the ~b~Police')
            add_value(textArray, '~s~You may kill the ~y~Imposter~s~ if you wish')
            add_value(textArray, '')
            add_value(textArray, '~b~[Police]')
            add_value(textArray, '~s~You must try and stop the ~r~Driver~s~ from reaching the extraction point by any means')
            add_value(textArray, '~s~You cannot kill the ~r~Driver~s~ while they are in any vehicle (that has fuel)')
            add_value(textArray, '~s~You may kill the ~y~Imposter~s~ if you wish')
            add_value(textArray, '')
            add_value(textArray, '~y~[Imposter]')
            add_value(textArray, '5+ Players')
            add_value(textArray, '~s~You will respawn as the ~y~Imposter~s~ if you are killed as a ~r~Driver')
            add_value(textArray, '~s~You can do ~p~anything~s~ you want. ~p~No Rules.')
            add_value(textArray, '')
            add_value(textArray, '~o~[Tips]')
            add_value(textArray, '~o~You will refresh your ammo when you are in the drivers seat of a vehicle')
            add_value(textArray, '~o~If you are far away, use ~p~F1~o~ to respawn quickly into the action')
            add_value(textArray, '~o~The longer you take to extract as the driver the more points you will receive')
            add_value(textArray, '~o~The extraction will not be visible to you until you beat your highscore on the leaderboard')
            add_value(textArray, '~o~You can carjack players using ~p~G~o~ by default')
            add_value(textArray, '~o~Weapons are upgraded when the ~r~Driver~o~ kills ~b~Police')
        end
    for i, text in pairs(textArray) do
        SetTextFont(0)
        SetTextProportional(0)
        SetTextScale(0.0, 0.28)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(10, 0, 0, 0, 255)
        SetTextEdge(2, 2, 2, 2, 500)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(
            ("%s"):format(text))
            DrawText(0.5, 0.2 + (i * 0.02))
    end
end
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

RegisterNetEvent('OnWeaponUpgrade')
AddEventHandler('OnWeaponUpgrade', function(inWeaponUpgradeLevel)
    weaponUpgradeLevel = inWeaponUpgradeLevel
end)

RegisterNetEvent('OnNotifyDriverBlipArea')
AddEventHandler('OnNotifyDriverBlipArea', function(driverName, enabled, posX, posY, posZ)
    if enabled then
        PlaySoundFrontend(999, 'Lose_1st', 'GTAO_Magnate_Boss_Modes_Soundset')       
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

RegisterCommand('+scoreboard', function(source, args, rawcommand)
    showScoreboard = true
  
end, false)

RegisterCommand('-scoreboard', function(source, args, rawcommand)
    showScoreboard = false
  
end, false)

local carJackingVehicle = 0
local isCarjacking = false
RegisterCommand('+carjack', function(source, args, rawcommand)
    local closestPlayerDist = 10
    local closestPlayerPed = 0
    local currentPlayer = PlayerId()
    for player = 0, 64 do
        if player ~= currentPlayer and NetworkIsPlayerActive(player) then
            local playerPed = GetPlayerPed(player)
            local playerName = GetPlayerName(player)
            local distanceToPlayer = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(playerPed))
            if distanceToPlayer < closestPlayerDist then
                closestPlayerDist = distanceToPlayer
                closestPlayerPed = playerPed
            
            end
        end
    end
    if closestPlayerPed ~= 0 then
        local pos = GetEntityCoords(GetPlayerPed(-1))
        local veh = GetVehiclePedIsIn(closestPlayerPed, true)
        if veh ~= 0 then
            isCarjacking = true
            carJackingVehicle = veh
            TaskEnterVehicle(GetPlayerPed(-1), veh, 30.0, -1, 2.0, 8, 0)
        end
    end
  
end, false)


RegisterCommand('-carjack', function(source, args, rawcommand)

    isCarjacking = false
    ClearPedTasks(GetPlayerPed(-1))
  
end, false)


Citizen.CreateThread(function()
    while true do
        Wait(100)
        if isCarjacking and GetVehiclePedIsIn(PlayerPedId()) == carJackingVehicle then
            TaskLeaveVehicle(PlayerPedId(), carJackingVehicle, 256)
            isCarjacking = false
            carJackingVehicle = 0
        end
    end
end)


RegisterCommand('+rules', function(source, args, rawcommand)
    showRules = true
end, false)

RegisterCommand('-rules', function(source, args, rawcommand)
    showRules = false
end, false)

RegisterCommand('debug', function(source, args, rawcommand)
   if GetPlayerName(PlayerId()) == '886 // RyroNZ' then
        SetPedCoordsKeepVehicle(GetPlayerPed(-1),  selectedEndPoint.destination.x+5, selectedEndPoint.destination.y+5, selectedEndPoint.destination.z)
   end
  
end, false)

RegisterKeyMapping('respawngroundbtn', 'Respawn Land Vehicle', "keyboard", "F1")
RegisterKeyMapping('respawnairbtn', 'Respawn Air Vehicle', "keyboard", "F2")
RegisterKeyMapping('debug', 'Debug', "keyboard", "F3")
RegisterKeyMapping('+scoreboard', 'Scoreboard', 'keyboard', 'CAPITAL')
RegisterKeyMapping('+carjack', 'Car Jack', 'keyboard', 'G')
RegisterKeyMapping('+rules', 'View Rules', 'keyboard', 'F5')
