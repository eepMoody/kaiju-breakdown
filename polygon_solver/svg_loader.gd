class_name SvgLoader
extends Node

@export var svg_path: String = "res://polygon_solver/textures/paw-vector.svg"
@export var texture: Texture2D
@export var target_parent: Node
@export var polygon_solver: PolygonSolver

func _ready() -> void:
	if svg_path.is_empty() or texture == null:
		return

	var polygon = load_polygon(svg_path, texture)
	target_parent.call_deferred("add_child", polygon)
	polygon_solver.call_deferred("reset_targets")

static func load_polygon(path: String, part_texture: Texture2D, scale: float = 0.25) -> Polygon2D:
	var polygon = Polygon2D.new()

	var parser = XMLParser.new()
	parser.open(path)

	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.has_attribute("id"):
				var node_id = parser.get_named_attribute_value("id")

				if node_id == "outline":
					var d = parser.get_named_attribute_value("d")
					var points = parse_path_into_points(d)

					points = godot_polygon_slice_plugin.ramer_douglas_peucker(points, 200)
					polygon.polygon = points
					polygon.uv = points
					polygon.texture = part_texture
					polygon.color = Color.WHITE
					polygon.scale = Vector2.ONE * scale

	return polygon

static func parse_path_into_points(path_data: String) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var cursor = Vector2.ZERO

	var regex = RegEx.new()
	regex.compile("([a-zA-Z])|(-?[0-9.]+)")

	var tokens: Array = []
	for m in regex.search_all(path_data):
		var s = m.get_string()
		if s != "": tokens.push_back(s)

	var cmd = ""
	while tokens.size() > 0:
		var t = tokens.pop_front().to_upper()

		if (t >= "A" and t <= "Z"):
			cmd = t
			if cmd == "Z" and points.size() > 0:
				points.append(points[0])
			continue

		match cmd:
			"M", "L":
				cursor = Vector2(
					t.to_float(),
					tokens.pop_front().to_float()
				)
				points.append(cursor)
				if cmd == "M": cmd = "L"
			"C":
				var cp1 = Vector2(t.to_float(), tokens.pop_front().to_float())
				var cp2 = Vector2(tokens.pop_front().to_float(), tokens.pop_front().to_float())
				var dest = Vector2(tokens.pop_front().to_float(), tokens.pop_front().to_float())

				var segments = 12
				for i in range(1, segments + 1):
					var weight = i / float(segments)
					var curve_pt = cursor.bezier_interpolate(cp1, cp2, dest, weight)
					points.append(curve_pt)

				cursor = dest

	return points

static func center_polygon(polygon: Polygon2D) -> void:
	if polygon.polygon.is_empty():
		return

	var min_vertex = polygon.polygon[0]
	var max_vertex = polygon.polygon[0]

	for vertex in polygon.polygon:
		min_vertex = min_vertex.min(vertex)
		max_vertex = max_vertex.max(vertex)

	var local_center = (min_vertex + max_vertex) / 2.0
	polygon.position = -local_center * polygon.scale
