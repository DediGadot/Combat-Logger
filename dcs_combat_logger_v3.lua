--[[
DCS Combat Logger v3.0 - Multiplayer Compatible
==================================================

A comprehensive combat logging system for DCS World that works reliably 
in both single-player and dedicated multiplayer server environments.

Key improvements in v3.0:
- Uses polling instead of unreliable S_EVENT_PLAYER_ENTER_UNIT/LEAVE_UNIT
- Focuses on events that work reliably in multiplayer
- Enhanced error protection for dedicated server environments
- Simplified player tracking system

Installation:
1. Place this file in your mission's trigger "DO SCRIPT FILE" action
2. Logs will appear in DCS.log with "COMBAT_LOG:" prefix
3. Mission summary will be logged at mission end

Author: AI Assistant
Version: 3.0 (Multiplayer Compatible)
Date: 2024
--]]

-- ============================================================================
-- UTILITY FUNCTIONS (Safe for DCS environment)
-- ============================================================================

local function safeString(value)
    if value == nil then return "Unknown" end
    if type(value) == "string" then return value end
    return tostring(value)
end

local function safeNumber(value)
    if value == nil then return 0 end
    if type(value) == "number" then return value end
    return 0
end

local function countTable(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function safeMath()
    return {
        floor = function(x)
            if not x then return 0 end
            return x - (x % 1)
        end,
        max = function(a, b)
            if not a then return b or 0 end
            if not b then return a or 0 end
            return (a > b) and a or b
        end,
        min = function(a, b)
            if not a then return b or 0 end
            if not b then return a or 0 end
            return (a < b) and a or b
        end
    }
end

local math = safeMath()

-- ============================================================================
-- GLOBAL DATA STRUCTURES
-- ============================================================================

local CombatLogger = {
    version = "3.0",
    startTime = 0,
    logBuffer = {},
    bufferSize = 0,
    maxBufferSize = 100,
    
    -- Player tracking (polling-based)
    knownPlayers = {},
    playerCheckInterval = 5, -- seconds
    
    -- Statistics
    stats = {
        pilots = {},
        formations = {},
        coalitions = {
            [1] = { name = "Red", shots = 0, hits = 0, kills = 0, deaths = 0 },
            [2] = { name = "Blue", shots = 0, hits = 0, kills = 0, deaths = 0 }
        },
        weapons = {},
        events = {
            shots = 0,
            hits = 0,
            kills = 0,
            deaths = 0,
            takeoffs = 0,
            landings = 0,
            crashes = 0,
            ejections = 0
        }
    }
}

-- ============================================================================
-- LOGGING FUNCTIONS
-- ============================================================================

local function addToBuffer(message)
    if not message then return end
    
    CombatLogger.bufferSize = CombatLogger.bufferSize + 1
    CombatLogger.logBuffer[CombatLogger.bufferSize] = message
    
    -- Flush buffer if it gets too large
    if CombatLogger.bufferSize >= CombatLogger.maxBufferSize then
        flushLogBuffer()
    end
end

function flushLogBuffer()
    if CombatLogger.bufferSize == 0 then return end
    
    local success, error = pcall(function()
        for i = 1, CombatLogger.bufferSize do
            local message = CombatLogger.logBuffer[i]
            if message then
                env.info("COMBAT_LOG: " .. message, false)
            end
        end
    end)
    
    if not success then
        env.info("COMBAT_LOG: Error flushing buffer: " .. safeString(error), false)
    end
    
    -- Clear buffer
    CombatLogger.logBuffer = {}
    CombatLogger.bufferSize = 0
end

local function logEvent(eventType, details)
    local timestamp = safeNumber(timer.getTime()) - CombatLogger.startTime
    local message = string.format("[%.1f] %s: %s", timestamp, safeString(eventType), safeString(details))
    addToBuffer(message)
end

-- ============================================================================
-- PLAYER TRACKING (Polling-based for MP compatibility)
-- ============================================================================

local function getUnitInfo(unit)
    if not unit then return nil end
    
    local success, info = pcall(function()
        local playerName = nil
        if unit.getPlayerName then
            playerName = unit:getPlayerName()
        end
        
        local unitName = "Unknown"
        if unit.getName then
            unitName = unit:getName()
        end
        
        local typeName = "Unknown"
        if unit.getTypeName then
            typeName = unit:getTypeName()
        end
        
        local coalition = 0
        if unit.getCoalition then
            coalition = unit:getCoalition()
        end
        
        local groupName = "Unknown"
        if unit.getGroup and unit:getGroup() and unit:getGroup().getName then
            groupName = unit:getGroup():getName()
        end
        
        return {
            playerName = playerName,
            unitName = unitName,
            typeName = typeName,
            coalition = coalition,
            groupName = groupName,
            unit = unit
        }
    end)
    
    if success and info then
        return info
    end
    return nil
end

local function checkForPlayers()
    local success, error = pcall(function()
        local currentPlayers = {}
        
        -- Check both coalitions
        for coalitionId = 1, 2 do
            local groups = coalition.getGroups(coalitionId)
            if groups then
                for i = 1, #groups do
                    local group = groups[i]
                    if group and group.getUnits then
                        local units = group:getUnits()
                        if units then
                            for j = 1, #units do
                                local unit = units[j]
                                local unitInfo = getUnitInfo(unit)
                                
                                if unitInfo and unitInfo.playerName then
                                    local playerId = unitInfo.playerName .. "_" .. unitInfo.unitName
                                    currentPlayers[playerId] = unitInfo
                                    
                                    -- Check if this is a new player
                                    if not CombatLogger.knownPlayers[playerId] then
                                        handlePlayerEnter(unitInfo)
                                        CombatLogger.knownPlayers[playerId] = unitInfo
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check for players who left
        for playerId, playerInfo in pairs(CombatLogger.knownPlayers) do
            if not currentPlayers[playerId] then
                handlePlayerLeave(playerInfo)
                CombatLogger.knownPlayers[playerId] = nil
            end
        end
    end)
    
    if not success then
        logEvent("ERROR", "Player check failed: " .. safeString(error))
    end
    
    -- Schedule next check
    return timer.getTime() + CombatLogger.playerCheckInterval
end

-- ============================================================================
-- PLAYER EVENT HANDLERS
-- ============================================================================

function handlePlayerEnter(unitInfo)
    local playerName = safeString(unitInfo.playerName)
    local unitName = safeString(unitInfo.unitName)
    local typeName = safeString(unitInfo.typeName)
    local coalitionName = CombatLogger.stats.coalitions[unitInfo.coalition].name
    
    logEvent("PLAYER_ENTER", string.format("%s entered %s (%s) - %s Coalition", 
        playerName, unitName, typeName, coalitionName))
    
    -- Initialize pilot stats if needed
    if not CombatLogger.stats.pilots[playerName] then
        CombatLogger.stats.pilots[playerName] = {
            name = playerName,
            coalition = unitInfo.coalition,
            aircraft = {},
            shots = 0,
            hits = 0,
            kills = 0,
            deaths = 0,
            takeoffs = 0,
            landings = 0,
            flightTime = 0,
            lastTakeoffTime = 0
        }
    end
    
    -- Track aircraft usage
    local pilot = CombatLogger.stats.pilots[playerName]
    if not pilot.aircraft[typeName] then
        pilot.aircraft[typeName] = 0
    end
    pilot.aircraft[typeName] = pilot.aircraft[typeName] + 1
end

function handlePlayerLeave(unitInfo)
    local playerName = safeString(unitInfo.playerName)
    local unitName = safeString(unitInfo.unitName)
    
    logEvent("PLAYER_LEAVE", string.format("%s left %s", playerName, unitName))
end

-- ============================================================================
-- COMBAT EVENT HANDLERS (Reliable events only)
-- ============================================================================

local function getEventUnitInfo(unit)
    if not unit then return "Unknown", "Unknown", 0 end
    
    local success, info = pcall(function()
        local playerName = "AI"
        if unit.getPlayerName then
            local pName = unit:getPlayerName()
            if pName then playerName = pName end
        end
        
        local unitName = "Unknown"
        if unit.getName then
            unitName = unit:getName()
        end
        
        local coalition = 0
        if unit.getCoalition then
            coalition = unit:getCoalition()
        end
        
        return playerName, unitName, coalition
    end)
    
    if success then
        return info
    else
        return "Unknown", "Unknown", 0
    end
end

local function handleShot(event)
    local success, error = pcall(function()
        local shooterName, shooterUnit, shooterCoalition = getEventUnitInfo(event.initiator)
        local weaponName = "Unknown"
        
        if event.weapon and event.weapon.getTypeName then
            weaponName = event.weapon:getTypeName()
        end
        
        logEvent("SHOT", string.format("%s (%s) fired %s", 
            shooterName, shooterUnit, weaponName))
        
        -- Update statistics
        CombatLogger.stats.events.shots = CombatLogger.stats.events.shots + 1
        CombatLogger.stats.coalitions[shooterCoalition].shots = 
            CombatLogger.stats.coalitions[shooterCoalition].shots + 1
        
        if CombatLogger.stats.pilots[shooterName] then
            CombatLogger.stats.pilots[shooterName].shots = 
                CombatLogger.stats.pilots[shooterName].shots + 1
        end
        
        -- Track weapon usage
        if not CombatLogger.stats.weapons[weaponName] then
            CombatLogger.stats.weapons[weaponName] = { fired = 0, hits = 0 }
        end
        CombatLogger.stats.weapons[weaponName].fired = 
            CombatLogger.stats.weapons[weaponName].fired + 1
    end)
    
    if not success then
        logEvent("ERROR", "Shot handler failed: " .. safeString(error))
    end
end

local function handleHit(event)
    local success, error = pcall(function()
        local shooterName, shooterUnit, shooterCoalition = getEventUnitInfo(event.initiator)
        local targetName, targetUnit, targetCoalition = getEventUnitInfo(event.target)
        local weaponName = "Unknown"
        
        if event.weapon and event.weapon.getTypeName then
            weaponName = event.weapon:getTypeName()
        end
        
        logEvent("HIT", string.format("%s (%s) hit %s (%s) with %s", 
            shooterName, shooterUnit, targetName, targetUnit, weaponName))
        
        -- Update statistics
        CombatLogger.stats.events.hits = CombatLogger.stats.events.hits + 1
        CombatLogger.stats.coalitions[shooterCoalition].hits = 
            CombatLogger.stats.coalitions[shooterCoalition].hits + 1
        
        if CombatLogger.stats.pilots[shooterName] then
            CombatLogger.stats.pilots[shooterName].hits = 
                CombatLogger.stats.pilots[shooterName].hits + 1
        end
        
        -- Track weapon hits
        if CombatLogger.stats.weapons[weaponName] then
            CombatLogger.stats.weapons[weaponName].hits = 
                CombatLogger.stats.weapons[weaponName].hits + 1
        end
    end)
    
    if not success then
        logEvent("ERROR", "Hit handler failed: " .. safeString(error))
    end
end

local function handleKill(event)
    local success, error = pcall(function()
        local killerName, killerUnit, killerCoalition = getEventUnitInfo(event.initiator)
        local victimName, victimUnit, victimCoalition = getEventUnitInfo(event.target)
        local weaponName = "Unknown"
        
        if event.weapon and event.weapon.getTypeName then
            weaponName = event.weapon:getTypeName()
        end
        
        logEvent("KILL", string.format("%s (%s) killed %s (%s) with %s", 
            killerName, killerUnit, victimName, victimUnit, weaponName))
        
        -- Update statistics
        CombatLogger.stats.events.kills = CombatLogger.stats.events.kills + 1
        CombatLogger.stats.events.deaths = CombatLogger.stats.events.deaths + 1
        
        CombatLogger.stats.coalitions[killerCoalition].kills = 
            CombatLogger.stats.coalitions[killerCoalition].kills + 1
        CombatLogger.stats.coalitions[victimCoalition].deaths = 
            CombatLogger.stats.coalitions[victimCoalition].deaths + 1
        
        if CombatLogger.stats.pilots[killerName] then
            CombatLogger.stats.pilots[killerName].kills = 
                CombatLogger.stats.pilots[killerName].kills + 1
        end
        
        if CombatLogger.stats.pilots[victimName] then
            CombatLogger.stats.pilots[victimName].deaths = 
                CombatLogger.stats.pilots[victimName].deaths + 1
        end
    end)
    
    if not success then
        logEvent("ERROR", "Kill handler failed: " .. safeString(error))
    end
end

local function handleTakeoff(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("TAKEOFF", string.format("%s (%s) took off", pilotName, unitName))
        
        CombatLogger.stats.events.takeoffs = CombatLogger.stats.events.takeoffs + 1
        
        if CombatLogger.stats.pilots[pilotName] then
            CombatLogger.stats.pilots[pilotName].takeoffs = 
                CombatLogger.stats.pilots[pilotName].takeoffs + 1
            CombatLogger.stats.pilots[pilotName].lastTakeoffTime = timer.getTime()
        end
    end)
    
    if not success then
        logEvent("ERROR", "Takeoff handler failed: " .. safeString(error))
    end
end

local function handleLanding(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("LANDING", string.format("%s (%s) landed", pilotName, unitName))
        
        CombatLogger.stats.events.landings = CombatLogger.stats.events.landings + 1
        
        if CombatLogger.stats.pilots[pilotName] then
            CombatLogger.stats.pilots[pilotName].landings = 
                CombatLogger.stats.pilots[pilotName].landings + 1
            
            -- Calculate flight time
            if CombatLogger.stats.pilots[pilotName].lastTakeoffTime > 0 then
                local flightTime = timer.getTime() - CombatLogger.stats.pilots[pilotName].lastTakeoffTime
                CombatLogger.stats.pilots[pilotName].flightTime = 
                    CombatLogger.stats.pilots[pilotName].flightTime + flightTime
            end
        end
    end)
    
    if not success then
        logEvent("ERROR", "Landing handler failed: " .. safeString(error))
    end
end

local function handleCrash(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("CRASH", string.format("%s (%s) crashed", pilotName, unitName))
        
        CombatLogger.stats.events.crashes = CombatLogger.stats.events.crashes + 1
    end)
    
    if not success then
        logEvent("ERROR", "Crash handler failed: " .. safeString(error))
    end
end

local function handleEjection(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("EJECTION", string.format("%s ejected from %s", pilotName, unitName))
        
        CombatLogger.stats.events.ejections = CombatLogger.stats.events.ejections + 1
    end)
    
    if not success then
        logEvent("ERROR", "Ejection handler failed: " .. safeString(error))
    end
end

-- ============================================================================
-- MAIN EVENT HANDLER
-- ============================================================================

local CombatEventHandler = {}

function CombatEventHandler:onEvent(event)
    if not event or not event.id then return end
    
    local success, error = pcall(function()
        if event.id == world.event.S_EVENT_SHOT then
            handleShot(event)
        elseif event.id == world.event.S_EVENT_HIT then
            handleHit(event)
        elseif event.id == world.event.S_EVENT_KILL then
            handleKill(event)
        elseif event.id == world.event.S_EVENT_TAKEOFF then
            handleTakeoff(event)
        elseif event.id == world.event.S_EVENT_LAND then
            handleLanding(event)
        elseif event.id == world.event.S_EVENT_CRASH then
            handleCrash(event)
        elseif event.id == world.event.S_EVENT_EJECTION then
            handleEjection(event)
        end
        
        -- Periodically flush the log buffer
        if CombatLogger.bufferSize > 0 and 
           (timer.getTime() - CombatLogger.startTime) % 30 < 1 then
            flushLogBuffer()
        end
    end)
    
    if not success then
        env.info("COMBAT_LOG: Event handler error: " .. safeString(error), false)
    end
end

-- ============================================================================
-- STATISTICS AND REPORTING
-- ============================================================================

local function generateMissionSummary()
    local success, error = pcall(function()
        local missionTime = timer.getTime() - CombatLogger.startTime
        local minutes = math.floor(missionTime / 60)
        local seconds = math.floor(missionTime % 60)
        
        addToBuffer("=== MISSION SUMMARY ===")
        addToBuffer(string.format("Mission Duration: %d:%02d", minutes, seconds))
        addToBuffer(string.format("Total Events: Shots=%d, Hits=%d, Kills=%d, Deaths=%d", 
            CombatLogger.stats.events.shots,
            CombatLogger.stats.events.hits,
            CombatLogger.stats.events.kills,
            CombatLogger.stats.events.deaths))
        addToBuffer(string.format("Flight Operations: Takeoffs=%d, Landings=%d, Crashes=%d, Ejections=%d",
            CombatLogger.stats.events.takeoffs,
            CombatLogger.stats.events.landings,
            CombatLogger.stats.events.crashes,
            CombatLogger.stats.events.ejections))
        
        -- Coalition summary
        addToBuffer("=== COALITION PERFORMANCE ===")
        for coalitionId, coalitionData in pairs(CombatLogger.stats.coalitions) do
            if coalitionData.shots > 0 or coalitionData.hits > 0 or coalitionData.kills > 0 then
                local hitRate = coalitionData.shots > 0 and 
                    math.floor((coalitionData.hits / coalitionData.shots) * 100) or 0
                addToBuffer(string.format("%s Coalition: Shots=%d, Hits=%d (%d%%), Kills=%d, Deaths=%d",
                    coalitionData.name,
                    coalitionData.shots,
                    coalitionData.hits,
                    hitRate,
                    coalitionData.kills,
                    coalitionData.deaths))
            end
        end
        
        -- Pilot summary
        addToBuffer("=== PILOT PERFORMANCE ===")
        for pilotName, pilot in pairs(CombatLogger.stats.pilots) do
            if pilot.shots > 0 or pilot.hits > 0 or pilot.kills > 0 then
                local hitRate = pilot.shots > 0 and 
                    math.floor((pilot.hits / pilot.shots) * 100) or 0
                local kd = pilot.deaths > 0 and 
                    string.format("%.1f", pilot.kills / pilot.deaths) or 
                    (pilot.kills > 0 and "∞" or "0")
                local flightMinutes = math.floor(pilot.flightTime / 60)
                
                addToBuffer(string.format("%s (%s): Shots=%d, Hits=%d (%d%%), K/D=%s, Flight=%dm",
                    pilotName,
                    CombatLogger.stats.coalitions[pilot.coalition].name,
                    pilot.shots,
                    pilot.hits,
                    hitRate,
                    kd,
                    flightMinutes))
            end
        end
        
        -- Weapon effectiveness
        addToBuffer("=== WEAPON EFFECTIVENESS ===")
        for weaponName, weaponData in pairs(CombatLogger.stats.weapons) do
            if weaponData.fired > 0 then
                local hitRate = math.floor((weaponData.hits / weaponData.fired) * 100)
                addToBuffer(string.format("%s: Fired=%d, Hits=%d (%d%%)",
                    weaponName, weaponData.fired, weaponData.hits, hitRate))
            end
        end
        
        addToBuffer("=== END SUMMARY ===")
        flushLogBuffer()
    end)
    
    if not success then
        env.info("COMBAT_LOG: Summary generation failed: " .. safeString(error), false)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function initializeCombatLogger()
    local success, error = pcall(function()
        CombatLogger.startTime = timer.getTime()
        
        logEvent("SYSTEM", "Combat Logger v" .. CombatLogger.version .. " initialized (Multiplayer Compatible)")
        logEvent("SYSTEM", "Using polling-based player detection for MP compatibility")
        
        -- Register event handler for reliable events only
        world.addEventHandler(CombatEventHandler)
        
        -- Start player polling system
        timer.scheduleFunction(checkForPlayers, nil, timer.getTime() + CombatLogger.playerCheckInterval)
        
        -- Schedule periodic buffer flushes
        timer.scheduleFunction(function()
            flushLogBuffer()
            return timer.getTime() + 30 -- Flush every 30 seconds
        end, nil, timer.getTime() + 30)
        
        logEvent("SYSTEM", "All systems initialized successfully")
    end)
    
    if not success then
        env.info("COMBAT_LOG: Initialization failed: " .. safeString(error), false)
    end
end

-- ============================================================================
-- MISSION END HANDLER
-- ============================================================================

local MissionEndHandler = {}

function MissionEndHandler:onEvent(event)
    if event.id == world.event.S_EVENT_MISSION_END then
        generateMissionSummary()
    end
end

world.addEventHandler(MissionEndHandler)

-- ============================================================================
-- START THE LOGGER
-- ============================================================================

initializeCombatLogger()

env.info("COMBAT_LOG: DCS Combat Logger v3.0 (Multiplayer Compatible) loaded successfully", false) 