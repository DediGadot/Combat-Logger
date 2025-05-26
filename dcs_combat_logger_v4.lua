--[[
DCS Combat Logger v4.1 - Simplified with getLauncher
====================================================

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
3. Set DEBUG = false to disable debug messages

Author: AI Assistant
Version: 4.1 (Simplified with getLauncher)
Date: 2024
--]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local DEBUG = true  -- Set to false to disable debug messages

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function safe(value, default)
    return (value ~= nil) and value or (default or "Unknown")
end

local function log(message)
    env.info("COMBAT: " .. safe(message), false)
end

local function debug(message)
    if DEBUG then
        trigger.action.outText("DEBUG: " .. safe(message), 8)
        log("DEBUG: " .. safe(message))
    end
end

-- ============================================================================
-- CORE DATA
-- ============================================================================

local Logger = {
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
-- UNIT INFO EXTRACTION
-- ============================================================================

local function getUnitInfo(unit)
    if not unit then return "Unknown", "Unknown", 0 end
    
    local success, result = pcall(function()
        -- Check if unit exists
        if unit.isExist and not unit:isExist() then
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
            unitName = unit:getCallsign() or "Unknown"
        end
        
        local coalition = 0
        if unit.getCoalition then
            coalition = unit:getCoalition() or 0
        end
        
        return playerName, unitName, coalition
    end)
    
    if success and result then
        return result
    else
        return "Unknown", "Unknown", 0
    end
end

local function getWeaponName(weapon)
    if not weapon then return "Unknown" end
    
    local success, name = pcall(function()
        if weapon.getTypeName then
            return weapon:getTypeName()
        end
        return "Unknown"
    end)
    
    return success and name or "Unknown"
end

-- Get launcher info from weapon (more accurate than event.initiator for hits/kills)
local function getLauncherInfo(weapon)
    if not weapon then return nil end
    
    local success, launcher = pcall(function()
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
    if event.weapon then
        local launcher = getLauncherInfo(event.weapon)
        if launcher then
            shooterUnit = launcher
            source = "weapon"
        end
    end
    
    -- Fall back to event initiator if no launcher found
    if not shooterUnit and event.initiator then
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
    local success = pcall(function()
        -- For shots, event.initiator is usually most accurate
        local shooterName, shooterUnit, coalition = getUnitInfo(event.initiator)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("SHOT: %s (%s) fired %s", shooterName, shooterUnit, weaponName))
        
        -- Update stats
        Logger.stats.shots = Logger.stats.shots + 1
        if coalition == 1 then
            Logger.stats.red.shots = Logger.stats.red.shots + 1
        elseif coalition == 2 then
            Logger.stats.blue.shots = Logger.stats.blue.shots + 1
        end
        
        -- Debug for players only
        if shooterName ~= "AI" and DEBUG then
            debug(shooterName .. " fired " .. weaponName)
        end
    end)
    
    if not success then
        log("ERROR: Shot handler failed")
    end
end

local function handleHit(event)
    local success = pcall(function()
        -- Use getLauncher for more accurate shooter info on hits
        local shooterName, shooterUnit, shooterCoalition, source = getBestShooterInfo(event)
        local targetName, targetUnit, targetCoalition = getUnitInfo(event.target)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("HIT: %s (%s) hit %s with %s", shooterName, shooterUnit, targetName, weaponName))
        
        -- Update stats
        Logger.stats.hits = Logger.stats.hits + 1
        if shooterCoalition == 1 then
            Logger.stats.red.hits = Logger.stats.red.hits + 1
        elseif shooterCoalition == 2 then
            Logger.stats.blue.hits = Logger.stats.blue.hits + 1
        end
        
        -- Debug for player involvement (show data source for troubleshooting)
        if (shooterName ~= "AI" or targetName ~= "AI") and DEBUG then
            debug(string.format("HIT: %s → %s (%s)", shooterName, targetName, source))
        end
    end)
    
    if not success then
        log("ERROR: Hit handler failed")
    end
end

local function handleKill(event)
    local success = pcall(function()
        -- Use getLauncher for more accurate shooter info on kills
        local killerName, killerUnit, killerCoalition, source = getBestShooterInfo(event)
        local victimName, victimUnit, victimCoalition = getUnitInfo(event.target)
        local weaponName = getWeaponName(event.weapon)
        
        log(string.format("KILL: %s (%s) killed %s with %s", killerName, killerUnit, victimName, weaponName))
        
        -- Update stats
        Logger.stats.kills = Logger.stats.kills + 1
        if killerCoalition == 1 then
            Logger.stats.red.kills = Logger.stats.red.kills + 1
        elseif killerCoalition == 2 then
            Logger.stats.blue.kills = Logger.stats.blue.kills + 1
        end
        
        -- Debug for player involvement (show data source for troubleshooting)
        if (killerName ~= "AI" or victimName ~= "AI") and DEBUG then
            debug(string.format("KILL: %s eliminated %s (%s)", killerName, victimName, source))
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
    local success = pcall(function()
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
                                if unit then
                                    local playerName, unitName, coal = getUnitInfo(unit)
                                    if playerName and playerName ~= "AI" then
                                        local playerId = playerName .. "_" .. unitName
                                        currentPlayers[playerId] = {
                                            name = playerName,
                                            unit = unitName,
                                            coalition = coal
                                        }
                                        
                                        -- New player?
                                        if not Logger.players[playerId] then
                                            log("PLAYER_JOIN: " .. playerName .. " entered " .. unitName)
                                            if DEBUG then
                                                debug("Player joined: " .. playerName)
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
                log("PLAYER_LEAVE: " .. playerInfo.name .. " left " .. playerInfo.unit)
                if DEBUG then
                    debug("Player left: " .. playerInfo.name)
                end
                Logger.players[playerId] = nil
            end
        end
    end)
    
    if not success then
        log("ERROR: Player check failed")
    end
    
    -- Schedule next check
    return timer.getTime() + 5
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
    local success = pcall(function()
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
    if event.id == world.event.S_EVENT_MISSION_END then
        generateSummary()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function initialize()
    local success = pcall(function()
        Logger.startTime = timer.getTime()
        
        log("Combat Logger v4.1 initialized")
        if DEBUG then
            debug("Combat Logger v4.1 started - Debug mode ON")
        end
        
        -- Register event handlers
        world.addEventHandler(EventHandler)
        world.addEventHandler(SummaryHandler)
        
        -- Start player polling
        timer.scheduleFunction(checkPlayers, nil, timer.getTime() + 5)
        
        log("All systems operational")
        if DEBUG then
            debug("Logger ready - tracking combat events")
        end
    end)
    
    if not success then
        env.info("COMBAT: CRITICAL - Initialization failed", false)
    end
end

-- ============================================================================
-- START
-- ============================================================================

initialize() 