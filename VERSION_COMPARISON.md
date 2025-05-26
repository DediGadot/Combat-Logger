# DCS Combat Logger Version Comparison

## 📊 Version Overview

| Version | Lines | Size | Focus | Key Features |
|---------|-------|------|-------|--------------|
| **v3.0** | 917 | ~35KB | Full-featured | Detailed stats, formations, file logging |
| **v4.0** | 356 | ~12KB | Simplified | Core events only, minimal complexity |
| **v4.1** | 398 | ~14KB | Enhanced accuracy | Added weapon.getLauncher() support |
| **v4.2** | 465 | ~17KB | Production-ready | Bug fixes, centralized config |

## 🎯 Feature Comparison

| Feature | v3.0 | v4.0 | v4.1 | v4.2 |
|---------|------|------|------|------|
| **Combat Events** | ✅ All types | ✅ Core only | ✅ Core only | ✅ Core only |
| **Player Tracking** | ✅ Advanced | ✅ Basic | ✅ Basic | ✅ Basic |
| **File Logging** | ✅ Separate files | ❌ DCS.log only | ❌ DCS.log only | ❌ DCS.log only |
| **Formation Tracking** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Weapon Stats** | ✅ Detailed | ❌ No | ❌ No | ❌ No |
| **getLauncher()** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Centralized Config** | ❌ Scattered | ❌ Minimal | ❌ Minimal | ✅ Complete |
| **Bug Protection** | ✅ Good | ✅ Basic | ✅ Good | ✅ Excellent |

## 📝 Version Details

### **v3.0 - Full Featured**
```
✅ Comprehensive event tracking
✅ Detailed pilot statistics
✅ Formation analysis
✅ Weapon effectiveness
✅ Separate log files
❌ Complex (917 lines)
❌ Higher performance impact
```

### **v4.0 - Simplified**
```
✅ Minimal complexity (356 lines)
✅ Core combat events only
✅ Low performance impact
✅ Easy to understand
❌ Basic features only
❌ No advanced statistics
```

### **v4.1 - Enhanced Accuracy**
```
✅ weapon.getLauncher() support
✅ Better hit/kill attribution
✅ Data source tracking
✅ Still simple (398 lines)
❌ Configuration scattered
❌ Some edge-case bugs
```

### **v4.2 - Production Ready**
```
✅ All v4.1 features
✅ Centralized CONFIG table
✅ Comprehensive bug fixes
✅ Enhanced error handling
✅ Version tracking
✅ Production stable
⚠️ Slightly larger (465 lines)
```

## 🔧 Bug Fixes by Version

### **v4.1 Fixes:**
- Improved weapon attribution accuracy

### **v4.2 Fixes:**
- ✅ pcall return value handling
- ✅ nil string concatenation
- ✅ env.info parameter error
- ✅ Missing nil checks
- ✅ getCallsign fallback logic
- ✅ Unit existence checks
- ✅ Event nil protection
- ✅ Empty string handling
- ✅ Coalition default values

## 🎯 Which Version to Choose?

### **Choose v3.0 if you need:**
- Detailed pilot statistics
- Formation tracking
- Weapon effectiveness analysis
- Separate log files
- Comprehensive event tracking

### **Choose v4.0 if you want:**
- Absolute minimal complexity
- Quick setup
- Low performance impact
- Basic logging only

### **Choose v4.1 if you need:**
- Better weapon attribution
- Simple implementation
- Debug tracking features

### **Choose v4.2 if you want:**
- ⭐ **RECOMMENDED**
- Most stable version
- Easy configuration
- All bug fixes
- Production ready
- Best of v4.x series

## 📈 Evolution Summary

```
v3.0 → v4.0: Simplified by 63% (removed advanced features)
v4.0 → v4.1: Added getLauncher() for accuracy (+42 lines)
v4.1 → v4.2: Fixed bugs & reorganized (+67 lines)
```

## 🏆 Recommendation

**For most users: Use v4.2**
- Most stable and bug-free
- Easy to configure
- Good balance of features and simplicity
- Production-tested code structure

**For advanced users: Consider v3.0**
- If you need detailed statistics
- Formation tracking requirements
- Separate log file output 