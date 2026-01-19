extends Node2D

var is_oscillating: bool = false
var oscillation_time: float = 0.0
var base_angle: float = 0.0
var origin_position: Vector2 = Vector2.ZERO

var arc_line: Line2D
var blade_preview: Line2D

func _ready() -> void:
	arc_line = Line2D.new()
	arc_line.width = CuttingConfig.ARC_LINE_WIDTH
	arc_line.default_color = CuttingConfig.ARC_LINE_COLOR
	arc_line.visible = false
	arc_line.z_index = CuttingConfig.INTERFACE_Z_INDEX
	add_child(arc_line)

	blade_preview = Line2D.new()
	blade_preview.width = CuttingConfig.BLADE_OUTLINE_WIDTH
	blade_preview.default_color = CuttingConfig.BLADE_OUTLINE_COLOR
	blade_preview.visible = false
	blade_preview.z_index = CuttingConfig.INTERFACE_Z_INDEX
	blade_preview.closed = true
	add_child(blade_preview)

func start_oscillation(start_pos: Vector2, direction_angle: float) -> void:
	origin_position = start_pos
	base_angle = direction_angle
	is_oscillating = true
	oscillation_time = 0.0

	_update_arc_visual()

	arc_line.visible = true
	blade_preview.visible = true

func stop_oscillation() -> void:
	is_oscillating = false
	arc_line.visible = false
	blade_preview.visible = false

func get_current_angle() -> float:
	var swing = sin(oscillation_time * CuttingConfig.OSCILLATION_FREQUENCY) * deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)
	return base_angle + swing

func _process(delta: float) -> void:
	if is_oscillating:
		oscillation_time += delta
		blade_preview.points = Utilities.new().blade_outline_points(
			origin_position,
			get_current_angle(),
			CuttingConfig.BLADE_WIDTH,
			CuttingConfig.BLADE_LENGTH,
		)

func _update_arc_visual() -> void:
	var left_angle = base_angle - deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)
	var right_angle = base_angle + deg_to_rad(CuttingConfig.ARC_WIDTH_DEGREES/2)

	var left_point = origin_position + Vector2(cos(left_angle), sin(left_angle)) * CuttingConfig.ARC_RADIUS
	var right_point = origin_position + Vector2(cos(right_angle), sin(right_angle)) * CuttingConfig.ARC_RADIUS

	arc_line.clear_points()
	arc_line.add_point(left_point)
	arc_line.add_point(origin_position)
	arc_line.add_point(right_point)
