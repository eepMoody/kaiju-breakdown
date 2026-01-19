extends Node2D

var current_area: InteractableArea = null
var modal_container: CanvasLayer = null

var modal_scene = preload("res://cutting_minigame/modal_container.tscn")
var cutting_minigame_scene = preload("res://cutting_minigame/cutting_minigame.tscn")

func _ready() -> void:
	add_to_group("kaiju_manager")

func _notify_area_entered(area: InteractableArea) -> void:
	if current_area and current_area != area:
		current_area.hide_highlight()

	current_area = area
	current_area.show_highlight()

func _notify_area_exited(area: InteractableArea) -> void:
	if current_area == area:
		current_area.hide_highlight()
		current_area = null

func _notify_interaction(area: InteractableArea) -> void:
	if not modal_container:
		modal_container = modal_scene.instantiate()
		modal_container.modal_closed.connect(_on_modal_closed)
		get_tree().root.add_child(modal_container)

	modal_container.show_modal(cutting_minigame_scene)

func _on_modal_closed() -> void:
	pass
