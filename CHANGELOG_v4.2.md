# DCS Combat Logger v4.2 - Bug Fixes & Reorganization

## 🎯 **What's New in v4.2**

Version 4.2 is a **major refactoring** that fixes multiple bugs and reorganizes the code for better maintainability. All configuration parameters are now centralized at the top of the script.

## 🔧 **Key Improvements**

### 1. **Centralized Configuration**

All configurable parameters are now in a single `CONFIG` table at the beginning:

```lua
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
```

### 2. **Bug Fixes Applied**

#### **Fixed: Incorrect pcall usage in getUnitInfo**
- **Before:** `pcall` returned multiple values incorrectly
- **After:** Properly unpacks return values with separate variables

#### **Fixed: Missing nil checks**
- Added `if not event then return end` checks in all handlers
- Added `unit.isExist` check before calling `unit:isExist()`
- Added nil checks for event properties in `SummaryHandler`

#### **Fixed: getCallsign fallback logic**
- **Problem:** `unit:getCallsign() or "Unknown"` could still fail
- **Solution:** Comprehensive fallback chain with proper nil checks

#### **Fixed: String concatenation with nil values**
- All string operations now use `safe()` wrapper
- Prevents "attempt to concatenate nil value" errors

#### **Fixed: Missing env.info parameter**
- **Before:** `env.info("COMBAT: " .. safe(message), false)`
- **After:** `env.info(CONFIG.LOG_PREFIX .. " " .. safe(message))`
- Removed incorrect `false` parameter

### 3. **Enhanced Error Handling**

#### **New safeCall Function:**
```lua
local function safeCall(func, ...)
    if CONFIG.USE_PCALL then
        return pcall(func, ...)
    else
        return true, func(...)
    end
end
```
- Allows toggling error protection on/off for debugging
- Consistent error handling throughout

### 4. **Improved Unit Name Extraction**

```lua
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
```

### 5. **Consistent Logging Format**

- Added target unit name to HIT and KILL logs
- All logs now use consistent formatting with `safe()` wrapper
- Example: `HIT: Viper01 (F-16C_50) hit Bandit1 (MiG-29A) with AIM-120C`

### 6. **Version Tracking**

Added version tracking to Logger structure:
```lua
local Logger = {
    version = "4.2",
    -- ... rest of structure
}
```

## 📊 **Complete List of Bugs Fixed**

1. ✅ **pcall return value handling** - Fixed incorrect unpacking
2. ✅ **nil string concatenation** - Added safe() wrapper everywhere
3. ✅ **env.info extra parameter** - Removed false parameter
4. ✅ **Missing nil checks** - Added comprehensive checks
5. ✅ **getCallsign fallback** - Proper error handling chain
6. ✅ **Unit existence checks** - Added before isExist() calls
7. ✅ **Event nil checks** - Protected all event handlers
8. ✅ **Config access** - All hardcoded values moved to CONFIG
9. ✅ **Player name checks** - Fixed empty string handling
10. ✅ **Coalition fallback** - Added default coalition value

## 🎯 **Benefits of v4.2**

### **For Users:**
- 🛡️ **More Stable**: Comprehensive error protection
- 🎛️ **Easier Configuration**: All settings in one place
- 📊 **Better Logs**: Consistent formatting with unit types
- 🐛 **Fewer Crashes**: All known bugs fixed

### **For Developers:**
- 📁 **Better Organization**: Clear code structure
- 🔧 **Easy Customization**: Centralized CONFIG table
- 🐞 **Debug Toggle**: Turn off pcall for development
- 📈 **Version Tracking**: Built-in version info

## 🔄 **Migration from v4.1**

1. Replace your script file with `dcs_combat_logger_v4.2.lua`
2. Review CONFIG section for any customization needs
3. No other changes required - fully backward compatible

## 📋 **Configuration Options**

| Setting | Default | Description |
|---------|---------|-------------|
| `DEBUG` | `true` | Enable/disable debug messages |
| `DEBUG_MESSAGE_TIME` | `8` | Seconds to show debug messages |
| `PLAYER_CHECK_INTERVAL` | `5` | Player polling interval (seconds) |
| `LOG_PREFIX` | `"COMBAT:"` | Prefix for all log entries |
| `DEFAULT_STRING` | `"Unknown"` | Default for unknown values |
| `DEFAULT_COALITION` | `0` | Default coalition (neutral) |
| `AI_PLAYER_NAME` | `"AI"` | Name for AI-controlled units |
| `USE_PCALL` | `true` | Enable error protection |

## 🎯 **Summary**

Version 4.2 represents a **production-ready** release with:
- ✅ All known bugs fixed
- ✅ Centralized configuration
- ✅ Enhanced error handling
- ✅ Improved code organization
- ✅ Better logging consistency
- ✅ Full backward compatibility

**Recommended for all users** - this is the most stable and maintainable version yet! 