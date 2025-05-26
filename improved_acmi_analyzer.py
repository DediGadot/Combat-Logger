#!/usr/bin/env python3
"""
TACVIEW ACMI Air-to-Air Combat Analyzer (Improved Version)

This script analyzes TACVIEW ACMI files to extract air-to-air combat statistics per pilot.
Since parent-child relationships aren't preserved in the final object data, this version
uses intelligent analysis of missile types, coalitions, and aircraft losses to estimate
combat statistics.
"""

import pyacmi
import json
from collections import defaultdict
from datetime import datetime
import argparse
import sys

class ImprovedCombatAnalyzer:
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
            'air_to_air_kills': 0,
            'deaths': 0,
            'survived': False,
            'missile_types_used': [],
            'estimated_hit_rate': 0.0
        })
        
        # Air-to-air missile types
        self.air_to_air_missiles = {
            'AIM_120': 'AMRAAM',
            'AIM-9L': 'Sidewinder',
            'AIM-9M': 'Sidewinder',
            'AIM-9X': 'Sidewinder',
            'AIM-7': 'Sparrow',
            'R-27': 'Alamo',
            'R-73': 'Archer',
            'R-77': 'Adder',
            'P_24R': 'Apex'
        }
        
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
    
    def analyze_combat_data(self):
        """Analyze combat data using available information"""
        print("Analyzing combat data...")
        
        alive_objects = self.acmi.alive_objects()
        removed_objects = self.acmi.removed_objects()
        
        # Categorize objects
        alive_aircraft = [obj for obj in alive_objects if obj.is_plane]
        removed_aircraft = [obj for obj in removed_objects if obj.is_plane]
        all_aircraft = alive_aircraft + removed_aircraft
        
        missiles = [obj for obj in removed_objects if obj.is_missile]
        air_to_air_missiles = [m for m in missiles if self.is_air_to_air_missile(m)]
        
        print(f"Total aircraft: {len(all_aircraft)} (Alive: {len(alive_aircraft)}, Lost: {len(removed_aircraft)})")
        print(f"Total missiles: {len(missiles)} (Air-to-air: {len(air_to_air_missiles)})")
        
        # Analyze pilots and aircraft
        self.analyze_pilots(all_aircraft, alive_aircraft)
        
        # Estimate missile usage based on coalition and aircraft types
        self.estimate_missile_usage(air_to_air_missiles)
        
        # Calculate kill estimates
        self.calculate_kill_estimates(removed_aircraft)
        
        return True
    
    def is_air_to_air_missile(self, missile):
        """Check if a missile is an air-to-air type"""
        json_data = missile.json()
        missile_name = json_data.get('Name', '')
        return any(aam in missile_name for aam in self.air_to_air_missiles.keys())
    
    def analyze_pilots(self, all_aircraft, alive_aircraft):
        """Analyze pilot information and survival status"""
        print("Analyzing pilots...")
        
        alive_pilots = set()
        for aircraft in alive_aircraft:
            pilot = aircraft.pilot()
            if pilot:
                alive_pilots.add(pilot)
        
        for aircraft in all_aircraft:
            pilot = aircraft.pilot()
            if not pilot:
                continue
            
            json_data = aircraft.json()
            
            # Initialize pilot stats
            if pilot not in self.pilot_stats:
                self.pilot_stats[pilot] = {
                    'pilot_name': pilot,
                    'aircraft_type': json_data.get('Name', 'Unknown'),
                    'coalition': aircraft.coalition(),
                    'country': json_data.get('Country', 'Unknown'),
                    'group': json_data.get('Group', 'Unknown'),
                    'missiles_fired': 0,
                    'air_to_air_kills': 0,
                    'deaths': 0,
                    'survived': pilot in alive_pilots,
                    'missile_types_used': [],
                    'estimated_hit_rate': 0.0
                }
            
            # Count deaths (aircraft in removed objects)
            if aircraft not in alive_aircraft:
                self.pilot_stats[pilot]['deaths'] += 1
    
    def estimate_missile_usage(self, air_to_air_missiles):
        """Estimate missile usage per pilot based on coalition and aircraft capabilities"""
        print("Estimating missile usage...")
        
        # Group missiles by coalition
        coalition_missiles = defaultdict(list)
        for missile in air_to_air_missiles:
            coalition = missile.coalition()
            coalition_missiles[coalition].append(missile)
        
        # Get pilots by coalition who could have fired missiles
        coalition_pilots = defaultdict(list)
        for pilot, stats in self.pilot_stats.items():
            aircraft_type = stats['aircraft_type']
            # Only fighter aircraft can fire air-to-air missiles
            if self.is_fighter_aircraft(aircraft_type):
                coalition_pilots[stats['coalition']].append(pilot)
        
        # Distribute missiles among pilots based on aircraft capabilities
        for coalition, missiles in coalition_missiles.items():
            pilots = coalition_pilots[coalition]
            if not pilots:
                continue
            
            # Group missiles by type
            missile_types = defaultdict(int)
            for missile in missiles:
                json_data = missile.json()
                missile_name = json_data.get('Name', '')
                missile_types[missile_name] += 1
            
            # Distribute missiles based on aircraft capabilities
            for missile_type, count in missile_types.items():
                capable_pilots = [p for p in pilots if self.can_carry_missile(self.pilot_stats[p]['aircraft_type'], missile_type)]
                
                if capable_pilots:
                    missiles_per_pilot = count // len(capable_pilots)
                    remainder = count % len(capable_pilots)
                    
                    for i, pilot in enumerate(capable_pilots):
                        missiles_to_add = missiles_per_pilot
                        if i < remainder:
                            missiles_to_add += 1
                        
                        self.pilot_stats[pilot]['missiles_fired'] += missiles_to_add
                        if missile_type not in self.pilot_stats[pilot]['missile_types_used']:
                            self.pilot_stats[pilot]['missile_types_used'].append(missile_type)
    
    def is_fighter_aircraft(self, aircraft_type):
        """Check if aircraft type is a fighter capable of air-to-air combat"""
        fighters = ['F-16', 'F-4', 'F-18', 'FA-18', 'MiG-21', 'MiG-23', 'MiG-25', 'Su-27']
        return any(fighter in aircraft_type for fighter in fighters)
    
    def can_carry_missile(self, aircraft_type, missile_type):
        """Check if an aircraft type can carry a specific missile type"""
        # Simplified mapping - in reality this would be more complex
        western_aircraft = ['F-16', 'F-4', 'F-18', 'FA-18']
        eastern_aircraft = ['MiG-21', 'MiG-23', 'MiG-25', 'Su-27']
        western_missiles = ['AIM_120', 'AIM-9L', 'AIM-9M', 'AIM-9X', 'AIM-7']
        eastern_missiles = ['R-27', 'R-73', 'R-77', 'P_24R']
        
        is_western_aircraft = any(ac in aircraft_type for ac in western_aircraft)
        is_eastern_aircraft = any(ac in aircraft_type for ac in eastern_aircraft)
        is_western_missile = any(missile in missile_type for missile in western_missiles)
        is_eastern_missile = any(missile in missile_type for missile in eastern_missiles)
        
        return (is_western_aircraft and is_western_missile) or (is_eastern_aircraft and is_eastern_missile)
    
    def calculate_kill_estimates(self, removed_aircraft):
        """Calculate kill estimates based on enemy losses and missile effectiveness"""
        print("Calculating kill estimates...")
        
        # Group losses by coalition
        coalition_losses = defaultdict(int)
        for aircraft in removed_aircraft:
            coalition = aircraft.coalition()
            coalition_losses[coalition] += 1
        
        # Estimate kills for each pilot based on their missile launches and enemy losses
        for pilot, stats in self.pilot_stats.items():
            if stats['missiles_fired'] == 0:
                continue
            
            pilot_coalition = stats['coalition']
            enemy_coalition = 'Allies' if pilot_coalition == 'Enemies' else 'Enemies'
            enemy_losses = coalition_losses[enemy_coalition]
            
            if enemy_losses == 0:
                continue
            
            # Get all pilots from same coalition who fired missiles
            coalition_shooters = [p for p, s in self.pilot_stats.items() 
                                if s['coalition'] == pilot_coalition and s['missiles_fired'] > 0]
            
            if not coalition_shooters:
                continue
            
            # Calculate this pilot's share of kills based on missiles fired
            total_coalition_missiles = sum(self.pilot_stats[p]['missiles_fired'] for p in coalition_shooters)
            pilot_missile_share = stats['missiles_fired'] / total_coalition_missiles
            
            # Estimate kills (assuming some missiles miss)
            estimated_hit_rate = 0.3  # Assume 30% hit rate for air-to-air missiles
            estimated_kills = min(
                int(stats['missiles_fired'] * estimated_hit_rate),
                int(enemy_losses * pilot_missile_share)
            )
            
            stats['air_to_air_kills'] = estimated_kills
            stats['estimated_hit_rate'] = estimated_hit_rate if stats['missiles_fired'] > 0 else 0.0
    
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
            
            status = "SURVIVED" if stats['survived'] else "KIA"
            print(f"Pilot: {stats['pilot_name']} ({status})")
            print(f"  Aircraft: {stats['aircraft_type']}")
            print(f"  Country: {stats['country']}")
            print(f"  Group: {stats['group']}")
            print(f"  Missiles Fired: {stats['missiles_fired']}")
            if stats['missile_types_used']:
                print(f"  Missile Types: {', '.join(stats['missile_types_used'])}")
            print(f"  Estimated Kills: {stats['air_to_air_kills']}")
            print(f"  Deaths: {stats['deaths']}")
            print(f"  Kill/Death Ratio: {stats['air_to_air_kills'] / max(1, stats['deaths']):.2f}")
            if stats['missiles_fired'] > 0:
                print(f"  Estimated Hit Rate: {stats['estimated_hit_rate']*100:.1f}%")
            print()
        
        # Summary statistics
        print("\n" + "-"*80)
        print("SUMMARY STATISTICS")
        print("-"*80)
        
        total_pilots = len(self.pilot_stats)
        total_missiles = sum(stats['missiles_fired'] for stats in self.pilot_stats.values())
        total_kills = sum(stats['air_to_air_kills'] for stats in self.pilot_stats.values())
        total_deaths = sum(stats['deaths'] for stats in self.pilot_stats.values())
        survivors = sum(1 for stats in self.pilot_stats.values() if stats['survived'])
        
        print(f"Total Pilots: {total_pilots}")
        print(f"Survivors: {survivors}")
        print(f"Casualties: {total_pilots - survivors}")
        print(f"Total Missiles Fired: {total_missiles}")
        print(f"Total Estimated Kills: {total_kills}")
        print(f"Total Aircraft Lost: {total_deaths}")
        
        if total_missiles > 0:
            print(f"Overall Estimated Hit Rate: {(total_kills / total_missiles * 100):.1f}%")
        
        # Coalition breakdown
        coalitions = {}
        for stats in self.pilot_stats.values():
            coalition = stats['coalition']
            if coalition not in coalitions:
                coalitions[coalition] = {
                    'pilots': 0, 'survivors': 0, 'missiles': 0, 'kills': 0, 'deaths': 0
                }
            
            coalitions[coalition]['pilots'] += 1
            if stats['survived']:
                coalitions[coalition]['survivors'] += 1
            coalitions[coalition]['missiles'] += stats['missiles_fired']
            coalitions[coalition]['kills'] += stats['air_to_air_kills']
            coalitions[coalition]['deaths'] += stats['deaths']
        
        print(f"\nCoalition Breakdown:")
        for coalition, data in coalitions.items():
            print(f"  {coalition}:")
            print(f"    Pilots: {data['pilots']} (Survivors: {data['survivors']})")
            print(f"    Missiles Fired: {data['missiles']}")
            print(f"    Estimated Kills: {data['kills']}")
            print(f"    Aircraft Lost: {data['deaths']}")
            if data['deaths'] > 0:
                print(f"    K/D Ratio: {data['kills'] / data['deaths']:.2f}")
            if data['missiles'] > 0:
                print(f"    Hit Rate: {data['kills'] / data['missiles'] * 100:.1f}%")
    
    def export_to_json(self, output_file):
        """Export statistics to JSON file"""
        output_data = {
            'mission_info': self.acmi.global_json(),
            'pilot_statistics': dict(self.pilot_stats),
            'analysis_timestamp': datetime.now().isoformat(),
            'analysis_notes': [
                "This analysis uses estimated missile assignments based on aircraft capabilities",
                "Kill estimates are based on coalition losses and missile effectiveness assumptions",
                "Actual combat results may differ from these estimates"
            ]
        }
        
        with open(output_file, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"Statistics exported to: {output_file}")
    
    def run_analysis(self):
        """Run the complete analysis"""
        if not self.load_acmi():
            return False
        
        self.analyze_combat_data()
        self.generate_report()
        
        return True

def main():
    parser = argparse.ArgumentParser(description='Analyze TACVIEW ACMI files for air-to-air combat statistics')
    parser.add_argument('acmi_file', help='Path to the ACMI file to analyze')
    parser.add_argument('--output', '-o', help='Output JSON file for statistics')
    
    args = parser.parse_args()
    
    analyzer = ImprovedCombatAnalyzer(args.acmi_file)
    
    if analyzer.run_analysis():
        if args.output:
            analyzer.export_to_json(args.output)
        print("\nAnalysis completed successfully!")
        print("\nNote: This analysis uses intelligent estimates based on available data.")
        print("For more precise results, timeline data analysis would be required.")
    else:
        print("Analysis failed!")
        sys.exit(1)

if __name__ == "__main__":
    main() 