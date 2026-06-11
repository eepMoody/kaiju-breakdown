extends RefCounted
class_name Utilities

static func interpolate_uvs_for_sliced_polygon(sliced_vertices: PackedVector2Array, original_world_vertices: PackedVector2Array, original_uvs: PackedVector2Array) -> PackedVector2Array:
	var uvs = PackedVector2Array()
	var vertex_epsilon = 0.01

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

	for i in range(1, vertices.size() - 1):
		var v1 = vertices[i]
		var v2 = vertices[i + 1]
		var uv1 = uvs[i]
		var uv2 = uvs[i + 1]

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

		if u >= -0.001 and v >= -0.001 and w >= -0.001:
			var sum = u + v + w
			if sum > 0.0001:
				u /= sum
				v /= sum
				w /= sum

			return uv0 * u + uv1 * v + uv2 * w

	var total_weight = 0.0
	var weighted_uv = Vector2.ZERO

	for i in range(vertices.size()):
		var dist = point.distance_to(vertices[i])
		if dist < 0.0001:
			return uvs[i]
		var weight = 1.0 / (dist * dist)
		weighted_uv += uvs[i] * weight
		total_weight += weight

	if total_weight > 0.0001:
		return weighted_uv / total_weight

	return uvs[0]

static func spawn_sliced_fragments(
	parent: Node2D,
	matched_targets: Array[Polygon2D],
	polyline: Polygon2D,
	targets: Array[Polygon2D]
) -> bool:
	var spawned_any := false

	for matched_target in matched_targets:
		var sliced_polygons = Geometry2D.clip_polygons(
			matched_target.global_transform * matched_target.polygon,
			polyline.global_transform * polyline.polygon
		)

		var original_world_verts = matched_target.global_transform * matched_target.polygon
		var original_uvs = matched_target.uv

		for world_polygon in sliced_polygons:
			spawned_any = true

			var centroid := Vector2.ZERO
			for vertex in world_polygon:
				centroid += vertex
			centroid /= world_polygon.size()

			var rigidbody = RigidBody2D.new()
			rigidbody.position = parent.to_local(centroid)

			var local_polygon := PackedVector2Array()
			for vertex in world_polygon:
				local_polygon.append(parent.to_local(vertex) - rigidbody.position)

			var polygon = Polygon2D.new()
			polygon.polygon = local_polygon

			var surface_area = godot_polygon_slice_plugin.get_polygon_area(local_polygon) / 1000.0
			var is_harvestable = surface_area < CuttingConfig.HARVESTABLE_AREA_THRESHOLD

			if is_harvestable:
				var collider = CollisionPolygon2D.new()
				collider.polygon = local_polygon
				polygon.add_child(collider)
				rigidbody.freeze = false
				polygon.modulate = CuttingConfig.HARVESTABLE_HIGHLIGHT
			else:
				rigidbody.freeze = true

			if matched_target.texture and original_uvs.size() >= 3:
				polygon.uv = interpolate_uvs_for_sliced_polygon(
					world_polygon,
					original_world_verts,
					original_uvs
				)

			polygon.texture = matched_target.texture
			polygon.color = matched_target.color

			rigidbody.add_child(polygon)
			parent.add_child(rigidbody)
			targets.push_back(polygon)

		var parent_rigidbody = matched_target.get_parent()
		if parent_rigidbody is RigidBody2D:
			parent_rigidbody.queue_free()
		else:
			matched_target.queue_free()
		targets.erase(matched_target)

	return spawned_any
