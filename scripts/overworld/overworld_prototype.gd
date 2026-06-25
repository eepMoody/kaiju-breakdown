extends Node2D

const LEVEL_PATH := "res://scenes/game_scene/levels/overworld.tscn"

func _ready() -> void:
	# Play the opening dialog only the first time. Once it's been completed,
	# resuming (Continue) lands straight in the overworld without replaying it.
	if GameState.is_intro_completed():
		return
	Dialogic.timeline_ended.connect(_on_intro_dialog_finished, CONNECT_ONE_SHOT)
	Dialogic.start('main')

func _on_intro_dialog_finished() -> void:
	GameState.complete_intro("")
	# Checkpoint here so the main menu's Continue resumes in the overworld.
	GameState.set_checkpoint_level_path(LEVEL_PATH)
