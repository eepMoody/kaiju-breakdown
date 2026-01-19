extends RefCounted
class_name Utilities

func blade_outline_points(origin: Vector2, angle: float, blade_width: float, blade_length: float) -> PackedVector2Array:
	var perpendicular_angle = angle + PI / 2
	var half_width = blade_width / 2.0
	var offset = Vector2(cos(perpendicular_angle), sin(perpendicular_angle)) * half_width

	var forward_direction = Vector2(cos(angle), sin(angle))
	var pivot_offset = blade_width / 2.0
	var extended_start = origin - forward_direction * pivot_offset
	var extended_end = origin + forward_direction * (blade_length - pivot_offset)

	return PackedVector2Array([
		extended_start - offset,
		extended_start + offset,
		extended_end + offset,
		extended_end - offset,
		extended_start - offset
	])
