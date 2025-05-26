--[[
DCS Combat Logger v4.2 - Bug Fixed & Reorganized
================================================

A streamlined combat logging system for DCS World.
Focuses on core functionality with minimal complexity.

Features:
- Logs combat events (shots, hits, kills)
- Uses weapon.getLauncher() for improved accuracy on hits/kills
- Tracks player activity
- Simple file output to DCS.log
- Minimal debug output with data source tracking
- Multiplayer compatible

Installation:
1. Place this file in your mission's trigger "DO SCRIPT FILE" action
2. Logs appear in DCS.log with "COMBAT:" prefix
3. Configure settings in the CONFIGURATION section below

Author: AI Assistant
Version: 4.2 (Bug Fixed & Reorganized)
Date: 2024
--]]

-- ============================================================================
-- CONFIGURATION - All user-configurable parameters
-- ============================================================================

local CONFIG = {
    -- Debug Settings
    DEBUG = true,                      -- Set to false to disable debug messages
    DEBUG_MESSAGE_TIME = 8,            -- How long debug messages stay on screen (seconds)
    
    -- Player Tracking
    PLAYER_CHECK_INTERVAL = 5,         -- How often to check for player changes (seconds)
    
    -- Logging
    LOG_PREFIX = "COMBAT:",            -- Prefix for all log messages
    
    -- Data Defaults
    DEFAULT_STRING = "Unknown",        -- Default value for unknown strings
    DEFAULT_COALITION = 0,             -- Default coalition (0 = neutral)
    AI_PLAYER_NAME = "AI",            -- Name used for AI units
    
    -- Performance
    USE_PCALL = true,                 -- Use protected calls for error handling
}

-- ============================================================================
-- CORE DATA STRUCTURES
-- ============================================================================

local Logger = {
    version = "4.2",
    startTime = 0,
    players = {},
    stats = {
        shots = 0,
        hits = 0,
        kills = 0,
        red = { shots = 0, hits = 0, kills = 0 },
        blue = { shots = 0, hits = 0, kills = 0 }
    }
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function safe(value, default)
    return (value ~= nil) and value or (default or CONFIG.DEFAULT_STRING)
end

local function safeCall(func, ...)
    if CONFIG.USE_PCALL then
        return pcall(func, ...)
    else
        return true, func(...)
    end
end

local function log(message)
    env.info(CONFIG.LOG_PREFIX .. " " .. safe(message))
end

local function debug(message)
    if CONFIG.DEBUG then
        trigger.action.outText("DEBUG: " .. safe(message), CONFIG.DEBUG_MESSAGE_TIME)
        log("DEBUG: " .. safe(message))
    end
end

-- ============================================================================
-- UNIT INFO EXTRACTION
-- ============================================================================

local function getUnitInfo(unit)
    if not unit then 
        return CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_COALITION 
    end
    
    local success, playerName, unitName, coalition = safeCall(function()
        -- Check if unit exists
        if unit.isExist and not unit:isExist() then
            return CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_COALITION
        end
        
        -- Get player name
        local pName = CONFIG.AI_PLAYER_NAME
        if unit.getPlayerName then
            local playerNameResult = unit:getPlayerName()
            if playerNameResult and playerNameResult ~= "" then
                pName = playerNameResult
            end
        end
        
        -- Get unit name/callsign
        local uName = CONFIG.DEFAULT_STRING
        if unit.getName then
            -- First try getCallsign
            if unit.getCallsign then
                local callsign = unit:getCallsign()
                if callsign and callsign ~= "" then
                    uName = callsign
                else
                    -- Fallback to getName if no callsign
                    local name = unit:getName()
                    if name and name ~= "" then
                        uName = name
                    end
                end
            else
                -- No getCallsign method, use getName
                local name = unit:getName()
                if name and name ~= "" then
                    uName = name
                end
            end
        end
        
        -- Get coalition
        local coal = CONFIG.DEFAULT_COALITION
        if unit.getCoalition then
            coal = unit:getCoalition() or CONFIG.DEFAULT_COALITION
        end
        
        return pName, uName, coal
    end)
    
    if success then
        return playerName, unitName, coalition
    else
        return CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_STRING, CONFIG.DEFAULT_COALITION
    end
end

local function getWeaponName(weapon)
    if not weapon then return CONFIG.DEFAULT_STRING end
    
    local success, name = safeCall(function()
        if weapon.getTypeName then
            return weapon:getTypeName() or CONFIG.DEFAULT_STRING
        end
        return CONFIG.DEFAULT_STRING
    end)
    
    return success and name or CONFIG.DEFAULT_STRING
end

-- Get launcher info from weapon (more accurate than event.initiator for hits/kills)
local function getLauncherInfo(weapon)
    if not weapon then return nil end
    
    local success, launcher = safeCall(function()
        if weapon.getLauncher then
            return weapon:getLauncher()
        end
        return nil
    end)
    
    return success and launcher or nil
end

-- Get best available shooter info (tries weapon launcher first, falls back to event initiator)
local function getBestShooterInfo(event)
    local shooterUnit = nil
    local source = "event"
    
    -- Try to get launcher from weapon first (more accurate for hits/kills)
    if event and event.weapon then
        local launcher = getLauncherInfo(event.weapon)
        if launcher then
            shooterUnit = launcher
            source = "weapon"
        end
    end
    
    -- Fall back to event initiator if no launcher found
    if not shooterUnit and event and event.initiator then
        shooterUnit = event.initiator
        source = "event"
    end
    
    local shooterName, unitName, coalition = getUnitInfo(shooterUnit)
    return shooterName, unitName, coalition, source
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local function handleShot(event)
    if not event then return end
    
    local success = safeCall(function()
        -- For shots, event.initiator is usually most accurate
        local shooterName, shooterUnit, coalition = getUnitInfo(event.initiator)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("SHOT: %s (%s) fired %s", 
            safe(shooterName), safe(shooterUnit), safe(weaponName)))
        
        -- Update stats
        Logger.stats.shots = Logger.stats.shots + 1
        if coalition == 1 then
            Logger.stats.red.shots = Logger.stats.red.shots + 1
        elseif coalition == 2 then
            Logger.stats.blue.shots = Logger.stats.blue.shots + 1
        end
        
        -- Debug for players only
        if shooterName ~= CONFIG.AI_PLAYER_NAME and CONFIG.DEBUG then
            debug(shooterName .. " fired " .. weaponName)
        end
    end)
    
    if not success then
        log("ERROR: Shot handler failed")
    end
end

local function handleHit(event)
    if not event then return end
    
    local success = safeCall(function()
        -- Use getLauncher for more accurate shooter info on hits
        local shooterName, shooterUnit, shooterCoalition, source = getBestShooterInfo(event)
        local targetName, targetUnit, targetCoalition = getUnitInfo(event.target)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("HIT: %s (%s) hit %s (%s) with %s", 
            safe(shooterName), safe(shooterUnit), safe(targetName), safe(targetUnit), safe(weaponName)))
        
        -- Update stats
        Logger.stats.hits = Logger.stats.hits + 1
        if shooterCoalition == 1 then
            Logger.stats.red.hits = Logger.stats.red.hits + 1
        elseif shooterCoalition == 2 then
            Logger.stats.blue.hits = Logger.stats.blue.hits + 1
        end
        
        -- Debug for player involvement (show data source for troubleshooting)
        if (shooterName ~= CONFIG.AI_PLAYER_NAME or targetName ~= CONFIG.AI_PLAYER_NAME) and CONFIG.DEBUG then
            debug(string.format("HIT: %s → %s (%s)", 
                safe(shooterName), safe(targetName), safe(source)))
        end
    end)
    
    if not success then
        log("ERROR: Hit handler failed")
    end
end

local function handleKill(event)
    if not event then return end
    
    local success = safeCall(function()
        -- Use getLauncher for more accurate shooter info on kills
        local killerName, killerUnit, killerCoalition, source = getBestShooterInfo(event)
        local victimName, victimUnit, victimCoalition = getUnitInfo(event.target)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("KILL: %s (%s) killed %s (%s) with %s", 
            safe(killerName), safe(killerUnit), safe(victimName), safe(victimUnit), safe(weaponName)))
        
        -- Update stats
        Logger.stats.kills = Logger.stats.kills + 1
        if killerCoalition == 1 then
            Logger.stats.red.kills = Logger.stats.red.kills + 1
        elseif killerCoalition == 2 then
            Logger.stats.blue.kills = Logger.stats.blue.kills + 1
        end
        
        -- Debug for player involvement (show data source for troubleshooting)
        if (killerName ~= CONFIG.AI_PLAYER_NAME or victimName ~= CONFIG.AI_PLAYER_NAME) and CONFIG.DEBUG then
            debug(string.format("KILL: %s eliminated %s (%s)", 
                safe(killerName), safe(victimName), safe(source)))
        end
    end)
    
    if not success then
        log("ERROR: Kill handler failed")
    end
end

-- ============================================================================
-- PLAYER TRACKING
-- ============================================================================

local function checkPlayers()
    local success = safeCall(function()
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
                                if unit and unit.isExist and unit:isExist() then
                                    local playerName, unitName, coal = getUnitInfo(unit)
                                    if playerName and playerName ~= CONFIG.AI_PLAYER_NAME then
                                        local playerId = playerName .. "_" .. unitName
                                        currentPlayers[playerId] = {
                                            name = playerName,
                                            unit = unitName,
                                            coalition = coal
                                        }
                                        
                                        -- New player?
                                        if not Logger.players[playerId] then
                                            log(string.format("PLAYER_JOIN: %s entered %s", 
                                                safe(playerName), safe(unitName)))
                                            if CONFIG.DEBUG then
                                                debug("Player joined: " .. safe(playerName))
                                            end
                                            Logger.players[playerId] = currentPlayers[playerId]
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check for players who left
        for playerId, playerInfo in pairs(Logger.players) do
            if not currentPlayers[playerId] then
                log(string.format("PLAYER_LEAVE: %s left %s", 
                    safe(playerInfo.name), safe(playerInfo.unit)))
                if CONFIG.DEBUG then
                    debug("Player left: " .. safe(playerInfo.name))
                end
                Logger.players[playerId] = nil
            end
        end
    end)
    
    if not success then
        log("ERROR: Player check failed")
    end
    
    -- Schedule next check
    return timer.getTime() + CONFIG.PLAYER_CHECK_INTERVAL
end

-- ============================================================================
-- MAIN EVENT HANDLER
-- ============================================================================

local EventHandler = {}

function EventHandler:onEvent(event)
    if not event or not event.id then return end
    
    if event.id == world.event.S_EVENT_SHOT then
        handleShot(event)
    elseif event.id == world.event.S_EVENT_HIT then
        handleHit(event)
    elseif event.id == world.event.S_EVENT_KILL then
        handleKill(event)
    end
end

-- ============================================================================
-- MISSION SUMMARY
-- ============================================================================

local function generateSummary()
    local success = safeCall(function()
        local runtime = timer.getTime() - Logger.startTime
        local minutes = math.floor(runtime / 60)
        
        log("=== MISSION SUMMARY ===")
        log(string.format("Runtime: %d minutes", minutes))
        log(string.format("Total: Shots=%d, Hits=%d, Kills=%d", 
            Logger.stats.shots, Logger.stats.hits, Logger.stats.kills))
        log(string.format("Red: Shots=%d, Hits=%d, Kills=%d", 
            Logger.stats.red.shots, Logger.stats.red.hits, Logger.stats.red.kills))
        log(string.format("Blue: Shots=%d, Hits=%d, Kills=%d", 
            Logger.stats.blue.shots, Logger.stats.blue.hits, Logger.stats.blue.kills))
        log("=== END SUMMARY ===")
    end)
    
    if not success then
        log("ERROR: Summary generation failed")
    end
end

local SummaryHandler = {}

function SummaryHandler:onEvent(event)
    if event and event.id == world.event.S_EVENT_MISSION_END then
        generateSummary()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function initialize()
    local success = safeCall(function()
        Logger.startTime = timer.getTime()
        
        log(string.format("Combat Logger v%s initialized", Logger.version))
        if CONFIG.DEBUG then
            debug(string.format("Combat Logger v%s started - Debug mode ON", Logger.version))
        end
        
        -- Register event handlers
        world.addEventHandler(EventHandler)
        world.addEventHandler(SummaryHandler)
        
        -- Start player polling
        timer.scheduleFunction(checkPlayers, nil, timer.getTime() + CONFIG.PLAYER_CHECK_INTERVAL)
        
        log("All systems operational")
        if CONFIG.DEBUG then
            debug("Logger ready - tracking combat events")
        end
    end)
    
    if not success then
        env.info(CONFIG.LOG_PREFIX .. " CRITICAL - Initialization failed")
    end
end

-- ============================================================================
-- START
-- ============================================================================

initialize() 