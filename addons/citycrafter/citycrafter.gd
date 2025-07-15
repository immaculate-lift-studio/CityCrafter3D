@tool
extends Node3D

@export var city_configuration: CityConfiguration
@export var generate_city_button: bool = false : set = _on_generate_pressed
@export var clear_city_button: bool = false : set = _on_clear_pressed

var noise: FastNoiseLite
var active_blocks: Array[Vector2i] = []

func _ready():
	if not city_configuration:
		city_configuration = CityConfiguration.create_default()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	if city_configuration:
		noise.frequency = city_configuration.noise_scale

func _on_generate_pressed(value):
	if value:
		generate_city()
		generate_city_button = false

func _on_clear_pressed(value):
	if value:
		clear_city()
		clear_city_button = false

func generate_city():
	if not city_configuration:
		print("Load a City Configuration Resource first!")
		return
	
	if not city_configuration.is_valid():
		print("No buildings assigned!")
		return

	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
	noise.frequency = city_configuration.noise_scale
	clear_all_buildings()
	generate_active_blocks()
	if city_configuration.generate_ground:
		generate_ground_planes()
	if city_configuration.generate_roads:
		generate_road_network()
	for block_pos in active_blocks:
		if randf() < city_configuration.empty_block_chance:
			continue
		generate_block(block_pos.x, block_pos.y)

func generate_active_blocks():
	active_blocks.clear()
	var base_blocks = generate_base_grid()
	if city_configuration.enable_edge_variations:
		base_blocks = apply_edge_variations(base_blocks)
	if city_configuration.enable_random_extensions:
		base_blocks = add_random_extensions(base_blocks)
	active_blocks = base_blocks

func generate_base_grid() -> Array[Vector2i]:
	var blocks: Array[Vector2i] = []
	for x in range(city_configuration.grid_width):
		for z in range(city_configuration.grid_height):
			blocks.append(Vector2i(x, z))
	return blocks

func apply_edge_variations(base_blocks: Array[Vector2i]) -> Array[Vector2i]:
	var varied_blocks = base_blocks.duplicate()  
	for x in range(city_configuration.grid_width):
		for z in range(city_configuration.grid_height):
			var is_edge = (x == 0 or x == city_configuration.grid_width - 1 or 
						  z == 0 or z == city_configuration.grid_height - 1)
			if is_edge:
				var adjacent_positions = [
					Vector2i(x, -1),  # Top
					Vector2i(x, city_configuration.grid_height),  # Bottom
					Vector2i(-1, z),  # Left
					Vector2i(city_configuration.grid_width, z)  # Right
				]
				for pos in adjacent_positions:
					if not block_exists_in_array(varied_blocks, pos):
						if randf() < city_configuration.edge_variation_chance:
							varied_blocks.append(pos)
	return varied_blocks

func add_random_extensions(base_blocks: Array[Vector2i]) -> Array[Vector2i]:
	var extended_blocks = base_blocks.duplicate()
	for i in range(city_configuration.random_extensions_count):
		if randf() > city_configuration.extension_spawn_chance:
			continue

		var edge_blocks = get_edge_blocks(extended_blocks)
		if edge_blocks.is_empty():
			continue
			
		var source_block = edge_blocks[randi() % edge_blocks.size()]
		var directions = [
			Vector2i(0, 1), 
			Vector2i(0, -1), 
			Vector2i(1, 0), 
			Vector2i(-1, 0)  
		]
		directions.shuffle()
		for direction in directions:
			var new_pos = source_block + direction
			if not block_exists_in_array(extended_blocks, new_pos):
				extended_blocks.append(new_pos)
				break
	
	return extended_blocks

func get_edge_blocks(blocks: Array[Vector2i]) -> Array[Vector2i]:
	var edge_blocks: Array[Vector2i] = []
	for block in blocks:
		var is_edge = false
		var directions = [
			Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
		]
		for direction in directions:
			var adjacent_pos = block + direction
			if not block_exists_in_array(blocks, adjacent_pos):
				is_edge = true
				break
		
		if is_edge:
			edge_blocks.append(block)
	return edge_blocks

func block_exists_in_array(blocks: Array[Vector2i], pos: Vector2i) -> bool:
	for block in blocks:
		if block == pos:
			return true
	return false

func generate_ground_planes():
	for block_pos in active_blocks:
		var block_center = Vector3(
			block_pos.x * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2,
			city_configuration.ground_height_offset,
			block_pos.y * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2
		)
		var district_type = get_district_type(block_pos.x, block_pos.y)
		create_ground_plane(block_center, Vector2(city_configuration.block_size, city_configuration.block_size), district_type)

func generate_road_network():
	generate_dynamic_roads()

func generate_dynamic_roads():
	var road_positions = {} 
	for block_pos in active_blocks:
		var x = block_pos.x
		var z = block_pos.y
		var top_road_key = "h_" + str(x) + "_" + str(z + 1)
		var bottom_road_key = "h_" + str(x) + "_" + str(z)
		if not road_positions.has(top_road_key):
			var top_road_center = Vector3(
				x * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2,
				0,
				(z + 1) * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2
			)
			create_road_plane(top_road_center, Vector2(city_configuration.block_size, city_configuration.street_width), "Road")
			road_positions[top_road_key] = true
		if not road_positions.has(bottom_road_key):
			var bottom_road_center = Vector3(
				x * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2,
				0,
				z * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2
			)
			create_road_plane(bottom_road_center, Vector2(city_configuration.block_size, city_configuration.street_width), "Road")
			road_positions[bottom_road_key] = true
		var right_road_key = "v_" + str(x + 1) + "_" + str(z)
		var left_road_key = "v_" + str(x) + "_" + str(z)
		if not road_positions.has(right_road_key):
			var right_road_center = Vector3(
				(x + 1) * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2,
				0,
				z * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2
			)
			create_road_plane(right_road_center, Vector2(city_configuration.street_width, city_configuration.block_size), "Road")
			road_positions[right_road_key] = true
		if not road_positions.has(left_road_key):
			var left_road_center = Vector3(
				x * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2,
				0,
				z * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2
			)
			create_road_plane(left_road_center, Vector2(city_configuration.street_width, city_configuration.block_size), "Road")
			road_positions[left_road_key] = true
	
	if city_configuration.generate_intersections:
		generate_intersections()

func generate_intersections():
	var min_x = 999999
	var max_x = -999999
	var min_z = 999999
	var max_z = -999999
	
	for block_pos in active_blocks:
		min_x = min(min_x, block_pos.x)
		max_x = max(max_x, block_pos.x)
		min_z = min(min_z, block_pos.y)
		max_z = max(max_z, block_pos.y)
	for x in range(min_x, max_x + 2):
		for z in range(min_z, max_z + 2):
			var has_horizontal_road = false
			var has_vertical_road = false
			var has_block_above = block_exists_in_array(active_blocks, Vector2i(x, z))
			var has_block_below = block_exists_in_array(active_blocks, Vector2i(x, z - 1))
			var has_block_above_left = block_exists_in_array(active_blocks, Vector2i(x - 1, z))
			var has_block_below_left = block_exists_in_array(active_blocks, Vector2i(x - 1, z - 1))
			has_horizontal_road = has_block_above or has_block_below or has_block_above_left or has_block_below_left
			var has_block_left = block_exists_in_array(active_blocks, Vector2i(x - 1, z))
			var has_block_right = block_exists_in_array(active_blocks, Vector2i(x, z))
			var has_block_left_above = block_exists_in_array(active_blocks, Vector2i(x - 1, z - 1))
			var has_block_right_above = block_exists_in_array(active_blocks, Vector2i(x, z - 1))
			has_vertical_road = has_block_left or has_block_right or has_block_left_above or has_block_right_above
			if has_horizontal_road and has_vertical_road:
				var intersection_center = Vector3(
					x * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2,
					city_configuration.intersection_height_offset,
					z * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2
				)
				create_intersection_plane(intersection_center, Vector2(city_configuration.street_width, city_configuration.street_width))

func create_intersection_plane(center: Vector3, size: Vector2):
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = size
	mesh_instance.mesh = plane_mesh
	if city_configuration.intersection_material:
		mesh_instance.material_override = city_configuration.intersection_material
	elif city_configuration.road_material:
		mesh_instance.material_override = city_configuration.road_material
	mesh_instance.position = center
	mesh_instance.name = "Intersection"
	add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

func create_road_plane(center: Vector3, size: Vector2, road_type: String):
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = size
	mesh_instance.mesh = plane_mesh
	if road_type == "SubdivisionRoad" and city_configuration.subdivision_road_material:
		mesh_instance.material_override = city_configuration.subdivision_road_material
	elif city_configuration.road_material:
		mesh_instance.material_override = city_configuration.road_material
	mesh_instance.position = center
	mesh_instance.name = road_type
	add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

func create_ground_plane(center: Vector3, size: Vector2, district_type: String = ""):
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = size
	mesh_instance.mesh = plane_mesh
	var material_to_use: Material = null
	match district_type:
		"residential":
			material_to_use = city_configuration.residential_ground_material
		"commercial":
			material_to_use = city_configuration.commercial_ground_material
		"industrial":
			material_to_use = city_configuration.industrial_ground_material

	if not material_to_use:
		material_to_use = city_configuration.ground_material
	if material_to_use:
		mesh_instance.material_override = material_to_use
	mesh_instance.position = center
	mesh_instance.name = "Ground_" + district_type if district_type != "" else "Ground"
	add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

func get_district_type(grid_x: int, grid_z: int) -> String:
	var clamped_x = clamp(grid_x, 0, city_configuration.grid_width - 1)
	var clamped_z = clamp(grid_z, 0, city_configuration.grid_height - 1)
	match city_configuration.district_mode:
		0: 
			var noise_value = noise.get_noise_2d(clamped_x, clamped_z)
			noise_value = (noise_value + 1.0) / 2.0
			var total_ratio = city_configuration.residential_ratio + city_configuration.commercial_ratio + city_configuration.industrial_ratio
			if total_ratio <= 0:
				return "residential"
			
			var normalized_residential = city_configuration.residential_ratio / total_ratio
			var normalized_commercial = city_configuration.commercial_ratio / total_ratio
			if noise_value < normalized_residential:
				return "residential"
			elif noise_value < normalized_residential + normalized_commercial:
				return "commercial"
			else:
				return "industrial"
		1: 
			var center_x = city_configuration.grid_width / 2.0
			var center_z = city_configuration.grid_height / 2.0
			var dist_from_center = Vector2(clamped_x - center_x, clamped_z - center_z).length()
			var max_dist = Vector2(center_x, center_z).length()
			var normalized_dist = dist_from_center / max_dist if max_dist > 0 else 0
			var total_ratio = city_configuration.residential_ratio + city_configuration.commercial_ratio + city_configuration.industrial_ratio
			if total_ratio <= 0:
				return "residential"
			
			var normalized_commercial = city_configuration.commercial_ratio / total_ratio
			var normalized_residential = city_configuration.residential_ratio / total_ratio
			if normalized_dist < normalized_commercial:
				return "commercial"
			elif normalized_dist < normalized_commercial + normalized_residential:
				return "residential"
			else:
				return "industrial"
		2:
			var seed_value = clamped_x * 1000 + clamped_z
			var rng = RandomNumberGenerator.new()
			rng.seed = seed_value
			var rand_val = rng.randf()
			var total_ratio = city_configuration.residential_ratio + city_configuration.commercial_ratio + city_configuration.industrial_ratio
			if total_ratio <= 0:
				return "residential" # Fallback
			
			var normalized_residential = city_configuration.residential_ratio / total_ratio
			var normalized_commercial = city_configuration.commercial_ratio / total_ratio
			if rand_val < normalized_residential:
				return "residential"
			elif rand_val < normalized_residential + normalized_commercial:
				return "commercial"
			else:
				return "industrial"
	
	return "residential"

func get_buildings_for_district(district: String) -> Array[PackedScene]:
	match district:
		"residential":
			return city_configuration.residential_buildings
		"commercial":
			return city_configuration.commercial_buildings
		"industrial":
			return city_configuration.industrial_buildings
		_:
			return city_configuration.residential_buildings

func get_district_density_settings(district: String) -> Dictionary:
	match district:
		"residential":
			return {
				"min_buildings": city_configuration.residential_buildings_min,
				"max_buildings": city_configuration.residential_buildings_max,
				"spacing": city_configuration.residential_spacing,
				"border_margin": city_configuration.residential_border_margin
			}
		"commercial":
			return {
				"min_buildings": city_configuration.commercial_buildings_min,
				"max_buildings": city_configuration.commercial_buildings_max,
				"spacing": city_configuration.commercial_spacing,
				"border_margin": city_configuration.commercial_border_margin
			}
		"industrial":
			return {
				"min_buildings": city_configuration.industrial_buildings_min,
				"max_buildings": city_configuration.industrial_buildings_max,
				"spacing": city_configuration.industrial_spacing,
				"border_margin": city_configuration.industrial_border_margin
			}
		_:
			return {
				"min_buildings": 1,
				"max_buildings": 4,
				"spacing": 20.0,
				"border_margin": 10.0
			}

func get_subdivision_grid() -> Vector2i:
	match city_configuration.subdivision_mode:
		0: 
			match city_configuration.subdivision_layout:
				0: return Vector2i(2, 2)
				1: return Vector2i(2, 3)
				2: return Vector2i(3, 3)
				_: return Vector2i(2, 2)
		1: 
			var layouts = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)]
			return layouts[randi() % layouts.size()]
		_:
			return Vector2i(2, 2)

func generate_block(grid_x: int, grid_z: int):
	var district = get_district_type(grid_x, grid_z)
	var available_buildings = get_buildings_for_district(district)
	
	if available_buildings.is_empty():
		print("No buildings assigned to district: ", district)
		return
	
	if district == "residential" and city_configuration.enable_residential_subdivisions:
		generate_subdivided_block(grid_x, grid_z, available_buildings)
	else:
		generate_regular_block(grid_x, grid_z, available_buildings, district)

func generate_subdivided_block(grid_x: int, grid_z: int, available_buildings: Array[PackedScene]):
	var block_center = Vector3(
		grid_x * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2,
		0,
		grid_z * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2
	)
	var subdivision_grid = get_subdivision_grid()
	var density_settings = get_district_density_settings("residential")
	var total_internal_street_width_x = (subdivision_grid.x - 1) * city_configuration.subdivision_street_width
	var total_internal_street_width_z = (subdivision_grid.y - 1) * city_configuration.subdivision_street_width
	var subdivision_size_x = (city_configuration.block_size - total_internal_street_width_x) / subdivision_grid.x
	var subdivision_size_z = (city_configuration.block_size - total_internal_street_width_z) / subdivision_grid.y
	if city_configuration.generate_subdivision_roads:
		generate_subdivision_road_network(block_center, subdivision_grid, subdivision_size_x, subdivision_size_z)
	for sub_x in range(subdivision_grid.x):
		for sub_z in range(subdivision_grid.y):
			var local_x = (sub_x - subdivision_grid.x / 2.0 + 0.5) * (subdivision_size_x + city_configuration.subdivision_street_width)
			var local_z = (sub_z - subdivision_grid.y / 2.0 + 0.5) * (subdivision_size_z + city_configuration.subdivision_street_width)
			var subdivision_center = block_center + Vector3(local_x, 0, local_z)
			var building_count = randi_range(density_settings.min_buildings, density_settings.max_buildings)
			var building_positions = []
			var max_attempts = building_count * 10
			for i in range(building_count):
				var attempts = 0
				var valid_position = false
				while not valid_position and attempts < max_attempts:
					var local_pos = Vector3(
						randf_range(-subdivision_size_x/2 + density_settings.border_margin, subdivision_size_x/2 - density_settings.border_margin),
						0,
						randf_range(-subdivision_size_z/2 + density_settings.border_margin, subdivision_size_z/2 - density_settings.border_margin)
					)
					var world_pos = subdivision_center + local_pos
					valid_position = true
					for existing_pos in building_positions:
						if world_pos.distance_to(existing_pos) < density_settings.spacing:
							valid_position = false
							break
					if valid_position:
						building_positions.append(world_pos)
						spawn_building_at_position(world_pos, available_buildings)
					
					attempts += 1

func generate_subdivision_road_network(block_center: Vector3, subdivision_grid: Vector2i, subdivision_size_x: float, subdivision_size_z: float):
	for i in range(subdivision_grid.y - 1):
		var z_offset = (i - (subdivision_grid.y - 2) / 2.0) * (subdivision_size_z + city_configuration.subdivision_street_width)
		var road_center = block_center + Vector3(0, 0, z_offset)
		create_road_plane(road_center, Vector2(city_configuration.block_size, city_configuration.subdivision_street_width), "SubdivisionRoad")
	for i in range(subdivision_grid.x - 1):
		var x_offset = (i - (subdivision_grid.x - 2) / 2.0) * (subdivision_size_x + city_configuration.subdivision_street_width)
		var road_center = block_center + Vector3(x_offset, 0, 0)
		create_road_plane(road_center, Vector2(city_configuration.subdivision_street_width, city_configuration.block_size), "SubdivisionRoad")

func generate_regular_block(grid_x: int, grid_z: int, available_buildings: Array[PackedScene], district: String):
	var density_settings = get_district_density_settings(district)
	var block_center = Vector3(
		grid_x * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2,
		0,
		grid_z * (city_configuration.block_size + city_configuration.street_width) + city_configuration.block_size / 2
	)
	var building_count = randi_range(density_settings.min_buildings, density_settings.max_buildings)
	var building_positions = []
	var max_attempts = building_count * 10
	for i in range(building_count):
		var attempts = 0
		var valid_position = false
		while not valid_position and attempts < max_attempts:
			var local_pos = Vector3(
				randf_range(-city_configuration.block_size/2 + density_settings.border_margin, city_configuration.block_size/2 - density_settings.border_margin),
				0,
				randf_range(-city_configuration.block_size/2 + density_settings.border_margin, city_configuration.block_size/2 - density_settings.border_margin)
			)
			var world_pos = block_center + local_pos
			valid_position = true
			for existing_pos in building_positions:
				if world_pos.distance_to(existing_pos) < density_settings.spacing:
					valid_position = false
					break
			if valid_position:
				building_positions.append(world_pos)
				spawn_building_at_position(world_pos, available_buildings)
			attempts += 1

func spawn_building_at_position(world_pos: Vector3, available_buildings: Array[PackedScene]):
	var building_scene = available_buildings[randi() % available_buildings.size()]
	var building = building_scene.instantiate()
	building.position = world_pos
	match city_configuration.rotation_mode:
		0: 
			building.rotation.y = randf_range(0, TAU)
		1:
			var rotation_steps = [0, PI/2, PI, 3*PI/2]
			building.rotation.y = rotation_steps[randi() % rotation_steps.size()]
		2: 
			building.rotation.y = 0
	if city_configuration.scale_variation != 0:
		var scale_factor = 1.0 + randf_range(-city_configuration.scale_variation, city_configuration.scale_variation)
		building.scale = Vector3.ONE * scale_factor
	add_child(building)
	building.owner = get_tree().edited_scene_root

func clear_city():
	clear_all_buildings()
	active_blocks.clear()

func clear_all_buildings():
	for child in get_children():
		child.queue_free()
