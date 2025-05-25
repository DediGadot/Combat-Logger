--[[
DCS World Air-to-Air Combat Event Logger
========================================

This script logs comprehensive air-to-air combat events during a DCS World mission
for later post-processing and statistical analysis per formation and per pilot.

Features:
- Logs all relevant air-to-air combat events
- Tracks pilot and formation statistics
- Records weapon usage, hits, kills, and deaths
- Exports data in structured format for analysis
- Compatible with the PyAcmi-Analyzer for cross-validation

Installation:
1. Place this script in your mission's trigger actions
2. Set it to run once at mission start
3. Log files will be created in DCS Logs folder

Author: DCS Combat Analytics
Version: 1.0
--]]

-- Configuration
local CONFIG = {
    LOG_FILE_PREFIX = "dcs_combat_log_",
    LOG_FOLDER = lfs.writedir() .. "Logs\\",
    ENABLE_CONSOLE_OUTPUT = true,
    LOG_LEVEL = "INFO", -- DEBUG, INFO, WARN, ERROR
    MISSION_NAME = env.mission.theatre or "Unknown",
    LOG_INTERVAL = 30, -- seconds between status updates
}

-- Global variables
local CombatLogger = {}
CombatLogger.pilots = {}
CombatLogger.formations = {}
CombatLogger.weapons = {}
CombatLogger.events = {}
CombatLogger.missionStartTime = timer.getTime()
CombatLogger.logFile = nil
CombatLogger.eventCount = 0

-- Utility functions
local function log(level, message)
    local timestamp = timer.getTime() - CombatLogger.missionStartTime
    local logEntry = string.format("[%08.2f] [%s] %s", timestamp, level, message)
    
    if CONFIG.ENABLE_CONSOLE_OUTPUT then
        env.info(logEntry)
    end
    
    if CombatLogger.logFile then
        CombatLogger.logFile:write(logEntry .. "\n")
        CombatLogger.logFile:flush()
    end
end

local function initializeLogFile()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = CONFIG.LOG_FOLDER .. CONFIG.LOG_FILE_PREFIX .. timestamp .. ".log"
    
    CombatLogger.logFile = io.open(filename, "w")
    if CombatLogger.logFile then
        log("INFO", "Combat logger initialized - " .. filename)
        log("INFO", "Mission: " .. CONFIG.MISSION_NAME)
        log("INFO", "Start time: " .. os.date())
        
        -- Write JSON header for structured data
        CombatLogger.logFile:write("=== DCS COMBAT LOG START ===\n")
        CombatLogger.logFile:write("{\n")
        CombatLogger.logFile:write('  "mission_info": {\n')
        CombatLogger.logFile:write('    "name": "' .. CONFIG.MISSION_NAME .. '",\n')
        CombatLogger.logFile:write('    "start_time": "' .. os.date() .. '",\n')
        CombatLogger.logFile:write('    "theatre": "' .. (env.mission.theatre or "Unknown") .. '"\n')
        CombatLogger.logFile:write('  },\n')
        CombatLogger.logFile:write('  "events": [\n')
        CombatLogger.logFile:flush()
        return true
    else
        env.error("Failed to create log file: " .. filename)
        return false
    end
end

local function getPilotInfo(unit)
    if not unit then return nil end
    
    local unitName = unit:getName()
    local groupName = unit:getGroup() and unit:getGroup():getName() or "Unknown"
    local coalition = unit:getCoalition()
    local coalitionName = coalition == 1 and "Red" or coalition == 2 and "Blue" or "Neutral"
    local typeName = unit:getTypeName()
    local callsign = unit:getCallsign()
    
    return {
        unit_name = unitName,
        group_name = groupName,
        coalition = coalitionName,
        coalition_id = coalition,
        aircraft_type = typeName,
        callsign = callsign,
        position = unit:getPosition() and unit:getPosition().p or nil
    }
end

local function getWeaponInfo(weapon)
    if not weapon then return nil end
    
    return {
        type_name = weapon:getTypeName(),
        display_name = weapon:getDisplayName(),
        category = weapon:getCategory(),
        target = weapon:getTarget() and weapon:getTarget():getName() or nil
    }
end

local function logEvent(eventType, eventData)
    CombatLogger.eventCount = CombatLogger.eventCount + 1
    local timestamp = timer.getTime() - CombatLogger.missionStartTime
    
    local event = {
        id = CombatLogger.eventCount,
        timestamp = timestamp,
        mission_time = timer.getTime(),
        type = eventType,
        data = eventData
    }
    
    table.insert(CombatLogger.events, event)
    
    -- Write to log file in JSON format
    if CombatLogger.logFile then
        local jsonEvent = string.format(
            '    {\n' ..
            '      "id": %d,\n' ..
            '      "timestamp": %.2f,\n' ..
            '      "mission_time": %.2f,\n' ..
            '      "type": "%s",\n' ..
            '      "data": %s\n' ..
            '    }%s\n',
            event.id,
            event.timestamp,
            event.mission_time,
            eventType,
            mist.utils.tableToString(eventData),
            CombatLogger.eventCount > 1 and "," or ""
        )
        
        -- Insert comma before previous event if this isn't the first
        if CombatLogger.eventCount > 1 then
            CombatLogger.logFile:seek("end", -2) -- Go back to overwrite the last newline
            CombatLogger.logFile:write(",\n" .. jsonEvent)
        else
            CombatLogger.logFile:write(jsonEvent)
        end
        CombatLogger.logFile:flush()
    end
    
    log("DEBUG", string.format("Event %d: %s", CombatLogger.eventCount, eventType))
end

local function updatePilotStats(pilotInfo, statType, data)
    if not pilotInfo or not pilotInfo.unit_name then return end
    
    local pilotName = pilotInfo.unit_name
    
    if not CombatLogger.pilots[pilotName] then
        CombatLogger.pilots[pilotName] = {
            info = pilotInfo,
            stats = {
                shots_fired = 0,
                hits_scored = 0,
                kills = 0,
                deaths = 0,
                weapons_used = {},
                targets_engaged = {},
                flight_time = 0,
                last_seen = timer.getTime()
            }
        }
    end
    
    local pilot = CombatLogger.pilots[pilotName]
    pilot.stats.last_seen = timer.getTime()
    
    if statType == "shot" then
        pilot.stats.shots_fired = pilot.stats.shots_fired + 1
        if data.weapon_type then
            pilot.stats.weapons_used[data.weapon_type] = (pilot.stats.weapons_used[data.weapon_type] or 0) + 1
        end
    elseif statType == "hit" then
        pilot.stats.hits_scored = pilot.stats.hits_scored + 1
        if data.target then
            pilot.stats.targets_engaged[data.target] = (pilot.stats.targets_engaged[data.target] or 0) + 1
        end
    elseif statType == "kill" then
        pilot.stats.kills = pilot.stats.kills + 1
    elseif statType == "death" then
        pilot.stats.deaths = pilot.stats.deaths + 1
    end
end

local function updateFormationStats(groupName, statType, data)
    if not groupName then return end
    
    if not CombatLogger.formations[groupName] then
        CombatLogger.formations[groupName] = {
            name = groupName,
            stats = {
                total_shots = 0,
                total_hits = 0,
                total_kills = 0,
                total_deaths = 0,
                members = {},
                weapons_used = {},
                active = true
            }
        }
    end
    
    local formation = CombatLogger.formations[groupName]
    
    if statType == "shot" then
        formation.stats.total_shots = formation.stats.total_shots + 1
        if data.weapon_type then
            formation.stats.weapons_used[data.weapon_type] = (formation.stats.weapons_used[data.weapon_type] or 0) + 1
        end
    elseif statType == "hit" then
        formation.stats.total_hits = formation.stats.total_hits + 1
    elseif statType == "kill" then
        formation.stats.total_kills = formation.stats.total_kills + 1
    elseif statType == "death" then
        formation.stats.total_deaths = formation.stats.total_deaths + 1
    end
    
    -- Add pilot to formation if not already present
    if data.pilot_name and not formation.stats.members[data.pilot_name] then
        formation.stats.members[data.pilot_name] = true
    end
end

-- Event handlers
local function onShot(event)
    local initiatorInfo = getPilotInfo(event.initiator)
    local weaponInfo = getWeaponInfo(event.weapon)
    
    if initiatorInfo and weaponInfo then
        local eventData = {
            pilot = initiatorInfo,
            weapon = weaponInfo,
            pilot_name = initiatorInfo.unit_name,
            weapon_type = weaponInfo.type_name,
            coalition = initiatorInfo.coalition
        }
        
        logEvent("SHOT", eventData)
        updatePilotStats(initiatorInfo, "shot", eventData)
        updateFormationStats(initiatorInfo.group_name, "shot", eventData)
        
        log("INFO", string.format("%s (%s) fired %s", 
            initiatorInfo.unit_name, initiatorInfo.aircraft_type, weaponInfo.type_name))
    end
end

local function onHit(event)
    local initiatorInfo = getPilotInfo(event.initiator)
    local targetInfo = getPilotInfo(event.target)
    local weaponInfo = getWeaponInfo(event.weapon)
    
    if initiatorInfo and targetInfo then
        local eventData = {
            shooter = initiatorInfo,
            target = targetInfo,
            weapon = weaponInfo,
            pilot_name = initiatorInfo.unit_name,
            target_name = targetInfo.unit_name,
            weapon_type = weaponInfo and weaponInfo.type_name or "Unknown"
        }
        
        logEvent("HIT", eventData)
        updatePilotStats(initiatorInfo, "hit", eventData)
        updateFormationStats(initiatorInfo.group_name, "hit", eventData)
        
        log("INFO", string.format("%s hit %s with %s", 
            initiatorInfo.unit_name, targetInfo.unit_name, 
            weaponInfo and weaponInfo.type_name or "Unknown"))
    end
end

local function onKill(event)
    local initiatorInfo = getPilotInfo(event.initiator)
    local targetInfo = getPilotInfo(event.target)
    local weaponInfo = getWeaponInfo(event.weapon)
    
    if initiatorInfo and targetInfo then
        local eventData = {
            killer = initiatorInfo,
            victim = targetInfo,
            weapon = weaponInfo,
            pilot_name = initiatorInfo.unit_name,
            victim_name = targetInfo.unit_name,
            weapon_type = weaponInfo and weaponInfo.type_name or "Unknown"
        }
        
        logEvent("KILL", eventData)
        updatePilotStats(initiatorInfo, "kill", eventData)
        updatePilotStats(targetInfo, "death", eventData)
        updateFormationStats(initiatorInfo.group_name, "kill", eventData)
        updateFormationStats(targetInfo.group_name, "death", eventData)
        
        log("INFO", string.format("%s killed %s with %s", 
            initiatorInfo.unit_name, targetInfo.unit_name, 
            weaponInfo and weaponInfo.type_name or "Unknown"))
    end
end

local function onDead(event)
    local unitInfo = getPilotInfo(event.initiator)
    
    if unitInfo then
        local eventData = {
            pilot = unitInfo,
            pilot_name = unitInfo.unit_name,
            aircraft_type = unitInfo.aircraft_type,
            coalition = unitInfo.coalition
        }
        
        logEvent("DEAD", eventData)
        
        log("INFO", string.format("%s (%s) was destroyed", 
            unitInfo.unit_name, unitInfo.aircraft_type))
    end
end

local function onCrash(event)
    local unitInfo = getPilotInfo(event.initiator)
    
    if unitInfo then
        local eventData = {
            pilot = unitInfo,
            pilot_name = unitInfo.unit_name,
            aircraft_type = unitInfo.aircraft_type,
            coalition = unitInfo.coalition
        }
        
        logEvent("CRASH", eventData)
        
        log("INFO", string.format("%s (%s) crashed", 
            unitInfo.unit_name, unitInfo.aircraft_type))
    end
end

local function onEjection(event)
    local unitInfo = getPilotInfo(event.initiator)
    
    if unitInfo then
        local eventData = {
            pilot = unitInfo,
            pilot_name = unitInfo.unit_name,
            aircraft_type = unitInfo.aircraft_type,
            coalition = unitInfo.coalition
        }
        
        logEvent("EJECTION", eventData)
        
        log("INFO", string.format("Pilot ejected from %s (%s)", 
            unitInfo.unit_name, unitInfo.aircraft_type))
    end
end

local function onTakeoff(event)
    local unitInfo = getPilotInfo(event.initiator)
    
    if unitInfo then
        local eventData = {
            pilot = unitInfo,
            pilot_name = unitInfo.unit_name,
            aircraft_type = unitInfo.aircraft_type,
            coalition = unitInfo.coalition,
            airbase = event.place and event.place:getName() or "Unknown"
        }
        
        logEvent("TAKEOFF", eventData)
        
        log("INFO", string.format("%s (%s) took off from %s", 
            unitInfo.unit_name, unitInfo.aircraft_type, eventData.airbase))
    end
end

local function onLanding(event)
    local unitInfo = getPilotInfo(event.initiator)
    
    if unitInfo then
        local eventData = {
            pilot = unitInfo,
            pilot_name = unitInfo.unit_name,
            aircraft_type = unitInfo.aircraft_type,
            coalition = unitInfo.coalition,
            airbase = event.place and event.place:getName() or "Unknown"
        }
        
        logEvent("LANDING", eventData)
        
        log("INFO", string.format("%s (%s) landed at %s", 
            unitInfo.unit_name, unitInfo.aircraft_type, eventData.airbase))
    end
end

-- Main event handler
local function onEvent(event)
    if not event or not event.id then return end
    
    if event.id == world.event.S_EVENT_SHOT then
        onShot(event)
    elseif event.id == world.event.S_EVENT_HIT then
        onHit(event)
    elseif event.id == world.event.S_EVENT_KILL then
        onKill(event)
    elseif event.id == world.event.S_EVENT_DEAD then
        onDead(event)
    elseif event.id == world.event.S_EVENT_CRASH then
        onCrash(event)
    elseif event.id == world.event.S_EVENT_EJECTION then
        onEjection(event)
    elseif event.id == world.event.S_EVENT_TAKEOFF then
        onTakeoff(event)
    elseif event.id == world.event.S_EVENT_LAND then
        onLanding(event)
    elseif event.id == world.event.S_EVENT_MISSION_START then
        log("INFO", "Mission started")
    elseif event.id == world.event.S_EVENT_MISSION_END then
        log("INFO", "Mission ended")
        CombatLogger.finalizeLogs()
    end
end

-- Status reporting function
local function reportStatus()
    local currentTime = timer.getTime()
    local missionTime = currentTime - CombatLogger.missionStartTime
    
    log("INFO", string.format("Status Report - Mission Time: %.1f minutes", missionTime / 60))
    log("INFO", string.format("Total Events: %d", CombatLogger.eventCount))
    log("INFO", string.format("Active Pilots: %d", table.getn(CombatLogger.pilots)))
    log("INFO", string.format("Active Formations: %d", table.getn(CombatLogger.formations)))
    
    -- Schedule next status report
    timer.scheduleFunction(reportStatus, nil, currentTime + CONFIG.LOG_INTERVAL)
end

-- Finalization function
function CombatLogger.finalizeLogs()
    if CombatLogger.logFile then
        -- Close events array and add summary
        CombatLogger.logFile:write('  ],\n')
        CombatLogger.logFile:write('  "summary": {\n')
        CombatLogger.logFile:write('    "total_events": ' .. CombatLogger.eventCount .. ',\n')
        CombatLogger.logFile:write('    "mission_duration": ' .. (timer.getTime() - CombatLogger.missionStartTime) .. ',\n')
        CombatLogger.logFile:write('    "pilots": ' .. mist.utils.tableToString(CombatLogger.pilots) .. ',\n')
        CombatLogger.logFile:write('    "formations": ' .. mist.utils.tableToString(CombatLogger.formations) .. '\n')
        CombatLogger.logFile:write('  }\n')
        CombatLogger.logFile:write('}\n')
        CombatLogger.logFile:write("=== DCS COMBAT LOG END ===\n")
        CombatLogger.logFile:close()
        
        log("INFO", "Combat log finalized")
    end
end

-- Initialization
local function initialize()
    if initializeLogFile() then
        -- Create event handler
        local eventHandler = {}
        eventHandler.onEvent = onEvent
        world.addEventHandler(eventHandler)
        
        -- Schedule periodic status reports
        timer.scheduleFunction(reportStatus, nil, timer.getTime() + CONFIG.LOG_INTERVAL)
        
        log("INFO", "DCS Combat Logger initialized successfully")
        log("INFO", "Monitoring air-to-air combat events...")
        
        return true
    else
        env.error("Failed to initialize DCS Combat Logger")
        return false
    end
end

-- Auto-initialize when script loads
initialize()

-- Export the logger for external access if needed
return CombatLogger 