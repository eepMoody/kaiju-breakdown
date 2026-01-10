extends Polygon2D

var input_held: bool
var input_over: bool

var sprite_held_offset: Vector2 = Vector2.ZERO
var sprite_held_scale: Vector2 = Vector2.ONE

var input_grab_offset: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if input_held:
		position = get_global_mouse_position() - input_grab_offset

	var input_position = get_global_mouse_position()

	if Geometry2D.is_point_in_polygon(input_position, global_transform * polygon):
		color = Color.GREEN
	else:
		color = Color.WHITE

func _input(event):
	var mouse_pos = get_local_mouse_position()

	if event is InputEventMouseMotion:
		if Geometry2D.is_point_in_polygon(mouse_pos, polygon) and not input_over:
			input_over = true
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		elif not Geometry2D.is_point_in_polygon(mouse_pos, polygon) and input_over:
			input_over = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if event is InputEventMouseButton:
		if event.pressed and input_over:
			input_grab_offset = get_global_mouse_position() - position
			input_held = true
			sprite_held_offset = Vector2(0, -15)
			sprite_held_scale = Vector2.ONE * 1.1
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		elif not event.pressed and input_held:
			input_held = false
			sprite_held_offset = Vector2.ZERO
			sprite_held_scale = Vector2.ONE
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
