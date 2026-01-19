extends Node2D

signal minigame_completed

enum State {
	IDLE,
	DRAGGING,
	OSCILLATING,
	CUTTING,
	PAUSED
}

var current_state: State = State.IDLE

var click_start_position: Vector2
var drag_current_position: Vector2
var base_direction_angle: float
var locked_cut_angle: float

var direction_preview_line: Line2D
var arc_display: Node2D
var cutter: Node2D

@export var kaiju_part_texture: Texture2D
@export var kaiju_part_polygon: PackedVector2Array

var part_polygon: Polygon2D
var background: ColorRect

func _ready() -> void:
	part_polygon = Polygon2D.new()
	if kaiju_part_polygon.size() > 0:
		part_polygon.polygon = kaiju_part_polygon
	else:
		part_polygon.polygon = PackedVector2Array([
			Vector2(-200, -200), Vector2(200, -200),
			Vector2(200, 200), Vector2(-200, 200)
		])

	part_polygon.color = Color(0.6, 0.3, 0.3)
	part_polygon.z_index = CuttingConfig.KAIJU_Z_INDEX
	add_child(part_polygon)

	direction_preview_line = Line2D.new()
	direction_preview_line.width = CuttingConfig.DIRECTION_LINE_WIDTH
	direction_preview_line.default_color = CuttingConfig.DIRECTION_LINE_COLOR
	direction_preview_line.visible = false
	direction_preview_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(direction_preview_line)

	var arc_display_script = load("res://cutting_minigame/arc_display.gd")
	arc_display = Node2D.new()
	arc_display.set_script(arc_display_script)
	add_child(arc_display)

	var cutter_script = load("res://cutting_minigame/cutter.gd")
	cutter = Node2D.new()
	cutter.set_script(cutter_script)
	add_child(cutter)

func _process(delta: float) -> void:
	if current_state == State.DRAGGING:
		drag_current_position = get_global_mouse_position()
		var direction_vector = drag_current_position - click_start_position
		var preview_length = min(direction_vector.length(), 150)
		var preview_end = click_start_position + direction_vector.normalized() * preview_length
		direction_preview_line.clear_points()
		direction_preview_line.add_point(click_start_position)
		direction_preview_line.add_point(preview_end)
	elif current_state == State.CUTTING:
		cutter.update_cutting(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_on_left_click_pressed()
			else:
				_on_left_click_released()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed and current_state == State.OSCILLATING:
				_exit_oscillation()
				get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		if current_state == State.OSCILLATING:
			_exit_oscillation()
			get_viewport().set_input_as_handled()
		elif current_state == State.IDLE:
			minigame_completed.emit()
			get_viewport().set_input_as_handled()

func _on_left_click_pressed() -> void:
	match current_state:
		State.IDLE:
			click_start_position = get_global_mouse_position()
			drag_current_position = click_start_position
			direction_preview_line.visible = true
			current_state = State.DRAGGING

		State.OSCILLATING:
			locked_cut_angle = arc_display.get_current_angle()
			arc_display.stop_oscillation()
			cutter.start_cutting(click_start_position, locked_cut_angle)
			current_state = State.CUTTING

func _on_left_click_released() -> void:
	match current_state:
		State.DRAGGING:
			var direction_vector = drag_current_position - click_start_position
			if direction_vector.length() > 10:
				base_direction_angle = direction_vector.angle()
				direction_preview_line.visible = false
				arc_display.start_oscillation(click_start_position, base_direction_angle)
				current_state = State.OSCILLATING
			else:
				direction_preview_line.visible = false
				current_state = State.IDLE

		State.CUTTING:
			cutter.stop_cutting()
			click_start_position = cutter.get_current_position()
			base_direction_angle = cutter.get_current_direction()
			arc_display.start_oscillation(click_start_position, base_direction_angle)
			current_state = State.OSCILLATING

func _exit_oscillation() -> void:
	arc_display.stop_oscillation()
	current_state = State.IDLE
