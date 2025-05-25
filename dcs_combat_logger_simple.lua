--[[
DCS World Air-to-Air Combat Event Logger (Simplified & Enhanced - FIXED)
========================================================================

A comprehensive combat event logger for DCS World missions that tracks
all relevant air-to-air combat events without external dependencies.
This version is fully compatible with DCS scripting restrictions.

INSTALLATION:
1. Open your mission in DCS Mission Editor
2. Create a new trigger:
   - Event: Mission Start
   - Condition: Time More (1 second)
   - Action: Do Script (paste this entire script)
3. Save and run your mission

Log data is output to: DCS.log file (all entries prefixed with "COMBAT_LOG:")

Version: 2.1 (Fully Fixed)
--]]

-- Configuration
local CONFIG = {
    LOG_PREFIX = "dcs_combat_",
    LOG_INTERVAL = 60,      -- seconds between status reports
    ENABLE_DEBUG = false,   -- enable debug messages
    TRACK_GROUND_UNITS = false, -- track ground unit interactions
}

-- Global state
local CombatLogger = {
    startTime = 0,
    logBuffer = {},
    events = {},
    pilots = {},
    formations = {},
    weapons = {},
    missionData = {},
    initialized = false
}

-- Utility: Safe string conversion
local function safeString(value)
    if value == nil then return "Unknown" end
    return tostring(value)
end

-- Utility: Safe number conversion
local function safeNumber(value)
    if value == nil then return 0 end
    local num = tonumber(value)
    return num or 0
end

-- Utility: Count table entries (replacement for table.getn)
local function countTable(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Utility: Safe math operations (replacement for math library)
local function safeMath(operation, a, b)
    local numA = safeNumber(a)
    local numB = safeNumber(b)
    
    if operation == "divide" then
        if numB == 0 then return 0 end
        return numA / numB
    elseif operation == "multiply" then
        return numA * numB
    elseif operation == "add" then
        return numA + numB
    elseif operation == "subtract" then
        return numA - numB
    elseif operation == "floor" then
        -- Safe floor operation without math library
        if numA >= 0 then
            return numA - (numA % 1)
        else
            return numA - (numA % 1) - 1
        end
    end
    return 0
end

-- Utility: Get timestamp
local function getTimestamp()
    return timer.getTime() - CombatLogger.startTime
end

-- Utility: Write to log
local function log(level, message)
    local timestamp = getTimestamp()
    local entry = string.format("[%08.2f] [%-5s] %s", timestamp, level, safeString(message))
    
    -- Store in buffer for later output
    table.insert(CombatLogger.logBuffer, entry)
    
    -- Always output to DCS log for real-time monitoring
    env.info("COMBAT_LOG: " .. entry)
end

-- Initialize logger
local function initLogger()
    -- Initialize using DCS's built-in functions only
    CombatLogger.startTime = timer.getTime()
    
    -- Store mission data safely
    CombatLogger.missionData = {
        theatre = safeString(env.mission and env.mission.theatre),
        startTime = string.format("%.0f", CombatLogger.startTime),
        weather = "Clear", -- Could be expanded
    }
    
    -- Write header to log buffer
    table.insert(CombatLogger.logBuffer, "=== DCS COMBAT EVENT LOG ===")
    table.insert(CombatLogger.logBuffer, "Version: 2.1 (Fully Fixed)")
    table.insert(CombatLogger.logBuffer, "Mission: " .. CombatLogger.missionData.theatre)
    table.insert(CombatLogger.logBuffer, "Start Time: " .. CombatLogger.missionData.startTime)
    table.insert(CombatLogger.logBuffer, "========================================")
    table.insert(CombatLogger.logBuffer, "")
    
    log("INFO", "Combat logger initialized successfully")
    CombatLogger.initialized = true
    
    -- Show user message
    trigger.action.outText("Combat Event Logger v2.1 activated - check DCS.log for events", 10)
    
    return true
end

-- Get comprehensive unit information with full error protection
local function getUnitData(unit)
    if not unit then return nil end
    
    -- Safely get unit data with multiple layers of protection
    local ok, data = pcall(function()
        local unitData = {
            name = "Unknown",
            type = "Unknown",
            coalition = 0,
            country = 0,
            pilot = "Unknown",
            group = "Unknown",
            groupSize = 1,
            position = {x = 0, y = 0, z = 0},
            coalitionName = "Unknown",
            category = 0,
            isAircraft = false,
            isHelicopter = false
        }
        
        -- Get basic unit info with safe method calls
        if unit.getName then
            unitData.name = safeString(unit:getName())
        end
        
        if unit.getTypeName then
            unitData.type = safeString(unit:getTypeName())
        end
        
        if unit.getCoalition then
            unitData.coalition = safeNumber(unit:getCoalition())
        end
        
        if unit.getCountry then
            unitData.country = safeNumber(unit:getCountry())
        end
        
        -- Get pilot name if available
        if unit.getPlayerName then
            local playerName = unit:getPlayerName()
            if playerName then
                unitData.pilot = safeString(playerName)
            else
                unitData.pilot = unitData.name
            end
        else
            unitData.pilot = unitData.name
        end
        
        -- Get group info safely
        if unit.getGroup then
            local group = unit:getGroup()
            if group then
                if group.getName then
                    unitData.group = safeString(group:getName())
                end
                if group.getSize then
                    unitData.groupSize = safeNumber(group:getSize())
                end
            end
        end
        
        -- Get position safely
        if unit.getPoint then
            local pos = unit:getPoint()
            if pos then
                unitData.position = {
                    x = safeMath("floor", pos.x),
                    y = safeMath("floor", pos.y),
                    z = safeMath("floor", pos.z)
                }
            end
        end
        
        -- Coalition name mapping
        if unitData.coalition == 0 then
            unitData.coalitionName = "Neutral"
        elseif unitData.coalition == 1 then
            unitData.coalitionName = "Red"
        elseif unitData.coalition == 2 then
            unitData.coalitionName = "Blue"
        else
            unitData.coalitionName = "Unknown"
        end
        
        -- Check if it's an aircraft safely
        if unit.getDesc then
            local desc = unit:getDesc()
            if desc and desc.category then
                unitData.category = safeNumber(desc.category)
                unitData.isAircraft = (unitData.category == 0 or unitData.category == 1)
                unitData.isHelicopter = (unitData.category == 1)
            end
        end
        
        return unitData
    end)
    
    if not ok then
        log("ERROR", "Failed to get unit data: " .. safeString(data))
        return nil
    end
    
    return data
end

-- Get weapon information with full error protection
local function getWeaponData(weapon)
    if not weapon then return {type = "Unknown", category = 0} end
    
    local ok, data = pcall(function()
        local weaponData = {
            type = "Unknown",
            category = 0,
            launcher = "Unknown",
            targetName = "Unknown"
        }
        
        if weapon.getTypeName then
            weaponData.type = safeString(weapon:getTypeName())
        end
        
        if weapon.getCategory then
            weaponData.category = safeNumber(weapon:getCategory())
        end
        
        -- Try to get launcher info safely
        if weapon.getLauncher then
            local launcher = weapon:getLauncher()
            if launcher and launcher.getName then
                weaponData.launcher = safeString(launcher:getName())
            end
        end
        
        -- Try to get target safely
        if weapon.getTarget then
            local target = weapon:getTarget()
            if target and target.getName then
                weaponData.targetName = safeString(target:getName())
            end
        end
        
        return weaponData
    end)
    
    return ok and data or {type = "Unknown", category = 0}
end

-- Update pilot statistics with safe operations
local function updatePilotStats(unitData, eventType, additionalData)
    if not unitData or not unitData.name then return end
    
    local pilotId = unitData.pilot or unitData.name
    additionalData = additionalData or {}
    
    -- Initialize pilot entry
    if not CombatLogger.pilots[pilotId] then
        CombatLogger.pilots[pilotId] = {
            name = pilotId,
            unit = unitData.name,
            aircraft = unitData.type,
            coalition = unitData.coalitionName,
            group = unitData.group,
            firstSeen = getTimestamp(),
            lastSeen = getTimestamp(),
            -- Combat stats
            shots = 0,
            hits = 0,
            kills = 0,
            deaths = 0,
            ejections = 0,
            crashes = 0,
            -- Detailed weapon stats
            weaponsFired = {},
            targetsEngaged = {},
            targetsKilled = {},
            -- Flight stats
            takeoffs = 0,
            landings = 0,
            flightTime = 0,
        }
    end
    
    local pilot = CombatLogger.pilots[pilotId]
    pilot.lastSeen = getTimestamp()
    
    -- Update stats based on event
    if eventType == "shot" and additionalData.weapon then
        pilot.shots = pilot.shots + 1
        local weaponType = safeString(additionalData.weapon.type)
        pilot.weaponsFired[weaponType] = (pilot.weaponsFired[weaponType] or 0) + 1
        
        if additionalData.weapon.targetName and additionalData.weapon.targetName ~= "Unknown" then
            pilot.targetsEngaged[additionalData.weapon.targetName] = true
        end
    elseif eventType == "hit" then
        pilot.hits = pilot.hits + 1
    elseif eventType == "kill" and additionalData.victim then
        pilot.kills = pilot.kills + 1
        local victimName = safeString(additionalData.victim)
        pilot.targetsKilled[victimName] = (pilot.targetsKilled[victimName] or 0) + 1
    elseif eventType == "death" then
        pilot.deaths = pilot.deaths + 1
        pilot.flightTime = pilot.flightTime + (getTimestamp() - pilot.firstSeen)
    elseif eventType == "ejection" then
        pilot.ejections = pilot.ejections + 1
    elseif eventType == "crash" then
        pilot.crashes = pilot.crashes + 1
    elseif eventType == "takeoff" then
        pilot.takeoffs = pilot.takeoffs + 1
        pilot.firstSeen = getTimestamp() -- Reset flight time counter
    elseif eventType == "landing" then
        pilot.landings = pilot.landings + 1
        pilot.flightTime = pilot.flightTime + (getTimestamp() - pilot.firstSeen)
    end
end

-- Update formation statistics
local function updateFormationStats(groupName, eventType)
    if not groupName or groupName == "Unknown" then return end
    
    if not CombatLogger.formations[groupName] then
        CombatLogger.formations[groupName] = {
            name = groupName,
            shots = 0,
            hits = 0,
            kills = 0,
            losses = 0,
            members = {},
            firstContact = getTimestamp()
        }
    end
    
    local formation = CombatLogger.formations[groupName]
    
    if eventType == "shot" then
        formation.shots = formation.shots + 1
    elseif eventType == "hit" then
        formation.hits = formation.hits + 1
    elseif eventType == "kill" then
        formation.kills = formation.kills + 1
    elseif eventType == "loss" then
        formation.losses = formation.losses + 1
    end
end

-- Add member to formation
local function addFormationMember(groupName, pilotName)
    if groupName and pilotName and CombatLogger.formations[groupName] then
        CombatLogger.formations[groupName].members[pilotName] = true
    end
end

-- Log event with safe string formatting
local function logEvent(eventType, data)
    local event = {
        id = #CombatLogger.events + 1,
        time = getTimestamp(),
        type = eventType,
        data = data
    }
    
    table.insert(CombatLogger.events, event)
    
    -- Create log message with safe string operations
    local message = safeString(eventType) .. ": "
    
    if eventType == "SHOT" and data.shooter and data.weapon then
        message = message .. string.format("%s (%s) fired %s",
            safeString(data.shooter.name), safeString(data.shooter.type), safeString(data.weapon.type))
        if data.weapon.targetName and data.weapon.targetName ~= "Unknown" then
            message = message .. " at " .. safeString(data.weapon.targetName)
        end
    elseif eventType == "HIT" and data.shooter and data.target and data.weapon then
        message = message .. string.format("%s hit %s with %s",
            safeString(data.shooter.name), safeString(data.target.name), safeString(data.weapon.type))
    elseif eventType == "KILL" and data.killer and data.victim and data.weapon then
        message = message .. string.format("%s killed %s with %s",
            safeString(data.killer.name), safeString(data.victim.name), safeString(data.weapon.type))
    elseif eventType == "DEATH" and data.unit then
        message = message .. string.format("%s (%s) was destroyed",
            safeString(data.unit.name), safeString(data.unit.type))
    elseif eventType == "CRASH" and data.unit then
        message = message .. string.format("%s (%s) crashed",
            safeString(data.unit.name), safeString(data.unit.type))
    elseif eventType == "EJECT" and data.unit then
        message = message .. string.format("Pilot ejected from %s (%s)",
            safeString(data.unit.name), safeString(data.unit.type))
    elseif eventType == "BIRTH" and data.unit then
        message = message .. string.format("%s (%s) spawned",
            safeString(data.unit.name), safeString(data.unit.type))
    elseif eventType == "TAKEOFF" and data.unit then
        message = message .. string.format("%s (%s) took off from %s",
            safeString(data.unit.name), safeString(data.unit.type), safeString(data.airbase or "ground"))
    elseif eventType == "LAND" and data.unit then
        message = message .. string.format("%s (%s) landed at %s",
            safeString(data.unit.name), safeString(data.unit.type), safeString(data.airbase or "ground"))
    elseif eventType == "ENGINE_START" and data.unit then
        message = message .. string.format("%s started engines",
            safeString(data.unit.name))
    elseif eventType == "ENGINE_STOP" and data.unit then
        message = message .. string.format("%s stopped engines",
            safeString(data.unit.name))
    else
        message = message .. "Unknown event"
    end
    
    log("EVENT", message)
end

-- Event handlers with comprehensive error protection
local function handleEvent(event)
    if not CombatLogger.initialized or not event then return end
    
    -- Safely get event data
    local eventId = event.id
    local initiator = event.initiator
    local target = event.target
    local weapon = event.weapon
    local place = event.place
    
    -- Wrap all event handling in pcall for safety
    local ok, err = pcall(function()
        -- Birth event (unit spawned)
        if eventId == world.event.S_EVENT_BIRTH then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                logEvent("BIRTH", {unit = unitData})
                updatePilotStats(unitData, "birth")
                addFormationMember(unitData.group, unitData.pilot or unitData.name)
            end
            
        -- Shot event
        elseif eventId == world.event.S_EVENT_SHOT then
            local shooterData = getUnitData(initiator)
            local weaponData = getWeaponData(weapon)
            
            if shooterData and weaponData then
                logEvent("SHOT", {
                    shooter = shooterData,
                    weapon = weaponData
                })
                updatePilotStats(shooterData, "shot", {weapon = weaponData})
                updateFormationStats(shooterData.group, "shot")
                
                -- Track weapon safely
                if weapon and weapon.getName then
                    local weaponId = weapon:getName()
                    if weaponId then
                        CombatLogger.weapons[weaponId] = {
                            type = weaponData.type,
                            launcher = shooterData.name,
                            launchTime = getTimestamp()
                        }
                    end
                end
            end
            
        -- Hit event
        elseif eventId == world.event.S_EVENT_HIT then
            local shooterData = getUnitData(initiator)
            local targetData = getUnitData(target)
            local weaponData = getWeaponData(weapon)
            
            if shooterData and targetData and weaponData then
                logEvent("HIT", {
                    shooter = shooterData,
                    target = targetData,
                    weapon = weaponData
                })
                updatePilotStats(shooterData, "hit")
                updateFormationStats(shooterData.group, "hit")
            end
            
        -- Kill event (unit destroyed by another unit)
        elseif eventId == world.event.S_EVENT_KILL then
            local killerData = getUnitData(initiator)
            local victimData = getUnitData(target)
            local weaponData = getWeaponData(weapon)
            
            if killerData and victimData then
                logEvent("KILL", {
                    killer = killerData,
                    victim = victimData,
                    weapon = weaponData or {type = "Unknown"}
                })
                updatePilotStats(killerData, "kill", {victim = victimData.name})
                updatePilotStats(victimData, "death")
                updateFormationStats(killerData.group, "kill")
                updateFormationStats(victimData.group, "loss")
            end
            
        -- Dead event (unit destroyed)
        elseif eventId == world.event.S_EVENT_DEAD then
            local unitData = getUnitData(initiator)
            if unitData then
                logEvent("DEATH", {unit = unitData})
                updatePilotStats(unitData, "death")
                updateFormationStats(unitData.group, "loss")
            end
            
        -- Crash event
        elseif eventId == world.event.S_EVENT_CRASH then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                logEvent("CRASH", {unit = unitData})
                updatePilotStats(unitData, "crash")
            end
            
        -- Ejection event
        elseif eventId == world.event.S_EVENT_EJECTION then
            local unitData = getUnitData(initiator)
            if unitData then
                logEvent("EJECT", {unit = unitData})
                updatePilotStats(unitData, "ejection")
            end
            
        -- Takeoff event
        elseif eventId == world.event.S_EVENT_TAKEOFF then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                local airbaseName = nil
                if place and place.getName then
                    airbaseName = place:getName()
                end
                logEvent("TAKEOFF", {
                    unit = unitData,
                    airbase = airbaseName
                })
                updatePilotStats(unitData, "takeoff")
            end
            
        -- Landing event
        elseif eventId == world.event.S_EVENT_LAND then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                local airbaseName = nil
                if place and place.getName then
                    airbaseName = place:getName()
                end
                logEvent("LAND", {
                    unit = unitData,
                    airbase = airbaseName
                })
                updatePilotStats(unitData, "landing")
            end
            
        -- Engine startup event
        elseif eventId == world.event.S_EVENT_ENGINE_STARTUP then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                logEvent("ENGINE_START", {unit = unitData})
            end
            
        -- Engine shutdown event
        elseif eventId == world.event.S_EVENT_ENGINE_SHUTDOWN then
            local unitData = getUnitData(initiator)
            if unitData and unitData.isAircraft then
                logEvent("ENGINE_STOP", {unit = unitData})
            end
            
        -- Refueling events
        elseif eventId == world.event.S_EVENT_REFUELING then
            local unitData = getUnitData(initiator)
            if unitData then
                log("EVENT", string.format("REFUEL: %s started refueling", unitData.name))
            end
            
        elseif eventId == world.event.S_EVENT_REFUELING_STOP then
            local unitData = getUnitData(initiator)
            if unitData then
                log("EVENT", string.format("REFUEL: %s stopped refueling", unitData.name))
            end
            
        -- Mission events
        elseif eventId == world.event.S_EVENT_MISSION_START then
            log("INFO", "Mission started")
            
        elseif eventId == world.event.S_EVENT_MISSION_END then
            log("INFO", "Mission ending...")
            finalizeLogs()
        end
    end)
    
    if not ok then
        log("ERROR", "Event handling error: " .. safeString(err))
    end
end

-- Status report with safe operations
local function reportStatus()
    if not CombatLogger.initialized then return end
    
    local missionTime = safeMath("divide", getTimestamp(), 60)
    local pilotCount = countTable(CombatLogger.pilots)
    local formationCount = countTable(CombatLogger.formations)
    local totalKills = 0
    local totalShots = 0
    
    for _, pilot in pairs(CombatLogger.pilots) do
        totalKills = totalKills + safeNumber(pilot.kills)
        totalShots = totalShots + safeNumber(pilot.shots)
    end
    
    log("INFO", string.format("STATUS: Time=%.1fm Events=%d Pilots=%d Formations=%d Kills=%d Shots=%d",
        missionTime, #CombatLogger.events, pilotCount, formationCount, totalKills, totalShots))
    
    -- Schedule next report with error protection
    local ok, err = pcall(function()
        timer.scheduleFunction(reportStatus, nil, timer.getTime() + CONFIG.LOG_INTERVAL)
    end)
    
    if not ok then
        log("ERROR", "Failed to schedule status report: " .. safeString(err))
    end
end

-- Finalize logs with safe operations
function finalizeLogs()
    log("INFO", "Finalizing combat log...")
    
    -- Count pilots and formations safely
    local pilotCount = countTable(CombatLogger.pilots)
    local formationCount = countTable(CombatLogger.formations)
    
    -- Mission summary
    table.insert(CombatLogger.logBuffer, "")
    table.insert(CombatLogger.logBuffer, "========================================")
    table.insert(CombatLogger.logBuffer, "=== MISSION SUMMARY ===")
    table.insert(CombatLogger.logBuffer, "Total Events: " .. #CombatLogger.events)
    table.insert(CombatLogger.logBuffer, "Mission Duration: " .. string.format("%.1f minutes", safeMath("divide", getTimestamp(), 60)))
    table.insert(CombatLogger.logBuffer, "Total Pilots: " .. pilotCount)
    table.insert(CombatLogger.logBuffer, "Total Formations: " .. formationCount)
    
    -- Pilot statistics
    table.insert(CombatLogger.logBuffer, "")
    table.insert(CombatLogger.logBuffer, "=== PILOT STATISTICS ===")
    for pilotId, pilot in pairs(CombatLogger.pilots) do
        local shots = safeNumber(pilot.shots)
        local hits = safeNumber(pilot.hits)
        local kills = safeNumber(pilot.kills)
        local deaths = safeNumber(pilot.deaths)
        
        local efficiency = safeMath("multiply", safeMath("divide", hits, shots), 100)
        local kd = deaths > 0 and safeMath("divide", kills, deaths) or kills
        
        table.insert(CombatLogger.logBuffer, string.format(
            "%-20s (%s, %s, %s)",
            safeString(pilot.name), safeString(pilot.aircraft), safeString(pilot.group), safeString(pilot.coalition)
        ))
        table.insert(CombatLogger.logBuffer, string.format(
            "  Combat: Kills=%d Deaths=%d KD=%.2f Shots=%d Hits=%d Eff=%.1f%%",
            kills, deaths, kd, shots, hits, efficiency
        ))
        table.insert(CombatLogger.logBuffer, string.format(
            "  Flight: Takeoffs=%d Landings=%d Ejections=%d Crashes=%d Time=%.1fm",
            safeNumber(pilot.takeoffs), safeNumber(pilot.landings), 
            safeNumber(pilot.ejections), safeNumber(pilot.crashes), 
            safeMath("divide", safeNumber(pilot.flightTime), 60)
        ))
        
        -- Weapon usage
        if next(pilot.weaponsFired) then
            local weaponStr = "  Weapons: "
            for weapon, count in pairs(pilot.weaponsFired) do
                weaponStr = weaponStr .. safeString(weapon) .. "=" .. safeNumber(count) .. " "
            end
            table.insert(CombatLogger.logBuffer, weaponStr)
        end
    end
    
    -- Formation statistics
    table.insert(CombatLogger.logBuffer, "")
    table.insert(CombatLogger.logBuffer, "=== FORMATION STATISTICS ===")
    for formName, form in pairs(CombatLogger.formations) do
        local memberCount = countTable(form.members)
        
        table.insert(CombatLogger.logBuffer, string.format(
            "%-20s: Members=%d Shots=%d Hits=%d Kills=%d Losses=%d",
            safeString(form.name), memberCount, safeNumber(form.shots), 
            safeNumber(form.hits), safeNumber(form.kills), safeNumber(form.losses)
        ))
    end
    
    -- Combat effectiveness summary
    table.insert(CombatLogger.logBuffer, "")
    table.insert(CombatLogger.logBuffer, "=== COMBAT EFFECTIVENESS ===")
    local redKills, redLosses, redShots = 0, 0, 0
    local blueKills, blueLosses, blueShots = 0, 0, 0
    
    for _, pilot in pairs(CombatLogger.pilots) do
        local kills = safeNumber(pilot.kills)
        local deaths = safeNumber(pilot.deaths)
        local shots = safeNumber(pilot.shots)
        
        if pilot.coalition == "Red" then
            redKills = redKills + kills
            redLosses = redLosses + deaths
            redShots = redShots + shots
        elseif pilot.coalition == "Blue" then
            blueKills = blueKills + kills
            blueLosses = blueLosses + deaths
            blueShots = blueShots + shots
        end
    end
    
    table.insert(CombatLogger.logBuffer, string.format("Red Coalition:  Kills=%d Losses=%d Shots=%d", redKills, redLosses, redShots))
    table.insert(CombatLogger.logBuffer, string.format("Blue Coalition: Kills=%d Losses=%d Shots=%d", blueKills, blueLosses, blueShots))
    
    -- Output complete log to DCS log
    table.insert(CombatLogger.logBuffer, "")
    table.insert(CombatLogger.logBuffer, "=== END OF LOG ===")
    
    -- Output entire log buffer to DCS log
    for _, line in ipairs(CombatLogger.logBuffer) do
        env.info("COMBAT_LOG: " .. safeString(line))
    end
    
    env.info("Combat log finalized - check DCS.log for complete mission summary")
    trigger.action.outText("Combat log complete - check DCS.log for full mission summary", 15)
end

-- Initialize with error protection
local function initialize()
    local ok, err = pcall(function()
        if not initLogger() then
            return false
        end
        
        -- Create event handler
        local eventHandler = {}
        eventHandler.onEvent = handleEvent
        world.addEventHandler(eventHandler)
        
        -- Schedule status reports
        timer.scheduleFunction(reportStatus, nil, timer.getTime() + CONFIG.LOG_INTERVAL)
        
        return true
    end)
    
    if not ok then
        env.error("Failed to initialize DCS Combat Logger: " .. safeString(err))
        return false
    end
    
    return true
end

-- Start the logger with final error protection
local initOk, initErr = pcall(function()
    if initialize() then
        env.info("DCS Combat Logger v2.1 (Fully Fixed) initialized successfully")
        return true
    else
        env.error("Failed to initialize DCS Combat Logger")
        return false
    end
end)

if not initOk then
    env.error("Critical error in DCS Combat Logger: " .. safeString(initErr))
end 