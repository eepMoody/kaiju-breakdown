extends RefCounted
class_name Utilities

static func interpolate_uvs_for_sliced_polygon(sliced_vertices: PackedVector2Array, original_world_vertices: PackedVector2Array, original_uvs: PackedVector2Array) -> PackedVector2Array:
	var uvs = PackedVector2Array()

	var position_to_uv = _build_position_to_uv_transform(original_world_vertices, original_uvs)
	if position_to_uv != null:
		for vertex in sliced_vertices:
			uvs.append(position_to_uv * vertex)
		return uvs

	# No triangle could be built (collinear source); fall back to nearest vertex's uv.
	for vertex in sliced_vertices:
		var nearest = 0
		var nearest_dist = INF
		for i in range(original_world_vertices.size()):
			var d = vertex.distance_squared_to(original_world_vertices[i])
			if d < nearest_dist:
				nearest_dist = d
				nearest = i
		uvs.append(original_uvs[nearest] if original_uvs.size() > 0 else Vector2.ZERO)

	return uvs

# A flat textured polygon's uv is an affine function of position, so position->uv is
# a Transform2D defined exactly by any three non-collinear vertices.
static func _build_position_to_uv_transform(pos: PackedVector2Array, uv: PackedVector2Array):
	if pos.size() < 3:
		return null

	# Avoid sliver triangles that would throw off the uv mapping.
	var i0 = 0
	var i1 = _farthest_from(pos, i0)
	var i2 = _farthest_from_line(pos, i0, i1)
	if i1 < 0 or i2 < 0:
		return null

	# Map the unit square's basis onto the source triangle, then onto the uv triangle.
	var src_triangle = Transform2D(pos[i1] - pos[i0], pos[i2] - pos[i0], pos[i0])
	var uv_triangle = Transform2D(uv[i1] - uv[i0], uv[i2] - uv[i0], uv[i0])
	return uv_triangle * src_triangle.affine_inverse()

static func _farthest_from(pos: PackedVector2Array, anchor: int) -> int:
	var best = -1
	var best_dist = 1e-6
	for i in range(pos.size()):
		if i == anchor:
			continue
		var d = pos[i].distance_squared_to(pos[anchor])
		if d > best_dist:
			best_dist = d
			best = i
	return best

# Find the vertex forming the largest-area triangle with the line a-b (least collinear).
static func _farthest_from_line(pos: PackedVector2Array, a: int, b: int) -> int:
	if a < 0 or b < 0:
		return -1
	var edge = pos[b] - pos[a]
	var best = -1
	var best_area = 1e-6
	for i in range(pos.size()):
		if i == a or i == b:
			continue
		var area = abs(edge.cross(pos[i] - pos[a]))
		if area > best_area:
			best_area = area
			best = i
	return best

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
