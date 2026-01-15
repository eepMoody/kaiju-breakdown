extends Node2D

enum State {
  SLICING,
  GRABBING
}

var current_state: State = State.SLICING

var is_pressed: bool

var temp_line: Line2D

var pick_up_script = preload("res://polygon_solver/pick_up_entity.gd")

var particles = preload("res://gravity_demo/cpu_particles_2d.tscn")

@export var targets: Array[Polygon2D]

@export var current_state_label: Label

var next_tick: float

func _ready() -> void:
	temp_line = Line2D.new()
	temp_line.width = 20
	temp_line.default_color = Color.TRANSPARENT
	temp_line.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	get_parent().call_deferred("add_child", temp_line)

	# Clean up null entries the editor sometimes leaves behind
	clean_targets()
	for child in get_children():
		if child is Polygon2D:
			targets.push_back(child)

	for target in targets:
		target.set_script(pick_up_script)

func clean_targets() -> void:
	targets = targets.filter(func(t): return t != null)

func _process(delta: float) -> void:
	if current_state_label:
		match current_state:
			State.SLICING:
				current_state_label.text = "Slicing"
			State.GRABBING:
				current_state_label.text = "Grabbing"

	if Input.is_action_just_pressed("Slicing"):
		current_state = State.SLICING

		for target in targets:
			target.color = Color.WHITE
			target.set_script(null)

		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	elif Input.is_action_just_pressed("Grabbing"):
		current_state = State.GRABBING

		for target in targets:
			target.set_script(pick_up_script)
			target.set_process(true)
			target.set_process_input(true)

	if current_state == State.SLICING:
		handle_slicing(delta)
	elif current_state == State.GRABBING:
		handle_grabbing()

func handle_slicing(delta: float) -> void:
	var input_position = get_global_mouse_position()

	next_tick -= delta

	if is_pressed and temp_line.points.size() > 1 and next_tick < 0:
		handle_slicing_end(godot_polygon_slice_plugin.ramer_douglas_peucker(temp_line.points, 10))
		if particles:
			var p = particles.instantiate()
			p.position = input_position
			p.finished.connect(p.queue_free)
			p.emitting = true
			get_parent().add_child(p)

		next_tick = 0.1

	if Input.is_action_just_pressed("Click"):
		is_pressed = true
		temp_line.clear_points()
		temp_line.add_point(input_position)
		temp_line.add_point(input_position)

	if Input.is_action_just_released("Click"):
		is_pressed = false

	if is_pressed:
		temp_line.add_point(input_position)
	else:
		temp_line.clear_points()

func handle_grabbing() -> void:
	pass


func find_target_matches(points: PackedVector2Array) -> Array[Polygon2D]:
	var matches: Array[Polygon2D]

	for target in targets:
		if (Geometry2D.intersect_polyline_with_polygon(points, target.polygon)):
			matches.push_back(target)

	return matches

func handle_slicing_end(points: PackedVector2Array) -> void:
	var matched_targets = find_target_matches(points)

	var polyline = Polygon2D.new()

	polyline.polygon = godot_polygon_slice_plugin.create_polyline(points, 20)

	for matched_target in matched_targets:
		var sliced_polygons = Geometry2D.clip_polygons(
			matched_target.global_transform * matched_target.polygon,
			polyline.global_transform * polyline.polygon
		)

		var original_world_verts = matched_target.global_transform * matched_target.polygon
		var original_uvs = matched_target.uv

		for sliced_polygon in sliced_polygons:
			var rigidbody = RigidBody2D.new()
			var polygon = Polygon2D.new()

			polygon.polygon = sliced_polygon

			var surface_area = godot_polygon_slice_plugin.get_polygon_area(polygon.polygon) / 1000

			if surface_area < 50:
				var collider = CollisionPolygon2D.new()
				collider.polygon = polygon.polygon
				polygon.add_child(collider)

			if surface_area < 50:
				rigidbody.set_freeze_enabled(false)
			else:
				rigidbody.set_freeze_enabled(true)

			if matched_target.texture and original_uvs.size() >= 3:
				polygon.uv = Utilities.interpolate_uvs_for_sliced_polygon(
					sliced_polygon,
					original_world_verts,
					original_uvs
				)

			polygon.texture = matched_target.texture
			polygon.color = matched_target.color

			rigidbody.add_child(polygon)

			add_child(rigidbody)
			targets.push_back(polygon)

		matched_target.queue_free()
		targets.erase(matched_target)
