extends Sprite2D

var input_held: bool

var position_history: Line2D

var start_position: Vector2

func _ready() -> void:
	position_history = Line2D.new()
	position_history.width = 10
	position_history.default_color = Color.GREEN
	position_history.z_index = -1
	get_parent().call_deferred("add_child", position_history)

func _process(_delta: float) -> void:
	if input_held:
		position = lerp(position, get_global_mouse_position(), 0.01)
		position_history.add_point(position)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			input_held = true
		else:
			input_held = false
