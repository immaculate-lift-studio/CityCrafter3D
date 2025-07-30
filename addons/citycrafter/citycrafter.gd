@tool
extends Node3D

signal generation_progress(current: int, total: int, stage: String)
signal generation_complete()

@export var city_configuration: CityConfiguration
@export var generate_city_button: bool = false : set = _on_generate_pressed
@export var clear_city_button: bool = false : set = _on_clear_pressed
@export_group("Performance Settings")
@export var blocks_per_frame: int = 2
@export var buildings_per_frame: int = 5 
@export var enable_progress_feedback: bool = true

var noise: FastNoiseLite
var active_blocks: Array[Vector2i] = []
var block_sizes: Dictionary = {} 
var is_generating: bool = false

func _ready():
	if not city_configuration:
		city_configuration = CityConfiguration.create_default()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	if city_configuration:
		noise.frequency = city_configuration.noise_scale

func _on_generate_pressed(value):
	if value:
		if not is_generating:
			generate_city_async()
		generate_city_button = false

func _on_clear_pressed(value):
	if value:
		clear_city()
		clear_city_button = false

func generate_city_async():
	if not city_configuration:
		print("Load a City Configuration Resource first!")
		return
	
	if not city_configuration.is_valid():
		print("No buildings assigned!")
		return

	if is_generating:
		print("Generation already in progress!")
		return
		
	is_generating = true
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
	noise.frequency = city_configuration.noise_scale
	clear_all_buildings()
	emit_progress(0, 100, "Calculating city layout...")
	generate_active_blocks()
	await get_tree().process_frame
	if city_configuration.generate_ground:
		await generate_ground_planes_async()
	if city_configuration.generate_roads:
		await generate_road_network_async()
	await generate_buildings_async()
	is_generating = false
	emit_progress(100, 100, "Generation complete!")
	generation_complete.emit()

func generate_active_blocks():
	active_blocks.clear()
	block_sizes.clear()
	var base_blocks = generate_base_grid_with_sizes()
	if city_configuration.enable_edge_variations:
		base_blocks = apply_edge_variations_with_sizes(base_blocks)
	if city_configuration.enable_random_extensions:
		base_blocks = add_random_extensions_with_sizes(base_blocks)
	for block_data in base_blocks:
		var pos: Vector2i = block_data.position
		var size: Vector2i = block_data.size
		if not block_sizes.has(pos):
			active_blocks.append(pos)
			block_sizes[pos] = size

func generate_base_grid_with_sizes() -> Array:
	var blocks = []
	var occupied_positions = {}
	for x in range(city_configuration.grid_width):
		for z in range(city_configuration.grid_height):
			var pos = Vector2i(x, z)
			if occupied_positions.has(pos):
				continue
			
			var block_size = Vector2i(1, 1) 
			if city_configuration.enable_multi_size_blocks:
				block_size = determine_block_size(x, z, occupied_positions)
			blocks.append({
				"position": pos,
				"size": block_size
			})
			for bx in range(block_size.x):
				for bz in range(block_size.y):
					var occupied_pos = Vector2i(x + bx, z + bz)
					occupied_positions[occupied_pos] = true
	return blocks

func determine_block_size(x: int, z: int, occupied_positions: Dictionary) -> Vector2i:
	var available_sizes = []
	if can_place_block_size(x, z, Vector2i(2, 2), occupied_positions):
		available_sizes.append({"size": Vector2i(2, 2), "chance": city_configuration.large_block_chance})
	if can_place_block_size(x, z, Vector2i(2, 1), occupied_positions):
		available_sizes.append({"size": Vector2i(2, 1), "chance": city_configuration.wide_block_chance})
	if can_place_block_size(x, z, Vector2i(1, 2), occupied_positions):
		available_sizes.append({"size": Vector2i(1, 2), "chance": city_configuration.tall_block_chance})
	available_sizes.append({"size": Vector2i(1, 1), "chance": 1.0})
	for size_option in available_sizes:
		if randf() < size_option.chance:
			return size_option.size

	return Vector2i(1, 1)

func can_place_block_size(x: int, z: int, size: Vector2i, occupied_positions: Dictionary) -> bool:
	if x + size.x > city_configuration.grid_width or z + size.y > city_configuration.grid_height:
		return false

	for bx in range(size.x):
		for bz in range(size.y):
			var check_pos = Vector2i(x + bx, z + bz)
			if occupied_positions.has(check_pos):
				return false
	
	return true

func apply_edge_variations_with_sizes(base_blocks: Array) -> Array:
	var varied_blocks = base_blocks.duplicate()
	var occupied_positions = {}
	for block_data in base_blocks:
		var pos = block_data.position
		var size = block_data.size
		for bx in range(size.x):
			for bz in range(size.y):
				occupied_positions[Vector2i(pos.x + bx, pos.y + bz)] = true
	for block_data in base_blocks:
		var pos = block_data.position
		var is_edge = (pos.x == 0 or pos.x >= city_configuration.grid_width - 1 or 
					  pos.y == 0 or pos.y >= city_configuration.grid_height - 1)
		if is_edge:
			var adjacent_positions = [
				Vector2i(pos.x, pos.y - 1),
				Vector2i(pos.x, pos.y + 1), 
				Vector2i(pos.x - 1, pos.y), 
				Vector2i(pos.x + 1, pos.y) 
			]
			for adj_pos in adjacent_positions:
				if not occupied_positions.has(adj_pos) and randf() < city_configuration.edge_variation_chance:
					varied_blocks.append({
						"position": adj_pos,
						"size": Vector2i(1, 1)
					})
					occupied_positions[adj_pos] = true
	return varied_blocks

func add_random_extensions_with_sizes(base_blocks: Array) -> Array:
	var extended_blocks = base_blocks.duplicate()
	var occupied_positions = {}
	for block_data in base_blocks:
		var pos = block_data.position
		var size = block_data.size
		for bx in range(size.x):
			for bz in range(size.y):
				occupied_positions[Vector2i(pos.x + bx, pos.y + bz)] = true
	for i in range(city_configuration.random_extensions_count):
		if randf() > city_configuration.extension_spawn_chance:
			continue
		
		var edge_blocks = get_edge_blocks_from_sized_array(extended_blocks)
		if edge_blocks.is_empty():
			continue
		
		var source_block = edge_blocks[randi() % edge_blocks.size()]
		var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		directions.shuffle()
		for direction in directions:
			var new_pos = source_block + direction
			if not occupied_positions.has(new_pos):
				extended_blocks.append({
					"position": new_pos,
					"size": Vector2i(1, 1)
				})
				occupied_positions[new_pos] = true
				break
	
	return extended_blocks

func get_edge_blocks_from_sized_array(blocks: Array) -> Array[Vector2i]:
	var edge_blocks: Array[Vector2i] = []
	var all_positions = {}
	for block_data in blocks:
		var pos = block_data.position
		var size = block_data.size
		for bx in range(size.x):
			for bz in range(size.y):
				all_positions[Vector2i(pos.x + bx, pos.y + bz)] = true
	for block_data in blocks:
		var pos = block_data.position
		var size = block_data.size
		var is_edge = false
		for bx in range(size.x):
			for bz in range(size.y):
				var check_pos = Vector2i(pos.x + bx, pos.y + bz)
				var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
				for direction in directions:
					var adjacent_pos = check_pos + direction
					if not all_positions.has(adjacent_pos):
						is_edge = true
						break
				
				if is_edge:
					break
			if is_edge:
				break
		
		if is_edge:
			edge_blocks.append(pos)
	return edge_blocks

func generate_ground_planes_async():
	emit_progress(10, 100, "Generating ground planes...")
	var total_blocks = active_blocks.size()
	var processed = 0
	for i in range(0, total_blocks, blocks_per_frame):
		var end_idx = min(i + blocks_per_frame, total_blocks)
		for j in range(i, end_idx):
			var block_pos = active_blocks[j]
			var block_size = block_sizes.get(block_pos, Vector2i(1, 1))
			var world_width = block_size.x * city_configuration.block_size + (block_size.x - 1) * city_configuration.street_width
			var world_height = block_size.y * city_configuration.block_size + (block_size.y - 1) * city_configuration.street_width
			var block_center = Vector3(
				block_pos.x * (city_configuration.block_size + city_configuration.street_width) + world_width / 2,
				city_configuration.ground_height_offset,
				block_pos.y * (city_configuration.block_size + city_configuration.street_width) + world_height / 2
			)
			var district_type = get_district_type(block_pos.x, block_pos.y)
			create_ground_plane(block_center, Vector2(world_width, world_height), district_type)
			processed += 1
		var progress = 10 + (processed * 20 / total_blocks)
		emit_progress(progress, 100, "Generating ground planes... (%d/%d)" % [processed, total_blocks])
		await get_tree().process_frame

func generate_road_network_async():
	emit_progress(30, 100, "Generating roads...")
	await generate_dynamic_roads_async()
	emit_progress(40, 100, "Roads complete!")

func generate_dynamic_roads_async():
	var road_positions = {}
	var roads_to_create = []
	var horizontal_roads = {}
	var vertical_roads = {}
	var min_x = 999999
	var max_x = -999999
	var min_z = 999999
	var max_z = -999999
	
	for block_pos in active_blocks:
		var block_size = block_sizes.get(block_pos, Vector2i(1, 1))
		min_x = min(min_x, block_pos.x)
		max_x = max(max_x, block_pos.x + block_size.x - 1)
		min_z = min(min_z, block_pos.y)
		max_z = max(max_z, block_pos.y + block_size.y - 1)
	for block_pos in active_blocks:
		var block_size = block_sizes.get(block_pos, Vector2i(1, 1))
		var block_end_x = block_pos.x + block_size.x - 1
		var block_end_z = block_pos.y + block_size.y - 1
		var top_road_z = block_end_z + 1
		var bottom_road_z = block_pos.y
		if not horizontal_roads.has(str(top_road_z)):
			horizontal_roads[str(top_road_z)] = []
		if not horizontal_roads.has(str(bottom_road_z)):
			horizontal_roads[str(bottom_road_z)] = []
		horizontal_roads[str(top_road_z)].append({"start": block_pos.x, "end": block_end_x})
		horizontal_roads[str(bottom_road_z)].append({"start": block_pos.x, "end": block_end_x})
		var left_road_x = block_pos.x
		var right_road_x = block_end_x + 1
		if not vertical_roads.has(str(left_road_x)):
			vertical_roads[str(left_road_x)] = []
		if not vertical_roads.has(str(right_road_x)):
			vertical_roads[str(right_road_x)] = []
		vertical_roads[str(left_road_x)].append({"start": block_pos.y, "end": block_end_z})
		vertical_roads[str(right_road_x)].append({"start": block_pos.y, "end": block_end_z})

	for z_str in horizontal_roads.keys():
		var z = int(z_str)
		var merged = merge_road_segments(horizontal_roads[z_str])
		for segment in merged:
			var key = "h_%s_%s_%s" % [segment.start, segment.end, z]
			if not road_positions.has(key):
				var seg_w = (segment.end - segment.start + 1) * city_configuration.block_size + (segment.end - segment.start) * city_configuration.street_width
				var cx = segment.start * (city_configuration.block_size + city_configuration.street_width) + seg_w / 2
				var cz = z * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2
				roads_to_create.append({
					"center": Vector3(cx, 0, cz),
					"size": Vector2(seg_w, city_configuration.street_width),
					"type": "Road"
				})
				road_positions[key] = true

	for x_str in vertical_roads.keys():
		var x = int(x_str)
		var merged = merge_road_segments(vertical_roads[x_str])
		for segment in merged:
			var key = "v_%s_%s_%s" % [x, segment.start, segment.end]
			if not road_positions.has(key):
				var seg_h = (segment.end - segment.start + 1) * city_configuration.block_size + (segment.end - segment.start) * city_configuration.street_width
				var cx = x * (city_configuration.block_size + city_configuration.street_width) - city_configuration.street_width / 2
				var cz = segment.start * (city_configuration.block_size + city_configuration.street_width) + seg_h / 2
				roads_to_create.append({
					"center": Vector3(cx, 0, cz),
					"size": Vector2(city_configuration.street_width, seg_h),
					"type": "Road"
				})
				road_positions[key] = true
	var total = roads_to_create.size()
	var count = 0
	for i in range(0, total, buildings_per_frame * 2):
		var end_idx = min(i + buildings_per_frame * 2, total)
		for j in range(i, end_idx):
			var rd = roads_to_create[j]
			create_road_plane(rd.center, rd.size, rd.type)
			count += 1
		if count % 10 == 0:
			await get_tree().process_frame

	var w = city_configuration.grid_width
	var h = city_configuration.grid_height
	if not horizontal_roads.has(str(h)):
		horizontal_roads[str(h)] = []
	horizontal_roads[str(h)].append({
		"start": 0,
		"end": w - 1
	})

	if not vertical_roads.has(str(w)):
		vertical_roads[str(w)] = []
	vertical_roads[str(w)].append({
		"start": 0,
		"end": h - 1
	})
	if city_configuration.generate_intersections:
		await generate_intersections_async(horizontal_roads, vertical_roads)


func merge_road_segments(segments: Array) -> Array:
	if segments.is_empty():
		return []
	
	segments.sort_custom(func(a, b): return a.start < b.start)
	var merged = []
	var current = segments[0]
	for i in range(1, segments.size()):
		var next_segment = segments[i]
		if next_segment.start <= current.end + 1:
			current.end = max(current.end, next_segment.end)
		else:
			merged.append(current)
			current = next_segment
	merged.append(current)
	return merged

func generate_intersections_async(horizontal_roads: Dictionary, vertical_roads: Dictionary) -> void:
	var min_x = 999999
	var max_x = -999999
	var min_z = 999999
	var max_z = -999999
	for pos in active_blocks:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_z = min(min_z, pos.y)
		max_z = max(max_z, pos.y)
	var interior_seams: Array[Vector2i] = []
	for block_pos in block_sizes.keys():
		var size: Vector2i = block_sizes[block_pos]
		if size.x > 1 and size.y > 1:
			for dx in range(1, size.x):
				for dz in range(1, size.y):
					interior_seams.append(Vector2i(block_pos.x + dx, block_pos.y + dz))
	for x in range(min_x, max_x + 2):
		for z in range(min_z, max_z + 2):
			var seam = Vector2i(x, z)
			if block_exists_in_array(interior_seams, seam):
				continue

			var has_block_above      = block_exists_in_array(active_blocks, Vector2i(x,   z  ))
			var has_block_below      = block_exists_in_array(active_blocks, Vector2i(x,   z-1))
			var has_block_above_left = block_exists_in_array(active_blocks, Vector2i(x-1, z  ))
			var has_block_below_left = block_exists_in_array(active_blocks, Vector2i(x-1, z-1))
			var has_horizontal_road  = has_block_above or has_block_below or has_block_above_left or has_block_below_left
			var has_block_left       = block_exists_in_array(active_blocks, Vector2i(x-1, z  ))
			var has_block_right      = block_exists_in_array(active_blocks, Vector2i(x,   z  ))
			var has_block_left_above = block_exists_in_array(active_blocks, Vector2i(x-1, z-1))
			var has_block_right_above= block_exists_in_array(active_blocks, Vector2i(x,   z-1))
			var has_vertical_road    = has_block_left or has_block_right or has_block_left_above or has_block_right_above
			if has_horizontal_road and has_vertical_road:
				var center = Vector3(
					x * (city_configuration.block_size + city_configuration.street_width)
						- city_configuration.street_width * 0.5,
					city_configuration.intersection_height_offset,
					z * (city_configuration.block_size + city_configuration.street_width)
						- city_configuration.street_width * 0.5
				)
				create_intersection_plane(center, Vector2(
					city_configuration.street_width,
					city_configuration.street_width
				))
				await get_tree().process_frame


func generate_buildings_async():
	emit_progress(40, 100, "Generating buildings...")
	var total_blocks = active_blocks.size()
	var processed_blocks = 0
	for block_pos in active_blocks:
		if randf() < city_configuration.empty_block_chance:
			processed_blocks += 1
			continue
		
		await generate_block_async(block_pos.x, block_pos.y)
		processed_blocks += 1
		var progress = 40 + (processed_blocks * 50 / total_blocks)  # Buildings take 50% of total progress
		emit_progress(progress, 100, "Generating buildings... (%d/%d blocks)" % [processed_blocks, total_blocks])

func generate_block_async(grid_x: int, grid_z: int):
	var district = get_district_type(grid_x, grid_z)
	var available_buildings = get_buildings_for_district(district)
	if available_buildings.is_empty():
		print("No buildings assigned to district: ", district)
		return

	var block_pos = Vector2i(grid_x, grid_z)
	var block_size = block_sizes.get(block_pos, Vector2i(1, 1))
	if district == "residential" and city_configuration.enable_residential_subdivisions:
		await generate_subdivided_block_async(grid_x, grid_z, available_buildings, block_size)
	else:
		await generate_regular_block_async(grid_x, grid_z, available_buildings, district, block_size)

func generate_regular_block_async(grid_x: int, grid_z: int, available_buildings: Array[PackedScene], district: String, block_size: Vector2i = Vector2i(1, 1)):
	var density_settings = get_district_density_settings(district)
	var world_width = block_size.x * city_configuration.block_size + (block_size.x - 1) * city_configuration.street_width
	var world_height = block_size.y * city_configuration.block_size + (block_size.y - 1) * city_configuration.street_width
	var block_center = Vector3(
		grid_x * (city_configuration.block_size + city_configuration.street_width) + world_width / 2,
		0,
		grid_z * (city_configuration.block_size + city_configuration.street_width) + world_height / 2
	)
	var size_multiplier = block_size.x * block_size.y
	var building_count = randi_range(
		density_settings.min_buildings * size_multiplier, 
		density_settings.max_buildings * size_multiplier
	)
	var building_positions = []
	var buildings_to_spawn = []
	var max_attempts = building_count * 10
	for i in range(building_count):
		var attempts = 0
		var valid_position = false
		while not valid_position and attempts < max_attempts:
			var local_pos = Vector3(
				randf_range(-world_width/2 + density_settings.border_margin, world_width/2 - density_settings.border_margin),
				0,
				randf_range(-world_height/2 + density_settings.border_margin, world_height/2 - density_settings.border_margin)
			)
			var world_pos = block_center + local_pos
			valid_position = true
			for existing_pos in building_positions:
				if world_pos.distance_to(existing_pos) < density_settings.spacing:
					valid_position = false
					break
			if valid_position:
				building_positions.append(world_pos)
				buildings_to_spawn.append(world_pos)
			attempts += 1
	for i in range(0, buildings_to_spawn.size(), buildings_per_frame):
		var end_idx = min(i + buildings_per_frame, buildings_to_spawn.size())
		for j in range(i, end_idx):
			var world_pos = buildings_to_spawn[j]
			spawn_building_at_position(world_pos, available_buildings)
		if i > 0: 
			await get_tree().process_frame

func generate_subdivided_block_async(grid_x: int, grid_z: int, available_buildings: Array[PackedScene], block_size: Vector2i = Vector2i(1, 1)):
	var world_width = block_size.x * city_configuration.block_size + (block_size.x - 1) * city_configuration.street_width
	var world_height = block_size.y * city_configuration.block_size + (block_size.y - 1) * city_configuration.street_width
	var block_center = Vector3(
		grid_x * (city_configuration.block_size + city_configuration.street_width) + world_width / 2,
		0,
		grid_z * (city_configuration.block_size + city_configuration.street_width) + world_height / 2
	)
	var subdivision_grid = get_subdivision_grid()
	var density_settings = get_district_density_settings("residential")
	subdivision_grid.x *= block_size.x
	subdivision_grid.y *= block_size.y
	var total_internal_street_width_x = (subdivision_grid.x - 1) * city_configuration.subdivision_street_width
	var total_internal_street_width_z = (subdivision_grid.y - 1) * city_configuration.subdivision_street_width
	var subdivision_size_x = (world_width - total_internal_street_width_x) / subdivision_grid.x
	var subdivision_size_z = (world_height - total_internal_street_width_z) / subdivision_grid.y
	if city_configuration.generate_subdivision_roads:
		generate_subdivision_road_network(block_center, subdivision_grid, subdivision_size_x, subdivision_size_z, world_width, world_height)
	var total_subdivisions = subdivision_grid.x * subdivision_grid.y
	var processed_subdivisions = 0
	for sub_x in range(subdivision_grid.x):
		for sub_z in range(subdivision_grid.y):
			var local_x = (sub_x - subdivision_grid.x / 2.0 + 0.5) * (subdivision_size_x + city_configuration.subdivision_street_width)
			var local_z = (sub_z - subdivision_grid.y / 2.0 + 0.5) * (subdivision_size_z + city_configuration.subdivision_street_width)
			var subdivision_center = block_center + Vector3(local_x, 0, local_z)
			var building_count = randi_range(density_settings.min_buildings, density_settings.max_buildings)
			var building_positions = []
			var buildings_to_spawn = []
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
						buildings_to_spawn.append(world_pos)
					attempts += 1
			for world_pos in buildings_to_spawn:
				spawn_building_at_position(world_pos, available_buildings)
			processed_subdivisions += 1
			if processed_subdivisions % 4 == 0:
				await get_tree().process_frame

func emit_progress(current: int, total: int, stage: String):
	if enable_progress_feedback:
		generation_progress.emit(current, total, stage)
		print("Progress: %d%% - %s" % [current, stage])

func block_exists_in_array(blocks: Array[Vector2i], pos: Vector2i) -> bool:
	for block in blocks:
		if block == pos:
			return true
	return false

func get_district_type(grid_x: int, grid_z: int) -> String:
	var clamped_x = clamp(grid_x, 0, city_configuration.grid_width - 1)
	var clamped_z = clamp(grid_z, 0, city_configuration.grid_height - 1)
	match city_configuration.district_mode:
		0: 
			var noise_value = noise.get_noise_2d(clamped_x, clamped_z)
			noise_value = (noise_value + 1.0) / 2.0
			if noise_value < city_configuration.residential_ratio:
				return "residential"
			elif noise_value < city_configuration.residential_ratio + city_configuration.commercial_ratio:
				return "commercial"
			else:
				return "industrial"
		1: 
			var center_x = city_configuration.grid_width / 2.0
			var center_z = city_configuration.grid_height / 2.0
			var dist_from_center = Vector2(clamped_x - center_x, clamped_z - center_z).length()
			var max_dist = Vector2(center_x, center_z).length()
			var normalized_dist = dist_from_center / max_dist if max_dist > 0 else 0
			if normalized_dist < 0.3:
				return "commercial"
			elif normalized_dist > 0.7:
				return "industrial"
			else:
				return "residential"
		2:
			var seed_value = clamped_x * 1000 + clamped_z
			var rng = RandomNumberGenerator.new()
			rng.seed = seed_value
			var rand_val = rng.randf()
			if rand_val < city_configuration.residential_ratio:
				return "residential"
			elif rand_val < city_configuration.residential_ratio + city_configuration.commercial_ratio:
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

func generate_subdivision_road_network(block_center: Vector3, subdivision_grid: Vector2i, subdivision_size_x: float, subdivision_size_z: float, world_width: float = 0, world_height: float = 0):
	var actual_width = world_width if world_width > 0 else city_configuration.block_size
	var actual_height = world_height if world_height > 0 else city_configuration.block_size
	if subdivision_grid.x <= 1 and subdivision_grid.y <= 1:
		return

	for i in range(subdivision_grid.y - 1):
		var z_offset = (i - (subdivision_grid.y - 2) / 2.0) * (subdivision_size_z + city_configuration.subdivision_street_width)
		var road_center = block_center + Vector3(0, city_configuration.intersection_height_offset * 2, z_offset)  # Slightly higher than main roads
		create_road_plane(road_center, Vector2(actual_width, city_configuration.subdivision_street_width), "SubdivisionRoad")
	for i in range(subdivision_grid.x - 1):
		var x_offset = (i - (subdivision_grid.x - 2) / 2.0) * (subdivision_size_x + city_configuration.subdivision_street_width)
		var road_center = block_center + Vector3(x_offset, city_configuration.intersection_height_offset * 2, 0)  # Slightly higher than main roads
		create_road_plane(road_center, Vector2(city_configuration.subdivision_street_width, actual_height), "SubdivisionRoad")

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

func clear_city():
	if is_generating:
		print("Cannot clear city while generation is in progress!")
		return
	clear_all_buildings()
	active_blocks.clear()
	block_sizes.clear()

func clear_all_buildings():
	for child in get_children():
		child.queue_free()
