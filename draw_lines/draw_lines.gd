extends Node2D

var temp_line: Line2D

func _input(event):
	var input_position = get_global_mouse_position()

	if event is InputEventMouseButton:
		if event.pressed:
			temp_line = Line2D.new()
			temp_line.width = 10
			temp_line.default_color = Color.RED
			temp_line.add_point(input_position)

			add_child(temp_line)
		else:
			if temp_line:
				print(temp_line.points.size())
				temp_line.points = Utilities.RamerDouglasPeucker(temp_line.points, 10)
				print(temp_line.points.size())
				temp_line.default_color = Color.YELLOW
				temp_line = null

	elif event is InputEventMouseMotion:
		if temp_line:
			temp_line.add_point(input_position)
