extends Node2D

signal slice_impact

var is_cutting: bool = false
var cut_start_position: Vector2
var cut_direction: float
var current_position: Vector2

var cut_path_line: Line2D
var cutter_blade: Sprite2D

var next_slice_tick: float = 0.0
var _blade_jitter_time: float = 0.0

var targets: Array[Polygon2D] = []
var particles = preload("res://gravity_demo/cpu_particles_2d.tscn")
var blade_texture = preload("res://assets/cutter-knife-base.png")

func _ready() -> void:
	cut_path_line = Line2D.new()
	cut_path_line.width = CuttingConfig.CUT_PATH_WIDTH
	cut_path_line.default_color = CuttingConfig.CUT_PATH_COLOR
	cut_path_line.visible = false
	cut_path_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(cut_path_line)

	cutter_blade = Sprite2D.new()
	cutter_blade.texture = blade_texture
	cutter_blade.visible = false
	cutter_blade.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(cutter_blade)

func start_cutting(start_pos: Vector2, angle: float) -> void:
	cut_start_position = start_pos
	cut_direction = angle
	current_position = start_pos

	is_cutting = true
	next_slice_tick = CuttingConfig.SLICE_INTERVAL

	cut_path_line.clear_points()
	cut_path_line.add_point(current_position)

	_update_blade_visual()
	cutter_blade.visible = true

	_find_targets()

func stop_cutting() -> void:
	if is_cutting:
		_perform_slice()
		
		var pivot_offset = CuttingConfig.BLADE_WIDTH / 2.0
		var forward_direction = Vector2(cos(cut_direction), sin(cut_direction))
		current_position += forward_direction * (CuttingConfig.BLADE_LENGTH - pivot_offset)
		
	is_cutting = false
	cutter_blade.visible = false

func update_cutting(delta: float) -> void:
	if not is_cutting:
		return

	_blade_jitter_time += delta

	var direction_vector = Vector2(cos(cut_direction), sin(cut_direction))
	current_position += direction_vector * CuttingConfig.CUTTER_SPEED * delta

	if cut_path_line.points.size() == 0 or current_position.distance_to(cut_path_line.points[-1]) > 5.0:
		cut_path_line.add_point(current_position)

	_update_blade_visual()

	next_slice_tick -= delta
	if next_slice_tick <= 0:
		_perform_slice()
		next_slice_tick = CuttingConfig.SLICE_INTERVAL

func _update_blade_visual() -> void:
	var pivot_offset = CuttingConfig.BLADE_WIDTH / 2.0
	var jitter = Vector2.ZERO
	if is_cutting:
		jitter = Vector2(
			sin(_blade_jitter_time * 53.0),
			cos(_blade_jitter_time * 47.0)
		) * CuttingConfig.CUTTING_JITTER_PX
	cutter_blade.position = current_position + Vector2(cos(cut_direction), sin(cut_direction)) * (CuttingConfig.BLADE_LENGTH / 2.0 - pivot_offset) + jitter
	cutter_blade.rotation = cut_direction + PI
	
	if cutter_blade.texture:
		var texture_size = cutter_blade.texture.get_size()
		cutter_blade.scale = Vector2(
			CuttingConfig.BLADE_LENGTH / texture_size.x,
			CuttingConfig.BLADE_WIDTH / texture_size.y
		)

func _find_targets() -> void:
	targets.clear()

	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is Polygon2D and child != self:
				targets.push_back(child)
			elif child is RigidBody2D:
				for rigidbody_child in child.get_children():
					if rigidbody_child is Polygon2D:
						targets.push_back(rigidbody_child)

func _perform_slice() -> void:
	if cut_path_line.points.size() < 2:
		return

	var simplified_points = godot_polygon_slice_plugin.ramer_douglas_peucker(cut_path_line.points, 10)
	var extended_points = _extend_path_ends(simplified_points)
	var polyline = godot_polygon_slice_plugin.create_polyline(extended_points, CuttingConfig.BLADE_WIDTH)

	var matched_targets = godot_polygon_slice_plugin.find_polygon_matches(targets, polyline)
	var sliced_polygons = godot_polygon_slice_plugin.slice_polygons_with_polyline(matched_targets, polyline)

	if sliced_polygons.is_empty():
		return

	_spawn_slice_particles()
	slice_impact.emit()

	for polygon in sliced_polygons:
		get_parent().add_child(polygon)
		targets.push_back(polygon)

	for matched_target in matched_targets:
		var parent_rigidbody = matched_target.get_parent()
		if parent_rigidbody is RigidBody2D:
			parent_rigidbody.queue_free()
		else:
			matched_target.queue_free()
		targets.erase(matched_target)

func get_current_position() -> Vector2:
	return current_position

func get_current_direction() -> float:
	return cut_direction

func get_blade_center_in_parent_space() -> Vector2:
	var pivot_offset = CuttingConfig.BLADE_WIDTH / 2.0
	return position + current_position + Vector2(cos(cut_direction), sin(cut_direction)) * (CuttingConfig.BLADE_LENGTH / 2.0 - pivot_offset)

func _spawn_slice_particles() -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	var p = particles.instantiate() as CPUParticles2D
	parent_node.add_child(p)
	p.z_index = CuttingConfig.INTERFACE_Z_INDEX + 1
	p.position = get_blade_center_in_parent_space()
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func (): p.queue_free())

func _extend_path_ends(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2:
		return points

	var extended_points = PackedVector2Array()

	for point in points:
		extended_points.append(point)

	var end_direction = (points[-1] - points[-2]).normalized()
	var extended_end = points[-1] + end_direction * CuttingConfig.BLADE_EXTENSION
	extended_points.append(extended_end)

	return extended_points
