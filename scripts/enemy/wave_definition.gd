class_name WaveDefinition
extends Resource

@export var active_budget: int = 14
@export var infantry_count: int = 7
@export var archer_count: int = 3
@export var ladder_crew_count: int = 4
@export var ram_count: int = 0
@export var bossram_count: int = 0
@export var wave_gap: float = 6.0
@export var spawn_interval: float = 1.05
@export var staged_auto_start_delay: float = 7.0
@export var staging_horizon_distance: float = 22.0
@export var staging_width: float = 96.0
@export var staging_row_gap: float = 3.2

func unit_kinds() -> Array:
	var out: Array = []
	for _ram_index in ram_count:
		out.append("ram")
	for _boss_index in bossram_count:
		out.append("bossram")
	for _ladder_index in ladder_crew_count:
		out.append("ladder_crew")
	for _archer_index in archer_count:
		out.append("archer")
	for _infantry_index in infantry_count:
		out.append("infantry")
	return out

func unit_count_with_crews(ladder_carriers_per_crew: int, ladder_escorts_per_crew: int) -> int:
	return infantry_count + archer_count + ram_count + bossram_count + ladder_crew_count * (ladder_carriers_per_crew + ladder_escorts_per_crew)
