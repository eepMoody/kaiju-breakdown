class_name Utilities

static func RamerDouglasPeucker(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var maxDistance: float = 0
	var index: int = 0
	var start: Vector2 = points[0]
	var end: Vector2 = points[-1]

	for i in range(1, points.size()):
		var distance = PerpendicularDistance(points[i], start, end)

		if distance > maxDistance:
			maxDistance = distance;
			index = i;

	if maxDistance > tolerance:
		var left = RamerDouglasPeucker(points.slice(0, index + 1), tolerance)
		var right = RamerDouglasPeucker(points.slice(index), tolerance)

		var result = Array(left)
		result.pop_back()
		result.append_array(right)

		return result

	return [start, end]

static func PerpendicularDistance(point: Vector2, lineStart: Vector2, lineEnd: Vector2) -> float:
	if lineStart == lineEnd:
		return point.distance_to(lineStart)
	var line = lineEnd - lineStart
	var projection = lineStart + (point - lineStart).dot(line.normalized()) * line.normalized()
	return point.distance_to(projection)
