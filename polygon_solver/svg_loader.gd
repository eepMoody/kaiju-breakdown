extends Node

@export var texture: Texture2D

func _ready():
	var paper_polygon = load_svg_as_polygon2d("res://polygon_solver/textures/paper.svg")

	get_parent().call_deferred("add_child", paper_polygon)

func load_svg_as_polygon2d(path: String) -> Polygon2D:
	var polygon = Polygon2D.new()

	var parser = XMLParser.new()
	parser.open(path)

	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.has_attribute("id"):
				var node_id = parser.get_named_attribute_value("id")

				if node_id == "outline":
					var d = parser.get_named_attribute_value("d")

					polygon.polygon = parse_path_into_points(d)

	polygon.texture = texture

	return polygon

func parse_path_into_points(path_data: String) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var cursor = Vector2.ZERO

	var regex = RegEx.new()
	regex.compile("([a-zA-Z])|(-?[0-9.]*)")

	var tokens: Array = []
	for m in regex.search_all(path_data):
		var s = m.get_string()
		if s != "":
			tokens.push_back(s)

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
			"H":
				cursor.x = t.to_float()
				points.append(cursor)
			"V":
				cursor.y = t.to_float()
				points.append(cursor)

	return points
