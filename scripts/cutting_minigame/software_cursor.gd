class_name SoftwareCursor
extends Sprite2D

func _ready() -> void:
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	z_as_relative = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
