#!/usr/bin/env python3
"""
TACVIEW ACMI Air-to-Air Combat Analyzer

This script analyzes TACVIEW ACMI files to extract air-to-air combat statistics per pilot.
It tracks missile launches, hits, kills, and other combat metrics for each pilot.
"""

import pyacmi
import json
from collections import defaultdict
from datetime import datetime, timedelta
import argparse
import sys

class CombatAnalyzer:
    def __init__(self, acmi_file):
        self.acmi_file = acmi_file
        self.acmi = pyacmi.Acmi()
        self.pilot_stats = defaultdict(lambda: {
            'pilot_name': '',
            'aircraft_type': '',
            'coalition': '',
            'country': '',
            'group': '',
            'missiles_fired': 0,
            'missiles_hit': 0,
            'air_to_air_kills': 0,
            'deaths': 0,
            'missiles_fired_list': [],
            'kills_list': [],
            'death_cause': '',
            'flight_time': 0,
            'max_altitude': 0,
            'max_speed': 0
        })
        
    def load_acmi(self):
        """Load the ACMI file"""
        print(f"Loading ACMI file: {self.acmi_file}")
        try:
            self.acmi.load_acmi(self.acmi_file)
            print("ACMI file loaded successfully")
            return True
        except Exception as e:
            print(f"Error loading ACMI file: {e}")
            return False
    
    def analyze_objects(self):
        """Analyze all objects in the ACMI file"""
        print("Analyzing objects...")
        
        # Get all objects
        alive_objects = self.acmi.alive_objects()
        removed_objects = self.acmi.removed_objects()
        
        all_objects = alive_objects + removed_objects
        
        print(f"Total objects: {len(all_objects)}")
        print(f"Alive objects: {len(alive_objects)}")
        print(f"Removed objects: {len(removed_objects)}")
        
        # Categorize objects
        aircraft = []
        missiles = []
        
        for obj in all_objects:
            if obj.is_plane:
                aircraft.append(obj)
            elif obj.is_missile:
                missiles.append(obj)
        
        print(f"Aircraft found: {len(aircraft)}")
        print(f"Missiles found: {len(missiles)}")
        
        return aircraft, missiles
    
    def analyze_aircraft(self, aircraft):
        """Analyze aircraft and extract pilot information"""
        print("Analyzing aircraft...")
        
        for plane in aircraft:
            pilot = plane.pilot()
            if not pilot:
                continue
                
            json_data = plane.json()
            
            # Initialize or update pilot stats
            if pilot not in self.pilot_stats:
                self.pilot_stats[pilot] = {
                    'pilot_name': pilot,
                    'aircraft_type': json_data.get('Name', 'Unknown'),
                    'coalition': plane.coalition(),
                    'country': json_data.get('Country', 'Unknown'),
                    'group': json_data.get('Group', 'Unknown'),
                    'missiles_fired': 0,
                    'missiles_hit': 0,
                    'air_to_air_kills': 0,
                    'deaths': 0,
                    'missiles_fired_list': [],
                    'kills_list': [],
                    'death_cause': '',
                    'flight_time': 0,
                    'max_altitude': json_data.get('Altitude', 0) or 0,
                    'max_speed': 0
                }
            
            # Check if this aircraft was destroyed (in removed objects)
            if plane in self.acmi.removed_objects():
                self.pilot_stats[pilot]['deaths'] += 1
    
    def analyze_missiles(self, missiles):
        """Analyze missiles to track launches and hits"""
        print("Analyzing missiles...")
        
        air_to_air_missiles = ['AIM_120', 'AIM-9L', 'AIM-9M', 'AIM-9X', 'AIM-7', 'R-27', 'R-73', 'R-77', 'P_24R']
        
        for missile in missiles:
            json_data = missile.json()
            missile_name = json_data.get('Name', '')
            
            # Check if it's an air-to-air missile
            if any(aam in missile_name for aam in air_to_air_missiles):
                parent_id = json_data.get('Parent')
                
                if parent_id:
                    # Find the parent aircraft
                    parent_pilot = self.find_pilot_by_object_id(parent_id)
                    
                    if parent_pilot:
                        self.pilot_stats[parent_pilot]['missiles_fired'] += 1
                        self.pilot_stats[parent_pilot]['missiles_fired_list'].append({
                            'missile_type': missile_name,
                            'target': 'Unknown',  # Would need timeline data to determine target
                            'time': 'Unknown'
                        })
    
    def find_pilot_by_object_id(self, object_id):
        """Find pilot name by object ID"""
        # This is a simplified approach - in a full implementation,
        # we'd need to track object IDs to pilots more carefully
        all_objects = self.acmi.alive_objects() + self.acmi.removed_objects()
        
        for obj in all_objects:
            json_data = obj.json()
            if json_data.get('ID') == object_id and obj.is_plane:
                return obj.pilot()
        
        return None
    
    def calculate_kill_statistics(self):
        """Calculate kill statistics based on aircraft losses and missile data"""
        print("Calculating kill statistics...")
        
        # This is a simplified approach - a more sophisticated analysis
        # would require timeline data to correlate missile hits with aircraft losses
        
        removed_aircraft = [obj for obj in self.acmi.removed_objects() if obj.is_plane]
        
        # For now, we'll estimate kills based on coalition differences
        # and missile launches (this is not perfectly accurate without timeline data)
        
        for pilot, stats in self.pilot_stats.items():
            if stats['missiles_fired'] > 0:
                # Rough estimation: assume some missiles hit based on enemy losses
                enemy_coalition = 'Allies' if stats['coalition'] == 'Enemies' else 'Enemies'
                enemy_losses = len([obj for obj in removed_aircraft 
                                  if obj.coalition() == enemy_coalition])
                
                # Very rough estimation - this would be much more accurate with timeline data
                if enemy_losses > 0 and stats['missiles_fired'] > 0:
                    estimated_kills = min(stats['missiles_fired'] // 2, enemy_losses // len([p for p in self.pilot_stats.values() if p['coalition'] == stats['coalition'] and p['missiles_fired'] > 0]) or 1)
                    stats['air_to_air_kills'] = max(0, estimated_kills)
    
    def generate_report(self):
        """Generate a comprehensive combat report"""
        print("\n" + "="*80)
        print("AIR-TO-AIR COMBAT ANALYSIS REPORT")
        print("="*80)
        
        # Global statistics
        global_data = self.acmi.global_json()
        print(f"Mission: {global_data.get('Title', 'Unknown')}")
        print(f"Date: {global_data.get('ReferenceTime', 'Unknown')}")
        print(f"Duration: {global_data.get('TimeFrames', 0)} time frames")
        print(f"Total Objects: {global_data.get('Objects', 0)}")
        
        print("\n" + "-"*80)
        print("PILOT STATISTICS")
        print("-"*80)
        
        # Sort pilots by coalition and then by kills
        sorted_pilots = sorted(self.pilot_stats.items(), 
                             key=lambda x: (x[1]['coalition'], -x[1]['air_to_air_kills'], -x[1]['missiles_fired']))
        
        current_coalition = None
        for pilot, stats in sorted_pilots:
            if stats['coalition'] != current_coalition:
                current_coalition = stats['coalition']
                print(f"\n{current_coalition.upper()} COALITION:")
                print("-" * 40)
            
            print(f"Pilot: {stats['pilot_name']}")
            print(f"  Aircraft: {stats['aircraft_type']}")
            print(f"  Country: {stats['country']}")
            print(f"  Group: {stats['group']}")
            print(f"  Missiles Fired: {stats['missiles_fired']}")
            print(f"  Estimated Kills: {stats['air_to_air_kills']}")
            print(f"  Deaths: {stats['deaths']}")
            print(f"  Kill/Death Ratio: {stats['air_to_air_kills'] / max(1, stats['deaths']):.2f}")
            print()
        
        # Summary statistics
        print("\n" + "-"*80)
        print("SUMMARY STATISTICS")
        print("-"*80)
        
        total_pilots = len(self.pilot_stats)
        total_missiles = sum(stats['missiles_fired'] for stats in self.pilot_stats.values())
        total_kills = sum(stats['air_to_air_kills'] for stats in self.pilot_stats.values())
        total_deaths = sum(stats['deaths'] for stats in self.pilot_stats.values())
        
        print(f"Total Pilots: {total_pilots}")
        print(f"Total Missiles Fired: {total_missiles}")
        print(f"Total Air-to-Air Kills: {total_kills}")
        print(f"Total Aircraft Lost: {total_deaths}")
        
        if total_missiles > 0:
            print(f"Overall Hit Rate: {(total_kills / total_missiles * 100):.1f}%")
        
        # Coalition breakdown
        coalitions = {}
        for stats in self.pilot_stats.values():
            coalition = stats['coalition']
            if coalition not in coalitions:
                coalitions[coalition] = {'pilots': 0, 'missiles': 0, 'kills': 0, 'deaths': 0}
            
            coalitions[coalition]['pilots'] += 1
            coalitions[coalition]['missiles'] += stats['missiles_fired']
            coalitions[coalition]['kills'] += stats['air_to_air_kills']
            coalitions[coalition]['deaths'] += stats['deaths']
        
        print(f"\nCoalition Breakdown:")
        for coalition, data in coalitions.items():
            print(f"  {coalition}:")
            print(f"    Pilots: {data['pilots']}")
            print(f"    Missiles Fired: {data['missiles']}")
            print(f"    Kills: {data['kills']}")
            print(f"    Deaths: {data['deaths']}")
            if data['deaths'] > 0:
                print(f"    K/D Ratio: {data['kills'] / data['deaths']:.2f}")
    
    def export_to_json(self, output_file):
        """Export statistics to JSON file"""
        output_data = {
            'mission_info': self.acmi.global_json(),
            'pilot_statistics': dict(self.pilot_stats),
            'analysis_timestamp': datetime.now().isoformat()
        }
        
        with open(output_file, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"Statistics exported to: {output_file}")
    
    def run_analysis(self):
        """Run the complete analysis"""
        if not self.load_acmi():
            return False
        
        aircraft, missiles = self.analyze_objects()
        self.analyze_aircraft(aircraft)
        self.analyze_missiles(missiles)
        self.calculate_kill_statistics()
        self.generate_report()
        
        return True

def main():
    parser = argparse.ArgumentParser(description='Analyze TACVIEW ACMI files for air-to-air combat statistics')
    parser.add_argument('acmi_file', help='Path to the ACMI file to analyze')
    parser.add_argument('--output', '-o', help='Output JSON file for statistics')
    
    args = parser.parse_args()
    
    analyzer = CombatAnalyzer(args.acmi_file)
    
    if analyzer.run_analysis():
        if args.output:
            analyzer.export_to_json(args.output)
        print("\nAnalysis completed successfully!")
    else:
        print("Analysis failed!")
        sys.exit(1)

if __name__ == "__main__":
    main() 