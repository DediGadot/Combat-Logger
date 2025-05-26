#!/usr/bin/env python3
"""
DCS Combat Log Extractor
========================

Extracts combat logs from DCS.log file and saves them to a separate file.
Useful for analyzing combat data without the noise of other DCS log entries.

Usage:
    python extract_combat_logs.py [input_file] [output_file]

If no arguments provided, uses default DCS log location.

Author: AI Assistant
Version: 1.0
"""

import os
import sys
import re
from pathlib import Path
from datetime import datetime

def get_default_dcs_log_path():
    """Get the default DCS logs directory path."""
    user_profile = os.environ.get('USERPROFILE', '')
    if user_profile:
        return Path(user_profile) / 'Saved Games' / 'DCS' / 'Logs'
    return None

def find_combat_log_files(logs_dir):
    """Find all combat log files in the logs directory."""
    combat_files = []
    if logs_dir and logs_dir.exists():
        # Look for separate combat log files first
        combat_files = list(logs_dir.glob('combat_log_*.log'))
        combat_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)  # Most recent first
    return combat_files

def extract_combat_logs(input_file, output_file):
    """Extract combat logs from DCS.log file."""
    try:
        combat_logs = []
        total_lines = 0
        combat_lines = 0
        
        print(f"Reading from: {input_file}")
        
        with open(input_file, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                total_lines += 1
                if 'COMBAT_LOG:' in line:
                    combat_lines += 1
                    # Clean up the line and extract just the combat log part
                    combat_part = line.split('COMBAT_LOG:', 1)
                    if len(combat_part) > 1:
                        clean_log = combat_part[1].strip()
                        combat_logs.append(clean_log)
        
        print(f"Found {combat_lines} combat log entries out of {total_lines} total lines")
        
        if combat_logs:
            print(f"Writing to: {output_file}")
            with open(output_file, 'w', encoding='utf-8') as f:
                # Write header
                f.write(f"# DCS Combat Log Extract\n")
                f.write(f"# Extracted on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"# Source: {input_file}\n")
                f.write(f"# Total combat events: {len(combat_logs)}\n")
                f.write(f"# {'='*50}\n\n")
                
                # Write combat logs
                for log_entry in combat_logs:
                    f.write(f"{log_entry}\n")
            
            print(f"Successfully extracted {len(combat_logs)} combat log entries!")
            return True
        else:
            print("No combat logs found in the input file.")
            return False
            
    except FileNotFoundError:
        print(f"Error: Input file not found: {input_file}")
        return False
    except PermissionError:
        print(f"Error: Permission denied accessing file: {input_file}")
        return False
    except Exception as e:
        print(f"Error: {str(e)}")
        return False

def generate_output_filename(input_file):
    """Generate output filename based on input file."""
    input_path = Path(input_file)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    return input_path.parent / f"combat_log_extract_{timestamp}.txt"

def main():
    """Main function."""
    print("DCS Combat Log Extractor v1.0")
    print("=" * 40)
    
    # Parse command line arguments
    if len(sys.argv) >= 2:
        input_file = sys.argv[1]
    else:
        # Look for combat log files in default DCS logs directory
        logs_dir = get_default_dcs_log_path()
        combat_files = find_combat_log_files(logs_dir)
        
        if combat_files:
            # Use the most recent combat log file
            input_file = str(combat_files[0])
            print(f"Found {len(combat_files)} combat log file(s)")
            print(f"Using most recent: {input_file}")
        else:
            # Fallback to DCS.log
            dcs_log = logs_dir / 'DCS.log' if logs_dir else None
            if dcs_log and dcs_log.exists():
                input_file = str(dcs_log)
                print(f"No separate combat logs found, using DCS.log: {input_file}")
            else:
                print("Error: Could not find any combat log files or DCS.log.")
                print("Please specify the input file path as an argument.")
                print("Usage: python extract_combat_logs.py [input_file] [output_file]")
                return 1
    
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        # Generate output filename
        output_file = str(generate_output_filename(input_file))
    
    # Extract combat logs
    success = extract_combat_logs(input_file, output_file)
    
    if success:
        print("\nExtraction completed successfully!")
        print(f"Combat logs saved to: {output_file}")
        
        # Offer to open the file
        try:
            response = input("\nWould you like to open the extracted log file? (y/n): ")
            if response.lower() in ['y', 'yes']:
                os.startfile(output_file)  # Windows
        except:
            pass  # Ignore if startfile not available or user cancels
        
        return 0
    else:
        print("\nExtraction failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 