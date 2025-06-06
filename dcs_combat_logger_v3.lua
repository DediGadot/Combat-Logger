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
- Built-in debug mode with in-game messages

Installation:
1. Place this file in your mission's trigger "DO SCRIPT FILE" action
2. Logs will be saved to a separate file in the DCS logging folder:
   %USERPROFILE%\Saved Games\DCS\Logs\combat_log_HHMMSS.log
3. If separate file creation fails, falls back to DCS.log with "COMBAT_LOG:" prefix
4. Mission summary will be logged at mission end
5. Debug messages appear in-game (set debugMode = false to disable)

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
-- DEBUG FUNCTION (Defined early to avoid nil reference errors)
-- ============================================================================

local function debugMessage(message, duration)
    -- Check if CombatLogger exists and debug mode is enabled
    if not CombatLogger or not CombatLogger.debugMode then return end
    
    local success, error = pcall(function()
        local timestamp = 0
        if CombatLogger.startTime then
            timestamp = safeNumber(timer.getTime()) - CombatLogger.startTime
        end
        local debugMsg = string.format("[%.1f] DEBUG: %s", timestamp, safeString(message))
        
        -- Send message to all players
        trigger.action.outText(debugMsg, duration or 10)
        
        -- Also log to DCS.log directly (avoid recursion)
        env.info("COMBAT_LOG: DEBUG: " .. safeString(message), false)
    end)
    
    if not success then
        env.info("COMBAT_LOG: Debug message error: " .. safeString(error), false)
    end
end

-- ============================================================================
-- GLOBAL DATA STRUCTURES
-- ============================================================================

local CombatLogger = {
    version = "3.0",
    startTime = 0,
    logBuffer = {},
    bufferSize = 0,
    maxBufferSize = 100,
    logFileName = nil, -- Will be set on first write
    debugMode = true, -- Set to false to disable debug messages
    
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

local function getLogFileName()
    -- Generate unique log file name with mission timestamp
    local timestamp = safeNumber(timer.getAbsTime())
    local hours = math.floor(timestamp / 3600) % 24
    local minutes = math.floor(timestamp / 60) % 60
    local seconds = math.floor(timestamp) % 60
    
    return string.format("combat_log_%02d%02d%02d.log", hours, minutes, seconds)
end

local function writeToSeparateLogFile(content)
    local success, error = pcall(function()
        -- Try to write to separate combat log file in DCS Logs folder
        local logFileName = CombatLogger.logFileName or getLogFileName()
        
        -- First time setup - show debug info about log file
        if not CombatLogger.logFileName then
            CombatLogger.logFileName = logFileName
            
            -- Use DCS export functions to write to separate file
            local exportPath = lfs and lfs.writedir() or ""
            if exportPath and exportPath ~= "" then
                local fullPath = exportPath .. "Logs\\" .. logFileName
                debugMessage("Attempting to create log file: " .. fullPath, 15)
                
                -- Try to create/test the file
                local testFile = io.open(fullPath, "a")
                if testFile then
                    testFile:close()
                    debugMessage("✅ Combat log file created successfully!", 10)
                    debugMessage("📁 Log location: " .. fullPath, 15)
                else
                    debugMessage("❌ Failed to create separate log file", 10)
                    debugMessage("📝 Falling back to DCS.log", 10)
                end
            else
                debugMessage("❌ Could not access DCS write directory", 10)
                debugMessage("📝 Falling back to DCS.log", 10)
            end
        end
        
        -- Use DCS export functions to write to separate file
        local exportPath = lfs and lfs.writedir() or ""
        if exportPath and exportPath ~= "" then
            local fullPath = exportPath .. "Logs\\" .. logFileName
            
            -- Try to write to separate file
            local file = io.open(fullPath, "a")
            if file then
                file:write(content .. "\n")
                file:close()
                return true
            end
        end
        
        -- Fallback: write to DCS.log with clear prefix
        env.info("COMBAT_LOG: " .. content, false)
        return false
    end)
    
    if not success then
        -- Final fallback to DCS.log
        env.info("COMBAT_LOG: " .. safeString(content), false)
        env.info("COMBAT_LOG: Log write error: " .. safeString(error), false)
        
        if CombatLogger.debugMode then
            debugMessage("❌ Log write error: " .. safeString(error), 15)
        end
    end
end

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
    
    local bufferCount = CombatLogger.bufferSize
    local success, error = pcall(function()
        for i = 1, CombatLogger.bufferSize do
            local message = CombatLogger.logBuffer[i]
            if message then
                writeToSeparateLogFile(message)
            end
        end
    end)
    
    if not success then
        env.info("COMBAT_LOG: Error flushing buffer: " .. safeString(error), false)
        if CombatLogger.debugMode then
            debugMessage("❌ Buffer flush error: " .. safeString(error), 10)
        end
    else
        if CombatLogger.debugMode and bufferCount > 10 then
            debugMessage("💾 Flushed " .. bufferCount .. " log entries", 5)
        end
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
        -- Check if unit object still exists and is valid
        if not unit.isExist or not unit:isExist() then
            return nil
        end
        
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
    local coalition = safeNumber(unitInfo.coalition)
    local coalitionName = "Unknown"
    
    if CombatLogger.stats.coalitions[coalition] then
        coalitionName = CombatLogger.stats.coalitions[coalition].name
    end
    
    logEvent("PLAYER_ENTER", string.format("%s entered %s (%s) - %s Coalition", 
        safeString(playerName), safeString(unitName), safeString(typeName), safeString(coalitionName)))
    
    debugMessage("👤 Player joined: " .. playerName .. " in " .. typeName, 8)
    
    -- Initialize pilot stats if needed
    if not CombatLogger.stats.pilots[playerName] then
        CombatLogger.stats.pilots[playerName] = {
            name = playerName,
            coalition = coalition,
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
    debugMessage("👋 Player left: " .. playerName, 8)
end

-- ============================================================================
-- COMBAT EVENT HANDLERS (Reliable events only)
-- ============================================================================

local function getEventUnitInfo(unit)
    if not unit then return "Unknown", "Unknown", 0 end
    
    local success, playerName, unitName, coalition = pcall(function()
        -- Check if unit object still exists and is valid
        if not unit.isExist or not unit:isExist() then
            if CombatLogger.debugMode then
                debugMessage("⚠️ Unit object no longer exists during event processing", 5)
            end
            return "Unknown", "Unknown", 0
        end
        
        local playerName = "AI"
        if unit.getPlayerName then
            local pName = unit:getPlayerName()
            if pName and pName ~= "" then 
                playerName = pName 
            end
        end
        
        local unitName = "Unknown"
        if unit.getName then
            local uName = unit:getName()
            if uName and uName ~= "" then
                unitName = uName
            end
        end
        
        local coalition = 0
        if unit.getCoalition then
            local coal = unit:getCoalition()
            if coal then
                coalition = coal
            end
        end
        
        return playerName, unitName, coalition
    end)
    
    if success and playerName and unitName and coalition then
        return safeString(playerName), safeString(unitName), safeNumber(coalition)
    else
        return "Unknown", "Unknown", 0
    end
end

local function handleShot(event)
    local success, error = pcall(function()
        local shooterName, shooterUnit, shooterCoalition = getEventUnitInfo(event.initiator)
        local weaponName = "Unknown"
        
        if event.weapon then
            local weaponSuccess, wName = pcall(function()
                if event.weapon.getTypeName then
                    return event.weapon:getTypeName()
                end
                return nil
            end)
            
            if weaponSuccess and wName and wName ~= "" then
                weaponName = wName
            end
        end
        
        logEvent("SHOT", string.format("%s (%s) fired %s", 
            safeString(shooterName), safeString(shooterUnit), safeString(weaponName)))
        
        if shooterName ~= "AI" then
            debugMessage("🚀 " .. shooterName .. " fired " .. weaponName, 5)
        end
        
        -- Update statistics
        CombatLogger.stats.events.shots = CombatLogger.stats.events.shots + 1
        
        if CombatLogger.stats.coalitions[shooterCoalition] then
            CombatLogger.stats.coalitions[shooterCoalition].shots = 
                CombatLogger.stats.coalitions[shooterCoalition].shots + 1
        end
        
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
        if CombatLogger.debugMode then
            debugMessage("❌ Shot event error - check unit/weapon objects", 8)
        end
    end
end

local function handleHit(event)
    local success, error = pcall(function()
        local shooterName, shooterUnit, shooterCoalition = getEventUnitInfo(event.initiator)
        local targetName, targetUnit, targetCoalition = getEventUnitInfo(event.target)
        local weaponName = "Unknown"
        
        if event.weapon then
            local weaponSuccess, wName = pcall(function()
                if event.weapon.getTypeName then
                    return event.weapon:getTypeName()
                end
                return nil
            end)
            
            if weaponSuccess and wName and wName ~= "" then
                weaponName = wName
            end
        end
        
        logEvent("HIT", string.format("%s (%s) hit %s (%s) with %s", 
            safeString(shooterName), safeString(shooterUnit), 
            safeString(targetName), safeString(targetUnit), safeString(weaponName)))
        
        if shooterName ~= "AI" or targetName ~= "AI" then
            debugMessage("💥 HIT: " .. shooterName .. " → " .. targetName, 6)
        end
        
        -- Update statistics
        CombatLogger.stats.events.hits = CombatLogger.stats.events.hits + 1
        
        if CombatLogger.stats.coalitions[shooterCoalition] then
            CombatLogger.stats.coalitions[shooterCoalition].hits = 
                CombatLogger.stats.coalitions[shooterCoalition].hits + 1
        end
        
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
        if CombatLogger.debugMode then
            debugMessage("❌ Hit event error - check unit/weapon objects", 8)
        end
    end
end

local function handleKill(event)
    local success, error = pcall(function()
        local killerName, killerUnit, killerCoalition = getEventUnitInfo(event.initiator)
        local victimName, victimUnit, victimCoalition = getEventUnitInfo(event.target)
        local weaponName = "Unknown"
        
        if event.weapon then
            local weaponSuccess, wName = pcall(function()
                if event.weapon.getTypeName then
                    return event.weapon:getTypeName()
                end
                return nil
            end)
            
            if weaponSuccess and wName and wName ~= "" then
                weaponName = wName
            end
        end
        
        logEvent("KILL", string.format("%s (%s) killed %s (%s) with %s", 
            safeString(killerName), safeString(killerUnit), 
            safeString(victimName), safeString(victimUnit), safeString(weaponName)))
        
        if killerName ~= "AI" or victimName ~= "AI" then
            debugMessage("💀 KILL: " .. killerName .. " eliminated " .. victimName, 8)
        end
        
        -- Update statistics
        CombatLogger.stats.events.kills = CombatLogger.stats.events.kills + 1
        CombatLogger.stats.events.deaths = CombatLogger.stats.events.deaths + 1
        
        if CombatLogger.stats.coalitions[killerCoalition] then
            CombatLogger.stats.coalitions[killerCoalition].kills = 
                CombatLogger.stats.coalitions[killerCoalition].kills + 1
        end
        
        if CombatLogger.stats.coalitions[victimCoalition] then
            CombatLogger.stats.coalitions[victimCoalition].deaths = 
                CombatLogger.stats.coalitions[victimCoalition].deaths + 1
        end
        
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
        if CombatLogger.debugMode then
            debugMessage("❌ Kill event error - likely destroyed unit object", 8)
        end
    end
end

local function handleTakeoff(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("TAKEOFF", string.format("%s (%s) took off", 
            safeString(pilotName), safeString(unitName)))
        
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
        
        logEvent("LANDING", string.format("%s (%s) landed", 
            safeString(pilotName), safeString(unitName)))
        
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
        
        logEvent("CRASH", string.format("%s (%s) crashed", 
            safeString(pilotName), safeString(unitName)))
        
        CombatLogger.stats.events.crashes = CombatLogger.stats.events.crashes + 1
    end)
    
    if not success then
        logEvent("ERROR", "Crash handler failed: " .. safeString(error))
    end
end

local function handleEjection(event)
    local success, error = pcall(function()
        local pilotName, unitName, coalition = getEventUnitInfo(event.initiator)
        
        logEvent("EJECTION", string.format("%s ejected from %s", 
            safeString(pilotName), safeString(unitName)))
        
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
        
        -- Show initialization debug messages
        debugMessage("🚀 Combat Logger v" .. CombatLogger.version .. " starting up...", 10)
        debugMessage("🔧 Debug mode: " .. (CombatLogger.debugMode and "ENABLED" or "DISABLED"), 8)
        
        logEvent("SYSTEM", "Combat Logger v" .. CombatLogger.version .. " initialized (Multiplayer Compatible)")
        logEvent("SYSTEM", "Using polling-based player detection for MP compatibility")
        
        -- Log the target file name
        local logFileName = getLogFileName()
        logEvent("SYSTEM", "Target log file: " .. logFileName)
        debugMessage("📝 Target log file: " .. logFileName, 12)
        
        -- Register event handler for reliable events only
        world.addEventHandler(CombatEventHandler)
        debugMessage("✅ Event handlers registered", 8)
        
        -- Start player polling system
        timer.scheduleFunction(checkForPlayers, nil, timer.getTime() + CombatLogger.playerCheckInterval)
        debugMessage("🔄 Player polling started (every " .. CombatLogger.playerCheckInterval .. "s)", 8)
        
        -- Schedule periodic buffer flushes
        timer.scheduleFunction(function()
            flushLogBuffer()
            return timer.getTime() + 30 -- Flush every 30 seconds
        end, nil, timer.getTime() + 30)
        
        -- Schedule periodic status updates (if debug enabled)
        if CombatLogger.debugMode then
            timer.scheduleFunction(function()
                local missionTime = timer.getTime() - CombatLogger.startTime
                local minutes = math.floor(missionTime / 60)
                local playerCount = countTable(CombatLogger.knownPlayers)
                local totalEvents = CombatLogger.stats.events.shots + CombatLogger.stats.events.hits + CombatLogger.stats.events.kills
                
                if totalEvents > 0 or playerCount > 0 then
                    debugMessage(string.format("📊 Status: %dm runtime, %d players, %d events logged", 
                        minutes, playerCount, totalEvents), 8)
                end
                
                return timer.getTime() + 120 -- Status every 2 minutes
            end, nil, timer.getTime() + 120)
        end
        debugMessage("💾 Auto-flush scheduled (every 30s)", 8)
        
        logEvent("SYSTEM", "All systems initialized successfully")
        debugMessage("🎯 Combat Logger fully operational!", 10)
    end)
    
    if not success then
        env.info("COMBAT_LOG: Initialization failed: " .. safeString(error), false)
        debugMessage("❌ CRITICAL: Initialization failed - " .. safeString(error), 20)
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