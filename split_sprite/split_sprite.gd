extends Sprite2D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		split_sprite_into_two_parts()

func split_sprite_into_two_parts() -> void:
	var polygon1 = Polygon2D.new()
	var polygon2 = Polygon2D.new()

	polygon1.texture = texture
	polygon2.texture = texture

	var texture_size = texture.get_size()

	var top_vertices = PackedVector2Array([
		Vector2(0, 0),
		Vector2(texture_size.x / 2, 0),
		Vector2(texture_size.x / 2, texture_size.y),
		Vector2(0, texture_size.y)
	])

	var bottom_vertices = PackedVector2Array([
		Vector2(texture_size.x / 2, 0),
		Vector2(texture_size.x, 0),
		Vector2(texture_size.x, texture_size.y),
		Vector2(texture_size.x / 2, texture_size.y)
	])

	polygon1.polygon = top_vertices
	polygon2.polygon = bottom_vertices

	polygon1.uv = top_vertices
	polygon2.uv = bottom_vertices

	polygon1.position = to_global(get_rect().position) + Vector2(-10, 0)
	polygon2.position = to_global(get_rect().position) + Vector2(10, 0)

	get_parent().add_child(polygon1)
	get_parent().add_child(polygon2)

	visible = false
