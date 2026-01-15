class_name Utilities

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
