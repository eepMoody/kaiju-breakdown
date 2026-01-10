# interactable_area.gd - SIMPLIFIED
class_name InteractableArea
extends Area2D  # Area2D directly, not Node2D parent!

signal interacted(area: InteractableArea)

@export var part_id: String = ""
@export var interaction_scene: PackedScene
@export_group("Highlight")
@export var highlight_color: Color = Color.YELLOW
@export var highlight_width: float = 10.0

@onready var highlight: Path2D = $HighlightPath

var is_active: bool = false

func _ready() -> void:
	collision_layer = 2  # Interactables
	collision_mask = 1   # Player

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	part_id = name

	_set_highlight(false)

func _on_body_entered(_body: Node2D) -> void:
	is_active = true
	get_tree().call_group("kaiju_manager", "_notify_area_entered", self)

func _on_body_exited(_body: Node2D) -> void:
	is_active = false
	get_tree().call_group("kaiju_manager", "_notify_area_exited", self)

func _input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interact"):
		get_tree().call_group("kaiju_manager", "_notify_interaction", self)
		get_viewport().set_input_as_handled()
		print("Interacted with InteractableArea: ", part_id)

func show_highlight() -> void:
	_set_highlight(true)

func hide_highlight() -> void:
	_set_highlight(false)

func _set_highlight(visible: bool) -> void:
	if highlight:
		highlight.visible = visible
