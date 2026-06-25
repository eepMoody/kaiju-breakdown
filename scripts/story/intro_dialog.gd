extends Control

const OVERWORLD := "res://scenes/game_scene/levels/overworld.tscn"
const _INTRO_TIMELINE_PATH := "res://dialogic/timelines/intro.dtl"

var _intro_choice: String = ""

func _ready() -> void:
	var guide = load("res://addons/dialogic/Resources/character.gd").new()
	guide.display_name = "Guide"
	guide.portraits = {
		"default": {"scene": "res://scenes/story/rectangle_portrait.tscn"}
	}
	guide.default_portrait = "default"
	DialogicResourceUtil.register_runtime_resource(guide, "guide", "dch")

	var timeline = load(_INTRO_TIMELINE_PATH)
	if timeline == null:
		timeline = load("res://addons/dialogic/Resources/timeline.gd").new()
		timeline.from_text(FileAccess.get_file_as_string(_INTRO_TIMELINE_PATH))

	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)

# The intro timeline emits [signal arg="ready"|"not_ready"] for the player's choice.
func _on_dialogic_signal(argument: Variant) -> void:
	_intro_choice = str(argument)

func _on_dialog_finished() -> void:
	GameState.complete_intro(_intro_choice)
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	get_tree().change_scene_to_file(OVERWORLD)
