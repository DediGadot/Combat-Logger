# DCS World Combat Event Logger

A comprehensive Lua scripting solution for logging air-to-air combat events in DCS World missions. This tool provides detailed event tracking for post-mission analysis of pilot and formation performance.

## Overview

This project provides two Lua scripts for DCS World that log combat events during missions:

1. **`dcs_combat_logger.lua`** - Full-featured version with advanced JSON logging (requires MIST)
2. **`dcs_combat_logger_simple.lua`** - Enhanced standalone version with comprehensive event tracking (v2.0)

Both scripts track combat events but differ in dependencies and complexity.

## Features

### Events Tracked (v2.0 Simple Logger)
- **Birth Events** - Aircraft spawning
- **Weapon Shots** - All missile, bomb, and rocket launches with target tracking
- **Weapon Hits** - Successful weapon impacts on targets
- **Aircraft Kills** - Confirmed aircraft destructions with weapon attribution
- **Aircraft Deaths** - Aircraft losses and crashes
- **Pilot Ejections** - Emergency ejections
- **Takeoffs and Landings** - Flight operations with airbase tracking
- **Engine Events** - Engine startup and shutdown
- **Refueling Events** - Aerial refueling operations
- **Mission Events** - Mission start/end lifecycle

### Statistics Generated
- **Per Pilot Statistics**:
  - Shots fired by weapon type
  - Hits scored on targets
  - Kill/Death ratio
  - Hit efficiency percentage
  - Aircraft type and coalition
  - Flight time tracking
  - Takeoffs, landings, ejections, crashes
  - Weapons used and targets engaged
  - Detailed kill tracking

- **Per Formation Statistics**:
  - Total shots, hits, kills, losses
  - Formation member tracking
  - First contact time
  - Combat effectiveness

- **Coalition Summary**:
  - Red vs Blue kills/losses comparison
  - Total shots fired per side
  - Overall combat effectiveness

## Installation

### Method 1: Mission Editor (Recommended)

1. Open your mission in the DCS Mission Editor
2. Go to **Triggers** tab
3. Create a new trigger:
   - **Event**: Mission Start
   - **Condition**: Time More (1 second)
   - **Action**: Do Script
4. Copy and paste the entire content of either script file
5. Save your mission

### Method 2: External Script File

1. Place the script file in your mission folder
2. In Mission Editor, create a trigger:
   - **Event**: Mission Start
   - **Condition**: Time More (1 second)
   - **Action**: Do Script File
   - **File**: Select your script file

## Script Versions

### Full Version (`dcs_combat_logger.lua`)

**Requirements**: MIST (Mission Scripting Tools)

**Features**:
- Advanced JSON logging format
- Detailed event data structures
- Real-time event streaming
- Enhanced error handling
- Position tracking
- Weapon target information

**Use Case**: Advanced analysis, integration with external tools

### Simple Version (`dcs_combat_logger_simple.lua`) - v2.0

**Requirements**: None (standalone)

**New Features in v2.0**:
- Comprehensive event tracking (birth, engine, refueling)
- Enhanced pilot statistics with K/D ratio and efficiency
- Improved error handling with pcall protection
- Better coalition tracking (Red/Blue/Neutral)
- Aircraft category detection (plane/helicopter)
- Weapon launcher tracking
- Flight time calculation
- Combat effectiveness summary
- Cleaner log format with event levels

**Use Case**: Production missions, comprehensive analysis, no dependencies

## Output Files

Log data is output to the DCS.log file:
```
%USERPROFILE%\Saved Games\DCS\Logs\DCS.log
```

**Note**: The simple version (v2.0) outputs all data to the DCS.log file to avoid file system permission issues. All combat events are prefixed with "COMBAT_LOG:" for easy filtering.

### Log Format
- All events are logged to DCS.log with "COMBAT_LOG:" prefix
- Real-time event logging during mission
- Complete mission summary at mission end

### Log File Structure (v2.0)

#### Enhanced Simple Version Format (in DCS.log)
```
COMBAT_LOG: === DCS COMBAT EVENT LOG ===
COMBAT_LOG: Version: 2.0 (Simplified & Enhanced)
COMBAT_LOG: Mission: Caucasus
COMBAT_LOG: Start Time: 12345
COMBAT_LOG: ========================================
COMBAT_LOG: 
COMBAT_LOG: [00000.00] [INFO ] Combat logger initialized successfully
COMBAT_LOG: [00012.34] [EVENT] BIRTH: Viper-1 (F-16C_50) spawned
COMBAT_LOG: [00045.23] [EVENT] SHOT: Viper-1 (F-16C_50) fired AIM-120C at Flanker-1
COMBAT_LOG: [00047.15] [EVENT] HIT: Viper-1 hit Flanker-1 with AIM-120C
COMBAT_LOG: [00047.16] [EVENT] KILL: Viper-1 killed Flanker-1 with AIM-120C

COMBAT_LOG: ========================================
COMBAT_LOG: === MISSION SUMMARY ===
COMBAT_LOG: Total Events: 156
COMBAT_LOG: Mission Duration: 45.2 minutes
COMBAT_LOG: Total Pilots: 8
COMBAT_LOG: Total Formations: 2
COMBAT_LOG: 
COMBAT_LOG: === PILOT STATISTICS ===
COMBAT_LOG: Viper-1              (F-16C_50, Blue Squadron, Blue)
COMBAT_LOG:   Combat: Kills=2 Deaths=0 KD=2.00 Shots=4 Hits=3 Eff=75.0%
COMBAT_LOG:   Flight: Takeoffs=1 Landings=1 Ejections=0 Crashes=0 Time=42.5m
COMBAT_LOG:   Weapons: AIM-120C=2 AIM-9X=2
COMBAT_LOG: 
COMBAT_LOG: === FORMATION STATISTICS ===
COMBAT_LOG: Blue Squadron       : Members=4 Shots=16 Hits=12 Kills=6 Losses=1
COMBAT_LOG: 
COMBAT_LOG: === COMBAT EFFECTIVENESS ===
COMBAT_LOG: Red Coalition:  Kills=2 Losses=6 Shots=24
COMBAT_LOG: Blue Coalition: Kills=6 Losses=2 Shots=32
COMBAT_LOG: 
COMBAT_LOG: === END OF LOG ===
```

## Configuration

### Simple Version Configuration (v2.0)
Edit the CONFIG table at the top of the script:

```lua
local CONFIG = {
    LOG_PREFIX = "dcs_combat_",        -- Log file prefix
    LOG_INTERVAL = 60,                 -- Status report interval (seconds)
    ENABLE_DEBUG = false,              -- Enable debug messages
    TRACK_GROUND_UNITS = false,        -- Track ground unit interactions
}
```

### Full Version Configuration
Edit the CONFIG table:

```lua
local CONFIG = {
    LOG_FILE_PREFIX = "dcs_combat_log_",
    ENABLE_CONSOLE_OUTPUT = true,
    LOG_LEVEL = "INFO",                -- DEBUG, INFO, WARN, ERROR
    LOG_INTERVAL = 30,                 -- Status update interval
}
```

## Key Improvements in v2.0

### Bug Fixes
- Fixed coalition ID mapping (DCS uses 1=Red, 2=Blue, not the reverse)
- Added pcall protection for all unit data access to prevent crashes
- Improved nil checking and error handling
- Fixed table.getn usage for proper pilot counting
- Removed lfs and os library dependencies - now uses only DCS built-in functions

### Enhanced Features
- **Better Event Coverage**: Added birth, engine, and refueling events
- **Improved Statistics**: K/D ratio, hit efficiency, flight time tracking
- **Formation Tracking**: Member lists and first contact time
- **Weapon Details**: Tracks which weapons were used and how many times
- **Target Tracking**: Records which targets were engaged and killed
- **Coalition Summary**: Clear Red vs Blue combat effectiveness comparison

### Performance Improvements
- Reduced file I/O with buffered writes
- More efficient event processing
- Cleaner code structure with better separation of concerns

## Integration with PyAcmi-Analyzer

The log files generated by these scripts are designed to complement TACVIEW ACMI files and can be used alongside the PyAcmi-Analyzer tool for comprehensive mission analysis.

### Cross-Validation Workflow
1. Run DCS mission with combat logger enabled
2. Generate TACVIEW ACMI file during the same mission
3. Use PyAcmi-Analyzer to process the ACMI file
4. Compare results between both tools for validation
5. Use combined data for comprehensive analysis

## Troubleshooting

### Common Issues

**Script not running:**
- Check DCS.log for error messages
- Ensure trigger is set to "Mission Start" event
- Verify script syntax (no copy/paste errors)

**No log entries in DCS.log:**
- Look for initialization errors in DCS.log
- Verify the script is running (check for "COMBAT_LOG:" entries)
- Ensure trigger is properly configured
- Check that events are actually occurring in the mission

**Missing events:**
- Some events may not fire in single-player vs multiplayer
- Weapon events depend on DCS event system timing
- Check if aircraft are properly spawned (not late activation)

**Performance issues:**
- Increase LOG_INTERVAL for less frequent updates
- Set ENABLE_DEBUG to false
- Disable TRACK_GROUND_UNITS if not needed

### Debug Mode

Enable debug logging in v2.0:
```lua
CONFIG.ENABLE_DEBUG = true
```

This will show additional error messages and debug information.

## Data Analysis

### Python Analysis Example

```python
# Extract combat log data from DCS.log
import re

combat_events = []
with open(r'%USERPROFILE%\Saved Games\DCS\Logs\DCS.log', 'r') as f:
    for line in f:
        if 'COMBAT_LOG:' in line:
            # Remove the COMBAT_LOG: prefix
            clean_line = line.split('COMBAT_LOG: ', 1)[1].strip()
            
            # Parse event lines
            if '[EVENT]' in clean_line:
                match = re.match(r'\[(\d+\.\d+)\] \[EVENT\] (\w+): (.+)', clean_line)
                if match:
                    combat_events.append({
                        'time': float(match.group(1)),
                        'type': match.group(2),
                        'details': match.group(3)
                    })

print(f"Found {len(combat_events)} combat events")
```

### Filtering DCS.log for Combat Data

```python
# Extract only combat log entries from DCS.log
def extract_combat_log(dcs_log_path, output_file):
    with open(dcs_log_path, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if 'COMBAT_LOG:' in line:
                # Remove timestamp and COMBAT_LOG: prefix
                clean_line = line.split('COMBAT_LOG: ', 1)[1]
                outfile.write(clean_line)

# Usage
extract_combat_log(r'%USERPROFILE%\Saved Games\DCS\Logs\DCS.log', 'combat_summary.txt')
```

## Contributing

To contribute improvements or report issues:

1. Test scripts in various mission scenarios
2. Document any compatibility issues
3. Suggest additional events or statistics to track
4. Provide feedback on log format and usability

## License

This project is provided as-is for the DCS World community. Feel free to modify and distribute according to your needs.

## Version History

- **v1.0** - Initial release with basic event logging
- **v1.1** - Added formation statistics and improved error handling
- **v1.2** - Enhanced JSON format and PyAcmi-Analyzer compatibility
- **v2.0** - Complete rewrite of simple version with comprehensive event tracking, bug fixes, and enhanced statistics

## Support

For support and questions:
- Check the troubleshooting section above
- Review DCS.log for error messages
- Test with simple missions first
- Verify DCS World version compatibility

---

**Note**: These scripts are designed for DCS World 2.5.6+ and have been tested with various aircraft modules. Coalition IDs in DCS: 0=Neutral, 1=Red, 2=Blue. 