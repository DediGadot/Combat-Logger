# DCS Combat Logger v3.0 - Multiplayer Compatible

A robust combat logging system for DCS World that works reliably in both single-player and dedicated multiplayer server environments.

## 🆕 What's New in Version 3.0

### Major Compatibility Improvements

**Version 3.0** addresses critical multiplayer compatibility issues found in previous versions:

- **✅ Polling-Based Player Detection**: Replaces unreliable `S_EVENT_PLAYER_ENTER_UNIT`/`S_EVENT_PLAYER_LEAVE_UNIT` events
- **✅ Dedicated Server Compatible**: Works reliably on dedicated multiplayer servers
- **✅ Reliable Events Only**: Focuses on events that work consistently in all environments
- **✅ Enhanced Error Protection**: Multiple layers of error handling for edge cases

### Key Differences from v2.x

| Feature | v2.x (Event-Based) | v3.0 (Polling-Based) |
|---------|-------------------|----------------------|
| Player Detection | Event handlers (unreliable in MP) | Polling every 5 seconds (reliable) |
| MP Server Support | ❌ Broken on dedicated servers | ✅ Fully compatible |
| Event Coverage | All events (some unreliable) | Reliable events only |
| Error Handling | Basic protection | Comprehensive protection |

## 📋 Features

### Combat Tracking
- **Weapon Shots**: All missile and gun shots with weapon types
- **Hits & Kills**: Impact tracking with weapon effectiveness
- **Player vs AI**: Distinguishes between human pilots and AI
- **Coalition Statistics**: Red vs Blue performance comparison

### Flight Operations
- **Takeoffs & Landings**: Flight operation tracking
- **Crashes & Ejections**: Emergency situation logging
- **Flight Time**: Automatic calculation per pilot

### Statistics & Analysis
- **Per-Pilot Stats**: Individual performance metrics
- **Weapon Effectiveness**: Hit rates by weapon type
- **Coalition Performance**: Team-based statistics
- **Mission Summary**: Comprehensive end-of-mission report

## 🚀 Installation

### Method 1: Mission Editor (Recommended)
1. Open your mission in the DCS Mission Editor
2. Add a new trigger with condition "ONCE" and "TIME MORE (1)"
3. Add action "DO SCRIPT FILE" 
4. Select `dcs_combat_logger_v3.lua`
5. Save and test your mission

### Method 2: Mission Script
1. Copy the contents of `dcs_combat_logger_v3.lua`
2. In Mission Editor, add trigger with "DO SCRIPT" action
3. Paste the script content
4. Save mission

## 📊 Output Format

All logs are saved to a **separate combat log file** in the DCS logging folder:
- **Location**: `%USERPROFILE%\Saved Games\DCS\Logs\combat_log_HHMMSS.log`
- **Fallback**: If file creation fails, logs go to `DCS.log` with `COMBAT_LOG:` prefix
- **Format**: Clean, timestamped entries with event details (no DCS noise)

Example output in `combat_log_143052.log`:

```
[0.0] SYSTEM: Combat Logger v3.0 initialized (Multiplayer Compatible)
[0.0] SYSTEM: Using polling-based player detection for MP compatibility
[0.0] SYSTEM: Target log file: combat_log_143052.log
[15.3] PLAYER_ENTER: Viper01 entered F-16C_50 (F-16C_50) - Blue Coalition
[45.7] TAKEOFF: Viper01 (F-16C_50) took off
[156.2] SHOT: Viper01 (F-16C_50) fired AIM-120C
[158.4] HIT: Viper01 (F-16C_50) hit MiG-29A (MiG-29A) with AIM-120C
[158.5] KILL: Viper01 (F-16C_50) killed MiG-29A (MiG-29A) with AIM-120C
```

### 🔧 Log Extraction Utility

For easier analysis, use the included `extract_combat_logs.py` utility:

```bash
# Automatically finds and processes the most recent combat log file
python extract_combat_logs.py

# Extract from specific file
python extract_combat_logs.py "C:\path\to\combat_log_143052.log" "analysis.txt"
```

This utility:
- **Automatically finds** separate combat log files in DCS Logs folder
- **Prioritizes** most recent combat log file
- **Falls back** to extracting from DCS.log if no separate files found
- **Creates clean** analysis-ready files with timestamps

## 🔧 Configuration

### Player Check Interval
Modify the polling frequency (default: 5 seconds):
```lua
playerCheckInterval = 5, -- seconds
```

### Buffer Size
Adjust log buffer size (default: 100 messages):
```lua
maxBufferSize = 100,
```

## 📈 Mission Summary

At mission end, a comprehensive summary is generated:

```
=== MISSION SUMMARY ===
Mission Duration: 45:23
Total Events: Shots=156, Hits=89, Kills=23, Deaths=12
Flight Operations: Takeoffs=8, Landings=6, Crashes=1, Ejections=1

=== COALITION PERFORMANCE ===
Blue Coalition: Shots=98, Hits=67 (68%), Kills=18, Deaths=5
Red Coalition: Shots=58, Hits=22 (38%), Kills=5, Deaths=18

=== PILOT PERFORMANCE ===
Viper01 (Blue): Shots=34, Hits=28 (82%), K/D=4.0, Flight=23m
Falcon02 (Blue): Shots=29, Hits=19 (66%), K/D=2.5, Flight=31m

=== WEAPON EFFECTIVENESS ===
AIM-120C: Fired=45, Hits=38 (84%)
AIM-9X: Fired=23, Hits=15 (65%)
M61A1: Fired=234, Hits=67 (29%)
```

## 🔍 Troubleshooting

### Common Issues

**Q: No combat log files appearing**
- Check that the script loaded without errors
- Look for separate combat log files: `%USERPROFILE%\Saved Games\DCS\Logs\combat_log_*.log`
- If no separate files, check DCS.log for "COMBAT_LOG:" entries (fallback mode)
- Ensure the mission trigger is set to execute the script
- Verify DCS has write permissions to the Logs folder

**Q: Player detection not working**
- v3.0 uses polling instead of events - players detected within 5 seconds
- Check that units are set as "Client" slots in Mission Editor
- Verify players are actually in aircraft (not spectating)

**Q: Missing events on dedicated server**
- v3.0 specifically addresses this issue
- Only uses events that work reliably in multiplayer
- Player tracking uses polling instead of unreliable events

**Q: Script errors or crashes**
- All functions wrapped in `pcall()` for error protection
- Check DCS.log for specific error messages
- Ensure you're using v3.0 (not older versions)

### Performance Considerations

- **Polling Overhead**: Player checks every 5 seconds (minimal impact)
- **Buffer Management**: Automatic flushing prevents memory issues
- **Error Protection**: Multiple safety layers prevent script crashes

## 🔄 Migration from v2.x

If upgrading from v2.x:

1. **Replace the script file** with `dcs_combat_logger_v3.lua`
2. **No configuration changes needed** - v3.0 is backward compatible
3. **Improved reliability** - especially on dedicated servers
4. **Same log format** - existing analysis tools should work

## 🎯 Compatibility

### Tested Environments
- ✅ DCS World Single Player
- ✅ DCS World Multiplayer (Local Host)
- ✅ DCS World Dedicated Server
- ✅ All DCS aircraft modules
- ✅ All terrain modules

### DCS Version Support
- **Minimum**: DCS World 2.5.6+
- **Recommended**: DCS World 2.8.0+
- **Latest**: DCS World 2.9.x (fully tested)

## 🤝 Contributing

Found an issue or have suggestions?

1. **Test thoroughly** in your environment
2. **Provide detailed logs** from DCS.log
3. **Specify DCS version** and server type
4. **Include mission details** if relevant

## 📝 Version History

### v3.0 (2024) - Multiplayer Compatible
- **Major**: Polling-based player detection
- **Major**: Dedicated server compatibility
- **Major**: Enhanced error protection
- **Improved**: Reliable event handling only
- **Fixed**: Player enter/leave detection in MP

### v2.1 (Previous)
- Event-based player detection
- Full event coverage
- Single-player focused

### v1.0 (Original)
- Basic combat logging
- Limited error handling

## 📄 License

This script is provided as-is for the DCS World community. Feel free to modify and distribute.

---

**Note**: This is Version 3.0 specifically designed for multiplayer compatibility. If you're experiencing issues with previous versions on dedicated servers, this version should resolve those problems. 