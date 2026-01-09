extends Node2D

var temp_line: Line2D

var is_pressed: bool

@export var targets: Array[Polygon2D]

func _ready() -> void:
	temp_line = Line2D.new()
	temp_line.width = 20
	temp_line.default_color = Color.RED
	temp_line.z_index = 100000
	get_parent().call_deferred("add_child", temp_line)

func _process(_delta: float) -> void:
	var input_position = get_global_mouse_position()

	if Input.is_action_just_pressed("Click"):
		is_pressed = true
		temp_line.clear_points()
		temp_line.add_point(input_position)
		temp_line.add_point(input_position)

		for target in targets:
			target.color = Color.WHITE

	if Input.is_action_just_released("Click"):
		is_pressed = false

		if abs(temp_line.points[0].distance_to(temp_line.points[1])) > 10:
			var matchedTargets = find_polygon_matches(targets, temp_line.points[0], temp_line.points[1])

			var polyline = create_polyline(temp_line.points[0], temp_line.points[1], 20)

			for matchedTarget in matchedTargets:
				var slicedPolygons = slice_polygon(matchedTarget, polyline)

				for slicedPolygon in slicedPolygons:
					var polygon = Polygon2D.new()
					polygon.polygon = slicedPolygon
					add_child(polygon)
					targets.push_back(polygon)

				matchedTarget.queue_free()
				targets.erase(matchedTarget)

			temp_line.clear_points()

	if is_pressed:
		temp_line.points[1] = input_position

func find_polygon_matches(polygons: Array[Polygon2D], point_a: Vector2, point_b: Vector2) -> Array[Polygon2D]:
	var matches: Array[Polygon2D]

	for polygon in polygons:
		if Utilities.line_collides_with_polygon(point_a, point_b, polygon.polygon):
			matches.push_back(polygon)

	return matches

func create_polyline(point_a: Vector2, point_b: Vector2, width: int) -> Polygon2D:
	var polygon = Polygon2D.new()

	var dir = (point_b - point_a).normalized()

	var normal = dir.orthogonal()

	var offset = normal * (width / 2.0)

	polygon.polygon = PackedVector2Array([
		point_a + offset,
		point_b + offset,
		point_b - offset,
		point_a - offset
	])

	return polygon

func slice_polygon(poly_a_node: Polygon2D, poly_b_node: Polygon2D):
	var poly_a_global = poly_a_node.global_transform * poly_a_node.polygon
	var poly_b_global = poly_b_node.global_transform * poly_b_node.polygon

	var outside_fragments = Geometry2D.clip_polygons(poly_a_global, poly_b_global)

	return outside_fragments
