--[[
DCS World Air-to-Air Combat Event Logger (Simplified & Enhanced)
===============================================================

A comprehensive combat event logger for DCS World missions that tracks
all relevant air-to-air combat events without external dependencies.

INSTALLATION:
1. Open your mission in DCS Mission Editor
2. Create a new trigger:
   - Event: Mission Start
   - Condition: Time More (1 second)
   - Action: Do Script (paste this entire script)
3. Save and run your mission

Log files are saved to: Current working directory (usually mission folder)

Version: 2.0 (Simplified & Enhanced)
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
    logFile = nil,
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

-- Utility: Get timestamp
local function getTimestamp()
    return timer.getTime() - CombatLogger.startTime
end

-- Utility: Write to log
local function log(level, message)
    if not CombatLogger.logFile then return end
    
    local timestamp = getTimestamp()
    local entry = string.format("[%08.2f] [%-5s] %s\n", timestamp, level, message)
    
    CombatLogger.logFile:write(entry)
    
    if level == "ERROR" or (CONFIG.ENABLE_DEBUG and level == "DEBUG") then
        env.info("COMBAT_LOG: " .. entry)
    end
end

-- Initialize logger
local function initLogger()
    -- Create log file using DCS's built-in functions
    local timestamp = string.format("%.0f", timer.getTime())
    local filename = CONFIG.LOG_PREFIX .. timestamp .. ".log"
    
    CombatLogger.logFile = io.open(filename, "w")
    if not CombatLogger.logFile then
        env.error("Failed to create log file: " .. filename)
        return false
    end
    
    -- Write header
    CombatLogger.startTime = timer.getTime()
    CombatLogger.logFile:write("=== DCS COMBAT EVENT LOG ===\n")
    CombatLogger.logFile:write("Version: 2.0 (Simplified & Enhanced)\n")
    CombatLogger.logFile:write("Mission: " .. safeString(env.mission.theatre) .. "\n")
    CombatLogger.logFile:write("Start Time: " .. string.format("%.0f", CombatLogger.startTime) .. "\n")
    CombatLogger.logFile:write("Log File: " .. filename .. "\n")
    CombatLogger.logFile:write("========================================\n\n")
    
    -- Store mission data
    CombatLogger.missionData = {
        theatre = env.mission.theatre,
        startTime = string.format("%.0f", CombatLogger.startTime),
        weather = "Clear", -- Could be expanded
    }
    
    log("INFO", "Combat logger initialized successfully")
    CombatLogger.initialized = true
    
    -- Show user message
    trigger.action.outText("Combat Event Logger activated - logging to: " .. filename, 10)
    
    return true
end

-- Get comprehensive unit information
local function getUnitData(unit)
    if not unit then return nil end
    
    -- Safely get unit data
    local ok, data = pcall(function()
        local unitData = {
            name = unit:getName(),
            type = unit:getTypeName(),
            coalition = unit:getCoalition(),
            country = unit:getCountry(),
        }
        
        -- Get pilot name if available
        local unitName = unit:getName()
        if unitName then
            unitData.pilot = unit:getPlayerName() or unitName
        end
        
        -- Get group info
        local group = unit:getGroup()
        if group then
            unitData.group = group:getName()
            unitData.groupSize = group:getSize()
        end
        
        -- Get position
        local pos = unit:getPoint()
        if pos then
            unitData.position = {
                x = math.floor(pos.x),
                y = math.floor(pos.y),
                z = math.floor(pos.z)
            }
        end
        
        -- Coalition name
        unitData.coalitionName = unitData.coalition == 0 and "Neutral" or
                                 unitData.coalition == 1 and "Red" or
                                 unitData.coalition == 2 and "Blue" or "Unknown"
        
        -- Check if it's an aircraft
        local desc = unit:getDesc()
        if desc then
            unitData.category = desc.category
            unitData.isAircraft = desc.category == 0 or desc.category == 1
            unitData.isHelicopter = desc.category == 1
        end
        
        return unitData
    end)
    
    if not ok then
        log("ERROR", "Failed to get unit data: " .. tostring(data))
        return nil
    end
    
    return data
end

-- Get weapon information
local function getWeaponData(weapon)
    if not weapon then return nil end
    
    local ok, data = pcall(function()
        local weaponData = {
            type = weapon:getTypeName(),
            category = weapon:getCategory()
        }
        
        -- Try to get launcher info
        local launcher = weapon:getLauncher()
        if launcher then
            weaponData.launcher = launcher:getName()
        end
        
        -- Try to get target
        local target = weapon:getTarget()
        if target then
            weaponData.targetName = target:getName()
        end
        
        return weaponData
    end)
    
    return ok and data or {type = "Unknown"}
end

-- Update pilot statistics
local function updatePilotStats(unitData, eventType, additionalData)
    if not unitData or not unitData.name then return end
    
    local pilotId = unitData.pilot or unitData.name
    
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
        local weaponType = additionalData.weapon.type
        pilot.weaponsFired[weaponType] = (pilot.weaponsFired[weaponType] or 0) + 1
        
        if additionalData.weapon.targetName then
            pilot.targetsEngaged[additionalData.weapon.targetName] = true
        end
    elseif eventType == "hit" then
        pilot.hits = pilot.hits + 1
    elseif eventType == "kill" and additionalData.victim then
        pilot.kills = pilot.kills + 1
        pilot.targetsKilled[additionalData.victim] = (pilot.targetsKilled[additionalData.victim] or 0) + 1
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

-- Log event
local function logEvent(eventType, data)
    local event = {
        id = #CombatLogger.events + 1,
        time = getTimestamp(),
        type = eventType,
        data = data
    }
    
    table.insert(CombatLogger.events, event)
    
    -- Create log message
    local message = eventType .. ": "
    
    if eventType == "SHOT" then
        message = message .. string.format("%s (%s) fired %s",
            data.shooter.name, data.shooter.type, data.weapon.type)
        if data.weapon.targetName then
            message = message .. " at " .. data.weapon.targetName
        end
    elseif eventType == "HIT" then
        message = message .. string.format("%s hit %s with %s",
            data.shooter.name, data.target.name, data.weapon.type)
    elseif eventType == "KILL" then
        message = message .. string.format("%s killed %s with %s",
            data.killer.name, data.victim.name, data.weapon.type)
    elseif eventType == "DEATH" then
        message = message .. string.format("%s (%s) was destroyed",
            data.unit.name, data.unit.type)
    elseif eventType == "CRASH" then
        message = message .. string.format("%s (%s) crashed",
            data.unit.name, data.unit.type)
    elseif eventType == "EJECT" then
        message = message .. string.format("Pilot ejected from %s (%s)",
            data.unit.name, data.unit.type)
    elseif eventType == "BIRTH" then
        message = message .. string.format("%s (%s) spawned",
            data.unit.name, data.unit.type)
    elseif eventType == "TAKEOFF" then
        message = message .. string.format("%s (%s) took off from %s",
            data.unit.name, data.unit.type, data.airbase or "ground")
    elseif eventType == "LAND" then
        message = message .. string.format("%s (%s) landed at %s",
            data.unit.name, data.unit.type, data.airbase or "ground")
    elseif eventType == "ENGINE_START" then
        message = message .. string.format("%s started engines",
            data.unit.name)
    elseif eventType == "ENGINE_STOP" then
        message = message .. string.format("%s stopped engines",
            data.unit.name)
    else
        message = message .. "Unknown event"
    end
    
    log("EVENT", message)
end

-- Event handlers
local function handleEvent(event)
    if not CombatLogger.initialized or not event then return end
    
    -- Get event data safely
    local eventId = event.id
    local initiator = event.initiator
    local target = event.target
    local weapon = event.weapon
    local place = event.place
    
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
            
            -- Track weapon
            local weaponId = weapon:getName()
            if weaponId then
                CombatLogger.weapons[weaponId] = {
                    type = weaponData.type,
                    launcher = shooterData.name,
                    launchTime = getTimestamp()
                }
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
            local airbaseName = place and place:getName() or nil
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
            local airbaseName = place and place:getName() or nil
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
end

-- Status report
local function reportStatus()
    if not CombatLogger.initialized then return end
    
    local missionTime = getTimestamp() / 60
    local pilotCount = 0
    local formationCount = 0
    local totalKills = 0
    local totalShots = 0
    
    for _, pilot in pairs(CombatLogger.pilots) do
        pilotCount = pilotCount + 1
        totalKills = totalKills + pilot.kills
        totalShots = totalShots + pilot.shots
    end
    
    for _ in pairs(CombatLogger.formations) do
        formationCount = formationCount + 1
    end
    
    log("INFO", string.format("STATUS: Time=%.1fm Events=%d Pilots=%d Formations=%d Kills=%d Shots=%d",
        missionTime, #CombatLogger.events, pilotCount, formationCount, totalKills, totalShots))
    
    -- Schedule next report
    timer.scheduleFunction(reportStatus, nil, timer.getTime() + CONFIG.LOG_INTERVAL)
end

-- Finalize logs
function finalizeLogs()
    if not CombatLogger.logFile then return end
    
    log("INFO", "Finalizing combat log...")
    
    -- Mission summary
    CombatLogger.logFile:write("\n========================================\n")
    CombatLogger.logFile:write("=== MISSION SUMMARY ===\n")
    CombatLogger.logFile:write("Total Events: " .. #CombatLogger.events .. "\n")
    CombatLogger.logFile:write("Mission Duration: " .. string.format("%.1f minutes\n", getTimestamp() / 60))
    CombatLogger.logFile:write("Total Pilots: " .. table.getn(CombatLogger.pilots) .. "\n")
    CombatLogger.logFile:write("Total Formations: " .. table.getn(CombatLogger.formations) .. "\n")
    
    -- Pilot statistics
    CombatLogger.logFile:write("\n=== PILOT STATISTICS ===\n")
    for pilotId, pilot in pairs(CombatLogger.pilots) do
        local efficiency = pilot.shots > 0 and (pilot.hits / pilot.shots * 100) or 0
        local kd = pilot.deaths > 0 and (pilot.kills / pilot.deaths) or pilot.kills
        
        CombatLogger.logFile:write(string.format(
            "%-20s (%s, %s, %s)\n" ..
            "  Combat: Kills=%d Deaths=%d KD=%.2f Shots=%d Hits=%d Eff=%.1f%%\n" ..
            "  Flight: Takeoffs=%d Landings=%d Ejections=%d Crashes=%d Time=%.1fm\n",
            pilot.name, pilot.aircraft, pilot.group, pilot.coalition,
            pilot.kills, pilot.deaths, kd, pilot.shots, pilot.hits, efficiency,
            pilot.takeoffs, pilot.landings, pilot.ejections, pilot.crashes, pilot.flightTime / 60
        ))
        
        -- Weapon usage
        if next(pilot.weaponsFired) then
            CombatLogger.logFile:write("  Weapons: ")
            for weapon, count in pairs(pilot.weaponsFired) do
                CombatLogger.logFile:write(weapon .. "=" .. count .. " ")
            end
            CombatLogger.logFile:write("\n")
        end
    end
    
    -- Formation statistics
    CombatLogger.logFile:write("\n=== FORMATION STATISTICS ===\n")
    for formName, form in pairs(CombatLogger.formations) do
        local memberCount = 0
        for _ in pairs(form.members) do memberCount = memberCount + 1 end
        
        CombatLogger.logFile:write(string.format(
            "%-20s: Members=%d Shots=%d Hits=%d Kills=%d Losses=%d\n",
            form.name, memberCount, form.shots, form.hits, form.kills, form.losses
        ))
    end
    
    -- Combat effectiveness summary
    CombatLogger.logFile:write("\n=== COMBAT EFFECTIVENESS ===\n")
    local redKills, redLosses, redShots = 0, 0, 0
    local blueKills, blueLosses, blueShots = 0, 0, 0
    
    for _, pilot in pairs(CombatLogger.pilots) do
        if pilot.coalition == "Red" then
            redKills = redKills + pilot.kills
            redLosses = redLosses + pilot.deaths
            redShots = redShots + pilot.shots
        elseif pilot.coalition == "Blue" then
            blueKills = blueKills + pilot.kills
            blueLosses = blueLosses + pilot.deaths
            blueShots = blueShots + pilot.shots
        end
    end
    
    CombatLogger.logFile:write(string.format("Red Coalition:  Kills=%d Losses=%d Shots=%d\n", redKills, redLosses, redShots))
    CombatLogger.logFile:write(string.format("Blue Coalition: Kills=%d Losses=%d Shots=%d\n", blueKills, blueLosses, blueShots))
    
    -- JSON export for analysis
    CombatLogger.logFile:write("\n=== JSON EXPORT ===\n")
    CombatLogger.logFile:write("{\n")
    CombatLogger.logFile:write('  "mission": {\n')
    CombatLogger.logFile:write('    "theatre": "' .. safeString(CombatLogger.missionData.theatre) .. '",\n')
    CombatLogger.logFile:write('    "duration_seconds": ' .. getTimestamp() .. ',\n')
    CombatLogger.logFile:write('    "total_events": ' .. #CombatLogger.events .. '\n')
    CombatLogger.logFile:write('  },\n')
    CombatLogger.logFile:write('  "statistics": {\n')
    CombatLogger.logFile:write('    "total_pilots": ' .. table.getn(CombatLogger.pilots) .. ',\n')
    CombatLogger.logFile:write('    "total_formations": ' .. table.getn(CombatLogger.formations) .. ',\n')
    CombatLogger.logFile:write('    "red_kills": ' .. redKills .. ',\n')
    CombatLogger.logFile:write('    "red_losses": ' .. redLosses .. ',\n')
    CombatLogger.logFile:write('    "blue_kills": ' .. blueKills .. ',\n')
    CombatLogger.logFile:write('    "blue_losses": ' .. blueLosses .. '\n')
    CombatLogger.logFile:write('  }\n')
    CombatLogger.logFile:write('}\n')
    
    CombatLogger.logFile:write("\n=== END OF LOG ===\n")
    CombatLogger.logFile:close()
    
    env.info("Combat log finalized and saved")
end

-- Initialize
local function initialize()
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
end

-- Start the logger
if initialize() then
    env.info("DCS Combat Logger v2.0 initialized successfully")
else
    env.error("Failed to initialize DCS Combat Logger")
end 