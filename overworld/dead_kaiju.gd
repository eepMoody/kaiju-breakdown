# dead_kaiju.gd - SIMPLIFIED MANAGER
extends Node2D

var current_area: InteractableArea = null

func _ready() -> void:
	add_to_group("kaiju_manager")

func _notify_area_entered(area: InteractableArea) -> void:
	print("Area entered: ", area.part_id)
	if current_area and current_area != area:
		current_area.hide_highlight()

	current_area = area
	current_area.show_highlight()

func _notify_area_exited(area: InteractableArea) -> void:
	if current_area == area:
		current_area.hide_highlight()
		current_area = null

func _notify_interaction(area: InteractableArea) -> void:
	if area.interaction_scene:
		var instance = area.interaction_scene.instantiate()
		get_tree().root.add_child(instance)
