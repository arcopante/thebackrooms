extends Control

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.visible = FileAccess.file_exists("user://save.json")

func _on_new_game_pressed() -> void:
	# Resetear todo el estado antes de empezar partida nueva
	if SanityManager != null:
		SanityManager.reset_for_new_level(100.0)
	GameManager.loaded_player_hp = 100
	GameManager.loaded_player_sanity = 100.0
	GameManager.loaded_player_position = Vector3.ZERO
	GameManager.loaded_map_seed = 0
	GameManager.is_loading_save = false
	GameManager.death_reason = ""
	GameManager.change_level(5)
	GameManager.set_game_state("playing")
	get_tree().change_scene_to_file("res://scenes/levels/GameLevel.tscn")

func _on_continue_pressed() -> void:
	GameManager.load_game()
	GameManager.set_game_state("playing")
	get_tree().change_scene_to_file("res://scenes/levels/GameLevel.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
