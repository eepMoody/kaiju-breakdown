extends Node2D

@onready var press_any: Sprite2D = $PressAny

var float_tween: Tween
var fade_tween: Tween

func _ready() -> void:
	_start_animations()

func _start_animations() -> void:
	var start_pos := press_any.position

	float_tween = create_tween()
	float_tween.set_loops()
	float_tween.set_parallel(true)
	float_tween.tween_property(press_any, "position:y", start_pos.y - 10, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(press_any, "position:x", start_pos.x + 5, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	press_any.modulate.a = 1.0
	fade_tween = create_tween()
	fade_tween.set_loops()
	fade_tween.tween_property(press_any, "modulate:a", 0.3, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_property(press_any, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://overworld/overworld_prototype.tscn")
