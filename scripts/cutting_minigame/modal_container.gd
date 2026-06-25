extends CanvasLayer

signal modal_closed

@onready var modal_control: Control = $ModalControl
@onready var viewport: SubViewport = $ModalControl/ContentContainer/ViewportContainer/SubViewport

var minigame_instance: Node = null

func _ready() -> void:
	modal_control.visible = false

func show_modal(minigame_scene: PackedScene, interact_area: InteractableArea = null) -> void:
	if minigame_instance:
		minigame_instance.queue_free()

	minigame_instance = minigame_scene.instantiate()

	if interact_area and minigame_instance.has_method("configure_from_area"):
		minigame_instance.configure_from_area(interact_area)

	viewport.add_child(minigame_instance)

	if minigame_instance.has_signal("minigame_completed"):
		minigame_instance.minigame_completed.connect(_on_minigame_completed)

	modal_control.visible = true

func hide_modal() -> void:
	if minigame_instance:
		minigame_instance.queue_free()
		minigame_instance = null

	modal_control.visible = false
	modal_closed.emit()

func _on_minigame_completed() -> void:
	hide_modal()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_modal()
		get_viewport().set_input_as_handled()
