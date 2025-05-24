# DCS World Combat Logger

A comprehensive Lua script for DCS World that tracks combat events and generates scoreboards for pilots and formations.

## Features

- **Combat Event Tracking**
  - Air-to-air kills
  - Air-to-ground kills
  - Naval kills
  - Pilot deaths, crashes, and ejections
  - Team kills detection
  - Takeoffs and landings
  - Flight time tracking

- **Real-time Feedback**
  - On-screen kill notifications
  - In-game scoreboard display via F10 menu
  - Team kill warnings

- **Data Export**
  - CSV format logging for all events
  - JSON export for statistics
  - Timestamped log files

- **Scoreboard Generation**
  - Pilot performance rankings
  - Multiple scoring categories
  - Automatic score calculation

## Installation

1. Copy `combat_logger.lua` to your DCS mission folder
2. In the Mission Editor, add a trigger:
   - **Type**: Mission Start
   - **Action**: Do Script File
   - **File**: Select `combat_logger.lua`

## Usage

### In-Game Menu (F10)

Once the mission starts, access the Combat Logger menu via F10:
- **Show Scoreboard**: Display current rankings
- **Export Stats**: Save statistics to JSON file
- **Show My Stats**: View personal statistics (requires player identification setup)

### Log Files Location

All logs are saved to:
```
DCS World/Logs/
├── combat_log_YYYYMMDD_HHMMSS.csv
└── combat_stats_YYYYMMDD_HHMMSS.json
```

### CSV Log Format

The CSV file contains the following columns:
- Timestamp
- Event (KILL, TAKEOFF, LANDING, etc.)
- Killer name and details
- Victim name and details
- Weapon used
- Additional details

### Scoring System

The default scoring system:
- Air-to-air kill: +10 points
- Ground kill: +5 points
- Naval kill: +7 points
- Death: -5 points
- Crash: -3 points
- Team kill: -20 points

## Configuration

Edit the configuration section in the script:

```lua
CombatLogger.config = {
    logPath = lfs.writedir() .. "Logs/",
    logToFile = true,              -- Enable/disable file logging
    logToScreen = true,            -- Enable/disable on-screen messages
    screenMessageDuration = 10,     -- Message display time in seconds
    trackFriendlyFire = true,      -- Track team kills
    trackFormations = true,        -- Track formation data
}
```

## Advanced Usage

### Custom Scoring

Modify the scoring formula in `generateScoreboard()`:

```lua
score = (stats.airKills * YOUR_A2A_POINTS + 
         stats.groundKills * YOUR_A2G_POINTS + 
         stats.navalKills * YOUR_NAVAL_POINTS) - 
        (stats.deaths * YOUR_DEATH_PENALTY + 
         stats.crashes * YOUR_CRASH_PENALTY + 
         stats.teamKills * YOUR_TK_PENALTY)
```

### Adding Custom Events

To track additional events, add new handlers in `registerEventHandlers()`:

```lua
elseif event.id == world.event.S_EVENT_YOUR_EVENT then
    CombatLogger:onYourEvent(event)
```

### Formation Tracking

The script includes basic formation tracking through group names. For advanced formation analysis, you can extend the `trackUnit()` function to include formation-specific data.

## Data Analysis

### Using the CSV Export

The CSV file can be imported into:
- Excel/Google Sheets for analysis
- Python/R for statistical analysis
- Database systems for long-term storage

### Using the JSON Export

The JSON file contains structured statistics perfect for:
- Web-based scoreboards
- API integration
- Automated reporting tools

Example JSON structure:
```json
{
  "missionTime": 3600.5,
  "stats": {
    "Pilot Name": {
      "airKills": 5,
      "groundKills": 10,
      "navalKills": 2,
      "deaths": 1,
      "crashes": 0,
      "ejections": 1,
      "teamKills": 0,
      "sorties": 3,
      "flightTime": 2847.3
    }
  }
}
```

## Troubleshooting

### Script Not Loading
- Ensure the script path is correct in the trigger
- Check DCS.log for Lua errors
- Verify file permissions in the DCS folder

### No Logs Created
- Check if `lfs.writedir()` path exists
- Ensure DCS has write permissions
- Look for error messages in DCS.log

### Missing Kills
- Some kills might not register if the killer disconnects immediately
- AI vs AI kills are tracked but pilot name will be the unit name
- Delayed explosions might not attribute kills correctly

## Performance Considerations

- The script is optimized for missions with up to 200 active units
- Large CSV files may impact performance if kept open
- Consider periodic exports and log rotation for long missions

## Future Enhancements

Potential improvements:
- Database integration
- Web-based real-time scoreboard
- Advanced formation statistics
- Weapon accuracy tracking
- Damage dealt tracking
- Mission objective scoring

## License

This script is provided as-is for use in DCS World missions. Feel free to modify and distribute with attribution. 