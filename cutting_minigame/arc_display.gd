extends Node2D

var is_oscillating: bool = false
var oscillation_time: float = 0.0
var base_angle: float = 0.0
var origin_position: Vector2 = Vector2.ZERO

var _transition_elapsed: float = 0.0
var _transition_duration: float = 0.0
var _transition_from: Vector2 = Vector2.ZERO
var _transition_to: Vector2 = Vector2.ZERO
var _transition_active: bool = false

var arc_line: Line2D
var blade_preview: Sprite2D

var blade_texture = preload("res://assets/cutter-knife-base.png")

func _ready() -> void:
	arc_line = Line2D.new()
	arc_line.width = CuttingConfig.ARC_LINE_WIDTH
	arc_line.default_color = CuttingConfig.ARC_LINE_COLOR
	arc_line.visible = false
	arc_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(arc_line)

	blade_preview = Sprite2D.new()
	blade_preview.texture = blade_texture
	blade_preview.visible = false
	blade_preview.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(blade_preview)

func start_oscillation(start_pos: Vector2, direction_angle: float, transition_from: Vector2 = Vector2.ZERO, transition_duration: float = 0.0) -> void:
	base_angle = direction_angle
	is_oscillating = true
	oscillation_time = 0.0

	if transition_duration > 0.0:
		_transition_active = true
		_transition_elapsed = 0.0
		_transition_duration = transition_duration
		_transition_from = transition_from
		_transition_to = start_pos
		origin_position = transition_from
	else:
		_transition_active = false
		origin_position = start_pos

	_update_arc_visual()

	arc_line.visible = true
	blade_preview.visible = true

func stop_oscillation() -> void:
	is_oscillating = false
	_transition_active = false
	arc_line.visible = false
	blade_preview.visible = false

func get_current_angle() -> float:
	var swing = sin(oscillation_time * CuttingConfig.OSCILLATION_FREQUENCY) * deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)
	return base_angle + swing

func _process(delta: float) -> void:
	if not is_oscillating:
		return

	if _transition_active:
		_transition_elapsed += delta
		var t_linear = clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
		var t_eased = ease(t_linear, -2.0)
		origin_position = _transition_from.lerp(_transition_to, t_eased)
		if _transition_elapsed >= _transition_duration:
			_transition_active = false
	else:
		oscillation_time += delta

	_update_arc_visual()

	var current_angle = get_current_angle()
	var pivot_offset = CuttingConfig.BLADE_WIDTH / 2.0
	blade_preview.position = origin_position + Vector2(cos(current_angle), sin(current_angle)) * (CuttingConfig.BLADE_LENGTH / 2.0 - pivot_offset)
	blade_preview.rotation = current_angle + PI

	if blade_preview.texture:
		var texture_size = blade_preview.texture.get_size()
		var base_scale = Vector2(
			CuttingConfig.BLADE_LENGTH / texture_size.x,
			CuttingConfig.BLADE_WIDTH / texture_size.y
		)
		var lift = 1.0
		if _transition_active:
			var t_lift = clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
			var peak = 1.0 - abs(t_lift - 0.5) * 2.0
			lift = lerpf(1.0, CuttingConfig.CURSOR_TRANSITION_LIFT_SCALE, peak)
		blade_preview.scale = base_scale * lift

func _update_arc_visual() -> void:
	var left_angle = base_angle - deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)
	var right_angle = base_angle + deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)

	var left_point = origin_position + Vector2(cos(left_angle), sin(left_angle)) * CuttingConfig.ARC_RADIUS
	var right_point = origin_position + Vector2(cos(right_angle), sin(right_angle)) * CuttingConfig.ARC_RADIUS

	arc_line.clear_points()
	arc_line.add_point(left_point)
	arc_line.add_point(origin_position)
	arc_line.add_point(right_point)
