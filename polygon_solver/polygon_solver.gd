extends Node2D

enum State {
  SLICING,
  GRABBING
}

var current_state: State = State.SLICING

var is_pressed: bool

var temp_line: Line2D

var pick_up_script = preload("res://polygon_solver/pick_up_entity.gd")

@export var targets: Array[Polygon2D]

@export var current_state_label: Label

func _ready() -> void:
	temp_line = Line2D.new()
	temp_line.width = 20
	temp_line.default_color = Color.RED
	temp_line.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	get_parent().call_deferred("add_child", temp_line)

	for target in targets:
		target.set_script(pick_up_script)

func _process(_delta: float) -> void:
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
		handle_slicing()
	elif current_state == State.GRABBING:
		handle_grabbing()

func handle_slicing() -> void:
	var input_position = get_global_mouse_position()

	if Input.is_action_just_pressed("Click"):
		is_pressed = true
		temp_line.clear_points()
		temp_line.add_point(input_position)
		temp_line.add_point(input_position)

	if Input.is_action_just_released("Click"):
		if abs(temp_line.points[0].distance_to(temp_line.points[1])) > 10:
			var matched_targets = Utilities.find_polygon_matches(targets, temp_line.points[0], temp_line.points[1])

			var polyline = Utilities.create_polyline(temp_line.points[0], temp_line.points[1], 20)

			for matched_target in matched_targets:
				var sliced_polygons = Utilities.slice_polygon(matched_target, polyline)

				for sliced_polygon in sliced_polygons:
					var polygon = Polygon2D.new()
					polygon.polygon = sliced_polygon
					add_child(polygon)
					targets.push_back(polygon)

				matched_target.queue_free()
				targets.erase(matched_target)

		is_pressed = false

	if is_pressed:
		temp_line.points[1] = input_position
	else:
		temp_line.clear_points()

func handle_grabbing() -> void:
	pass
