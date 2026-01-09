class_name Utilities

static func ramer_douglas_peucker(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var maxDistance: float = 0
	var index: int = 0
	var start: Vector2 = points[0]
	var end: Vector2 = points[-1]

	for i in range(1, points.size()):
		var distance = perpendicular_distance(points[i], start, end)

		if distance > maxDistance:
			maxDistance = distance;
			index = i;

	if maxDistance > tolerance:
		var left = ramer_douglas_peucker(points.slice(0, index + 1), tolerance)
		var right = ramer_douglas_peucker(points.slice(index), tolerance)

		var result = Array(left)
		result.pop_back()
		result.append_array(right)

		return result

	return [start, end]

static func perpendicular_distance(point: Vector2, lineStart: Vector2, lineEnd: Vector2) -> float:
	if lineStart == lineEnd:
		return point.distance_to(lineStart)
	var line = lineEnd - lineStart
	var projection = lineStart + (point - lineStart).dot(line.normalized()) * line.normalized()
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
