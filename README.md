# PyAcmi-Analyzer

A Python tool for analyzing TACVIEW ACMI files to extract air-to-air combat statistics per pilot.

## Overview

This tool analyzes TACVIEW ACMI files (`.acmi` format) and generates comprehensive air-to-air combat statistics for each pilot in the mission. It provides insights into missile usage, kill/death ratios, survival rates, and coalition performance.

## Features

- **Pilot Statistics**: Individual pilot performance including missiles fired, kills, deaths, and survival status
- **Aircraft Analysis**: Aircraft type identification and capability-based missile assignment
- **Coalition Breakdown**: Performance comparison between different coalitions
- **Missile Tracking**: Air-to-air missile identification and usage statistics
- **Export Capabilities**: JSON export for further analysis
- **Intelligent Estimation**: Smart algorithms to estimate combat results when direct data isn't available

## Installation

1. Clone or download this repository
2. Create a virtual environment:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install pyacmi constantly
   ```

## Usage

### Basic Analysis

```bash
python improved_acmi_analyzer.py path/to/your/file.acmi
```

### Export to JSON

```bash
python improved_acmi_analyzer.py path/to/your/file.acmi --output results.json
```

### Command Line Options

- `acmi_file`: Path to the ACMI file to analyze (required)
- `--output`, `-o`: Output JSON file for detailed statistics (optional)

## Example Output

```
================================================================================
AIR-TO-AIR COMBAT ANALYSIS REPORT
================================================================================
Mission: 2025-05-10 boz-attack
Date: 2020-06-01T05:00:00
Duration: 99160 time frames
Total Objects: 4218

--------------------------------------------------------------------------------
PILOT STATISTICS
--------------------------------------------------------------------------------

ENEMIES COALITION:
----------------------------------------
Pilot: IAF. Yuval KIZ (SURVIVED)
  Aircraft: F-4E-45MC
  Country: xb
  Group: f4
  Missiles Fired: 3
  Missile Types: AIM_120, AIM-9L
  Estimated Kills: 0
  Deaths: 0
  Kill/Death Ratio: 0.00
  Estimated Hit Rate: 30.0%

[... more pilots ...]

--------------------------------------------------------------------------------
SUMMARY STATISTICS
--------------------------------------------------------------------------------
Total Pilots: 26
Survivors: 9
Casualties: 17
Total Missiles Fired: 22
Total Estimated Kills: 0
Total Aircraft Lost: 26
Overall Estimated Hit Rate: 0.0%

Coalition Breakdown:
  Enemies:
    Pilots: 13 (Survivors: 4)
    Missiles Fired: 21
    Estimated Kills: 0
    Aircraft Lost: 12
    K/D Ratio: 0.00
    Hit Rate: 0.0%
```

## How It Works

### Data Analysis Process

1. **ACMI File Loading**: Uses the `pyacmi` library to parse TACVIEW files
2. **Object Categorization**: Separates aircraft, missiles, and other objects
3. **Pilot Identification**: Maps pilots to their aircraft and survival status
4. **Missile Assignment**: Intelligently distributes missiles to pilots based on:
   - Aircraft capabilities (what missiles each aircraft type can carry)
   - Coalition alignment (Western vs Eastern weapon systems)
   - Missile types found in the mission
5. **Kill Estimation**: Estimates kills based on:
   - Enemy coalition losses
   - Missile effectiveness assumptions
   - Pilot missile usage proportions

### Supported Aircraft Types

- **Western Aircraft**: F-16, F-4, F-18, FA-18
- **Eastern Aircraft**: MiG-21, MiG-23, MiG-25, Su-27
- **Support Aircraft**: E-3A (AWACS)

### Supported Missile Types

- **Western Missiles**: AIM-120 (AMRAAM), AIM-9L/M/X (Sidewinder), AIM-7 (Sparrow)
- **Eastern Missiles**: R-27 (Alamo), R-73 (Archer), R-77 (Adder), P-24R (Apex)

## Limitations

### Data Availability

Due to limitations in the ACMI format and the `pyacmi` library:

- **Parent-Child Relationships**: Direct missile-to-launcher relationships aren't preserved in the final object data
- **Timeline Data**: Full timeline analysis would require CSV export, which can be very large for long missions
- **Hit Confirmation**: Actual missile hits vs. misses aren't directly trackable

### Estimation Approach

The tool uses intelligent estimation algorithms:

- **Missile Distribution**: Based on aircraft capabilities and coalition alignment
- **Kill Calculation**: Uses statistical models with assumed hit rates (30% default)
- **Conservative Estimates**: Tends to underestimate rather than overestimate results

## Technical Details

### Dependencies

- `pyacmi`: TACVIEW ACMI file parsing
- `constantly`: Required by pyacmi
- Standard Python libraries: `json`, `collections`, `datetime`, `argparse`

### File Structure

- `improved_acmi_analyzer.py`: Main analysis script
- `acmi_analyzer.py`: Original version (basic implementation)
- `test_acmi.py`, `explore_*.py`: Development and debugging scripts
- `README.md`: This documentation
- `requirements.txt`: Python dependencies

### JSON Export Format

The exported JSON contains:
```json
{
  "mission_info": {
    "Title": "Mission Name",
    "ReferenceTime": "2020-06-01T05:00:00",
    "TimeFrames": 99160,
    "Objects": 4218
  },
  "pilot_statistics": {
    "PilotName": {
      "pilot_name": "PilotName",
      "aircraft_type": "F-16C_50",
      "coalition": "Enemies",
      "missiles_fired": 3,
      "air_to_air_kills": 1,
      "deaths": 0,
      "survived": true,
      "missile_types_used": ["AIM_120", "AIM-9L"]
    }
  },
  "analysis_timestamp": "2025-01-XX...",
  "analysis_notes": [...]
}
```

## Future Improvements

- **Timeline Analysis**: Full CSV export processing for precise missile tracking
- **Enhanced Hit Detection**: Better algorithms for determining actual hits
- **Weapon System Modeling**: More detailed aircraft-weapon compatibility
- **Performance Metrics**: Additional statistics like engagement ranges, altitudes
- **Visualization**: Charts and graphs for combat analysis
- **Multi-Mission Analysis**: Batch processing and comparison tools

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the analyzer.

## License

This project is provided as-is for educational and analysis purposes.

## Acknowledgments

- TACVIEW for the ACMI format specification
- The `pyacmi` library developers for ACMI file parsing capabilities 