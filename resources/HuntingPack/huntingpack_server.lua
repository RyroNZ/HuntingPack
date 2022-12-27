local spawnedPlayers = {}
local drivers = {}
local defenders = {}
local attackers = {}
local afkplayers = {}
local timerCountdown = 30
local gameStarted = false
local selectedSpawn = nil
local respawnRot = 0
local defaultLocation =
    'resources\\HuntingPack\\config\\'
local respawnPoint = vector3(0, 0, 0)
local lifeStart = GetGameTimer()
local startTime = GetGameTimer()
local totalLife = 0
local defenderPlayerId = -1

local function has_value(tab, val)
    for index, value in ipairs(tab) do if value == val then return true end end

    return false
end

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end



function GetSpawnedPlayers() return spawnedPlayers end

RegisterNetEvent("OnPlayerSpawned")
AddEventHandler('OnPlayerSpawned', function()
    print('Added spawned playerIdx to table: ' .. source)
    spawnedPlayers[#spawnedPlayers + 1] = source
end)

function shuffle(tbl)
    for i = #tbl, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
  end

AddEventHandler('playerDropped', function(reason)
    print(
        'Player ' .. GetPlayerName(source) .. ' dropped (Reason: ' .. reason ..
            ')')
    droppedIdx = -1
    droppedPlayerId = -1
    for Idx, playerId in ipairs(GetSpawnedPlayers()) do
        if playerId == source then
            droppedIdx = Idx
            droppedPlayerId = playerId
        end
    end
    print('DroppedIdx: ' .. droppedIdx .. ' DroppedPlayerId ' .. droppedPlayerId)
    if  has_value(drivers, GetPlayerName(source)) then

        outDriverIdx = -1
        for Idx, v in ipairs(drivers) do
            if v == GetPlayerName(source) then
            outDriverIdx = Idx
            end
        end
    
        if outDriverIdx ~= -1 then
            table.remove(drivers, outDriverIdx)
        end

        TriggerClientEvent('OnUpdateDrivers', -1, drivers)
    end
    if spawnedPlayers[droppedIdx] ~= nil then
        table.remove(spawnedPlayers, droppedIdx)
    end
end)

function saveTable(t, filename)

    -- Path for the file to write
    local path = defaultLocation .. filename

    -- Open the file handle
    local file, errorString = io.open(path, "w")

    if not file then
        -- Error occurred; output the cause
        print("File error (Save): " .. errorString)
        return false
    else
        -- Write encoded JSON data to file
        file:write(json.encode(t))
        -- Close the file handle
        io.close(file)
        print('Saved Table At ' .. path)
        return true
    end
end

function loadTable(filename)

    -- Path for the file to read
    local path = defaultLocation .. filename

    -- Open the file handle
    local file, errorString = io.open(path, "r")

    if not file then
        -- Error occurred; output the cause
        print("File error(load): " .. errorString)
        if string.find(filename, 'ranks') then
            saveTable({
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

            }, 'ranks' .. selectedSpawn.name .. '.json')
            return loadTable('ranks' .. selectedSpawn.name .. '.json')
        end
    else
        -- Read data from file
        local contents = file:read("*a")
        -- Decode JSON data into Lua table
        local t = json.decode(contents)
        -- Close the file handle
        io.close(file)
        -- Return table
        return t
    end
end


local ranks = loadTable('ranks.json')
local spawns = loadTable('spawns.json')
total_spawns = count_array(spawns)
selectedSpawn = spawns[math.random(1, total_spawns)]

local function send_global_message(text)
    print('Sending Global Message ' .. text)
    for _, playerId in ipairs(GetPlayers()) do
        local name = GetPlayerName(playerId)
        TriggerClientEvent('OnReceivedChatMessage', playerId, text)
    end
end

RegisterNetEvent("OnRequestedStart")
AddEventHandler('OnRequestedStart', function(startPoint)
    print("Received Start Event")
   
    timeBelowSpeed = 0
    spawnedPlayers = GetSpawnedPlayers()
    total_players = count_array(spawnedPlayers)
    print(("Selecting Teams (Total Players %i)"):format(total_players))
    gameStarted = true
    exports.vSync:RT()
    exports.vSync:RW()
    respawnPoint = vector3(0, 0, 0)
    total_spawns = count_array(spawns)
    selectedSpawn = spawns[math.random(1, total_spawns)]
    print('Spawning at ' .. selectedSpawn.name)
    ranks = loadTable('ranks' .. selectedSpawn.name .. '.json')
    -- randomly select the driver
  
    --defenderIdx = math.random(1, total_players)
    --while defenderidx == driverIdx do
    --    defenderIdx = math.random(1, total_players)
    --end
    local driverIdxs = {}
    local totalDrivers = 1
    if total_players >= 6 then
        totalDrivers = 2
    end

    while #driverIdxs < totalDrivers do
        local driverIdx = math.random(1, total_players)
        if not has_value(driverIdxs, driverIdx) then
            driverIdxs[#driverIdxs + 1] = driverIdx
        end
    end

    drivers = {}
    attackers = {}
    defenders = {}

    driverName = ''

    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if has_value(driverIdxs, i) then
            drivers[#drivers + 1] = name
        end
    end

    drivers = shuffle(drivers)
   
    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if has_value(driverIdxs, i) then
            driverName = name
            send_global_message(
                ('^1%s was selected as the driver!'):format(name))
            TriggerClientEvent('onHuntingPackStart', playerId, 'driver',
                               selectedSpawn.driverSpawnVec, selectedSpawn.driverSpawnRot, drivers, selectedSpawn, true)
            maxTimeBelowSpeed = 30
            if total_players == 1 then maxTimeBelowSpeed = 30 end
            TriggerClientEvent('OnUpdateMinSpeed', playerId, 45,
                               maxTimeBelowSpeed)
            send_global_message('^3' .. total_players ..
                                    ' players in game. Vehicle must be stopped for ' ..
                                    maxTimeBelowSpeed .. ' seconds')
            print('Spawning ' .. name .. ' as the driver')
        end
    end

    local defenderSpawn = vector3(selectedSpawn.defenderSpawnVec.x, selectedSpawn.defenderSpawnVec.y, selectedSpawn.defenderSpawnVec.z)
    local attackerSpawn = vector3(selectedSpawn.attackerSpawnVec.x, selectedSpawn.attackerSpawnVec.y, selectedSpawn.attackerSpawnVec.z)
    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if not has_value(driverIdxs, i) then
            if false then
                TriggerClientEvent('OnUpdateDefender', -1, name)
                defenderPlayerId = playerId
                TriggerClientEvent('onHuntingPackStart', playerId, 'defender',
                                    defenderSpawn +
                                       vector3(math.random(-10, 10),
                                               math.random(-10, 10), 0),
                                   selectedSpawn.driverSpawnRot, drivers, selectedSpawn, true)
            else
                TriggerClientEvent('onHuntingPackStart', playerId, 'attacker',
                                   attackerSpawn +
                                       vector3(math.random(-10, 10),
                                               math.random(-10, 10), 0),
                                   selectedSpawn.attackerSpawnRot, drivers, selectedSpawn, true)
                print('Spawning ' .. name .. ' as an attacker')
            end
        end
    end
    print("Finished Selecting Teams!... Preparing spawning")
end)

RegisterNetEvent("OnNotifyBelowSpeed")
AddEventHandler('OnNotifyBelowSpeed', function(name)
    isBelowSpeed = true
    -- send_global_message(name .. " has dropped below the speed!")
end)

RegisterNetEvent("OnNotifyAboveSpeed")
AddEventHandler('OnNotifyAboveSpeed', function(name, timeBelowSpeed)
    isBelowSpeed = false
    timeRemaining = maxTimeBelowSpeed - timeBelowSpeed
    if timeRemaining < 1.0 and timeRemaining > 0.0 then
        send_global_message(
            "^2" .. name .. " has has gone above the speed! .. " ..
                timeRemaining .. ' seconds remaining!')
    end
end)

RegisterNetEvent("OnNewRespawnPoint")
AddEventHandler('OnNewRespawnPoint',
                function(newRespawnLocation, newRespawnRotation)
    respawnPoint = newRespawnLocation
    respawnRot = newRespawnRotation
    print('Received new spawn location ' .. respawnPoint)
end)

RegisterNetEvent("OnNotifyDriverBlipVisible")
AddEventHandler('OnNotifyDriverBlipVisible', function(driverName, isVisible)

    TriggerClientEvent('OnNotifyDriverBlipVisible', -1, driverName, isVisible)

end)

RegisterNetEvent("OnMarkedAFK")
AddEventHandler('OnMarkedAFK', function(isAfk)
    if isAfk then
        send_global_message(GetPlayerName(source) ..
                                " is now marked as Away From Keyboard")
        afkIdx = -1
        for Idx, playerId in ipairs(spawnedPlayers) do
            if playerId == source then afkIdx = Idx end
        end
        if afkIdx ~= -1 then table.remove(spawnedPlayers, afkIdx) end
    else
        send_global_message(GetPlayerName(source) .. " has rejoined the chaos!")
        spawnedPlayers[#spawnedPlayers + 1] = source
    end
end)


RegisterNetEvent("OnUpdateEndPoint")
AddEventHandler('OnUpdateEndPoint', function(selectedEndPoint)
    TriggerClientEvent('OnUpdateEndPoint', -1, selectedEndPoint)
end)

RegisterNetEvent("OnUpdateLifeTimers")
AddEventHandler('OnUpdateLifeTimers', function(newTotalLife)
    totalLife = newTotalLife
    TriggerClientEvent('OnUpdateLifeTimers', -1, totalLife)
end)

RegisterNetEvent("OnUploadSpawnPoint")
AddEventHandler('OnUploadSpawnPoint', function(spawnData)
    print('Recevied new spawn data ->' .. spawnData.name)
    if spawns == nil then
        spawns = {}
    end
    table.insert(spawns, spawnData)
    saveTable(spawns, 'spawns.json')
end)

RegisterNetEvent("OnRequestJoinInProgress")
AddEventHandler('OnRequestJoinInProgress', function(playerId)
    if playerId ~= -1 then
        outDriverIdx = -1
        for Idx, v in ipairs(drivers) do
            if v == GetPlayerName(playerId) then
            outDriverIdx = Idx
            end
        end

        if outDriverIdx == -1 then
            local defenderSpawn = vector3(selectedSpawn.defenderSpawnVec.x, selectedSpawn.defenderSpawnVec.y, selectedSpawn.defenderSpawnVec.z)
            local attackerSpawn = vector3(selectedSpawn.attackerSpawnVec.x, selectedSpawn.attackerSpawnVec.y, selectedSpawn.attackerSpawnVec.z)
            if respawnPoint ~= vector3(0, 0, 0) then
                if  has_value(defenders, playerId) then
                    print('Starting ' .. GetPlayerName(playerId) .. ' in progress as defender')
                    TriggerClientEvent('onHuntingPackStart', playerId, 'defender',
                                    respawnPoint +
                                        vector3(math.random(-10, 10),
                                                math.random(-10, 10), 0),
                                    respawnRot, drivers, selectedSpawn, gameStarted)
                else
                    print('Starting ' .. GetPlayerName(playerId) .. ' in progress as attacker')
                    TriggerClientEvent('onHuntingPackStart', playerId, 'attacker',
                                    respawnPoint +
                                        vector3(math.random(-10, 10),
                                                math.random(-10, 10), 0),
                                    respawnRot, drivers, selectedSpawn, gameStarted)
                end
            else
                if has_value(defenders, playerId) then
                    print('Starting ' .. GetPlayerName(playerId) .. ' in progress as defender')
                    TriggerClientEvent('onHuntingPackStart', playerId, 'defender',
                                        defenderSpawn +
                                        vector3(math.random(-10, 10),
                                                math.random(-10, 10), 0),
                                    respawnRot, drivers, selectedSpawn, gameStarted)
                else
                    print('Starting ' .. GetPlayerName(playerId) .. ' in progress as attacker')
                    TriggerClientEvent('onHuntingPackStart', playerId, 'attacker',
                        attackerSpawn +
                                        vector3(math.random(-10, 10),
                                                math.random(-10, 10), 0),
                                    respawnRot, drivers, selectedSpawn, gameStarted)
                end
            end
        end
    end
end)

function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

RegisterNetEvent('OnNotifyHighScore')
AddEventHandler('OnNotifyHighScore', function(Name, LifeTime)

    if not gameStarted then
        return
    end

    defenders[#defenders + 1] = source

    outDriverIdx = -1
    for Idx, v in ipairs(drivers) do
        if v == GetPlayerName(source) then
        outDriverIdx = Idx
        end
    end

    if outDriverIdx ~= -1 then
        table.remove(drivers, outDriverIdx)
    end

    for d in ipairs(drivers) do
        print('Driver: ' .. d .. ' remaining')
    end

    TriggerClientEvent('OnUpdateDrivers', -1, drivers)
    if #drivers == 0 then
        gameStarted = false
        timerCountdown = 15
        for _, playerId in ipairs(GetSpawnedPlayers()) do
            TriggerClientEvent('OnGameEnded', playerId)
        end      
    end

    newhighScoreIdx = -1

    send_global_message('^6' .. Name .. ' has successfully extracted! Drivers Remaining: ' .. #drivers)
   

    local isOnLeaderboard = false
    local hasHigherScoreOnLeaderboard = false
    local previousRankIdx = -1
    oldRanks = deepcopy(ranks)
    total_players = count_array(GetSpawnedPlayers())
    for i, player in pairs(ranks) do
        if LifeTime * (total_players * 1.68 - 1) < player.points *
            (player.players * 1.68 - 1) and Name == player.name then
            send_global_message(Name ..
                                    ' score was lower than their previous score on the leaderboard. Score will not be counted.')
            hasHigherScoreOnLeaderboard = true
        end
        if Name == player.name then
            table.remove(ranks, i)
            isOnLeaderboard = true
            previousRankIdx = i
            break
        end
    end

    local replacedPlayerScore = nil

    if hasHigherScoreOnLeaderboard == false then
        for i, player in pairs(ranks) do
            if LifeTime * (total_players * 1.68 - 1) > player.points *
                (player.players * 1.68 - 1) then
                local rank = {name = Name, points = LifeTime, players = total_players}
                print(rank.points)
                table.insert(ranks, i, rank)
                newhighScoreIdx = i
                send_global_message(Name ..
                                        ' just received a new high score! Rank: ' ..
                                        i .. ' Life: ' .. LifeTime)
                break
            end
        end

        for i, player in pairs(ranks) do
            if i > newhighScoreIdx and newhighScoreIdx ~= -1 and Name == ranks[i].name then
                table.remove(ranks, i)
                i = i - 1
            end
        end

        saveTable(ranks, 'ranks' .. selectedSpawn.name .. '.json')
    end

end)

RegisterNetEvent('OnNotifyDriverBlipArea')
AddEventHandler('OnNotifyDriverBlipArea', function(enabled, posX, posY, posZ)
    TriggerClientEvent('OnNotifyDriverBlipArea', -1, enabled, posX, posY, posZ)
end)

RegisterNetEvent('OnNotifyDriversVehicleSpawned')
AddEventHandler('OnNotifyDriversVehicleSpawned', function(spawnPos, vehicleNetId, seatPosition)

    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if has_value(drivers, name) and name ~= drivers[1] then
            TriggerClientEvent('OnNotifyDriversVehicleSpawned', playerId, spawnPos, vehicleNetId, seatPosition)
        end
    end

    
end)

RegisterNetEvent('OnNotifyKilled')
AddEventHandler('OnNotifyKilled', function(Name, LifeTime)

    if not gameStarted then
       return
    end    

   
    defenders[#defenders + 1] = source
    outDriverIdx = -1
    for Idx, v in ipairs(drivers) do
        if v == GetPlayerName(source) then
        outDriverIdx = Idx
        end
    end

    if outDriverIdx ~= -1 then
        table.remove(drivers, outDriverIdx)
    end

   

    send_global_message(GetPlayerName(source) .. ' has been killed! Total Life: ' .. LifeTime ..
    ' Seconds\nDrivers Remaining: ' .. #drivers)

    for i, d in ipairs(drivers) do
        print('Driver: ' .. d .. ' remaining')
    end

    TriggerClientEvent('OnUpdateDrivers', -1, drivers)

    if #drivers == 0 then
        gameStarted = false
        timerCountdown = 15
        newhighScoreIdx = -1
        for _, playerId in ipairs(GetSpawnedPlayers()) do
            TriggerClientEvent('OnGameEnded', playerId)
        end
    end

end)

local function save_score(name, score) file = io.open('scores.txt') end

Citizen.CreateThread(function()
    while true do
        total_players = count_array(GetSpawnedPlayers())
        TriggerClientEvent('OnUpdateTotalPlayers', -1, total_players)
        if total_players < 1 and gameStarted then
            timerCountdown = 30
            gameStarted = false
        end
        if total_players >= 2 and not gameStarted then
            if timerCountdown > 10 then
                timerCountdown = timerCountdown - 5
            else
                timerCountdown = timerCountdown - 1
            end
            send_global_message('^1' .. timerCountdown ..
                                    " seconds until game starts!")
            if timerCountdown < 0 then
                gameStarted = true
                TriggerEvent('OnRequestedStart')
                
            end
        end
        if timerCountdown > 10 then
            Citizen.Wait(5000)
        else
            Citizen.Wait(1000)
        end
    end

end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if selectedSpawn ~= nil then
            ranks =
                loadTable('ranks' .. selectedSpawn.name .. '.json')
            for _, playerId in ipairs(GetSpawnedPlayers()) do
                TriggerClientEvent('OnClearRanks', playerId)
                for _, player in pairs(ranks) do
                    TriggerClientEvent('OnUpdateRanks', playerId, player.name,
                                    player.points, player.players, _)
                end
            end
        end
    end
end)
