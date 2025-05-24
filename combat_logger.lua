-- DCS World Combat Logger Script
-- Logs air-to-air kills, air-to-ground kills, and other combat events
-- Designed for easy scoreboard generation

local CombatLogger = {}
CombatLogger.version = "1.0.0"
CombatLogger.logFile = nil
CombatLogger.logFileName = "combat_log_" .. os.date("%Y%m%d_%H%M%S") .. ".csv"
CombatLogger.stats = {}
CombatLogger.activeUnits = {}

-- Configuration
CombatLogger.config = {
    logPath = lfs.writedir() .. "Logs/",
    logToFile = true,
    logToScreen = true,
    screenMessageDuration = 10,
    trackFriendlyFire = true,
    trackFormations = true,
}

-- Initialize the logger
function CombatLogger:init()
    -- Create logs directory if it doesn't exist
    lfs.mkdir(self.config.logPath)
    
    -- Open log file
    if self.config.logToFile then
        self.logFile = io.open(self.config.logPath .. self.logFileName, "w")
        if self.logFile then
            -- Write CSV header
            self.logFile:write("Timestamp,Event,Killer,KillerType,KillerCoalition,KillerCountry,Victim,VictimType,VictimCoalition,VictimCountry,Weapon,Details\n")
            self.logFile:flush()
        end
    end
    
    -- Register event handlers
    self:registerEventHandlers()
    
    -- Initial scan of all units
    self:scanAllUnits()
    
    self:log("CombatLogger initialized - Version " .. self.version)
end

-- Register DCS event handlers
function CombatLogger:registerEventHandlers()
    local eventHandler = {}
    
    function eventHandler:onEvent(event)
        if event.id == world.event.S_EVENT_KILL then
            CombatLogger:onKill(event)
        elseif event.id == world.event.S_EVENT_PILOT_DEAD then
            CombatLogger:onPilotDead(event)
        elseif event.id == world.event.S_EVENT_CRASH then
            CombatLogger:onCrash(event)
        elseif event.id == world.event.S_EVENT_EJECTION then
            CombatLogger:onEjection(event)
        elseif event.id == world.event.S_EVENT_HIT then
            CombatLogger:onHit(event)
        elseif event.id == world.event.S_EVENT_TAKEOFF then
            CombatLogger:onTakeoff(event)
        elseif event.id == world.event.S_EVENT_LAND then
            CombatLogger:onLand(event)
        elseif event.id == world.event.S_EVENT_BIRTH then
            CombatLogger:onBirth(event)
        elseif event.id == world.event.S_EVENT_DEAD then
            CombatLogger:onDead(event)
        end
    end
    
    world.addEventHandler(eventHandler)
end

-- Scan all units at mission start
function CombatLogger:scanAllUnits()
    for _, coalition in pairs({coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}) do
        for _, unitType in pairs({"plane", "helicopter", "vehicle", "ship", "static"}) do
            local groups = coalition.getGroups(coalition, Group.Category[string.upper(unitType)])
            if groups then
                for _, group in pairs(groups) do
                    local units = group:getUnits()
                    if units then
                        for _, unit in pairs(units) do
                            if unit and unit:isExist() then
                                self:trackUnit(unit)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Track a unit
function CombatLogger:trackUnit(unit)
    if not unit or not unit:isExist() then return end
    
    local unitName = unit:getName()
    local unitType = unit:getTypeName()
    local unitCoalition = unit:getCoalition()
    local unitCountry = unit:getCountry()
    local pilotName = self:getPilotName(unit)
    
    self.activeUnits[unitName] = {
        type = unitType,
        coalition = unitCoalition,
        country = unitCountry,
        pilot = pilotName,
        group = unit:getGroup() and unit:getGroup():getName() or "Unknown",
        startTime = timer.getTime()
    }
    
    -- Initialize stats for pilot
    if pilotName and pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
    end
end

-- Initialize pilot statistics
function CombatLogger:initPilotStats(pilotName)
    if not self.stats[pilotName] then
        self.stats[pilotName] = {
            airKills = 0,
            groundKills = 0,
            navalKills = 0,
            deaths = 0,
            crashes = 0,
            ejections = 0,
            teamKills = 0,
            sorties = 0,
            flightTime = 0,
            lastTakeoff = nil,
            kills = {},
            deaths_detail = {}
        }
    end
end

-- Get pilot name from unit
function CombatLogger:getPilotName(unit)
    if not unit or not unit:isExist() then return "Unknown" end
    
    -- Try to get pilot name
    local unitName = unit:getName()
    
    -- For single-seat aircraft, the pilot name might be stored as a property
    -- This is a simplified approach - in real missions you might have a pilot roster
    local pilotName = unit:getPlayerName()
    
    if not pilotName or pilotName == "" then
        -- Use unit name as fallback
        pilotName = unitName
    end
    
    return pilotName
end

-- Get unit details
function CombatLogger:getUnitDetails(unit)
    if not unit or not unit:isExist() then
        return "Unknown", "Unknown", -1, -1
    end
    
    local unitType = unit:getTypeName() or "Unknown"
    local unitName = unit:getName() or "Unknown"
    local unitCoalition = unit:getCoalition() or -1
    local unitCountry = unit:getCountry() or -1
    
    return unitType, unitName, unitCoalition, unitCountry
end

-- Event handlers
function CombatLogger:onKill(event)
    local killer = event.initiator
    local victim = event.target
    local weapon = event.weapon
    
    if not victim then return end
    
    local killerType, killerName, killerCoalition, killerCountry = self:getUnitDetails(killer)
    local victimType, victimName, victimCoalition, victimCountry = self:getUnitDetails(victim)
    local weaponType = weapon and weapon:getTypeName() or "Unknown"
    
    local killerPilot = killer and self:getPilotName(killer) or "Unknown"
    local victimPilot = victim and self:getPilotName(victim) or "Unknown"
    
    -- Determine kill type
    local killType = "Unknown"
    local victimCategory = victim:getCategory()
    
    if victimCategory == Object.Category.UNIT then
        local victimDesc = victim:getDesc()
        if victimDesc then
            if victimDesc.category == Unit.Category.AIRPLANE or victimDesc.category == Unit.Category.HELICOPTER then
                killType = "Air"
            elseif victimDesc.category == Unit.Category.GROUND_UNIT then
                killType = "Ground"
            elseif victimDesc.category == Unit.Category.SHIP then
                killType = "Naval"
            end
        end
    elseif victimCategory == Object.Category.STATIC then
        killType = "Static"
    end
    
    -- Check for team kill
    local isTeamKill = (killerCoalition == victimCoalition) and killerCoalition ~= -1
    
    -- Update statistics
    if killerPilot ~= "Unknown" then
        self:initPilotStats(killerPilot)
        
        if killType == "Air" then
            self.stats[killerPilot].airKills = self.stats[killerPilot].airKills + 1
        elseif killType == "Ground" or killType == "Static" then
            self.stats[killerPilot].groundKills = self.stats[killerPilot].groundKills + 1
        elseif killType == "Naval" then
            self.stats[killerPilot].navalKills = self.stats[killerPilot].navalKills + 1
        end
        
        if isTeamKill then
            self.stats[killerPilot].teamKills = self.stats[killerPilot].teamKills + 1
        end
        
        -- Record detailed kill info
        table.insert(self.stats[killerPilot].kills, {
            time = timer.getTime(),
            victim = victimName,
            victimType = victimType,
            weapon = weaponType,
            killType = killType,
            teamKill = isTeamKill
        })
    end
    
    -- Log the kill
    local details = string.format("Kill Type: %s%s", killType, isTeamKill and " (TEAM KILL)" or "")
    self:logEvent("KILL", killerPilot, killerType, killerCoalition, killerCountry, 
                  victimPilot, victimType, victimCoalition, victimCountry, weaponType, details)
    
    -- Screen message
    if self.config.logToScreen then
        local message = string.format("%s killed %s (%s) with %s%s", 
                                    killerPilot, victimName, killType, weaponType,
                                    isTeamKill and " [TEAM KILL]" or "")
        trigger.action.outText(message, self.config.screenMessageDuration)
    end
end

function CombatLogger:onPilotDead(event)
    local unit = event.initiator
    if not unit then return end
    
    local pilotName = self:getPilotName(unit)
    if pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
        self.stats[pilotName].deaths = self.stats[pilotName].deaths + 1
        
        local unitType, unitName, unitCoalition, unitCountry = self:getUnitDetails(unit)
        self:logEvent("PILOT_DEAD", pilotName, unitType, unitCoalition, unitCountry, 
                      "", "", -1, -1, "", "Pilot killed")
    end
end

function CombatLogger:onCrash(event)
    local unit = event.initiator
    if not unit then return end
    
    local pilotName = self:getPilotName(unit)
    if pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
        self.stats[pilotName].crashes = self.stats[pilotName].crashes + 1
        
        local unitType, unitName, unitCoalition, unitCountry = self:getUnitDetails(unit)
        self:logEvent("CRASH", pilotName, unitType, unitCoalition, unitCountry, 
                      "", "", -1, -1, "", "Aircraft crashed")
    end
end

function CombatLogger:onEjection(event)
    local unit = event.initiator
    if not unit then return end
    
    local pilotName = self:getPilotName(unit)
    if pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
        self.stats[pilotName].ejections = self.stats[pilotName].ejections + 1
        
        local unitType, unitName, unitCoalition, unitCountry = self:getUnitDetails(unit)
        self:logEvent("EJECTION", pilotName, unitType, unitCoalition, unitCountry, 
                      "", "", -1, -1, "", "Pilot ejected")
    end
end

function CombatLogger:onTakeoff(event)
    local unit = event.initiator
    if not unit then return end
    
    local pilotName = self:getPilotName(unit)
    if pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
        self.stats[pilotName].sorties = self.stats[pilotName].sorties + 1
        self.stats[pilotName].lastTakeoff = timer.getTime()
        
        local unitType, unitName, unitCoalition, unitCountry = self:getUnitDetails(unit)
        self:logEvent("TAKEOFF", pilotName, unitType, unitCoalition, unitCountry, 
                      "", "", -1, -1, "", "Takeoff")
    end
end

function CombatLogger:onLand(event)
    local unit = event.initiator
    if not unit then return end
    
    local pilotName = self:getPilotName(unit)
    if pilotName ~= "Unknown" then
        self:initPilotStats(pilotName)
        
        -- Calculate flight time
        if self.stats[pilotName].lastTakeoff then
            local flightTime = timer.getTime() - self.stats[pilotName].lastTakeoff
            self.stats[pilotName].flightTime = self.stats[pilotName].flightTime + flightTime
            self.stats[pilotName].lastTakeoff = nil
        end
        
        local unitType, unitName, unitCoalition, unitCountry = self:getUnitDetails(unit)
        self:logEvent("LANDING", pilotName, unitType, unitCoalition, unitCountry, 
                      "", "", -1, -1, "", "Landing")
    end
end

function CombatLogger:onBirth(event)
    local unit = event.initiator
    if unit then
        self:trackUnit(unit)
    end
end

function CombatLogger:onDead(event)
    local unit = event.initiator
    if not unit then return end
    
    local unitName = unit:getName()
    if self.activeUnits[unitName] then
        self.activeUnits[unitName] = nil
    end
end

function CombatLogger:onHit(event)
    -- Optional: Track hits for damage assessment
    -- This can generate a lot of data, so it's not logged by default
end

-- Log event to file
function CombatLogger:logEvent(eventType, killer, killerType, killerCoalition, killerCountry, 
                              victim, victimType, victimCoalition, victimCountry, weapon, details)
    if not self.config.logToFile or not self.logFile then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("%s,%s,%s,%s,%d,%d,%s,%s,%d,%d,%s,%s\n",
                              timestamp, eventType, killer or "", killerType or "", 
                              killerCoalition or -1, killerCountry or -1,
                              victim or "", victimType or "", 
                              victimCoalition or -1, victimCountry or -1,
                              weapon or "", details or "")
    
    self.logFile:write(line)
    self.logFile:flush()
end

-- Log general message
function CombatLogger:log(message)
    if self.config.logToFile and self.logFile then
        self.logFile:write(os.date("%Y-%m-%d %H:%M:%S") .. ",INFO,,,,,,,,,,," .. message .. "\n")
        self.logFile:flush()
    end
end

-- Generate scoreboard
function CombatLogger:generateScoreboard(coalition)
    local scoreboard = {}
    
    for pilotName, stats in pairs(self.stats) do
        -- Optionally filter by coalition
        local include = true
        if coalition then
            -- Need to check pilot's coalition from active units or kills
            include = false -- Implement coalition filtering logic if needed
        end
        
        if include then
            table.insert(scoreboard, {
                pilot = pilotName,
                airKills = stats.airKills,
                groundKills = stats.groundKills,
                navalKills = stats.navalKills,
                totalKills = stats.airKills + stats.groundKills + stats.navalKills,
                deaths = stats.deaths,
                crashes = stats.crashes,
                ejections = stats.ejections,
                teamKills = stats.teamKills,
                sorties = stats.sorties,
                flightTime = stats.flightTime,
                score = (stats.airKills * 10 + stats.groundKills * 5 + stats.navalKills * 7) 
                        - (stats.deaths * 5 + stats.crashes * 3 + stats.teamKills * 20)
            })
        end
    end
    
    -- Sort by score
    table.sort(scoreboard, function(a, b) return a.score > b.score end)
    
    return scoreboard
end

-- Display scoreboard in game
function CombatLogger:displayScoreboard(duration)
    duration = duration or 30
    
    local scoreboard = self:generateScoreboard()
    local message = "=== COMBAT SCOREBOARD ===\n\n"
    message = message .. string.format("%-20s %4s %4s %4s %4s %4s %5s\n", 
                                      "PILOT", "A2A", "A2G", "SEA", "DEAD", "TK", "SCORE")
    message = message .. string.rep("-", 60) .. "\n"
    
    for i, entry in ipairs(scoreboard) do
        if i <= 10 then -- Show top 10
            message = message .. string.format("%-20s %4d %4d %4d %4d %4d %5d\n",
                                             entry.pilot:sub(1, 20),
                                             entry.airKills,
                                             entry.groundKills,
                                             entry.navalKills,
                                             entry.deaths,
                                             entry.teamKills,
                                             entry.score)
        end
    end
    
    trigger.action.outText(message, duration)
end

-- Export statistics to JSON file
function CombatLogger:exportStats()
    local jsonFile = io.open(self.config.logPath .. "combat_stats_" .. os.date("%Y%m%d_%H%M%S") .. ".json", "w")
    if jsonFile then
        -- Simple JSON serialization
        jsonFile:write("{\n")
        jsonFile:write('  "missionTime": ' .. timer.getTime() .. ',\n')
        jsonFile:write('  "stats": {\n')
        
        local first = true
        for pilotName, stats in pairs(self.stats) do
            if not first then jsonFile:write(",\n") end
            first = false
            
            jsonFile:write('    "' .. pilotName .. '": {\n')
            jsonFile:write('      "airKills": ' .. stats.airKills .. ',\n')
            jsonFile:write('      "groundKills": ' .. stats.groundKills .. ',\n')
            jsonFile:write('      "navalKills": ' .. stats.navalKills .. ',\n')
            jsonFile:write('      "deaths": ' .. stats.deaths .. ',\n')
            jsonFile:write('      "crashes": ' .. stats.crashes .. ',\n')
            jsonFile:write('      "ejections": ' .. stats.ejections .. ',\n')
            jsonFile:write('      "teamKills": ' .. stats.teamKills .. ',\n')
            jsonFile:write('      "sorties": ' .. stats.sorties .. ',\n')
            jsonFile:write('      "flightTime": ' .. stats.flightTime .. '\n')
            jsonFile:write('    }')
        end
        
        jsonFile:write('\n  }\n')
        jsonFile:write('}\n')
        jsonFile:close()
        
        self:log("Statistics exported to JSON")
    end
end

-- Cleanup function
function CombatLogger:cleanup()
    if self.logFile then
        self:log("CombatLogger shutting down")
        self:exportStats()
        self.logFile:close()
    end
end

-- F10 menu functions for in-game access
function CombatLogger:setupF10Menu()
    local rootMenu = missionCommands.addSubMenu("Combat Logger")
    
    missionCommands.addCommand("Show Scoreboard", rootMenu, function()
        CombatLogger:displayScoreboard(30)
    end)
    
    missionCommands.addCommand("Export Stats", rootMenu, function()
        CombatLogger:exportStats()
        trigger.action.outText("Combat statistics exported to file", 10)
    end)
    
    missionCommands.addCommand("Show My Stats", rootMenu, function()
        -- This would need to identify the calling player
        trigger.action.outText("Player stats feature requires player identification", 10)
    end)
end

-- Initialize the logger
CombatLogger:init()
CombatLogger:setupF10Menu()

-- Return the module
return CombatLogger 