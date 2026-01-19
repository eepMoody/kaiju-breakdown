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

func _ready() -> void:
	temp_line = Line2D.new()
	temp_line.width = 20
	temp_line.default_color = Color.RED
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
		handle_slicing_input(delta)
	elif current_state == State.GRABBING:
		pass

func handle_slicing_input(delta: float) -> void:
	var input_position = get_global_mouse_position()

	if Input.is_action_just_pressed("Click"):
		is_pressed = true
		temp_line.clear_points()
		temp_line.add_point(input_position)
		temp_line.add_point(input_position)

	if Input.is_action_just_released("Click"):
		is_pressed = false

		var polyline = godot_polygon_slice_plugin.create_polyline(
			godot_polygon_slice_plugin.ramer_douglas_peucker(temp_line.points, 10)
		, 20)

		var matched_targets = godot_polygon_slice_plugin.find_polygon_matches(polyline.polygon, targets)
		var polygons = handle_slicing_end(polyline, matched_targets)

		for polygon in polygons:
			add_child(polygon)
			targets.push_back(polygon)

		for matched_target in matched_targets:
			matched_target.queue_free()
			targets.erase(matched_target)

	if is_pressed:
		temp_line.add_point(input_position)
	else:
		temp_line.clear_points()

static func handle_slicing_end(polyline: Polygon2D, matched_targets: Array[Polygon2D]) -> Array[Polygon2D]:
	var new_polygons: Array[Polygon2D]

	for matched_target in matched_targets:
		var sliced_polygons = godot_polygon_slice_plugin.slice_polygon_with_polyline(matched_target, polyline)

		for sliced_polygon in sliced_polygons:
			new_polygons.push_back(sliced_polygon)

	return new_polygons
