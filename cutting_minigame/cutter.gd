extends Node2D

var is_cutting: bool = false
var cut_start_position: Vector2
var cut_direction: float
var current_position: Vector2

var cut_path_line: Line2D
var cutter_blade: Line2D

var next_slice_tick: float = 0.0

var targets: Array[Polygon2D] = []
var particles = preload("res://gravity_demo/cpu_particles_2d.tscn")

func _ready() -> void:
	cut_path_line = Line2D.new()
	cut_path_line.width = CuttingConfig.CUT_PATH_WIDTH
	cut_path_line.default_color = CuttingConfig.CUT_PATH_COLOR
	cut_path_line.visible = false
	cut_path_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(cut_path_line)

	cutter_blade = Line2D.new()
	cutter_blade.width = CuttingConfig.BLADE_OUTLINE_WIDTH
	cutter_blade.default_color = CuttingConfig.BLADE_OUTLINE_COLOR
	cutter_blade.visible = false
	cutter_blade.z_index = CuttingConfig.INTERFACE_Z_INDEX
	cutter_blade.closed = true
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
	is_cutting = false
	cutter_blade.visible = false

func update_cutting(delta: float) -> void:
	if not is_cutting:
		return

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
	cutter_blade.points = Utilities.new().blade_outline_points(
		current_position,
		cut_direction,
		CuttingConfig.BLADE_WIDTH,
		CuttingConfig.BLADE_LENGTH,
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

	for polygon in sliced_polygons:
		add_child(polygon)
		targets.push_back(polygon)

	for matched_target in matched_targets:
		matched_target.queue_free()
		targets.erase(matched_target)

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
