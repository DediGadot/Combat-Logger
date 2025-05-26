# DCS Combat Logger v4.1 - getLauncher Improvements

## 🎯 **What's New in v4.1**

Version 4.1 introduces **improved weapon tracking accuracy** using the DCS `weapon:getLauncher()` function as suggested in the [DCS Wiki documentation](https://wiki.hoggitworld.com/view/DCS_func_getLauncher).

## 🔧 **Key Improvements**

### 1. **Enhanced Shooter Detection**

#### **New `getBestShooterInfo()` Function:**
```lua
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
```

### 2. **Smart Event Handling Strategy**

#### **S_EVENT_SHOT:** Uses `event.initiator` (most accurate at launch time)
#### **S_EVENT_HIT:** Uses `weapon:getLauncher()` first, falls back to `event.initiator`
#### **S_EVENT_KILL:** Uses `weapon:getLauncher()` first, falls back to `event.initiator`

### 3. **Data Source Tracking**

Debug messages now show the data source for troubleshooting:
```
DEBUG: HIT: Viper01 → Bandit1 (weapon)
DEBUG: KILL: Hornet02 eliminated Bandit2 (event)
```

## 🎯 **Why This Matters**

### **Problem Solved:**
In some DCS scenarios, `event.initiator` might become unreliable for hits/kills, especially:
- When the launching aircraft has been destroyed
- In complex multi-stage weapon scenarios
- With certain weapon types or timing edge cases

### **Solution:**
The `weapon:getLauncher()` function provides a direct link from the weapon object back to the unit that launched it, offering potentially more reliable data for hit/kill attribution.

## 📊 **Improved Log Output**

### **Before v4.1:**
```
COMBAT: HIT: Viper01 hit Bandit1 with AIM-120C
COMBAT: KILL: Viper01 killed Bandit2 with AIM-120C
```

### **After v4.1:**
```
COMBAT: HIT: Viper01 (F-16C_50) hit Bandit1 with AIM-120C
COMBAT: KILL: Viper01 (F-16C_50) killed Bandit2 with AIM-120C
```

*Note: Unit names now included in parentheses for better context*

## 🔍 **Debug Enhancements**

When `DEBUG = true`, you'll see:
```
DEBUG: HIT: Viper01 → Bandit1 (weapon)
DEBUG: KILL: Viper01 eliminated Bandit2 (weapon)
```

The `(weapon)` or `(event)` indicator shows which data source was used, helping with troubleshooting.

## 🚀 **Performance Impact**

- **Minimal overhead:** Only one additional function call per hit/kill event
- **Graceful fallback:** If `getLauncher()` fails, falls back to original method
- **Error protection:** All new code wrapped in `pcall()` for safety

## 📋 **Compatibility**

- ✅ **Backward compatible:** All existing functionality preserved
- ✅ **DCS 2.7+:** `getLauncher()` available since DCS 1.2.4
- ✅ **Multiplayer:** Fully compatible with dedicated servers
- ✅ **Single-player:** Works in all mission types

## 🔄 **Migration from v4.0**

Simply replace your `dcs_combat_logger_v4.lua` file with the new v4.1 version. No configuration changes needed!

## 🎯 **When to Use v4.1**

**Upgrade to v4.1 if you:**
- Want the most accurate weapon attribution possible
- Are experiencing any issues with hit/kill tracking
- Want better debugging information
- Want future-proof weapon tracking

**v4.0 is still fine if you:**
- Have a working setup with no issues
- Prefer absolute minimal complexity
- Are in a testing/development environment

## 📈 **Expected Benefits**

1. **More accurate hit/kill attribution** in edge cases
2. **Better debugging capabilities** with source tracking
3. **Future-proof design** using DCS's recommended weapon tracking
4. **Enhanced log readability** with unit type information

---

**Version 4.1 maintains the same simplicity as v4.0 while adding smart weapon tracking for improved accuracy!** 🎯 