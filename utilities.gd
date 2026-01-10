class_name Utilities

static func ramer_douglas_peucker(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var max_distance: float = 0
	var index: int = 0
	var start: Vector2 = points[0]
	var end: Vector2 = points[-1]

	for i in range(1, points.size()):
		var distance = perpendicular_distance(points[i], start, end)

		if distance > max_distance:
			max_distance = distance;
			index = i;

	if max_distance > tolerance:
		var left = ramer_douglas_peucker(points.slice(0, index + 1), tolerance)
		var right = ramer_douglas_peucker(points.slice(index), tolerance)

		var result = Array(left)
		result.pop_back()
		result.append_array(right)

		return result

	return [start, end]

static func perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	if line_start == line_end:
		return point.distance_to(line_start)
	var line = line_end - line_start
	var projection = line_start + (point - line_start).dot(line.normalized()) * line.normalized()
	return point.distance_to(projection)

static func line_collides_with_polygon(line_a: Vector2, line_b: Vector2, polygon_points: PackedVector2Array) -> bool:
	for i in range(polygon_points.size()):
		var p1 = polygon_points[i]
		var p2 = polygon_points[(i + 1) % polygon_points.size()]
		if Geometry2D.segment_intersects_segment(line_a, line_b, p1, p2) != null:
			return true

	if Geometry2D.is_point_in_polygon(line_a, polygon_points):
		return true

	return false

static func find_polygon_matches(polygons: Array[Polygon2D], point_a: Vector2, point_b: Vector2) -> Array[Polygon2D]:
	var matches: Array[Polygon2D]

	for polygon in polygons:
		if Utilities.line_collides_with_polygon(point_a, point_b, polygon.global_transform * polygon.polygon):
			matches.push_back(polygon)

	return matches

static func create_polyline(point_a: Vector2, point_b: Vector2, width: int) -> Polygon2D:
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

static func slice_polygon(poly_a_node: Polygon2D, poly_b_node: Polygon2D):
	return Geometry2D.clip_polygons(
		get_global_polygon_position(poly_a_node),
		get_global_polygon_position(poly_b_node)
	)

static func get_global_polygon_position(polygon: Polygon2D) -> PackedVector2Array:
	return polygon.global_transform * polygon.polygon
