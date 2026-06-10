extends Control

const OVERWORLD := "res://overworld/overworld_prototype.tscn"
const _INTRO_TIMELINE_PATH := "res://dialogic/timelines/intro.dtl"

func _ready() -> void:
	var guide = load("res://addons/dialogic/Resources/character.gd").new()
	guide.display_name = "Guide"
	guide.portraits = {
		"default": {"scene": "res://story/rectangle_portrait.tscn"}
	}
	guide.default_portrait = "default"
	DialogicResourceUtil.register_runtime_resource(guide, "guide", "dch")

	var timeline = load(_INTRO_TIMELINE_PATH)
	if timeline == null:
		timeline = load("res://addons/dialogic/Resources/timeline.gd").new()
		timeline.from_text(FileAccess.get_file_as_string(_INTRO_TIMELINE_PATH))

	Dialogic.timeline_ended.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)

func _on_dialog_finished() -> void:
	get_tree().change_scene_to_file(OVERWORLD)
