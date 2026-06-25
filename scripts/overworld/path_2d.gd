extends Path2D

func _ready() -> void:
	var line = get_node_or_null("highlight_display")
	if line and curve:
		line.points = curve.get_baked_points()
		line.width = 10
		line.default_color = Color.YELLOW
