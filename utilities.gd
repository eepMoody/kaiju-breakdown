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
		if polygon and Utilities.line_collides_with_polygon(point_a, point_b, polygon.global_transform * polygon.polygon):
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

static func interpolate_uvs_for_sliced_polygon(sliced_vertices: PackedVector2Array, original_world_vertices: PackedVector2Array, original_uvs: PackedVector2Array) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	var vertex_epsilon = 0.01 # "exact" match tolerance to account for floating point errors

	for sliced_vert in sliced_vertices:
		var found_uv = Vector2.ZERO
		var found = false

		for i in range(original_world_vertices.size()):
			if sliced_vert.distance_to(original_world_vertices[i]) < vertex_epsilon:
				found_uv = original_uvs[i]
				found = true
				break

		if not found:
			found_uv = barycentric_interpolate_uv(sliced_vert, original_world_vertices, original_uvs)

		uvs.append(found_uv)

	return uvs

static func barycentric_interpolate_uv(point: Vector2, vertices: PackedVector2Array, uvs: PackedVector2Array) -> Vector2:
	if vertices.size() < 3:
		return Vector2.ZERO

	var v0 = vertices[0]
	var uv0 = uvs[0]

	# Try each triangle in the fan
	for i in range(1, vertices.size() - 1):
		var v1 = vertices[i]
		var v2 = vertices[i + 1]
		var uv1 = uvs[i]
		var uv2 = uvs[i + 1]

		# Check if point is inside this triangle using barycentric coordinates
		var v0v1 = v1 - v0
		var v0v2 = v2 - v0
		var v0p = point - v0

		var d00 = v0v1.dot(v0v1)
		var d01 = v0v1.dot(v0v2)
		var d11 = v0v2.dot(v0v2)
		var d20 = v0p.dot(v0v1)
		var d21 = v0p.dot(v0v2)

		var denom = d00 * d11 - d01 * d01
		if abs(denom) < 0.0001:
			continue

		var v = (d11 * d20 - d01 * d21) / denom
		var w = (d00 * d21 - d01 * d20) / denom
		var u = 1.0 - v - w

		# If point is in triangle, return the interpolated UV
		if u >= -0.001 and v >= -0.001 and w >= -0.001:
			var sum = u + v + w
			if sum > 0.0001:
				u /= sum
				v /= sum
				w /= sum

			return uv0 * u + uv1 * v + uv2 * w

	# For points that fail the barycentric check,
	# use weighted average based on distance to all vertices (more expensive, less accurate)

	var total_weight = 0.0
	var weighted_uv = Vector2.ZERO

	for i in range(vertices.size()):
		var dist = point.distance_to(vertices[i])
		var weight = 1.0 / (dist * dist)
		weighted_uv += uvs[i] * weight
		total_weight += weight
		return weighted_uv / total_weight

	return uvs[0]
