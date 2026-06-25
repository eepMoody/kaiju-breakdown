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

var part_polygon: Polygon2D

var _part_svg_path: String = ""
var _part_texture: Texture2D
var _slice_shake: float = 0.0

const CURSOR_AVAILABLE := preload("res://assets/cursor-dot.png")
const CURSOR_BLOCKED := preload("res://assets/cursor-x.png")
const CURSOR_TRIGGER := preload("res://assets/cursor-trigger.png")

# World-space region the camera keeps framed; zoom adapts to the viewport so this
# region stays visible (and the part stays large) at any resolution.
const DESIGN_VIEW_SIZE := Vector2(800, 600)

var _cursor: SoftwareCursor

@onready var camera: Camera2D = $Camera2D

func configure_from_area(area: InteractableArea) -> void:
	_part_svg_path = area.part_svg_path
	_part_texture = area.part_texture

func _ready() -> void:
	part_polygon = _create_part_polygon()
	part_polygon.z_index = CuttingConfig.KAIJU_Z_INDEX
	add_child(part_polygon)

	direction_preview_line = Line2D.new()
	direction_preview_line.width = CuttingConfig.DIRECTION_LINE_WIDTH
	direction_preview_line.default_color = CuttingConfig.DIRECTION_LINE_COLOR
	direction_preview_line.visible = false
	direction_preview_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(direction_preview_line)

	var arc_display_script = load("res://scripts/cutting_minigame/arc_display.gd")
	arc_display = Node2D.new()
	arc_display.set_script(arc_display_script)
	add_child(arc_display)

	var cutter_script = load("res://scripts/cutting_minigame/cutter.gd")
	cutter = Node2D.new()
	cutter.set_script(cutter_script)
	add_child(cutter)
	cutter.slice_impact.connect(_on_cutter_slice_impact)

	_cursor = SoftwareCursor.new()
	_cursor.texture = CURSOR_AVAILABLE
	add_child(_cursor)

	_apply_camera_scaling()
	get_viewport().size_changed.connect(_apply_camera_scaling)

func _create_part_polygon() -> Polygon2D:
	if _part_svg_path != "" and _part_texture:
		var polygon = SvgLoader.load_polygon(_part_svg_path, _part_texture)
		SvgLoader.center_polygon(polygon)
		return polygon

	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-200, -200), Vector2(200, -200),
		Vector2(200, 200), Vector2(-200, 200)
	])
	polygon.color = Color(0.6, 0.3, 0.3)
	return polygon

func _process(delta: float) -> void:
	_slice_shake = move_toward(_slice_shake, 0.0, delta * CuttingConfig.SLICE_SHAKE_DECAY)
	if camera:
		if _slice_shake > 0.01:
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _slice_shake
		else:
			camera.offset = Vector2.ZERO

	_update_hover_cursor()

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
			var start := get_global_mouse_position()
			# Don't start a cut from inside the cuttable area — only from outside it.
			if not _is_point_inside_cuttable(start):
				click_start_position = start
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
			var blade_center = cutter.get_blade_center_in_parent_space()
			cutter.stop_cutting()
			if _is_blade_outside_cuttable():
				current_state = State.IDLE
			else:
				click_start_position = cutter.get_current_position()
				base_direction_angle = cutter.get_current_direction()
				arc_display.start_oscillation(
					click_start_position,
					base_direction_angle,
					blade_center,
					CuttingConfig.CURSOR_TRANSITION_DURATION
				)
				current_state = State.OSCILLATING

func _exit_oscillation() -> void:
	arc_display.stop_oscillation()
	current_state = State.IDLE

# Fit DESIGN_VIEW_SIZE world units inside the current viewport (contain, never crop),
# so the minigame fills the modal and rescales whenever the resolution changes.
func _apply_camera_scaling() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var zoom_factor := minf(view_size.x / DESIGN_VIEW_SIZE.x, view_size.y / DESIGN_VIEW_SIZE.y)
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	if _cursor:
		_cursor.scale = Vector2.ONE / camera.zoom

func _update_hover_cursor() -> void:
	match current_state:
		# Oscillating/Cutting/Paused all advance on a mouse press; prompt for it.
		State.OSCILLATING, State.CUTTING, State.PAUSED:
			_cursor.texture = CURSOR_TRIGGER
		State.IDLE:
			if _is_point_inside_cuttable(get_global_mouse_position()):
				_cursor.texture = CURSOR_BLOCKED
			else:
				_cursor.texture = CURSOR_AVAILABLE
		_:
			_cursor.texture = CURSOR_AVAILABLE

func _is_point_inside_cuttable(global_point: Vector2) -> bool:
	for polygon in _get_cuttable_polygons():
		if Geometry2D.is_point_in_polygon(global_point, _to_global_polygon(polygon)):
			return true
	return false

func _is_blade_outside_cuttable() -> bool:
	var blade = cutter.get_blade_footprint_global()
	for polygon in _get_cuttable_polygons():
		if not Geometry2D.intersect_polygons(blade, _to_global_polygon(polygon)).is_empty():
			return false
	return true

func _get_cuttable_polygons() -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for child in get_children():
		if child is Polygon2D:
			result.append(child)
		elif child is RigidBody2D:
			for rigidbody_child in child.get_children():
				if rigidbody_child is Polygon2D:
					result.append(rigidbody_child)
	return result

func _to_global_polygon(polygon: Polygon2D) -> PackedVector2Array:
	return polygon.global_transform * polygon.polygon

func _on_cutter_slice_impact() -> void:
	_slice_shake = CuttingConfig.SLICE_SHAKE_STRENGTH
	Input.vibrate_handheld(40)
	for joy in Input.get_connected_joypads():
		Input.start_joy_vibration(joy, 0.28, 0.55, 0.11)
