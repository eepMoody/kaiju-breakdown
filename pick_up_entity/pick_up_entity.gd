extends Node2D

@export var sprite: Sprite2D

var input_held: bool
var input_over: bool

var sprite_held_offset: Vector2 = Vector2.ZERO
var sprite_held_scale: Vector2 = Vector2.ONE

var input_grab_offset: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	sprite.offset = lerp(sprite.offset, sprite_held_offset, 0.1)
	sprite.scale = lerp(sprite.scale, sprite_held_scale, 0.1)

	if input_held:
		position = get_global_mouse_position() - input_grab_offset

func _input(event):
	if event is InputEventMouseMotion:
		if is_input_over() and not input_over:
			input_over = true
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		elif not is_input_over() and input_over:
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

func sprite_rect():
	return Rect2(sprite.global_position - (sprite.texture.get_size() * sprite.scale) / 2,
				sprite.texture.get_size() * sprite.scale)

func is_input_over():
	return sprite_rect().has_point(get_global_mouse_position())
