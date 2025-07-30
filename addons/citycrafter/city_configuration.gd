@tool
class_name CityConfiguration
extends Resource

@export_group("Building Collections")
@export var residential_buildings: Array[PackedScene] = []
@export var commercial_buildings: Array[PackedScene] = []
@export var industrial_buildings: Array[PackedScene] = []
@export_group("Materials")
@export var road_material: Material
@export var intersection_material: Material
@export var subdivision_road_material: Material
@export var ground_material: Material
@export var residential_ground_material: Material
@export var commercial_ground_material: Material
@export var industrial_ground_material: Material
@export_group("City Layout Settings")
@export var grid_width: int = 10
@export var grid_height: int = 10
@export var block_size: float = 200.0
@export var street_width: float = 25.0
@export_range(0.0, 0.2) var empty_block_chance: float = 0.01
@export_group("Multi-Size Blocks")
@export var enable_multi_size_blocks: bool = false
@export_range(0.0, 1.0) var large_block_chance: float = 0.15
@export_range(0.0, 1.0) var wide_block_chance: float = 0.1
@export_range(0.0, 1.0) var tall_block_chance: float = 0.1
@export_group("City Shape Variations")
@export var enable_edge_variations: bool = true
@export_range(0.0, 1.0) var edge_variation_chance: float = 0.3
@export var max_edge_variation: int = 2
@export var enable_random_extensions: bool = true
@export var random_extensions_count: int = 5
@export_range(0.0, 1.0) var extension_spawn_chance: float = 0.4
@export_group("District Settings")
@export_enum("Noise Based", "Zoned Areas", "Random Mix") var district_mode: int = 0
@export_range(0.0, 1.0) var residential_ratio: float = 0.4
@export_range(0.0, 1.0) var commercial_ratio: float = 0.4
@export_range(0.0, 1.0) var industrial_ratio: float = 0.2
@export var noise_scale: float = 0.1
@export_group("Residential Density")
@export var enable_residential_subdivisions: bool = true
@export_enum("Fixed Layout", "Random Layout") var subdivision_mode: int = 1
@export_enum("2x2", "2x3", "3x3") var subdivision_layout: int = 0
@export var subdivision_street_width: float = 8.0
@export var residential_buildings_min: int = 3
@export var residential_buildings_max: int = 6
@export var residential_spacing: float = 20.0
@export var residential_border_margin: float = 15.0
@export_group("Commercial Density")
@export var commercial_buildings_min: int = 8
@export var commercial_buildings_max: int = 10
@export var commercial_spacing: float = 50.0
@export var commercial_border_margin: float = 25.0
@export_group("Industrial Density")
@export var industrial_buildings_min: int = 25
@export var industrial_buildings_max: int = 30
@export var industrial_spacing: float = 35.0
@export var industrial_border_margin: float = 25.0
@export_group("Building Variations")
@export_enum("Free", "90 Degrees", "No Rotation") var rotation_mode: int = 1
@export_range(-1.0, 1.0) var scale_variation: float = 0.3
@export_group("Ground and Roads")
@export var generate_roads: bool = true
@export var generate_intersections: bool = true
@export var intersection_height_offset: float = 0.01
@export var generate_subdivision_roads: bool = true
@export var generate_ground: bool = true
@export var ground_height_offset: float = -0.1

static func create_default() -> CityConfiguration:
	var config = CityConfiguration.new()
	return config

func is_valid() -> bool:
	return (residential_buildings.size() > 0 or 
			commercial_buildings.size() > 0 or 
			industrial_buildings.size() > 0)
